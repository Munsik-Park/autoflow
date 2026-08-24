// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// Regression harness for the deliberation workflow scripts (issue #153).
//
// These tests lock the pure control-flow logic of the reference workflows —
// convergence rule, counter threading, ledger-authority branching, VERIFY
// next_action mapping, missing-response handling, and the arg guards — by running
// each script against a mock runtime. They do NOT exercise a live Claude Code
// Workflow runtime (that is the operator-side smoke scenario in
// docs/teammate-contracts.md > Verification scenarios); they catch the logic-bug
// class found in PR #197 review without spawning real agents.
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
import { readFileSync, writeFileSync, unlinkSync, existsSync } from 'node:fs'
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
// file's verbatim content, exactly as a working transcription sub-agent would, so the ~150
// pre-existing scenarios (written before #150) do not need to individually stub a call they know
// nothing about. The handful of scenarios that exercise the load failure itself (absent / malformed
// / agent-missing) pass an explicit override.
const REAL_POLICY_CONTENT = readFileSync(join(root, '.claude/autoflow/spawn-policy.json'), 'utf8')
const DEFAULT_POLICY_LOAD_RESPONSE = { found: true, content: REAL_POLICY_CONTENT }

function makeAgent(responder, calls, policyLoad = DEFAULT_POLICY_LOAD_RESPONSE) {
  return async (prompt, opts = {}) => {
    const label = opts.label || ''
    // `opts` is recorded verbatim (issue #150 cycle 2) so a scenario can assert what a call site's
    // site(key) spread actually produced -- in particular whether an `effort` key reached the
    // spawn opts at all, which is the observable the sentinel-from-config legs need. Additive: no
    // existing assertion reads more than `.label` / `.prompt` off a `calls` entry (grepped).
    calls.push({ label, prompt, opts })
    if (label === 'policy-load') return typeof policyLoad === 'function' ? policyLoad() : policyLoad
    return responder(label, prompt)
  }
}

// Fixture support for AC2 (issue #845): the real fs.existsSync check the
// implementation is expected to add runs against real on-disk artifacts, so
// the harness must write/remove the two draft artifacts around each ARCHITECT
// run. `extractArgv` mirrors architect-deliberation.js's string-arg
// normalization so the fixture targets the same issue id the script resolves
// (needed for the JSON-string-args test which drives issue '7').
// DCR-1 (issue #14, c2): mirror the SAME catch-path three-tier prose-salvage rule
// the scripts adopt (tier 1 hash /#(\d+)/, tier 2 issue-anchored /\bissue\s+#?(\d+)\b/i,
// tier 3 bare /(\d+)/ adopted ONLY when exactly one number is present -- otherwise
// ambiguous -> {} -> the loud-fail guard fires) so a prose-args fixture lands at the
// id the script itself resolves. This is the single source of the resolution rule at
// test time.
// Widened (issue #127): renamed from `extractIssue` and returns the whole normalized
// argv object `{ issue, resume }` instead of the bare issue string -- per feature design
// > API interface > Argument surface, *The rename carries a specified data flow*. The
// catch path additionally salvages a standalone `resume` word token (the resume-token
// parity surface with architect-deliberation.js is two copies, this mirror and the
// script itself -- verified by the source-parity test below).
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
          const resumeToken = /\bresume\b/i.test(args)
          const salvaged = {}
          if (issue) salvaged.issue = issue
          if (resumeToken) salvaged.resume = true
          return salvaged
        }
      })()
    : (args || {})
  return { issue: argv.issue, resume: argv.resume }
}

function artifactPaths(issue) {
  return {
    feature: join(root, `.autoflow/issue-${issue}-feature-design.md`),
    verif: join(root, `.autoflow/issue-${issue}-verification-design.md`),
    register: join(root, `.autoflow/issue-${issue}-architect-register.json`),
  }
}

function writeDraftArtifacts(issue, omit) {
  const { feature, verif } = artifactPaths(issue)
  if (omit !== 'feature') writeFileSync(feature, '# feature design fixture\n')
  if (omit !== 'verif') writeFileSync(verif, '# verification design fixture\n')
}

// Extended (issue #127) to also unlink the register artifact -- unconditionally, since
// either a resume case (which seeds the file itself) or a write-eligible cold case (whose
// persistence responder creates it) can leave one behind; the wrapper needs no knowledge
// of the resolved `resume` value (feature design > API interface, *The rename's data flow*).
function removeDraftArtifacts(issue) {
  const { feature, verif, register } = artifactPaths(issue)
  for (const p of [feature, verif, register]) {
    try { unlinkSync(p) } catch (_) { /* not written for this run (omit case, or never created) */ }
  }
}

const runArch = (args, responder, opts = {}) => {
  const calls = []
  const { issue } = extractArgv(args)
  writeDraftArtifacts(issue, opts.omitArtifact)
  return arch(args, phase, parallel, makeAgent(responder, calls, opts.policyLoad), mockConsole)
    .then((result) => ({ result, calls }))
    .finally(() => removeDraftArtifacts(issue))
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

// Turn-model shorthands (issue #152). The Converge loop is TURN-based: sides alternate
// one-participant turns, Test AI first, so turn 2r-1 is the Test half of the r-th exchange and
// turn 2r its Dev half. `roundOf` recovers that exchange number from a turn label, which is what
// lets a fixture keep describing itself in exchanges while driving `test-t<N>` / `dev-t<N>` calls.
const roundOf = (label) => Math.ceil(Number(label.split('-t')[1]) / 2)
// A turn reports two facts and nothing else decides termination: whether it MODIFIED a design
// document and whether it ACCEPTs. Two consecutive unmodified accepts converge; anything else
// continues. `counters` / `accept_grounds` / `dispositions` are the deliberation's record only.
const ACCEPT_TURN = { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
const OPEN_TURN = { modified: false, accept: false, counters: [], accept_grounds: [], dispositions: [] }

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
// interception in `makeAgent` above) -- these three scenarios drive it directly via
// `opts.policyLoad` to lock the three fail-closed sentinels architect-deliberation.js
// derives from it (REASON_POLICY_LOAD_AGENT_MISSING / REASON_POLICY_ABSENT /
// REASON_POLICY_MALFORMED), each escalating with ITS OWN distinct cause.

await test('ARCHITECT: policy-load agent returns null (agent missing/errored) -> ESCALATE "spawn policy load agent missing"', async () => {
  const { result } = await runArch({ issue: 'policy-null' }, () => 'x', { policyLoad: null })
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'spawn policy load agent missing')
})

await test('ARCHITECT: policy-load returns found:false (file absent/empty) -> ESCALATE "spawn policy absent"', async () => {
  const { result } = await runArch({ issue: 'policy-absent' }, () => 'x', {
    policyLoad: { found: false, content: '' },
  })
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'spawn policy absent')
})

await test('ARCHITECT: policy-load content is not valid JSON -> ESCALATE "spawn policy malformed"', async () => {
  const { result } = await runArch({ issue: 'policy-malformed-json' }, () => 'x', {
    policyLoad: { found: true, content: 'not json' },
  })
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'spawn policy malformed')
})

await test('ARCHITECT: policy-load content parses but lacks this workflow\'s site table -> ESCALATE "spawn policy malformed"', async () => {
  const { result } = await runArch({ issue: 'policy-malformed-shape' }, () => 'x', {
    policyLoad: { found: true, content: JSON.stringify({ workflow_sites: { 'verify-cause-branch': {} } }) },
  })
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'spawn policy malformed')
})

await test('ARCHITECT: a valid policy-load (the real spawn-policy.json content, unmodified by any scenario) lets the run reach Draft normally', async () => {
  const { calls } = await runArch({ issue: 'policy-ok' }, (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return null
  })
  assert.ok(calls.some((c) => c.label === 'policy-load'), 'the policy-load call must have been made')
  assert.ok(calls.some((c) => c.label === 'dev-draft'), 'a valid default policy must let Draft proceed')
})

// ---- Issue #150 cycle 2 (F1 policy-row fail-closed totality) ------------------
// Verification design > .autoflow/issue-150-verification-design.md > §1 rows
// `required-row-omission-escalates` / `empty-site-table-fails-closed` /
// `fail-closed-precedes-work` / `required-key-declaration-join`'s ARCHITECT half. Every payload is
// derived from the REAL on-disk .claude/autoflow/spawn-policy.json (never a hand-written fixture),
// per §3's composition oracle.
// Eight site keys since issue #152 retired the cap-round closing half-round -- `test-closing` is
// no longer declared, no longer called, and carries no config row.
const ARCH_REQUIRED_KEYS = [
  'dev-draft', 'test-draft', 'register-load', 'test-round', 'dev-round',
  'ac-diff', 'ledger', 'register-write',
]
const VERIFY_REQUIRED_KEYS = ['test-self-check', 'impl-self-check', 'ledger']

function policyPayload(mutate) {
  const policy = JSON.parse(REAL_POLICY_CONTENT)
  mutate(policy)
  return { found: true, content: JSON.stringify(policy) }
}

for (const key of ARCH_REQUIRED_KEYS) {
  await test(`ARCHITECT: required row "${key}" deleted from workflow_sites.architect-deliberation -> ESCALATE with a policy-row cause, exactly [policy-load] issued, register not written (required-row-omission-escalates)`, async () => {
    const policyLoad = policyPayload((p) => { delete p.workflow_sites['architect-deliberation'][key] })
    const { result, calls } = await runArch(
      { issue: `policy-row-missing-${key}` },
      () => { throw new Error(`no sub-agent should be spawned under an incomplete policy (deleted "${key}")`) },
      { policyLoad },
    )
    assert.equal(result.verdict, 'ESCALATE', `deleting "${key}" must escalate`)
    assert.match(result.escalation, /policy/i, `escalation cause must name the policy, got: ${result.escalation}`)
    assert.equal(result.registerWritten, false, `deleting "${key}" must not write the register`)
    assert.deepEqual(
      calls.map((c) => c.label), ['policy-load'],
      `exactly one call (policy-load) may be issued when required row "${key}" is missing -- no Draft, no Ledger, no Register spawn -- got: ${JSON.stringify(calls.map((c) => c.label))}`,
    )
  })
}

