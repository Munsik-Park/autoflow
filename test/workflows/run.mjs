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
// run. `extractIssue` mirrors architect-deliberation.js:31-44's string-arg
// normalization so the fixture targets the same issue id the script resolves
// (needed for the JSON-string-args test which drives issue '7').
// DCR-1 (issue #14, c2): mirror the SAME catch-path three-tier prose-salvage rule
// the scripts adopt (tier 1 hash /#(\d+)/, tier 2 issue-anchored /\bissue\s+#?(\d+)\b/i,
// tier 3 bare /(\d+)/ adopted ONLY when exactly one number is present -- otherwise
// ambiguous -> {} -> the loud-fail guard fires) so a prose-args fixture lands at the
// id the script itself resolves. This is the single source of the resolution rule at
// test time.
function extractIssue(args) {
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
          return issue ? { issue } : {}
        }
      })()
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

await test('ARCHITECT: draft non-null with a withheld artifact no longer early-ESCALATEs (regression lock on the §D7 capability removal, issue #62)', async () => {
  // REWRITTEN IN PLACE (issue #62, §D7/§D8) — was "draft non-null but artifact
  // missing -> early ESCALATE". The artifact-existence check (the
  // `import('node:fs')` block) is retired; this same driver (omitArtifact:
  // 'verif') must now converge normally instead of early-ESCALATEing.
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '845-4' }, responder, { omitArtifact: 'verif' })
  assert.equal(result.verdict, 'CONVERGED')
  assert.ok(result.rounds > 0, 'Converge loop must be entered even when a draft artifact was withheld')
  assert.ok(!String(result.escalation ?? '').includes('draft artifact missing'))
  assert.ok(calls.some((c) => /-r\d/.test(c.label)), 'Converge-round calls must be made')
})

// ---- ARCHITECT: sequential test->dev rounds + carry compaction + citation
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
    if (label === 'test-r1') {
      return new Promise((resolve) => setTimeout(() => {
        testResolved = true
        resolve({ response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] })
      }, 15))
    }
    if (label === 'dev-r1') {
      devSawTestResolved = testResolved
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
    }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  await runArch({ issue: '62-1' }, responder)
  assert.equal(devSawTestResolved, true, 'dev-r1 must be invoked only after test-r1 has resolved')
})

await test('ARCHITECT: dev-rN prompt carries the same-round test-rN counter token (AC-62-2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['TEST_PEER_TOKEN_62'], accept_grounds: [] }
    if (label === 'dev-r1') return { response: 'COUNTER', counters: ['dev-c1'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-2' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  assert.match(devR1, /TEST_PEER_TOKEN_62/)
})

await test('ARCHITECT: test-r2 lacks the round-2 dev token but carries the round-1 one via ${carry} (AC-62-3)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-r1') return { response: 'COUNTER', counters: ['R1_DEV_TOKEN_62'], accept_grounds: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['t1'], accept_grounds: [] }
    if (label === 'dev-r2') return { response: 'COUNTER', counters: ['R2_DEV_TOKEN_62'], accept_grounds: [] }
    if (label === 'test-r2') return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-3' }, responder)
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  assert.doesNotMatch(testR2, /R2_DEV_TOKEN_62/)
  assert.match(testR2, /R1_DEV_TOKEN_62/)
})

await test('ARCHITECT: recorded call-log index of test-rN precedes dev-rN, every round (AC-62-4)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r < 3) return { response: 'COUNTER', counters: [`c${r}`], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-4' }, responder)
  for (let r = 1; r <= 3; r++) {
    const testIdx = calls.findIndex((c) => c.label === `test-r${r}`)
    const devIdx = calls.findIndex((c) => c.label === `dev-r${r}`)
    assert.ok(testIdx >= 0 && devIdx >= 0, `round ${r} calls must exist`)
    assert.ok(testIdx < devIdx, `round ${r}: test-r${r} (idx ${testIdx}) must precede dev-r${r} (idx ${devIdx})`)
  }
})

