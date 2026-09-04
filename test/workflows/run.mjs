// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// Regression harness for the deliberation workflow scripts (issue #153).
//
// These tests lock the pure control-flow logic of the reference workflows — the
// ARCHITECT relay (topic + transcript threading, the two-consecutive-done
// termination, the Report and Record calls, the ledger condition), the VERIFY
// next_action mapping, the spawn-policy fail-closed guards, missing-response
// handling, and the arg guards — by running each script against a mock runtime.
// They do NOT exercise a live Claude Code Workflow runtime (that is the
// operator-side smoke scenario in docs/teammate-contracts.md > Verification
// scenarios); they catch the logic-bug class found in PR #197 review without
// spawning real agents.
//
// Run: node test/workflows/run.mjs
//
// The mock passes the runtime globals (args, phase, parallel, agent, console) as
// function parameters. A script that references a workflow global NOT in this set
// (e.g. a stray `log`) throws a ReferenceError here — which catches that ABI-mismatch
// class. Caveat: an AsyncFunction body can still see Node ambient globals (process,
// Buffer, globalThis, ...), so this guard does not prove the script is free of *every*
// non-workflow global — only that it does not reference an undefined one. The scripts
// use solely the injected globals; a stricter `vm`-sandbox check is a possible follow-up.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

function load(rel) {
  const src = readFileSync(join(root, rel), 'utf8').replace(/^export const meta/m, 'const meta')
  return new AsyncFunction('args', 'phase', 'parallel', 'agent', 'console', src)
}

const arch = load('.claude/workflows/architect-deliberation.js')
const verify = load('.claude/workflows/verify-cause-branch.js')

const mockConsole = { log() {} }
const phase = () => {}
// Mirror the documented parallel(): concurrent, and a thunk that throws resolves to null.
const parallel = (thunks) => Promise.all(thunks.map((t) => Promise.resolve().then(t).catch(() => null)))

// Spawn-policy load default (issue #150 / #151 regression): both workflow scripts open with an
// unlabelled `policy-load` transcription call (no `site()` spread — it is the one bootstrap
// exemption, see architect-deliberation.js > Spawn policy load) that every OTHER agent() call
// depends on via `site(key)`. A scenario's own `responder` never sees this label unless it opts in
// via the third `policyLoad` arg below; by default every scenario answers it with the REAL policy
// file's verbatim content, exactly as a working transcription sub-agent would, so a scenario that
// is not about the policy at all does not have to stub a call it knows nothing about. The handful
// of scenarios that exercise the load failure itself (absent / malformed / agent-missing) pass an
// explicit override.
const REAL_POLICY_CONTENT = readFileSync(join(root, '.claude/autoflow/spawn-policy.json'), 'utf8')
const DEFAULT_POLICY_LOAD_RESPONSE = { found: true, content: REAL_POLICY_CONTENT }

function makeAgent(responder, calls, policyLoad = DEFAULT_POLICY_LOAD_RESPONSE) {
  return async (prompt, opts = {}) => {
    const label = opts.label || ''
    // `opts` is recorded verbatim (issue #150 cycle 2) so a scenario can assert what a call site's
    // site(key) spread actually produced -- in particular whether an `effort` key reached the
    // spawn opts at all, which is the observable the sentinel-from-config legs need.
    calls.push({ label, prompt, opts })
    if (label === 'policy-load') return typeof policyLoad === 'function' ? policyLoad() : policyLoad
    return responder(label, prompt)
  }
}

