// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// ARCHITECT deliberation — isolated facilitation (Decision 8), in its original form (issue #166).
// Invoked by the orchestrator: Workflow({ name: "architect-deliberation", args: { issue: "N" } }).
// The Developer AI and the Test AI discuss the issue's design in relayed turns INSIDE this
// workflow: each turn receives one fixed prompt plus the transcript so far, and the transcript is
// the participants' memory. Nobody edits a design document while the discussion runs. When both
// participants have said they have nothing further to add, each reports what was agreed and what
// was not, and a scribe writes the two design documents and the report from those conclusions.
// The orchestrator receives only the returned object. Requires Claude Code v2.1.154+ (Workflow runtime).
export const meta = {
  name: 'architect-deliberation',
  description: 'Isolated ARCHITECT deliberation: the Developer AI and the Test AI discuss the issue\'s design in relayed turns inside workflow sub-contexts, report what they agreed and what they did not, and a scribe writes the two design documents from the report. Invoke with args {issue: "N"} (issue number required); {issue: "N", brief: "<text>"} adds the orchestrator\'s preparation for a re-discussion (a narrowed topic, confirmed facts, the prior report path).',
  phases: [
    { title: 'Discuss', detail: 'Developer AI and Test AI alternate turns on the topic; the transcript is the shared memory; ends when both say they have nothing further to add' },
    { title: 'Report', detail: 'each participant reports the agreed conclusions and the points worth raising as un-agreed' },
    { title: 'Record', detail: 'the scribe writes the feature design, the verification design and the report; the ledger records the agreed conclusions' },
  ],
}

// Stable stop-reason literals: declared once, shared verbatim by this script and the regression
// tests, so an assertion pins a cause by equality rather than by prose. `stopped` is the run's
// infrastructure state — it says the deliberation could not be carried out, never what the
// participants concluded; a completed deliberation returns `stopped: null` whatever its report says.
const REASON_PARTICIPANT_MISSING = 'participant missing' // full: `${REASON_PARTICIPANT_MISSING} for N consecutive turn(s)`
const REASON_REPORT_MISSING = 'report missing'
const REASON_SCRIBE_MISSING = 'scribe missing'
// Spawn-policy load sentinels (issue #150). The per-site model/effort policy is loaded through a
// transcription channel (there is no filesystem here), and a run must never proceed on an unknown
// policy: degrading to session-inherited models is precisely the bypass the single-source policy
// exists to close. Each cause is distinct so the operator sees which half failed.
const REASON_POLICY_LOAD_AGENT_MISSING = 'spawn policy load agent missing'
const REASON_POLICY_ABSENT = 'spawn policy absent'
const REASON_POLICY_MALFORMED = 'spawn policy malformed'
const REASON_POLICY_ROW_INCOMPLETE = 'spawn policy row incomplete'
const REASON_POLICY_EFFORT_CONTRACT_UNUSABLE = 'spawn policy effort contract unusable'