await test('ARCHITECT: test-side null in a round still lets dev run that round (AC-62-8 new case)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('test-')) return null
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result, calls } = await runArch({ issue: '62-5' }, responder)
  assert.ok(calls.some((c) => c.label === 'dev-r1'), 'dev-r1 must still be invoked despite test-r1 being null')
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.rounds, 2)
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
await test('ARCHITECT: conclusion crosses the round boundary — a raised concern\'s argument/conclusion reaches both r2 prompts (AC17, conclusion-crosses-boundary)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-r1') return { response: 'COUNTER', counters: [{ agenda: 'NAME_X_67', locator: 'LOC_X_67', argument: 'CONCLUSION_PROBE_67' }], accept_grounds: [], dispositions: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-conclusion' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  assert.match(devR2, /CONCLUSION_PROBE_67/, 'dev-r2 must carry the substantive conclusion content, not only the name/locator')
  assert.match(testR2, /CONCLUSION_PROBE_67/, 'test-r2 must carry the substantive conclusion content, not only the name/locator')
})

await test('ARCHITECT: no counter lost to compaction — every open counter agenda reaches both r2 prompts (AC-62-10)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-r1') return { response: 'COUNTER', counters: [{ agenda: 'AGENDA_A_62', locator: 'a' }, { agenda: 'AGENDA_B_62', locator: 'b' }], accept_grounds: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: [{ agenda: 'AGENDA_C_62', locator: 'c' }], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-7' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  for (const tok of ['AGENDA_A_62', 'AGENDA_B_62', 'AGENDA_C_62']) {
    assert.ok(devR2.includes(tok), `dev-r2 must carry ${tok}`)
    assert.ok(testR2.includes(tok), `test-r2 must carry ${tok}`)
  }
})

await test('ARCHITECT: bare-string counter becomes a named register entry, name=string, evidence=unspecified (AC-62-11a re-anchored to the register / AC6)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-r1') return { response: 'COUNTER', counters: ['STALE_PROBE_62'], accept_grounds: [], dispositions: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-11a' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  for (const p of [devR2, testR2]) {
    assert.match(p, /STALE_PROBE_62/, 'the bare string becomes the entry name')
    assert.match(p, /unspecified/, 'evidence defaults to the unspecified placeholder')
  }
})

await test('ARCHITECT: record without agenda normalized via JSON.stringify(item), nothing dropped (AC-62-11b re-anchored to the register / AC6)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-r1') return { response: 'COUNTER', counters: [{ locator: 'PARTIAL_PROBE_62' }], accept_grounds: [], dispositions: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-11b' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  for (const p of [devR2, testR2]) {
    assert.ok(p.includes('PARTIAL_PROBE_62'), 'the locator content must reach the register (as the item\'s own JSON.stringify name)')
  }
})

await test('ARCHITECT: null counter item renders as unspecified concern, never {} or undefined (AC-62-11c re-anchored to the register / AC6)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    if (label === 'dev-r1') return { response: 'COUNTER', counters: [null], accept_grounds: [], dispositions: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-11c' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
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
    if (label === 'dev-r1') return { response: 'COUNTER', counters: [{ agenda: longAgenda, locator: 'src/x.js:1', argument: longConclusion }], accept_grounds: [], dispositions: [] }
    if (label === 'test-r1') return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-notrunc' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  for (const p of [devR2, testR2]) {
    assert.ok(!p.includes('…[truncated]'), 'no truncation marker literal may appear in a rendered prompt')
    assert.ok(p.includes(longAgenda), 'an over-long name must survive untruncated in the register')
    assert.ok(p.includes(longConclusion), 'an over-long conclusion must survive untruncated in the register')
  }
})

await test('ARCHITECT: dev-r1 prompt instructs section/item-ID citation for mutable design-doc targets (AC-62-15)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-12' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  assert.match(devR1, /cite it by section heading or item ID, never by line number/)
})

await test('ARCHITECT: dev-r1 prompt reserves path:line citation for immutable repository source (AC-62-16)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '62-13' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  assert.match(devR1, /reserve `path:line` for immutable repository source files/)
})

await test('ARCHITECT: DEV_OPEN_CONCERN_RULE (document-as-durable-channel) no longer reaches dev-r1 (AC8, open-concern-rule-gone)', async () => {
  // AC-62-28i deleted outright (its whole purpose is the mechanism AC8 removes). Retargeted
  // per feature design §5.1 test-contract-conflict: assert the literal phrase is gone from
  // the delivered script, not merely from one prompt.
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  assert.doesNotMatch(src, /record its argument as a named open-concern entry/)
})