// DCR-1 (issue #14, c2): mirror the SAME catch-path three-tier prose-salvage rule
// the scripts adopt (tier 1 hash /#(\d+)/, tier 2 issue-anchored /\bissue\s+#?(\d+)\b/i,
// tier 3 bare /(\d+)/ adopted ONLY when exactly one number is present -- otherwise
// ambiguous -> {} -> the loud-fail guard fires) so a prose-args fixture lands at the
// id the script itself resolves. This is the single source of the resolution rule at
// test time, and the source-parity guard below pins its two literals against the
// scripts'. Issue #166 removed the resume path, so the mirror salvages the issue number
// and nothing else -- `brief` is a JSON/object-only argument and is deliberately NOT
// salvaged from prose, which the arg-surface tests assert against the script.
function extractArgv(args) {
  const argv = typeof args === 'string'
    ? (() => {
        try { return JSON.parse(args) }
        catch (_) {
          const hash = args.match(/#(\d+)/)
          const labeled = hash ? null : args.match(/\bissue\s+#?(\d+)\b/i)
          const all = hash || labeled ? null : args.match(/\d+/g)
          const issue = hash ? hash[1]
            : labeled ? labeled[1]
            : (all && all.length === 1) ? all[0]
            : null
          const salvaged = {}
          if (issue) salvaged.issue = issue
          return salvaged
        }
      })()
    : (args || {})
  return { issue: argv.issue, brief: argv.brief }
}

// The three documents the deliberation's scribe writes, in the order the script returns them.
// Nothing on disk is involved: the issue #166 script touches no filesystem, so these are the
// expected VALUES of `result.artifacts`, not fixtures to create and remove.
function artifactPaths(issue) {
  return [
    `.autoflow/issue-${issue}-feature-design.md`,
    `.autoflow/issue-${issue}-verification-design.md`,
    `.autoflow/issue-${issue}-architect-report.md`,
  ]
}

const runArch = (args, responder, opts = {}) => {
  const calls = []
  return arch(args, phase, parallel, makeAgent(responder, calls, opts.policyLoad), mockConsole)
    .then((result) => ({ result, calls }))
}
const runVerify = (args, responder, opts = {}) => {
  const calls = []
  return verify(args, phase, parallel, makeAgent(responder, calls, opts.policyLoad), mockConsole).then((result) => ({ result, calls }))
}
// Issue #150 cycle 2, `required-row-omission-throws` / `fail-closed-precedes-work`: unlike runVerify
// above, this variant does NOT let a rejection propagate past the call -- it captures `calls` even
// when the run throws at the boundary, which the plain `assert.rejects(() => runVerify(...))` idiom
// used by the four pre-existing load-failure scenarios cannot do (the `calls` array closed over
// inside runVerify's promise chain is unreachable once that promise rejects).
const runVerifyRaw = async (args, responder, opts = {}) => {
  const calls = []
  let result = null
  let error = null
  try {
    result = await verify(args, phase, parallel, makeAgent(responder, calls, opts.policyLoad), mockConsole)
  } catch (e) {
    error = e
  }
  return { result, error, calls }
}

// Relay shorthands (issue #166). A Discuss turn returns a message and one fact: whether the
// participant has nothing further to raise. The discussion ends when two CONSECUTIVE turns both
// say so; nothing else terminates it, and there is no ceiling. Report / Record return the closed
// report shape (agreed conclusions + un-agreed points).
const turn = (message, done) => ({ message, done })
const DONE_TURN = turn('nothing further', true)
const OPEN_TURN = turn('one more point', false)
const AGREED_REPORT = { agreed: ['the feature design is the two-file change'], unagreed: [] }
const UNAGREED_POINT = { point: 'oracle depth', developer_position: 'unit is enough', test_position: 'needs composition', why_raised: 'the criterion is not otherwise observable' }

// Default responder for the whole relay: every turn is done (so the discussion ends on the first
// consecutive pair, at turn 2), both reports and the scribe return one agreed conclusion, the
// ledger acknowledges. `overrides` replaces any single label's answer -- including with `null`,
// which is how a missing sub-agent is scripted -- or with a function called per call.
const relayResponder = (overrides = {}) => {
  const calls = {}
  return (label) => {
    calls[label] = (calls[label] || 0) + 1
    if (Object.prototype.hasOwnProperty.call(overrides, label)) {
      const v = overrides[label]
      return typeof v === 'function' ? v(calls[label]) : v
    }
    if (/^(dev|test)-t\d+$/.test(label)) return DONE_TURN
    if (label === 'dev-report' || label === 'test-report') return AGREED_REPORT
    if (label === 'scribe') return AGREED_REPORT
    if (label === 'ledger') return 'ledger ok'
    return null
  }
}
// Scripts the Discuss turns in order; `null` scripts a missing (errored / skipped) sub-agent turn,
// which the workflow's own `.catch(() => null)` records as a MISSING turn.
const scriptTurns = (list) => {
  let i = 0
  return (label) => {
    if (!/^(dev|test)-t\d+$/.test(label)) return undefined
    const v = list[i++]
    if (v === undefined) throw new Error(`ran out of scripted turns at ${label}`)
    if (v === null) throw new Error('scripted missing turn')
    return v
  }
}
const relayWithTurns = (list, overrides = {}) => {
  const next = scriptTurns(list)
  const base = relayResponder(overrides)
  return (label, prompt) => {
    const t = next(label)
    return t === undefined ? base(label, prompt) : t
  }
}
// The Topic block of a prompt, which is byte-identical across every call of one run.
const topicOf = (prompt) => (prompt.split('## Topic\n')[1] || '').split('\n\n## Transcript')[0]
const transcriptOf = (prompt) => prompt.split('## Transcript\n')[1] || ''

let failures = 0
async function test(name, fn) {
  try {
    await fn()
    console.log(`  ok    ${name}`)
  } catch (e) {
    failures++
    console.log(`  FAIL  ${name}\n        ${e.message}`)
  }
}

// ---- ARCHITECT: spawn-policy load (issue #150 / #151 regression) --------------
// The transcription call itself never reaches the responder (see the `policy-load`
// interception in `makeAgent` above) -- these scenarios drive it directly via
// `opts.policyLoad` to lock the fail-closed sentinels architect-deliberation.js
// derives from it (REASON_POLICY_LOAD_AGENT_MISSING / REASON_POLICY_ABSENT /
// REASON_POLICY_MALFORMED), each stopping the run with ITS OWN distinct cause.
// Since issue #166 the workflow reaches no verdict, so the observable is `stopped`:
// the run's infrastructure state, null on a deliberation that was carried out.

await test('ARCHITECT: policy-load agent returns null (agent missing/errored) -> stopped "spawn policy load agent missing"', async () => {
  const { result } = await runArch({ issue: 'policy-null' }, () => 'x', { policyLoad: null })
  assert.equal(result.stopped, 'spawn policy load agent missing')
  assert.equal(result.report, null)
})

await test('ARCHITECT: policy-load returns found:false (file absent/empty) -> stopped "spawn policy absent"', async () => {
  const { result } = await runArch({ issue: 'policy-absent' }, () => 'x', {
    policyLoad: { found: false, content: '' },
  })
  assert.equal(result.stopped, 'spawn policy absent')
})

await test('ARCHITECT: policy-load content is not valid JSON -> stopped "spawn policy malformed"', async () => {
  const { result } = await runArch({ issue: 'policy-malformed-json' }, () => 'x', {
    policyLoad: { found: true, content: 'not json' },
  })
  assert.equal(result.stopped, 'spawn policy malformed')
})

await test('ARCHITECT: policy-load content parses but lacks this workflow\'s site table -> stopped "spawn policy malformed"', async () => {
  const { result } = await runArch({ issue: 'policy-malformed-shape' }, () => 'x', {
    policyLoad: { found: true, content: JSON.stringify({ workflow_sites: { 'verify-cause-branch': {} } }) },
  })
  assert.equal(result.stopped, 'spawn policy malformed')
})

await test('ARCHITECT: a valid policy-load (the real spawn-policy.json content, unmodified by any scenario) lets the run reach Discuss normally', async () => {
  const { result, calls } = await runArch({ issue: 'policy-ok' }, relayResponder())
  assert.equal(result.stopped, null)
  assert.ok(calls.some((c) => c.label === 'policy-load'), 'the policy-load call must have been made')
  assert.ok(calls.some((c) => c.label === 'dev-t1'), 'a valid default policy must let the relay open')
})

// ---- Issue #150 cycle 2 (F1 policy-row fail-closed totality) ------------------
// Verification design > .autoflow/issue-150-verification-design.md > §1 rows
// `required-row-omission-escalates` / `empty-site-table-fails-closed` /
// `fail-closed-precedes-work` / `required-key-declaration-join`'s ARCHITECT half. Every payload is
// derived from the REAL on-disk .claude/autoflow/spawn-policy.json (never a hand-written fixture),
// per §3's composition oracle. Four site keys since issue #166 restored the deliberation to a
// relay: the two turn sites, the scribe and the ledger.
const ARCH_REQUIRED_KEYS = ['dev-turn', 'test-turn', 'scribe', 'ledger']
const VERIFY_REQUIRED_KEYS = ['test-self-check', 'impl-self-check', 'ledger']

function policyPayload(mutate) {
  const policy = JSON.parse(REAL_POLICY_CONTENT)
  mutate(policy)
  return { found: true, content: JSON.stringify(policy) }
}

for (const key of ARCH_REQUIRED_KEYS) {
  await test(`ARCHITECT: required row "${key}" deleted from workflow_sites.architect-deliberation -> stopped with a policy-row cause naming it, exactly [policy-load] issued (required-row-omission-stops)`, async () => {
    const policyLoad = policyPayload((p) => { delete p.workflow_sites['architect-deliberation'][key] })
    const { result, calls } = await runArch(
      { issue: `policy-row-missing-${key}` },
      () => { throw new Error(`no sub-agent should be spawned under an incomplete policy (deleted "${key}")`) },
      { policyLoad },
    )
    assert.match(result.stopped, /^spawn policy row incomplete/, `deleting "${key}" must stop the run on the row cause, got: ${result.stopped}`)
    assert.ok(result.stopped.includes(key), `the cause must name the deleted row "${key}", got: ${result.stopped}`)
    assert.equal(result.report, null, 'a stopped run reports nothing')
    assert.deepEqual(
      calls.map((c) => c.label), ['policy-load'],
      `exactly one call (policy-load) may be issued when required row "${key}" is missing -- no turn, no scribe, no ledger spawn -- got: ${JSON.stringify(calls.map((c) => c.label))}`,
    )
  })
}

await test('ARCHITECT: workflow_sites.architect-deliberation present but empty ({}) -> the same row-incomplete disposition as a single omission, naming every required key (empty-site-table-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { p.workflow_sites['architect-deliberation'] = {} })
  const { result, calls } = await runArch({ issue: 'policy-row-empty-table' }, () => null, { policyLoad })
  assert.match(result.stopped, /^spawn policy row incomplete/)
  for (const key of ARCH_REQUIRED_KEYS) assert.ok(result.stopped.includes(key), `the cause must name "${key}", got: ${result.stopped}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('ARCHITECT: required effort_contract absent -> the policy-unusable disposition, cause naming the contract, exactly [policy-load] issued (effort-contract-unusable-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { delete p.effort_contract })
  const { result, calls } = await runArch({ issue: 'policy-contract-absent' }, () => { throw new Error('no sub-agent should be spawned under an unusable effort_contract') }, { policyLoad })
  assert.match(result.stopped, /contract/i, `the cause must name the contract, got: ${result.stopped}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('ARCHITECT: effort_contract.config_inherit_sentinel empty string -> the policy-unusable disposition, exactly [policy-load] issued (effort-contract-unusable-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { p.effort_contract.config_inherit_sentinel = '' })
  const { result, calls } = await runArch({ issue: 'policy-contract-sentinel-empty' }, () => { throw new Error('no sub-agent should be spawned under an unusable effort_contract') }, { policyLoad })
  assert.match(result.stopped, /contract/i, `the cause must name the contract, got: ${result.stopped}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('ARCHITECT: site() reads the inherit sentinel from effort_contract.config_inherit_sentinel, not the bare literal -- a row carrying the REWRITTEN sentinel omits the effort key (workflow-sentinel-from-config, arm a)', async () => {
  const CUSTOM = 'CUSTOM_SENTINEL_XYZ'
  const policyLoad = policyPayload((p) => {
    p.effort_contract.config_inherit_sentinel = CUSTOM
    p.workflow_sites['architect-deliberation']['dev-turn'].effort = CUSTOM
  })
  const { calls } = await runArch({ issue: 'sentinel-rewrite-a' }, relayResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'dev-t1')
  assert.ok(call, 'dev-t1 must have been spawned under a valid rewritten contract')
  assert.equal('effort' in call.opts, false, `a row carrying the rewritten sentinel must omit the effort key, got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: under a REWRITTEN sentinel, a row still carrying the literal string "inherit" ships it as a CONCRETE effort value (workflow-sentinel-from-config, arm b)', async () => {
  const CUSTOM = 'CUSTOM_SENTINEL_XYZ'
  const policyLoad = policyPayload((p) => {
    p.effort_contract.config_inherit_sentinel = CUSTOM
    // test-turn keeps its shipped "inherit" value unchanged -- it is no longer the sentinel.
  })
  const { calls } = await runArch({ issue: 'sentinel-rewrite-b' }, relayResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'test-t2')
  assert.ok(call, 'test-t2 must have been spawned under a valid rewritten contract')
  assert.equal(call.opts.effort, 'inherit', `"inherit" under a rewritten contract must ship as a concrete effort value, got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: the real, unmodified shipped policy still passes the row-totality and effort_contract checks and completes a deliberation (valid-policy-unaffected, F1 over-strictness)', async () => {
  const { result, calls } = await runArch({ issue: 'valid-policy-still-runs' }, relayResponder())
  assert.equal(result.stopped, null)
  assert.ok(calls.some((c) => c.label === 'dev-t1'), 'the real policy must not be rejected by the per-row/contract check')
})

// ---- Issue #150 cycle 3 (F4 effort-truthiness pass-through) --------------------
// Verification design > .autoflow/issue-150-verification-design.md > §1 rows
// `effort-zero-admitted` / `unadmitted-falsy-passes-through`. `site()` decides "override vs
// inherit" against the SENTINEL ALONE, never by truthiness -- a truthiness test would drop the
// contract-admitted concrete value `0`, indistinguishable from "no override". Both legs mutate
// the REAL on-disk config (policyPayload), per §3's composition oracle.
await test('ARCHITECT: a workflow_sites row carrying the contract-admitted concrete effort 0 reaches the spawn opts as 0, not silently dropped to inherit (effort-zero-propagates, ARCHITECT arm)', async () => {
  const policyLoad = policyPayload((p) => {
    p.workflow_sites['architect-deliberation']['dev-turn'].effort = 0
  })
  const { calls } = await runArch({ issue: 'effort-zero-propagates-arch' }, relayResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'dev-t1')
  assert.ok(call, 'dev-t1 must have been spawned under a valid policy')
  assert.equal('effort' in call.opts, true, `a row carrying the concrete effort 0 must NOT be treated as inherit (no effort key), got opts=${JSON.stringify(call.opts)}`)
  assert.equal(call.opts.effort, 0, `the concrete effort 0 must reach the spawn opts verbatim, got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: a workflow_sites row carrying an UNADMITTED falsy effort ("") reaches the spawn opts verbatim rather than degrading to inherit (unadmitted-falsy-passes-through, ARCHITECT arm)', async () => {
  const policyLoad = policyPayload((p) => {
    p.workflow_sites['architect-deliberation']['test-turn'].effort = ''
  })
  const { calls } = await runArch({ issue: 'unadmitted-falsy-passthrough-arch' }, relayResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'test-t2')
  assert.ok(call, 'test-t2 must have been spawned under a valid policy')
  assert.equal('effort' in call.opts, true, `an unadmitted falsy value must reach opts verbatim, not degrade to inherit (no effort key), got opts=${JSON.stringify(call.opts)}`)
  assert.equal(call.opts.effort, '', `the unadmitted value must reach the spawn opts verbatim (not coerced), got opts=${JSON.stringify(call.opts)}`)
})

// ---- ARCHITECT: the relay (issue #166) ----------------------------------------
// The Developer AI opens, the Test AI answers, the two alternate. Every turn receives ONE fixed
// prompt per role plus the same Topic and the transcript of every prior turn; the transcript is
// the participants' memory, and nobody edits a design document while the discussion runs.

await test('ARCHITECT: the Developer AI opens and the Test AI answers, alternating (#166 relay)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayWithTurns([OPEN_TURN, OPEN_TURN, DONE_TURN, DONE_TURN]))
  assert.deepEqual(calls.filter((c) => /^(dev|test)-t\d+$/.test(c.label)).map((c) => c.label), ['dev-t1', 'test-t2', 'dev-t3', 'test-t4'])
  assert.equal(result.turns, 4)
})

await test('ARCHITECT: the Topic is one string, identical on every turn and on the Report and Record prompts (#166 topic-stated-once)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayWithTurns([OPEN_TURN, OPEN_TURN, DONE_TURN, DONE_TURN]))
  const topics = calls.filter((c) => c.label !== 'policy-load' && c.label !== 'ledger').map((c) => topicOf(c.prompt))
  assert.ok(topics.length >= 7, `expected the four turns plus both reports and the scribe, got ${topics.length}`)
  assert.equal(new Set(topics).size, 1, 'the Topic string must not differ between calls')
  assert.match(topics[0], /^Issue #166\./)
  assert.match(topics[0], /\.autoflow\/issue-166-phase-b\.md/)
})

await test('ARCHITECT: each turn prompt carries every prior turn, in order, attributed to its side (#166 transcript-is-the-memory)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayWithTurns([
    turn('dev proposes the two-file change', false),
    turn('test asks for the composition oracle', false),
    DONE_TURN, DONE_TURN,
  ]))
  const byLabel = Object.fromEntries(calls.map((c) => [c.label, c.prompt]))
  assert.match(transcriptOf(byLabel['dev-t1']), /no turns yet/)
  assert.match(transcriptOf(byLabel['test-t2']), /### Turn 1 — Developer AI\ndev proposes the two-file change/)
  const t3 = transcriptOf(byLabel['dev-t3'])
  assert.match(t3, /### Turn 1 — Developer AI/)
  assert.match(t3, /### Turn 2 — Test AI\ntest asks for the composition oracle/)
  assert.ok(t3.indexOf('Turn 1') < t3.indexOf('Turn 2'), 'the transcript must stay in turn order')
})

await test('ARCHITECT: every turn prompt states that no file is edited during the discussion (#166 no-authoring-while-discussing)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayWithTurns([OPEN_TURN, DONE_TURN, DONE_TURN]))
  for (const label of ['dev-t1', 'test-t2', 'dev-t3']) {
    const p = calls.find((c) => c.label === label).prompt
    assert.match(p, /do not edit any file/, `${label} must carry the no-editing rule`)
  }
})

await test('ARCHITECT: the discussion ends when two CONSECUTIVE turns both report done (#166 termination)', async () => {
  const { result } = await runArch({ issue: '166' }, relayWithTurns([DONE_TURN, DONE_TURN]))
  assert.equal(result.turns, 2)
  assert.equal(result.stopped, null)
})

await test('ARCHITECT: a done turn followed by a not-done turn does not terminate -- the pair must be consecutive (#166 termination)', async () => {
  const { result } = await runArch({ issue: '166' }, relayWithTurns([DONE_TURN, OPEN_TURN, DONE_TURN, DONE_TURN]))
  assert.equal(result.turns, 4, 'a done/not-done/done sequence must run on to the next consecutive pair')
})

await test('ARCHITECT: the first turn has no predecessor to pair with, so it never ends the discussion alone (#166 termination)', async () => {
  const { result } = await runArch({ issue: '166' }, relayWithTurns([DONE_TURN, OPEN_TURN, OPEN_TURN, DONE_TURN, DONE_TURN]))
  assert.equal(result.turns, 5)
})

await test('ARCHITECT: a single missing turn is recorded in the transcript as missing and the discussion continues (#166 missing-turn)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayWithTurns([null, OPEN_TURN, DONE_TURN, DONE_TURN]))
  assert.equal(result.stopped, null)
  assert.equal(result.turns, 4)
  assert.match(transcriptOf(calls.find((c) => c.label === 'test-t2').prompt), /### Turn 1 — Developer AI\n\(no response — this turn is missing\)/)
})

await test('ARCHITECT: two consecutive missing turns stop the run, with no Report, Record or ledger call (#166 missing-turn)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayWithTurns([null, null]))
  assert.equal(result.stopped, 'participant missing for 2 consecutive turn(s)')
  assert.equal(result.report, null)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load', 'dev-t1', 'test-t2'])
  assert.match(result.summary, /^ARCHITECT deliberation stopped — participant missing/)
})

await test('ARCHITECT: a missing turn does not pair across the gap -- the done turns around a hole are same-side and must not terminate (#166 missing-turn)', async () => {
  const { result } = await runArch({ issue: '166' }, relayWithTurns([DONE_TURN, null, DONE_TURN, DONE_TURN]))
  assert.equal(result.turns, 4)
})

// ---- ARCHITECT: Report and Record (issue #166) --------------------------------
// Each participant reads the same transcript and reports it; the scribe writes the documents and
// returns the consolidated report, which IS the run's result.

await test('ARCHITECT: both participants are asked to report, on the transcript (#166 report)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayWithTurns([turn('dev opens', true), DONE_TURN]))
  for (const label of ['dev-report', 'test-report']) {
    const call = calls.find((c) => c.label === label)
    assert.ok(call, `${label} must be called`)
    assert.match(transcriptOf(call.prompt), /### Turn 1 — Developer AI\ndev opens/, `${label} must carry the transcript`)
    assert.match(call.prompt, /in "agreed"/, `${label} must carry the report instruction`)
  }
})

await test('ARCHITECT: both reports missing -> stopped "report missing", no scribe and no ledger (#166 report)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayResponder({ 'dev-report': null, 'test-report': null }))
  assert.equal(result.stopped, 'report missing')
  assert.equal(result.report, null)
  assert.ok(!calls.some((c) => c.label === 'scribe' || c.label === 'ledger'))
})

