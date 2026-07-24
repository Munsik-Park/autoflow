// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// VERIFY cause-branch — isolated facilitation (issue #153, Decision 8).
// Invoked by the orchestrator: Workflow({ name: "verify-cause-branch", args: { issue: "N", failLog: "<path>" } }).
// The Test-AI and Developer-AI self-checks run INSIDE this workflow; only the
// canonical next action crosses back to the orchestrator. The orchestrator routes
// strictly on `next_action`. Requires Claude Code v2.1.154+ (Workflow runtime).
//
// Termination (Decision 7): a single self-check round — each side answers once and
// the next action is derived deterministically. There is no internal loop. Repeated
// VERIFY entries are bounded by the GREEN<->VERIFY round-trip cap (max 3) the
// orchestrator enforces in CLAUDE.md > Flow Control.
export const meta = {
  name: 'verify-cause-branch',
  description: 'Isolated VERIFY cause-branch: Test-AI + Developer-AI self-check on a test failure; returns only the canonical next action. Invoke with args {issue: "N", failLog: "<path>"} (both required).',
  phases: [
    { title: 'Self-check', detail: 'test-AI and dev-AI each self-check against the acceptance criterion (one round)' },
  ],
}

// The Claude Code Workflow runtime delivers the `args` input to the script as a
// JSON STRING, not the parsed object the tool doc implies (verified empirically
// via the args-probe diagnostic: a `{issue}` object arrives as typeof === 'string').
// Normalize defensively: parse a string, accept an object if a future runtime
// passes one — forward-compatible either way.
const argv = typeof args === 'string'
  ? (() => {
      try { return JSON.parse(args) }
      catch (_) {
        // Prose fallback (issue #14): the skill channel forwards the operator's free
        // text verbatim as `args`. Free text is not JSON, so parsing threw. Salvage the
        // issue number, preferring a hashed token (#215) over a bare digit run so an
        // incidental leading digit (the "2" in "v2") is not adopted. No digit match ->
        // {} -> the loud-fail guard below still fires unchanged. `failLog` deliberately
        // gets NO salvage (DCR-3 asymmetry: a filesystem path has no reliable prose
        // shape); its guard stays a hard requirement.
        const m = args.match(/#(\d+)/) || args.match(/(\d+)/)
        return m ? { issue: m[1] } : {}
      }
    })()
  : (args || {})
// System boundary: reject missing required args loudly rather than proceeding with placeholders.
if (!argv.issue) throw new Error('verify-cause-branch: args.issue is required')
if (!argv.failLog) throw new Error('verify-cause-branch: args.failLog is required')
const issue = argv.issue
const failLog = argv.failLog
const ledger = `.autoflow/issue-${issue}-ledger.md`

const TEST_CHECK = {
  type: 'object',
  additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['fix_test', 'no_problem'] },
    reason: { type: 'string' },
  },
  required: ['verdict', 'reason'],
}
const IMPL_CHECK = {
  type: 'object',
  additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['fix_impl', 'no_problem'] },
    reason: { type: 'string' },
  },
  required: ['verdict', 'reason'],
}

phase('Self-check')
console.log(`VERIFY cause-branch for issue #${issue}`)

const [test, impl] = await parallel([
  () => agent(
    `You are the Test AI. A test is failing in AutoFlow VERIFY. Read the failure log at ${failLog}, the test code, and the acceptance criteria in .autoflow/issue-${issue}-*.md. Single self-check (one round, no discussion with the Developer AI): does my test accurately reflect the acceptance criterion? Answer "fix_test" if the test is wrong, "no_problem" if the test is correct. Return your verdict + a one-line reason. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { schema: TEST_CHECK, label: 'test-self-check', phase: 'Self-check', model: 'opus' },
  ),
  () => agent(
    `You are the Developer AI. A test is failing in AutoFlow VERIFY. Read the failure log at ${failLog}, the implementation, and the acceptance criteria in .autoflow/issue-${issue}-*.md. Single self-check (one round, no discussion with the Test AI): does my implementation meet the acceptance criterion? Answer "fix_impl" if the implementation is wrong, "no_problem" if the implementation is correct. Return your verdict + a one-line reason. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { schema: IMPL_CHECK, label: 'impl-self-check', phase: 'Self-check', model: 'opus' },
  ),
])

// A null sub-agent is a MISSING/errored judgment, not a verdict — record it truthfully as
// "missing" (never substitute "no_problem", which would write a self-check that never happened
// into the append-only ledger as authoritative fact).
const t = test ? test.verdict : 'missing'
const i = impl ? impl.verdict : 'missing'

let next
if (t === 'missing' || i === 'missing') next = 'EVALUATION_AI' // missing judgment -> conservative arbitration
else if (t === 'fix_test' && i === 'no_problem') next = 'RED' // fix test -> re-Red -> re-enter GREEN
else if (t === 'no_problem' && i === 'fix_impl') next = 'GREEN' // fix impl -> re-run VERIFY
else if (t === 'fix_test' && i === 'fix_impl') next = 'SEQUENTIAL_FIX' // fix test first -> Red -> fix impl -> Green
else next = 'EVALUATION_AI' // both "no_problem" -> deadlock: Evaluation AI arbitrates

await agent(
  `Append (do NOT rewrite or delete) to ${ledger} one VERIFY cause-branch entry: decision "next_action=${next}"; grounds (test self-check=${t}, impl self-check=${i}; failure log ${failLog}); authority "VERIFY self-check"; cycle/phase "VERIFY". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only. Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
  { label: 'ledger', phase: 'Self-check', model: 'opus' },
)

return {
  phase: 'verify',
  test_self_check: t,
  impl_self_check: i,
  next_action: next,
  ledger,
  summary: `VERIFY: test=${t}, impl=${i} -> ${next}`,
}