// The Claude Code Workflow runtime delivers the `args` input to the script as a JSON STRING, not
// the parsed object the tool doc implies (verified empirically via the args-probe diagnostic).
// Normalize defensively: parse a string, accept an object if a future runtime passes one.
const argv = typeof args === 'string'
  ? (() => {
      try { return JSON.parse(args) }
      catch (_) {
        // Prose fallback (issue #14): the skill channel forwards the operator's free text verbatim
        // as `args`. Free text is not JSON, so parsing threw. Salvage the issue number by
        // decreasing anchor strength (first hit wins):
        //   tier 1  #(\d+)               — a hashed token (#215) is an explicit issue ref
        //   tier 2  \bissue\s+#?(\d+)\b  — the word "issue" anchors the number, so an
        //                                  incidental leading digit (the "2" in "v2") loses
        //   tier 3  bare (\d+)           — adopted ONLY when exactly one number is present;
        //                                  two-or-more bare runs is ambiguous -> fail loud.
        // No match / ambiguous -> {} -> the loud-fail guard below fires unchanged.
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
// System boundary: reject a missing or malformed arg loudly rather than proceeding on a placeholder.
// `brief` is the orchestrator's preparation for a re-discussion and is accepted only as a string
// from a JSON / object argument — never salvaged from prose. Single throw site.
const briefMalformed = argv.brief != null && typeof argv.brief !== 'string'
if (!argv.issue || briefMalformed) {
  throw new Error(!argv.issue
    ? 'architect-deliberation: args.issue is required'
    : `architect-deliberation: args.brief must be a string or absent (got ${JSON.stringify(argv.brief)})`)
}
const issue = argv.issue
const brief = typeof argv.brief === 'string' ? argv.brief.trim() : ''
const feature = `.autoflow/issue-${issue}-feature-design.md`
const verif = `.autoflow/issue-${issue}-verification-design.md`
const reportPath = `.autoflow/issue-${issue}-architect-report.md`
const ledger = `.autoflow/issue-${issue}-ledger.md`

// ---- Spawn policy load (issue #150) ------------------------------------------------------------
// Every governed call site reads its model (and effort) from .claude/autoflow/spawn-policy.json
// through `site()`. The policy arrives through a transcription sub-agent because this script has
// no filesystem. That bootstrap call is the one call with no `site()` spread — it cannot read its
// own model from the policy it is loading, and a verbatim file transcription under a closed schema
// is not model-tier load-bearing (CLAUDE.md > Spawn Model, the single carve-out).
const POLICY_PATH = '.claude/autoflow/spawn-policy.json'
const WORKFLOW_NAME = 'architect-deliberation'
const POLICY_FILE = {
  type: 'object',
  additionalProperties: false,
  properties: {
    found: { type: 'boolean' },
    content: { type: 'string' },
  },
  required: ['found', 'content'],
}
const FOREGROUND_RULE = ' Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).'
const policyLoaded = await Promise.resolve()
  .then(() => agent(
    `You are a transcription channel, not a reviewer. Read ${POLICY_PATH} and return its raw contents verbatim in "content" -- do not summarize, reword, add, drop or re-order anything, and do not re-serialize or pretty-print the JSON. Set "found" true only when the file exists AND is non-empty; when it does not, set "found" false and "content" to the empty string. Exercise no judgment about the policy itself.${FOREGROUND_RULE}`,
    { schema: POLICY_FILE, label: 'policy-load', phase: 'Discuss' },
  ))
  .catch(() => null)
let policy = null
if (policyLoaded && policyLoaded.found) {
  try { policy = JSON.parse(policyLoaded.content) } catch (_) { policy = null }
}
// The site keys this script spreads, declared once, in a fixed grep-parsable shape: one BARE quoted
// key per line between the two markers, never written in the site-call syntax -- the contract CI
// extracts call-site keys by grepping that syntax over the file OUTSIDE this range. The three-way
// equality (declaration = call sites = config rows) lives in
// tests/test-spawn-policy-single-source.sh > required-key-declaration-join.
const REQUIRED_SITE_KEYS = [
  /* site-keys:begin */
  'dev-turn',
  'test-turn',
  'scribe',
  'ledger',
  /* site-keys:end */
]
// Universally quantified over the DECLARED list, never over the loaded table's own keys. `effort`
// must be PRESENT — the config's own `effort_contract.absent_means` states that a row carrying no
// `effort` key is a validation error rather than an inherit. The contract clause is checked first:
// `site()` reads `effort_contract.config_inherit_sentinel`, so an unusable contract would ship
// every row's `inherit` to the harness as a literal effort value. Value ADMISSION is deliberately
// absent: that is `spawn-policy.sh check`'s job.
const policyRowDefect = (p) => {
  const c = p.effort_contract
  if (!c || typeof c !== 'object' || Array.isArray(c)
      || typeof c.config_inherit_sentinel !== 'string' || !c.config_inherit_sentinel) {
    return `${REASON_POLICY_EFFORT_CONTRACT_UNUSABLE} (effort_contract.config_inherit_sentinel)`
  }
  const table = p.workflow_sites[WORKFLOW_NAME]
  const bad = REQUIRED_SITE_KEYS.filter((key) => {
    const row = table[key]
    return !row || typeof row !== 'object' || typeof row.model !== 'string' || !row.model
      || !Object.prototype.hasOwnProperty.call(row, 'effort')
  })
  if (bad.length) return `${REASON_POLICY_ROW_INCOMPLETE} (${bad.join(', ')})`
  return null
}
let stopped = null
if (!policy || !policy.workflow_sites || !policy.workflow_sites[WORKFLOW_NAME]) {
  stopped = !policyLoaded
    ? REASON_POLICY_LOAD_AGENT_MISSING
    : !policyLoaded.found
    ? REASON_POLICY_ABSENT
    : REASON_POLICY_MALFORMED
} else {
  stopped = policyRowDefect(policy)
}
// The site opts helper. [MUST] The key is a STRING LITERAL at every call site -- never a variable,
// a template string or any computed expression: contract CI is pure bash + jq with no node, so the
// join between call sites and config rows has no run-time oracle, and a literal key is what keeps
// that join decidable by static set comparison (tests/test-spawn-policy-single-source.sh).
// An INHERITING row yields an opts object with no `effort` key at all, which is exactly how the
// runtime is documented to inherit -- the config sentinel is this policy's own vocabulary and is
// never written to a harness channel. Every other value the row carries is a concrete effort and
// reaches the opts unchanged, including an admitted falsy one such as the integer zero.
const site = (key) => {
  const row = policy.workflow_sites[WORKFLOW_NAME][key]
  if (!row || !row.model) throw new Error(`${WORKFLOW_NAME}: no spawn-policy row for workflow site "${key}"`)
  const inheritSentinel = policy.effort_contract.config_inherit_sentinel
  return row.effort !== inheritSentinel
    ? { model: row.model, effort: row.effort }
    : { model: row.model }
}

// ---- The topic, stated once ---------------------------------------------------------------------
// The topic is the only per-run text; it is the same string on every turn. The decision ledger's
// settled entries are part of the topic input so a settled decision is read, not re-argued
// (CLAUDE.md > Decision Ledger). The orchestrator's `brief`, when given, is its preparation for a
// re-discussion — a narrowed topic, confirmed facts, the prior report path — and is carried
// verbatim as part of the topic.
const TOPIC = `Issue #${issue}. Inputs: .autoflow/issue-${issue}-phase-a.md (code structure), .autoflow/issue-${issue}-phase-b.md (issue analysis and the acceptance-criteria table), any other .autoflow/issue-${issue}-*.md, and the decision ledger ${ledger} if it exists — an entry there under authority "ARCHITECT agreed", "ARCHITECT mutual ACCEPT", "ARCHITECT rejected" or "operator decision" is settled and is reopened only on a fact verified now that was unavailable when it was written. Question: what is the feature design for this issue — files to change, API interface, data structures, dependencies — and how is each acceptance criterion verified?${brief ? `\n\nFrom the orchestrator: ${brief}` : ''}`

// ---- Fixed prompts --------------------------------------------------------------------------------
// One prompt per role, fixed for the run: the role by reference to its contract, the discussion
// rules by reference to the Discussion Protocol, the topic, the transcript. No clause is assembled
// per turn.
const TURN = {
  type: 'object',
  additionalProperties: false,
  properties: {
    message: { type: 'string' },
    done: { type: 'boolean' },
  },
  required: ['message', 'done'],
}
const REPORT = {
  type: 'object',
  additionalProperties: false,
  properties: {
    agreed: { type: 'array', items: { type: 'string' } },
    unagreed: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          point: { type: 'string' },
          developer_position: { type: 'string' },
          test_position: { type: 'string' },
          why_raised: { type: 'string' },
        },
        required: ['point', 'developer_position', 'test_position', 'why_raised'],
      },
    },
  },
  required: ['agreed', 'unagreed'],
}
const TURN_RULE = ' The topic is stated once below and the transcript is the whole record of the discussion so far — the other participant\'s last message is what you are answering. Read whatever repository files and .autoflow/issue-*.md inputs you need to ground your position, and do not edit any file: the design documents are written after the discussion, from its conclusions. Return your message for this turn as "message". Set "done" true when you have nothing further to raise on this topic; the discussion ends when both participants say so in succession.'
const DEV_TURN_PROMPT = `You are the Developer AI in an AutoFlow ARCHITECT deliberation — role contract docs/teammate-contracts.md > Submodule AI, discussion rules docs/teammate-common-rules.md > Discussion Protocol. You propose and defend the feature design: files to change, API interface, data structures, dependencies, under docs/submodule-common-rules.md > Change Surface Rules.${TURN_RULE}${FOREGROUND_RULE}`
const TEST_TURN_PROMPT = `You are the Test AI in an AutoFlow ARCHITECT deliberation — role contract docs/teammate-contracts.md > Test AI, discussion rules docs/teammate-common-rules.md > Discussion Protocol. You examine the feature design from the verification side: how each acceptance criterion is verified, under the dispositions and the test-necessity, verification-depth and composition-oracle determinations at docs/autoflow-guide.md > ARCHITECT > Output artifacts, and what in the design would have to change to make a criterion verifiable.${TURN_RULE}${FOREGROUND_RULE}`
const REPORT_RULE = ' The discussion below has ended. Report it: in "agreed", each design conclusion both participants accepted, one line each; in "unagreed", each point you consider worth raising to the orchestrator — the point, the Developer AI\'s position, the Test AI\'s position, and why it is worth raising. Leave out a point you judge not worth raising.'
const DEV_REPORT_PROMPT = `You are the Developer AI of the AutoFlow ARCHITECT deliberation transcribed below.${REPORT_RULE}${FOREGROUND_RULE}`
const TEST_REPORT_PROMPT = `You are the Test AI of the AutoFlow ARCHITECT deliberation transcribed below.${REPORT_RULE}${FOREGROUND_RULE}`

