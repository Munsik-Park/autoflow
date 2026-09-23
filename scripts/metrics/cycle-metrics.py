#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
"""AutoFlow cycle cost / outcome collector (issue #268).

A record tool, machine-local: it reads what Claude Code already left on disk and
keeps the aggregate, because the transcripts expire and the archive does not
hold them. It changes no rule, gate, hook or bundle, is no gate input, and is
not shipped to a target (same disposition as scripts/architect/deliberation-metrics.py).

Two steps, run together by default:

  collect  ~/.claude/projects/*/<session>.jsonl
           + <session>/subagents/*.jsonl + <session>/subagents/workflows/*/*.jsonl
           -> $ROOT/sessions/<session-id>.json, written once per session and left
           alone afterwards. A session whose last record is younger than
           --settle-hours is not finalized yet and is skipped. The one case a
           session file is written again is a source transcript that GREW after
           collection (a resumed session), judged per source. The new record is
           merged with the old one, never a replacement: an agent whose
           transcript has expired in the meantime keeps its prior aggregate, and
           a main transcript that shrank or vanished leaves the record alone.

           A record written under an older schema is replaced only by a
           collection that covers it (the roots are tried in order, so a
           preserved copy can stand in for an expired transcript); with no
           covering source it is left as it is and reported.

  derive   $ROOT/sessions/*.json + $ROOT/labels.tsv + the .autoflow archive
           + $ROOT/github/*.json (the cycle rows' PRs, fetched with --gh)
           -> $ROOT/issues.tsv and $ROOT/issues.json, REGENERATED on every run,
           so a fix to the attribution logic recomputes every past issue.

$ROOT is ${AUTOFLOW_ARCHIVE_ROOT:-$HOME/.autoflow}/_metrics.

What a session record holds is aggregate only — per agent: role (the declared
`subagent_type`),
model, the spawn's short `description` label, phase-key, call count, cache
read / write / output, peak context, start / end, per-wake figures; for the
orchestrator: one row per API call (timestamp, context, cache read / write,
output, re-write flag); the `.autoflow/issue-{N}` reference runs; operator
prompt and AskUserQuestion-answer timestamps; the issues whose own state file
the session wrote; configured-reviewer launches; the harness's session cost.
No transcript text, tool output or prompt body is stored.

Phase-key recovery. Every spawn is preceded (a `[MUST]`) by a
`spawn-policy.sh model <phase-key>` readout, so the key is recovered from the
orchestrator's Bash calls: literal keys and the word list of a `for k in ...`
loop around the readout. Readouts are often batched, so the candidates are
narrowed by the policy's own `agent_type` for the spawn's `subagent_type`. The
spawn's description label decides among them (`readout+description`; plain
`description` when the named key was never read out in the session); a label
that names no key falls to the one unspent readout of that role (`readout`),
then to a role the policy maps to a single key (`agent-type`). Workflow
sub-agents take `<workflow>/<site>` (`workflow-site`). Each agent records the
method that decided it, or null, and the run prints the recovery rate.

Usage:
  cycle-metrics.py [--projects-root DIR]... [--root DIR] [--archive-root DIR]
                   [--settle-hours H] [--now ISO] [--session ID]...
                   [--policy FILE] [--no-collect] [--no-derive] [--gh]

Only the standard library is used.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True   # no __pycache__ in the checkout: PREFLIGHT wants a clean tree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from transcript_stats import (  # noqa: E402
    context_of, dedup_calls, is_rewrite, is_wake, load, parse_ts, tool_use_blocks, wake_indices,
)

SCHEMA = 3            # 3: state writes from the shell and the edit tools, reviewer runs, AskUserQuestion answers, the harness's session cost
PK_RE = re.compile(r'spawn-policy\.sh["\']?\s+(?:model|effort)\s+([A-Za-z0-9][A-Za-z0-9_-]*)')
PK_LOOP_RE = re.compile(r'\bfor\s+\w+\s+in\s+([^;\n]+?)\s*;\s*do\b')
ISSUE_RE = re.compile(r'\.autoflow/issue-(\d+)(?=[-./\s"\'`)\\]|$)')   # not a truncated preview (`issue-5…`)
WF_ISSUE_RE = re.compile(r'''["']?issue["']?\s*[:=]\s*["']?#?(\d+)''')
STATE_RE = re.compile(r'\.autoflow/issue-(\d+)\.json')
EDIT_TOOLS = ('Write', 'Edit', 'MultiEdit', 'NotebookEdit')
REVIEWER_RE = re.compile(r'codex-review-pr\.sh\b([^;&|\n>]*)')
SWITCH_REFS = 3       # consecutive references that move the session to another issue
TAIL_S = 1800         # a segment reaches this far past its last reference, no further
REVIEW_WINDOW_S = 7200  # a reviewer run's comment is looked for this far past its launch, no further
DESC_MAX = 80
USAGE_KEYS = ('input', 'cache_creation', 'cache_read', 'output')
CI_FAILED = ('failure', 'timed_out', 'startup_failure')
CI_NOT_RUN = ('cancelled', 'skipped', 'neutral', 'stale')


# --------------------------------------------------------------------------- collect

def load_policy(path):
    """{phase-key: agent_type} and {workflow: {site: model}} from the spawn policy, or empty."""
    try:
        with open(path, encoding='utf-8') as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        return {}, {}
    phases = cfg.get('phases') or {}
    keys = {k: (v or {}).get('agent_type') for k, v in phases.items()} if isinstance(phases, dict) else {}
    return keys, cfg.get('workflow_sites') or {}


def role_of(agent_type):
    return (agent_type or '').split(':')[-1]


def tokens(s):
    return set(re.findall(r'[a-z0-9]+', (s or '').lower()))


def readout_keys(block):
    """Phase keys one orchestrator Bash call read out."""
    if isinstance(block.get('phase_keys'), list):
        return list(block['phase_keys'])
    cmd = (block.get('input') or {}).get('command') or ''
    if 'spawn-policy' not in cmd:
        return []
    keys = PK_RE.findall(cmd)
    for words in PK_LOOP_RE.findall(cmd):
        keys.extend(w for w in words.split() if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', w))
    out = []
    for k in keys:
        if k not in out:
            out.append(k)
    return out


def issue_refs(block):
    if isinstance(block.get('issues'), list):
        return sorted({int(n) for n in block['issues']})
    inp = block.get('input')
    if not inp:
        return []
    blob = json.dumps(inp, ensure_ascii=False)
    found = set(ISSUE_RE.findall(blob))
    if block.get('name') in ('Workflow', 'Skill'):
        found |= set(WF_ISSUE_RE.findall(blob.replace('\\"', '"')))
    return sorted(int(n) for n in found)


def written_states(name, inp, cwds):
    """Issue numbers whose own .autoflow/issue-{N}.json this tool call writes.

    The working tree's state file only: a relative `.autoflow/…` path, one under a working
    directory of the session, or a shell or script variable assigned to either. A copy written
    under a scratch or temp directory is not the state file. A shell write is a redirect into the
    path, the path as the last argument of mv / cp / install, tee, sed -i, or a script opening it
    for writing.
    """
    roots = '|'.join(re.escape(c.rstrip('/')) + '/' for c in cwds if c)
    if name in EDIT_TOOLS:
        fp = inp.get('file_path') or inp.get('notebook_path') or ''
        m = re.fullmatch(r'(?:%s)?(?:\./)?\.autoflow/issue-(\d+)\.json' % roots, fp) if roots else \
            re.fullmatch(r'(?:\./)?\.autoflow/issue-(\d+)\.json', fp)
        return {int(m.group(1))} if m else set()
    if name != 'Bash':
        return set()
    cmd = inp.get('command') or ''
    out = set()
    q = '["\']?'
    for n in {int(x) for x in STATE_RE.findall(cmd)}:
        own = r'(?:%s)?(?:\./)?\.autoflow/issue-%d\.json' % (roots, n) if roots else r'(?:\./)?\.autoflow/issue-%d\.json' % n
        lit = r'(?:(?<=[\s"\'=(>])|^)' + own
        if not re.search(lit, cmd, re.M):
            continue
        shell_vars = re.findall(r'\b([A-Za-z_]\w*)=["\']?' + own + r'(?=["\']?(?:$|[\s;&|]))', cmd, re.M)
        tgt = '(?:%s)' % '|'.join([lit] + [r'\$\{?%s\}?' % v for v in shell_vars])
        end = r'["\']?(?=$|[\s;&|)])'
        script_vars = re.findall(r'\b([A-Za-z_]\w*)\s*=\s*(?:Path\()?["\']' + own + r'["\']', cmd)
        stgt = '(?:%s)' % '|'.join([r'["\']' + own + r'["\']'] + [r'\b%s\b' % v for v in script_vars])
        if (re.search(r'>>?\s*' + q + tgt + end, cmd, re.M)
                or re.search(r'\b(?:mv|cp|install)\b[^;&|\n]*\s' + q + tgt + r'["\']?\s*(?=$|[;&|)])', cmd, re.M)
                or re.search(r'\btee\b[^;&|\n]*\s' + q + tgt + end, cmd, re.M)
                or re.search(r'\bsed\s+-i\b[^;&|\n]*' + tgt, cmd, re.M)
                or re.search(r'open\(\s*' + stgt + r'\s*,\s*["\'][wa]', cmd)
                or re.search(stgt + r'\)?\.write_text\(', cmd)
                or re.search(r'writeFileSync\(\s*' + stgt, cmd)):
            out.add(n)
    return out


def reviewer_runs(cmd):
    """[repo or None, pr] for each configured-reviewer launch (`codex-review-pr.sh --pr N`) in one command."""
    out = []
    for m in REVIEWER_RE.finditer(cmd or ''):
        pr = re.search(r'--pr\s+["\']?(\d+)', m.group(1))
        repo = re.search(r'--repo\s+["\']?([\w.-]+/[\w.-]+)', m.group(1))
        if pr:
            out.append([repo.group(1) if repo else None, int(pr.group(1))])
    return out


def best_by_description(cands, desc):
    dt_ = tokens(desc)
    scored = []
    for k in cands:
        kt = tokens(k)
        if kt:
            scored.append((len(kt & dt_) / len(kt), k))
    if not scored:
        return None
    top = max(s for s, _ in scored)
    if top <= 0:
        return None
    winners = [k for s, k in scored if s == top]
    return winners[0] if len(winners) == 1 else None


def recover_phase_key(role, desc, pending, pool, policy_keys):
    """(phase_key, method) for one orchestrator spawn. `pending` is consumed by a plain `readout`."""
    def of_role(keys):
        if not policy_keys:
            return list(keys)
        return [k for k in keys if policy_keys.get(k) == role]

    vocab = of_role(policy_keys) if policy_keys else list(pool)
    named = best_by_description(vocab, desc)
    if named:
        return named, 'readout+description' if named in pool else 'description'
    # The label names no key: only a readout not yet spent on an earlier spawn decides.
    fresh = of_role(pending)
    if len(fresh) == 1:
        pending.remove(fresh[0])
        return fresh[0], 'readout'
    if len(vocab) == 1:
        return vocab[0], 'agent-type'
    return None, None


def is_operator_prompt(rec):
    if not is_wake(rec) or rec.get('isMeta') or rec.get('isSidechain'):
        return None
    origin = rec.get('origin')
    if isinstance(origin, dict):
        return origin.get('kind') == 'human'
    if rec.get('promptSource'):
        return rec['promptSource'] == 'typed'
    if isinstance(rec.get('user'), dict):
        return None          # a stripped record keeps no origin: not derivable
    content = (rec.get('message') or {}).get('content')
    text = content if isinstance(content, str) else ''.join(
        p.get('text', '') for p in content or [] if isinstance(p, dict))
    return bool(text) and not text.lstrip().startswith('<')


def sum_usage(calls):
    tot = dict.fromkeys(USAGE_KEYS, 0)
    for c in calls:
        for k in USAGE_KEYS:
            tot[k] += c[k]
    return tot


def span(recs):
    ts = [r.get('timestamp') for r in recs if r.get('timestamp')]
    return (min(ts), max(ts)) if ts else (None, None)


def agent_record(path, meta):
    recs = load(path)
    assistant = [r for r in recs if r.get('type') == 'assistant']
    calls = dedup_calls(assistant)
    start, end = span(recs)
    wakes = []
    idx = wake_indices(recs)
    for j, lo in enumerate(idx):
        hi = idx[j + 1] if j + 1 < len(idx) else len(recs)
        wc = dedup_calls([r for r in recs[lo:hi] if r.get('type') == 'assistant'])
        ws, we = span(recs[lo:hi])
        wakes.append({
            'start': ws, 'end': we, 'calls': len(wc),
            'first_in': context_of(wc[0]) if wc else 0,
            'first_cache_creation': wc[0]['cache_creation'] if wc else 0,
            'rewrite': bool(wc) and j > 0 and is_rewrite(wc[0]),
            'usage': sum_usage(wc),
        })
    tools = {}
    seen = set()
    for r in assistant:
        for b in tool_use_blocks(r):
            if b.get('id') in seen:
                continue
            seen.add(b.get('id'))
            tools[b.get('name') or '?'] = tools.get(b.get('name') or '?', 0) + 1
    models = {}
    for c in calls:
        if c['model']:
            models[c['model']] = models.get(c['model'], 0) + 1
    return {
        'id': os.path.basename(path)[len('agent-'):-len('.jsonl')],
        'role': role_of(meta.get('agentType')),      # collect_session overrides this with the spawn's declaration
        'agent_type': meta.get('agentType'),
        'name': meta.get('name'),
        'model': meta.get('model'),
        'api_models': models,
        'description': (meta.get('description') or '')[:DESC_MAX],
        'tool_use_id': meta.get('toolUseId'),
        'parent': meta.get('parentAgentId'),
        'depth': meta.get('spawnDepth'),
        'workflow_phase': meta.get('workflowPhase'),
        'phase_key': None, 'phase_key_method': None,
        'start': start, 'end': end,
        'calls': len(calls),
        'requests': len({r.get('requestId') for r in assistant if r.get('requestId')}),
        'usage': sum_usage(calls),
        'first_in': context_of(calls[0]) if calls else 0,
        'max_context': max((context_of(c) for c in calls), default=0),
        'rewrites': sum(1 for i, c in enumerate(calls) if i > 0 and is_rewrite(c)),
        'wakes': wakes,
        'tools': tools,
    }


def read_meta(jsonl):
    try:
        with open(jsonl[:-len('.jsonl')] + '.meta.json', encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def session_files(main):
    base = main[:-len('.jsonl')]
    direct = sorted(glob.glob(os.path.join(base, 'subagents', 'agent-*.jsonl')))
    wf = sorted(glob.glob(os.path.join(base, 'subagents', 'workflows', '*', 'agent-*.jsonl')))
    return direct, wf


def source_sizes(main):
    """{relative path: bytes} for every transcript of the session that is present now."""
    base = os.path.dirname(main)
    direct, wf = session_files(main)
    sizes = {}
    for p in [main] + direct + wf:
        try:
            sizes[os.path.relpath(p, base)] = os.path.getsize(p)
        except OSError:
            pass
    return sizes


def grew(sizes, prior):
    """Has any source the prior record was built from grown, or a new one appeared?

    Judged per source, never on the total: an expired agent transcript and a resumed main transcript
    move the total in opposite directions, and neither direction says the record is a superset.
    """
    src = prior.get('source') or {}
    known = src.get('sizes')
    if known is None:                                   # a record older than per-source tracking
        return sum(sizes.values()) > src.get('bytes', 0)
    return any(n > known.get(rel, 0) for rel, n in sizes.items())


def merge_prior(rec, prior):
    """Keep what the prior record holds and the present sources no longer can.

    Transcripts only grow until the harness deletes them, so the better aggregate of one source is
    the one over more calls. An agent whose transcript expired (absent now, or present with fewer
    calls) keeps its prior record; an orchestrator transcript that shrank or vanished keeps the whole
    prior record (None). The merged source sizes are the per-source maxima, so an expired source is
    not mistaken for growth on the next run.
    """
    if len(rec['orchestrator']['calls']) < len((prior.get('orchestrator') or {}).get('calls') or []):
        return None
    now = {a['id']: a for a in rec['agents']}
    for old in prior.get('agents') or []:
        cur = now.get(old['id'])
        if cur is None or cur['calls'] < old['calls']:
            now[old['id']] = dict(old, source_expired=True)
    rec['agents'] = sorted(now.values(), key=lambda a: a['start'] or '')
    top = [a for a in rec['agents'] if not a['workflow'] and not a['parent'] and a['role'].startswith('autoflow-')]
    by_method = {}
    for a in top:
        m = a['phase_key_method'] or 'none'
        by_method[m] = by_method.get(m, 0) + 1
    rec['phase_key_recovery'] = {'spawns': len(top), 'by_method': by_method}
    known = (prior.get('source') or {}).get('sizes') or {}
    sizes = rec['source']['sizes']
    rec['source']['sizes'] = {rel: max(sizes.get(rel, 0), known.get(rel, 0)) for rel in set(sizes) | set(known)}
    rec['source']['bytes'] = max(sum(rec['source']['sizes'].values()), (prior.get('source') or {}).get('bytes', 0))
    return rec


def collect_session(main, policy_keys):
    recs = load(main)
    sid = os.path.basename(main)[:-len('.jsonl')]
    assistant = [r for r in recs if r.get('type') == 'assistant']
    calls = dedup_calls(assistant)
    start, end = span(recs)

    def distinct(field):
        seen = []
        for r in recs:
            v = r.get(field)
            if isinstance(v, str) and v and v not in seen:
                seen.append(v)
        return seen

    # A stripped copy keeps no tool input and no tool result: what is read from them is not derivable.
    stripped = any('user' in r and isinstance(r.get('user'), dict) for r in recs[:200])
    cwds = distinct('cwd')

    # One pass over the orchestrator's tool calls, in order: readouts, spawns, issue references.
    pending, pool = [], []
    spawn_keys = {}                     # tool_use id -> (phase_key, method)
    # The role a spawn declared is the orchestrator's `subagent_type`. The meta file's `agentType`
    # repeats it for an anonymous spawn, but for a named teammate it holds the NAME and no toolUseId,
    # so the declaration is joined by tool_use id and, failing that, by name.
    spawn_decl, spawn_decl_by_name = {}, {}
    refs = []                           # [issue, first_ts, last_ts, count] runs
    state_writes = []
    reviews = []                        # [ts, repo or None, pr] configured-reviewer launches
    asks = set()                        # AskUserQuestion tool_use ids
    tools = {}
    seen = set()
    for r in assistant:
        for b in tool_use_blocks(r):
            if b.get('id') in seen:
                continue
            seen.add(b.get('id'))
            name = b.get('name') or '?'
            if 'input' not in b and b.get('subagent_type') and name not in ('Agent', 'Task'):
                # a stripped copy that flattened the spawn's own `name` over the tool name
                b = dict(b, spawn_name=name)
                name = 'Agent'
            tools[name] = tools.get(name, 0) + 1
            inp = b.get('input') or {}
            ts = r.get('timestamp')
            state_writes += [[ts, n] for n in sorted(written_states(name, inp, cwds))]
            if name == 'Bash':
                keys = readout_keys(b)
                if keys:
                    pending = keys
                    pool = keys + [k for k in pool if k not in keys]
                reviews += [[ts] + run for run in reviewer_runs(inp.get('command'))]
            elif name == 'AskUserQuestion':
                asks.add(b.get('id'))
            elif name in ('Agent', 'Task'):
                role = role_of(inp.get('subagent_type') or b.get('subagent_type'))
                desc = inp.get('description') or b.get('description') or ''
                spawn_keys[b.get('id')] = recover_phase_key(role, desc, pending, pool, policy_keys)
                decl = {'id': b.get('id'), 'role': role}
                spawn_decl[b.get('id')] = decl
                if inp.get('name') or b.get('spawn_name'):
                    spawn_decl_by_name[inp.get('name') or b.get('spawn_name')] = decl
            for n in issue_refs(b):
                if refs and refs[-1][0] == n:
                    refs[-1][2] = ts
                    refs[-1][3] += 1
                else:
                    refs.append([n, ts, ts, 1])

    prompts = []
    answers = []                        # an AskUserQuestion the operator answered; a rejected one is not an answer
    derivable = False
    cost = None
    for r in recs:
        if r.get('type') == 'cost-state':
            # The harness's own running total for the session, restored on resume: the last one stands.
            cost = {'usd': r.get('totalCostUSD'),
                    'by_model': {m: (u or {}).get('costUSD') for m, u in (r.get('modelUsage') or {}).items()},
                    'unknown_model_cost': bool(r.get('hasUnknownModelCost'))}
            continue
        if r.get('type') != 'user':
            continue
        v = is_operator_prompt(r)
        if v is not None:
            derivable = True
        if v:
            prompts.append(r.get('timestamp'))
        content = (r.get('message') or {}).get('content')
        for p in content if isinstance(content, list) else []:
            if (isinstance(p, dict) and p.get('type') == 'tool_result' and p.get('tool_use_id') in asks
                    and not p.get('is_error') and not r.get('toolDenialKind')):
                answers.append(r.get('timestamp'))

    workflows = {}
    for p in sorted(glob.glob(os.path.join(main[:-len('.jsonl')], 'workflows', 'wf_*.json'))):
        try:
            with open(p, encoding='utf-8') as f:
                w = json.load(f)
        except (OSError, ValueError):
            continue
        workflows[w.get('runId') or os.path.basename(p)[:-5]] = {
            'name': w.get('workflowName'), 'start': w.get('timestamp'),
            'duration_ms': w.get('durationMs'), 'status': w.get('status'),
        }

    direct, wf = session_files(main)
    agents = []
    for p in direct:
        a = agent_record(p, read_meta(p))
        a['workflow'] = None
        decl = spawn_decl.get(a['tool_use_id']) or spawn_decl_by_name.get(a['name'] or a['agent_type'])
        if decl:
            a['role'] = decl['role'] or a['role']
            a['phase_key'], a['phase_key_method'] = spawn_keys.get(decl['id'], (None, None))
        agents.append(a)
    for p in wf:
        a = agent_record(p, read_meta(p))
        run = os.path.basename(os.path.dirname(p))
        a['workflow'] = run
        wname = (workflows.get(run) or {}).get('name')
        if wname and a['description']:
            a['phase_key'], a['phase_key_method'] = '%s/%s' % (wname, a['description']), 'workflow-site'
        agents.append(a)
    agents.sort(key=lambda a: a['start'] or '')

    # The policy governs AutoFlow roles only: a research type (Explore, general-purpose) has no key to recover.
    top = [a for a in agents if not a['workflow'] and not a['parent'] and a['role'].startswith('autoflow-')]
    by_method = {}
    for a in top:
        m = a['phase_key_method'] or 'none'
        by_method[m] = by_method.get(m, 0) + 1

    sizes = source_sizes(main)
    nbytes, nfiles = sum(sizes.values()), len(sizes)
    models = {}
    for c in calls:
        if c['model']:
            models[c['model']] = models.get(c['model'], 0) + 1
    return {
        'schema': SCHEMA,
        'session': sid,
        'project_dir': os.path.basename(os.path.dirname(main)),
        'cwd': distinct('cwd'),
        'git_branches': distinct('gitBranch'),
        'versions': distinct('version'),
        'source': {
            'bytes': nbytes, 'files': nfiles, 'records': len(recs), 'sizes': sizes,
            'form': 'stripped' if stripped else 'raw',
        },
        'start': start, 'end': end,
        'operator': {'prompts': prompts if derivable else None, 'answers': None if stripped else answers},
        'cost': cost,
        'orchestrator': {
            'models': models,
            'usage': sum_usage(calls),
            'first_in': context_of(calls[0]) if calls else 0,
            'max_context': max((context_of(c) for c in calls), default=0),
            'rewrites': sum(1 for i, c in enumerate(calls) if i > 0 and is_rewrite(c)),
            'tools': tools,
            'call_columns': ['ts', 'context', 'cache_read', 'cache_creation', 'output', 'input', 'rewrite'],
            'calls': [[c['ts'], context_of(c), c['cache_read'], c['cache_creation'], c['output'], c['input'],
                       int(i > 0 and is_rewrite(c))] for i, c in enumerate(calls)],
        },
        'agents': agents,
        'workflows': workflows,
        'issue_refs': refs,
        'state_writes': None if stripped else state_writes,
        'reviewer_runs': None if stripped else reviews,
        'pr_links': [{'ts': r.get('timestamp'), 'repo': r.get('prRepository'), 'number': r.get('prNumber')}
                     for r in recs if r.get('type') == 'pr-link' and r.get('prNumber')],
        'phase_key_recovery': {'spawns': len(top), 'by_method': by_method},
    }


def write_json(path, obj):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    os.replace(tmp, path)


def covers(rec, prior):
    """Does `rec` hold everything `prior` holds? The test for replacing a record outright.

    Judged on the aggregates, not on file sizes — a raw transcript and its stripped copy differ in
    size and agree in calls: the orchestrator has at least the prior's calls, and every agent of the
    prior record is present with at least its calls.
    """
    if len(rec['orchestrator']['calls']) < len((prior.get('orchestrator') or {}).get('calls') or []):
        return False
    now = {a['id']: a['calls'] for a in rec['agents']}
    return all(now.get(old['id'], -1) >= old['calls'] for old in prior.get('agents') or [])


def collect(args, now):
    out_dir = os.path.join(args.root, 'sessions')
    os.makedirs(out_dir, exist_ok=True)
    policy_keys, _ = load_policy(args.policy)
    counts = {'written': 0, 'updated': 0, 'kept': 0, 'unsettled': 0, 'empty': 0}
    upgrade = {'raw': 0, 'stripped': 0}
    # Every root that holds a session, in the order given: a later root (a preserved copy) is tried
    # when an earlier one no longer holds the whole session.
    found = {}
    for root in args.projects_root:
        for main in sorted(glob.glob(os.path.join(root, '*', '*.jsonl'))):
            sid = os.path.basename(main)[:-len('.jsonl')]
            if not args.session or sid in args.session:
                found.setdefault(sid, []).append(main)
    for sid in sorted(found):
        dest = os.path.join(out_dir, sid + '.json')
        prior = None
        if os.path.exists(dest):
            try:
                with open(dest, encoding='utf-8') as f:
                    prior = json.load(f)
            except (OSError, ValueError):
                prior = None
        if prior is None:
            rec = collect_session(found[sid][0], policy_keys)
        else:
            old_schema = (prior.get('schema') or 0) < SCHEMA
            grown = [m for m in found[sid] if grew(source_sizes(m), prior)]
            if not old_schema and not grown:
                counts['kept'] += 1
                continue
            # A record is REPLACED only by a collection that covers it. A schema upgrade with no
            # covering source leaves the record exactly as it is — still readable, still the older
            # schema, reported as such — and is retried on every later run, grown source or not. On
            # the current schema, a source that grew but no longer covers the record (a resumed
            # session, an expired agent) is merged into it.
            rec = None
            for m in found[sid] if old_schema else grown:
                cand = collect_session(m, policy_keys)
                if covers(cand, prior):
                    rec = cand
                    break
            # The merge is for a record of the CURRENT schema only. Merging into an older record would
            # stamp it with the new schema while the agents it keeps still carry the old one's fields,
            # and the upgrade would never be retried.
            if rec is None and grown and not old_schema:
                rec = merge_prior(collect_session(grown[0], policy_keys), prior)
            if rec is None:
                counts['kept'] += 1
                continue
        last = parse_ts(rec['end'])
        for a in rec['agents']:
            t = parse_ts(a['end'])
            if t and (last is None or t > last):
                last = t
        if last is None:
            counts['empty'] += 1
            continue
        if (now - last).total_seconds() < args.settle_hours * 3600:
            counts['unsettled'] += 1
            continue
        rec['collected_at'] = now.isoformat()
        write_json(dest, rec)
        counts['updated' if prior else 'written'] += 1
        if prior and (prior.get('schema') or 0) < SCHEMA:
            upgrade[rec['source']['form']] += 1
    counts['upgrade'] = upgrade
    return counts


def stale_sessions(root):
    """Session records still on an older schema: their source was gone, or no longer whole."""
    stale = []
    for p in sorted(glob.glob(os.path.join(root, 'sessions', '*.json'))):
        try:
            with open(p, encoding='utf-8') as f:
                if (json.load(f).get('schema') or 0) < SCHEMA:
                    stale.append(os.path.basename(p)[:-len('.json')])
        except (OSError, ValueError):
            pass
    return stale


# --------------------------------------------------------------------------- derive

def repo_of(sess):
    cwds = sess.get('cwd') or []
    return os.path.basename(cwds[0].rstrip('/')) if cwds else sess.get('project_dir') or '?'


def segments_of(sess):
    """Issue segments of one session: [{'issue', 'start', 'end', 'refs'}], non-overlapping, in order."""
    segs = []
    cur = None
    pend = None
    for issue, first, last, count in sess.get('issue_refs') or []:
        if cur and issue == cur['issue']:
            cur['last'] = last
            cur['refs'] += count
            pend = None
            continue
        if pend and pend['issue'] == issue:
            pend['last'] = last
            pend['refs'] += count
        else:
            pend = {'issue': issue, 'start': first, 'last': last, 'refs': count}
        if pend['refs'] >= SWITCH_REFS:
            if cur:
                segs.append(cur)
            cur = pend
            pend = None
    if cur:
        segs.append(cur)
    end_of_session = norm_ts(sess.get('end'))
    spans = [(norm_ts(a.get('start')), norm_ts(a.get('end'))) for a in sess.get('agents') or []]
    for _, a_end in spans:
        if a_end and (not end_of_session or a_end > end_of_session):
            end_of_session = a_end
    for s in segs:
        s['start'], s['last'] = norm_ts(s['start']), norm_ts(s['last'])
    # A segment opens at the operator prompt that started it, not at the first reference that prompt led to.
    prompts = sorted(norm_ts(p) for p in (sess.get('operator') or {}).get('prompts') or [])
    for i, s in enumerate(segs):
        floor = segs[i - 1]['last'] if i else ''
        before = [p for p in prompts if floor < p < s['start']]
        if before:
            s['start'] = before[-1]
    for i, s in enumerate(segs):
        limit = segs[i + 1]['start'] if i + 1 < len(segs) else end_of_session
        tail = parse_ts(s['last'])
        cap = norm_ts((tail + dt.timedelta(seconds=TAIL_S)).isoformat()) if tail else None
        s['end'] = min(x for x in (limit, cap) if x) if (limit or cap) else s['last']
        bounded_by_next = i + 1 < len(segs)
        # an agent spawned inside the segment may outlive its last reference
        for a_start, a_end in spans:
            if a_start and a_end and s['start'] <= a_start < s['end'] < a_end:
                s['end'] = min(a_end, limit) if limit else a_end
        # The boundary with the next segment is exclusive (that record is the next issue's); the
        # session's own last record has no next segment to belong to, so the end includes it.
        s['end_inclusive'] = not (bounded_by_next and s['end'] == limit)
    return segs


def norm_ts(s):
    t = parse_ts(s)
    return t.astimezone(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z' if t else s


def read_labels(path):
    rows = {}
    try:
        with open(path, encoding='utf-8') as f:
            lines = [ln.rstrip('\n') for ln in f if ln.strip() and not ln.startswith('#')]
    except OSError:
        return rows
    for ln in lines:
        c = ln.split('\t')
        if c[0] in ('session-id', 'session_id'):
            continue
        c += [''] * (6 - len(c))
        rows[c[0]] = {'arm': c[1], 'issue': c[2].lstrip('#'), 'operator_minutes': c[3], 'note': c[4],
                      'cost_usd': c[5]}
    return rows


def find_artifacts(archive_root, repo, issue, cwds):
    """The directory holding issue-{N}.json: the archive copy, else a live .autoflow."""
    hits = []
    for pat in ('*__%s' % repo, repo):
        hits += glob.glob(os.path.join(archive_root, pat, 'issue-%s-*' % issue, 'issue-%s.json' % issue))
    if hits:
        return os.path.dirname(sorted(hits)[-1]), 'archive'
    for cwd in cwds:
        p = os.path.join(cwd, '.autoflow', 'issue-%s.json' % issue)
        if os.path.exists(p):
            return os.path.dirname(p), 'live'
    return None, None


def score_avg(scores):
    vals = []
    for v in (scores or {}).values():
        v = v.get('score') if isinstance(v, dict) else v
        if isinstance(v, (int, float)):
            vals.append(v)
    return round(sum(vals) / len(vals), 2) if vals else None


def outcome(adir, issue):
    o = {}
    if not adir:
        return o
    try:
        with open(os.path.join(adir, 'issue-%s.json' % issue), encoding='utf-8') as f:
            st = json.load(f)
    except (OSError, ValueError):
        st = {}
    o['cycle'] = st.get('cycle')
    o['state_date'] = st.get('date')
    o['state_phase'] = st.get('phase')
    o['mode'] = st.get('mode')
    for gate in ('gate_hypothesis_structure', 'gate_hypothesis_cause', 'gate_plan', 'audit', 'gate_quality'):
        o[gate] = score_avg(((st.get('phases') or {}).get(gate) or {}).get('scores'))

    # A number means "counted from its source"; None means "no source to count from". The artifacts
    # were introduced over time — an archive older than the relay transcript, the handoff-ci logs or
    # the review-comment files holds none of them, and a 0 there would read as "no rounds" when it is
    # "not recorded". Each metric is a number only where at least one of ITS source artifacts exists.
    def count(pattern):
        rx = re.compile(pattern)
        return sum(1 for n in os.listdir(adir) if rx.fullmatch(n)) or None

    pre = r'issue-%s-(?:c\d+-)?' % issue
    o['gate_plan_evals'] = count(pre + r'gate-plan(?:-\d+)?\.md')
    o['audit_evals'] = count(pre + r'audit(?:-\d+)?\.md')
    o['gate_quality_evals'] = count(pre + r'gate-quality(?:-\d+)?\.md')
    o['archive_reviewer_rounds'] = count(pre + r'review-comment-.*\.md')
    # One transcript per cycle's ARCHITECT entry (a later cycle's is preserved as issue-N-cC-*): each
    # discussion is its opening round plus one per Brief, so the rounds are counted per file.
    turns = rounds = 0
    for p in glob.glob(os.path.join(adir, 'issue-%s-*architect-transcript.md' % issue)):
        t = b = 0
        with open(p, encoding='utf-8') as f:
            for ln in f:
                t += ln.startswith('### Turn ')
                b += ln.startswith('### Brief')
        turns += t
        rounds += (b + 1) if t else 0
    transcripts = glob.glob(os.path.join(adir, 'issue-%s-*architect-transcript.md' % issue))
    o['architect_turns'] = turns if transcripts else None
    o['architect_rounds'] = rounds if transcripts else None
    heads = []
    ledgers = sorted(set(glob.glob(os.path.join(adir, 'issue-%s-*ledger.md' % issue)) +
                         glob.glob(os.path.join(adir, 'issue-%s-ledger.md' % issue))))
    for p in ledgers:
        with open(p, encoding='utf-8') as f:
            heads += [ln.strip() for ln in f if ln.startswith('## ')]
    heads = list(dict.fromkeys(heads))
    # With a ledger present, 0 is a finding: the cycle recorded its decisions and none was an auto-fix.
    o['ledger_entries'] = len(heads) if ledgers else None
    o['review_autofix'] = sum(1 for h in heads if h.endswith('[review-autofix]')) if ledgers else None
    o['gate_autofix'] = sum(1 for h in heads if h.endswith('[gate-autofix]')) if ledgers else None
    o['ac_decisions'] = sum(1 for h in heads if h.endswith('[ac-decision]')) if ledgers else None
    # A CI round is judged by the `exit=<n>` line confirm-ci-green.sh's caller left in the log, never by
    # its position: a later log is often a green re-confirmation. 12 is the red build; any other
    # non-zero exit (not mergeable, no check published, no verdict) is a round that did not fail the
    # build; a log with no exit line is undetermined and counted as nothing else.
    ci_logs = glob.glob(os.path.join(adir, 'issue-%s-local' % issue, 'handoff-ci-*.log'))
    for k in ('archive_ci_rounds', 'archive_ci_fail_rounds', 'archive_ci_other_rounds', 'archive_ci_undetermined'):
        o[k] = 0 if ci_logs else None
    for p in ci_logs:
        with open(p, encoding='utf-8', errors='replace') as f:
            exits = re.findall(r'^exit=(\d+)\s*$', f.read(), re.M)
        if not exits:
            o['archive_ci_undetermined'] += 1
            continue
        o['archive_ci_rounds'] += 1
        code = int(exits[-1])
        o['archive_ci_fail_rounds'] += code == 12
        o['archive_ci_other_rounds'] += code not in (0, 12)
    markers = []
    for p in glob.glob(os.path.join(adir, 'issue-%s-phases.jsonl' % issue)):
        with open(p, encoding='utf-8') as f:
            for ln in f:
                try:
                    markers.append(json.loads(ln))
                except ValueError:
                    pass
    o['phase_markers'] = [[m.get('ts'), m.get('phase'), m.get('event')] for m in markers if m.get('ts')]
    return o


def marker_phase(markers, ts):
    cur = None
    for mts, phase, event in sorted(markers):
        if norm_ts(mts) > ts:
            break
        cur = phase if event == 'enter' else None
    return cur


# --------------------------------------------------------------------------- GitHub

def gh_lines(args):
    """One JSON value per output line of `gh api … --jq '… | tojson'`."""
    r = subprocess.run(['gh', 'api'] + args, capture_output=True, text=True, timeout=120)
    if r.returncode:
        raise RuntimeError((r.stderr or r.stdout).strip()[:200])
    return [json.loads(ln) for ln in r.stdout.splitlines() if ln.strip()]


def fetch_pr(repo, number):
    """What the outcome needs from one PR: its state, its comments (no body — only whether a comment
    has the configured reviewer's output format) and the workflow runs of its head branch, each run
    with every attempt's conclusion."""
    pr = gh_lines(['repos/%s/pulls/%d' % (repo, number), '--jq',
                   '{state, merged_at, created_at, closed_at, head_ref: .head.ref} | tojson'])[0]
    comments = gh_lines(['--paginate', 'repos/%s/issues/%d/comments' % (repo, number), '--jq',
                         '.[] | {id, created_at, author: .user.login, '
                         'review: ((.body // "") | test("\\\\A\\\\s*# Review Summary\\\\b"))} | tojson'])
    runs = gh_lines(['--paginate', '-X', 'GET', 'repos/%s/actions/runs' % repo, '-f', 'branch=%s' % pr['head_ref'],
                     '-f', 'per_page=100', '--jq',
                     '.workflow_runs[] | {id, workflow: .name, event, head_sha, run_attempt, created_at, status, '
                     'conclusion} | tojson'])
    # The head branch's runs from ten minutes before the PR opened (the push that opened it) to its close.
    lo = parse_ts(pr['created_at']) - dt.timedelta(minutes=10)
    hi = parse_ts(pr['closed_at']) if pr.get('closed_at') else None
    kept = []
    for run in runs:
        t = parse_ts(run['created_at'])
        if t < lo or (hi and t > hi):
            continue
        attempts = []
        for n in range(1, (run.get('run_attempt') or 1)):
            a = gh_lines(['repos/%s/actions/runs/%d/attempts/%d' % (repo, run['id'], n), '--jq',
                          '{status, conclusion} | tojson'])[0]
            attempts.append([n, a.get('status'), a.get('conclusion')])
        attempts.append([run.get('run_attempt') or 1, run.get('status'), run.get('conclusion')])
        kept.append({'id': run['id'], 'workflow': run.get('workflow'), 'event': run.get('event'),
                     'head_sha': run['head_sha'], 'created_at': run['created_at'], 'attempts': attempts})
    return {'repo': repo, 'number': number, 'pr': pr, 'comments': comments, 'runs': kept}


def pr_cache_path(root, repo, number):
    return os.path.join(root, 'github', '%s__%d.json' % (repo.replace('/', '__'), number))


def load_pr(root, repo, number, fetch):
    """The cached PR record; with `fetch`, (re)fetched unless the cache holds a closed PR."""
    path = pr_cache_path(root, repo, number)
    cached = None
    try:
        with open(path, encoding='utf-8') as f:
            cached = json.load(f)
    except (OSError, ValueError):
        pass
    if fetch and (cached is None or (cached.get('pr') or {}).get('state') == 'open'):
        try:
            rec = fetch_pr(repo, number)
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError, IndexError, KeyError) as e:
            print('gh: %s#%d not fetched (%s)' % (repo, number, e), file=sys.stderr)
            return cached
        rec['fetched_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_json(path, rec)
        return rec
    return cached


def pr_state(rec):
    pr = (rec or {}).get('pr') or {}
    if pr.get('merged_at'):
        return 'MERGED'
    return (pr.get('state') or '').upper() or None


def ci_heads(rec):
    """One entry per head SHA of the PR's runs, in the order CI first saw it.

    A head is a CI round when at least one of its attempts ran — a head whose every run was
    cancelled or skipped was not evaluated. It is a failed round when an attempt failed; a cancelled
    attempt is not a failure. A rerun is an attempt past the first of the same run: it evaluates the
    same head again and opens no round of its own.
    """
    heads = {}
    for run in sorted(rec.get('runs') or [], key=lambda r: r['created_at']):
        h = heads.setdefault(run['head_sha'], {'sha': run['head_sha'], 'first': run['created_at'], 'runs': 0,
                                               'attempts': 0, 'ran': 0, 'failed': 0, 'cancelled': 0, 'reruns': 0})
        h['runs'] += 1
        h['reruns'] += len(run['attempts']) - 1
        for _, status, conclusion in run['attempts']:
            h['attempts'] += 1
            h['ran'] += conclusion not in CI_NOT_RUN
            h['failed'] += conclusion in CI_FAILED
            h['cancelled'] += conclusion == 'cancelled'
    return list(heads.values())


def reviewer_matches(rec, launches):
    """Comments of the configured reviewer on this PR: a comment in the reviewer's output format posted
    after a reviewer launch for this PR, the first such comment per launch, before the next launch and
    within REVIEW_WINDOW_S. A comment in that format that no launch of the row's own sessions accounts
    for — another review run elsewhere, an evaluator's comparison — is not the configured reviewer's."""
    revs = sorted((parse_ts(c['created_at']), c['id']) for c in rec.get('comments') or [] if c.get('review'))
    times = sorted(parse_ts(t) for t in launches if parse_ts(t))
    used = []
    for i, t in enumerate(times):
        hi = t + dt.timedelta(seconds=REVIEW_WINDOW_S)
        if i + 1 < len(times):
            hi = min(hi, times[i + 1])
        for ct, cid in revs:
            if cid not in used and t <= ct < hi:
                used.append(cid)
                break
    return used, len(revs)


def github_outcome(it, gh):
    """The outcome read from the row's own PRs — the same for either arm. Per PR in `github`, summed
    over the row's PRs in `o`; a row with no PR, or a PR not fetched, has no source: None."""
    per = {}
    for k in it['prs']:
        rec = gh.get(k)
        if not rec:
            continue
        repo, number = rec['repo'], rec['number']
        launches = [ts for ts, r, n in it['reviewer_runs'] if n == number and (r is None or r.lower() == repo.lower())]
        matched, review_format = reviewer_matches(rec, launches)
        per[k] = {'state': pr_state(rec), 'reviewer_launches': len(launches),
                  'reviewer_rounds': len(matched) if it['reviewer_runs_known'] else None,
                  'review_format_comments': review_format, 'ci_heads': ci_heads(rec)}
    whole = bool(it['prs']) and len(per) == len(it['prs'])
    heads = [h for v in per.values() for h in v['ci_heads']]
    o = {
        'reviewer_rounds': sum(v['reviewer_rounds'] for v in per.values()) if whole and it['reviewer_runs_known'] else None,
        'ci_rounds': sum(1 for h in heads if h['ran']) if whole else None,
        'ci_fail_rounds': sum(1 for h in heads if h['failed']) if whole else None,
        'ci_cancelled': sum(h['cancelled'] for h in heads) if whole else None,
        'ci_reruns': sum(h['reruns'] for h in heads) if whole else None,
    }
    return o, per


def derive(args):
    labels = read_labels(os.path.join(args.root, 'labels.tsv'))
    issues = {}
    unattributed = []
    sess_cost = {}
    for path in sorted(glob.glob(os.path.join(args.root, 'sessions', '*.json'))):
        try:
            with open(path, encoding='utf-8') as f:
                sess = json.load(f)
        except (OSError, ValueError):
            continue
        repo = repo_of(sess)
        label = labels.get(sess['session'])
        segs = segments_of(sess)
        if not segs and label and label['issue']:
            segs = [{'issue': int(label['issue']), 'start': norm_ts(sess['start']), 'end': '9999', 'refs': 0}]
        calls = sess['orchestrator']['calls']
        prompts = sess['operator']['prompts']
        answers = sess['operator'].get('answers')
        sess_cost[sess['session']] = sess.get('cost')
        # The issues whose own state file the session wrote. A record of an older schema — its transcript
        # expired before it could be re-read — or a stripped copy cannot tell: None.
        wrote = ({n for _, n in sess['state_writes']}
                 if (sess.get('schema') or 0) >= 3 and sess.get('state_writes') is not None else None)
        taken_calls = taken_agents = 0
        for s in segs:
            # The label's own link to this segment, kept explicitly: the session is labelled, and the label
            # names this issue or none. Neither the arm's value nor the reference count stands in for it.
            linked = bool(label) and label['issue'] in ('', str(s['issue']))
            # A session performs an issue when a label names it or it wrote the issue's state file. Any
            # other session that referenced the issue's files only read them: its segment is a reference
            # row of its own, never merged into the issue's cycle row. None: the record cannot tell.
            performed = True if linked else (s['issue'] in wrote if wrote is not None else None)
            # Two arms of one issue are two rows: the comparison is the point of the label.
            arm = (label['arm'] if linked else '') or ('A' if s['refs'] and performed is not False else '')
            key = ('%s#%s' % (repo, s['issue']) + ('' if arm in ('', 'A') else '@' + arm)
                   + ('~ref' if performed is False else ''))
            it = issues.setdefault(key, {
                'key': key, 'repo': repo, 'issue': s['issue'], 'arm': arm, 'reference': performed is False,
                'operator_minutes': '', 'operator_cost_usd': '', 'notes': [], 'labelled': [],
                'stale_schema_sessions': [], 'label_sessions': [], 'write_sessions': [], 'legacy_sessions': [],
                'orch_base': 0,
                'sessions': [], 'segments': [], 'cwd': [], 'orch_calls': [], 'agents': [], 'pr_links': [],
                'operator_prompts': 0, 'operator_prompts_known': True,
                'operator_answers': 0, 'operator_answers_known': True,
                'reviewer_runs': [], 'reviewer_runs_known': True,
            })
            inside = lambda ts: ts is not None and (  # noqa: E731
                s['start'] <= norm_ts(ts) < s['end'] or (s.get('end_inclusive') and norm_ts(ts) == s['end']))
            if sess['session'] not in it['sessions']:
                it['sessions'].append(sess['session'])
                if (sess.get('schema') or 0) < SCHEMA:
                    it['stale_schema_sessions'].append(sess['session'])
            it['cwd'] = list(dict.fromkeys(it['cwd'] + (sess.get('cwd') or [])))
            if performed and not linked and sess['session'] not in it['write_sessions']:
                it['write_sessions'].append(sess['session'])
            if performed is None and sess['session'] not in it['legacy_sessions']:
                it['legacy_sessions'].append(sess['session'])
            # A label is per session: its minutes and cost are summed over the issue's sessions, once per
            # session however many segments that session has in the issue.
            if linked and sess['session'] not in it['label_sessions']:
                it['label_sessions'].append(sess['session'])
            if linked and sess['session'] not in it['labelled']:
                it['labelled'].append(sess['session'])
                for field, col in (('operator_minutes', 'operator_minutes'), ('operator_cost_usd', 'cost_usd')):
                    try:
                        it[field] = round((it[field] or 0) + float(label[col]), 2)
                    except ValueError:
                        pass                # blank or not a number: nothing to add
                if label['note']:
                    it['notes'].append((s['start'], label['note']))
            seg_calls = [c for c in calls if inside(c[0])]
            seg_agents = [a for a in sess['agents'] if inside(a.get('start'))]
            # Base context is a property of the segment: the context it opened with, paid on each of its
            # calls. Summed per segment, so it does not depend on which session file is read first.
            if seg_calls:
                it['orch_base'] += len(seg_calls) * seg_calls[0][1]
            taken_calls += len(seg_calls)
            taken_agents += len(seg_agents)
            it['segments'].append({'session': sess['session'], 'start': s['start'],
                                   'end': s['end'] if s['end'] != '9999' else norm_ts(sess['end']),
                                   'refs': s['refs']})
            it['orch_calls'] += [[norm_ts(c[0])] + c[1:] for c in seg_calls]
            it['agents'] += [dict(a, session=sess['session']) for a in seg_agents]
            it['pr_links'] += [p for p in sess.get('pr_links') or [] if inside(p.get('ts'))]
            if prompts is None:
                it['operator_prompts_known'] = False
            else:
                it['operator_prompts'] += sum(1 for p in prompts if inside(p))
            if answers is None:
                it['operator_answers_known'] = False
            else:
                it['operator_answers'] += sum(1 for a in answers if inside(a))
            if sess.get('reviewer_runs') is None:
                it['reviewer_runs_known'] = False
            else:
                it['reviewer_runs'] += [r for r in sess['reviewer_runs'] if inside(r[0])]
        rest = len(calls) - taken_calls
        if rest or len(sess['agents']) - taken_agents:
            unattributed.append({'session': sess['session'], 'repo': repo, 'orch_calls': rest,
                                 'agents': len(sess['agents']) - taken_agents})

    rows = []
    for key in sorted(issues, key=lambda k: (issues[k]['repo'], issues[k]['issue'])):
        it = issues[key]
        it['orch_calls'].sort(key=lambda c: c[0])
        it['agents'].sort(key=lambda a: norm_ts(a.get('start')) or '')
        it['segments'].sort(key=lambda g: g['start'])
        it['note'] = '; '.join(dict.fromkeys(n for _, n in sorted(it.pop('notes'))))   # in session order
        del it['labelled']
        # The .autoflow artifacts are the AutoFlow arm's. Another arm of the same issue has none of its
        # own, and borrowing these would put arm A's scores and rounds on arm B's row; a reference row
        # only read them.
        adir, where = (find_artifacts(args.archive_root, it['repo'], it['issue'], it['cwd'])
                       if it['arm'] in ('', 'A') and not it['reference'] else (None, None))
        it['outcome'] = outcome(adir, it['issue'])
        it['outcome']['artifacts'] = where
        for a in it['agents']:
            a['phase_marker'] = marker_phase(it['outcome'].get('phase_markers') or [], norm_ts(a['start'])) \
                if it['outcome'].get('phase_markers') else None
        prs = {}
        for p in it['pr_links']:
            prs['%s#%s' % (p['repo'], p['number'])] = p
        it['prs'] = sorted(prs)
        del it['pr_links']

        orch = dict.fromkeys(USAGE_KEYS, 0)
        for c in it['orch_calls']:
            orch['cache_read'] += c[2]
            orch['cache_creation'] += c[3]
            orch['output'] += c[4]
            orch['input'] += c[5]
        ag = dict.fromkeys(USAGE_KEYS, 0)
        gate = 0
        for a in it['agents']:
            for k in USAGE_KEYS:
                ag[k] += a['usage'][k]
            if a['role'] == 'autoflow-evaluator':
                gate += sum(a['usage'].values())
        total = sum(orch.values()) + sum(ag.values())
        wall = sum((parse_ts(s['end']) - parse_ts(s['start'])).total_seconds() for s in it['segments']
                   if parse_ts(s['end']) and parse_ts(s['start']))
        top = [a for a in it['agents'] if not a['workflow'] and not a['parent'] and a['role'].startswith('autoflow-')]
        it['totals'] = {
            'orchestrator': orch, 'agents': ag, 'tokens': total,
            'orch_base': min(it.pop('orch_base'), orch['input'] + orch['cache_read'] + orch['cache_creation']),
            'orch_share': round(sum(orch.values()) / total, 4) if total else None,
            'gate_share': round(gate / total, 4) if total else None,
            'wall_h': round(wall / 3600, 2),
            'max_orch_context': max((c[1] for c in it['orch_calls']), default=0),
            'rewrites': sum(c[6] for c in it['orch_calls']) + sum(a['rewrites'] for a in it['agents']),
            'spawns': len(top),
            'phase_keys_recovered': sum(1 for a in top if a['phase_key']),
        }
        # A row is a cycle when one of its sessions performed the issue: a label names it (the other arm
        # of a comparison has no state by construction and is never classified away), or the session
        # wrote the issue's own state file. A reference row — sessions that only read the issue's files —
        # is never a cycle. A session whose record cannot tell a state write (an older schema, a stripped
        # copy) is classified as before: an AutoFlow role spawn in the row, or the issue's state `date`
        # within a day of the row's segments.
        by_label = bool(it['label_sessions'])
        by_write = bool(it['write_sessions'])
        role_spawns = sum(1 for a in it['agents'] if (a.get('role') or '').startswith('autoflow-'))
        own_state = False
        day = parse_ts((it['outcome'].get('state_date') or '') + 'T12:00:00+00:00')
        if it['outcome'].get('cycle') is not None and day:
            own_state = any(parse_ts(g['start']) - dt.timedelta(days=1) <= day <= parse_ts(g['end']) + dt.timedelta(days=1)
                            for g in it['segments'] if parse_ts(g['start']) and parse_ts(g['end']))
        legacy = ('role-spawn' if role_spawns else 'state-date' if own_state else None) if it['legacy_sessions'] else None
        it['kind_basis'] = 'label' if by_label else 'state-write' if by_write else legacy
        it['kind'] = 'cycle' if it['kind_basis'] else 'non-cycle'
        # The GitHub outcome is a cycle row's own PRs'; a reference or non-cycle row carries none.
        gh = {k: load_pr(args.root, prs[k]['repo'], prs[k]['number'], args.gh) for k in it['prs']} \
            if it['kind'] == 'cycle' else {}
        it['pr_states'] = {k: pr_state(r) for k, r in gh.items() if r}
        o_gh, it['github'] = github_outcome(it, gh) if it['kind'] == 'cycle' else ({}, {})
        it['outcome'].update(o_gh)
        it['operator_decisions'] = (it['operator_prompts'] + it['operator_answers']
                                    if it['operator_prompts_known'] and it['operator_answers_known'] else None)
        del it['reviewer_runs']

    # The harness's own session cost (`cost-state`) is a session total, not split by segment: it is a
    # cycle row's only when every session of the row performed this row and no other cycle row.
    cycle_rows_of = {}
    for it in issues.values():
        if it['kind'] == 'cycle':
            for sid in it['sessions']:
                cycle_rows_of.setdefault(sid, []).append(it['key'])
    for key in sorted(issues, key=lambda k: (issues[k]['repo'], issues[k]['issue'], k)):
        it = issues[key]
        costs = [sess_cost.get(sid) for sid in it['sessions']]
        whole = it['kind'] == 'cycle' and all(cycle_rows_of.get(sid) == [key] for sid in it['sessions'])
        it['cost_usd'] = (round(sum(c['usd'] for c in costs), 2)
                          if whole and costs and all(c and isinstance(c.get('usd'), (int, float)) for c in costs) else None)
        o, t = it['outcome'], it['totals']
        orch, ag = t['orchestrator'], t['agents']
        rows.append([
            it['repo'], it['issue'], it['arm'], it['kind'], it['kind_basis'], len(it['sessions']),
            len(it['stale_schema_sessions']),
            min(s['start'] for s in it['segments']), max(s['end'] for s in it['segments']), t['wall_h'],
            it['operator_prompts'] if it['operator_prompts_known'] else '',
            it['operator_answers'] if it['operator_answers_known'] else '',
            it['operator_decisions'],
            ('%g' % it['operator_minutes']) if it['operator_minutes'] != '' else '',
            it['cost_usd'], ('%g' % it['operator_cost_usd']) if it['operator_cost_usd'] != '' else '',
            len(it['orch_calls']), orch['cache_read'], orch['cache_creation'], orch['output'],
            len(it['agents']), ag['cache_read'], ag['cache_creation'], ag['output'],
            t['tokens'], t['orch_share'], t['gate_share'], t['max_orch_context'], t['rewrites'],
            t['spawns'], t['phase_keys_recovered'],
            o.get('cycle'), o.get('state_phase'), o.get('gate_hypothesis_structure'), o.get('gate_hypothesis_cause'),
            o.get('gate_plan'), o.get('audit'), o.get('gate_quality'),
            o.get('architect_turns'), o.get('architect_rounds'), o.get('gate_plan_evals'), o.get('audit_evals'),
            o.get('gate_quality_evals'), o.get('review_autofix'), o.get('gate_autofix'),
            o.get('reviewer_rounds'), o.get('ci_rounds'), o.get('ci_fail_rounds'), o.get('ci_cancelled'),
            o.get('ci_reruns'),
            o.get('archive_reviewer_rounds'), o.get('archive_ci_rounds'), o.get('archive_ci_fail_rounds'),
            o.get('archive_ci_other_rounds'), o.get('archive_ci_undetermined'),
            ' '.join(it['prs']), ' '.join('%s=%s' % kv for kv in sorted(it['pr_states'].items()) if kv[1]),
            it['note'],
        ])
    header = [
        'repo', 'issue', 'arm', 'kind', 'kind_basis', 'sessions', 'stale_schema_sessions', 'start', 'end', 'wall_h',
        'operator_prompts', 'operator_answers', 'operator_decisions', 'operator_minutes', 'cost_usd', 'operator_cost_usd',
        'orch_calls', 'orch_cache_read', 'orch_cache_creation', 'orch_output',
        'agents', 'agent_cache_read', 'agent_cache_creation', 'agent_output',
        'tokens', 'orch_share', 'gate_share', 'max_orch_context', 'rewrites', 'spawns', 'phase_keys_recovered',
        'cycle', 'state_phase', 'gate_hypothesis_structure', 'gate_hypothesis_cause', 'gate_plan', 'audit',
        'gate_quality', 'architect_turns', 'architect_rounds', 'gate_plan_evals', 'audit_evals',
        'gate_quality_evals', 'review_autofix', 'gate_autofix',
        'reviewer_rounds', 'ci_rounds', 'ci_fail_rounds', 'ci_cancelled', 'ci_reruns',
        'archive_reviewer_rounds', 'archive_ci_rounds', 'archive_ci_fail_rounds', 'archive_ci_other_rounds',
        'archive_ci_undetermined',
        'prs', 'pr_states', 'note',
    ]
    tmp = os.path.join(args.root, 'issues.tsv.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write('\t'.join(header) + '\n')
        for r in rows:
            f.write('\t'.join('' if v is None else str(v).replace('\t', ' ') for v in r) + '\n')
    os.replace(tmp, os.path.join(args.root, 'issues.tsv'))
    write_json(os.path.join(args.root, 'issues.json'),
               {'schema': SCHEMA, 'issues': [issues[k] for k in sorted(issues)], 'unattributed': unattributed})
    return len(rows), unattributed


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    archive = os.environ.get('AUTOFLOW_ARCHIVE_ROOT') or os.path.join(os.path.expanduser('~'), '.autoflow')
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--projects-root', action='append',
                    help='transcript root (repeatable; first hit of a session id wins). '
                         'Default: ~/.claude/projects')
    ap.add_argument('--archive-root', default=archive, help='the .autoflow archive root (outcome join)')
    ap.add_argument('--root', help='metrics store. Default: <archive-root>/_metrics')
    ap.add_argument('--settle-hours', type=float, default=12.0,
                    help='a session whose last record is younger than this is not finalized')
    ap.add_argument('--now', help='clock override (ISO 8601), for tests')
    ap.add_argument('--session', action='append', help='collect only this session id (repeatable)')
    ap.add_argument('--policy', default=os.path.join(here, '..', '..', '.claude', 'autoflow', 'spawn-policy.json'))
    ap.add_argument('--no-collect', action='store_true')
    ap.add_argument('--no-derive', action='store_true')
    ap.add_argument('--gh', action='store_true',
                    help='fetch each cycle row\'s linked PRs (state, comments, workflow runs) with the gh CLI '
                         'into <root>/github/ (network); without it the cached copies are read')
    args = ap.parse_args(argv)
    args.projects_root = args.projects_root or [os.path.join(os.path.expanduser('~'), '.claude', 'projects')]
    args.root = args.root or os.path.join(args.archive_root, '_metrics')
    now = parse_ts(args.now) if args.now else dt.datetime.now(dt.timezone.utc)
    if now is None:
        ap.error('--now is not ISO 8601')
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)
    os.makedirs(args.root, exist_ok=True)

    if not args.no_collect:
        c = collect(args, now)
        print('collect: written %(written)d, updated %(updated)d, kept %(kept)d, '
              'unsettled %(unsettled)d, empty %(empty)d' % c)
        spawns = recovered = 0
        methods = {}
        for p in glob.glob(os.path.join(args.root, 'sessions', '*.json')):
            with open(p, encoding='utf-8') as f:
                r = json.load(f).get('phase_key_recovery') or {}
            spawns += r.get('spawns', 0)
            for m, n in (r.get('by_method') or {}).items():
                methods[m] = methods.get(m, 0) + n
                recovered += n if m != 'none' else 0
        if spawns:
            print('phase-key recovery: %d / %d orchestrator spawns (%.1f%%) — %s' % (
                recovered, spawns, 100.0 * recovered / spawns,
                ', '.join('%s %d' % kv for kv in sorted(methods.items()))))
        stale = stale_sessions(args.root)
        if stale or sum(c['upgrade'].values()):
            print('schema %d: upgraded %d from the transcripts, %d from a preserved copy; %d kept on an older schema'
                  % (SCHEMA, c['upgrade']['raw'], c['upgrade']['stripped'], len(stale)))
    if not args.no_derive:
        n, un = derive(args)
        print('derive: %d issue rows -> %s' % (n, os.path.join(args.root, 'issues.tsv')))
        if un:
            print('unattributed: %d sessions hold calls or agents outside every issue segment' % len(un))
    return 0


if __name__ == '__main__':
    sys.exit(main())