await test('ARCHITECT: register no-relitigation instruction reaches both round prompts, byte-identical, and neither Draft prompt (AC-62-28ii re-anchored to REGISTER_RULE / AC11b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-register-scope' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  // No exact prose is fixed by the feature design for the new REGISTER_RULE constant (unlike
  // the #56/#59 constants it is not a reword of prior text) -- assert the stated semantic
  // content instead: a re-litigation-guard sentence naming both the closed statuses and the
  // "not reopened without a new verified fact" rule, present identically on both round-1
  // prompts (AC11b: REGISTER_RULE is byte-identical in dev-r*/test-r*) and absent from Draft.
  const reopenPattern = /not (?:be )?reopen\w* without (?:a )?(?:newly )?verified fact/i
  assert.match(devR1, reopenPattern, 'dev-r1 must carry the no-relitigation instruction')
  assert.match(testR1, reopenPattern, 'test-r1 must carry the no-relitigation instruction')
  const devMatch = devR1.match(reopenPattern)[0]
  const testMatch = testR1.match(reopenPattern)[0]
  assert.equal(devMatch, testMatch, 'the no-relitigation instruction must be byte-identical across roles')
  assert.doesNotMatch(devDraft, reopenPattern, 'dev-draft must not carry the round-prompt-only register rule')
  assert.doesNotMatch(testDraft, reopenPattern, 'test-draft must not carry the round-prompt-only register rule')
})

// ---- ARCHITECT: issue register + disposition redesign (issue #67) -------------
// Verification design §2 (.autoflow/issue-67-verification-design.md). The register replaces
// the round-local open-counter carry: a concern raised in round n and not disposed of must
// still reach round n+2's prompts (AC1), in place rather than duplicated (AC2), and a
// returned disposition must be able to flip its status (AC3) subject to raiser precedence
// (AC16) and admission rules (AC18). Each entry renders as four labelled lines plus a `---`
// terminator (AC4), with no character truncation (AC5, covered above) and no concern ever
// lost to normalization (AC6, covered above via the re-anchored AC-62-11a/b/c). None of
// these tests exist against the current carry-based script — every one is RED at HEAD.

await test('ARCHITECT: a raised, undisposed concern is still carried at round n+2 (AC1, register-carried)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_CARRIED_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    if (r === 2) return { response: 'COUNTER', counters: ['unrelated-c2'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-carried' }, responder)
  for (const label of ['dev-r2', 'test-r2', 'dev-r3', 'test-r3']) {
    const prompt = calls.find((c) => c.label === label).prompt
    assert.match(prompt, /NAME_CARRIED_67/, `${label} must still carry the undisposed concern`)
  }
})

await test('ARCHITECT: a resolved entry stays in the register alongside a fresh one — non-cumulative reassignment discriminator (AC2, register-cumulative)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_X_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return {
        response: 'COUNTER',
        counters: [{ agenda: 'NAME_Y_67', locator: 'l2', argument: 'a2' }],
        accept_grounds: [],
        dispositions: [{ name: 'NAME_X_67', conclusion: 'resolved', evidence: 'e', status: 'agreed' }],
      }
    }
    if (r === 2) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-cumulative' }, responder)
  const devR3 = calls.find((c) => c.label === 'dev-r3').prompt
  const testR3 = calls.find((c) => c.label === 'test-r3').prompt
  for (const p of [devR3, testR3]) {
    assert.match(p, /NAME_X_67/, 'the resolved entry must not be dropped by a wholesale reassignment')
    assert.match(p, /NAME_Y_67/, 'the fresh entry raised alongside the disposition must also be carried')
  }
})

await test('ARCHITECT: same name raised twice merges into one entry — in-place update, not duplication (AC2, near-miss-names-stay-distinct part 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) {
      return {
        response: 'COUNTER',
        counters: [
          { agenda: 'Register key', locator: 'l1', argument: 'a1' },
          { agenda: 'register  key', locator: 'l2', argument: 'a2' },
        ],
        accept_grounds: [],
        dispositions: [],
      }
    }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-nearmiss1' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const nameLines = devR2.match(/^name: .*$/gm) || []
  assert.equal(nameLines.length, 1, 'case/whitespace near-miss names must merge into a single entry')
  assert.match(devR2, /^name: Register key$/m, 'the merged entry keeps the first-raised display name')
})