await test('ARCHITECT: workflow_sites.architect-deliberation present but empty ({}) -> the same malformed-policy disposition as a single omission, not a draft-agent cause (empty-site-table-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { p.workflow_sites['architect-deliberation'] = {} })
  const { result, calls } = await runArch({ issue: 'policy-row-empty-table' }, () => null, { policyLoad })
  assert.equal(result.verdict, 'ESCALATE')
  assert.match(result.escalation, /policy/i, `escalation cause must name the policy, got: ${result.escalation}`)
  assert.doesNotMatch(result.escalation, /draft agent missing/i, 'an empty table must not be reported as a draft-agent-missing cause')
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('ARCHITECT: a REASON_DRAFT_AGENT_MISSING escalation (valid policy, Draft agent unreachable) still writes its ledger entry -- the Ledger suppression is keyed on policy-unusable, not on escalating at large (fail-closed-precedes-work non-regression)', async () => {
  const { result, calls } = await runArch({ issue: 'draft-agent-missing-still-ledgers' }, (label) => {
    if (label.endsWith('-draft')) return null // agent unreachable -> earlyEscalateReason set AFTER Draft, valid policy
    if (label === 'ledger') return 'ledger ok'
    return null
  })
  assert.equal(result.verdict, 'ESCALATE')
  assert.ok(calls.some((c) => c.label === 'ledger'), 'a valid-policy draft-agent-missing escalation must still spawn the Ledger call')
})

await test('ARCHITECT: required effort_contract absent -> the policy-unusable disposition, cause naming the contract, exactly [policy-load] issued (effort-contract-unusable-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { delete p.effort_contract })
  const { result, calls } = await runArch({ issue: 'policy-contract-absent' }, () => { throw new Error('no sub-agent should be spawned under an unusable effort_contract') }, { policyLoad })
  assert.equal(result.verdict, 'ESCALATE')
  assert.match(result.escalation, /contract/i, `escalation cause must name the contract, got: ${result.escalation}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

await test('ARCHITECT: effort_contract.config_inherit_sentinel empty string -> the policy-unusable disposition, exactly [policy-load] issued (effort-contract-unusable-fails-closed)', async () => {
  const policyLoad = policyPayload((p) => { p.effort_contract.config_inherit_sentinel = '' })
  const { result, calls } = await runArch({ issue: 'policy-contract-sentinel-empty' }, () => { throw new Error('no sub-agent should be spawned under an unusable effort_contract') }, { policyLoad })
  assert.equal(result.verdict, 'ESCALATE')
  assert.match(result.escalation, /contract/i, `escalation cause must name the contract, got: ${result.escalation}`)
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

// Turn ceilings are config values since issue #152: `deliberation_caps["architect-deliberation"]`
// carries `max_turns` / `bounded_max_turns`, and a payload without a valid caps row is unusable
// for the same fail-closed reason a missing site row is -- inventing a default here would restore
// the hardcoded literal the config exists to replace.
await test('ARCHITECT: deliberation_caps deleted from the policy -> ESCALATE with the caps cause, exactly [policy-load] issued (caps-row-omission-escalates)', async () => {
  const policyLoad = policyPayload((p) => { delete p.deliberation_caps })
  const { result, calls } = await runArch(
    { issue: 'policy-caps-missing' },
    () => { throw new Error('no sub-agent should be spawned under a policy carrying no turn ceilings') },
    { policyLoad },
  )
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'spawn policy deliberation caps incomplete (deliberation_caps.architect-deliberation)')
  assert.deepEqual(calls.map((c) => c.label), ['policy-load'])
})

for (const [name, mutate] of [
  ['max_turns below one full exchange', (p) => { p.deliberation_caps['architect-deliberation'].max_turns = 1 }],
  ['bounded_max_turns non-integer', (p) => { p.deliberation_caps['architect-deliberation'].bounded_max_turns = 2.5 }],
  ['the caps row is an array', (p) => { p.deliberation_caps['architect-deliberation'] = [12, 4] }],
]) {
  await test(`ARCHITECT: a caps row with ${name} is a config defect, not a small budget -> ESCALATE with the caps cause (caps-row-shape)`, async () => {
    const { result } = await runArch({ issue: `policy-caps-${name.replace(/\W+/g, '-')}` }, () => null, { policyLoad: policyPayload(mutate) })
    assert.equal(result.verdict, 'ESCALATE')
    assert.match(result.escalation, /spawn policy deliberation caps incomplete/)
  })
}

// Converges on the second exchange: turns 1-2 disagree, turns 3-4 are the unmodified accept pair.
function fullConvergenceResponder() {
  return (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
}

await test('ARCHITECT: site() reads the inherit sentinel from effort_contract.config_inherit_sentinel, not the bare literal -- a row carrying the REWRITTEN sentinel omits the effort key (workflow-sentinel-from-config, arm a)', async () => {
  const CUSTOM = 'CUSTOM_SENTINEL_XYZ'
  const policyLoad = policyPayload((p) => {
    p.effort_contract.config_inherit_sentinel = CUSTOM
    p.workflow_sites['architect-deliberation']['dev-draft'].effort = CUSTOM
  })
  const { calls } = await runArch({ issue: 'sentinel-rewrite-a' }, fullConvergenceResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'dev-draft')
  assert.ok(call, 'dev-draft must have been spawned under a valid rewritten contract')
  assert.equal('effort' in call.opts, false, `a row carrying the rewritten sentinel must omit the effort key, got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: under a REWRITTEN sentinel, a row still carrying the literal string "inherit" ships it as a CONCRETE effort value (workflow-sentinel-from-config, arm b)', async () => {
  const CUSTOM = 'CUSTOM_SENTINEL_XYZ'
  const policyLoad = policyPayload((p) => {
    p.effort_contract.config_inherit_sentinel = CUSTOM
    // test-draft keeps its shipped "inherit" value unchanged -- it is no longer the sentinel.
  })
  const { calls } = await runArch({ issue: 'sentinel-rewrite-b' }, fullConvergenceResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'test-draft')
  assert.ok(call, 'test-draft must have been spawned under a valid rewritten contract')
  assert.equal(call.opts.effort, 'inherit', `"inherit" under a rewritten contract must ship as a concrete effort value, got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: the real, unmodified shipped policy still passes the row-totality and effort_contract checks and reaches Draft (valid-policy-unaffected, F1 over-strictness)', async () => {
  const { result, calls } = await runArch({ issue: 'valid-policy-still-drafts' }, fullConvergenceResponder())
  assert.equal(result.verdict, 'CONVERGED')
  assert.ok(calls.some((c) => c.label === 'dev-draft'), 'the real policy must not be rejected by the new per-row/contract check')
})

// ---- Issue #150 cycle 3 (F4 effort-truthiness pass-through) --------------------
// Verification design > .autoflow/issue-150-verification-design.md > §1 rows
// `effort-zero-admitted` / `unadmitted-falsy-passes-through`, §2 "Workflow-script
// regression, ARCHITECT arm" / "Unadmitted-value pass-through". `site()` at
// architect-deliberation.js:595 decides "override vs inherit" by `row.effort &&
// row.effort !== inheritSentinel` -- a truthiness test that drops the contract-admitted
// concrete value `0`, indistinguishable from "no override". The fix compares against the
// sentinel ALONE. Both legs mutate the REAL on-disk config (policyPayload), per §3's
// composition oracle.
await test('ARCHITECT: a workflow_sites row carrying the contract-admitted concrete effort 0 reaches the spawn opts as 0, not silently dropped to inherit (effort-zero-propagates, ARCHITECT arm)', async () => {
  const policyLoad = policyPayload((p) => {
    p.workflow_sites['architect-deliberation']['dev-draft'].effort = 0
  })
  const { calls } = await runArch({ issue: 'effort-zero-propagates-arch' }, fullConvergenceResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'dev-draft')
  assert.ok(call, 'dev-draft must have been spawned under a valid policy')
  assert.equal('effort' in call.opts, true, `a row carrying the concrete effort 0 must NOT be treated as inherit (no effort key), got opts=${JSON.stringify(call.opts)}`)
  assert.equal(call.opts.effort, 0, `the concrete effort 0 must reach the spawn opts verbatim, got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: a workflow_sites row carrying an UNADMITTED falsy effort ("") reaches the spawn opts verbatim rather than degrading to inherit (unadmitted-falsy-passes-through, ARCHITECT arm)', async () => {
  const policyLoad = policyPayload((p) => {
    p.workflow_sites['architect-deliberation']['test-draft'].effort = ''
  })
  const { calls } = await runArch({ issue: 'unadmitted-falsy-passthrough-arch' }, fullConvergenceResponder(), { policyLoad })
  const call = calls.find((c) => c.label === 'test-draft')
  assert.ok(call, 'test-draft must have been spawned under a valid policy')
  assert.equal('effort' in call.opts, true, `an unadmitted falsy value must reach opts verbatim, not degrade to inherit (no effort key), got opts=${JSON.stringify(call.opts)}`)
  assert.equal(call.opts.effort, '', `the unadmitted value must reach the spawn opts verbatim (not coerced), got opts=${JSON.stringify(call.opts)}`)
})

await test('ARCHITECT: converges on the second exchange (turns 3+4 both unmodified accepts), ledger = mutual ACCEPT', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
  const { result, calls } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 4)
  assert.match(calls.find((c) => c.label === 'ledger').prompt, /ARCHITECT mutual ACCEPT/)
})

// Issue #152 Case A, replacing the retired "round-1 mutual ACCEPT is structurally blocked" test:
// the first-exchange devil's-advocate sentence is prompt guidance, not a convergence guard, so
// immediate agreement at turns 1 and 2 DOES converge. The mock runtime does not obey prompts,
// which is exactly why the structural outcome is what this suite can assert.
await test('ARCHITECT: immediate agreement — turns 1 and 2 both unmodified accepts converge at turn 2 (#152 Case A)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    return ACCEPT_TURN
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 2)
})

// The first turn of a run has no predecessor to pair with, so it can never converge alone --
// the one early-turn condition the termination rule still carries (issue #152).
await test('ARCHITECT: the first turn cannot converge alone — an accepting turn 1 followed by a non-accepting turn 2 runs on', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const t = Number(label.split('-t')[1])
    if (t === 2) return OPEN_TURN
    return ACCEPT_TURN
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 4, 'the accepting pair is turns 3+4, not the lone accepting turn 1')
})

// Replaces the retired "ACCEPT without grounds never converges": accept_grounds is a record
// field, not a termination input (issue #152). Persistent disagreement is what exhausts the
// ceiling now, and the ceiling is the config's `max_turns` (12), not a MAX_ROUNDS literal.
await test('ARCHITECT: persistent non-acceptance runs to the 12-turn ceiling -> ESCALATE + non-convergence ledger', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return OPEN_TURN
  }
  const { result, calls } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.turns, 12)
  assert.equal(result.escalation, 'No convergence within 12 turns (reached turn 12)')
  const ledger = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledger, /ARCHITECT non-convergence/)
  assert.doesNotMatch(ledger, /ARCHITECT mutual ACCEPT/)
})

// Replaces the retired "ACCEPT carrying open counters does not converge": counters no longer
// block convergence (they are record-only). What blocks it is a MODIFICATION — a turn that
// edited a design document owes the other side a review, whatever its `accept` says.
await test('ARCHITECT: a modifying accepting turn does not converge; the following unmodified pair does (#152 Case B)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const t = Number(label.split('-t')[1])
    if (t === 2) return { modified: true, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return ACCEPT_TURN
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 4, 'the modifying accept at turn 2 cannot terminate; turns 3+4 do')
})

await test('ARCHITECT: unresolved counter is threaded into the next exchange\'s prompts', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['SCHEMA_GAP_42'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '1' }, responder)
  assert.match(calls.find((c) => c.label === 'dev-t4').prompt, /SCHEMA_GAP_42/)
})

await test('ARCHITECT: missing args.issue throws at the boundary', async () => {
  await assert.rejects(
    () => arch(undefined, phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.issue is required/,
  )
})

await test('ARCHITECT: args delivered as a JSON string (real runtime form) resolves issue', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  // The Workflow runtime delivers args as a JSON STRING, not an object — pre-fix
  // this threw "args.issue is required"; the argv normalizer must resolve it.
  const { result } = await runArch(JSON.stringify({ issue: '7' }), responder)
  assert.match(result.artifacts[0], /issue-7-/)
})

await test('ARCHITECT: draft-null recorded as missing -> early ESCALATE', async () => {
  const responder = (label) => {
    if (label === 'dev-draft') return null // simulate skipped/errored draft sub-agent
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '845-1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.turns, 0, 'Converge loop must not be entered on a missing draft')
  assert.match(result.escalation, /draft agent missing/)
  assert.ok(!calls.some((c) => /-t\d/.test(c.label)), 'no Converge-round call should be made')
  const ledger = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledger, /missing/)
  assert.match(ledger, /ARCHITECT non-convergence/)
  assert.doesNotMatch(ledger, /ARCHITECT mutual ACCEPT/)
})

await test('ARCHITECT: both-null x2 consecutive -> early ESCALATE (budget not exhausted)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 || r === 2) return null // every turn of the first two exchanges is missing
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch({ issue: '845-2' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.turns, 2, 'must exit at the second consecutive null turn, not run to the 12-turn ceiling')
  assert.match(result.escalation, /sub-agent missing for 2 consecutive turn\(s\)/)
})

await test('ARCHITECT: single transient one-side-null still converges (regression-lock, not RED-discriminating)', async () => {
  // Turn 1 accepts, turn 2 is missing, turns 3+4 are the unmodified accept pair. The hole does
  // not early-exit (one null is transient, not a persistent infra failure) and it does not pair
  // across itself either: prevTurn is null after a missing turn (issue #152), so the two accepts
  // on either side of the gap — both test-side — never converge together.
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return null
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch({ issue: '845-3' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 4)
})

await test('ARCHITECT: draft non-null with a withheld artifact no longer early-ESCALATEs (regression lock on the §D7 capability removal, issue #62)', async () => {
  // REWRITTEN IN PLACE (issue #62, §D7/§D8) — was "draft non-null but artifact
  // missing -> early ESCALATE". The artifact-existence check (the
  // `import('node:fs')` block) is retired; this same driver (omitArtifact:
  // 'verif') must now converge normally instead of early-ESCALATEing.
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '845-4' }, responder, { omitArtifact: 'verif' })
  assert.equal(result.verdict, 'CONVERGED')
  assert.ok(result.turns > 0, 'Converge loop must be entered even when a draft artifact was withheld')
  assert.ok(!String(result.escalation ?? '').includes('draft artifact missing'))
  assert.ok(calls.some((c) => /-t\d/.test(c.label)), 'Converge-round calls must be made')
})

// ---- ARCHITECT: alternating test->dev turns + carry compaction + citation
// partitioning by mutability (issue #62) ----------------------------------
// Verification design §1/§5 (.autoflow/issue-62-verification-design.md). The
// 15 cases below are RED against the current concurrent-round script; several
// (marked in-line) pass vacuously pre-fix by construction — see the
// verification design's per-AC RED column for which.

await test('ARCHITECT: test-side call completes before the dev-side call is invoked (awaited-timer flag) (AC-62-1)', async () => {
  let testResolved = false
  let devSawTestResolved = null
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'test-t1') {
      return new Promise((resolve) => setTimeout(() => {
        testResolved = true
        resolve({ modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] })
      }, 15))
    }
    if (label === 'dev-t2') {
      devSawTestResolved = testResolved
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
    }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  await runArch({ issue: '62-1' }, responder)
  assert.equal(devSawTestResolved, true, 'dev-t2 must be invoked only after test-t1 has resolved')
})

await test('ARCHITECT: the Dev turn prompt carries the immediately-preceding Test turn counter token (AC-62-2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['TEST_PEER_TOKEN_62'], accept_grounds: [] }
    if (label === 'dev-t2') return { modified: false, accept: false, counters: ['dev-c1'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-2' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  assert.match(devR1, /TEST_PEER_TOKEN_62/)
})

await test('ARCHITECT: test-t3 cannot carry the not-yet-run dev-t4 token, and carries the dev-t2 one via ${carry} (AC-62-3)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: ['R1_DEV_TOKEN_62'], accept_grounds: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [] }
    if (label === 'dev-t4') return { modified: false, accept: false, counters: ['R2_DEV_TOKEN_62'], accept_grounds: [] }
    if (label === 'test-t3') return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-3' }, responder)
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  assert.doesNotMatch(testR2, /R2_DEV_TOKEN_62/)
  assert.match(testR2, /R1_DEV_TOKEN_62/)
})

await test('ARCHITECT: recorded call-log index of the Test turn precedes the Dev turn, every exchange (AC-62-4)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r < 3) return { modified: false, accept: false, counters: [`c${r}`], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-4' }, responder)
  // Alternation is by turn parity (issue #152): exchange r is turn 2r-1 (Test) then turn 2r (Dev).
  for (let r = 1; r <= 3; r++) {
    const testIdx = calls.findIndex((c) => c.label === `test-t${2 * r - 1}`)
    const devIdx = calls.findIndex((c) => c.label === `dev-t${2 * r}`)
    assert.ok(testIdx >= 0 && devIdx >= 0, `exchange ${r} calls must exist`)
    assert.ok(testIdx < devIdx, `exchange ${r}: test-t${2 * r - 1} (idx ${testIdx}) must precede dev-t${2 * r} (idx ${devIdx})`)
  }
})

await test('ARCHITECT: a missing Test turn still lets the Dev turn run, and does not pair across the gap (AC-62-8 new case)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1 && label.startsWith('test-')) return null
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '62-5' }, responder)
  assert.ok(calls.some((c) => c.label === 'dev-t2'), 'dev-t2 must still be invoked despite test-t1 being null')
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 3, 'turn 2 has a null predecessor and cannot converge; turns 2+3 are the first real pair')
})

// AC-62-9 ("carried counter argument prose tail is absent from both r2 prompts") is
// SUPERSEDED, not preserved: issue #67's register makes `conclusion` (ex-`argument`) the
// substantive field that DOES cross the round boundary (feature design §2.1 "conclusion is
// the substantive field", AC17) — the direct opposite of the old compactCounter-drop
// assumption this test locked. Verification design §2's `conclusion-crosses-boundary` row
// names this as the RED discriminator against compactCounter's argument drop
// (architect-deliberation.js:115-120, interpolated :184-185); §3 lists it among this
// cycle's RED discriminators. The old test is retired here rather than left in place, since
// keeping it would assert the property AC17 exists to reverse — a silent contradiction the
// per-test disposition table (feature design §4 item 2) did not separately enumerate.
await test('ARCHITECT: conclusion crosses the round boundary — a raised concern\'s argument/conclusion reaches the following turns\' prompts (AC17, conclusion-crosses-boundary)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [{ agenda: 'NAME_X_67', locator: 'LOC_X_67', argument: 'CONCLUSION_PROBE_67' }], accept_grounds: [], dispositions: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-conclusion' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  assert.match(devR2, /CONCLUSION_PROBE_67/, 'dev-t4 must carry the substantive conclusion content, not only the name/locator')
  assert.match(testR2, /CONCLUSION_PROBE_67/, 'test-t3 must carry the substantive conclusion content, not only the name/locator')
})

await test('ARCHITECT: no counter lost to compaction — every open counter agenda reaches the following turns\' prompts (AC-62-10)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [{ agenda: 'AGENDA_A_62', locator: 'a' }, { agenda: 'AGENDA_B_62', locator: 'b' }], accept_grounds: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: [{ agenda: 'AGENDA_C_62', locator: 'c' }], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-7' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  for (const tok of ['AGENDA_A_62', 'AGENDA_B_62', 'AGENDA_C_62']) {
    assert.ok(devR2.includes(tok), `dev-t4 must carry ${tok}`)
    assert.ok(testR2.includes(tok), `test-t3 must carry ${tok}`)
  }
})

await test('ARCHITECT: bare-string counter becomes a named register entry, name=string, evidence=unspecified (AC-62-11a re-anchored to the register / AC6)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: ['STALE_PROBE_62'], accept_grounds: [], dispositions: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-11a' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  for (const p of [devR2, testR2]) {
    assert.match(p, /STALE_PROBE_62/, 'the bare string becomes the entry name')
    assert.match(p, /unspecified/, 'evidence defaults to the unspecified placeholder')
  }
})

await test('ARCHITECT: record without agenda normalized via JSON.stringify(item), nothing dropped (AC-62-11b re-anchored to the register / AC6)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [{ locator: 'PARTIAL_PROBE_62' }], accept_grounds: [], dispositions: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-11b' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  for (const p of [devR2, testR2]) {
    assert.ok(p.includes('PARTIAL_PROBE_62'), 'the locator content must reach the register (as the item\'s own JSON.stringify name)')
  }
})

await test('ARCHITECT: null counter item renders as unspecified concern, never {} or undefined (AC-62-11c re-anchored to the register / AC6)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [null], accept_grounds: [], dispositions: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-11c' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  for (const p of [devR2, testR2]) {
    assert.match(p, /unspecified concern/)
    assert.doesNotMatch(p, /\{\}/)
    assert.doesNotMatch(p, /undefined/)
  }
})

await test('ARCHITECT: no character cap or truncation marker survives in the script or rendered register (AC5, no-truncation)', async () => {
  // Issue #67 discriminator: the operator's Scope discards the 80/120-char truncated
  // carry (feature design §2.6 Removed / AC5). Retires AC-62-12, which asserted exactly
  // the truncation behavior AC5 now forbids.
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  for (const literal of ['AGENDA_MAX', 'LOCATOR_MAX', 'TRUNCATION_MARKER', 'capField']) {
    assert.ok(!src.includes(literal), `${literal} must not survive in architect-deliberation.js`)
  }
  const longAgenda = 'A'.repeat(200)
  const longConclusion = 'C'.repeat(200)
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [{ agenda: longAgenda, locator: 'src/x.js:1', argument: longConclusion }], accept_grounds: [], dispositions: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-notrunc' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  for (const p of [devR2, testR2]) {
    assert.ok(!p.includes('…[truncated]'), 'no truncation marker literal may appear in a rendered prompt')
    assert.ok(p.includes(longAgenda), 'an over-long name must survive untruncated in the register')
    assert.ok(p.includes(longConclusion), 'an over-long conclusion must survive untruncated in the register')
  }
})

await test('ARCHITECT: dev-t2 prompt instructs section/item-ID citation for mutable design-doc targets (AC-62-15)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-12' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  assert.match(devR1, /cite it by section heading or item ID, never by line number/)
})

await test('ARCHITECT: dev-t2 prompt reserves path:line citation for immutable repository source (AC-62-16)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-13' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  assert.match(devR1, /reserve `path:line` for immutable repository source files/)
})

await test('ARCHITECT: DEV_OPEN_CONCERN_RULE (document-as-durable-channel) no longer reaches dev-t2 (AC8, open-concern-rule-gone)', async () => {
  // AC-62-28i deleted outright (its whole purpose is the mechanism AC8 removes). Retargeted
  // per feature design §5.1 test-contract-conflict: assert the literal phrase is gone from
  // the delivered script, not merely from one prompt.
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  assert.doesNotMatch(src, /record its argument as a named open-concern entry/)
})

await test('ARCHITECT: register no-relitigation instruction reaches both turn prompts, byte-identical, and neither Draft prompt (AC-62-28ii re-anchored to REGISTER_RULE / AC11b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-register-scope' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  // No exact prose is fixed by the feature design for the new REGISTER_RULE constant (unlike
  // the #56/#59 constants it is not a reword of prior text) -- assert the stated semantic
  // content instead: a re-litigation-guard sentence naming both the closed statuses and the
  // "not reopened without a new verified fact" rule, present identically on both round-1
  // prompts (AC11b: REGISTER_RULE is byte-identical in dev-r*/test-r*) and absent from Draft.
  const reopenPattern = /not (?:be )?reopen\w* without (?:a )?(?:newly )?verified fact/i
  assert.match(devR1, reopenPattern, 'dev-t2 must carry the no-relitigation instruction')
  assert.match(testR1, reopenPattern, 'test-t1 must carry the no-relitigation instruction')
  const devMatch = devR1.match(reopenPattern)[0]
  const testMatch = testR1.match(reopenPattern)[0]
  assert.equal(devMatch, testMatch, 'the no-relitigation instruction must be byte-identical across roles')
  assert.doesNotMatch(devDraft, reopenPattern, 'dev-draft must not carry the round-prompt-only register rule')
  assert.doesNotMatch(testDraft, reopenPattern, 'test-draft must not carry the round-prompt-only register rule')
})

// ---- ARCHITECT: issue register + disposition redesign (issue #67) -------------
// Verification design §2 (.autoflow/issue-67-verification-design.md). The register replaces
// the round-local open-counter carry: a concern raised on one turn and not disposed of must
// still reach the prompts two turns later (AC1), in place rather than duplicated (AC2), and a
// returned disposition must be able to flip its status (AC3) subject to raiser precedence
// (AC16) and admission rules (AC18). Each entry renders as four labelled lines plus a `---`
// terminator (AC4), with no character truncation (AC5, covered above) and no concern ever
// lost to normalization (AC6, covered above via the re-anchored AC-62-11a/b/c). None of
// these tests exist against the current carry-based script — every one is RED at HEAD.

await test('ARCHITECT: a raised, undisposed concern is still carried two exchanges later (AC1, register-carried)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_CARRIED_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    if (r === 2) return { modified: false, accept: false, counters: ['unrelated-c2'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-carried' }, responder)
  for (const label of ['dev-t4', 'test-t3', 'dev-t6', 'test-t5']) {
    const prompt = calls.find((c) => c.label === label).prompt
    assert.match(prompt, /NAME_CARRIED_67/, `${label} must still carry the undisposed concern`)
  }
})

await test('ARCHITECT: a resolved entry stays in the register alongside a fresh one — non-cumulative reassignment discriminator (AC2, register-cumulative)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_X_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return {
        modified: false, accept: false,
        counters: [{ agenda: 'NAME_Y_67', locator: 'l2', argument: 'a2' }],
        accept_grounds: [],
        dispositions: [{ name: 'NAME_X_67', conclusion: 'resolved', evidence: 'e', status: 'agreed' }],
      }
    }
    if (r === 2) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-cumulative' }, responder)
  const devR3 = calls.find((c) => c.label === 'dev-t6').prompt
  const testR3 = calls.find((c) => c.label === 'test-t5').prompt
  for (const p of [devR3, testR3]) {
    assert.match(p, /NAME_X_67/, 'the resolved entry must not be dropped by a wholesale reassignment')
    assert.match(p, /NAME_Y_67/, 'the fresh entry raised alongside the disposition must also be carried')
  }
})

await test('ARCHITECT: same name raised twice merges into one entry — in-place update, not duplication (AC2, near-miss-names-stay-distinct part 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) {
      return {
        modified: false, accept: false,
        counters: [
          { agenda: 'Register key', locator: 'l1', argument: 'a1' },
          { agenda: 'register  key', locator: 'l2', argument: 'a2' },
        ],
        accept_grounds: [],
        dispositions: [],
      }
    }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-nearmiss1' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const nameLines = devR2.match(/^name: .*$/gm) || []
  assert.equal(nameLines.length, 1, 'case/whitespace near-miss names must merge into a single entry')
  assert.match(devR2, /^name: Register key$/m, 'the merged entry keeps the first-raised display name')
})

await test('ARCHITECT: names differing by content stay distinct entries (AC2, near-miss-names-stay-distinct part 2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) {
      return {
        modified: false, accept: false,
        counters: [
          { agenda: 'Register key A', locator: 'l1', argument: 'a1' },
          { agenda: 'Register key B', locator: 'l2', argument: 'a2' },
        ],
        accept_grounds: [],
        dispositions: [],
      }
    }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-nearmiss2' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const nameLines = devR2.match(/^name: .*$/gm) || []
  assert.equal(nameLines.length, 2, 'names differing by content must not merge')
  assert.match(devR2, /^name: Register key A$/m)
  assert.match(devR2, /^name: Register key B$/m)
})

await test('ARCHITECT: register block grows linearly — N distinct names produce N name-lines and N terminators (§2.3 register growth, observation lock)', async () => {
  for (const n of [1, 2, 3]) {
    const names = Array.from({ length: n }, (_, i) => `GROWTH_${n}_${i}_67`)
    const responder = (label) => {
      if (label.endsWith('-draft')) return 'drafted'
      if (label === 'ledger') return 'ledger ok'
      const r = roundOf(label)
      if (r === 1 && label.startsWith('dev-')) {
        return {
          modified: false, accept: false,
          counters: names.map((agenda) => ({ agenda, locator: 'l', argument: 'a' })),
          accept_grounds: [],
          dispositions: [],
        }
      }
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    }
    const { calls } = await runArch({ issue: `67-growth-${n}` }, responder)
    const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
    const nameLines = devR2.match(/^name: .*$/gm) || []
    const terminators = devR2.match(/^---$/gm) || []
    assert.equal(nameLines.length, n, `N=${n}: name-line count must equal entry count`)
    assert.equal(terminators.length, n, `N=${n}: terminator count must equal entry count exactly (N × 5 lines per entry)`)
  }
})

await test('ARCHITECT: a rendered entry is four labelled lines + one terminator; embedded whitespace is flattened (AC4, entry-shape)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) {
      return {
        modified: false, accept: false,
        counters: [{ agenda: 'NAME_WS_67', locator: 'a\tb  c', argument: 'line1\nline2\r\nline3   end' }],
        accept_grounds: [],
        dispositions: [],
      }
    }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-entryshape' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const m = devR2.match(/^name: NAME_WS_67\nconclusion: ([^\n]*)\nevidence: ([^\n]*)\nstatus: ([^\n]*)\n---$/m)
  assert.ok(m, 'the entry must render as exactly four labelled lines followed by one terminator line')
  assert.equal(m[1], 'line1 line2 line3 end', 'embedded newlines/CRLF/space-runs in conclusion must collapse to single spaces')
  assert.equal(m[2], 'a b c', 'embedded tabs/space-runs in evidence must collapse to single spaces')
})

await test('ARCHITECT: a field whose flattened value is exactly "---" renders as a labelled content line, not a delimiter (AC4, entry-shape part 2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) {
      return { modified: false, accept: false, counters: [{ agenda: 'NAME_DASH_67', locator: 'l', argument: '---' }], accept_grounds: [], dispositions: [] }
    }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-dashfield' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  assert.match(devR2, /^conclusion: ---$/m, 'a field whose value is exactly the delimiter literal must still render as a labelled content line')
  const terminators = devR2.match(/^---$/gm) || []
  assert.equal(terminators.length, 1, 'the delimiter-valued field line must not be double-counted as a terminator')
})

await test('ARCHITECT: a returned disposition sets the entry status, which survives to the next round (AC3, disposition-applied)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_DISP_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_DISP_67', conclusion: 'fixed', evidence: 'e', status: 'agreed' }] }
    }
    if (r === 2) return { modified: false, accept: false, counters: ['stay-open'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-dispapplied' }, responder)
  // The register is updated after every turn (issue #152), so the disposition returned by the Dev
  // turn 4 is already visible to the very next turn's prompt.
  const testT5 = calls.find((c) => c.label === 'test-t5').prompt
  assert.match(testT5, /name: NAME_DISP_67[\s\S]{0,120}status: agreed/, 'the disposed entry must reach the next turn showing its new status')
})

await test('ARCHITECT: turn-report schema — TURN.required, additionalProperties, and the closed DISPOSITION item shape (AC15, disposition-schema-shape)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  // TURN replaced VERDICT in issue #152: the retired `response` verdict enum is gone and the two
  // termination facts `modified` / `accept` are required alongside the record fields.
  const turnMatch = src.match(/const TURN = \{[\s\S]*?\n\}/)
  assert.ok(turnMatch, 'TURN constant must exist')
  assert.match(turnMatch[0], /additionalProperties:\s*false/, 'TURN must keep additionalProperties: false')
  assert.doesNotMatch(turnMatch[0], /response:/, 'the retired ACCEPT/COUNTER/PARTIAL verdict field must not survive in TURN')
  for (const field of ['modified', 'accept', 'counters', 'accept_grounds', 'dispositions']) {
    assert.match(turnMatch[0], new RegExp(`required:\\s*\\[[^\\]]*['"]${field}['"]`), `TURN.required must name ${field}`)
  }
  const dispositionMatch = src.match(/const DISPOSITION = \{[\s\S]*?\n\}/)
  assert.ok(dispositionMatch, 'a DISPOSITION constant must exist')
  const seg = dispositionMatch[0]
  assert.match(seg, /additionalProperties:\s*false/)
  for (const field of ['name', 'conclusion', 'evidence', 'status']) {
    assert.match(seg, new RegExp(`required:\\s*\\[[^\\]]*['"]${field}['"]`), `DISPOSITION.required must name ${field}`)
  }
  assert.match(seg, /enum:\s*\[\s*['"]agreed['"]\s*,\s*['"]rejected['"]\s*\]/, 'status enum must be exactly [agreed, rejected]')

  // Behavioral half: an all-empty-dispositions run still converges without a schema error.
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result } = await runArch({ issue: '67-schema' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: a disposition naming an entry no one raised is ignored — never minted, never reaches the ledger (AC18, disposition-admission part 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_REAL_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('test-')) {
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NEVER_RAISED_67', conclusion: 'c', evidence: 'e', status: 'rejected' }] }
    }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result, calls } = await runArch({ issue: '67-admission1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  const devR3 = calls.find((c) => c.label === 'dev-t6')
  const testR3 = calls.find((c) => c.label === 'test-t5')
  for (const c of [devR3, testR3].filter(Boolean)) {
    assert.doesNotMatch(c.prompt, /NEVER_RAISED_67/, 'an unresolvable disposition name must never be minted into the register')
  }
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.doesNotMatch(ledgerPrompt, /NEVER_RAISED_67/, 'an unresolvable disposition must never reach the append-only ledger')
})

await test('ARCHITECT: an out-of-enum disposition status is ignored — the entry keeps its prior status (AC18, disposition-admission part 2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_ENUM_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_ENUM_67', conclusion: 'c1', evidence: 'e1', status: 'agreed' }] }
    }
    if (r === 2) return { modified: false, accept: false, counters: ['stay-open'], accept_grounds: [], dispositions: [] }
    if (r === 3 && label.startsWith('dev-')) {
      return { modified: false, accept: false, counters: ['still-going'], accept_grounds: [], dispositions: [{ name: 'NAME_ENUM_67', conclusion: 'c2', evidence: 'e2', status: 'open' }] }
    }
    if (r === 3) return { modified: false, accept: false, counters: ['stay-open-2'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-admission2' }, responder)
  const devR4 = calls.find((c) => c.label === 'dev-t8').prompt
  assert.match(devR4, /name: NAME_ENUM_67[\s\S]{0,120}status: agreed/, 'a status outside the enum must be ignored — the entry keeps its last valid status')
})

await test('ARCHITECT: a disposition with a missing/non-string name is ignored without throwing (AC18, disposition-admission part 3)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_SHAPE_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 123, conclusion: 'c', evidence: 'e', status: 'agreed' }] }
    }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  await assert.doesNotReject(() => runArch({ issue: '67-admission3' }, responder))
})

await test('ARCHITECT: only the raiser\'s side can close an entry — a peer disposition proposes but leaves it open (AC16, raiser-precedence)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('test-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_PREC_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      // dev is the PEER here (test raised it) — a peer disposition must not close it.
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_PREC_67', conclusion: 'PEER_FIX_67', evidence: 'e', status: 'agreed' }] }
    }
    if (r === 2) return { modified: false, accept: false, counters: ['stay-open'], accept_grounds: [], dispositions: [] }
    if (r === 3 && label.startsWith('test-')) {
      // test is the RAISER — its own disposition closes it. It keeps countering so the run does
      // not converge on this turn and the following Dev turn's prompt is still rendered.
      return { modified: false, accept: false, counters: ['keep-going'], accept_grounds: [], dispositions: [{ name: 'NAME_PREC_67', conclusion: 'PEER_FIX_67', evidence: 'e', status: 'agreed' }] }
    }
    if (r === 3) return { modified: false, accept: false, counters: ['stay-open-2'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-precedence' }, responder)
  // test-t5 is rendered after the peer's turn-4 disposition and before the raiser's own on turn 5.
  const testT5 = calls.find((c) => c.label === 'test-t5').prompt
  assert.match(testT5, /name: NAME_PREC_67[\s\S]{0,120}status: open/, 'a peer disposition must leave the entry open')
  assert.match(testT5, /PEER_FIX_67/, 'the peer\'s proposed conclusion/evidence must still be carried, even though status stays open')
  const devT6 = calls.find((c) => c.label === 'dev-t6').prompt
  assert.match(devT6, /name: NAME_PREC_67[\s\S]{0,120}status: agreed/, 'the raiser\'s own disposition must close the entry')
})

await test('ARCHITECT: both sides ACCEPT with empty counters while an entry is still open still CONVERGES (AC7b, converge-unaffected-by-open-entry)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_SILENT_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result } = await runArch({ issue: '67-silentconverge' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 4, 'convergence must not be blocked by an entry no one ever disposed of')
})

await test('ARCHITECT: both turn prompts render every open entry and instruct disposal before an accept (AC7, open-entries-rendered-and-disposal-instructed)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_OPEN2_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: false, counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-opendisposal' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  const disposalPattern = /dispos\w*[^\n]{0,80}(?:before|prior to)[^\n]{0,20}ACCEPT/i
  for (const p of [devR2, testR2]) {
    assert.match(p, /name: NAME_OPEN2_67[\s\S]{0,120}status: open/, 'the open entry must be rendered')
    assert.match(p, disposalPattern, 'the round prompt must instruct disposal of every open entry before ACCEPT')
  }
})

await test('ARCHITECT: CONVERGED ledger names authority "ARCHITECT rejected" and carries the rejected entry (AC10, ledger-rejected-authority part 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1 && label.startsWith('dev-')) return { modified: false, accept: false, counters: [{ agenda: 'NAME_REJ_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_REJ_67', conclusion: 'not valid', evidence: 'e', status: 'rejected' }] }
    }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result, calls } = await runArch({ issue: '67-ledgerrejected' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /ARCHITECT rejected/)
  assert.match(ledgerPrompt, /NAME_REJ_67/)
})

await test('ARCHITECT: ESCALATE still appends exactly one outcome entry, never the rejected authority (AC10, ledger-rejected-authority part 2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return OPEN_TURN // never accepts -> never converges (issue #152: accept_grounds is a record field, not a termination input)
  }
  const { result, calls } = await runArch({ issue: '67-ledgeresc' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /EXACTLY ONE/)
  assert.doesNotMatch(ledgerPrompt, /ARCHITECT rejected/)
})

