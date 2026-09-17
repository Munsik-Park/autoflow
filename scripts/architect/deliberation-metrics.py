#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""ARCHITECT deliberation — cost aggregation over agent transcripts (issue #179).

The effect record of ADR-0023 D4 compares two ARCHITECT arms — the per-turn
respawn script (arm 0) and the orchestrator-relayed persistent participants
(arm A2) — on the same input. The review that measured the baseline
(docs/records/design-reviews/issue-177-deliberation-participant-lifetime.md, §1.3)
computed its numbers with scratch scripts that were not committed; this script
is that method, committed so the metric re-derives:

  * one API call = one distinct `requestId` among a transcript's `assistant`
    records (streamed records of one request share the id);
  * a turn's `first_in` = input + cache_read + cache_creation tokens of its
    first assistant record (the prompt the turn opened with);
  * tool calls = `tool_use` blocks by `name`, de-duplicated by block id;
  * wall = last record timestamp minus first;
  * tokens = cache_creation / cache_read / output summed over `message.usage`,
    de-duplicated by `message.id` keeping the record with the largest
    output_tokens (ADR-0017 > Notes > C8 method);
  * a persistent participant's transcript is split into wakes at each user
    record that is a message rather than a tool result, and every per-turn
    figure above is then computed per wake.

Usage:
  deliberation-metrics.py [--label <arm>] [--transcript <relay.md>]
                          [--session <session.jsonl> --from <iso> --to <iso>]
                          [--markdown] <agent.jsonl | dir> ...