await test('ARCHITECT: names differing by content stay distinct entries (AC2, near-miss-names-stay-distinct part 2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) {
      return {
        response: 'COUNTER',
        counters: [
          { agenda: 'Register key A', locator: 'l1', argument: 'a1' },
          { agenda: 'Register key B', locator: 'l2', argument: 'a2' },
        ],
        accept_grounds: [],
        dispositions: [],
      }
    }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-nearmiss2' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
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
      const r = Number(label.split('-r')[1])
      if (r === 1 && label.startsWith('dev-')) {
        return {
          response: 'COUNTER',
          counters: names.map((agenda) => ({ agenda, locator: 'l', argument: 'a' })),
          accept_grounds: [],
          dispositions: [],
        }
      }
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    }
    const { calls } = await runArch({ issue: `67-growth-${n}` }, responder)
    const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
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
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) {
      return {
        response: 'COUNTER',
        counters: [{ agenda: 'NAME_WS_67', locator: 'a\tb  c', argument: 'line1\nline2\r\nline3   end' }],
        accept_grounds: [],
        dispositions: [],
      }
    }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-entryshape' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const m = devR2.match(/^name: NAME_WS_67\nconclusion: ([^\n]*)\nevidence: ([^\n]*)\nstatus: ([^\n]*)\n---$/m)
  assert.ok(m, 'the entry must render as exactly four labelled lines followed by one terminator line')
  assert.equal(m[1], 'line1 line2 line3 end', 'embedded newlines/CRLF/space-runs in conclusion must collapse to single spaces')
  assert.equal(m[2], 'a b c', 'embedded tabs/space-runs in evidence must collapse to single spaces')
})

await test('ARCHITECT: a field whose flattened value is exactly "---" renders as a labelled content line, not a delimiter (AC4, entry-shape part 2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) {
      return { response: 'COUNTER', counters: [{ agenda: 'NAME_DASH_67', locator: 'l', argument: '---' }], accept_grounds: [], dispositions: [] }
    }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-dashfield' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  assert.match(devR2, /^conclusion: ---$/m, 'a field whose value is exactly the delimiter literal must still render as a labelled content line')
  const terminators = devR2.match(/^---$/gm) || []
  assert.equal(terminators.length, 1, 'the delimiter-valued field line must not be double-counted as a terminator')
})

await test('ARCHITECT: a returned disposition sets the entry status, which survives to the next round (AC3, disposition-applied)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_DISP_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_DISP_67', conclusion: 'fixed', evidence: 'e', status: 'agreed' }] }
    }
    if (r === 2) return { response: 'COUNTER', counters: ['stay-open'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-dispapplied' }, responder)
  const devR3 = calls.find((c) => c.label === 'dev-r3').prompt
  const testR3 = calls.find((c) => c.label === 'test-r3').prompt
  for (const p of [devR3, testR3]) {
    assert.match(p, /name: NAME_DISP_67[\s\S]{0,120}status: agreed/, 'the disposed entry must reach the next round showing its new status')
  }
})

