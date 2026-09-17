#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""Aggregation primitives over Claude Code JSONL transcripts (issues #179, #268).

The method is the one ADR-0017 > Notes > C8 records, first committed in
scripts/architect/deliberation-metrics.py (issue #179) and moved here so the
cycle collector (scripts/metrics/cycle-metrics.py, issue #268) computes the same
figures from the same code:

  * one API call = one distinct `requestId` among a transcript's `assistant`
    records (streamed records of one request share the id);
  * tokens = cache_creation / cache_read / output summed over `message.usage`,
    de-duplicated by `message.id` keeping the record with the largest
    output_tokens;
  * `first_in` = input + cache_read + cache_creation of the first assistant
    record of a slice (the prompt the slice opened with);
  * a persistent agent's transcript splits into wakes at each user record that
    is a message rather than a tool result;
  * a re-write is a call whose
    cache_creation >= 0.9 * (cache_read + cache_creation) — the whole prefix
    was written rather than read from cache.

Records may be raw harness records or the metering-only form a stripped copy
keeps (`user: {kind}` in place of the message content, `tool_use: [...]` in
place of the content blocks); both are read. Only the standard library is used.
"""
import datetime as dt
import json
import re

PATH_RE = re.compile(r'(?<!\w)((?:\.autoflow|\.claude|docs|scripts|tests|test|setup|plugin)/[\w./-]+\.[a-z]+)')
REWRITE_RATIO = 0.9


def parse_ts(s):
    if not s:
        return None
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    try:
        return dt.datetime.fromisoformat(s)
    except ValueError:
        return None


def load(path):
    recs = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                recs.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return recs


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return ''.join(p.get('text', '') for p in content if isinstance(p, dict) and p.get('type') == 'text')
    return ''


def is_wake(rec):
    """A user record that is a message to the agent (spawn prompt or a wake), not a tool result."""
    if rec.get('type') != 'user':
        return False
    if isinstance(rec.get('user'), dict):
        return rec['user'].get('kind') == 'text'
    content = (rec.get('message') or {}).get('content')
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(isinstance(p, dict) and p.get('type') == 'tool_result' for p in content)
    return False


def tool_use_blocks(rec):
    """The tool_use blocks of one assistant record, raw or stripped."""
    if isinstance(rec.get('tool_use'), list):
        return [c for c in rec['tool_use'] if isinstance(c, dict)]
    content = (rec.get('message') or {}).get('content')
    if not isinstance(content, list):
        return []
    return [c for c in content if isinstance(c, dict) and c.get('type') == 'tool_use']


def dedup_calls(assistant_recs):
    """One entry per message.id, in first-seen order, keeping the usage with the largest output_tokens."""
    best = {}
    for r in assistant_recs:
        m = r.get('message') or {}
        u = m.get('usage')
        if not u:
            continue
        mid = m.get('id') or r.get('requestId') or id(r)
        cur = best.get(mid)
        if cur is None:
            best[mid] = {'ts': r.get('timestamp'), 'model': m.get('model'), 'usage': u}
        elif (u.get('output_tokens') or 0) > (cur['usage'].get('output_tokens') or 0):
            cur['usage'] = u
    calls = []
    for c in best.values():
        u = c['usage']
        calls.append({
            'ts': c['ts'],
            'model': c['model'],
            'input': u.get('input_tokens') or 0,
            'cache_creation': u.get('cache_creation_input_tokens') or 0,
            'cache_read': u.get('cache_read_input_tokens') or 0,
            'output': u.get('output_tokens') or 0,
        })
    return calls


def context_of(call):
    return call['input'] + call['cache_read'] + call['cache_creation']


def is_rewrite(call):
    cached = call['cache_read'] + call['cache_creation']
    return cached > 0 and call['cache_creation'] >= REWRITE_RATIO * cached


def usage_totals(assistant_recs):
    """Sum usage de-duplicated by message.id, keeping the record with the largest output_tokens."""
    tot = {'input': 0, 'cache_creation': 0, 'cache_read': 0, 'output': 0}
    for c in dedup_calls(assistant_recs):
        for k in tot:
            tot[k] += c[k]
    return tot


def first_in(assistant_recs):
    for r in assistant_recs:
        u = (r.get('message') or {}).get('usage')
        if u:
            return (u.get('input_tokens') or 0) + (u.get('cache_read_input_tokens') or 0) + (u.get('cache_creation_input_tokens') or 0)
    return 0


def first_cache_creation(assistant_recs):
    for r in assistant_recs:
        u = (r.get('message') or {}).get('usage')
        if u:
            return u.get('cache_creation_input_tokens') or 0
    return 0


def tool_uses(assistant_recs):
    seen = set()
    counts = {}
    paths = set()
    message_len = None
    for r in assistant_recs:
        for c in tool_use_blocks(r):
            cid = c.get('id')
            if cid in seen:
                continue
            seen.add(cid)
            name = c.get('name') or '?'
            counts[name] = counts.get(name, 0) + 1
            inp = c.get('input') or {}
            if name == 'Bash':
                for m in PATH_RE.findall(inp.get('command') or ''):
                    paths.add(m)
            elif name in ('Read', 'Grep', 'Glob'):
                fp = inp.get('file_path') or inp.get('path')
                if fp:
                    paths.add(re.sub(r'^.*?/(?=(\.autoflow|\.claude|docs|scripts|tests|test|setup|plugin)/)', '', fp))
            if name == 'StructuredOutput' and isinstance(inp.get('message'), str):
                message_len = len(inp['message'])
    return counts, paths, message_len


def tool_seconds(recs):
    """Tool execution time: the span from each tool_use record to the next user record (§1.3)."""
    total = 0.0
    longest = 0.0
    pending = None
    for r in recs:
        if r.get('type') == 'assistant' and tool_use_blocks(r):
            pending = parse_ts(r.get('timestamp'))
        elif r.get('type') == 'user' and pending is not None:
            t = parse_ts(r.get('timestamp'))
            if t:
                span = (t - pending).total_seconds()
                total += span
                longest = max(longest, span)
            pending = None
    return round(total, 1), round(longest, 1)


def segment_stats(recs):
    """Stats for one contiguous slice of records (a whole one-shot agent, or one wake)."""
    a = [r for r in recs if r.get('type') == 'assistant']
    ts = [parse_ts(r.get('timestamp')) for r in recs]
    ts = [t for t in ts if t]
    calls = len({r.get('requestId') for r in a if r.get('requestId')})
    counts, paths, message_len = tool_uses(a)
    tool_s, longest_tool_s = tool_seconds(recs)
    return {
        'tool_s': tool_s,
        'longest_tool_s': longest_tool_s,
        'calls': calls,
        'tools': counts,
        'bash': counts.get('Bash', 0),
        'paths': sorted(paths),
        'first_in': first_in(a),
        'first_cache_creation': first_cache_creation(a),
        'usage': usage_totals(a),
        'wall_s': round((max(ts) - min(ts)).total_seconds(), 1) if len(ts) >= 2 else 0.0,
        'start': min(ts).isoformat() if ts else None,
        'end': max(ts).isoformat() if ts else None,
        'message_len': message_len,
    }


def wake_indices(recs):
    return [i for i, r in enumerate(recs) if is_wake(r)]