Positional arguments are agent transcripts or directories holding
`agent-*.jsonl`. `--transcript` adds per-turn message lengths from a relay
transcript file (arm A2; arm 0 reads them from each turn's StructuredOutput).
`--session` with a window adds the orchestrator's own calls and usage inside
that window (the relay turns, counted separately as the review §6 asks).
Output is JSON on stdout, or a Markdown record with `--markdown`.
Only the standard library is used; the aggregation primitives live in
scripts/metrics/transcript_stats.py.
"""
import argparse
import glob
import json
import os
import re
import sys

sys.dont_write_bytecode = True   # no __pycache__ in the checkout: PREFLIGHT wants a clean tree
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'metrics'))
# The aggregation primitives are shared with the cycle collector (issue #268).
from transcript_stats import (  # noqa: E402
    load, parse_ts, segment_stats, text_of, tool_uses, usage_totals, wake_indices,
)


def kind_of(prompt):
    p = prompt or ''
    if 'transcription channel' in p:
        return 'policy-load'
    if 'You are the scribe' in p:
        return 'scribe'
    if p.startswith('Append (do NOT rewrite') or 'Append (do NOT rewrite or delete)' in p:
        return 'ledger'
    if 'transcribed below' in p:
        return 'dev-report' if 'Developer AI' in p[:80] else 'test-report'
    if 'ARCHITECT relay' in p or 'relay participant' in p:
        return 'participant-dev' if 'Developer AI' in p[:200] else 'participant-test'
    if 'You are the Developer AI in an AutoFlow ARCHITECT deliberation' in p:
        return 'dev-turn'
    if 'You are the Test AI in an AutoFlow ARCHITECT deliberation' in p:
        return 'test-turn'
    return 'other'


def analyze_agent(path):
    recs = load(path)
    wakes = wake_indices(recs)
    prompt = text_of((recs[wakes[0]].get('message') or {}).get('content')) if wakes else ''
    kind = kind_of(prompt)
    whole = segment_stats(recs)
    segments = []
    for j, start in enumerate(wakes):
        end = wakes[j + 1] if j + 1 < len(wakes) else len(recs)
        seg = segment_stats(recs[start:end])
        seg['wake'] = j + 1
        seg['wake_text'] = text_of((recs[start].get('message') or {}).get('content'))[:120]
        segments.append(seg)
    return {
        'agent': os.path.basename(path).replace('.jsonl', ''),
        'kind': kind,
        'wakes': len(wakes),
        'whole': whole,
        'segments': segments,
    }


def transcript_turn_lengths(path):
    lengths = {}
    cur = None
    buf = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^### Turn (\d+) ', line)
            if m or line.startswith('## ') or line.startswith('### '):
                if cur is not None:
                    lengths[cur] = len(''.join(buf).strip())
                cur = int(m.group(1)) if m else None
                buf = []
                continue
            if cur is not None:
                buf.append(line)
    if cur is not None:
        lengths[cur] = len(''.join(buf).strip())
    return lengths


def session_window(path, t_from, t_to):
    recs = load(path)
    lo, hi = parse_ts(t_from), parse_ts(t_to)
    inside = [r for r in recs if r.get('type') == 'assistant' and (ts := parse_ts(r.get('timestamp'))) and lo <= ts <= hi]
    counts, _, _ = tool_uses(inside)
    return {
        'calls': len({r.get('requestId') for r in inside if r.get('requestId')}),
        'usage': usage_totals(inside),
        'tools': counts,
        'wakes': counts.get('SendMessage', 0) + counts.get('Agent', 0),
    }


def build(args):
    files = []
    for p in args.inputs:
        if os.path.isdir(p):
            files.extend(sorted(glob.glob(os.path.join(p, 'agent-*.jsonl'))))
        else:
            files.append(p)
    agents = [analyze_agent(f) for f in files]
    agents.sort(key=lambda a: a['whole']['start'] or '')

    # Turn rows, in chronological order across agents: one-shot turn agents contribute one row
    # each; a persistent participant contributes one row per wake.
    rows = []
    for a in agents:
        if a['kind'] in ('dev-turn', 'test-turn'):
            s = a['whole']
            rows.append({'side': 'dev' if a['kind'] == 'dev-turn' else 'test', 'agent': a['agent'], **s})
        elif a['kind'] in ('participant-dev', 'participant-test'):
            for s in a['segments']:
                rows.append({'side': 'dev' if a['kind'] == 'participant-dev' else 'test', 'agent': a['agent'], **s})
    rows.sort(key=lambda r: r['start'] or '')
    for i, r in enumerate(rows, 1):
        r['turn'] = i
    if args.transcript:
        lengths = transcript_turn_lengths(args.transcript)
        for r in rows:
            if r['turn'] in lengths:
                r['message_len'] = lengths[r['turn']]

    discuss_kinds = {'dev-turn', 'test-turn', 'participant-dev', 'participant-test'}
    record_kinds = {'dev-report', 'test-report', 'scribe', 'ledger'}

    def group(kinds):
        sel = [a for a in agents if a['kind'] in kinds]
        starts = [a['whole']['start'] for a in sel if a['whole']['start']]
        ends = [a['whole']['end'] for a in sel if a['whole']['end']]
        u = {'input': 0, 'cache_creation': 0, 'cache_read': 0, 'output': 0}
        for a in sel:
            for k in u:
                u[k] += a['whole']['usage'][k]
        return {
            'agents': len(sel),
            'calls': sum(a['whole']['calls'] for a in sel),
            'bash': sum(a['whole']['bash'] for a in sel),
            'tool_s': round(sum(a['whole']['tool_s'] for a in sel), 1),
            'wall_s': round((max(parse_ts(e) for e in ends) - min(parse_ts(s) for s in starts)).total_seconds(), 1) if starts and ends else 0.0,
            'usage': u,
        }

    path_counts = {}
    for a in agents:
        for p in a['whole']['paths']:
            path_counts[p] = path_counts.get(p, 0) + 1
    repeated = sorted(path_counts.items(), key=lambda kv: (-kv[1], kv[0]))

    out = {
        'label': args.label,
        'agents': agents,
        'turns': rows,
        'totals': {
            'all': group(discuss_kinds | record_kinds | {'policy-load', 'other'}),
            'discuss': group(discuss_kinds),
            'record': group(record_kinds),
        },
        'repeated_reads': [{'path': p, 'agents': n} for p, n in repeated if n >= args.min_readers],
    }
    if args.session:
        out['orchestrator'] = session_window(args.session, args.t_from, args.t_to)
    return out


def markdown(out):
    L = []
    lab = out['label'] or 'run'
    t = out['totals']
    L.append(f"### {lab} — run totals\n")
    L.append('| Item | Value |\n|---|---|')
    L.append(f"| Agents / discussion turns | {t['all']['agents']} / {len(out['turns'])} |")
    L.append(f"| API calls (distinct requestId) | {t['all']['calls']} — discussion {t['discuss']['calls']}, record {t['record']['calls']} |")
    L.append(f"| Bash tool calls | {t['all']['bash']} — discussion {t['discuss']['bash']} |")
    L.append(f"| Wall clock in-agent (s) | discussion {t['discuss']['wall_s']}, record {t['record']['wall_s']}, all {t['all']['wall_s']} |")
    L.append(f"| Tool execution (s, tool_use → next user record) | discussion {t['discuss']['tool_s']}, record {t['record']['tool_s']} — the rest of the wall is model generation |")
    u = t['all']['usage']
    L.append(f"| Tokens (dedup by message.id) | cache_creation {u['cache_creation']:,} · cache_read {u['cache_read']:,} · output {u['output']:,} · input {u['input']:,} |")
    if 'orchestrator' in out:
        o = out['orchestrator']
        ou = o['usage']
        L.append(f"| Orchestrator relay (session window) | {o['calls']} calls, {o['wakes']} wake/spawn tool uses; cache_creation {ou['cache_creation']:,} · cache_read {ou['cache_read']:,} · output {ou['output']:,} |")
    L.append('')
    L.append(f"### {lab} — per turn\n")
    L.append('| turn | side | calls | Bash | wall (s) | tool (s) | first_in | cache_w (first call) | msg |\n|---|---|---|---|---|---|---|---|---|')
    for r in out['turns']:
        L.append(f"| {r['turn']} | {r['side']} | {r['calls']} | {r['bash']} | {r['wall_s']} | {r['tool_s']} | {r['first_in']:,} | {r['first_cache_creation']:,} | {r['message_len'] if r['message_len'] is not None else '—'} |")
    L.append('')
    if out['repeated_reads']:
        L.append(f"### {lab} — paths read by ≥ {min(x['agents'] for x in out['repeated_reads'])} agents\n")
        for x in out['repeated_reads']:
            L.append(f"- `{x['path']}` ({x['agents']})")
        L.append('')
    return '\n'.join(L)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('inputs', nargs='+', help='agent transcript files or directories of agent-*.jsonl')
    ap.add_argument('--label', default='')
    ap.add_argument('--transcript', help='relay transcript (.md) for per-turn message lengths')
    ap.add_argument('--session', help='orchestrator session transcript (.jsonl)')
    ap.add_argument('--from', dest='t_from', help='window start (ISO 8601) for --session')
    ap.add_argument('--to', dest='t_to', help='window end (ISO 8601) for --session')
    ap.add_argument('--min-readers', type=int, default=2, help='report paths read by at least this many agents')
    ap.add_argument('--markdown', action='store_true')
    args = ap.parse_args(argv)
    if args.session and not (args.t_from and args.t_to):
        ap.error('--session requires --from and --to')
    out = build(args)
    if args.markdown:
        print(markdown(out))
    else:
        json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
        print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
