// SPDX-FileCopyrightText: 2026 Munsik-Park
// SPDX-License-Identifier: Elastic-2.0
// ARCHITECT deliberation — the Record phase (issue #179, ADR-0023 D2).
// Invoked by the orchestrator: Workflow({ name: "architect-deliberation", args: { issue: "N" } }),
// AFTER the discussion has ended. The discussion itself no longer runs here: the Developer AI and
// the Test AI are two persistent participants the orchestrator spawns once and wakes in turn, and
// every turn and each participant's report is appended to the relay transcript file
// `.autoflow/issue-N-architect-transcript.md` (grammar and state: scripts/architect/relay-state.sh;
// procedure: docs/autoflow-guide.md > ARCHITECT). This workflow reads that file through its
// sub-agents and records the outcome: a scribe writes the feature design, the verification design
// and the deliberation report from the transcript and the two reports, and a ledger call appends
// the agreed conclusions. The orchestrator receives only the returned object — it never receives
// the turns (Decision 8). Requires Claude Code v2.1.154+ (Workflow runtime).
export const meta = {
  name: 'architect-deliberation',
  description: 'ARCHITECT Record phase: after the orchestrator-relayed discussion has ended, a scribe writes the two design documents and the deliberation report from the relay transcript file (.autoflow/issue-N-architect-transcript.md — turns plus both participants\' reports), and the ledger records the agreed conclusions. Invoke with args {issue: "N"} (issue number required).',
  phases: [
    { title: 'Record', detail: 'the scribe writes the feature design, the verification design and the report from the transcript file; the ledger records the agreed conclusions' },
  ],
}

// Stable stop-reason literals: declared once, shared verbatim by this script and the regression
// tests, so an assertion pins a cause by equality rather than by prose. `stopped` is the run's
// infrastructure state — it says the record could not be carried out, never what the participants
// concluded; a completed run returns `stopped: null` whatever its report says.
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
// System boundary: reject a missing arg loudly rather than proceeding on a placeholder. The
// orchestrator's `brief` is no longer an argument of this workflow: a re-discussion is carried by
// the relay (a `### Brief` block in the transcript, scripts/architect/relay-state.sh brief), and
// the scribe reads it there with everything else.
if (!argv.issue) throw new Error('architect-deliberation: args.issue is required')
const issue = argv.issue
const transcript = `.autoflow/issue-${issue}-architect-transcript.md`
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
    { schema: POLICY_FILE, label: 'policy-load', phase: 'Record' },
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
// tests/test-spawn-policy-single-source.sh > required-key-declaration-join. The discussion turns
// have no site here since issue #179: the participants are direct spawns whose model the
// orchestrator resolves from the policy's `phases` rows (architect-dev-participant /
// architect-test-participant).
const REQUIRED_SITE_KEYS = [
  /* site-keys:begin */
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

// ---- Record: the scribe writes the documents and the report; the ledger records the agreed ------
// The scribe is a recorder: it reads the transcript file — the topic, every turn, any brief, and
// the two participants' reports — and writes the two design documents and the report from the
// participants' conclusions, adding no design of its own. Where the two reports differ, the point
// is carried as un-agreed; a report section that is missing is recorded from that participant's
// turns. The scribe returns the consolidated report, which is the run's result.
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
let report = null
if (!stopped) {
  phase('Record')
  console.log(`ARCHITECT record for issue #${issue}`)
  const scribeReport = await Promise.resolve()
    .then(() => agent(
      `You are the scribe of an AutoFlow ARCHITECT deliberation. The discussion has ended; its whole record is the relay transcript file ${transcript} — read it in full: the "## Topic" section (the question and any orchestrator brief), every "### Turn n — <side>" block in order (any "### Brief" block re-opened the discussion with the orchestrator's preparation), and the two participants' reports under "## Report — Developer AI" and "## Report — Test AI" (each lists the conclusions that participant accepted and the points it raises as un-agreed). From that record write three files. (1) The Feature Design Document to ${feature}: files to change, API interface, data structures, dependencies, as the participants concluded them. (2) The Verification Design Document to ${verif} in the format at docs/autoflow-guide.md > ARCHITECT > Output artifacts: one row per acceptance criterion of .autoflow/issue-${issue}-phase-b.md with its Issue AC id, verification disposition, kind, method and a one-line reason on every non-automated row, plus the Test necessity, Verification depth and Composition oracle determinations that section defines. (3) The report to ${reportPath} under the headings "## Agreed" (one line per agreed conclusion) and "## Unagreed" (per point: the point, the Developer AI's position, the Test AI's position, why it was raised). Record what the participants concluded and add no design of your own; where the two reports differ on a point, carry it as un-agreed; if a participant's report section is missing, record that participant's positions from its turns. Do not edit ${transcript}. Then return the consolidated report: "agreed" — the conclusions both reports list; "unagreed" — every point either report raises.${FOREGROUND_RULE}`,
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
  transcript,
  ledger,
  summary: stopped
    ? `ARCHITECT record stopped — ${stopped}`
    : `ARCHITECT record written from ${transcript}: ${report.agreed.length} agreed conclusion(s), ${report.unagreed.length} un-agreed point(s)`,
  // Infrastructure state, never a design outcome: null on a completed record.
  stopped,
}