const renderTranscript = (entries) => entries.length
  ? entries.map((e) => `### Turn ${e.turn} — ${e.side === 'dev' ? 'Developer AI' : 'Test AI'}\n${e.message}`).join('\n\n')
  : '(no turns yet — open the discussion)'
const withTopic = (fixed, entries) => `${fixed}\n\n## Topic\n${TOPIC}\n\n## Transcript\n${renderTranscript(entries)}`

// ---- Discuss: the relay ----------------------------------------------------------------------------
// The Developer AI opens with a proposal and the Test AI answers it; the two alternate. A turn's
// output is the next turn's input through the transcript. The discussion ends when two consecutive
// turns — one per participant — both report `done: true`: the participants' conclusion ends it.
// A null turn (skipped or errored sub-agent) is a MISSING turn, recorded as such in the
// transcript; two consecutive missing turns (one per side) is a persistent infrastructure failure
// and stops the run with its own cause rather than being read as a design outcome.
const transcript = []
let turn = 0
let consecutiveNull = 0
const MAX_CONSECUTIVE_NULL = 2
let prevDone = false
let report = null
let scribeReport = null

if (!stopped) {
  phase('Discuss')
  console.log(`ARCHITECT deliberation for issue #${issue}`)
  while (true) {
    turn++
    const side = turn % 2 === 1 ? 'dev' : 'test'
    // Two call sites, one per side, so each carries its site key as a STRING LITERAL (the [MUST]
    // above `site()`). The `.catch(() => null)` wrap turns a rejection and a synchronous throw
    // alike into the MISSING turn the loop handles below.
    const result = await Promise.resolve()
      .then(() => side === 'dev'
        ? agent(withTopic(DEV_TURN_PROMPT, transcript), { schema: TURN, label: `dev-t${turn}`, phase: 'Discuss', ...site('dev-turn') })
        : agent(withTopic(TEST_TURN_PROMPT, transcript), { schema: TURN, label: `test-t${turn}`, phase: 'Discuss', ...site('test-turn') }))
      .catch(() => null)
    if (!result) {
      consecutiveNull++
      transcript.push({ turn, side, message: '(no response — this turn is missing)' })
      console.log(`turn ${turn} (${side}): missing`)
      if (consecutiveNull >= MAX_CONSECUTIVE_NULL) {
        stopped = `${REASON_PARTICIPANT_MISSING} for ${consecutiveNull} consecutive turn(s)`
        break
      }
      prevDone = false
      continue
    }
    consecutiveNull = 0
    transcript.push({ turn, side, message: result.message })
    console.log(`turn ${turn} (${side}): done=${result.done}`)
    if (prevDone && result.done === true) break
    prevDone = result.done === true
  }
}

