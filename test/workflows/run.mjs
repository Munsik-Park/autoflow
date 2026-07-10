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
import { readFileSync, writeFileSync, unlinkSync } from 'node:fs'
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

function makeAgent(responder, calls) {
  return async (prompt, opts = {}) => {
    const label = opts.label || ''
    calls.push({ label, prompt })
    return responder(label, prompt)
  }
}

// Fixture support for AC2 (issue #845): the real fs.existsSync check the
// implementation is expected to add runs against real on-disk artifacts, so
// the harness must write/remove the two draft artifacts around each ARCHITECT
// run. `extractIssue` mirrors architect-deliberation.js:23-25's string-arg
// normalization so the fixture targets the same issue id the script resolves
// (needed for the JSON-string-args test which drives issue '7').
function extractIssue(args) {
  const argv = typeof args === 'string'
    ? (() => { try { return JSON.parse(args) } catch (_) { return {} } })()
    : (args || {})
  return argv.issue
}

function artifactPaths(issue) {
  return {
    feature: join(root, `.autoflow/issue-${issue}-feature-design.md`),
    verif: join(root, `.autoflow/issue-${issue}-verification-design.md`),
  }
}

function writeDraftArtifacts(issue, omit) {
  const { feature, verif } = artifactPaths(issue)
  if (omit !== 'feature') writeFileSync(feature, '# feature design fixture\n')
  if (omit !== 'verif') writeFileSync(verif, '# verification design fixture\n')
}

function removeDraftArtifacts(issue) {
  const { feature, verif } = artifactPaths(issue)
  for (const p of [feature, verif]) {
    try { unlinkSync(p) } catch (_) { /* not written for this run (omit case) */ }
  }
}

const runArch = (args, responder, opts = {}) => {
  const calls = []
  const issue = extractIssue(args)
  writeDraftArtifacts(issue, opts.omitArtifact)
  return arch(args, phase, parallel, makeAgent(responder, calls), mockConsole)
    .then((result) => ({ result, calls }))
    .finally(() => removeDraftArtifacts(issue))
}
const runVerify = (args, responder) => {
  const calls = []
  return verify(args, phase, parallel, makeAgent(responder, calls), mockConsole).then((result) => ({ result, calls }))
}

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

// ---- ARCHITECT ----------------------------------------------------------------

await test('ARCHITECT: converges at round 2 with a grounded ACCEPT, ledger = mutual ACCEPT', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['c1'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
  const { result, calls } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.rounds, 2)
  assert.match(calls.find((c) => c.label === 'ledger').prompt, /ARCHITECT mutual ACCEPT/)
})

await test('ARCHITECT: first-exchange ACCEPT cannot converge (round 1 blocked)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] } // ACCEPT every round
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.rounds, 2, 'must not stop at round 1')
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: ACCEPT without grounds never converges -> ESCALATE + non-convergence ledger', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: [] }
  }
  const { result, calls } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.rounds, 6)
  const ledger = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledger, /ARCHITECT non-convergence/)
  assert.doesNotMatch(ledger, /ARCHITECT mutual ACCEPT/)
})

await test('ARCHITECT: ACCEPT carrying open counters does not converge', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: ['still open'], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch({ issue: '1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
})

await test('ARCHITECT: unresolved counter is threaded into the next round prompt', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['SCHEMA_GAP_42'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '1' }, responder)
  assert.match(calls.find((c) => c.label === 'dev-r2').prompt, /SCHEMA_GAP_42/)
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '845-1' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.rounds, 0, 'Converge loop must not be entered on a missing draft')
  assert.match(result.escalation, /draft agent missing/)
  assert.ok(!calls.some((c) => /-r\d/.test(c.label)), 'no Converge-round call should be made')
  const ledger = calls.find((c) => c.label === 'ledger').prompt
  assert.match(ledger, /missing/)
  assert.match(ledger, /ARCHITECT non-convergence/)
  assert.doesNotMatch(ledger, /ARCHITECT mutual ACCEPT/)
})

await test('ARCHITECT: both-null x2 consecutive -> early ESCALATE (budget not exhausted)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 || r === 2) return null // both dev-rN and test-rN null for rounds 1 and 2
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch({ issue: '845-2' }, responder)
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.rounds, 2, 'must exit at round 2, not exhaust MAX_ROUNDS (6)')
  assert.match(result.escalation, /sub-agent missing for 2 consecutive/)
})

await test('ARCHITECT: single transient one-side-null still converges (regression-lock, not RED-discriminating)', async () => {
  // Round 1: dev-r1 null, test-r1 a grounded (but round-1-blocked) ACCEPT. Round 2: both ACCEPT.
  // Per verification design §1/§3: this locks the "one-side-null does not early-exit and a
  // single null round still gets a retry" guarantee. It is NOT expected to fail against the
  // current pre-fix script (both pre- and post-fix converge at round 2 here) — its purpose is
  // to catch a FUTURE regression to an any-null-triggers-escalate threshold.
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return null
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch({ issue: '845-3' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.rounds, 2)
})

await test('ARCHITECT: draft non-null but artifact missing -> early ESCALATE', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '845-4' }, responder, { omitArtifact: 'verif' })
  assert.equal(result.verdict, 'ESCALATE')
  assert.equal(result.rounds, 0, 'Converge loop must not be entered on a missing artifact')
  assert.match(result.escalation, /draft artifact missing/)
  assert.ok(!calls.some((c) => /-r\d/.test(c.label)), 'no Converge-round call should be made')
})

// ---- VERIFY -------------------------------------------------------------------

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

console.log(failures ? `\n${failures} test(s) FAILED` : '\nall workflow regression tests passed')
process.exit(failures ? 1 : 0)