await test('ARCHITECT: dispositions schema — VERDICT.required, additionalProperties, and the closed DISPOSITION item shape (AC15, disposition-schema-shape)', async () => {
  const src = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const verdictMatch = src.match(/const VERDICT = \{[\s\S]*?\n\}/)
  assert.ok(verdictMatch, 'VERDICT constant must exist')
  assert.match(verdictMatch[0], /additionalProperties:\s*false/, 'VERDICT must keep additionalProperties: false')
  assert.match(verdictMatch[0], /required:\s*\[[^\]]*['"]dispositions['"]/, 'dispositions must be in VERDICT.required (empty array permitted, not optional)')
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
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['c1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result } = await runArch({ issue: '67-schema' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: a disposition naming an entry no one raised is ignored — never minted, never reaches the ledger (AC18, disposition-admission part 1)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_REAL_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('test-')) {
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NEVER_RAISED_67', conclusion: 'c', evidence: 'e', status: 'rejected' }] }
    }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result, calls } = await runArch({ issue: '67-admission1' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  const devR3 = calls.find((c) => c.label === 'dev-r3')
  const testR3 = calls.find((c) => c.label === 'test-r3')
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
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_ENUM_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_ENUM_67', conclusion: 'c1', evidence: 'e1', status: 'agreed' }] }
    }
    if (r === 2) return { response: 'COUNTER', counters: ['stay-open'], accept_grounds: [], dispositions: [] }
    if (r === 3 && label.startsWith('dev-')) {
      return { response: 'COUNTER', counters: ['still-going'], accept_grounds: [], dispositions: [{ name: 'NAME_ENUM_67', conclusion: 'c2', evidence: 'e2', status: 'open' }] }
    }
    if (r === 3) return { response: 'COUNTER', counters: ['stay-open-2'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-admission2' }, responder)
  const devR4 = calls.find((c) => c.label === 'dev-r4').prompt
  assert.match(devR4, /name: NAME_ENUM_67[\s\S]{0,120}status: agreed/, 'a status outside the enum must be ignored — the entry keeps its last valid status')
})

await test('ARCHITECT: a disposition with a missing/non-string name is ignored without throwing (AC18, disposition-admission part 3)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_SHAPE_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 123, conclusion: 'c', evidence: 'e', status: 'agreed' }] }
    }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  await assert.doesNotReject(() => runArch({ issue: '67-admission3' }, responder))
})

await test('ARCHITECT: only the raiser\'s side can close an entry — a peer disposition proposes but leaves it open (AC16, raiser-precedence)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('test-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_PREC_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      // dev is the PEER here (test raised it) — a peer disposition must not close it.
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_PREC_67', conclusion: 'PEER_FIX_67', evidence: 'e', status: 'agreed' }] }
    }
    if (r === 2) return { response: 'COUNTER', counters: ['stay-open'], accept_grounds: [], dispositions: [] }
    if (r === 3 && label.startsWith('test-')) {
      // test is the RAISER — its own disposition closes it.
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_PREC_67', conclusion: 'PEER_FIX_67', evidence: 'e', status: 'agreed' }] }
    }
    if (r === 3) return { response: 'COUNTER', counters: ['stay-open-2'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-precedence' }, responder)
  const devR3 = calls.find((c) => c.label === 'dev-r3').prompt
  const testR3 = calls.find((c) => c.label === 'test-r3').prompt
  for (const p of [devR3, testR3]) {
    assert.match(p, /name: NAME_PREC_67[\s\S]{0,120}status: open/, 'a peer disposition must leave the entry open, one round after the peer proposal')
    assert.match(p, /PEER_FIX_67/, 'the peer\'s proposed conclusion/evidence must still be carried, even though status stays open')
  }
  const devR4 = calls.find((c) => c.label === 'dev-r4').prompt
  assert.match(devR4, /name: NAME_PREC_67[\s\S]{0,120}status: agreed/, 'the raiser\'s own disposition, returned in a later round, must close the entry')
})

await test('ARCHITECT: both sides ACCEPT with empty counters while an entry is still open still CONVERGES (AC7b, converge-unaffected-by-open-entry)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_SILENT_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { result } = await runArch({ issue: '67-silentconverge' }, responder)
  assert.equal(result.verdict, 'CONVERGED')
  assert.equal(result.rounds, 2, 'convergence must not be blocked by an entry no one ever disposed of')
})

await test('ARCHITECT: both round prompts render every open entry and instruct disposal before ACCEPT (AC7, open-entries-rendered-and-disposal-instructed)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_OPEN2_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'COUNTER', counters: ['t1'], accept_grounds: [], dispositions: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-opendisposal' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
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
    const r = Number(label.split('-r')[1])
    if (r === 1 && label.startsWith('dev-')) return { response: 'COUNTER', counters: [{ agenda: 'NAME_REJ_67', locator: 'l', argument: 'a' }], accept_grounds: [], dispositions: [] }
    if (r === 1) return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
    if (r === 2 && label.startsWith('dev-')) {
      return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [{ name: 'NAME_REJ_67', conclusion: 'not valid', evidence: 'e', status: 'rejected' }] }
    }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: [], dispositions: [] } // never grounded -> never converges
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
    if (label === 'dev-r1') return { response: 'COUNTER', counters: [{ agenda: 'NAME_ESC_67', locator: 'l', argument: 'GROUNDS_PROBE_67' }], accept_grounds: [], dispositions: [] }
    return { response: 'COUNTER', counters: ['still-open'], accept_grounds: [], dispositions: [] } // never accepts -> ESCALATE at MAX_ROUNDS
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-ledgerseed' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'], dispositions: [] }
  }
  const { calls } = await runArch({ issue: '67-recorddiscipline' }, responder)
  const noTranscription = /(?:measurement logs?|command output|code text)[\s\S]{0,80}(?:never|not)[\s\S]{0,40}(?:copie|transcri|paste)/i
  const designOnly = /design documents?[\s\S]{0,80}(?:only|current design)/i
  const readableNaming = /short[\s\S]{0,20}name/i
  const noTotals = /no totals?(?:\/| or )counts?|totals? (?:and|or) counts? (?:are )?(?:never|not)/i
  for (const label of ['dev-draft', 'test-draft', 'dev-r1', 'test-r1']) {
    const p = calls.find((c) => c.label === label).prompt
    assert.match(p, noTranscription, `${label} must forbid transcribing measurement logs/command output/code text`)
    assert.match(p, designOnly, `${label} must require design documents to hold only the current design`)
    assert.match(p, readableNaming, `${label} must require short readable names`)
    assert.match(p, noTotals, `${label} must forbid writing totals/counts into the documents`)
  }
})