await test('ARCHITECT: one report missing -> the run continues and the scribe is told which side is missing (#166 report)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayResponder({ 'test-report': null }))
  assert.equal(result.stopped, null)
  const scribe = calls.find((c) => c.label === 'scribe')
  assert.ok(scribe, 'the scribe must still be called')
  assert.match(scribe.prompt, /### Test AI\n\(report missing/)
  assert.match(scribe.prompt, /### Developer AI\nagreed:/)
})

await test('ARCHITECT: the scribe is instructed to write the three documents and add no design of its own (#166 record)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayResponder())
  const p = calls.find((c) => c.label === 'scribe').prompt
  for (const artifact of artifactPaths('166')) assert.ok(p.includes(artifact), `the scribe prompt must name ${artifact}`)
  assert.match(p, /add no design of your own/)
  assert.deepEqual(result.report, AGREED_REPORT, 'the scribe\'s consolidated report is the run\'s report')
})

await test('ARCHITECT: a missing scribe stops the run and suppresses the ledger (#166 record)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayResponder({ scribe: null }))
  assert.equal(result.stopped, 'scribe missing')
  assert.equal(result.report, null)
  assert.ok(!calls.some((c) => c.label === 'ledger'))
})

await test('ARCHITECT: the ledger runs exactly once, carrying the agreed conclusions under the authority "ARCHITECT agreed" (#166 record)', async () => {
  const scribe = { agreed: ['the relay is the deliberation', 'the scribe writes the documents'], unagreed: [UNAGREED_POINT] }
  const { result, calls } = await runArch({ issue: '166' }, relayResponder({ scribe }))
  const ledgerCalls = calls.filter((c) => c.label === 'ledger')
  assert.equal(ledgerCalls.length, 1)
  const p = ledgerCalls[0].prompt
  assert.match(p, /authority "ARCHITECT agreed"/)
  assert.ok(p.includes('- the relay is the deliberation'), 'the agreed conclusions must reach the ledger prompt')
  assert.ok(!p.includes(UNAGREED_POINT.point), 'an un-agreed point is not a decision and never reaches the ledger')
  assert.equal(result.summary, 'ARCHITECT deliberation ended after 2 turn(s): 2 agreed conclusion(s), 1 un-agreed point(s)')
})

