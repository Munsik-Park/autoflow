// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// =============================================================================
// architect-turn-harness.mjs — issue #166 relay/report simulation harness
// =============================================================================
// Executes .claude/workflows/architect-deliberation.js OUTSIDE the Workflow
// runtime by wrapping the script body in an async function and stubbing the
// runtime-injected hooks (agent/parallel/phase/log/console). The `agent` stub
// dispatches on each call's declared label: the policy-load call is answered
// with the REAL .claude/autoflow/spawn-policy.json (so the workflow's own
// fail-closed policy validation runs against the shipped config), each Discuss
// turn is answered from the scenario's scripted turn list, and the Report /
// Record calls from the scenario's scripted reports.
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

// eslint-disable-next-line no-new-func
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const wf = new AsyncFunction('args', 'agent', 'parallel', 'phase', 'log', 'console', scriptSrc)

// One scripted turn: `[message, done]`, or `null` for a missing (errored /
// skipped) sub-agent turn — the stub throws on it, which the script's own
// `.catch(() => null)` turns into the MISSING turn its loop records.
const turnOf = (t) => ({ message: t[0], done: t[1] })
const REPORT_OK = { agreed: ['a1'], unagreed: [] }
const REPORT_EMPTY = { agreed: [], unagreed: [] }

async function run(scenario) {
  const calls = []
  const prompts = {}
  const turns = [...(scenario.turns || [])]
  const agent = async (prompt, opts) => {
    const label = (opts && opts.label) || ''
    calls.push(label)
    prompts[label] = prompt
    if (label === 'policy-load') return { found: true, content: scenario.policyContent || policyContent }
    if (label === 'dev-report') return 'devReport' in scenario ? scenario.devReport : REPORT_OK
    if (label === 'test-report') return 'testReport' in scenario ? scenario.testReport : REPORT_OK
    if (label === 'scribe') return 'scribe' in scenario ? scenario.scribe : REPORT_OK
    if (label === 'ledger') return 'ok'
    const m = label.match(/^(dev|test)-t(\d+)$/)
    if (m) {
      if (!turns.length) throw new Error(`scenario ran out of scripted turns at ${label}`)
      const scripted = turns.shift()
      if (scripted.side && scripted.side !== m[1]) throw new Error(`side mismatch at ${label}: scripted ${scripted.side}`)
      if (scripted.v === null) throw new Error('scripted missing turn') // absorbed by the script's .catch
      return turnOf(scripted.v)
    }
    throw new Error(`unexpected agent label: ${label}`)
  }
  const parallel = (thunks) => Promise.all(thunks.map((f) => Promise.resolve().then(f).catch(() => null)))
  const result = await wf(scenario.args, agent, parallel, () => {}, () => {}, { log: () => {} })
  return { result, calls, prompts, leftover: turns.length }
}

// A short alternating run that ends on the first consecutive done pair.
const DONE_PAIR = [{ side: 'dev', v: ['open', true] }, { side: 'test', v: ['agree', true] }]