await test('ARCHITECT: REGISTER_RULE does not duplicate the dual-disposition phrase into round 1 (AC20, carry-text-locks-preserved part b)', async () => {
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
// rule (A3 trimmed + A7 absence-case escape) is D3 unconditional — delivered every round
// including round 1, where `carry` is empty.

await test('ARCHITECT: carry framing (A1 non-evidentiary + A2 staleness) delivered on round 2, both roles (AC-56-1b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['STALE_PROBE_56'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-1' }, responder)
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  assert.match(devR2, /are a checklist of topics to re-verify, NOT evidence/)
  assert.match(devR2, /may already be resolved/)
  assert.match(testR2, /are a checklist of topics to re-verify, NOT evidence/)
  assert.match(testR2, /may already be resolved/)
})

await test('ARCHITECT: carry framing absent on round 1 (no counters carried yet) (AC-56-2b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['STALE_PROBE_56'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-2' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  assert.doesNotMatch(devR1, /are a checklist of topics to re-verify, NOT evidence/)
  assert.doesNotMatch(devR1, /may already be resolved/)
  assert.doesNotMatch(testR1, /are a checklist of topics to re-verify, NOT evidence/)
  assert.doesNotMatch(testR1, /may already be resolved/)
})

await test('ARCHITECT: citation rule + absence-case escape delivered to dev on round 1 (AC-56-3b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-3' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  assert.match(devR1, /re-read the counterpart document/)
  assert.match(devR1, /name the section where it would belong/)
})

await test('ARCHITECT: citation rule + absence-case escape delivered to test on round 1 (AC-56-4b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-4' }, responder)
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  assert.match(testR1, /re-read the counterpart document/)
  assert.match(testR1, /name the section where it would belong/)
})

await test('ARCHITECT: evidence-discipline segment byte-identical between dev and test round-1 prompts (AC-56-5)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-5' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  // Anchor-delimited extraction (verification design §1 AC-56-5): the substring between
  // the two literal anchors shared verbatim by both round-1 prompts.
  const extract = (s) => {
    const startAnchor = 'leave "accept_grounds" empty.'
    const endAnchor = ' Run every Bash command'
    const start = s.indexOf(startAnchor) + startAnchor.length
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
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['STALE_PROBE_56'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '56-6' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  const devR2 = calls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = calls.find((c) => c.label === 'test-r2').prompt
  assert.match(devR2, /by dismissing it with the current/)
  assert.match(testR2, /by dismissing it with the current/)
  assert.doesNotMatch(devR1, /by dismissing it with the current/)
  assert.doesNotMatch(testR1, /by dismissing it with the current/)
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-2' }, responder)
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  assert.ok(testDraft.includes(ADOPTION_A8), 'test-draft must carry A8')
  assert.ok(testDraft.includes(ADOPTION_A9), 'test-draft must carry A9')
})

await test('ARCHITECT: adoption-evidence rule reaches dev-r1, carry empty (AC-59-3b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-3' }, responder)
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  assert.ok(devR1.includes(ADOPTION_A8), 'dev-r1 must carry A8')
  assert.ok(devR1.includes(ADOPTION_A9), 'dev-r1 must carry A9')
  assert.ok(devR1.includes(ADOPTION_A10), 'dev-r1 must carry A10')
})