await test('ARCHITECT: ESCALATE grounds carry the rendered open entries, never reference openCounters (AC10b, escalate-grounds-present part 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [{ agenda: 'NAME_ESC_67', locator: 'l', argument: 'GROUNDS_PROBE_67' }], accept_grounds: [], dispositions: [] }
    return { modified: false, accept: false, counters: ['still-open'], accept_grounds: [], dispositions: [] } // never accepts -> ESCALATE at the turn ceiling
  }
  const { result, calls } = await runArch({ issue: '67-escgrounds' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /NAME_ESC_67/, 'the grounds must carry the open entry\'s name')
  assert.match(ledgerPrompt, /GROUNDS_PROBE_67/, 'the grounds must carry the open entry\'s conclusion, not just its name')
  assert.doesNotMatch(ledgerPrompt, /openCounters/, 'the retired openCounters identifier must not leak into the ledger prompt')
})

await test('ARCHITECT: an early ESCALATE with no open entry still has non-empty grounds (AC10b, escalate-grounds-present part 2)', async () => {
  const responder = (label) => {
    if (label === 'dev-draft') return null // forces earlyEscalateReason before any Converge round
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result, calls } = await runArch({ issue: '67-escnoopen' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /draft agent missing/, 'grounds must carry the escalation reason when the register holds no open entry')
  assert.doesNotMatch(ledgerPrompt, /openCounters/)
})

await test('ARCHITECT: LEDGER_SEED_RULE reaches both Draft prompts only, instructing prior ledger entries as non-reopenable (AC11, ledger-seed-rule-drafts-only)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-ledgerseed' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  for (const p of [devDraft, testDraft]) {
    assert.match(p, /ARCHITECT mutual ACCEPT/, 'the Draft prompt must instruct treating prior mutual-ACCEPT ledger entries as non-reopenable')
    assert.match(p, /ARCHITECT rejected/, 'the Draft prompt must instruct treating prior rejected ledger entries as non-reopenable')
  }
  for (const p of [devR1, testR1]) {
    assert.doesNotMatch(p, /ARCHITECT mutual ACCEPT/, 'the ledger-seed rule is Draft-only, not round-prompt')
  }
})

await test('ARCHITECT: RECORD_DISCIPLINE_RULE reaches all four prompts — no transcription, design-only documents, readable naming (AC8/AC9)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-recorddiscipline' }, responder)
  const noTranscription = /(?:measurement logs?|command output|code text)[\s\S]{0,80}(?:never|not)[\s\S]{0,40}(?:copie|transcri|paste)/i
  const designOnly = /design documents?[\s\S]{0,80}(?:only|current design)/i
  const readableNaming = /short[\s\S]{0,20}name/i
  const noTotals = /no totals?(?:\/| or )counts?|totals? (?:and|or) counts? (?:are )?(?:never|not)/i
  for (const label of ['dev-draft', 'test-draft', 'dev-t2', 'test-t1']) {
    const p = calls.find((c) => c.label === label).prompt
    assert.match(p, noTranscription, `${label} must forbid transcribing measurement logs/command output/code text`)
    assert.match(p, designOnly, `${label} must require design documents to hold only the current design`)
    assert.match(p, readableNaming, `${label} must require short readable names`)
    assert.match(p, noTotals, `${label} must forbid writing totals/counts into the documents`)
  }
})

await test('ARCHITECT: REGISTER_RULE does not duplicate the dual-disposition phrase into turn 1 (AC20, carry-text-locks-preserved part b)', async () => {
  // Complements the untouched AC-56-14b lock (round-1 doesNotMatch on the whole prompt):
  // pins the constraint at its SOURCE declaration, per verification design §5.4's
  // half (b) rationale, so REGISTER_RULE's own wording — which reaches round 1 — cannot
  // silently collide with the carry-conditional phrase AC-56-14b locks.
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const registerRuleMatch = src.match(/const REGISTER_RULE = [^\n]*(?:\n(?!const )[^\n]*)*/)
  assert.ok(registerRuleMatch, 'a REGISTER_RULE constant must exist')
  assert.doesNotMatch(registerRuleMatch[0], /by dismissing it with the current/, 'REGISTER_RULE must state disposal in its own words, not the carry-conditional phrase')
})