await test('ARCHITECT: nothing agreed -> no ledger call, and the run still completes (#166 record)', async () => {
  const { result, calls } = await runArch({ issue: '166' }, relayResponder({ scribe: { agreed: [], unagreed: [UNAGREED_POINT] } }))
  assert.equal(result.stopped, null)
  assert.ok(!calls.some((c) => c.label === 'ledger'))
  assert.equal(result.summary, 'ARCHITECT deliberation ended after 2 turn(s): 0 agreed conclusion(s), 1 un-agreed point(s)')
})

await test('ARCHITECT: a rejecting ledger sub-agent is absorbed -- the report and the stopped state are already settled (#166 record)', async () => {
  const { result } = await runArch({ issue: '166' }, relayResponder({
    ledger: () => { throw new Error('ledger sub-agent unreachable') },
  }))
  assert.equal(result.stopped, null)
  assert.deepEqual(result.report, AGREED_REPORT)
})

// ---- ARCHITECT: the ledger seed in the Topic (issue #166) ----------------------
// The Topic carries the ledger's settled-authority sentence, so a settled decision is read rather
// than re-argued (CLAUDE.md > Decision Ledger). "operator decision" is named among the settled
// authorities -- the operator's acceptance-criterion call is not re-opened by a later discussion.
// The two retired ARCHITECT authorities stay readable there because old ledgers still carry them.

