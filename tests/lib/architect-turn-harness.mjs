// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// =============================================================================
// architect-turn-harness.mjs — issue #152 turn-convergence simulation harness
// =============================================================================
// Executes .claude/workflows/architect-deliberation.js OUTSIDE the Workflow
// runtime by wrapping the script body in an async function and stubbing the
// runtime-injected hooks (agent/parallel/phase/log/console). The `agent` stub
// dispatches on each call's declared label: the policy-load call is answered
// with the REAL .claude/autoflow/spawn-policy.json (so the workflow's own
// fail-closed policy validation runs against the shipped config), and each
// Converge turn is answered from the scenario's scripted turn list.
//
// Usage: node architect-turn-harness.mjs <repo-root>
// Prints one line per scenario: "<name> PASS" or "<name> FAIL: <detail>";
// exits non-zero when any scenario fails.
// =============================================================================
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node architect-turn-harness.mjs <repo-root>'); process.exit(2) }

const scriptSrc = readFileSync(join(root, '.claude/workflows/architect-deliberation.js'), 'utf8')
  .replace('export const meta', 'const meta')
const policyContent = readFileSync(join(root, '.claude/autoflow/spawn-policy.json'), 'utf8')
// Issue #159 regression fixture: the #157 cycle-1 register shape (all entries agreed, both
// sides' final reports accept: true / modified: true). `loadedFixture` renders it the way the
// register-load transcription channel returns a file — the closed REGISTER_FILE shape, with
// `lastResponses` reduced to each side's modified/accept pair.
const fixture159 = JSON.parse(readFileSync(join(root, 'tests/fixtures/issue-159-register-all-accept.json'), 'utf8'))
const loadedFixture = (f) => ({
  found: true, artifacts_present: true, lastTurn: f.lastTurn, verdict: f.verdict,
  entries: f.entries.map((e) => ({ ...e })),
  lastResponses: {
    dev: f.lastResponses.dev && { modified: f.lastResponses.dev.modified, accept: f.lastResponses.dev.accept },
    test: f.lastResponses.test && { modified: f.lastResponses.test.modified, accept: f.lastResponses.test.accept },
  },
})

// eslint-disable-next-line no-new-func
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const wf = new AsyncFunction('args', 'agent', 'parallel', 'phase', 'log', 'console', scriptSrc)

// One scripted turn: [modified, accept] plus optional counters. `null` scripts
// a missing (errored/skipped) sub-agent turn.
const turnOf = (t) => t === null ? null : {
  modified: t[0], accept: t[1],
  counters: t[2] || [],
  accept_grounds: t[1] ? ['scripted'] : [],
  dispositions: [],
}

async function run(scenario) {
  const calls = []
  const prompts = {}
  const turns = [...scenario.turns]
  const agent = async (prompt, opts) => {
    const label = (opts && opts.label) || ''
    calls.push(label)
    prompts[label] = prompt
    if (label === 'policy-load') return { found: true, content: scenario.policyContent || policyContent }
    if (label === 'dev-draft' || label === 'test-draft') return 'drafted'
    if (label === 'register-load') return scenario.register
    if (label === 'ac-diff') return {
      ac_source_present: true,
      ac_rows: [{ ac: 'AC1', carried: true, disposition: 'automated', reason_stated: true, locator: 'spec', proposed: 'automated' }],
      ledger_ac_decisions: [],
      substituted: [],
    }
    if (label === 'ledger' || label === 'register-write') return 'ok'
    const m = label.match(/^(test|dev)-t(\d+)$/)
    if (m) {
      if (!turns.length) throw new Error(`scenario ran out of scripted turns at ${label}`)
      const scripted = turns.shift()
      if (scripted.side && scripted.side !== m[1]) throw new Error(`side mismatch at ${label}: scripted ${scripted.side}`)
      const v = turnOf(scripted.v)
      if (v === null) throw new Error('scripted missing turn') // absorbed by the script's .catch
      return v
    }
    throw new Error(`unexpected agent label: ${label}`)
  }
  const parallel = (thunks) => Promise.all(thunks.map((f) => Promise.resolve().then(f).catch(() => null)))
  const result = await wf(scenario.args, agent, parallel, () => {}, () => {}, { log: () => {} })
  return { result, calls, prompts, leftover: turns.length }
}