// ---- ARCHITECT: carry-channel evidence discipline (issue #56) -----------------
// Verification design §1 AC-56-1b/2b/3b/4b/5/14b (.autoflow/issue-56-verification-design.md).
// A1 = 'are a checklist of topics to re-verify, NOT evidence', A2 = 'may already be resolved'
// (the non-evidentiary / staleness carry framing, D3: conditional on carry). A6 = 'by
// dismissing it with the current' (D4 dual disposition, also carry-conditional). The citation
// rule (A3 trimmed + A7 absence-case escape) is D3 unconditional — delivered on every turn
// including turn 1, where `carry` is empty.
//
// Re-anchored to turns (issue #152): under alternating one-participant turns the register is
// already non-empty for the Dev turn 2 when the Test turn 1 raised a counter, so turn 1 — not
// "round 1" — is the only turn whose carry is structurally empty.

await test('ARCHITECT: carry framing (A1 non-evidentiary + A2 staleness) delivered from turn 2 on, both roles (AC-56-1b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['STALE_PROBE_56'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-1' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = calls.find((c) => c.label === 'test-t3').prompt
  assert.match(devR2, /are a checklist of topics to re-verify, NOT evidence/)
  assert.match(devR2, /may already be resolved/)
  assert.match(testR2, /are a checklist of topics to re-verify, NOT evidence/)
  assert.match(testR2, /may already be resolved/)
})

await test('ARCHITECT: carry framing absent on turn 1 (no counters raised yet) (AC-56-2b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['STALE_PROBE_56'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-2' }, responder)
  const testT1 = calls.find((c) => c.label === 'test-t1').prompt
  assert.doesNotMatch(testT1, /are a checklist of topics to re-verify, NOT evidence/)
  assert.doesNotMatch(testT1, /may already be resolved/)
})

await test('ARCHITECT: citation rule + absence-case escape delivered to dev on its first turn (AC-56-3b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-3' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  assert.match(devR1, /re-read the counterpart document/)
  assert.match(devR1, /name the section where it would belong/)
})

await test('ARCHITECT: citation rule + absence-case escape delivered to test on its first turn (AC-56-4b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-4' }, responder)
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  assert.match(testR1, /re-read the counterpart document/)
  assert.match(testR1, /name the section where it would belong/)
})

await test('ARCHITECT: evidence-discipline segment byte-identical between the Test and Dev first turns (AC-56-5)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-5' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  // Anchor-delimited extraction (verification design §1 AC-56-5): the substring between the two
  // literal anchors shared verbatim by both turn prompts. Re-anchored for issue #152 — the old
  // start anchor sat inside the retired ACCEPT/COUNTER verdict instruction. The shared tail begins
  // at COUNTER_EVIDENCE_RULE, which both sides interpolate byte-identically.
  const extract = (s) => {
    const startAnchor = ' Before raising or sustaining any counter'
    const endAnchor = ' Run every Bash command'
    const start = s.indexOf(startAnchor)
    assert.ok(start >= 0, 'the counter-evidence anchor must be present')
    const end = s.indexOf(endAnchor)
    return s.slice(start, end)
  }
  const devSeg = extract(devR1)
  const testSeg = extract(testR1)
  assert.ok(devSeg.length > 0, 'dev evidence-discipline segment must be non-empty')
  assert.equal(devSeg, testSeg)
})

await test('ARCHITECT: dual-disposition clause (A6) delivered only when counters are carried (AC-56-14b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['STALE_PROBE_56'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-6' }, responder)
  const testT1 = calls.find((c) => c.label === 'test-t1').prompt
  const devT2 = calls.find((c) => c.label === 'dev-t2').prompt
  const testT3 = calls.find((c) => c.label === 'test-t3').prompt
  assert.match(devT2, /by dismissing it with the current/)
  assert.match(testT3, /by dismissing it with the current/)
  assert.doesNotMatch(testT1, /by dismissing it with the current/, 'turn 1 is the only turn with an empty register')
})

// ---- ARCHITECT: adoption-side evidence discipline (issue #59) -----------------
// Characteristic substrings of ADOPTION_EVIDENCE_RULE (feature design §4.1's constant
// block — cited by section per DCR-11, not by a path:line that restales as the document
// under revision grows).
const ADOPTION_A8 = 'is a re-verification checklist, not a fact, and its phrasing is not a source derivation'
const ADOPTION_A9 = 'whether you raise it as a counter or accept it'
const ADOPTION_A10 = 're-derive it from the current source and cite'

await test('ARCHITECT: adoption-evidence rule reaches dev-draft (AC-59-1b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-1' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  assert.ok(devDraft.includes(ADOPTION_A8), 'dev-draft must carry A8')
  assert.ok(devDraft.includes(ADOPTION_A9), 'dev-draft must carry A9')
})

await test('ARCHITECT: adoption-evidence rule reaches test-draft (AC-59-2b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-2' }, responder)
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  assert.ok(testDraft.includes(ADOPTION_A8), 'test-draft must carry A8')
  assert.ok(testDraft.includes(ADOPTION_A9), 'test-draft must carry A9')
})

await test('ARCHITECT: adoption-evidence rule reaches the Dev turn, carry empty (AC-59-3b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-3' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  assert.ok(devR1.includes(ADOPTION_A8), 'dev-t2 must carry A8')
  assert.ok(devR1.includes(ADOPTION_A9), 'dev-t2 must carry A9')
  assert.ok(devR1.includes(ADOPTION_A10), 'dev-t2 must carry A10')
})

await test('ARCHITECT: adoption-evidence rule reaches test-t1 (AC-59-4b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-4' }, responder)
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  assert.ok(testR1.includes(ADOPTION_A8), 'test-t1 must carry A8')
  assert.ok(testR1.includes(ADOPTION_A9), 'test-t1 must carry A9')
  assert.ok(testR1.includes(ADOPTION_A10), 'test-t1 must carry A10')
})

await test('ARCHITECT: adoption-evidence delivery is unconditional, not carry-gated (AC-59-5b)', async () => {
  const countOccurrences = (s, sub) => s.split(sub).length - 1

  // Part (i): an r1-COUNTER run converges at round 2 — A9 must reach dev-t4/test-t3,
  // exactly once per prompt (guards accidental double-interpolation once carry is non-empty).
  const counterResponder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['STALE_PROBE_59'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls: counterCalls } = await runArch({ issue: '59-5a' }, counterResponder)
  const devR2 = counterCalls.find((c) => c.label === 'dev-t4').prompt
  const testR2 = counterCalls.find((c) => c.label === 'test-t3').prompt
  assert.equal(countOccurrences(devR2, ADOPTION_A9), 1, 'dev-t4 must carry A9 exactly once')
  assert.equal(countOccurrences(testR2, ADOPTION_A9), 1, 'test-t3 must carry A9 exactly once')

  // Part (ii) — the discriminator: a run that raises no counter at all keeps the register (and so
  // the carry) empty for every turn up to the 12-turn ceiling. A9 must still reach dev-t2 AND
  // dev-t12 — a carry-gated implementation would pass 3b/4b/5b(i) and fail here.
  const noCarryResponder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return OPEN_TURN
  }
  const { calls: noGroundsCalls } = await runArch({ issue: '59-5b' }, noCarryResponder)
  const devR1 = noGroundsCalls.find((c) => c.label === 'dev-t2').prompt
  const devR6 = noGroundsCalls.find((c) => c.label === 'dev-t12').prompt
  assert.ok(devR1, 'dev-t2 call must exist')
  assert.ok(devR6, 'dev-t12 call must exist (every turn runs when no pair of unmodified accepts occurs)')
  assert.ok(devR1.includes(ADOPTION_A9), 'dev-t2 must carry A9 unconditionally')
  assert.ok(devR6.includes(ADOPTION_A9), 'dev-t12 must carry A9 unconditionally')
})

await test('ARCHITECT: adoption-evidence Draft segment byte-identical across dev/test (AC-59-6b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-6' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  // Anchor-delimited extraction (verification design §5.3 item 6): the opening phrase of
  // the constant, not A8 (which sits mid-constant and would drop the channel-list prefix
  // an asymmetric channel list needs to be caught by).
  const startAnchor = ' Text that reaches this deliberation from outside'
  const endAnchor = ' Run every Bash command'
  const extract = (s) => {
    const start = s.indexOf(startAnchor)
    assert.ok(start >= 0, 'start anchor must be present')
    const end = s.indexOf(endAnchor)
    return s.slice(start, end)
  }
  const devSeg = extract(devDraft)
  const testSeg = extract(testDraft)
  assert.ok(devSeg.length > 0, 'dev adoption-evidence Draft segment must be non-empty')
  assert.equal(devSeg, testSeg)
})

// ---- ARCHITECT: verification-depth justification (issue #69) ------------------
// The depth obligation (docs/autoflow-guide.md > ARCHITECT > Output artifacts >
// Verification depth) is Test-AI-owned: it must reach the executing agent through the
// Test-AI Draft prompt AND the Test-AI round prompt's ACCEPT condition (verification
// design AC:prompt-delivery / AC:accept-gating), not merely be defined in the script —
// only driving the script with the mock agent and reading the delivered prompt by label
// can distinguish *defined* from *delivered* (the text-matching registry/cycle-suite
// layers cannot).

await test('ARCHITECT: verification-depth OBLIGATION TEXT (not just the section path) reaches test-draft and test-t1, and stays off dev-draft/dev-t2 (AC-69-prompt-delivery)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '69-1' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  const devR1 = calls.find((c) => c.label === 'dev-t2').prompt
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  // The obligation's own content ("...names the failure mode it catches that no other layer
  // catches..."), not merely a "docs/autoflow-guide.md > ... > Verification depth" section-path
  // reference -- a path-only literal is satisfiable by an unrelated cross-reference and would not
  // discriminate "defined" from "the obligation's substance actually delivered".
  const obligationPattern = /failure mode (?:it catches |no other layer catches|that no other layer catches)/
  assert.match(testDraft, obligationPattern, 'test-draft must carry the Verification depth obligation TEXT')
  assert.match(testR1, obligationPattern, 'test-t1 must carry the Verification depth obligation TEXT')
  // ADR-0018 Decision 3: "The obligation is Test-AI-owned; no Developer-AI literal is added." --
  // negative fence mirroring the #56/#59 doesNotMatch idiom (:534-536, :1032-1035).
  assert.doesNotMatch(devDraft, obligationPattern, 'dev-draft must NOT carry the Verification depth obligation (Test-AI-owned, ADR-0018 Decision 3)')
  assert.doesNotMatch(devR1, obligationPattern, 'dev-t2 must NOT carry the Verification depth obligation (Test-AI-owned, ADR-0018 Decision 3)')
})

await test('ARCHITECT: test-t1 ACCEPT-condition sentence (not merely the prompt at large) gates on the per-layer unique-failure-mode requirement (AC-69-accept-gating)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '69-2' }, responder)
  const testR1 = calls.find((c) => c.label === 'test-t1').prompt
  // Extract the ACCEPT-condition sentence specifically -- the verification design's method is
  // "the ACCEPT-condition sentence of the test-r{n} prompt carries the depth clause", and advisory
  // (mentioned anywhere in the prompt) vs. gating (inside the sentence that actually governs
  // ACCEPT) is the discriminant a prompt-wide `.includes()` cannot make.
  // Re-anchored for issue #152: the accept condition is now stated as a `"accept"` boolean
  // instruction, the ACCEPT/COUNTER/PARTIAL verdict enum having been retired.
  const startAnchor = 'Set "accept" true ONLY when'
  const endAnchor = 'Otherwise set "accept" false'
  const start = testR1.indexOf(startAnchor)
  const end = testR1.indexOf(endAnchor)
  assert.ok(start >= 0, 'ACCEPT-condition start anchor must be present')
  assert.ok(end > start, 'ACCEPT-condition end anchor must be present and follow the start anchor')
  const acceptSentence = testR1.slice(start, end)
  assert.match(acceptSentence, /unique failure mode no other layer catches/, 'the ACCEPT-condition sentence itself must gate on the unique-failure-mode requirement, not merely mention it elsewhere in the prompt')
})

// ---- ARCHITECT: prose-args salvage (issue #14) --------------------------------

await test('ARCHITECT: prose args, hashed number (reported shape) resolves and converges', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
  const { result } = await runArch('issue #215 — architect deliberation for the caching layer', responder)
  assert.match(result.artifacts[0], /issue-215-/)
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: prose args, hash + incidental leading digit resolves 215 not 2 (DCR-2(a) lock)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch('v2 caching for issue #215', responder)
  assert.match(result.artifacts[0], /issue-215-/)
})

await test('ARCHITECT: valid-JSON string without issue still fails loudly (DCR-2(b) lock)', async () => {
  await assert.rejects(
    () => arch('{"other":"215"}', phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.issue is required/,
  )
})

await test('ARCHITECT: prose args, bare number, no hash resolves via fallback', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch('deliberation for issue 215', responder)
  assert.match(result.artifacts[0], /issue-215-/)
})

await test('ARCHITECT: prose args, no hash + incidental earlier digit resolves 215 not 2 — reviewer witness fix lock (c2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch('v2 caching for issue 215', responder)
  assert.match(result.artifacts[0], /issue-215-/)
  assert.doesNotMatch(result.artifacts[0], /issue-2-/)
})

await test('ARCHITECT: prose args, no extractable digits still fails loudly', async () => {
  await assert.rejects(
    () => arch('please run the architect deliberation', phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.issue is required/,
  )
})

await test('ARCHITECT: prose args, >=2 bare digit runs, no #/no issue-label — ambiguity loud-fail (c2, NEW)', async () => {
  await assert.rejects(
    () => arch('v2 build 42 for the caching layer', phase, parallel, makeAgent(() => 'x', []), mockConsole),
    /args\.issue is required/,
  )
})

await test('ARCHITECT: prose args, single bare digit, no #/no issue-label — tier-3 unique-adopt success (c2, NEW)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch('build 42', responder)
  assert.match(result.artifacts[0], /issue-42-/)
  assert.equal(result.verdict, 'CONVERGED')
})

// A responder that never converges, so a run always reaches its own turn ceiling. It replaces
// the retired `capResponder` (issue #123's cap-round closing half-round, removed by #152): what
// remains of that fixture's job is simply "drive every turn to the ceiling", with per-label
// overrides for the turns a case wants to shape.
function ceilingResponder(overrides = {}) {
  return (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    if (Object.prototype.hasOwnProperty.call(overrides, label)) return overrides[label]
    return { modified: false, accept: false, counters: [`c${roundOf(label)}`], accept_grounds: [], dispositions: [] }
  }
}

// ---- ARCHITECT: resume an ESCALATEd deliberation from its register (issue #127) ---
// Verification design (.autoflow/issue-127-verification-design.md). RED at HEAD: the
// script has no `resume` handling at all, so a `resume: true`/`"true"` arg is silently
// ignored and every case below falls through to the ordinary cold path (Draft runs,
// round numbering starts at 1) -- the assertions below are discriminating against that
// fallthrough. Two cases are deliberate REGRESSION LOCKS and pass vacuously at RED
// because the property they pin already holds on a script that touches no filesystem
// at all (see their inline notes), in the same spirit as the pre-existing
// "single transient one-side-null" case above.
//
// Neither the register-load nor the register-write agent() call's label is fixed by
// the feature design, so every case identifies them STRUCTURALLY instead of assuming a
// literal: on a resume run Draft never executes (Control flow > Entry), so the FIRST
// agent() call is the register load; Control flow > Register write states the write is
// a terminal phase run "after the Ledger phase, on all three verdicts" (issue #138 widened this
// from "both" to CONVERGED/AC_CHANGE/ESCALATE), so the first call observed strictly after the
// 'ledger' call is the register write.
//
// Two RED-time design decisions this suite fixes because the documents left the exact
// literal open (recorded in the RED report as a design-change addendum the Developer AI
// must adopt verbatim): the on-disk register payload's fence markers
// (REGISTER_FENCE_START/END) and the settled-block heading is NOT fixed here -- it is
// read back from whatever `SETTLED_BLOCK_RULE` the implementation declares, per the
// agenda-partition case below.

const REGISTER_FENCE_START = '===AUTOFLOW-REGISTER-JSON-START==='
const REGISTER_FENCE_END = '===AUTOFLOW-REGISTER-JSON-END==='