await test('ARCHITECT: the Topic names "operator decision" as a settled authority the discussion does not reopen (ledger-seed, operator-authority-is-readable)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayResponder())
  const topic = topicOf(calls.find((c) => c.label === 'dev-t1').prompt)
  assert.match(topic, /"operator decision"/, 'the seed sentence must name operator decision as settled')
  assert.match(topic, /is settled and is reopened only on a fact verified now/)
  assert.match(topic, /\.autoflow\/issue-166-ledger\.md/, 'the seed must name the issue\'s ledger')
  assert.ok(!/ARCHITECT ac-change/.test(topic), 'the retired ac-change authority is never seeded')
})

await test('ARCHITECT: the Topic keeps the two retired ARCHITECT authorities readable, since old ledgers carry them (ledger-seed)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayResponder())
  const topic = topicOf(calls.find((c) => c.label === 'dev-t1').prompt)
  assert.match(topic, /"ARCHITECT agreed"/)
  assert.match(topic, /"ARCHITECT mutual ACCEPT"/)
  assert.match(topic, /"ARCHITECT rejected"/)
})

// ---- ARCHITECT: the orchestrator's brief (issue #166) --------------------------
// `brief` is the orchestrator's preparation for a re-discussion -- a narrowed topic, facts it
// verified in the meantime, the prior report path. It is part of the Topic, so it reaches every
// call of the run, and it is accepted only from a JSON / object argument.

await test('ARCHITECT: a brief reaches the Topic of every turn, under the "From the orchestrator:" line (#166 brief)', async () => {
  const brief = 'discuss only the composition-oracle question; the prior report is .autoflow/issue-166-architect-report.md'
  const { calls } = await runArch({ issue: '166', brief }, relayWithTurns([OPEN_TURN, DONE_TURN, DONE_TURN]))
  for (const label of ['dev-t1', 'test-t2', 'dev-t3', 'dev-report', 'test-report', 'scribe']) {
    const call = calls.find((c) => c.label === label)
    assert.ok(call, `${label} must have been called`)
    assert.ok(call.prompt.includes(`From the orchestrator: ${brief}`), `${label} must carry the brief`)
  }
})