const scenarios = [
  // (a) The relay: the Developer AI opens, the Test AI answers, sides alternate,
  // and every turn prompt carries the SAME Topic plus the transcript so far.
  {
    name: 'relay-alternation-topic-and-growing-transcript',
    args: { issue: '166' },
    turns: [
      { side: 'dev', v: ['dev opens with a proposal', false] },
      { side: 'test', v: ['test answers on verification', false] },
      { side: 'dev', v: ['dev responds', true] },
      { side: 'test', v: ['test agrees', true] },
    ],
    expect: (r) => {
      const labels = r.calls.filter((c) => /^(dev|test)-t\d+$/.test(c))
      if (labels.join(',') !== 'dev-t1,test-t2,dev-t3,test-t4') return `turn labels: ${labels.join(',')}`
      const topics = labels.map((l) => (r.prompts[l].split('## Topic\n')[1] || '').split('\n\n## Transcript')[0])
      if (new Set(topics).size !== 1) return 'the Topic string differs between turns'
      if (!/Issue #166\./.test(topics[0])) return 'the Topic does not name the issue'
      const tr = (l) => r.prompts[l].split('## Transcript\n')[1]
      if (!/no turns yet/.test(tr('dev-t1'))) return 'turn 1 transcript is not the empty marker'
      if (!/### Turn 1 — Developer AI\ndev opens with a proposal/.test(tr('test-t2'))) return 'turn 2 does not carry turn 1'
      if (!/### Turn 1 — Developer AI/.test(tr('dev-t3')) || !/### Turn 2 — Test AI\ntest answers on verification/.test(tr('dev-t3'))) return 'turn 3 does not carry both prior turns'
      for (const l of ['dev-t1', 'test-t2', 'dev-t3', 'test-t4']) {
        if (!/do not edit any file/.test(r.prompts[l])) return `${l} does not carry the no-editing rule`
      }
      return r.result.turns === 4 && r.result.stopped === null ? true : `turns=${r.result.turns} stopped=${r.result.stopped}`
    },
  },
  // (b) Termination: only two CONSECUTIVE done turns end the discussion.
  {
    name: 'termination-done-pair-ends',
    args: { issue: '166' },
    turns: DONE_PAIR,
    expect: (r) => r.result.turns === 2 && r.result.stopped === null ? true : `turns=${r.result.turns}`,
  },
  {
    name: 'termination-done-notdone-done-continues',
    args: { issue: '166' },
    turns: [
      { side: 'dev', v: ['done for now', true] },
      { side: 'test', v: ['one more point', false] },
      { side: 'dev', v: ['answered', true] },
      { side: 'test', v: ['nothing further', true] },
    ],
    expect: (r) => r.result.turns === 4 ? true : `turns=${r.result.turns} (a done/not-done/done sequence must not terminate early)`,
  },
  {
    name: 'termination-first-turn-cannot-end-alone',
    args: { issue: '166' },
    turns: [
      { side: 'dev', v: ['nothing to add', true] },
      { side: 'test', v: ['I do have a point', false] },
      { side: 'dev', v: ['answered', true] },
      { side: 'test', v: ['settled', true] },
    ],
    expect: (r) => r.result.turns === 4 ? true : `turns=${r.result.turns}`,
  },
  // (c) A missing turn is recorded and the discussion continues; two in a row stop it.
  {
    name: 'single-missing-turn-recorded-and-continues',
    args: { issue: '166' },
    turns: [
      { side: 'dev', v: null },
      { side: 'test', v: ['answering an absent proposal', false] },
      { side: 'dev', v: ['proposal', true] },
      { side: 'test', v: ['agreed', true] },
    ],
    expect: (r) => {
      if (r.result.stopped !== null) return `stopped=${r.result.stopped}`
      if (r.result.turns !== 4) return `turns=${r.result.turns}`
      const tr = r.prompts['test-t2'].split('## Transcript\n')[1]
      if (!/### Turn 1 — Developer AI\n\(no response — this turn is missing\)/.test(tr)) return 'the missing turn is not recorded in the transcript'
      return true
    },
  },
  {
    name: 'two-consecutive-missing-turns-stop-the-run',
    args: { issue: '166' },
    turns: [{ side: 'dev', v: null }, { side: 'test', v: null }],
    expect: (r) => {
      if (r.result.stopped !== 'participant missing for 2 consecutive turn(s)') return `stopped=${JSON.stringify(r.result.stopped)}`
      if (r.result.report !== null) return `report=${JSON.stringify(r.result.report)}`
      if (r.calls.some((c) => ['dev-report', 'test-report', 'scribe', 'ledger'].includes(c))) return `calls after the stop: ${r.calls.join(',')}`
      if (!/stopped — participant missing/.test(r.result.summary)) return `summary=${r.result.summary}`
      return true
    },
  },
  // (d) Report: both participants report on the same transcript.
  {
    name: 'report-both-sides-called-with-the-transcript',
    args: { issue: '166' },
    turns: DONE_PAIR,
    expect: (r) => {
      for (const l of ['dev-report', 'test-report']) {
        if (!r.prompts[l]) return `${l} was not called`
        if (!/## Transcript\n### Turn 1 — Developer AI\nopen/.test(r.prompts[l])) return `${l} does not carry the transcript`
        if (!/## Topic\nIssue #166\./.test(r.prompts[l])) return `${l} does not carry the topic`
      }
      return true
    },
  },
  {
    name: 'report-both-null-stops-the-run',
    args: { issue: '166' },
    turns: DONE_PAIR,
    devReport: null,
    testReport: null,
    expect: (r) => {
      if (r.result.stopped !== 'report missing') return `stopped=${JSON.stringify(r.result.stopped)}`
      if (r.result.report !== null) return `report=${JSON.stringify(r.result.report)}`
      if (r.calls.includes('scribe') || r.calls.includes('ledger')) return `calls after the stop: ${r.calls.join(',')}`
      return true
    },
  },
  {
    name: 'report-one-null-continues-and-the-scribe-is-told',
    args: { issue: '166' },
    turns: DONE_PAIR,
    testReport: null,
    expect: (r) => {
      if (r.result.stopped !== null) return `stopped=${JSON.stringify(r.result.stopped)}`
      if (!r.calls.includes('scribe')) return 'the scribe was not called'
      const p = r.prompts['scribe']
      if (!/### Test AI\n\(report missing/.test(p)) return 'the scribe prompt does not state that the Test AI report is missing'
      if (!/### Developer AI\nagreed:/.test(p)) return 'the scribe prompt does not carry the present report'
      return true
    },
  },
  // (e) Record: the scribe's return is the run's report.
  {
    name: 'scribe-null-stops-the-run',
    args: { issue: '166' },
    turns: DONE_PAIR,
    scribe: null,
    expect: (r) => {
      if (r.result.stopped !== 'scribe missing') return `stopped=${JSON.stringify(r.result.stopped)}`
      if (r.result.report !== null) return `report=${JSON.stringify(r.result.report)}`
      if (r.calls.includes('ledger')) return 'the ledger ran after a missing scribe'
      return true
    },
  },
  // (f) The ledger records the agreed conclusions, and nothing else.
  {
    name: 'ledger-called-once-for-agreed-conclusions',
    args: { issue: '166' },
    turns: DONE_PAIR,
    scribe: { agreed: ['c1', 'c2'], unagreed: [{ point: 'p', developer_position: 'd', test_position: 't', why_raised: 'w' }] },
    expect: (r) => {
      const n = r.calls.filter((c) => c === 'ledger').length
      if (n !== 1) return `ledger called ${n} time(s)`
      const p = r.prompts['ledger']
      if (!/authority "ARCHITECT agreed"/.test(p)) return 'the ledger prompt does not name the ARCHITECT agreed authority'
      if (!/ledger-entry-id\.sh next .*-ledger\.md F\b/.test(p)) return 'the ledger prompt does not instruct the next allocation'
      if (!/ledger-entry-id\.sh check/.test(p)) return 'the ledger prompt does not instruct the check'
      if (!/- c1\n- c2/.test(p)) return 'the ledger prompt does not carry the agreed conclusions'
      if (/p\b.*why raised/.test(p)) return 'the ledger prompt carries an un-agreed point'
      if (r.result.summary !== 'ARCHITECT deliberation ended after 2 turn(s): 2 agreed conclusion(s), 1 un-agreed point(s)') return `summary=${r.result.summary}`
      return true
    },
  },
  {
    name: 'ledger-not-called-when-nothing-was-agreed',
    args: { issue: '166' },
    turns: DONE_PAIR,
    scribe: REPORT_EMPTY,
    expect: (r) => {
      if (r.calls.includes('ledger')) return 'the ledger ran with an empty agreed list'
      if (r.result.stopped !== null) return `stopped=${JSON.stringify(r.result.stopped)}`
      return true
    },
  },
  // (g) The orchestrator's brief.
  {
    name: 'brief-appears-in-every-turn-topic',
    args: { issue: '166', brief: 'discuss only the un-agreed oracle question' },
    turns: [
      { side: 'dev', v: ['m1', false] },
      { side: 'test', v: ['m2', true] },
      { side: 'dev', v: ['m3', true] },
    ],
    expect: (r) => {
      for (const l of ['dev-t1', 'test-t2', 'dev-t3', 'dev-report', 'test-report', 'scribe']) {
        if (!/From the orchestrator: discuss only the un-agreed oracle question/.test(r.prompts[l] || '')) return `${l} does not carry the brief`
      }
      return true
    },
  },
  {
    name: 'brief-absent-adds-no-line',
    args: { issue: '166' },
    turns: DONE_PAIR,
    expect: (r) => Object.values(r.prompts).every((p) => !/From the orchestrator:/.test(p))
      ? true : 'a From-the-orchestrator line appeared without a brief',
  },
  {
    name: 'brief-non-string-throws-at-the-boundary',
    args: { issue: '166', brief: 42 },
    turns: [],
    throws: /args\.brief must be a string or absent/,
  },
  // (h) Policy fail-closed: a missing required row stops before any other call.
  ...['dev-turn', 'test-turn', 'scribe', 'ledger'].map((key) => ({
    name: `policy-row-missing-${key}-fails-closed`,
    args: { issue: '166' },
    policyContent: JSON.stringify((() => {
      const p = JSON.parse(policyContent)
      delete p.workflow_sites['architect-deliberation'][key]
      return p
    })()),
    turns: [],
    expect: (r) => {
      if (!String(r.result.stopped).startsWith('spawn policy row incomplete')) return `stopped=${JSON.stringify(r.result.stopped)}`
      if (!String(r.result.stopped).includes(key)) return `the cause does not name "${key}": ${r.result.stopped}`
      if (r.calls.join(',') !== 'policy-load') return `calls=${r.calls.join(',')}`
      if (r.result.report !== null) return `report=${JSON.stringify(r.result.report)}`
      return true
    },
  })),
  // (i) The return contract.
  {
    name: 'return-shape-is-exactly-the-declared-keys',
    args: { issue: '166' },
    turns: DONE_PAIR,
    expect: (r) => {
      const keys = Object.keys(r.result).sort().join(',')
      if (keys !== 'artifacts,ledger,phase,report,stopped,summary,turns') return `keys=${keys}`
      if (r.result.phase !== 'architect') return `phase=${r.result.phase}`
      if (r.result.ledger !== '.autoflow/issue-166-ledger.md') return `ledger=${r.result.ledger}`
      const want = [
        '.autoflow/issue-166-feature-design.md',
        '.autoflow/issue-166-verification-design.md',
        '.autoflow/issue-166-architect-report.md',
      ]
      if (JSON.stringify(r.result.artifacts) !== JSON.stringify(want)) return `artifacts=${JSON.stringify(r.result.artifacts)}`
      if ('verdict' in r.result) return 'a verdict key survives in the return'
      return true
    },
  },
]

let failed = 0
for (const s of scenarios) {
  try {
    const r = await run(s)
    if (s.throws) { failed++; console.log(`${s.name} FAIL: expected a throw matching ${s.throws}`); continue }
    const verdict = s.expect(r)
    if (verdict === true && r.leftover === 0) console.log(`${s.name} PASS`)
    else { failed++; console.log(`${s.name} FAIL: ${verdict === true ? `leftover=${r.leftover}` : verdict}`) }
  } catch (e) {
    if (s.throws && s.throws.test(e.message)) console.log(`${s.name} PASS`)
    else { failed++; console.log(`${s.name} FAIL: ${e.message}`) }
  }
}
process.exit(failed ? 1 : 0)