const scenarios = [
  // Issue #152 simulation Case A — immediate agreement: two unmodified accepts.
  { name: 'case-A-immediate-agreement', args: { issue: '152' },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 2 },
  // Case B — a modifying accept never converges; the modified design returns to Test.
  { name: 'case-B-modified-accept-continues', args: { issue: '152' },
    turns: [
      { side: 'test', v: [false, true] }, { side: 'dev', v: [true, true] },
      { side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 4 },
  // Case C — intermediate accepts are irrelevant while modifications continue.
  { name: 'case-C-revision-chain', args: { issue: '152' },
    turns: [
      { side: 'test', v: [true, false] }, { side: 'dev', v: [true, true] },
      { side: 'test', v: [true, true] }, { side: 'dev', v: [false, true] },
      { side: 'test', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 5 },
  // Case D — disagreement without modification: runs to the ceiling, then ESCALATE.
  { name: 'case-D-ceiling-escalate', args: { issue: '152' },
    turns: Array.from({ length: 12 }, (_, i) => ({ v: i % 2 === 0 ? [false, false] : [false, true] })),
    expect: (r) => r.result.verdict === 'ESCALATE'
      && r.result.turns === 12
      && r.result.escalation === 'No convergence within 12 turns (reached turn 12)' },
  // Bounded run: the config's bounded ceiling governs.
  { name: 'bounded-ceiling', args: { issue: '152', bounded: 'true' },
    turns: Array.from({ length: 4 }, () => ({ v: [false, false] })),
    expect: (r) => r.result.verdict === 'ESCALATE'
      && r.result.escalation === 'No convergence within 4 turns (reached turn 4)' },
  // Resume: continues the persisted turn count, admits exactly one further
  // exchange (two turns), and its first turn is predecessor-less — the pair
  // that converges is the resumed exchange's own two turns.
  { name: 'resume-one-exchange', args: { issue: '152', resume: 'true' },
    register: { found: true, artifacts_present: true, lastTurn: 12, verdict: 'ESCALATE',
      entries: [{ name: 'open concern', conclusion: 'c', evidence: 'e', status: 'open', raisedBy: 'test' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 14 && r.result.resumed === true },
  // Resume with only its final turn accepting: the predecessor-less first turn
  // cannot converge alone, so the run escalates at its ceiling.
  { name: 'resume-single-accept-insufficient', args: { issue: '152', resume: 'true' },
    register: { found: true, artifacts_present: true, lastTurn: 12, verdict: 'ESCALATE',
      entries: [{ name: 'open concern', conclusion: 'c', evidence: 'e', status: 'open', raisedBy: 'test' }] },
    turns: [{ side: 'test', v: [true, false] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'ESCALATE' && r.result.turns === 14 },
  // Issue #159 — the all-accept terminal state {both accept, both modified, no open entry}.
  // The fixture mirrors the #157 cycle-1 register: every entry agreed, each side's final
  // report accept: true with modified: true. The register load transcribes `lastResponses`
  // in the reduced shape; the guard admits the resume as a confirmation exchange.
  { name: 'issue-159-all-accept-terminal-admitted', args: { issue: '157', resume: 'true' },
    register: loadedFixture(fixture159),
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 18 && r.result.resumed === true
      && /confirmation exchange/.test(r.prompts['test-t17'] || '') && /confirmation exchange/.test(r.prompts['dev-t18'] || '') },
  // The same register with one side's final report NOT accepting stays refused: no open entry
  // and no all-accept state is the infrastructure-cause shape the guard was written for.
  { name: 'issue-159-no-open-not-all-accept-refused', args: { issue: '157', resume: 'true' },
    register: (() => { const reg = loadedFixture(fixture159); reg.lastResponses.dev.accept = false; return reg })(),
    turns: [],
    expect: (r) => r.result.verdict === 'ESCALATE' && r.result.turns === 16
      && r.result.escalation === 'resume register has no open entry' },
  // A pre-#159 register (no lastResponses) with no open entry is refused as before.
  { name: 'issue-159-legacy-register-no-open-refused', args: { issue: '157', resume: 'true' },
    register: (() => { const reg = loadedFixture(fixture159); delete reg.lastResponses; return reg })(),
    turns: [],
    expect: (r) => r.result.verdict === 'ESCALATE' && r.result.turns === 16
      && r.result.escalation === 'resume register has no open entry' },
  // PR #162 review (Medium): a cleanly CONVERGED register is itself {both accept, no open entry}.
  // The `already converged` refusal must win over the all-accept admission, or a resume would
  // re-open a design the ledger already records under "ARCHITECT mutual ACCEPT".
  { name: 'issue-159-converged-all-accept-still-refused', args: { issue: '157', resume: 'true' },
    register: { found: true, artifacts_present: true, lastTurn: 2, verdict: 'CONVERGED', entries: [],
      lastResponses: { dev: { modified: false, accept: true }, test: { modified: false, accept: true } } },
    turns: [],
    expect: (r) => r.result.verdict === 'ESCALATE' && r.result.turns === 2
      && r.result.escalation === 'resume register already converged'
      && !r.calls.some((c) => /^(test|dev)-t\d+$|^ac-diff$|^register-write$/.test(c)) },
  // A confirmation exchange whose first turn still edits does not converge — the #152 rule holds
  // unchanged inside the admitted exchange; the escalated register is rewritten and resumable again.
  { name: 'issue-159-confirmation-exchange-still-editing', args: { issue: '157', resume: 'true' },
    register: loadedFixture(fixture159),
    turns: [{ side: 'test', v: [true, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'ESCALATE' && r.result.turns === 18 },
  // An ordinary resume (open entry present) is NOT framed as a confirmation exchange, and every
  // Converge turn — cold or resumed — carries the convergence rule sentence.
  { name: 'issue-159-convergence-rule-on-every-turn', args: { issue: '152' },
    turns: [{ side: 'test', v: [true, false] }, { side: 'dev', v: [false, true] }, { side: 'test', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED'
      && ['test-t1', 'dev-t2', 'test-t3'].every((k) => /Convergence rule: this deliberation terminates only when two consecutive turns both report modified: false, accept: true/.test(r.prompts[k] || ''))
      && ['test-t1', 'dev-t2', 'test-t3'].every((k) => /do not edit either document — report modified: false/.test(r.prompts[k] || ''))
      && !Object.values(r.prompts).some((p) => /confirmation exchange/.test(p)) },
  // Two consecutive missing turns (one per side) => infrastructure escalation.
  { name: 'consecutive-missing-turns', args: { issue: '152' },
    turns: [{ v: null }, { v: null }],
    expect: (r) => r.result.verdict === 'ESCALATE'
      && r.result.escalation === 'sub-agent missing for 2 consecutive turn(s)' },
  // A single missing turn does not pair across the gap: the two unmodified
  // accepts AROUND the hole are same-side and must not converge.
  { name: 'missing-turn-breaks-pair', args: { issue: '152' },
    turns: [
      { side: 'test', v: [false, true] }, { v: null },
      { side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 4 },
  // Missing deliberation_caps row => fail-closed with its own sentinel.
  { name: 'caps-missing-fail-closed', args: { issue: '152' },
    policyContent: JSON.stringify((() => { const p = JSON.parse(policyContent); delete p.deliberation_caps; return p })()),
    turns: [],
    expect: (r) => r.result.verdict === 'ESCALATE'
      && /spawn policy deliberation caps incomplete/.test(r.result.escalation) },
]

let failed = 0
for (const s of scenarios) {
  try {
    const r = await run(s)
    if (s.expect(r) && r.leftover === 0) console.log(`${s.name} PASS`)
    else { failed++; console.log(`${s.name} FAIL: verdict=${r.result.verdict} turns=${r.result.turns} escalation=${JSON.stringify(r.result.escalation)} leftover=${r.leftover}`) }
  } catch (e) {
    failed++; console.log(`${s.name} FAIL: ${e.message}`)
  }
}
process.exit(failed ? 1 : 0)
