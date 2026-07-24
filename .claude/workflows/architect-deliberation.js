// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// ARCHITECT deliberation — isolated facilitation (issue #153, Decision 8).
// Invoked by the orchestrator: Workflow({ name: "architect-deliberation", args: { issue: "N" } }).
// The Developer-AI and Test-AI sub-agents converge INSIDE this workflow; their
// round-by-round exchange stays in script variables and never enters the
// orchestrator's context. The orchestrator receives only the returned object.
// Requires Claude Code v2.1.154+ (Workflow runtime).
export const meta = {
  name: 'architect-deliberation',
  description: 'Isolated ARCHITECT facilitation: Developer-AI + Test-AI converge on feature + verification design in workflow sub-contexts; returns a single verdict. Invoke with args {issue: "N"} (issue number required).',
  phases: [
    { title: 'Draft', detail: 'dev drafts feature design, test drafts verification design (independent)' },
    { title: 'Converge', detail: 'cross-review rounds under the Discussion Protocol until mutual ACCEPT or the round cap' },
    { title: 'Ledger', detail: 'append the settled decisions (append-only)' },
  ],
}

const MAX_ROUNDS = 6 // Decision 7: explicit cap; a round = one Developer-AI <-> Test-AI exchange cycle.
// Stable escalation-reason literals (DCR-3): declared once, shared verbatim by this script
// and the regression test's `escalation`/ledger-prompt assertions so those are not brittle
// to prose rewording. Ported from verify-cause-branch.js's `missing`-sentinel discipline.
const REASON_DRAFT_AGENT_MISSING = 'draft agent missing'
const REASON_DRAFT_ARTIFACT_MISSING = 'draft artifact missing'
const REASON_SUBAGENT_MISSING = 'sub-agent missing' // full: `${REASON_SUBAGENT_MISSING} for N consecutive round(s)`
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
        // {} -> the loud-fail guard below still fires unchanged.
        const m = args.match(/#(\d+)/) || args.match(/(\d+)/)
        return m ? { issue: m[1] } : {}
      }
    })()
  : (args || {})
// System boundary: reject a missing required arg loudly rather than proceeding with a placeholder path.
if (!argv.issue) throw new Error('architect-deliberation: args.issue is required')
const issue = argv.issue
const feature = `.autoflow/issue-${issue}-feature-design.md`
const verif = `.autoflow/issue-${issue}-verification-design.md`
const ledger = `.autoflow/issue-${issue}-ledger.md`

const VERDICT = {
  type: 'object',
  additionalProperties: false,
  properties: {
    response: { type: 'string', enum: ['ACCEPT', 'COUNTER', 'PARTIAL'] },
    // Open concerns this party still has. ACCEPT REQUIRES this to be empty
    // (Discussion Protocol: a raised concern is never dropped unresolved).
    counters: { type: 'array', items: { type: 'string' } },
    // Grounds for ACCEPT: the dimensions verified + why each passed (Discussion Protocol:
    // ACCEPT must name the dimensions verified). ACCEPT REQUIRES this to be non-empty.
    accept_grounds: { type: 'array', items: { type: 'string' } },
  },
  required: ['response', 'counters', 'accept_grounds'],
}

phase('Draft')
console.log(`ARCHITECT facilitation for issue #${issue} (cap ${MAX_ROUNDS} rounds)`)

// Independent first drafts — the two perspectives do not see each other's draft yet.
const [devDraft, testDraft] = await parallel([
  () => agent(
    `You are the Developer AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md (issue analysis + plan inputs) and any repo code you need. Author the Feature Design Document — files to change, API interface, data structures, dependencies — and WRITE it to ${feature}. Honor docs/teammate-common-rules.md > Discussion Protocol and docs/submodule-common-rules.md > Change Surface Rules. Return a one-line summary only; the document body goes in the file, not the return. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'dev-draft', phase: 'Draft', model: 'opus' },
  ),
  () => agent(
    `You are the Test AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md and the relevant code. Author the Verification Design Document — each acceptance criterion -> verification type (automated / manual / environment-dependent) -> method; testability assessment; design-change requests for untestable items — and WRITE it to ${verif}. Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'test-draft', phase: 'Draft', model: 'opus' },
  ),
])

// A null draft return is a skipped/errored sub-agent — the ARCHITECT analogue of VERIFY's
// `test ? test.verdict : 'missing'`. Record it as a distinct early-ESCALATE reason and skip
// Converge entirely, so the terminal `escalation` string stays truthful about the cause.
let earlyEscalateReason = null
if (!devDraft) earlyEscalateReason = `${REASON_DRAFT_AGENT_MISSING} (dev-draft returned null)`
else if (!testDraft) earlyEscalateReason = `${REASON_DRAFT_AGENT_MISSING} (test-draft returned null)`

// Artifact-existence check (AC2): a draft agent may return non-null yet never write its file.
// Attempt the real on-disk check; if the hosted Workflow runtime forbids `import('node:fs')`,
// degrade to the AC1 null-return check alone rather than crash (settled option (b)). This
// catch branch is the one intentional harness-uncovered branch (harness always runs under Node).
if (!earlyEscalateReason) {
  try {
    const fs = await import('node:fs')
    if (!fs.existsSync(feature)) earlyEscalateReason = `${REASON_DRAFT_ARTIFACT_MISSING} (${feature} not written)`
    else if (!fs.existsSync(verif)) earlyEscalateReason = `${REASON_DRAFT_ARTIFACT_MISSING} (${verif} not written)`
  } catch (_) {
    // fs unavailable in this runtime: AC2's on-disk check degrades to AC1's null-return
    // check (already applied above). No artifact-existence assertion is possible here.
  }
}