// ---- Report: each participant states what was agreed and what is worth raising ------------------
// Both reports are collected concurrently — each is the participant's own reading of the same
// transcript. One missing report is recorded and the scribe records that side's positions from the
// transcript; both missing is the same persistent infrastructure failure as two missing turns.
let devReport = null
let testReport = null
if (!stopped) {
  phase('Report')
  ;[devReport, testReport] = await parallel([
    () => agent(withTopic(DEV_REPORT_PROMPT, transcript), { schema: REPORT, label: 'dev-report', phase: 'Report', ...site('dev-turn') }),
    () => agent(withTopic(TEST_REPORT_PROMPT, transcript), { schema: REPORT, label: 'test-report', phase: 'Report', ...site('test-turn') }),
  ])
  if (!devReport && !testReport) stopped = REASON_REPORT_MISSING
}

// ---- Record: the scribe writes the documents and the report; the ledger records the agreed ------
// The scribe is a recorder: it writes the two design documents and the report from the
// participants' conclusions and adds no design of its own. Where the two reports differ, the point
// is carried as un-agreed. The scribe returns the consolidated report, which is the run's result.
const renderReport = (name, r) => r
  ? `### ${name}\nagreed:\n${r.agreed.length ? r.agreed.map((a) => `- ${a}`).join('\n') : '- (none)'}\nunagreed:\n${r.unagreed.length ? r.unagreed.map((u) => `- point: ${u.point}\n  Developer AI: ${u.developer_position}\n  Test AI: ${u.test_position}\n  why raised: ${u.why_raised}`).join('\n') : '- (none)'}`
  : `### ${name}\n(report missing — record this participant's positions from the transcript)`