await test('ARCHITECT: no brief -> no "From the orchestrator:" line anywhere (#166 brief)', async () => {
  const { calls } = await runArch({ issue: '166' }, relayResponder())
  for (const c of calls) assert.ok(!/From the orchestrator:/.test(c.prompt), `${c.label} carries an orchestrator line without a brief`)
})

await test('ARCHITECT: a non-string brief throws at the boundary, at the single existing throw site (#166 brief)', async () => {
  await assert.rejects(
    () => runArch({ issue: '166', brief: 42 }, relayResponder()),
    /args\.brief must be a string or absent/,
  )
})

await test('ARCHITECT: brief is not salvaged from prose args -- it is a JSON/object argument only (#166 brief)', async () => {
  const { calls } = await runArch('please re-discuss issue #166, brief: narrow it to the oracle', relayResponder())
  for (const c of calls) assert.ok(!/From the orchestrator:/.test(c.prompt), 'a prose "brief:" token must not become the orchestrator brief')
})

// ---- ARCHITECT: the argument surface (issue #14 salvage, issue #166 return) ----

await test('ARCHITECT: missing args.issue throws at the boundary', async () => {
  await assert.rejects(() => runArch({}, relayResponder()), /args\.issue is required/)
})

await test('ARCHITECT: args delivered as a JSON string (real runtime form) resolves issue', async () => {
  const { result } = await runArch(JSON.stringify({ issue: '7' }), relayResponder())
  assert.deepEqual(result.artifacts, artifactPaths('7'))
})

await test('ARCHITECT: prose args, hashed number resolves, and the harness mirror agrees with the script (DCR-1)', async () => {
  const args = 'please run the architect deliberation for v2 of issue #215'
  const { result } = await runArch(args, relayResponder())
  assert.deepEqual(result.artifacts, artifactPaths('215'))
  assert.equal(extractArgv(args).issue, '215', 'the mirror must resolve the same id the script does')
})

await test('ARCHITECT: prose args, a single bare digit run resolves via the tier-3 fallback (DCR-2)', async () => {
  const { result } = await runArch('run the deliberation for 215', relayResponder())
  assert.deepEqual(result.artifacts, artifactPaths('215'))
})

await test('ARCHITECT: prose args, two or more bare digit runs are ambiguous and fail loudly (DCR-2, c2)', async () => {
  await assert.rejects(() => runArch('run the v2 deliberation for 215', relayResponder()), /args\.issue is required/)
})

await test('ARCHITECT: prose args with no extractable digits still fails loudly', async () => {
  await assert.rejects(() => runArch('please run the architect deliberation', relayResponder()), /args\.issue is required/)
})

await test('ARCHITECT: the return carries exactly phase/report/artifacts/ledger/turns/summary/stopped -- no verdict (#166 return contract)', async () => {
  const { result } = await runArch({ issue: '166' }, relayResponder())
  assert.deepEqual(Object.keys(result).sort(), ['artifacts', 'ledger', 'phase', 'report', 'stopped', 'summary', 'turns'])
  assert.equal(result.phase, 'architect')
  assert.deepEqual(result.artifacts, artifactPaths('166'))
  assert.equal(result.ledger, '.autoflow/issue-166-ledger.md')
  assert.equal(result.turns, 2)
  assert.equal(result.stopped, null)
})

// ---- VERIFY: spawn-policy load (issue #150 / #151 regression) -----------------
// verify-cause-branch.js has no ESCALATE verdict (Decision 7: a single self-check round,
// deterministic next_action), so a missing/unreadable/malformed policy raises at the boundary
// instead -- one throw message for all three causes (see verify-cause-branch.js > Spawn policy
// load > "Fail-closed: this workflow has no ESCALATE verdict").

await test('VERIFY: policy-load agent returns null (agent missing/errored) -> throws at the boundary', async () => {
  await assert.rejects(
    () => runVerify({ issue: '1', failLog: '/tmp/f.log' }, () => 'x', { policyLoad: null }),
    /verify-cause-branch: spawn policy could not be loaded/,
  )
})

await test('VERIFY: policy-load returns found:false (file absent/empty) -> throws at the boundary', async () => {
  await assert.rejects(
    () => runVerify({ issue: '1', failLog: '/tmp/f.log' }, () => 'x', {
      policyLoad: { found: false, content: '' },
    }),
    /verify-cause-branch: spawn policy could not be loaded/,
  )
})

await test('VERIFY: policy-load content is not valid JSON -> throws at the boundary', async () => {
  await assert.rejects(
    () => runVerify({ issue: '1', failLog: '/tmp/f.log' }, () => 'x', {
      policyLoad: { found: true, content: 'not json' },
    }),
    /verify-cause-branch: spawn policy could not be loaded/,
  )
})

await test('VERIFY: policy-load content parses but lacks this workflow\'s site table -> throws at the boundary', async () => {
  await assert.rejects(
    () => runVerify({ issue: '1', failLog: '/tmp/f.log' }, () => 'x', {
      policyLoad: { found: true, content: JSON.stringify({ workflow_sites: { 'architect-deliberation': {} } }) },
    }),
    /verify-cause-branch: spawn policy could not be loaded/,
  )
})

await test('VERIFY: a valid policy-load (the real spawn-policy.json content, unmodified by any scenario) lets the run reach the self-check calls', async () => {
  const responder = (label) => {
    if (label === 'ledger') return 'ledger ok'
    if (label === 'test-self-check') return { verdict: 'no_problem', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'x'
  }
  const { calls, result } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder)
  assert.ok(calls.some((c) => c.label === 'policy-load'), 'the policy-load call must have been made')
  assert.equal(result.next_action, 'EVALUATION_AI')
})

// ---- Issue #150 cycle 2 (F1 policy-row fail-closed totality), VERIFY half ----
// Verification design > §1 `required-row-omission-throws` / `empty-site-table-fails-closed` /
// `fail-closed-precedes-work` / `effort-contract-unusable-fails-closed`, `workflow-sentinel-from-config`.
for (const key of VERIFY_REQUIRED_KEYS) {
  await test(`VERIFY: required row "${key}" deleted from workflow_sites.verify-cause-branch -> throws at the boundary with a policy-row cause, exactly [policy-load] issued (required-row-omission-throws)`, async () => {
    const policyLoad = policyPayload((p) => { delete p.workflow_sites['verify-cause-branch'][key] })
    const { error, calls } = await runVerifyRaw(
      { issue: '1', failLog: '/tmp/f.log' },
      () => { throw new Error(`no sub-agent should be spawned under an incomplete policy (deleted "${key}")`) },
      { policyLoad },
    )
    assert.ok(error, `deleting "${key}" must throw at the boundary`)
    assert.match(error.message, /policy/i, `boundary error must name the policy, got: ${error.message}`)
    assert.deepEqual(
      calls.map((c) => c.label), ['policy-load'],
      `exactly one call (policy-load) may be issued when required row "${key}" is missing -- no self-check spawn, no Ledger spawn -- got: ${JSON.stringify(calls.map((c) => c.label))}`,
    )
  })
}