// Generic resume-path responder. `overrides.load` controls the register-load call's
// return (default: a passing register at lastTurn 6 with one open entry); `overrides
// [label]` controls an individual turn call; `overrides.roundDefault` controls every
// turn call without its own override (default: an unmodified accept); `overrides.write`
// controls the register-write call (default: a truthy ack).
function resumeResponder(overrides = {}) {
  let seenLedger = false
  return (label) => {
    if (label.endsWith('-draft')) return Object.prototype.hasOwnProperty.call(overrides, 'draft') ? overrides.draft : 'drafted'
    if (label === 'ledger') {
      seenLedger = true
      return Object.prototype.hasOwnProperty.call(overrides, 'ledger') ? overrides.ledger : 'ledger ok'
    }
    if (label.startsWith('test-t') || label.startsWith('dev-t')) {
      if (Object.prototype.hasOwnProperty.call(overrides, label)) return overrides[label]
      return overrides.roundDefault !== undefined ? overrides.roundDefault : { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
    }
    // Fixture-amendment class recorded for #127 cycle 3, amended this cycle for #138: a
    // converging run now runs Reconcile before Ledger, calling a sub-agent labelled
    // 'ac-diff'. Handled explicitly (not left to the register-load/-write fallback below,
    // which would misclassify it since 'ac-diff' precedes 'ledger' the same as register-load
    // does) -- the shape is the one the 'ac-diff-plumbing' leg proves yields CONVERGED.
    if (label === 'ac-diff') {
      return Object.prototype.hasOwnProperty.call(overrides, 'acDiff')
        ? overrides.acDiff
        : { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    }
    // Unclassified: register-load (before 'ledger') or register-write (after it).
    if (!seenLedger) {
      return Object.prototype.hasOwnProperty.call(overrides, 'load') ? overrides.load : {
        found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE',
        entries: [{ name: 'DEFAULT_OPEN', conclusion: 'c', evidence: 'e', status: 'open', raisedBy: 'dev' }],
      }
    }
    return Object.prototype.hasOwnProperty.call(overrides, 'write') ? overrides.write : { written: true }
  }
}

await test('ARCHITECT: resume spawns no Draft agent (AC127-1, resume-no-draft)', async () => {
  const { calls } = await runArch({ issue: '127-1', resume: true }, resumeResponder())
  assert.ok(!calls.some((c) => c.label.endsWith('-draft')), 'a resume run must not spawn a Draft agent')
})

await test('ARCHITECT: resume admission -- true and "true" both take the resume path, absent/false/"false" take the cold path (AC127-2a, admission-forms)', async () => {
  for (const v of [true, 'true']) {
    const { calls } = await runArch({ issue: '127-2a', resume: v }, resumeResponder())
    assert.ok(!calls.some((c) => c.label.endsWith('-draft')), `resume: ${JSON.stringify(v)} must skip Draft`)
  }
  for (const v of [undefined, false, 'false']) {
    const args = v === undefined ? { issue: '127-2a' } : { issue: '127-2a', resume: v }
    const { calls } = await runArch(args, resumeResponder())
    assert.ok(calls.some((c) => c.label.endsWith('-draft')), `resume: ${JSON.stringify(v)} must take the cold path`)
  }
})

await test('ARCHITECT: a malformed resume value throws at the boundary, extending the single existing args.issue throw site (AC127-2b, admission-malformed)', async () => {
  await assert.rejects(
    () => runArch({ issue: '127-2b', resume: 'yes' }, resumeResponder()),
    /resume/i,
  )
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  // Scoped to the args-admission block specifically (up to `const issue = argv.issue`, the line
  // right after the single admission guard) -- not to the whole pre-Draft prelude. Widening the
  // slice to `phase('Draft')` would also capture the spawn-policy `site()` helper's OWN fail-closed
  // throw (issue #150), which is a distinct, unrelated throw site and would make this count assert
  // 2 for a reason this AC never claimed to guard.
  const normalizationBlock = src.slice(0, src.indexOf('const issue = argv.issue'))
  assert.equal((normalizationBlock.match(/throw new Error/g) || []).length, 1, 'the resume admission rule must extend the single existing throw site, not add a second one')
})

await test('ARCHITECT: prose args carrying a standalone "resume" token plus a salvageable issue land on the resume path (AC127-2c, prose-resume-token)', async () => {
  const { calls } = await runArch('please resume issue #12700', resumeResponder())
  assert.ok(!calls.some((c) => c.label.endsWith('-draft')), 'a prose resume token must route to the resume path')
})

await test('meta: architect-deliberation.js description names the resume key and phases list the Resume/Register stages (AC127-3, meta-widened-args)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const descLine = (src.match(/description:[^\n]*\n?/) || [''])[0]
  assert.match(descLine, /resume/i, 'meta.description must name the resume key on its own line')
  assert.match(src, /title:\s*'Resume'/, 'meta.phases must carry a Resume stage')
  assert.match(src, /title:\s*'Register'/, 'meta.phases must carry a Register stage')
})

await test('ARCHITECT: a resume round prompt partitions the register -- the agenda is open-only, closed entries appear only under the declared settled-block heading (AC127-4, agenda-partition)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const m = src.match(/const SETTLED_BLOCK_RULE\s*=\s*(['"`])((?:\\.|(?!\1)[\s\S])*)\1/)
  assert.ok(m, 'SETTLED_BLOCK_RULE must be declared as a single, once-declared literal')
  const settledBlockRule = m[2].replace(/\\n/g, '\n').replace(/\\'/g, "'").replace(/\\"/g, '"')
  const responder = resumeResponder({
    load: {
      found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE',
      entries: [
        { name: 'OPEN_TOK_127', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' },
        { name: 'AGREED_TOK_127', conclusion: '', evidence: 'e', status: 'agreed', raisedBy: 'dev' },
        { name: 'REJECTED_TOK_127', conclusion: '', evidence: 'e', status: 'rejected', raisedBy: 'test' },
      ],
    },
  })
  const { calls } = await runArch({ issue: '127-4', resume: true }, responder)
  for (const label of ['test-t7', 'dev-t8']) {
    const p = calls.find((c) => c.label === label).prompt
    const settledIdx = p.indexOf(settledBlockRule)
    assert.ok(settledIdx >= 0, `${label} must carry the declared settled-block heading`)
    const agendaPart = p.slice(0, settledIdx)
    const settledPart = p.slice(settledIdx)
    assert.match(agendaPart, /OPEN_TOK_127/, `${label} agenda must carry the open entry`)
    assert.doesNotMatch(agendaPart, /AGREED_TOK_127/, `${label} agenda must not carry the agreed entry`)
    assert.doesNotMatch(agendaPart, /REJECTED_TOK_127/, `${label} agenda must not carry the rejected entry`)
    assert.match(settledPart, /AGREED_TOK_127/, `${label} settled block must carry the agreed entry`)
    assert.match(settledPart, /REJECTED_TOK_127/, `${label} settled block must carry the rejected entry`)
  }
})

await test('ARCHITECT: a resume run executes exactly one exchange and returns (AC127-5, resume-one-exchange)', async () => {
  const { result, calls } = await runArch({ issue: '127-5', resume: true }, resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'ONE_EX', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
  }))
  assert.equal(calls.filter((c) => c.label === 'test-t7').length, 1)
  assert.equal(calls.filter((c) => c.label === 'dev-t8').length, 1)
  assert.ok(!calls.some((c) => /-t9\b/.test(c.label)), 'a resume run admits exactly one further exchange (two turns), no more')
  assert.equal(result.turns, 8)
})

await test('ARCHITECT: round numbering continues from the register\'s lastTurn, never from an argument (AC127-6, resume-round-source)', async () => {
  const { result, calls } = await runArch({ issue: '127-6', resume: true }, resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 10, verdict: 'ESCALATE', entries: [{ name: 'RN', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
  }))
  assert.ok(calls.some((c) => c.label === 'test-t11'))
  assert.ok(calls.some((c) => c.label === 'dev-t12'))
  assert.equal(result.turns, 12)
})

await test('ARCHITECT: a resume from lastTurn 0 converges on its own first exchange -- the first-turn devil\'s-advocate guidance is lifted on resume (AC127-7, resume-lifts-first-exchange)', async () => {
  const { result, calls } = await runArch({ issue: '127-7', resume: true }, resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 0, verdict: 'ESCALATE', entries: [{ name: 'ZR', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t1': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'] },
    'dev-t2': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'], dispositions: [{ name: 'ZR', conclusion: 'closed', evidence: 'e', status: 'agreed' }] },
  }))
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 2, 'the pair that converges is the resumed exchange\'s own two turns')
  const testT1 = calls.find((c) => c.label === 'test-t1').prompt
  const devT2 = calls.find((c) => c.label === 'dev-t2').prompt
  // FIRST_EXCHANGE_RULE renders on a cold run's turns 1 and 2 only (issue #152) — a resume
  // continues a deliberation whose first exchange already happened.
  assert.doesNotMatch(testT1, /do NOT return accept: true on this turn/)
  assert.doesNotMatch(devT2, /do NOT return accept: true on this turn/)
})

await test('ARCHITECT: a resume run issues its terminal persistence call on both the CONVERGED and ESCALATE route (AC127-8, resume-persists-both-verdicts)', async () => {
  const convergedResp = resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'CV', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t7': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'] },
    // cycle-3 amendment (issue #127): the raiser ('dev') disposes of the carried entry so this
    // shape still converges under the resume-scoped open-entry precondition; this case's own
    // assertion (a persistence call follows 'ledger' on CONVERGED) is unchanged.
    'dev-t8': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'], dispositions: [{ name: 'CV', conclusion: 'closed', evidence: 'e', status: 'agreed' }] },
  })
  const { result: rConv, calls: cConv } = await runArch({ issue: '127-8a', resume: true }, convergedResp)
  assert.equal(rConv.verdict, 'CONVERGED')
  const ledgerIdxConv = cConv.findIndex((c) => c.label === 'ledger')
  assert.ok(ledgerIdxConv >= 0 && cConv.length > ledgerIdxConv + 1, 'a persistence call must follow the ledger call on CONVERGED')

  const escalateResp = resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'ES', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    roundDefault: { modified: false, accept: false, counters: ['still open'], accept_grounds: [] },
  })
  const { result: rEsc, calls: cEsc } = await runArch({ issue: '127-8b', resume: true }, escalateResp)
  assert.equal(rEsc.verdict, 'ESCALATE')
  const ledgerIdxEsc = cEsc.findIndex((c) => c.label === 'ledger')
  assert.ok(ledgerIdxEsc >= 0 && cEsc.length > ledgerIdxEsc + 1, 'a persistence call must follow the ledger call on ESCALATE')
  // The generic turn-exhaustion text names the RESUMED run's own ceiling (lastTurn 6 -> turnCeiling
  // 8), never the cold-path config ceiling (max_turns, 12): a resume-unaware implementation would
  // render "within 12 turns". Exact equality, not a substring match -- this run has no
  // earlyEscalateReason, so escalationReason IS this whole string verbatim, and an exact match
  // catches an implementation that gets the figure right but wraps or prefixes the text differently.
  assert.equal(rEsc.escalation, 'No convergence within 8 turns (reached turn 8)', 'the resume-path escalation text must name the run\'s own ceiling (8), not the cold-path config ceiling (12)')
})

await test('ARCHITECT: the return contract reports resumed/register/registerWritten truthfully, including a failed write (AC127-9, return-contract-fields)', async () => {
  const { result: coldResult } = await runArch({ issue: '127-9a' }, resumeResponder())
  assert.equal(coldResult.resumed, false)
  assert.equal(coldResult.registerWritten, true)
  assert.equal(coldResult.register, `.autoflow/issue-127-9a-architect-register.json`)

  const { result: resumeNullWrite } = await runArch({ issue: '127-9b', resume: true }, resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'RW', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t7': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'] },
    // cycle-3 amendment (issue #127): dispose of the carried entry from its raiser ('dev') so this
    // shape still converges under the resume-scoped open-entry precondition -- unrelated to what
    // this case actually pins (a failed write must not alter the already-decided verdict).
    'dev-t8': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'], dispositions: [{ name: 'RW', conclusion: 'closed', evidence: 'e', status: 'agreed' }] },
    write: null,
  }))
  assert.equal(resumeNullWrite.resumed, true)
  assert.equal(resumeNullWrite.registerWritten, false)
  assert.equal(resumeNullWrite.verdict, 'CONVERGED', 'a failed write must not alter the already-decided verdict')
})

// AC127-10 (the resumed closing prompt's ceiling coherence) is DELETED, not re-expressed: issue
// #152 removed the cap-round closing half-round outright, so there is no closing prompt to check.
// The turn prompts' own ceiling rendering is covered by the resume escalation-text leg above.

await test('ARCHITECT: a resume turn that goes missing at the ceiling escalates as an infrastructure cause naming exactly 1 consecutive turn (AC127-11, resume-final-turn-null-infra)', async () => {
  // The bound-aware disjunct: with no further turn to retry it, a null at the resume ceiling is a
  // MISSING judgment immediately rather than after a second consecutive null.
  const responder = resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'BN', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t7': { modified: false, accept: false, counters: ['still open'], accept_grounds: [] },
    'dev-t8': null,
  })
  const { result } = await runArch({ issue: '127-11', resume: true }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'sub-agent missing for 1 consecutive turn(s)')
})

const resumeGuardCases = [
  { name: 'load agent returned null', overrides: { load: null }, sentinel: 'resume register load agent missing' },
  { name: '`found` false', overrides: { load: { found: false, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [] } }, sentinel: 'resume register absent' },
  { name: 'no open entry', overrides: { load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'X', conclusion: '', evidence: 'e', status: 'agreed', raisedBy: 'dev' }] } }, sentinel: 'resume register has no open entry' },
  { name: '`verdict` is CONVERGED', overrides: { load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'CONVERGED', entries: [{ name: 'X', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] } }, sentinel: 'resume register already converged' },
]
for (let i = 0; i < resumeGuardCases.length; i++) {
  const g = resumeGuardCases[i]
  await test(`ARCHITECT: resume guard "${g.name}" resolves to its own declared sentinel (AC127-12, resume-guard-sentinels)`, async () => {
    const { result, calls } = await runArch({ issue: `127-12-${i}`, resume: true }, resumeResponder(g.overrides))
    assert.equal(result.verdict, 'ESCALATE')
    assert.equal(result.escalation, g.sentinel)
    assert.ok(!calls.some((c) => c.label.startsWith('test-t') || c.label.startsWith('dev-t')), 'a guard failure must escalate before any round is entered')
  })
}

// The artifacts_present guard is deliberately NOT driven by a fabricated flag above
// (verification design > Composition-oracle determination, third row): it is the
// composition contact point that must be reached from a REAL missing design document.
await test('ARCHITECT: the artifacts_present guard fires from a real missing design document, not a fabricated flag (AC127-12b, artifacts-present-real-fs, composition oracle)', async () => {
  const issue = '127-12b'
  const { feature, verif } = artifactPaths(issue)
  const responder = (label) => {
    if (label.endsWith('-draft')) return null
    if (label === 'ledger') return 'ledger ok'
    return {
      found: true,
      artifacts_present: existsSync(feature) && existsSync(verif),
      lastTurn: 6, verdict: 'ESCALATE', entries: [],
    }
  }
  const { result } = await runArch({ issue, resume: true }, responder, { omitArtifact: 'verif' })
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.escalation, 'resume design artifact missing')
})

// Driven directly against `arch()` (two invocations sharing one real register file)
// rather than through `runArch()`: the wrapper's teardown would delete the register
// between the two invocations, which is exactly the state this test needs to survive.
await test('ARCHITECT: register round-trip -- a cold CONVERGED run persists verdict:"CONVERGED" into a real on-disk register, which a later resume reads back and refuses under the already-converged guard (AC127-13, composition oracle: register entry-shape/status round-trip + verdict persistence)', async () => {
  const issue = '127-13'
  const { register } = artifactPaths(issue)
  try { unlinkSync(register) } catch (_) { /* none yet */ }
  writeDraftArtifacts(issue)
  const coldResponder = (label, prompt) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    if (label === 'dev-t2') return { modified: false, accept: false, counters: [{ agenda: 'ROUNDTRIP_CONCERN', locator: 'l', argument: 'a' }], accept_grounds: [] }
    if (label === 'test-t1') return { modified: false, accept: false, counters: ['t1'], accept_grounds: [] }
    if (label.startsWith('test-t') || label.startsWith('dev-t')) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
    // Unclassified => the terminal register-write call: extract the fenced payload and
    // write it for real -- the writing half of the round-trip oracle.
    const start = prompt.indexOf(REGISTER_FENCE_START)
    const end = prompt.indexOf(REGISTER_FENCE_END)
    assert.ok(start >= 0 && end > start, 'the register-write prompt must carry the declared fence literals around the payload')
    writeFileSync(register, prompt.slice(start + REGISTER_FENCE_START.length, end))
    return { written: true }
  }
  const coldResult = await arch({ issue }, phase, parallel, makeAgent(coldResponder, []), mockConsole)
  assert.equal(coldResult.verdict, 'CONVERGED')
  assert.equal(coldResult.registerWritten, true)
  const onDisk = JSON.parse(readFileSync(register, 'utf8'))
  assert.equal(onDisk.verdict, 'CONVERGED', 'the persisted register must carry the converging run\'s own verdict')

  // The resume run's load responder reads that same real file back -- the reading half
  // of the round trip -- and must refuse under the already-converged guard.
  const resumeLoadResponder = (label) => {
    if (label.endsWith('-draft')) return null
    if (label === 'ledger') return 'ledger ok'
    const onDiskNow = JSON.parse(readFileSync(register, 'utf8'))
    return { found: true, artifacts_present: true, lastTurn: onDiskNow.lastTurn, verdict: onDiskNow.verdict, entries: onDiskNow.entries }
  }
  const resumeResult = await arch({ issue, resume: true }, phase, parallel, makeAgent(resumeLoadResponder, []), mockConsole)
  removeDraftArtifacts(issue)
  assert.equal(resumeResult.verdict, 'ESCALATE')
  assert.equal(resumeResult.escalation, 'resume register already converged')
})

// Driven directly against `arch()` rather than through `runArch()`: the wrapper's own
// teardown unconditionally unlinks the register path (fixture hygiene, above), which
// would delete this test's fixture before the post-run byte-identity check can read it.
await test('ARCHITECT: a guard-failed resume leaves a real register file byte-identical and issues no persistence call (AC127-14, guard-failed-byte-identical)', async () => {
  const issue = '127-14'
  const { register } = artifactPaths(issue)
  writeDraftArtifacts(issue)
  writeFileSync(register, '{"untouched":true}\n')
  const before = readFileSync(register, 'utf8')
  const calls = []
  await arch({ issue, resume: true }, phase, parallel, makeAgent(resumeResponder({ load: null }), calls), mockConsole)
  const after = readFileSync(register, 'utf8')
  removeDraftArtifacts(issue)
  assert.equal(after, before, 'a guard-failed resume must not touch the register file')
  assert.ok(!calls.some((c) => /-t\d/.test(c.label)), 'no round call may be made')
})