if (!stopped) {
  phase('Record')
  scribeReport = await Promise.resolve()
    .then(() => agent(
      `You are the scribe of an AutoFlow ARCHITECT deliberation. From the transcript and the two participants' reports below, write three files. (1) The Feature Design Document to ${feature}: files to change, API interface, data structures, dependencies, as the participants concluded them. (2) The Verification Design Document to ${verif} in the format at docs/autoflow-guide.md > ARCHITECT > Output artifacts: one row per acceptance criterion of .autoflow/issue-${issue}-phase-b.md with its Issue AC id, verification disposition, kind, method and a one-line reason on every non-automated row, plus the Test necessity, Verification depth and Composition oracle determinations that section defines. (3) The report to ${reportPath} under the headings "## Agreed" (one line per agreed conclusion) and "## Unagreed" (per point: the point, the Developer AI's position, the Test AI's position, why it was raised). Record what the participants concluded and add no design of your own; where the two reports differ on a point, carry it as un-agreed. Then return the consolidated report: "agreed" — the conclusions both reports list; "unagreed" — every point either report raises.${FOREGROUND_RULE}\n\n## Topic\n${TOPIC}\n\n## Transcript\n${renderTranscript(transcript)}\n\n## Reports\n${renderReport('Developer AI', devReport)}\n\n${renderReport('Test AI', testReport)}`,
      { schema: REPORT, label: 'scribe', phase: 'Record', ...site('scribe') },
    ))
    .catch(() => null)
  if (!scribeReport) stopped = REASON_SCRIBE_MISSING
  else report = scribeReport
}
// The ledger records only what was agreed: one entry per agreed conclusion, under the authority
// "ARCHITECT agreed" the topic seeds as settled. An un-agreed point is not a decision and is not
// written here — it lives in the report the orchestrator routes. The entry identifier is allocated
// per CLAUDE.md > Decision Ledger (the facilitator delegate's namespace, one `next` call
// immediately before each append, `check` after). This call runs after the result is settled, so a
// failed append is absorbed to a null acknowledgement and never alters the report.
if (!stopped && report.agreed.length) {
  await Promise.resolve()
    .then(() => agent(
      `Append (do NOT rewrite or delete) to ${ledger} one entry per agreed conclusion below: the decision (the conclusion, one line); its grounds (${reportPath} and the section of ${feature} or ${verif} that records it); authority "ARCHITECT agreed"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Head each appended entry \`## <ID> — <title> (cycle <C>, ARCHITECT)\`, allocating <ID> by running \`bash scripts/ledger/ledger-entry-id.sh next ${ledger} F\` immediately before that entry's own append — one call per entry, never a serial incremented locally across the batch. After the appends, run \`bash scripts/ledger/ledger-entry-id.sh check ${ledger}\` and fix every defect it reports before returning. Return a one-line summary only.${FOREGROUND_RULE}\n\nAgreed conclusions:\n${report.agreed.map((a) => `- ${a}`).join('\n')}`,
      { label: 'ledger', phase: 'Record', ...site('ledger') },
    ))
    .catch(() => null)
}

return {
  phase: 'architect',
  // The participants' report — `null` only when the run stopped before the scribe could record it.
  report,
  artifacts: [feature, verif, reportPath],
  ledger,
  turns: turn,
  summary: stopped
    ? `ARCHITECT deliberation stopped — ${stopped}`
    : `ARCHITECT deliberation ended after ${turn} turn(s): ${report.agreed.length} agreed conclusion(s), ${report.unagreed.length} un-agreed point(s)`,
  // Infrastructure state, never a design outcome: null on a completed deliberation.
  stopped,
}
