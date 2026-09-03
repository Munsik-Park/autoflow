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

// Issue #160 regression fixture: the transcription the ac-diff channel returns for the #157
// cycle-1 verification design (tests/fixtures/issue-160-split-rows-verification-design.md).
const fixture160 = JSON.parse(readFileSync(join(root, 'tests/fixtures/issue-160-ac-diff-split-rows.json'), 'utf8'))

// eslint-disable-next-line no-new-func
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const wf = new AsyncFunction('args', 'agent', 'parallel', 'phase', 'log', 'console', scriptSrc)

// One scripted turn: [modified, accept] plus optional counters and (issue #166) optional
// dispositions. `null` scripts a missing (errored/skipped) sub-agent turn.
const turnOf = (t) => t === null ? null : {
  modified: t[0], accept: t[1],
  counters: t[2] || [],
  accept_grounds: t[1] ? ['scripted'] : [],
  dispositions: t[3] || [],
}

async function run(scenario) {
  const calls = []
  const prompts = {}
  // The schema each call declared (issue #166): the disposition-name enum is asserted from it.
  const schemas = {}
  const turns = [...scenario.turns]
  const agent = async (prompt, opts) => {
    const label = (opts && opts.label) || ''
    calls.push(label)
    prompts[label] = prompt
    schemas[label] = opts && opts.schema
    if (label === 'policy-load') return { found: true, content: scenario.policyContent || policyContent }
    if (label === 'dev-draft' || label === 'test-draft') return 'drafted'
    if (label === 'register-load') return scenario.register
    // Reconcile's transcription. A scenario may script the payload (issue #160); the default is
    // one clean carried row, exactly the post-#160 shape — no `substituted` list.
    if (label === 'ac-diff') return scenario.acDiff || {
      ac_source_present: true,
      ac_rows: [{ ac: 'AC1', carried: true, disposition: 'automated', reason_stated: true, locator: 'spec', proposed: 'automated' }],
      ledger_ac_decisions: [],
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
  return { result, calls, prompts, schemas, leftover: turns.length }
}
// Issue #166 shorthands: the snapshot paths a side's turn prompt names, and the register-write
// payload (the persisted register is the only place an observation's status is observable).
const snap = (issue, side, doc) => `.autoflow/issue-${issue}-architect-snapshot-${side}-${doc}.md`
const dispositionNameEnum = (schema) => {
  const d = schema && schema.properties && schema.properties.dispositions
  const n = d && d.items && d.items.properties && d.items.properties.name
  return n && n.enum
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
  // Issue #160 — the #157 cycle-1 verification-design shape: one AC id carried by TWO rows whose
  // propositions differ (the criterion split by verification method). The fixture is the
  // payload the transcription channel returns for that design (tests/fixtures/issue-160-*.json):
  // AC1 appears once in `ac_rows`, carried and automated. The run converges; no AC_CHANGE.
  { name: 'issue-160-split-rows-no-pause', args: { issue: '157' },
    acDiff: fixture160,
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.acChange.length === 0 && r.result.acReason === null },
  // The ac-diff prompt asks for no property comparison: the channel has no `substituted` reading
  // to return, so the halt cannot be reintroduced by the channel alone.
  { name: 'issue-160-ac-diff-prompt-no-property-comparison', args: { issue: '157' },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED'
      && !/substituted/i.test(r.prompts['ac-diff'] || '')
      && !/DIFFERENT property/.test(r.prompts['ac-diff'] || '')
      && /Do not compare the wording or the meaning/.test(r.prompts['ac-diff'] || '') },
  // A channel still answering from the pre-#160 prompt may return a `substituted` list. It is not
  // read: the payload stays well-formed (no fail-closed `reconciliation unavailable`) and the
  // legacy finding derives nothing.
  { name: 'issue-160-legacy-substituted-list-ignored', args: { issue: '157' },
    acDiff: { ...fixture160, substituted: [{ ac: 'AC1', locator: 'row 2', proposed: 'a different property' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.acChange.length === 0 && r.result.acReason === null },
  // The two remaining kinds still pause (issue #138 / #153 arms, unchanged by #160).
  { name: 'issue-160-dropped-still-pauses', args: { issue: '157' },
    acDiff: { ac_source_present: true, ledger_ac_decisions: [],
      ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', reason_stated: false, locator: '—', proposed: '' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'AC_CHANGE' && r.result.acChange.length === 1
      && r.result.acChange[0].kind === 'dropped' && r.result.acChange[0].ac === 'AC1' },
  { name: 'issue-160-unreasoned-still-pauses', args: { issue: '157' },
    acDiff: { ac_source_present: true, ledger_ac_decisions: [],
      ac_rows: [{ ac: 'AC1', carried: true, disposition: 'reduced', reason_stated: false, locator: 'row 1', proposed: 'manual' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'AC_CHANGE' && r.result.acChange.length === 1
      && r.result.acChange[0].kind === 'unreasoned' },
  // An `[ac-decision]` entry naming the id still authorizes the finding.
  { name: 'issue-160-dropped-authorized-by-ledger', args: { issue: '157' },
    acDiff: { ac_source_present: true, ledger_ac_decisions: ['AC1'],
      ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', reason_stated: false, locator: '—', proposed: '' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.acChange.length === 0 },
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
  // ---- Issue #166 — deliberation cost structure ------------------------------------------
  // Counter substance: from the third turn on, a counter that names no change (`changes` empty)
  // is an observation — not open, owed no disposition, rendered by name only, persisted under its
  // own status; the run converges as soon as the turns pair.
  { name: 'issue-166-late-counter-without-changes-is-observation', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false] }, { side: 'dev', v: [false, true] },
      { side: 'test', v: [false, false, [{ agenda: 'PROSE_NIT', locator: '§2', argument: 'wording', changes: '' }]] },
      { side: 'dev', v: [false, true] }, { side: 'test', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 5
      && !/name: PROSE_NIT/.test(r.prompts['dev-t4'] || '')
      && /^observation: [^\n]*PROSE_NIT/m.test(r.prompts['dev-t4'] || '')
      && !/with these open counters/.test(r.prompts['dev-t4'] || '')
      && /owe no disposition: PROSE_NIT/.test(r.prompts['dev-t4'] || '')
      && /"name": "PROSE_NIT",[\s\S]{0,200}"status": "observation"/.test(r.prompts['register-write'] || '') },
  // A late counter that names its change keeps the full open-entry path: rendered in full, handed
  // to the peer as a current counter with its `changes`, and — as before — never a convergence input.
  { name: 'issue-166-late-counter-with-changes-stays-open', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false] }, { side: 'dev', v: [false, true] },
      { side: 'test', v: [false, false, [{ agenda: 'REAL_GAP', locator: '§3', argument: 'the guard forbids this citation', changes: 'AC2' }]] },
      { side: 'dev', v: [false, true] }, { side: 'test', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 5
      && /name: REAL_GAP[\s\S]{0,160}status: open/.test(r.prompts['dev-t4'] || '')
      && /with these open counters[^\n]*"changes":"AC2"/.test(r.prompts['dev-t4'] || '')
      && /"name": "REAL_GAP",[\s\S]{0,200}"status": "open"/.test(r.prompts['register-write'] || '') },
  // The first exchange is exempt: a turn-1 bare-string counter is an open entry.
  { name: 'issue-166-first-exchange-counter-exempt', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false, ['EARLY']] }, { side: 'dev', v: [false, false] },
      { side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 4
      && /name: EARLY[\s\S]{0,160}status: open/.test(r.prompts['dev-t2'] || '')
      && !/From this turn on a counter whose "changes" is empty/.test(r.prompts['test-t1'] || '')
      && !/From this turn on a counter whose "changes" is empty/.test(r.prompts['dev-t2'] || '')
      && /From this turn on a counter whose "changes" is empty/.test(r.prompts['test-t3'] || '') },
  // Closed entries render by name only: the agreed entry appears under `agreed:` and never as its
  // four lines; the open one stays in full.
  { name: 'issue-166-closed-entry-renders-name-only', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false, [{ agenda: 'CLOSE_ME', locator: 'l', argument: 'THE_ARGUMENT_TEXT', changes: 'AC1' }, { agenda: 'STAY_OPEN', locator: 'l', argument: 'still owed', changes: 'AC3' }]] },
      { side: 'dev', v: [false, false] },
      { side: 'test', v: [false, false, [], [{ name: 'CLOSE_ME', conclusion: 'done', evidence: 'e', status: 'agreed' }]] },
      { side: 'dev', v: [false, true] }, { side: 'test', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 5
      && /^agreed: CLOSE_ME$/m.test(r.prompts['dev-t4'] || '')
      && !/name: CLOSE_ME/.test(r.prompts['dev-t4'] || '')
      && !/conclusion: done/.test(r.prompts['dev-t4'] || '')
      && /name: STAY_OPEN[\s\S]{0,160}status: open/.test(r.prompts['dev-t4'] || '')
      && /Closed register entries — names only/.test(r.prompts['dev-t4'] || '') },
  // A disposition on a closed entry is ignored: the entry keeps its status.
  { name: 'issue-166-disposition-on-closed-entry-ignored', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false, [{ agenda: 'X', locator: 'l', argument: 'a', changes: 'AC1' }]] },
      { side: 'dev', v: [false, false] },
      { side: 'test', v: [false, false, [], [{ name: 'X', conclusion: 'done', evidence: 'e', status: 'agreed' }]] },
      { side: 'dev', v: [false, false] },
      { side: 'test', v: [false, false, [], [{ name: 'X', conclusion: 'changed my mind', evidence: 'e', status: 'rejected' }]] },
      { side: 'dev', v: [false, true] }, { side: 'test', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 7
      && /^agreed: X$/m.test(r.prompts['dev-t6'] || '')
      && !/^rejected: /m.test(r.prompts['dev-t6'] || '') },
  // The disposition-name enum is the open set: offered when an entry is open, absent otherwise.
  { name: 'issue-166-disposition-name-enum-is-open-set', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false, ['A', 'B']] }, { side: 'dev', v: [false, false] },
      { side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED'
      && dispositionNameEnum(r.schemas['test-t1']) === undefined
      && JSON.stringify(dispositionNameEnum(r.schemas['dev-t2'])) === JSON.stringify(['A', 'B']) },
  // Snapshot / diff: a side's first cold turn snapshots and reads in full; its next turn diffs
  // against that snapshot first and reads the hunks.
  { name: 'issue-166-snapshot-first-then-read-by-diff', args: { issue: '166' },
    turns: [
      { side: 'test', v: [false, false] }, { side: 'dev', v: [false, false] },
      { side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] },
    ],
    expect: (r) => r.result.verdict === 'CONVERGED'
      && /Snapshot first/.test(r.prompts['test-t1']) && !/Read by diff/.test(r.prompts['test-t1'])
      && r.prompts['test-t1'].includes(`cp .autoflow/issue-166-feature-design.md ${snap('166', 'test', 'feature-design')}`)
      && /Snapshot first/.test(r.prompts['dev-t2'])
      && r.prompts['dev-t2'].includes(`cp .autoflow/issue-166-verification-design.md ${snap('166', 'dev', 'verification-design')}`)
      && /Read by diff, not in full/.test(r.prompts['test-t3']) && !/Snapshot first/.test(r.prompts['test-t3'])
      && r.prompts['test-t3'].includes(`diff -u ${snap('166', 'test', 'feature-design')} .autoflow/issue-166-feature-design.md`)
      && /Read by diff, not in full/.test(r.prompts['dev-t4'])
      && r.prompts['dev-t4'].includes(`diff -u ${snap('166', 'dev', 'verification-design')} .autoflow/issue-166-verification-design.md`) },
  // A resume turn reads by diff against the escalated run's snapshot, and the substance rule binds.
  { name: 'issue-166-resume-turn-reads-by-diff-and-binds-substance', args: { issue: '166', resume: 'true' },
    register: { found: true, artifacts_present: true, lastTurn: 12, verdict: 'ESCALATE',
      entries: [{ name: 'open concern', conclusion: 'c', evidence: 'e', status: 'open', raisedBy: 'test' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 14
      && /Read by diff, not in full/.test(r.prompts['test-t13']) && !/Snapshot first/.test(r.prompts['test-t13'])
      && /From this turn on a counter whose "changes" is empty/.test(r.prompts['test-t13']) },
  // A register holding only observations is a no-open-entry register: with both sides accepting
  // it is admitted as a confirmation exchange, and the observation rehydrates under its status.
  { name: 'issue-166-observation-only-register-all-accept-resumable', args: { issue: '166', resume: 'true' },
    register: { found: true, artifacts_present: true, lastTurn: 12, verdict: 'ESCALATE',
      entries: [{ name: 'OBS_ONLY', conclusion: 'c', evidence: 'e', status: 'observation', raisedBy: 'dev' }],
      lastResponses: { dev: { modified: true, accept: true }, test: { modified: true, accept: true } } },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED' && r.result.turns === 14
      && /confirmation exchange/.test(r.prompts['test-t13'] || '')
      && /^observation: OBS_ONLY$/m.test(r.prompts['test-t13'] || '')
      && /"name": "OBS_ONLY",[\s\S]{0,200}"status": "observation"/.test(r.prompts['register-write'] || '') },
  // An observation is never an escalation ground: a run that reaches the ceiling with only an
  // observation on the register records the no-open-entry fallback.
  { name: 'issue-166-observation-not-escalation-ground', args: { issue: '166' },
    turns: Array.from({ length: 12 }, (_, i) => ({
      v: i === 2 ? [false, false, [{ agenda: 'OBS_ONLY', locator: 'l', argument: 'a remark', changes: '' }]] : [false, false],
    })),
    expect: (r) => r.result.verdict === 'ESCALATE' && r.result.turns === 12
      && /the register held no open entry/.test(r.prompts['ledger'] || '')
      && !/name: OBS_ONLY/.test(r.prompts['ledger'] || '') },
  // Reconcile's minted AC entry names its change, so it stays OPEN after the first exchange — the
  // operator's re-entry depends on it (the `no open entry` guard).
  { name: 'issue-166-ac-mint-stays-open', args: { issue: '166' },
    acDiff: { ac_source_present: true, ledger_ac_decisions: [],
      ac_rows: [{ ac: 'AC1', carried: false, disposition: 'absent', reason_stated: false, locator: '—', proposed: '' }] },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'AC_CHANGE'
      && /"name": "ac-authority:AC1",[\s\S]{0,200}"status": "open"/.test(r.prompts['register-write'] || '') },
  // The record-discipline check reaches the authoring prompts — Draft and every Converge turn.
  { name: 'issue-166-record-discipline-check-in-authoring-prompts', args: { issue: '166' },
    turns: [{ side: 'test', v: [false, true] }, { side: 'dev', v: [false, true] }],
    expect: (r) => r.result.verdict === 'CONVERGED'
      && ['dev-draft', 'test-draft', 'test-t1', 'dev-t2'].every((k) =>
        (r.prompts[k] || '').includes('bash scripts/architect/record-discipline.sh check .autoflow/issue-166-feature-design.md .autoflow/issue-166-verification-design.md')) },
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