// Regression lock, vacuous PASS expected at RED (documented, not an oracle mistake): the
// AS-IS script touches no filesystem at all -- a cold null-draft run makes zero agent()
// calls beyond the drafts and the ledger, so a pre-seeded file is trivially untouched
// today. The case exists to catch a FUTURE regression once the write mechanism lands,
// mirroring the "single transient one-side-null" lock above (verification design >
// *An early-escalating run never overwrites a register it did not read*).
await test('ARCHITECT: a cold run that early-escalates on a null draft never overwrites an existing register file (AC127-15, cold-null-draft-byte-identical)', async () => {
  const issue = '127-15'
  const { register } = artifactPaths(issue)
  writeDraftArtifacts(issue)
  writeFileSync(register, '{"untouched":true}\n')
  const before = readFileSync(register, 'utf8')
  const responder = (label) => {
    if (label === 'dev-draft') return null
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const result = await arch({ issue }, phase, parallel, makeAgent(responder, []), mockConsole)
  const after = readFileSync(register, 'utf8')
  removeDraftArtifacts(issue)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(after, before, 'an early-escalating cold run must not overwrite an existing register file')
})

await test('ARCHITECT: an out-of-enum status/raisedBy rehydrates to the declared fallback, and the coerced raiser can then close it (AC127-16, rehydration-fallback)', async () => {
  let seenLedger = false
  let writePrompt = null
  const responder = (label, prompt) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') { seenLedger = true; return 'ledger ok' }
    if (label === 'test-t7') return { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'], dispositions: [{ name: 'BAD_RAISER', conclusion: 'closed', evidence: 'e', status: 'agreed' }] }
    if (label === 'dev-t8') return { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'], dispositions: [{ name: 'BAD_STATUS', conclusion: 'closed', evidence: 'e', status: 'agreed' }] }
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    if (!seenLedger) {
      return {
        found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE',
        entries: [
          { name: 'BAD_STATUS', conclusion: '', evidence: 'e', status: 'weird', raisedBy: 'dev' },
          { name: 'BAD_RAISER', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'nobody' },
        ],
      }
    }
    writePrompt = prompt
    return { written: true }
  }
  const { result, calls } = await runArch({ issue: '127-16', resume: true }, responder)
  const testR4 = calls.find((c) => c.label === 'test-t7').prompt
  assert.match(testR4, /BAD_STATUS[\s\S]{0,80}status: open/, 'an out-of-enum status must rehydrate as open')
  assert.match(testR4, /BAD_RAISER[\s\S]{0,80}raised by test/, 'an out-of-enum raisedBy must rehydrate as test')
  assert.equal(result.verdict, 'CONVERGED')
  assert.ok(writePrompt, 'the register write call must have been made')
  const start = writePrompt.indexOf(REGISTER_FENCE_START)
  const end = writePrompt.indexOf(REGISTER_FENCE_END)
  assert.ok(start >= 0 && end > start, 'the write prompt must carry the declared fence markers')
  const written = JSON.parse(writePrompt.slice(start + REGISTER_FENCE_START.length, end))
  const badRaiser = written.entries.find((e) => e.name === 'BAD_RAISER')
  assert.ok(badRaiser, 'BAD_RAISER must survive into the persisted register')
  assert.equal(badRaiser.status, 'agreed', 'the coerced raiser ("test") must be the one able to close it')
})

await test('ARCHITECT: LEDGER_SEED_RULE reaches both turn prompts of a resume run (AC127-17, resume-carries-ledger-seed)', async () => {
  const responder = resumeResponder({
    load: { found: true, artifacts_present: true, lastTurn: 12, verdict: 'ESCALATE', entries: [{ name: 'LS', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t13': { modified: false, accept: false, counters: ['ls-c'], accept_grounds: [] },
    'dev-t14': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'] },
  })
  const { calls } = await runArch({ issue: '127-17', resume: true }, responder)
  for (const label of ['test-t13', 'dev-t14']) {
    const p = calls.find((c) => c.label === label).prompt
    assert.match(p, /is a settled registered issue/, `${label} must carry the ledger-seed instruction on a resume run`)
  }
})

// Regression lock, vacuous PASS expected at RED: the AS-IS script already names no
// `.autoflow/issue-{N}.json` state-file path (verification design > *Resume does not
// increment the ARCHITECT re-entry counter*, re-derived by grep this cycle). The
// assertion locks the property rather than driving new behavior.
await test('ARCHITECT: the script still names no .autoflow/issue-{N}.json state-file path (AC127-18, resume-no-state-file-touch)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  assert.doesNotMatch(src, /issue-\$\{issue\}\.json|issue-\d+\.json/, 'the workflow must not name the ARCHITECT re-entry counter state file')
})

// ---- ARCHITECT: terminal post-verdict call rejection absorption (issue #127, cycle 2) ---
// Verification design (.autoflow/issue-127-verification-design.md, cycle 2 section). RED at
// HEAD: both the `ledger` call (architect-deliberation.js:602) and the `register-write` call
// (:632) are bare `await agent(...)` with no absorption wrapper, so a rejecting/throwing
// sub-agent call propagates OUT of `architect-deliberation` -- every case below asserts a
// RESOLVED result and therefore fails at HEAD for that reason.
//
// A rejection needs no harness plumbing change (verification design > Testability assessment):
// the shared `resumeResponder` factory returns each override's value directly, so composing it
// behind a one-label interceptor that throws for the intercepted label is sufficient -- the
// `async` `makeAgent` shim converts the throw into the rejection under test. The interceptor
// delegates to the base responder FIRST before throwing so structural state the base responder
// tracks (`seenLedger`) still advances -- required so a `ledger`-rejection case's subsequent
// register-write call is still classified past the ledger, not before it (RED hazard recorded
// in .autoflow/issue-127-c2-gate-plan.md item 2).
function interceptLabelReject(overrides, label, makeError) {
  const base = resumeResponder(overrides)
  return (l, p) => {
    if (l === label) {
      base(l, p) // delegate first -- advances seenLedger / round bookkeeping normally
      throw makeError()
    }
    return base(l, p)
  }
}

await test('ARCHITECT: a rejecting register-write sub-agent leaves the already-decided verdict intact and reports a failed write (AC-C2-127-1, write-reject-absorbed)', async () => {
  const responder = interceptLabelReject({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'WRA', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t7': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'] },
    // cycle-3 amendment (issue #127): dispose of the carried entry from its raiser ('dev') so this
    // shape still converges under the resume-scoped open-entry precondition -- unrelated to what
    // this case pins (a rejecting register-write must not alter the already-decided verdict).
    'dev-t8': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'], dispositions: [{ name: 'WRA', conclusion: 'closed', evidence: 'e', status: 'agreed' }] },
  }, 'register-write', () => new Error('register-write rejected'))
  const { result } = await runArch({ issue: 'c2-127-1', resume: true }, responder)
  assert.equal(result.verdict, 'CONVERGED', 'a rejecting register-write must not alter the already-decided verdict')
  assert.equal(result.registerWritten, false)
})

// Direct invocation, bypassing runArch()/makeAgent(): a plain (non-`async`) agent that throws
// SYNCHRONOUSLY at the register-write site. The harness's own agent shim is `async`
// (test/workflows/run.mjs makeAgent), which converts any synchronous throw into a rejection and
// so cannot exercise the distinction under test -- only a direct call with a non-async agent
// keeps the throw synchronous (verification design > `write-sync-throw-absorbed`, Invocation
// path clause). Owns its own artifact setup/unlink -- the same carve-out AC127-13/14 already
// take, for the same reason: neither the runner's fixture write nor its `finally` teardown apply
// to a call that bypasses the runner.
await test('ARCHITECT: a SYNCHRONOUS throw at the register-write call is absorbed the same as a rejection -- discriminates the wide guard form from a bare `.catch()` (write-sync-throw-absorbed, AC-C2-127-2)', async () => {
  const issue = 'c2-127-2-sync'
  const { register } = artifactPaths(issue)
  writeDraftArtifacts(issue)
  try { unlinkSync(register) } catch (_) { /* none yet */ }
  const syncThrowAgent = (prompt, opts = {}) => {
    const label = (opts && opts.label) || ''
    if (label === 'policy-load') return DEFAULT_POLICY_LOAD_RESPONSE
    if (label === 'register-write') throw new Error('sync register-write throw') // NOT a promise rejection
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [] }
    if (label.startsWith('test-t') || label.startsWith('dev-t')) return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
    return null
  }
  const result = await arch({ issue }, phase, parallel, syncThrowAgent, mockConsole)
  removeDraftArtifacts(issue)
  assert.equal(result.verdict, 'CONVERGED', 'a synchronous throw at register-write must not alter the already-decided verdict')
  assert.equal(result.registerWritten, false)
})

await test('ARCHITECT: a rejecting ledger sub-agent leaves the already-decided verdict intact, and the terminal register write still runs and succeeds (AC-C2-127-4, ledger-reject-absorbed)', async () => {
  const responder = interceptLabelReject({
    load: { found: true, artifacts_present: true, lastTurn: 6, verdict: 'ESCALATE', entries: [{ name: 'LRA', conclusion: '', evidence: 'e', status: 'open', raisedBy: 'dev' }] },
    'test-t7': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'] },
    // cycle-3 amendment (issue #127): dispose of the carried entry from its raiser ('dev') so this
    // shape still converges under the resume-scoped open-entry precondition -- unrelated to what
    // this case pins (a rejecting ledger call must not alter the already-decided verdict).
    'dev-t8': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'], dispositions: [{ name: 'LRA', conclusion: 'closed', evidence: 'e', status: 'agreed' }] },
  }, 'ledger', () => new Error('ledger rejected'))
  const { result } = await runArch({ issue: 'c2-127-4', resume: true }, responder)
  assert.equal(result.verdict, 'CONVERGED', 'a rejecting ledger call must not alter the already-decided verdict')
  assert.equal(result.registerWritten, true, 'the terminal register write must still be issued and acknowledged after an absorbed ledger rejection -- this is what separates "absorbed" from "swallowed the rest of the run"')
})

// Real-filesystem composition oracle (verification design > `stale-register-untouched`), driven
// directly against `arch()` three times over one real register file -- the same carve-out
// AC127-13/14 take, for the same reason: the runner's teardown would delete the file between
// invocations. Uses real labels directly ('register-load' / 'ledger' / 'register-write') rather
// than the resumeResponder factory, since this case's whole point is reading/writing that exact
// real file across three separate runs.
await test('ARCHITECT: a failed register write on resume leaves a previously persisted register byte-unchanged, and a later resume re-enters from that persisted round rather than a fresh one (stale-register-untouched, AC-C2-127-2)', async () => {
  const issue = 'c2-127-stale'
  const { register } = artifactPaths(issue)
  try { unlinkSync(register) } catch (_) { /* none yet */ }
  writeDraftArtifacts(issue)

  // Step 1 -- a real cold run that never converges (no turn accepts) persists a real ESCALATE
  // register with one open entry raised on turn 2, so it is resume-eligible (a CONVERGED register
  // would be refused by the already-converged guard).
  const coldResponder = (label, prompt) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'register-write') {
      const start = prompt.indexOf(REGISTER_FENCE_START)
      const end = prompt.indexOf(REGISTER_FENCE_END)
      assert.ok(start >= 0 && end > start, 'the register-write prompt must carry the declared fence literals around the payload')
      writeFileSync(register, prompt.slice(start + REGISTER_FENCE_START.length, end))
      return { written: true }
    }
    if (label === 'dev-t2') return { modified: false, accept: false, counters: ['STALE_CONCERN'], accept_grounds: [] }
    return OPEN_TURN // never accepts -> never converges (issue #152)
  }
  const coldResult = await arch({ issue }, phase, parallel, makeAgent(coldResponder, []), mockConsole)
  assert.equal(coldResult.verdict, 'ESCALATE')
  assert.equal(coldResult.registerWritten, true)
  const before = readFileSync(register, 'utf8')
  const beforeTurn = JSON.parse(before).lastTurn

  // Step 2 -- a resume run against that same real file whose register-write call REJECTS.
  const rejectingResumeAgent = (label) => {
    if (label === 'register-load') {
      const onDiskNow = JSON.parse(readFileSync(register, 'utf8'))
      return { found: true, artifacts_present: true, lastTurn: onDiskNow.lastTurn, verdict: onDiskNow.verdict, entries: onDiskNow.entries }
    }
    if (label === 'ledger') return 'ledger ok'
    if (label === 'register-write') throw new Error('register-write rejected')
    // The two resumed turns are both unmodified accepts, so this run converges (issue #152:
    // open register entries no longer block convergence). The assertions below read
    // `registerWritten`, on-disk byte equality and `turns` only -- never `verdict`.
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const rejectResult = await arch({ issue, resume: true }, phase, parallel, makeAgent(rejectingResumeAgent, []), mockConsole)
  assert.equal(rejectResult.registerWritten, false, 'the rejecting write must be reported as failed')
  const after = readFileSync(register, 'utf8')
  assert.equal(after, before, 'a failed register write must leave the previously persisted register byte-unchanged')

  // Step 3 -- a further resume whose load responder reads that same real (unchanged) file back
  // must re-enter at the persisted turn, not a fresh one.
  const finalLoadAgent = (label) => {
    if (label === 'register-load') {
      const onDiskNow = JSON.parse(readFileSync(register, 'utf8'))
      return { found: true, artifacts_present: true, lastTurn: onDiskNow.lastTurn, verdict: onDiskNow.verdict, entries: onDiskNow.entries }
    }
    if (label === 'ledger') return 'ledger ok'
    if (label === 'register-write') return { written: true }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const finalResult = await arch({ issue, resume: true }, phase, parallel, makeAgent(finalLoadAgent, []), mockConsole)
  removeDraftArtifacts(issue)
  assert.equal(finalResult.turns, beforeTurn + 2, 'the further resume must re-enter from the persisted turn and run its one further exchange, not restart cold')
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

// ---- meta-doc contract exposure (issue #14, F1) --------------------------------

await test('meta: architect-deliberation.js description states the args contract', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  assert.match(src, /description:[^\n]*issue/i)
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

// Separate assertion, not an added literal inside the three-way loop above (feature design
// > API interface > Argument surface, *The resume token's parity surface is two copies, not
// three*): verify-cause-branch.js has no resume concept and is outside this change's surface.
await test('source-parity: the resume-token literal (\\bresume\\b) is identical between architect-deliberation.js and the harness mirror (AC127-2c, resume-token-parity)', async () => {
  const archSrc = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const harnessSrc = readFileSync(join(root, 'test/workflows/run.mjs'), 'utf8')
  for (const [label, src] of [['architect-deliberation.js', archSrc], ['run.mjs extractArgv()', harnessSrc]]) {
    assert.ok(src.includes('\\bresume\\b'), `${label} missing the resume-token literal`)
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

await test('AC-facilitator-prompt: ARCHITECT CONVERGED ledger prompt carries the next-allocation and check instructions', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
    const r = roundOf(label)
    if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
  const { result, calls } = await runArch({ issue: '99900097' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /ledger-entry-id\.sh next[^\n]*F\b/, 'CONVERGED ledger prompt must instruct allocating each ID via next ... F')
  assert.match(ledgerPrompt, /ledger-entry-id\.sh check/, 'CONVERGED ledger prompt must instruct running check after the appends')
})

await test('AC-facilitator-prompt: ARCHITECT ESCALATE ledger prompt carries the next-allocation and check instructions', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return OPEN_TURN // never accepts -> never converges (issue #152)
  }
  const { result, calls } = await runArch({ issue: '99900097' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /ledger-entry-id\.sh next[^\n]*F\b/, 'ESCALATE ledger prompt must instruct allocating each ID via next ... F')
  assert.match(ledgerPrompt, /ledger-entry-id\.sh check/, 'ESCALATE ledger prompt must instruct running check after the appends')
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

// ---- ARCHITECT: AC-authority reconciliation (issue #138) ----------------------
// Verification design .autoflow/issue-138-verification-design.md. A new Reconcile
// phase sits between Converge and Ledger (feature design > Placement) and, on a
// converged run, calls a `label: 'ac-diff'` comparison channel that transcribes
// (never judges) the Phase B AC table, the converged verification design's `Issue
// AC` column, and the issue ledger's `[ac-decision]` entries, then derives `kind`
// and `authorized` IN THE SCRIPT (feature design > The comparison channel). None of
// this exists at HEAD -- every leg below is RED because the script returns only
// CONVERGED/ESCALATE and never calls a sub-agent labelled 'ac-diff'.

// Fence sentinels reused from the register-round-trip suite above (issue #127) --
// the register-write prompt wraps the persisted JSON payload between these two
// literals so a resume can extract it by equality rather than by prose-scanning.
function registerPayload(calls) {
  const call = calls.find((c) => c.label === 'register-write')
  if (!call) return null
  const start = call.prompt.indexOf(REGISTER_FENCE_START)
  const end = call.prompt.indexOf(REGISTER_FENCE_END)
  if (start === -1 || end === -1) return null
  const body = call.prompt.slice(start + REGISTER_FENCE_START.length, end).trim()
  return JSON.parse(body)
}
// A responder that converges normally (round 2 mutual ACCEPT) and additionally
// answers the 'ac-diff' label -- callers supply just the ac-diff return.
const convergingWithAcDiff = (acDiffReturn) => (label) => {
  if (label.endsWith('-draft')) return 'drafted'
  if (label === 'ledger') return 'ledger ok'
  if (label === 'register-write') return 'register written'
  if (label === 'ac-diff') return acDiffReturn
  const r = roundOf(label)
  if (r === 1) return { modified: false, accept: false, counters: ['c1'], accept_grounds: [] }
  return { modified: false, accept: true, counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
}

// Two Test-AI prompt sites since issue #152, not three: the cap-round closing prompt the dispatch
// named as the third is gone with the closing half-round it belonged to.
await test('ARCHITECT: both Test-AI prompt sites (draft, turn) carry the "Issue AC" column literal (dispatch obligation 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '138-ac0' }, responder)
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  const testT1 = calls.find((c) => c.label === 'test-t1').prompt
  assert.match(testDraft, /Issue AC/, 'test-draft prompt must instruct the Issue AC column')
  assert.match(testT1, /Issue AC/, 'test-t1 prompt must instruct the Issue AC column')
})

await test('ARCHITECT: an unauthorized ac-diff finding returns AC_CHANGE, not CONVERGED, with the declared acChange shape (AC1, ac-change-verdict-returns)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'not carried as a criterion' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-ac1' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acChange.length, 1)
  const finding = result.acChange[0]
  assert.equal(finding.ac, 'AC1')
  assert.equal(finding.kind, 'dropped')
  assert.ok('locator' in finding && 'proposed' in finding)
  const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledgerPrompt, /ARCHITECT ac-change/, 'ledger prompt must use authority "ARCHITECT ac-change"')
  assert.doesNotMatch(ledgerPrompt, /ARCHITECT mutual ACCEPT/, 'an AC_CHANGE run records no settled decision')
  const entryCountPattern = /exactly one/i
  assert.match(ledgerPrompt, entryCountPattern, 'ledger prompt must instruct exactly one outcome entry on the AC_CHANGE branch')
})

await test('ARCHITECT: a substituted ac-diff finding is plumbed through as kind "substituted" (AC1, substitution arm)', async () => {
  const acDiff = {
    ac_source_present: true,
    // A clean carried/verified/executable row for the OTHER AC (AC2) so this leg isolates the
    // substitution arm from the O5(c) empty-ac_rows fail-closed rule (an empty ac_rows set is its
    // own fail-closed path, tested separately by 'ac-diff-empty-rows-fail-closed').
    ac_rows: [{ ac: 'AC2', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }],
    ledger_ac_decisions: [],
    substituted: [{ ac: 'AC1', locator: 'design-doc-section', proposed: 'an always-true tautology' }],
  }
  const { result } = await runArch({ issue: '138-ac1-sub' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.ok(result.acChange.some((f) => f.ac === 'AC1' && f.kind === 'substituted'))
})

await test('ARCHITECT: a clean AC table (every AC carried, verified, executable) yields CONVERGED with no findings (Risk line, clean-fixture-yields-no-findings)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [
      { ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'test/workflows/run.mjs', proposed: 'verified' },
      { ac: 'AC2', carried: true, disposition: 'verified', method_executable: true, locator: 'tests/fixtures/gate-schema.json', proposed: 'verified' },
    ],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result } = await runArch({ issue: '138-ac-clean' }, convergingWithAcDiff(acDiff))
  assert.deepEqual(result.acChange, [])
  assert.equal(result.acReason, null)
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: ac_source_present:true with an EMPTY ac_rows set is fail-closed as "ac list absent", not a clean convergence (orchestrator decision O5(c), ac-diff-empty-rows-fail-closed)', async () => {
  // A well-formed AC_DIFF payload whose ac_source_present is true but whose ac_rows carries zero
  // rows is NOT the same as "no differences found" -- it is indistinguishable, from the script's
  // side, from the Phase B table having parsed to nothing readable. GATE:PLAN's own AC-authority
  // check already treats "absent, empty or unparseable" as one unresolvable-check cap (Trigger ->
  // cap, docs/autoflow-guide.md > GATE:PLAN > AC-authority check); Reconcile must resolve the same
  // way rather than silently converging on an empty row set.
  const acDiff = { ac_source_present: true, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
  const { result } = await runArch({ issue: '138-ac-empty-rows' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE', 'an empty ac_rows set must not converge silently')
  assert.equal(result.acReason, 'ac list absent', 'an empty ac_rows set is treated the same as ac_source_present:false')
  assert.deepEqual(result.acChange, [])
})

await test('ARCHITECT: kind derivation is computed in the script under a fixed first-match table, adversarial ordering (AC1, kind-table-is-computed-in-script)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [
      // carried:false wins over disposition:'declined' -> dropped, not not-carried
      { ac: 'AC-drop', carried: false, disposition: 'declined', method_executable: false, locator: '—', proposed: 'x' },
      // disposition:'deferred' wins over method_executable:false -> deferred, not weakened
      { ac: 'AC-defer', carried: true, disposition: 'deferred', method_executable: false, locator: 'x', proposed: 'x' },
      { ac: 'AC-notcarried', carried: true, disposition: 'declined', method_executable: true, locator: 'x', proposed: 'x' },
      { ac: 'AC-weak', carried: true, disposition: 'verified', method_executable: false, locator: '—', proposed: 'x' },
      { ac: 'AC-clean', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'x' },
    ],
    ledger_ac_decisions: [],
    substituted: [{ ac: 'AC-sub', locator: 'l', proposed: 'p' }],
  }
  const { result } = await runArch({ issue: '138-ac-kinds' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  const kindOf = (ac) => result.acChange.find((f) => f.ac === ac)?.kind
  assert.equal(kindOf('AC-drop'), 'dropped')
  assert.equal(kindOf('AC-defer'), 'deferred')
  assert.equal(kindOf('AC-notcarried'), 'not-carried')
  assert.equal(kindOf('AC-weak'), 'weakened')
  assert.equal(kindOf('AC-clean'), undefined, 'a fully carried/verified/executable row must yield no finding')
  const lastFinding = result.acChange[result.acChange.length - 1]
  assert.equal(lastFinding.ac, 'AC-sub', 'substituted findings are appended after the derived ones')
  assert.equal(lastFinding.kind, 'substituted')
})

await test('ARCHITECT: `authorized` is computed in the script by exact-after-trim match on ledger_ac_decisions, never substring/prefix (ac-diff-input-is-the-real-witness, half ii)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [
      { ac: 'AC1', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' },
      { ac: 'AC10', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' },
    ],
    // ' AC1 ' with surrounding whitespace must still match AC1 (trim); 'AC10' must NOT match on
    // the 'AC1' prefix (substring/prefix rejected).
    ledger_ac_decisions: [' AC1 '],
    substituted: [],
  }
  const { result } = await runArch({ issue: '138-ac-auth' }, convergingWithAcDiff(acDiff))
  // AC1 is authorized -> excluded from acChange; AC10 is unauthorized -> included.
  assert.ok(!result.acChange.some((f) => f.ac === 'AC1'), 'AC1 must be authorized by the trimmed exact match and excluded from acChange')
  assert.ok(result.acChange.some((f) => f.ac === 'AC10'), 'AC10 must NOT be authorized by a prefix match against "AC1"')
})

await test('ARCHITECT: an empty ledger_ac_decisions authorizes nothing -- acChange is the whole findings list (Return contract, on-empty-ledger-acChange-is-findings)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result } = await runArch({ issue: '138-ac-empty-ledger' }, convergingWithAcDiff(acDiff))
  assert.equal(result.acChange.length, 1)
  assert.equal(result.acChange[0].ac, 'AC1')
})

await test('ARCHITECT: the ac-diff prompt names all three input documents and states the ledger grammar verbatim (ac-diff-input-is-the-real-witness, half i, plumbing)', async () => {
  const acDiff = { ac_source_present: true, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
  const { calls } = await runArch({ issue: '138-ac-plumbing' }, convergingWithAcDiff(acDiff))
  const acDiffCall = calls.find((c) => c.label === 'ac-diff')
  assert.ok(acDiffCall, 'a Reconcile phase must issue an agent call labelled "ac-diff" on a converged run')
  assert.match(acDiffCall.prompt, /issue-138-ac-plumbing-phase-b/, 'the ac-diff prompt must name the Phase B AC-table artifact')
  assert.match(acDiffCall.prompt, /issue-138-ac-plumbing-verification-design/, 'the ac-diff prompt must name the verification design artifact')
  assert.match(acDiffCall.prompt, /issue-138-ac-plumbing-ledger/, 'the ac-diff prompt must name the issue ledger artifact')
  assert.match(acDiffCall.prompt, /\[ac-decision\]/, 'the ac-diff prompt must state the [ac-decision] heading-suffix grammar verbatim')
  assert.match(acDiffCall.prompt, /- AC:/, 'the ac-diff prompt must state the "- AC:" line-prefix grammar verbatim')
})

await test('ARCHITECT: a null ac-diff return resolves AC_CHANGE with the "ac reconciliation unavailable" sentinel, never CONVERGED (missing-diff-never-converges, leg i)', async () => {
  const { result, calls } = await runArch({ issue: '138-ac-null' }, convergingWithAcDiff(null))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.deepEqual(result.acChange, [])
  assert.equal(result.acReason, 'ac reconciliation unavailable')
  const payload = registerPayload(calls)
  assert.ok(payload, 'the fail-closed AC_CHANGE path must still write a register')
  assert.ok(payload.entries.some((e) => e.status === 'open'), 'at least one open entry must be minted so a resume is not refused')
})

await test('ARCHITECT: ac_source_present:false resolves AC_CHANGE with the "ac list absent" sentinel, distinct from the null-return sentinel (missing-diff-never-converges, leg ii)', async () => {
  const acDiff = { ac_source_present: false, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
  const { result, calls } = await runArch({ issue: '138-ac-absent' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.deepEqual(result.acChange, [])
  assert.equal(result.acReason, 'ac list absent')
  assert.notEqual(result.acReason, 'ac reconciliation unavailable')
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.status === 'open'))
})

await test('ARCHITECT: a non-converged run never calls ac-diff and never returns AC_CHANGE -- ESCALATE outranks AC_CHANGE (missing-diff-never-converges, leg iii, Placement)', async () => {
  const responder = (label) => {
    if (label === 'dev-draft') return null // early ESCALATE before Converge
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'ac-diff') return { ac_source_present: false, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '138-ac-noreconcile' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.acReason, null)
  assert.ok(!calls.some((c) => c.label === 'ac-diff'), 'Reconcile must not run on a non-converged run')
})

await test('ARCHITECT: an AC_CHANGE register round-trips the same acReason as the return, on every path (register-round-trips-ac-change)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-ac-roundtrip' }, convergingWithAcDiff(acDiff))
  const payload = registerPayload(calls)
  assert.equal(payload.verdict, 'AC_CHANGE')
  assert.equal(payload.acReason, result.acReason)
  const opened = payload.entries.filter((e) => e.status === 'open')
  assert.ok(opened.length >= 1)
  for (const e of opened) assert.equal(e.raisedBy, 'test')
})

await test('ARCHITECT: the two fail-closed paths mint register entries under the declared names (Register minting, fail-closed-paths-mint-too)', async () => {
  const { calls: callsNull } = await runArch({ issue: '138-ac-mint-null' }, convergingWithAcDiff(null))
  const payloadNull = registerPayload(callsNull)
  assert.ok(payloadNull.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))

  const acDiffAbsent = { ac_source_present: false, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
  const { calls: callsAbsent } = await runArch({ issue: '138-ac-mint-absent' }, convergingWithAcDiff(acDiffAbsent))
  const payloadAbsent = registerPayload(callsAbsent)
  assert.ok(payloadAbsent.entries.some((e) => e.name === 'ac-authority:ac-list-absent' && e.status === 'open'))
})

await test('ARCHITECT: the AC_CHANGE ledger prompt grounds clause is non-empty and names the run\'s acReason sentinel on all three AC_CHANGE paths (ac-change-ledger-grounds-name-the-sentinel)', async () => {
  const cases = [
    ['138-ac-grounds-unauth', {
      ac_source_present: true,
      ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' }],
      ledger_ac_decisions: [], substituted: [],
    }, 'unauthorized acceptance-criterion change'],
    ['138-ac-grounds-null', null, 'ac reconciliation unavailable'],
    ['138-ac-grounds-nosource', { ac_source_present: false, ac_rows: [], ledger_ac_decisions: [], substituted: [] }, 'ac list absent'],
  ]
  for (const [issueId, acDiff, sentinel] of cases) {
    const { calls } = await runArch({ issue: issueId }, convergingWithAcDiff(acDiff))
    const ledgerPrompt = calls.find((c) => c.label === 'ledger').prompt
    assert.ok(ledgerPrompt.trim().length > 0)
    assert.match(ledgerPrompt, new RegExp(sentinel.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')), `ledger grounds must name the sentinel "${sentinel}" for ${issueId}`)
  }
})

await test('ARCHITECT: LEDGER_SEED_RULE seeds "operator decision" as settled authority and never seeds "ARCHITECT ac-change" (operator-authority-is-readable, script half)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { modified: false, accept: true, counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '138-ac-seed' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  assert.match(devDraft, /operator decision/, 'the Draft prompt\'s seeded-authority set must contain "operator decision"')
  assert.doesNotMatch(devDraft, /ARCHITECT ac-change/, 'the Draft prompt\'s seeded-authority set must NOT contain "ARCHITECT ac-change"')
})

// ---- ARCHITECT: AC-authority reconciliation (issue #138), VERIFY-step-3 uncovered-hunk legs ----
// Added post-GREEN per the orchestrator's VERIFY step 3 disposition (.autoflow/issue-138-verify-
// report.md, hunks 2-7): uncovered code -> add a test. These legs are expected to PASS immediately
// against the existing GREEN implementation -- that is not a defect, it is the "add a test" branch
// of the minimal-implementation check, not the "remove the code" branch.

await test('ARCHITECT: AC_ROW/AC_SUBSTITUTION/AC_DIFF schema constants -- additionalProperties, required fields, and the closed disposition enum (VERIFY-hunk-2, ac-diff-schema-shape)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')

  const acRowMatch = src.match(/const AC_ROW = \{[\s\S]*?\n\}/)
  assert.ok(acRowMatch, 'AC_ROW constant must exist')
  const acRowSeg = acRowMatch[0]
  assert.match(acRowSeg, /additionalProperties:\s*false/, 'AC_ROW must keep additionalProperties: false')
  for (const field of ['ac', 'carried', 'disposition', 'method_executable', 'locator', 'proposed']) {
    assert.match(acRowSeg, new RegExp(`required:\\s*\\[[^\\]]*['"]${field}['"]`), `AC_ROW.required must name ${field}`)
  }
  assert.match(acRowSeg, /enum:\s*\[\s*['"]verified['"]\s*,\s*['"]declined['"]\s*,\s*['"]deferred['"]\s*,\s*['"]absent['"]\s*\]/, 'AC_ROW.disposition enum must be exactly [verified, declined, deferred, absent]')

  const acSubMatch = src.match(/const AC_SUBSTITUTION = \{[\s\S]*?\n\}/)
  assert.ok(acSubMatch, 'AC_SUBSTITUTION constant must exist')
  const acSubSeg = acSubMatch[0]
  assert.match(acSubSeg, /additionalProperties:\s*false/, 'AC_SUBSTITUTION must keep additionalProperties: false')
  for (const field of ['ac', 'locator', 'proposed']) {
    assert.match(acSubSeg, new RegExp(`required:\\s*\\[[^\\]]*['"]${field}['"]`), `AC_SUBSTITUTION.required must name ${field}`)
  }

  const acDiffMatch = src.match(/const AC_DIFF = \{[\s\S]*?\n\}/)
  assert.ok(acDiffMatch, 'AC_DIFF constant must exist')
  const acDiffSeg = acDiffMatch[0]
  assert.match(acDiffSeg, /additionalProperties:\s*false/, 'AC_DIFF must keep additionalProperties: false')
  for (const field of ['ac_source_present', 'ac_rows', 'ledger_ac_decisions', 'substituted']) {
    assert.match(acDiffSeg, new RegExp(`required:\\s*\\[[^\\]]*['"]${field}['"]`), `AC_DIFF.required must name ${field}`)
  }
  assert.match(acDiffSeg, /ac_rows:\s*\{\s*type:\s*['"]array['"],\s*items:\s*AC_ROW\s*\}/, 'AC_DIFF.ac_rows must be an array of AC_ROW')
  assert.match(acDiffSeg, /substituted:\s*\{\s*type:\s*['"]array['"],\s*items:\s*AC_SUBSTITUTION\s*\}/, 'AC_DIFF.substituted must be an array of AC_SUBSTITUTION')

  // codex F1 cycle 2 (enum-reference-is-observable): the item-level row/substitution guard must
  // read its accepted disposition members from AC_ROW.properties.disposition.enum -- the live
  // member expression, not a second free-standing literal list -- so the schema constant and the
  // runtime guard cannot drift apart. Presence-only: this proves the reference exists somewhere in
  // the file, not that no duplicate list exists elsewhere (residual, Risk and residuals).
  assert.match(src, /AC_ROW\.properties\.disposition\.enum/, 'the row/substitution guard must read AC_ROW.properties.disposition.enum, not a duplicated literal member list')

  // Behavioral half, in the same discipline as the VERDICT/DISPOSITION precedent (run.mjs:748):
  // a run whose ac-diff stub matches this schema shape still converges without a schema error.
  const acDiff = { ac_source_present: true, ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }], ledger_ac_decisions: [], substituted: [] }
  const { result } = await runArch({ issue: '138-ac-schema-shape' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: an unauthorized finding mints a register entry named ac-authority:<ac id> (VERIFY-hunk-3, ac-authority-prefix-per-finding)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC7', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { calls } = await runArch({ issue: '138-ac-prefix' }, convergingWithAcDiff(acDiff))
  const payload = registerPayload(calls)
  const minted = payload.entries.find((e) => e.name === 'ac-authority:AC7')
  assert.ok(minted, 'the per-finding entry must be named exactly "ac-authority:<ac id>"')
  assert.equal(minted.status, 'open')
  assert.equal(minted.raisedBy, 'test')
})

await test('ARCHITECT: result.summary states the AC_CHANGE pause and carries acReason (VERIFY-hunk-4, ac-change-summary-text)', async () => {
  const acDiff = { ac_source_present: false, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
  const { result } = await runArch({ issue: '138-ac-summary' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.match(result.summary, /ARCHITECT paused on an acceptance-criterion change/, 'summary must state the AC_CHANGE pause')
  assert.match(result.summary, /operator decision required/, 'summary must state that an operator decision is required')
  assert.ok(result.summary.includes(result.acReason), 'summary must carry the run\'s own acReason sentinel')
})

await test('ARCHITECT: a resumed run whose persisted register carries verdict AC_CHANGE is not latched by the already-converged guard, and Reconcile re-runs (VERIFY-hunk-5, ac-change-register-resumable)', async () => {
  // The `already converged` guard is keyed to `loaded.verdict === 'CONVERGED'` alone (:475) -- a
  // persisted AC_CHANGE register must NOT trip it. The resumed round's own ac-diff this time
  // authorizes the finding (ledger_ac_decisions carries AC9), so the run converges.
  const responder = resumeResponder({
    load: {
      found: true, artifacts_present: true, lastTurn: 8, verdict: 'AC_CHANGE',
      entries: [{ name: 'ac-authority:AC9', conclusion: 'dropped: x', evidence: 'e', status: 'open', raisedBy: 'test' }],
    },
    // The carried entry's raiser is 'test' (mintAcEntry always mints raisedBy: 'test'), so only a
    // test-side disposition can close it (raiser-only close rule) and let this round converge.
    'test-t9': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'], dispositions: [{ name: 'ac-authority:AC9', conclusion: 'authorized by operator', evidence: 'ledger', status: 'agreed' }] },
    'dev-t10': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'] },
    acDiff: {
      ac_source_present: true,
      ac_rows: [{ ac: 'AC9', carried: false, disposition: 'absent', method_executable: false, locator: '—', proposed: 'x' }],
      ledger_ac_decisions: ['AC9'], // now authorized -- the operator's [ac-decision] entry
      substituted: [],
    },
  })
  const { result, calls } = await runArch({ issue: '138-ac-resume-latch', resume: true }, responder)
  assert.notEqual(result.verdict, 'ESCALATE', 'a persisted AC_CHANGE register must not trip the CONVERGED-only already-converged guard')
  assert.ok(!/resume register already converged/.test(String(result.escalation ?? '')), 'the already-converged sentinel must not fire on a persisted AC_CHANGE verdict')
  assert.ok(calls.some((c) => c.label === 'ac-diff'), 'Reconcile must re-run on the resumed round')
  assert.equal(result.verdict, 'CONVERGED', 'the now-authorized finding must let the resumed run converge')
})

await test('ARCHITECT: a non-null but malformed ac-diff payload (wrong types / non-array fields) is treated the same as a missing return -- fail-closed (VERIFY-hunk-6, ac-diff-malformed-non-null)', async () => {
  const cases = [
    ['138-ac-malformed-1', { ac_source_present: 'yes', ac_rows: [], ledger_ac_decisions: [], substituted: [] }], // wrong type
    ['138-ac-malformed-2', { ac_source_present: true, ac_rows: 'not-an-array', ledger_ac_decisions: [], substituted: [] }],
    ['138-ac-malformed-3', { ac_source_present: true, ac_rows: [], ledger_ac_decisions: 'not-an-array', substituted: [] }],
    ['138-ac-malformed-4', { ac_source_present: true, ac_rows: [], ledger_ac_decisions: [], substituted: 'not-an-array' }],
  ]
  for (const [issueId, acDiff] of cases) {
    const { result } = await runArch({ issue: issueId }, convergingWithAcDiff(acDiff))
    assert.equal(result.verdict, 'AC_CHANGE', `${issueId}: a malformed non-null payload must resolve AC_CHANGE, not CONVERGED`)
    assert.equal(result.acReason, 'ac reconciliation unavailable', `${issueId}: malformed payload must carry the same sentinel as a missing return`)
    assert.deepEqual(result.acChange, [], `${issueId}: a malformed payload produces no findings`)
  }
})

await test('ARCHITECT: mintAcEntry updates an already-open ac-authority entry in place -- no duplicate, status reset to open (VERIFY-hunk-7, mint-upsert-branch)', async () => {
  // A resumed run whose register already carries an OPEN ac-authority:AC3 entry (the resume's own
  // carried agenda, per Register minting > 'The minted entries also give the resume round its
  // agenda') -- Reconcile re-mints the SAME finding this round (still unauthorized) and must UPDATE
  // the existing entry (conclusion/evidence refreshed, status set open) rather than append a
  // duplicate -- the register is a Map keyed by normalized name (toEntry/normalizeKey), so a second
  // register.set on the same key overwrites, but mintAcEntry's own `if (prior)` branch additionally
  // preserves the update-in-place discipline the raise() path already uses.
  const responder = resumeResponder({
    load: {
      found: true, artifacts_present: true, lastTurn: 8, verdict: 'AC_CHANGE',
      entries: [{ name: 'ac-authority:AC3', conclusion: 'stale conclusion', evidence: 'stale-evidence', status: 'open', raisedBy: 'test' }],
    },
    // Disposed this round (test-side, the raiser) so the resume converges and Reconcile actually
    // runs -- Reconcile then re-mints the SAME name, which is the upsert branch under test.
    'test-t9': { modified: false, accept: true, counters: [], accept_grounds: ['t: ok'], dispositions: [{ name: 'ac-authority:AC3', conclusion: 'believed resolved', evidence: 'e', status: 'agreed' }] },
    'dev-t10': { modified: false, accept: true, counters: [], accept_grounds: ['d: ok'] },
    acDiff: {
      ac_source_present: true,
      ac_rows: [{ ac: 'AC3', carried: false, disposition: 'absent', method_executable: false, locator: 'fresh-locator', proposed: 'still not carried' }],
      ledger_ac_decisions: [], // still unauthorized -- the same finding recurs this round
      substituted: [],
    },
  })
  const { result, calls } = await runArch({ issue: '138-ac-mint-upsert', resume: true }, responder)
  assert.equal(result.verdict, 'AC_CHANGE')
  const payload = registerPayload(calls)
  const matches = payload.entries.filter((e) => e.name === 'ac-authority:AC3')
  assert.equal(matches.length, 1, 'the recurring finding must update the existing entry, never duplicate it')
  assert.equal(matches[0].status, 'open')
  assert.notEqual(matches[0].conclusion, 'stale conclusion', 'the conclusion must be refreshed by this round\'s mint, not the stale carried one')
  assert.notEqual(matches[0].evidence, 'stale-evidence', 'the evidence must be refreshed by this round\'s mint, not the stale carried one')
})

// ---- ARCHITECT: item-level ac-diff validation (issue #138 cycle 2, codex F1 on PR #139) -------
// F1: acDiffWellFormed() validates only the top-level ac-diff shape and never descends into
// ac_rows[] / substituted[] items, so a row that is internally malformed but top-level-shaped-
// correctly reaches acKindOf()/the authorization join unvalidated and the run silently converges.
// Every leg below asserts the SENTINEL (acReason === 'ac reconciliation unavailable'), never the
// verdict alone (verification design > Testability assessment > "Assert the sentinel..."): some of
// these fixture shapes already reach AC_CHANGE today through the unauthorized-change path (a defect
// row that still yields a kind produces a finding with ac: '', which then fails the authorization
// join), so a verdict-only assertion would pass before the fix. All are RED against the as-is
// script (verification design > Testability assessment > RED validity).

await test('ARCHITECT: a row whose method_executable is a non-boolean string fails closed to AC_CHANGE with the reconciliation sentinel (AC1, row-nonboolean-method-executable)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: 'false', locator: 'x', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-nonbool-method' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a non-boolean method_executable must be caught by the fail-closed guard, not the unauthorized-change path')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a row whose carried is a non-boolean string fails closed to AC_CHANGE with the reconciliation sentinel (AC2, row-nonboolean-carried)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: 'false', disposition: 'verified', method_executable: true, locator: 'x', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-nonbool-carried' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a non-boolean carried must be caught by the fail-closed guard, not the unauthorized-change path')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a row whose disposition is outside the defined enum fails closed to AC_CHANGE with the reconciliation sentinel (AC3, row-out-of-enum-disposition)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: true, disposition: 'not-a-real-disposition', method_executable: true, locator: 'x', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-bad-enum' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'an out-of-enum disposition must be caught by the fail-closed guard, not the unauthorized-change path')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a row missing the required ac field fails closed to AC_CHANGE with the reconciliation sentinel (AC4, row-missing-ac)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-missing-ac' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a row missing ac must be caught by the fail-closed guard, not the unauthorized-change path')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a non-object ac_rows[] item (null or a bare string) fails closed to AC_CHANGE with the reconciliation sentinel, not a silent skip (nonobject-row-fails-closed)', async () => {
  const cases = [
    ['138-c2-row-null', [null]],
    ['138-c2-row-barestring', ['AC1']],
  ]
  for (const [issueId, ac_rows] of cases) {
    const acDiff = { ac_source_present: true, ac_rows, ledger_ac_decisions: [], substituted: [] }
    const { result } = await runArch({ issue: issueId }, convergingWithAcDiff(acDiff))
    assert.equal(result.verdict, 'AC_CHANGE', `${issueId}: a non-object row must not be silently skipped into a clean convergence`)
    assert.equal(result.acReason, 'ac reconciliation unavailable', `${issueId}: a non-object row must be caught by the fail-closed guard, not the unauthorized-change path`)
    assert.deepEqual(result.acChange, [], `${issueId}: a fail-closed row must produce no findings`)
  }
})

await test('ARCHITECT: a malformed substituted[] item (non-object, missing ac, or a non-string field) fails closed to AC_CHANGE with the reconciliation sentinel, not the unauthorized-change sentinel (substitution-item-fails-closed)', async () => {
  // Dispatch obligation 1: every fixture here pairs a clean, non-empty ac_rows row so the run does
  // not take the "ac list absent" branch (architect-deliberation.js:729) instead of the guard under
  // test -- an empty ac_rows array would assert the wrong branch (dispatch, .autoflow/issue-138-c2-
  // dispatch.md item 1). The shape mirrors the existing 'substitution arm' leg's clean row
  // (run.mjs:2621).
  const cleanRow = { ac: 'AC2', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }
  const cases = [
    ['138-c2-sub-null', null],
    ['138-c2-sub-missing-ac', { locator: 'x', proposed: 'x' }],
    ['138-c2-sub-nonstring-locator', { ac: 'AC1', locator: 123, proposed: 'x' }],
  ]
  for (const [issueId, subItem] of cases) {
    const acDiff = { ac_source_present: true, ac_rows: [cleanRow], ledger_ac_decisions: [], substituted: [subItem] }
    const { result } = await runArch({ issue: issueId }, convergingWithAcDiff(acDiff))
    assert.equal(result.verdict, 'AC_CHANGE', `${issueId}: a malformed substitution item must fail closed`)
    // The sentinel, never the verdict alone (Testability assessment): the latter two shapes reach
    // AC_CHANGE today through the unauthorized-change path (flatten() coerces a missing/non-string
    // field to '' or its String() form, still producing a 'substituted' finding that then fails the
    // authorization join) -- a verdict-only assertion would already pass pre-fix on those shapes.
    assert.equal(result.acReason, 'ac reconciliation unavailable', `${issueId}: must be caught by the fail-closed guard, not the unauthorized-change path`)
    assert.deepEqual(result.acChange, [], `${issueId}: a fail-closed substitution defect produces no findings`)
  }
})

await test('ARCHITECT: disposition "absent" with carried: true fails closed to AC_CHANGE with the reconciliation sentinel -- one direction only (absent-with-carried-true-fails-closed)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: true, disposition: 'absent', method_executable: true, locator: 'x', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-absent-carried-true' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'disposition: absent with carried: true is an internally inconsistent row and must fail closed')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
  // AC6 regression guard, restated here: the REVERSE direction (carried: false with a non-absent
  // disposition) must stay well-formed -- already pinned negatively by the existing leg
  // 'kind-table-is-computed-in-script' (its 'AC-drop' row is carried: false, disposition: 'declined'
  // and asserts derived kind 'dropped'); this leg does not repeat that assertion, only the forward
  // direction the codex finding's class covers.
})

// ---- ARCHITECT: VERIFY step-3 uncovered-clause legs (issue #138 cycle 2, RED2 c2) -------------
// Added post-GREEN per the orchestrator's VERIFY step 3 disposition
// (.autoflow/issue-138-c2-verify-report.md): four sub-clauses of acRowWellFormed /
// acSubstitutionWellFormed were uncovered by any cycle-2 leg even though they are explicit clauses
// of the feature design's row/substitution predicate table (ac non-empty-after-trim; locator /
// proposed as string) -- a verification-design coverage gap against an accepted design, not
// implementation overreach. These legs are expected to PASS immediately against the existing GREEN
// implementation -- that is the "add a test" branch of the check, not a defect. (The fifth finding,
// the redundant `typeof row.disposition === 'string'` clause at :392, is a Developer AI removal, not
// a test gap here.)

await test('ARCHITECT: a row whose ac is present but empty/whitespace-only fails closed to AC_CHANGE with the reconciliation sentinel (VERIFY-step-3, row-ac-whitespace-only)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: '   ', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-ac-whitespace' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a whitespace-only ac is not a valid identity key and must fail closed, not just an absent ac')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a row whose locator is a non-string fails closed to AC_CHANGE with the reconciliation sentinel (VERIFY-step-3, row-nonstring-locator)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 123, proposed: 'x' }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-nonstring-locator' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a non-string locator must be caught by the fail-closed guard')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a row whose proposed is a non-string fails closed to AC_CHANGE with the reconciliation sentinel (VERIFY-step-3, row-nonstring-proposed)', async () => {
  const acDiff = {
    ac_source_present: true,
    ac_rows: [{ ac: 'AC1', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 123 }],
    ledger_ac_decisions: [],
    substituted: [],
  }
  const { result, calls } = await runArch({ issue: '138-c2-row-nonstring-proposed' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a non-string proposed must be caught by the fail-closed guard')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a substituted[] item whose ac is present but empty/whitespace-only fails closed to AC_CHANGE with the reconciliation sentinel (VERIFY-step-3, substitution-ac-whitespace-only)', async () => {
  // Dispatch-pairing discipline carried from RED c2: a clean, non-empty ac_rows row accompanies the
  // malformed substituted[] item so the run does not take the "ac list absent" branch instead of the
  // guard under test (same clean-row shape as substitution-item-fails-closed, run.mjs).
  const cleanRow = { ac: 'AC2', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }
  const acDiff = { ac_source_present: true, ac_rows: [cleanRow], ledger_ac_decisions: [], substituted: [{ ac: ' ', locator: 'x', proposed: 'x' }] }
  const { result, calls } = await runArch({ issue: '138-c2-sub-ac-whitespace' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a whitespace-only substitution ac is not a valid identity key and must fail closed')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

await test('ARCHITECT: a substituted[] item whose proposed is a non-string fails closed to AC_CHANGE with the reconciliation sentinel (VERIFY-step-3, substitution-nonstring-proposed)', async () => {
  const cleanRow = { ac: 'AC2', carried: true, disposition: 'verified', method_executable: true, locator: 'x', proposed: 'verified' }
  const acDiff = { ac_source_present: true, ac_rows: [cleanRow], ledger_ac_decisions: [], substituted: [{ ac: 'AC1', locator: 'x', proposed: 123 }] }
  const { result, calls } = await runArch({ issue: '138-c2-sub-nonstring-proposed' }, convergingWithAcDiff(acDiff))
  assert.equal(result.verdict, 'AC_CHANGE')
  assert.equal(result.acReason, 'ac reconciliation unavailable', 'a non-string substitution proposed must be caught by the fail-closed guard')
  assert.deepEqual(result.acChange, [])
  const payload = registerPayload(calls)
  assert.ok(payload.entries.some((e) => e.name === 'ac-authority:reconciliation-unavailable' && e.status === 'open'))
})

// ---- ARCHITECT: scope-bounded review-response ceiling (issue #135) ------------------------
// `args.bounded` swaps the COLD ceiling from the config's `max_turns` (12) to its
// `bounded_max_turns` (4) — both read from .claude/autoflow/spawn-policy.json since issue #152,
// never from a literal in the script. Draft still runs, the first-turn devil's-advocate guidance
// is untouched, and the resume extension is unchanged. The flag is JSON/object-only — not
// salvaged from prose — so the catch-path mirror above stays byte-identical.

await test('ARCHITECT (#135): a bounded run that never converges stops at the config\'s 4-turn bounded ceiling', async () => {
  const { result, calls } = await runArch({ issue: '135-b1', bounded: true }, ceilingResponder())
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.turns, 4, 'the bounded ceiling is bounded_max_turns (4)')
  assert.ok(calls.some((c) => c.label.endsWith('-draft')), 'Draft still runs on a bounded cold run')
  assert.ok(!calls.some((c) => c.label === 'test-t5'), 'no turn beyond the bounded ceiling')
  assert.equal(result.escalation, 'No convergence within 4 turns (reached turn 4)')
})

await test('ARCHITECT (#135): a bounded run converging on its final turn pair returns CONVERGED at the ceiling', async () => {
  const responder = ceilingResponder({
    'test-t3': ACCEPT_TURN,
    'dev-t4': ACCEPT_TURN,
  })
  const { result } = await runArch({ issue: '135-b2', bounded: 'true' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.turns, 4)
})

await test('ARCHITECT (#135): bounded absent/false keeps the 12-turn cold ceiling; malformed bounded fails loud', async () => {
  const { result } = await runArch({ issue: '135-b3', bounded: false }, ceilingResponder())
  assert.equal(result.turns, 12, 'bounded:false is the cold max_turns path')
  await assert.rejects(
    () => runArch({ issue: '135-b4', bounded: 'yes' }, ceilingResponder()),
    /args\.bounded must be true, "true", false, "false" or absent/,
  )
})

await test('ARCHITECT (#135): bounded is not salvaged from prose args (catch-path parity preserved)', async () => {
  const { result } = await runArch('issue #135 bounded', ceilingResponder())
  assert.equal(result.turns, 12, 'a prose "bounded" token must not lower the ceiling')
})

console.log(failures ? `\n${failures} test(s) FAILED` : '\nall workflow regression tests passed')
process.exit(failures ? 1 : 0)