await test('ARCHITECT: adoption-evidence rule reaches test-r1 (AC-59-4b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '59-4' }, responder)
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  assert.ok(testR1.includes(ADOPTION_A8), 'test-r1 must carry A8')
  assert.ok(testR1.includes(ADOPTION_A9), 'test-r1 must carry A9')
  assert.ok(testR1.includes(ADOPTION_A10), 'test-r1 must carry A10')
})

await test('ARCHITECT: adoption-evidence delivery is unconditional, not carry-gated (AC-59-5b)', async () => {
  const countOccurrences = (s, sub) => s.split(sub).length - 1

  // Part (i): an r1-COUNTER run converges at round 2 — A9 must reach dev-r2/test-r2,
  // exactly once per prompt (guards accidental double-interpolation once carry is non-empty).
  const counterResponder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['STALE_PROBE_59'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls: counterCalls } = await runArch({ issue: '59-5a' }, counterResponder)
  const devR2 = counterCalls.find((c) => c.label === 'dev-r2').prompt
  const testR2 = counterCalls.find((c) => c.label === 'test-r2').prompt
  assert.equal(countOccurrences(devR2, ADOPTION_A9), 1, 'dev-r2 must carry A9 exactly once')
  assert.equal(countOccurrences(testR2, ADOPTION_A9), 1, 'test-r2 must carry A9 exactly once')

  // Part (ii) — the discriminator: an all-ACCEPT-without-accept_grounds run never converges
  // (accepted() requires accept_grounds.length > 0), so carry stays '' for all MAX_ROUNDS = 6
  // rounds. A9 must still reach dev-r1 AND dev-r6 — a carry-gated implementation would pass
  // 3b/4b/5b(i) and fail here.
  const noGroundsResponder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: [] }
  }
  const { calls: noGroundsCalls } = await runArch({ issue: '59-5b' }, noGroundsResponder)
  const devR1 = noGroundsCalls.find((c) => c.label === 'dev-r1').prompt
  const devR6 = noGroundsCalls.find((c) => c.label === 'dev-r6').prompt
  assert.ok(devR1, 'dev-r1 call must exist')
  assert.ok(devR6, 'dev-r6 call must exist (all 6 rounds run when accept_grounds never satisfies)')
  assert.ok(devR1.includes(ADOPTION_A9), 'dev-r1 must carry A9 unconditionally')
  assert.ok(devR6.includes(ADOPTION_A9), 'dev-r6 must carry A9 unconditionally')
})

await test('ARCHITECT: adoption-evidence Draft segment byte-identical across dev/test (AC-59-6b)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
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

await test('ARCHITECT: verification-depth OBLIGATION TEXT (not just the section path) reaches test-draft and test-r1, and stays off dev-draft/dev-r1 (AC-69-prompt-delivery)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '69-1' }, responder)
  const devDraft = calls.find((c) => c.label === 'dev-draft').prompt
  const testDraft = calls.find((c) => c.label === 'test-draft').prompt
  const devR1 = calls.find((c) => c.label === 'dev-r1').prompt
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  // The obligation's own content ("...names the failure mode it catches that no other layer
  // catches..."), not merely a "docs/autoflow-guide.md > ... > Verification depth" section-path
  // reference -- a path-only literal is satisfiable by an unrelated cross-reference and would not
  // discriminate "defined" from "the obligation's substance actually delivered".
  const obligationPattern = /failure mode (?:it catches |no other layer catches|that no other layer catches)/
  assert.match(testDraft, obligationPattern, 'test-draft must carry the Verification depth obligation TEXT')
  assert.match(testR1, obligationPattern, 'test-r1 must carry the Verification depth obligation TEXT')
  // ADR-0018 Decision 3: "The obligation is Test-AI-owned; no Developer-AI literal is added." --
  // negative fence mirroring the #56/#59 doesNotMatch idiom (:534-536, :1032-1035).
  assert.doesNotMatch(devDraft, obligationPattern, 'dev-draft must NOT carry the Verification depth obligation (Test-AI-owned, ADR-0018 Decision 3)')
  assert.doesNotMatch(devR1, obligationPattern, 'dev-r1 must NOT carry the Verification depth obligation (Test-AI-owned, ADR-0018 Decision 3)')
})