await test('VERIFY: workflow_sites.verify-cause-branch present but empty ({}) -> throws at the boundary with a policy-row cause, not an EVALUATION_AI route (empty-site-table-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { p.workflow_sites['verify-cause-branch'] = {} })
  const { result, error, calls } = await runVerifyRaw({ issue: '1', failLog: '/tmp/f.log' }, () => null, { policyLoad })
  assert.equal(result, null, 'an empty table must throw rather than resolve to an EVALUATION_AI route')
  assert.ok(error)
  assert.match(error.message, /policy/i, `boundary error must name the policy, got: ${error.message}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('VERIFY: effort_contract absent -> throws at the boundary with a contract-naming cause, exactly [policy-load] issued (effort-contract-unusable-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { delete p.effort_contract })
  const { error, calls } = await runVerifyRaw({ issue: '1', failLog: '/tmp/f.log' }, () => { throw new Error('no sub-agent should be spawned under an unusable effort_contract') }, { policyLoad })
  assert.ok(error)
  assert.match(error.message, /contract/i, `boundary error must name the contract, got: ${error.message}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('VERIFY: effort_contract.config_inherit_sentinel empty string -> throws at the boundary with a contract-naming cause, exactly [policy-load] issued (effort-contract-unusable-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { p.effort_contract.config_inherit_sentinel = '' })
  const { error, calls } = await runVerifyRaw({ issue: '1', failLog: '/tmp/f.log' }, () => { throw new Error('no sub-agent should be spawned under an unusable effort_contract') }, { policyLoad })
  assert.ok(error)
  assert.match(error.message, /contract/i, `boundary error must name the contract, got: ${error.message}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('VERIFY: site() reads the inherit sentinel from effort_contract.config_inherit_sentinel -- a row carrying the REWRITTEN sentinel omits the effort key (workflow-sentinel-from-config, arm a)', async () => {
  const CUSTOM = 'CUSTOM_SENTINEL_XYZ'
  const policyLoad = policyPayload((p) => {
    p.effort_contract.config_inherit_sentinel = CUSTOM
    p.workflow_sites['verify-cause-branch']['test-self-check'].effort = CUSTOM
  })
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'no_problem', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  const { calls } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder, { policyLoad })
  const call = calls.find((c) => c.label === 'test-self-check')
  assert.ok(call)
  assert.equal('effort' in call.opts, false, `a row carrying the rewritten sentinel must omit the effort key, got opts=${JSON.stringify(call.opts)}`)
})

await test('VERIFY: under a REWRITTEN sentinel, a row still carrying the literal string "inherit" ships it as a CONCRETE effort value (workflow-sentinel-from-config, arm b)', async () => {
  const CUSTOM = 'CUSTOM_SENTINEL_XYZ'
  const policyLoad = policyPayload((p) => {
    p.effort_contract.config_inherit_sentinel = CUSTOM
    // impl-self-check keeps its shipped "inherit" value unchanged -- it is no longer the sentinel.
  })
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'no_problem', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  const { calls } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder, { policyLoad })
  const call = calls.find((c) => c.label === 'impl-self-check')
  assert.ok(call)
  assert.equal(call.opts.effort, 'inherit', `"inherit" under a rewritten contract must ship as a concrete effort value, got opts=${JSON.stringify(call.opts)}`)
})

await test('VERIFY: the real, unmodified shipped policy still passes the row-totality and effort_contract checks and reaches the self-check calls (valid-policy-unaffected, F1 over-strictness)', async () => {
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'no_problem', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  const { calls } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder)
  assert.ok(calls.some((c) => c.label === 'test-self-check'), 'the real policy must not be rejected by the new per-row/contract check')
})

// ---- Issue #150 cycle 3 (F4 effort-truthiness pass-through), VERIFY arm -------
// Verification design > §1 `effort-zero-admitted`, §2 "Workflow-script regression, VERIFY
// arm" -- catches the same truthiness defect at verify-cause-branch.js:161 surviving after
// architect-deliberation.js is fixed; the two scripts carry independent textual copies of
// site(), so this is a separate falsifiable arm, not a re-run of the ARCHITECT one.
await test('VERIFY: a workflow_sites row carrying the contract-admitted concrete effort 0 reaches the spawn opts as 0, not silently dropped to inherit (effort-zero-propagates, VERIFY arm)', async () => {
  const policyLoad = policyPayload((p) => {
    p.workflow_sites['verify-cause-branch']['test-self-check'].effort = 0
  })
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'no_problem', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  const { calls } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder, { policyLoad })
  const call = calls.find((c) => c.label === 'test-self-check')
  assert.ok(call, 'test-self-check must have been spawned under a valid policy')
  assert.equal('effort' in call.opts, true, `a row carrying the concrete effort 0 must NOT be treated as inherit (no effort key), got opts=${JSON.stringify(call.opts)}`)
  assert.equal(call.opts.effort, 0, `the concrete effort 0 must reach the spawn opts verbatim, got opts=${JSON.stringify(call.opts)}`)
})

const combos = [
  [{ verdict: 'fix_test', reason: 'x' }, { verdict: 'no_problem', reason: 'x' }, 'RED'],
  [{ verdict: 'no_problem', reason: 'x' }, { verdict: 'fix_impl', reason: 'x' }, 'GREEN'],
  [{ verdict: 'fix_test', reason: 'x' }, { verdict: 'fix_impl', reason: 'x' }, 'SEQUENTIAL_FIX'],
  [{ verdict: 'no_problem', reason: 'x' }, { verdict: 'no_problem', reason: 'x' }, 'EVALUATION_AI'],
]
for (const [tv, iv, expected] of combos) {
  await test(`VERIFY: ${tv.verdict} + ${iv.verdict} -> ${expected}`, async () => {
    const responder = (label) => {
      if (label === 'ledger') return 'ledger ok'
      if (label === 'test-self-check') return tv
      if (label === 'impl-self-check') return iv
      return 'x'
    }
    const { result } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder)
    assert.equal(result.next_action, expected)
  })
}

await test('VERIFY: null self-check recorded as "missing" (not no_problem) -> EVALUATION_AI', async () => {
  const responder = (label) => {
    if (label === 'ledger') return 'ledger ok'
    if (label === 'test-self-check') return null // simulate skip/error
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'x'
  }
  const { result, calls } = await runVerify({ issue: '1', failLog: '/tmp/f.log' }, responder)
  assert.equal(result.test_self_check, 'missing')
  assert.equal(result.next_action, 'EVALUATION_AI')
  assert.match(calls.find((c) => c.label === 'ledger').prompt, /test self-check=missing/)
})

await test('VERIFY: missing args.failLog throws at the boundary', async () => {
  await assert.rejects(
    () => verify({ issue: '1' }, phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.failLog is required/,
  )
})

await test('VERIFY: args delivered as a JSON string (real runtime form) resolves issue + failLog', async () => {
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'fix_test', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  // String args must resolve BOTH issue and failLog (else the failLog guard throws);
  // next_action RED proves fix_test + no_problem mapped over a string-delivered payload.
  const { result } = await runVerify(JSON.stringify({ issue: '1', failLog: '/tmp/f.log' }), responder)
  assert.equal(result.next_action, 'RED')
})

// ---- VERIFY: prose-args salvage asymmetry (issue #14) -------------------------

await test('VERIFY: prose issue, no failLog — asymmetry lock (DCR-3): issue salvaged, failLog still hard-required', async () => {
  await assert.rejects(
    () => verify('issue #215 — verify cause branch', phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.failLog is required/,
  )
})

await test('VERIFY: prose args, no digits still fails on the issue guard', async () => {
  await assert.rejects(
    () => verify('please run the verify cause branch', phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.issue is required/,
  )
})


// ---- meta-doc contract exposure (issue #14, F1; widened by issue #166) ---------

await test('meta: architect-deliberation.js description states the args contract (issue + brief) and the phases are Discuss/Report/Record', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  assert.match(src, /description:[^\n]*issue/i)
  assert.match(src, /description:[^\n]*brief/, 'the description must name the optional brief argument')
  const phases = src.match(/phases: \[[\s\S]*?\n  \],/)
  assert.ok(phases, 'meta.phases must be declared')
  assert.deepEqual(
    [...phases[0].matchAll(/title: '([^']+)'/g)].map((m) => m[1]),
    ['Discuss', 'Report', 'Record'],
  )
})

await test('meta: verify-cause-branch.js description states the args contract (issue + failLog)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/verify-cause-branch.js'), 'utf8')
  assert.match(src, /description:[^\n]*issue/i)
  // Scoped to the description line specifically -- failLog already appears elsewhere in the
  // file (top-of-file comment, code), so an unscoped /failLog/ over the whole source would
  // pass vacuously both pre- and post-fix.
  assert.match(src, /description:[^\n]*failLog/)
})

// ---- source-parity drift guard (issue #14, c2, DCR-4 ADOPTED) -----------------
// Weak drift-guard, not a behavioral test (verification design c2 §2 case 13): the
// three-tier salvage is hand-duplicated across architect-deliberation.js,
// verify-cause-branch.js, and this harness's extractArgv() mirror above. Assert
// the tier-2 anchor literal and the tier-3 uniqueness-guard literal appear in all
// three copies verbatim. Guard literal reconciled to the feature-design §3
// reference implementation's exact form (`all && all.length === 1`), per
// GATE:PLAN instruction, rather than the `?.length === 1` shorthand.
await test('source-parity: tier-2 anchor + tier-3 uniqueness guard identical across all three copies (c2, NEW)', async () => {
  const archSrc = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const verifySrc = readFileSync(join(root, '.claude/workflows/verify-cause-branch.js'), 'utf8')
  const harnessSrc = readFileSync(join(root, 'test/workflows/run.mjs'), 'utf8')
  for (const [label, src] of [['architect-deliberation.js', archSrc], ['verify-cause-branch.js', verifySrc], ['run.mjs extractArgv()', harnessSrc]]) {
    assert.ok(src.includes('\\bissue\\s+#?(\\d+)\\b'), `${label} missing tier-2 anchor literal`)
    assert.ok(src.includes('all && all.length === 1'), `${label} missing tier-3 uniqueness guard literal`)
  }
})

// ---- AC-facilitator-prompt (issue #97) -----------------------------------
// Neither facilitator script can call scripts/ledger/ledger-entry-id.js
// itself (the Workflow runtime injects only args/phase/parallel/agent/console
// -- no fs, no exec). The wiring is therefore in the prompt text delivered to
// the ledger sub-agent: it must carry both the `next` allocation literal and
// the post-append `check` literal (feature design > facilitator-prompt-wiring).
// This verifies prompt DELIVERY only, not sub-agent compliance -- see
// verification design > Verification depth determination.

await test('AC-facilitator-prompt: the ARCHITECT ledger prompt carries the next-allocation and check instructions', async () => {
  const { calls } = await runArch({ issue: '99900097' }, relayResponder())
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /ledger-entry-id\.sh next[^\n]*F\b/, 'the ledger prompt must instruct allocating each ID via next ... F')
  assert.match(ledgerPrompt, /ledger-entry-id\.sh check/, 'the ledger prompt must instruct running check after the appends')
  assert.match(ledgerPrompt, /one call per entry, never a serial incremented locally/, 'the ledger prompt must forbid a locally incremented serial')
})

await test('AC-facilitator-prompt: VERIFY cause-branch ledger prompt carries the next-allocation and check instructions', async () => {
  const responder = (label) => {
    if (label === 'test-self-check') return { verdict: 'fix_test', reason: 'x' }
    if (label === 'impl-self-check') return { verdict: 'no_problem', reason: 'x' }
    return 'ledger ok'
  }
  const { calls } = await runVerify({ issue: '99900097', failLog: '/tmp/f.log' }, responder)
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /ledger-entry-id\.sh next[^\n]*F\b/, 'VERIFY ledger prompt must instruct allocating each ID via next ... F')
  assert.match(ledgerPrompt, /ledger-entry-id\.sh check/, 'VERIFY ledger prompt must instruct running check after the appends')
})

console.log(failures ? `\n${failures} test(s) FAILED` : '\nall workflow regression tests passed')
process.exit(failures ? 1 : 0)