phase('Converge')
let round = 0
let converged = false
let openCounters = [] // unresolved concerns carried from the previous round into the next one.
let lastDev = null
let lastTest = null
// A grounded ACCEPT: ACCEPT response + no open counters + named grounds (dimensions verified).
const accepted = (v) => !!(
  v && v.response === 'ACCEPT' &&
  Array.isArray(v.counters) && v.counters.length === 0 &&
  Array.isArray(v.accept_grounds) && v.accept_grounds.length > 0
)
let consecutiveNull = 0
const MAX_CONSECUTIVE_NULL = 2 // two consecutive both-null rounds => persistent infra failure, not a design split
while (!earlyEscalateReason && round < MAX_ROUNDS && !converged) {
  round++
  // Thread last round's open counters into this round so fresh sub-agents must resolve them.
  const carry = openCounters.length
    ? ` Open counters still unresolved from the previous round — you MUST address each before ACCEPT: ${JSON.stringify(openCounters)}.`
    : ''
  const [dev, test] = await parallel([
    () => agent(
      `You are the Developer AI. Round ${round} of ARCHITECT convergence. Read the current ${verif} and ${feature}. Apply the Discussion Protocol (UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND). Round 1 is a mandatory devil's-advocate review: do NOT ACCEPT on round 1. If the verification design exposes a gap in the feature design, UPDATE ${feature} in place. Respond ACCEPT ONLY when both documents are mutually consistent and complete AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${carry} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: VERDICT, label: `dev-r${round}`, phase: 'Converge', model: 'opus' },
    ),
    () => agent(
      `You are the Test AI. Round ${round} of ARCHITECT convergence. Read the current ${feature} and ${verif}. Apply the Discussion Protocol. Round 1 is a mandatory devil's-advocate review: do NOT ACCEPT on round 1. If the feature design changed testability, UPDATE ${verif} in place. Respond ACCEPT ONLY when every acceptance criterion has a concrete verification method (or a stated manual/mock alternative) AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${carry} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: VERDICT, label: `test-r${round}`, phase: 'Converge', model: 'opus' },
    ),
  ])
  lastDev = dev
  lastTest = test
  // A round where BOTH sub-agents are null is a MISSING judgment, not a design disagreement.
  // A single transient both-null round retries; two consecutive is a persistent infra failure —
  // exit early (saving up to MAX_ROUNDS-2 rounds of opus spawns) with a distinct reason rather
  // than laundering it into the generic "No mutual ACCEPT" text. A one-side-null round leaves the
  // live side's counters doing real work, so it is NOT aborted (accepted(null) already blocks it).
  const roundMissing = !dev && !test
  consecutiveNull = roundMissing ? consecutiveNull + 1 : 0
  if (consecutiveNull >= MAX_CONSECUTIVE_NULL) {
    earlyEscalateReason = `${REASON_SUBAGENT_MISSING} for ${consecutiveNull} consecutive round(s)`
    break
  }
  // No agreement on the first exchange (round > 1), and both sides must give a grounded ACCEPT
  // with no open counters (a raised concern is never dropped).
  converged = round > 1 && accepted(dev) && accepted(test)
  openCounters = [...((dev && dev.counters) || []), ...((test && test.counters) || [])]
  console.log(`round ${round}: dev=${dev ? dev.response : 'missing'}(${(dev && dev.counters && dev.counters.length) || 0}) test=${test ? test.response : 'missing'}(${(test && test.counters && test.counters.length) || 0})`)
}

phase('Ledger')
const verdict = converged ? 'CONVERGED' : 'ESCALATE'
// Cause-specific escalation reason: an early-exit reason (missing draft / artifact / consecutive
// null) survives verbatim; otherwise the generic round-exhaustion text.
const escalationReason = earlyEscalateReason
  || `No mutual ACCEPT within ${MAX_ROUNDS} rounds (reached round ${round})`
// Only a CONVERGED run records settled decisions under "ARCHITECT mutual ACCEPT".
// A non-convergence run records a single outcome entry under a DISTINCT authority so
// the append-only ledger is never polluted with un-agreed content (which would later
// block legitimate re-deliberation under the "no re-litigation" rule).
const acceptGrounds = converged
  ? [...((lastDev && lastDev.accept_grounds) || []), ...((lastTest && lastTest.accept_grounds) || [])]
  : []
const ledgerPrompt = converged
  ? `Append (do NOT rewrite or delete) to ${ledger} the settled ARCHITECT decisions. For each agreed design decision, append one entry: the decision (one line); its grounds (cite the verified dimensions ${JSON.stringify(acceptGrounds)} and the artifact path:line in ${feature} or ${verif}); authority "ARCHITECT mutual ACCEPT"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only — never edit existing entries. Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
  : `Append (do NOT rewrite or delete) to ${ledger} EXACTLY ONE outcome entry — do NOT record any design decision as settled: decision "ARCHITECT did not converge — ${escalationReason}"; grounds (unresolved counters: ${JSON.stringify(openCounters)}); authority "ARCHITECT non-convergence"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only. Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
await agent(ledgerPrompt, { label: 'ledger', phase: 'Ledger', model: 'opus' })

return {
  phase: 'architect',
  verdict,
  artifacts: [feature, verif],
  ledger,
  rounds: round,
  summary: converged
    ? `ARCHITECT converged in ${round} round(s)`
    : `ARCHITECT did not converge — escalate (${escalationReason})`,
  escalation: converged ? null : escalationReason,
}