await test('ARCHITECT: test-r1 ACCEPT-condition sentence (not merely the prompt at large) gates on the per-layer unique-failure-mode requirement (AC-69-accept-gating)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { calls } = await runArch({ issue: '69-2' }, responder)
  const testR1 = calls.find((c) => c.label === 'test-r1').prompt
  // Extract the ACCEPT-condition sentence specifically -- the verification design's method is
  // "the ACCEPT-condition sentence of the test-r{n} prompt carries the depth clause", and advisory
  // (mentioned anywhere in the prompt) vs. gating (inside the sentence that actually governs
  // ACCEPT) is the discriminant a prompt-wide `.includes()` cannot make.
  const startAnchor = 'Respond ACCEPT ONLY when'
  const endAnchor = 'Otherwise return COUNTER/PARTIAL'
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
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['c1'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
  }
  const { result } = await runArch('issue #215 — architect deliberation for the caching layer', responder)
  assert.match(result.artifacts[0], /issue-215-/)
  assert.equal(result.verdict, 'CONVERGED')
})

await test('ARCHITECT: prose args, hash + incidental leading digit resolves 215 not 2 (DCR-2(a) lock)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch('deliberation for issue 215', responder)
  assert.match(result.artifacts[0], /issue-215-/)
})

await test('ARCHITECT: prose args, no hash + incidental earlier digit resolves 215 not 2 — reviewer witness fix lock (c2)', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft') || label === 'ledger') return 'ok'
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: ['x: ok'] }
  }
  const { result } = await runArch('build 42', responder)
  assert.match(result.artifacts[0], /issue-42-/)
  assert.equal(result.verdict, 'CONVERGED')
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
// verify-cause-branch.js, and this harness's extractIssue() mirror above. Assert
// the tier-2 anchor literal and the tier-3 uniqueness-guard literal appear in all
// three copies verbatim. Guard literal reconciled to the feature-design §3
// reference implementation's exact form (`all && all.length === 1`), per
// GATE:PLAN instruction, rather than the `?.length === 1` shorthand.
await test('source-parity: tier-2 anchor + tier-3 uniqueness guard identical across all three copies (c2, NEW)', async () => {
  const archSrc = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  const verifySrc = readFileSync(join(root, '.claude/workflows/verify-cause-branch.js'), 'utf8')
  const harnessSrc = readFileSync(join(root, 'test/workflows/run.mjs'), 'utf8')
  for (const [label, src] of [['architect-deliberation.js', archSrc], ['verify-cause-branch.js', verifySrc], ['run.mjs extractIssue()', harnessSrc]]) {
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

await test('AC-facilitator-prompt: ARCHITECT CONVERGED ledger prompt carries the next-allocation and check instructions', async () => {
  const responder = (label) => {
    if (label.endsWith('-draft')) return 'drafted'
    if (label === 'ledger') return 'ledger ok'
    const r = Number(label.split('-r')[1])
    if (r === 1) return { response: 'COUNTER', counters: ['c1'], accept_grounds: [] }
    return { response: 'ACCEPT', counters: [], accept_grounds: ['feasibility: existing structure supports it'] }
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
    return { response: 'ACCEPT', counters: [], accept_grounds: [] } // never grounds -> never converges
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

console.log(failures ? `\n${failures} test(s) FAILED` : '\nall workflow regression tests passed')
process.exit(failures ? 1 : 0)
