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
  description: 'Isolated ARCHITECT facilitation: Developer-AI + Test-AI converge on feature + verification design in workflow sub-contexts; returns a single verdict. Invoke with args {issue: "N"} (issue number required), or {issue: "N", resume: "true"} to resume an ESCALATEd deliberation from its persisted register — skipping Draft and running one further round.',
  phases: [
    { title: 'Draft', detail: 'dev drafts feature design, test drafts verification design (independent) — cold runs only' },
    { title: 'Resume', detail: 'load the persisted issue register and re-enter Converge at the prior run\'s round — resume runs only' },
    { title: 'Converge', detail: 'cross-review rounds under the Discussion Protocol until mutual ACCEPT or the round cap' },
    { title: 'Reconcile', detail: 'on a converged run, compare the issue acceptance-criterion list against the converged verification design — converged runs only' },
    { title: 'Ledger', detail: 'append the settled decisions (append-only)' },
    { title: 'Register', detail: 'persist the issue register so a later resume can re-enter from it' },
  ],
}

const MAX_ROUNDS = 6 // Decision 7: explicit cap; a round = one Developer-AI <-> Test-AI exchange cycle.
// Stable escalation-reason literals (DCR-3): declared once, shared verbatim by this script
// and the regression test's `escalation`/ledger-prompt assertions so those are not brittle
// to prose rewording. Ported from verify-cause-branch.js's `missing`-sentinel discipline.
const REASON_DRAFT_AGENT_MISSING = 'draft agent missing'
const REASON_SUBAGENT_MISSING = 'sub-agent missing' // full: `${REASON_SUBAGENT_MISSING} for N consecutive round(s)`
// The cap-round closing half-round's own sentinels (issue #123), in the same declare-once
// discipline. The reason is assigned BARE — no interpolation, no suffix — so an assertion can
// pin it by equality; it is a MISSING-judgment cause and must not be laundered into the generic
// round-exhaustion text. The label is distinct from every `<side>-r<N>` round label (no digit run
// after `-r`), so a consumer partitioning calls by the round-label shape keeps counting rounds.
const REASON_CLOSING_AGENT_MISSING = 'closing agent missing'
const CLOSING_CALL_LABEL = 'test-closing'
// Resume-path guard sentinels (issue #127), same declare-once discipline. Each is assigned BARE —
// no interpolation, no suffix — so an assertion pins it by equality and a load failure is never
// laundered into the generic round-exhaustion text. One literal per declared guard condition.
const REASON_RESUME_LOAD_AGENT_MISSING = 'resume register load agent missing'
const REASON_RESUME_REGISTER_ABSENT = 'resume register absent'
const REASON_RESUME_ARTIFACT_MISSING = 'resume design artifact missing'
const REASON_RESUME_NO_OPEN_ENTRY = 'resume register has no open entry'
const REASON_RESUME_ALREADY_CONVERGED = 'resume register already converged'
// The resume-scoped open-entry precondition on CONVERGED (issue #127, cycle 3). Same declare-once,
// assigned-BARE discipline: this is a design outcome with its own cause — a resume run whose agenda
// entries were never disposed of — and laundering it into the generic round-exhaustion text would
// hide from the operator which concern blocked the run.
const REASON_RESUME_OPEN_ENTRY_AT_CONVERGENCE = 'resume register still open at convergence'
// Acceptance-criterion authority sentinels (issue #138), same declare-once, assigned-BARE
// discipline. They are carried on their OWN field, `acReason`, not inside `escalation`: an
// AC_CHANGE run converged, so `escalation` stays null by its existing definition and the two
// fail-closed causes would otherwise be indistinguishable from each other and from an
// unauthorized-finding pause. Fail-closed is deliberate and asymmetric with the terminal Ledger
// and Register calls: Reconcile runs BEFORE the verdict and stands in front of a human authority
// boundary, so a null return, a malformed payload or a missing AC table resolves to AC_CHANGE
// rather than degrading to CONVERGED — degrading would silently reproduce the #134 incident.
const REASON_AC_RECONCILIATION_UNAVAILABLE = 'ac reconciliation unavailable'
const REASON_AC_LIST_ABSENT = 'ac list absent'
const REASON_AC_UNAUTHORIZED_CHANGE = 'unauthorized acceptance-criterion change'
// Minted register-entry names for the two fail-closed paths (issue #138). Declared once so the
// resume agenda an operator re-enters on is named by a literal, not by assembled prose.
const AC_ENTRY_RECONCILIATION_UNAVAILABLE = 'ac-authority:reconciliation-unavailable'
const AC_ENTRY_AC_LIST_ABSENT = 'ac-authority:ac-list-absent'
const AC_ENTRY_PREFIX = 'ac-authority:'
// Fence sentinels for the persisted register payload (issue #127). The register-write prompt wraps
// the serialized JSON in these two literals and instructs the sub-agent to write exactly the bytes
// between them, so the payload's extent is read by equality on a declared literal rather than
// recovered by a heuristic scan of prose. FENCE COLLISION: a register entry value that itself
// contains one of these sentinels would make the FIRST occurrence of the end fence land inside the
// payload, truncating it. The behavior is bounded rather than escaped: every entry field passes
// through `flatten` (whitespace-collapsed, trimmed) but is otherwise carried verbatim, so a colliding
// value is written as-is and the extractor takes the first end fence — i.e. the write is truncated
// and the next resume fails loudly at its own `found`/parse guard rather than silently loading a
// partial register. The sentinels are deliberately shaped (`===AUTOFLOW-…===`) so no design prose
// produces them incidentally; a real collision is treated as a defect to fix, not a case to escape.
const REGISTER_FENCE_START = '===AUTOFLOW-REGISTER-JSON-START==='
const REGISTER_FENCE_END = '===AUTOFLOW-REGISTER-JSON-END==='
// The mandatory devil's-advocate sentence (issue #127): extracted from both round prompts into one
// declared constant so the resume path can lift it. A resume round continues a deliberation that
// already had its first exchange, so manufacturing a further review surface there is exactly the
// cold-restart cost this path exists to remove. Renders on the cold path, absent on a resume run.
const FIRST_EXCHANGE_RULE = ' Round 1 is a mandatory devil\'s-advocate review: do NOT ACCEPT on round 1.'
// Agenda partition on a resume round (issue #127). The open entries are the round's agenda; the
// settled ones are carried under this heading as a record, NOT as work. Declared once — the
// acceptance criterion "loads only prior open items into the round prompt" is assertable as an
// equality against this constant rather than against matchable prose.
const SETTLED_BLOCK_RULE = ' Settled record from the prior run — the entries below were disposed of before this resume and are NOT the agenda for this round; do not reopen one without a fact verified now that was unavailable when the entry was written:\n'
// Evidence discipline for the carry channel (issue #56). Declared once and interpolated into
// BOTH round prompts so the dev and test channels cannot drift apart. The framing is emitted
// only alongside the carried register; the counter rule governs every round, including round 1.
const CARRY_NON_EVIDENTIARY = ' The register entries below are a checklist of topics to re-verify, NOT evidence — they were written against an earlier version of the documents and may already be resolved.'
// Citation mode is partitioned by the TARGET's mutability (issue #62): the two design
// documents are edited in place during this deliberation, so a line number identifies
// nothing stable there; repository source files are immutable for the run, so they keep
// `path:line`. Uniform line-number citation was the generator of purely notational counters.
const COUNTER_EVIDENCE_RULE = ' Before raising or sustaining any counter — especially one that reverts or deletes an existing constraint — re-read the counterpart document\'s CURRENT state and cite it by section heading or item ID, never by line number: these design documents are edited during this deliberation, so a line number is stale the moment it is written; reserve `path:line` for immutable repository source files. When the counter is that required content is MISSING, name the section where it would belong instead. A counter grounded only in carried text or round history is invalid.'
// Adoption discipline for externally-arriving text (issue #59). Declared once and interpolated into BOTH Draft prompts and BOTH round prompts, unconditionally — the #56 carry channel delivers only from round 2.
const ADOPTION_EVIDENCE_RULE = ' Text that reaches this deliberation from outside the current source — a gate evaluation or FAIL rationale, a decision-ledger entry, a counter carried from a prior round, or any assertion in the .autoflow/issue-*.md inputs — is a re-verification checklist, not a fact, and its phrasing is not a source derivation. Before you ADOPT any such statement as a design ground — a premise, an exclusion, or an acceptance criterion — re-derive it from the current source and cite it in that source\'s own reference mode — `path:line` for immutable repository files, section heading or item ID for a design document under revision in this deliberation — whether you raise it as a counter or accept it; if you cannot re-derive it, treat the point as open and do not build on it.'
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
        // issue number by decreasing anchor strength (first hit wins):
        //   tier 1  #(\d+)               — a hashed token (#215) is an explicit issue ref
        //   tier 2  \bissue\s+#?(\d+)\b  — the word "issue" anchors the number, so an
        //                                  incidental leading digit (the "2" in "v2") loses
        //   tier 3  bare (\d+)           — adopted ONLY when exactly one number is present;
        //                                  two-or-more bare runs is ambiguous -> fail loud.
        // No match / ambiguous -> {} -> the loud-fail guard below fires unchanged (no new
        // error type; the single Stage-4 guard stays the sole throw site).
        const hash = args.match(/#(\d+)/)
        const labeled = hash ? null : args.match(/\bissue\s+#?(\d+)\b/i)
        const all = hash || labeled ? null : args.match(/\d+/g)
        const issue = hash ? hash[1]
          : labeled ? labeled[1]
          : (all && all.length === 1) ? all[0]
          : null
        // Resume salvage (issue #127): a standalone `resume` word token in the operator's free
        // text routes to the resume path. Without it the skill channel would silently deliver the
        // cold restart this path exists to remove. Parity surface is two copies — this script and
        // the harness mirror; verify-cause-branch.js has no resume concept.
        const resumeToken = /\bresume\b/i.test(args)
        const salvaged = {}
        if (issue) salvaged.issue = issue
        if (resumeToken) salvaged.resume = true
        return salvaged
      }
    })()
  : (args || {})
// Resume admission is strict (issue #127): `true`/`"true"` take the resume path, absent/`false`/
// `"false"` the cold one, anything else is a boundary failure. A silently ignored malformed value
// would degrade into exactly the cold restart this path removes, so it fails loud.
const resumeArg = argv.resume
const resume = resumeArg === true || resumeArg === 'true'
const resumeMalformed = ![true, 'true', false, 'false', undefined, null].includes(resumeArg)
// System boundary: reject a missing or malformed required arg loudly rather than proceeding with a
// placeholder path. Kept as the SINGLE throw site — the resume rule extends this guard, it does not
// add a second one.
if (!argv.issue || resumeMalformed) {
  throw new Error(!argv.issue
    ? 'architect-deliberation: args.issue is required'
    : `architect-deliberation: args.resume must be true, "true", false, "false" or absent (got ${JSON.stringify(resumeArg)})`)
}
const issue = argv.issue
const feature = `.autoflow/issue-${issue}-feature-design.md`
const verif = `.autoflow/issue-${issue}-verification-design.md`
const ledger = `.autoflow/issue-${issue}-ledger.md`
// The issue's acceptance-criterion list (issue #138). It is a SECTION of the existing DIAGNOSE
// Phase B artifact, not a new artifact: both archived cycles already write one there, and a new
// file would add a surface, a lifecycle and an archive rule for addressability a heading already
// gives. Read only by the Reconcile channel — this script has no filesystem.
const phaseB = `.autoflow/issue-${issue}-phase-b.md`
// The durable issue register (issue #127): written by every run that ever held a faithful register,
// read only by a resume run. It is what makes re-entry cost one round instead of a cold restart.
const registerPath = `.autoflow/issue-${issue}-architect-register.json`
// Register mechanics (issue #67). Round prompts only: the Draft calls pass no `schema`, so a
// Draft agent has no `dispositions` channel and round 1's register is empty. Declared once and
// interpolated byte-identically into both round prompts. It states disposal in its own words —
// the carry-conditional "by dismissing it with the current" phrasing stays on the carry line,
// which round 1 never receives.
const REGISTER_RULE = ' The issue register carried below is this deliberation\'s record: refer to each entry by its short readable name, never by a serial number, and update an entry in place instead of appending a second one — entries are never renumbered. An entry marked `agreed` or `rejected` is not reopened without a newly verified fact. Dispose of every open entry before you ACCEPT: return one item in "dispositions" for each entry you close, naming it and giving it `agreed` or `rejected`. Only the side that raised an entry may close it — a disposition returned by the other side proposes a resolution, which is recorded in the entry\'s conclusion while its status stays open.'
// Ledger seeding (issue #67). Draft prompts only: the register is empty at Draft time, but the
// prior deliberation's ledger is the cross-session half of the no-re-litigation rule, and only a
// Draft agent (which has filesystem access; this script does not) can read it.
// The authority set gains "operator decision" (issue #138): an operator's acceptance-criterion
// ruling is settled by the one authority this deliberation cannot outvote, so a resumed round must
// treat it as closed rather than re-arguing it. "ARCHITECT ac-change" is deliberately NOT in the
// set — that entry records content still awaiting the operator's decision, and seeding un-agreed
// content as settled is precisely what the no-re-litigation rule would then lock in.
const LEDGER_SEED_RULE = ` Read ${ledger} first if it exists: every entry there under authority "ARCHITECT mutual ACCEPT", "ARCHITECT rejected" or "operator decision" is a settled registered issue — treat it as closed and do not re-litigate it unless you can cite a fact verified now, in that source's own reference mode, that was unavailable when the entry was written.`
// The join key the Reconcile phase reads (issue #138). Declared once and interpolated into every
// Test-AI prompt that authors or revises the verification design — the Draft turn, every round
// turn, and the cap-round closing turn — because the column must exist before anything joins on
// it, and the composition-oracle / verification-depth obligations reached the authoring agent
// through these same prompt literals.
const ISSUE_AC_COLUMN_RULE = ` The acceptance-criteria table in ${verif} carries a leading "Issue AC" column: each row's value is either an AC id copied from the "## Acceptance criteria" table in ${phaseB}, or "—" for a criterion this verification design added on its own. Every AC id in that table gets a row, and a criterion you decline, defer or weaken keeps its row and states that disposition — never drop the row. A design-added criterion ("—") is never a finding.`
// Record discipline (issue #67). All four prompts: the Draft agents author the documents this
// rule governs, and the round agents edit them in place.
const RECORD_DISCIPLINE_RULE = ' Record discipline: the design documents carry only the current design and its conclusions — no round history; measurement logs, command output and code text are never copied into them, so state evidence as one line of what was checked and how, and re-verify it next round with tooling. Name issues with short readable names instead of serial numbers, and write no totals or counts into the documents.'

// A counter is a three-field record (issue #62): the concern's NAME, WHERE to look, and
// the case itself. All three cross a round boundary as a register entry — see toEntry below.
const COUNTER = {
  type: 'object',
  additionalProperties: false,
  properties: {
    // What is under dispute, not the case for it.
    agenda: { type: 'string' },
    // A section heading or item ID in the counterpart design document, or `path:line`
    // when the target is repository source (see COUNTER_EVIDENCE_RULE).
    locator: { type: 'string' },
    // The case itself. Becomes the entry's `conclusion` and DOES cross the round boundary
    // (issue #67) — the property the retired document-as-durable-channel rule stood in for.
    argument: { type: 'string' },
  },
  required: ['agenda', 'locator', 'argument'],
}

// Register field placeholders (issue #67). No character cap survives: the per-entry bound is
// structural — a fixed four labelled lines plus one `---` terminator — not lexical.
const LOCATOR_UNSPECIFIED = 'unspecified'
const NAME_UNSPECIFIED = 'unspecified concern'
const ENTRY_DELIMITER = '---'
// Flattening is what makes the line count fixed: every whitespace run — newline, CR, tab, space
// run — collapses to a single space, then the value is trimmed. Runs BEFORE the never-empty
// defaulting below, so a field that flattens to '' still takes its placeholder. It replaces, in
// role, the incidental \n-escaping the retired JSON.stringify carry gave for free.
const flatten = (v) => (v == null ? '' : String(v)).replace(/\s+/g, ' ').trim()
// One key normalization, shared by the raise path and the dispose path, so a near-miss name
// resolves identically in both.
const normalizeKey = (s) => flatten(s).toLowerCase()
// Normalize ANY counter item — record, bare string, or partial record — into a register entry.
// A non-record item is never emptied: its own text becomes the name, so no raised concern can
// be lost (a destructuring projection would render a bare string as `{}`, silently dropping it).
const toEntry = (c, raisedBy) => {
  let name, conclusion, evidence
  if (typeof c === 'string') {
    name = c; conclusion = ''; evidence = LOCATOR_UNSPECIFIED
  } else if (c && typeof c === 'object') {
    name = (typeof c.agenda === 'string' && c.agenda) || JSON.stringify(c)
    conclusion = (typeof c.argument === 'string' && c.argument) || ''
    evidence = (typeof c.locator === 'string' && c.locator) || LOCATOR_UNSPECIFIED
  } else {
    name = NAME_UNSPECIFIED; conclusion = ''; evidence = LOCATOR_UNSPECIFIED
  }
  return {
    name: flatten(name) || NAME_UNSPECIFIED,
    conclusion: flatten(conclusion),
    evidence: flatten(evidence) || LOCATOR_UNSPECIFIED,
    status: 'open',
    raisedBy,
  }
}
// Four labelled content lines + a terminator (emitted after EVERY entry, including the last, so
// the delimiter count is an exact entry count). Each line begins with its fixed label, so a field
// whose flattened value is itself `---` renders as `conclusion: ---`, never as a delimiter.
const renderEntry = (e) => `name: ${e.name}\nconclusion: ${e.conclusion}\nevidence: ${e.evidence}\nstatus: ${e.status} (raised by ${e.raisedBy})\n${ENTRY_DELIMITER}\n`
const renderRegister = (reg, keep) => [...reg.values()].filter(keep || (() => true)).map(renderEntry).join('')

// A disposition is the RETURNED judgment on a register entry — the script cannot infer
// agreement. Closed record, matching the discipline COUNTER and VERDICT already carry.
const DISPOSITION = {
  type: 'object',
  additionalProperties: false,
  properties: {
    name: { type: 'string' },
    conclusion: { type: 'string' },
    evidence: { type: 'string' },
    status: { type: 'string', enum: ['agreed', 'rejected'] },
  },
  required: ['name', 'conclusion', 'evidence', 'status'],
}

const VERDICT = {
  type: 'object',
  additionalProperties: false,
  properties: {
    response: { type: 'string', enum: ['ACCEPT', 'COUNTER', 'PARTIAL'] },
    // Open concerns this party still has. ACCEPT REQUIRES this to be empty
    // (Discussion Protocol: a raised concern is never dropped unresolved).
    counters: { type: 'array', items: COUNTER },
    // Grounds for ACCEPT: the dimensions verified + why each passed (Discussion Protocol:
    // ACCEPT must name the dimensions verified). ACCEPT REQUIRES this to be non-empty.
    accept_grounds: { type: 'array', items: { type: 'string' } },
    // Judgments on register entries this party is closing. Required, but an empty array is
    // valid — a round that disposes of nothing returns []. The enum above states the intent;
    // the runtime guard is applyDispositions, since `schema` is opaque to this script.
    dispositions: { type: 'array', items: DISPOSITION },
  },
  required: ['response', 'counters', 'accept_grounds', 'dispositions'],
}

// Register load schema (issue #127). Closed, in the same discipline as COUNTER/DISPOSITION/VERDICT:
// the load call is a pure transcription channel, so what comes back is structured, not prose. The
// persisted `escalation` and `lastResponses` fields are deliberately OUTSIDE this schema — no
// control-flow decision reads them; their consumer is the operator, per the resume procedure in
// docs/autoflow-guide.md > ARCHITECT.
const REGISTER_ENTRY = {
  type: 'object',
  additionalProperties: false,
  properties: {
    name: { type: 'string' },
    conclusion: { type: 'string' },
    evidence: { type: 'string' },
    status: { type: 'string', enum: ['open', 'agreed', 'rejected'] },
    raisedBy: { type: 'string', enum: ['dev', 'test'] },
  },
  required: ['name', 'conclusion', 'evidence', 'status', 'raisedBy'],
}
const REGISTER_FILE = {
  type: 'object',
  additionalProperties: false,
  properties: {
    // The artifact exists and parsed.
    found: { type: 'boolean' },
    // Both design documents exist and are non-empty. Checked HERE because resume skips Draft, and
    // this sub-agent is already reading the filesystem the script cannot reach.
    artifacts_present: { type: 'boolean' },
    lastRound: { type: 'number' },
    // Carried so the resume guards can refuse a resume of a run that already converged — the
    // `no open entry` guard cannot make that refusal (a CONVERGED run may still hold open entries).
    // Widened for AC_CHANGE (issue #138) so a persisted AC_CHANGE register LOADS instead of
    // failing its own schema. The `already converged` guard stays keyed to CONVERGED alone, which
    // is what keeps an AC_CHANGE register resumable — the operator's whole re-entry path.
    verdict: { type: 'string', enum: ['CONVERGED', 'AC_CHANGE', 'ESCALATE'] },
    entries: { type: 'array', items: REGISTER_ENTRY },
  },
  required: ['found', 'artifacts_present', 'lastRound', 'verdict', 'entries'],
}

// Reconcile channel schema (issue #138). Closed, in the same discipline as the schemas above. The
// channel has TWO declared halves and only the second is a reading: `ac_rows` and
// `ledger_ac_decisions` are TRANSCRIPTION (cell values copied out, uninterpreted), and the script
// derives `kind` and `authorized` from them in its own code. That split is what makes the
// join-decidable kinds assertable against a fixture with no model in the assertion path, and it
// keeps the channel a comparison channel rather than a reviewer: judging whether an
// acceptance-criterion change was JUSTIFIED is the faculty the #134 incident showed to be
// capturable by a well-written rationale, and it belongs to the operator.
const AC_ROW = {
  type: 'object',
  additionalProperties: false,
  properties: {
    // AC id, copied from the Phase B table.
    ac: { type: 'string' },
    // Some verification-design row's `Issue AC` cell equals this id.
    carried: { type: 'boolean' },
    // The carrying row's stated disposition mapped to this closed set; 'absent' iff !carried.
    disposition: { type: 'string', enum: ['verified', 'declined', 'deferred', 'absent'] },
    // The carrying row's Method cell names a file path, a command, or a manual-scenario file.
    method_executable: { type: 'boolean' },
    // The carrying row's name, or '—'.
    locator: { type: 'string' },
    // The row's disposition wording, copied verbatim.
    proposed: { type: 'string' },
  },
  required: ['ac', 'carried', 'disposition', 'method_executable', 'locator', 'proposed'],
}
const AC_SUBSTITUTION = {
  type: 'object',
  additionalProperties: false,
  properties: { ac: { type: 'string' }, locator: { type: 'string' }, proposed: { type: 'string' } },
  required: ['ac', 'locator', 'proposed'],
}
const AC_DIFF = {
  type: 'object',
  additionalProperties: false,
  properties: {
    // The Phase B `## Acceptance criteria` section exists and parses as a table.
    ac_source_present: { type: 'boolean' },
    ac_rows: { type: 'array', items: AC_ROW },
    // Transcription, second list: one entry per level-2 ledger heading ending in the
    // `[ac-decision]` marker, carrying that entry's `- AC:` value. Nothing else.
    ledger_ac_decisions: { type: 'array', items: { type: 'string' } },
    // The one reading the channel is asked for, and the design's stated residual
    // false-positive surface.
    substituted: { type: 'array', items: AC_SUBSTITUTION },
  },
  required: ['ac_source_present', 'ac_rows', 'ledger_ac_decisions', 'substituted'],
}
// The kind table, in the script, first match wins — one finding per row at most. `weakened` is
// bounded to the DECIDABLE form (no executable method named): "asserts a strictly weaker property"
// is a depth judgment about verification strength, which is both the faculty the channel is
// forbidden to exercise and an unbounded false-positive source; real-but-executable weakening
// stays with GATE:PLAN's depth items, which already score it.
const acKindOf = (row) => {
  if (!row.carried) return 'dropped'
  if (row.disposition === 'declined') return 'not-carried'
  if (row.disposition === 'deferred') return 'deferred'
  if (!row.method_executable) return 'weakened'
  return null
}
// Payload well-formedness. A schema is advisory to this script (it is opaque here, exactly as
// `applyDispositions` is the runtime guard behind DISPOSITION's enum), so a malformed return is
// treated as the channel not having delivered — fail-closed, not fail-open.
const acDiffWellFormed = (d) => !!d && typeof d === 'object' &&
  typeof d.ac_source_present === 'boolean' &&
  Array.isArray(d.ac_rows) && Array.isArray(d.ledger_ac_decisions) && Array.isArray(d.substituted)

// A null draft return is a skipped/errored sub-agent — the ARCHITECT analogue of VERIFY's
// `test ? test.verdict : 'missing'`. Record it as a distinct early-ESCALATE reason and skip
// Converge entirely, so the terminal `escalation` string stays truthful about the cause.
// A resume guard failure uses the same variable, so Converge is skipped through one path.
let earlyEscalateReason = null
let loaded = null
// The issue register (issue #67): an insertion-ordered map keyed by the normalized concern name,
// holding EVERY entry raised in the run — open, agreed and rejected alike. Unlike the retired
// `openCounters`, it is never reassigned, so a disposed entry stays visible and the
// no-re-litigation rule has something to point at. On a resume run it is rehydrated from the
// persisted register before Converge (issue #127) rather than starting empty.
const register = new Map()
// Zero-argument open-entry predicate over the register's CURRENT state (issue #127, cycle 3),
// declared with the register and read by the two convergence guard sites below. Zero-arity for the
// same reason `renderCarry` is: the register is a run-level structure, so both sites want the same
// question asked of the same map, not a parameterized view of it.
const hasOpenEntry = () => [...register.values()].some((e) => e.status === 'open')
// Rehydration is defensive (issue #127): a loaded entry passes back through the same flatten +
// never-empty defaulting a raised counter does, so the four-labelled-lines-plus-terminator render
// invariant holds whatever the load agent returned. An out-of-enum `status` coerces to `open` (the
// conservative direction — it keeps the concern on the agenda); an out-of-enum `raisedBy` coerces
// to `test`, because applyDispositions lets only the raiser close an entry and an unrecognized
// value would make the entry permanently uncloseable, forcing a guaranteed ESCALATE. `test` is the
// side the resumed round starts on and the side the closing half-round belongs to.
const rehydrate = (e) => {
  const src = e && typeof e === 'object'
    ? { agenda: e.name, locator: e.evidence, argument: e.conclusion }
    : e
  const raisedBy = e && (e.raisedBy === 'dev' || e.raisedBy === 'test') ? e.raisedBy : 'test'
  if (e && typeof e === 'object' && e.raisedBy !== raisedBy) {
    console.log(`register entry "${e.name}" rehydrated with raisedBy coerced to ${raisedBy} (was "${e.raisedBy}")`)
  }
  const entry = toEntry(src, raisedBy)
  entry.status = e && (e.status === 'agreed' || e.status === 'rejected') ? e.status : 'open'
  return entry
}

if (!resume) {
  phase('Draft')
  console.log(`ARCHITECT facilitation for issue #${issue} (cap ${MAX_ROUNDS} rounds)`)

// Independent first drafts — the two perspectives do not see each other's draft yet.
const [devDraft, testDraft] = await parallel([
  () => agent(
    `You are the Developer AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md (issue analysis + plan inputs) and any repo code you need. Author the Feature Design Document — files to change, API interface, data structures, dependencies — and WRITE it to ${feature}. Honor docs/teammate-common-rules.md > Discussion Protocol and docs/submodule-common-rules.md > Change Surface Rules. Return a one-line summary only; the document body goes in the file, not the return.${ADOPTION_EVIDENCE_RULE}${LEDGER_SEED_RULE}${RECORD_DISCIPLINE_RULE} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'dev-draft', phase: 'Draft', model: 'opus' },
  ),
  () => agent(
    `You are the Test AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md and the relevant code. Author the Verification Design Document — each acceptance criterion -> verification type (automated / manual / environment-dependent) -> method; testability assessment; design-change requests for untestable items; the composition-oracle determination per docs/autoflow-guide.md > ARCHITECT > Output artifacts > Composition oracle (a non-mock oracle per intersecting shared-state identifier, or an explicit no-intersection declaration); and the Verification depth determination per docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth (a risk line naming who is harmed if this change is wrong, plus one line per verification layer and per new spec file naming the failure mode no other layer catches — a justification form, not a quantity cap) — and WRITE it to ${verif}. Return a one-line summary only.${ISSUE_AC_COLUMN_RULE}${ADOPTION_EVIDENCE_RULE}${LEDGER_SEED_RULE}${RECORD_DISCIPLINE_RULE} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'test-draft', phase: 'Draft', model: 'opus' },
  ),
])

  if (!devDraft) earlyEscalateReason = `${REASON_DRAFT_AGENT_MISSING} (dev-draft returned null)`
  else if (!testDraft) earlyEscalateReason = `${REASON_DRAFT_AGENT_MISSING} (test-draft returned null)`

// Artifact existence is NOT checked here on the cold path. The Workflow runtime rejects `import(` at
// parse time (`SyntaxError: import() is not available in workflow scripts`) and injects
// no filesystem access, so a script-side check makes this file unlaunchable rather than
// degrading. The check lives with the orchestrator, which has a shell: see
// docs/autoflow-guide.md > ARCHITECT. Do not re-add `import(` to this file — issue #62.
} else {
  // Resume (issue #127): no Draft sub-agent is spawned and no document is re-authored. The register
  // load is a pure transcription channel — the script has no filesystem, so the sub-agent reads the
  // artifact and returns it under the closed REGISTER_FILE schema.
  phase('Resume')
  console.log(`ARCHITECT resume for issue #${issue} — loading ${registerPath}`)
  loaded = await Promise.resolve()
    .then(() => agent(
      `You are a transcription channel, not a reviewer. Read ${registerPath} and return its contents under the given schema, verbatim — do not summarize, reword, add, drop or re-order anything. Set "found" true only when the file exists AND parses as JSON; when it does not, set "found" false and return the other fields as empty defaults. Set "artifacts_present" true only when BOTH ${feature} and ${verif} exist and are non-empty. Copy "lastRound", "verdict" and every element of "entries" (name, conclusion, evidence, status, raisedBy) exactly as the file states them. Exercise no judgment about the design itself. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: REGISTER_FILE, label: 'register-load', phase: 'Resume', model: 'sonnet' },
    ))
    .catch(() => null)
  // Resume guards, in declared order. Each resolves to its OWN bare sentinel so a load failure is
  // attributable and is never laundered into the generic round-exhaustion text. A guard failure is
  // also write-ineligible: the run never held a faithful register, so it must not overwrite one.
  if (!loaded) earlyEscalateReason = REASON_RESUME_LOAD_AGENT_MISSING
  else if (!loaded.found) earlyEscalateReason = REASON_RESUME_REGISTER_ABSENT
  else if (!loaded.artifacts_present) earlyEscalateReason = REASON_RESUME_ARTIFACT_MISSING
  if (!earlyEscalateReason) {
    for (const e of Array.isArray(loaded.entries) ? loaded.entries : []) {
      const entry = rehydrate(e)
      register.set(normalizeKey(entry.name), entry)
    }
    // A prior run that escalated with no open entry escalated for an infrastructure cause, and
    // resume is not the instrument for that — a deliberate refusal, not a degenerate empty round.
    if (!hasOpenEntry()) earlyEscalateReason = REASON_RESUME_NO_OPEN_ENTRY
    // The refusal the row above cannot make: a run converges on mutual grounded ACCEPT regardless
    // of whether every entry was disposed of, so a CONVERGED run can persist open entries. Resuming
    // there would reopen a design the ledger already records under "ARCHITECT mutual ACCEPT".
    else if (loaded.verdict === 'CONVERGED') earlyEscalateReason = REASON_RESUME_ALREADY_CONVERGED
  }
}

// Register write eligibility (issue #127), evaluated HERE because it is a property of the RUN, not
// a branch of the resume path: a run writes the register only if it ever held a faithful copy of
// it. Both ineligible shapes are exactly the pre-Converge early escalations — a resume that failed
// a load guard (it could not read the file it would overwrite) and a cold run that early-escalates
// on a null draft (its register is empty and `round` stays 0, so a terminal write would destroy an
// existing register with `{lastRound: 0, entries: []}`). The second is reachable by the operator's
// most natural action after an ESCALATE, a plain re-invocation, which is why the predicate is
// stated over run shapes rather than over `resume`.
const registerHeld = !earlyEscalateReason

phase('Converge')
// Round bounds (issue #127). A cold run starts at 0 and is bounded by MAX_ROUNDS, byte-identically
// to before. A resume run continues the PERSISTED round number — never a number taken from an
// argument — and admits exactly one further round: the operator-decided single-round extension.
// The loop still terminates on its own bound (Decision 7), not on a count of resumes taken.
const startRound = resume && loaded ? (Number(loaded.lastRound) || 0) : 0
let round = startRound
const roundCeiling = resume ? startRound + 1 : MAX_ROUNDS
// The mandatory first-exchange rule and the cross-session ledger seed are the two run-level
// switches the resume path flips. Neither adds a round-family prompt literal: there is no separate
// "resume round prompt" — the resume path re-enters the same loop and the same closing block.
const firstExchange = resume ? '' : FIRST_EXCHANGE_RULE
// Draft prompts carry LEDGER_SEED_RULE on the cold path; resume skips Draft outright, so without
// this the cross-session half of the no-re-litigation rule would be silently dropped. Renders the
// empty string on the cold path, leaving those prompts byte-identical.
const resumeSeed = resume ? LEDGER_SEED_RULE : ''
let converged = false
// This run's LAST convergence-guard decision (issue #127, cycle 3), not a latch. It is ASSIGNED at
// every guard site, whether or not that site denied, because the terminal turn decides the reason:
// an in-loop denial always summons the closing half-round, and if that turn COUNTERs then mutual
// ACCEPT never happened on this run and the generic round-exhaustion text is the true one. The
// `converged` conjunct is what makes the assignment at a non-denying site write `false`.
let openEntryDenied = false
// Raise path: upsert as `open`. A re-raise updates the existing entry in place; `raisedBy` and
// the display `name` are fixed at first creation, so a carried name token is stable across rounds.
const raise = (items, side) => {
  for (const item of Array.isArray(items) ? items : []) {
    const fresh = toEntry(item, side)
    const prior = register.get(normalizeKey(fresh.name))
    if (prior) {
      prior.conclusion = fresh.conclusion
      prior.evidence = fresh.evidence
      prior.status = 'open'
    } else {
      register.set(normalizeKey(fresh.name), fresh)
    }
  }
}
// Dispose path: the runtime guard the advisory schema cannot give. A disposition acts on an
// EXISTING entry and only with an in-enum status; an ignored item is logged, never applied.
// Precedence: only the entry's raiser may move it out of `open` — a peer's disposition proposes
// a resolution (recorded in conclusion/evidence) and leaves the status alone.
const applyDispositions = (items, side) => {
  for (const d of Array.isArray(items) ? items : []) {
    if (!d || typeof d.name !== 'string') {
      console.log(`disposition ignored (missing or non-string name) from ${side}`)
      continue
    }
    const entry = register.get(normalizeKey(d.name))
    if (!entry) {
      console.log(`disposition ignored (unresolvable name "${d.name}") from ${side}`)
      continue
    }
    if (d.status !== 'agreed' && d.status !== 'rejected') {
      console.log(`disposition ignored (status outside the enum) for "${d.name}" from ${side}`)
      continue
    }
    if (typeof d.conclusion === 'string' && d.conclusion) entry.conclusion = flatten(d.conclusion)
    if (typeof d.evidence === 'string' && d.evidence) entry.evidence = flatten(d.evidence)
    if (entry.raisedBy !== side) {
      console.log(`disposition recorded as a proposal (raised by ${entry.raisedBy}) for "${d.name}"`)
      continue
    }
    entry.status = d.status
  }
}
let lastDev = null
let lastTest = null
// A grounded ACCEPT: ACCEPT response + no open counters + named grounds (dimensions verified).
const accepted = (v) => !!(
  v && v.response === 'ACCEPT' &&
  Array.isArray(v.counters) && v.counters.length === 0 &&
  Array.isArray(v.accept_grounds) && v.accept_grounds.length > 0
)
// The register carry, rendered from the register's CURRENT state. Declared once and used by both
// the round prompts and the closing half-round, so the closing turn evaluates under byte-identical
// framing to the rounds it concludes (issue #123); it renders no differently than the inline form
// it replaces.
// Agenda partition (issue #127) is a property of the RUN, not of the call — both call sites want
// the same partition on a resume — so it is read from the enclosing `resume` flag rather than from
// a parameter. `renderCarry` therefore keeps its zero-arity declaration line unchanged: that exact
// line is a cross-file anchor, and parameterizing it would red three standing suites at once.
// Cold: every entry, as today. Resume: the open entries as the agenda, then the settled ones under
// SETTLED_BLOCK_RULE as a record — never deleted, since after an ESCALATE the ledger holds no
// record of what the prior run rejected.
const renderSettled = () => {
  if (!resume) return ''
  const settled = renderRegister(register, (e) => e.status !== 'open')
  return settled ? `${SETTLED_BLOCK_RULE}${settled}` : ''
}
const renderCarry = () => register.size ? `${CARRY_NON_EVIDENTIARY} Issue register — address every entry whose status is open before ACCEPT, either by resolving it or by dismissing it with the current section or item that already satisfies it, and return that judgment in "dispositions":\n${renderRegister(register, resume ? (e) => e.status === 'open' : null)}${renderSettled()}` : ''
let consecutiveNull = 0
const MAX_CONSECUTIVE_NULL = 2 // two consecutive both-null rounds => persistent infra failure, not a design split
while (!earlyEscalateReason && round < roundCeiling && !converged) {
  round++
  // Thread the whole register into this round so fresh sub-agents see every issue raised so far
  // with its conclusion and status. Rendering is done HERE, by the script, rather than delegated
  // each round to a context-less fresh agent.
  const carry = renderCarry()
  // Sequential, test first (issue #62). The verification design challenges the feature design,
  // so test-then-dev makes each round a complete challenge-and-response and closes the window
  // in which a citation is written against a snapshot the counterpart is concurrently editing.
  // The `.catch(() => null)` wraps preserve the Draft phase's error semantics — the MISSING
  // path below consumes a null, which a bare `await` would replace with a propagated rejection.
  const test = await Promise.resolve()
    .then(() => agent(
      `You are the Test AI. Round ${round} of ARCHITECT convergence. Read the current ${feature} and ${verif}. Apply the Discussion Protocol.${firstExchange} If the feature design changed testability, UPDATE ${verif} in place. Respond ACCEPT ONLY when every acceptance criterion has a concrete verification method — a stated manual or mock alternative counts, except at a triggered composition contact point, where a mock or manual alternative is not acceptable and an oracle driving the real execution environment is owed — AND ${verif} carries the Verification depth determination, meaning every verification layer and every new spec file names a unique failure mode no other layer catches (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth); a layer that cannot name one is removed rather than argued down — AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds".${ISSUE_AC_COLUMN_RULE} Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${carry}${resumeSeed} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: VERDICT, label: `test-r${round}`, phase: 'Converge', model: 'opus' },
    ))
    .catch(() => null)
  // The Developer AI answers within the SAME round, reading the Test AI's live verdict.
  const peer = test && test.counters && test.counters.length
    ? ` The Test AI has already completed round ${round} against the documents in their current state and returned ${test.response} with these open counters — they are current, not carried: ${JSON.stringify(test.counters)}. Dispose of each in THIS round: resolve it by editing ${feature}, or dismiss it by naming the section or item that already satisfies it.`
    : ''
  const dev = await Promise.resolve()
    .then(() => agent(
      `You are the Developer AI. Round ${round} of ARCHITECT convergence. Read the current ${verif} and ${feature}.${peer} Apply the Discussion Protocol (UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND).${firstExchange} If the verification design exposes a gap in the feature design, UPDATE ${feature} in place. Respond ACCEPT ONLY when both documents are mutually consistent and complete AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${carry}${resumeSeed} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: VERDICT, label: `dev-r${round}`, phase: 'Converge', model: 'opus' },
    ))
    .catch(() => null)
  lastDev = dev
  lastTest = test
  // A round where BOTH sub-agents are null is a MISSING judgment, not a design disagreement.
  // A single transient both-null round retries; two consecutive is a persistent infra failure —
  // exit early (saving up to MAX_ROUNDS-2 rounds of opus spawns) with a distinct reason rather
  // than laundering it into the generic "No mutual ACCEPT" text. A one-side-null round leaves the
  // live side's counters doing real work, so it is NOT aborted (accepted(null) already blocks it).
  const roundMissing = !dev && !test
  consecutiveNull = roundMissing ? consecutiveNull + 1 : 0
  // Bound-aware second disjunct (issue #127): a resume run admits exactly one round, so
  // MAX_CONSECUTIVE_NULL is unreachable there and a both-null resume round would otherwise fall
  // through to the generic "No mutual ACCEPT" text — laundering an infrastructure cause into a
  // design outcome, and spending the operator's decided extra round to say the wrong thing. The
  // rule is stated on the BOUND: a both-null round is a MISSING judgment as soon as no further
  // round can retry it. `consecutiveNull` is per-invocation and is not a register field, so the
  // rendered figure is 1 on the resume path and 2 at the cold threshold — the discriminating half.
  // Scoped to `resume` deliberately: extending it to the cold cap round would alter the escalation
  // text of a run that never asked for it, against this change's cold-path bit-identity criterion.
  if (consecutiveNull >= MAX_CONSECUTIVE_NULL || (resume && roundMissing && round === roundCeiling)) {
    earlyEscalateReason = `${REASON_SUBAGENT_MISSING} for ${consecutiveNull} consecutive round(s)`
    break
  }
  // No agreement on the first exchange (round > 1), and both sides must give a grounded ACCEPT
  // with no open counters (a raised concern is never dropped). A resume round continues a
  // deliberation whose first exchange already happened, so the guard is lifted there (issue #127):
  // without the disjunct, a resume of a run that escalated before completing any round would land
  // at round 1 and be silently forbidden from converging.
  converged = (resume || round > 1) && accepted(dev) && accepted(test)
  // Register update, in the design's stated order: raise first (both sides), then dispose.
  raise(test && test.counters, 'test')
  raise(dev && dev.counters, 'dev')
  applyDispositions(test && test.dispositions, 'test')
  applyDispositions(dev && dev.dispositions, 'dev')
  // Guard site A (issue #127, cycle 3) — resume-scoped open-entry precondition, evaluated HERE
  // because it must read the register AFTER this round's own raise/dispose: the round that resolves
  // its own carried objection is exactly the round that should converge. `converged` itself is
  // cleared, not merely flagged — the Ledger phase computes the verdict from `converged` alone and
  // consults `escalationReason` only on the ESCALATE branch, so a flag-only guard is a no-op.
  openEntryDenied = resume && converged && hasOpenEntry()
  if (openEntryDenied) converged = false
  console.log(`round ${round}: dev=${dev ? dev.response : 'missing'}(${(dev && dev.counters && dev.counters.length) || 0}) test=${test ? test.response : 'missing'}(${(test && test.counters && test.counters.length) || 0})`)
}

// Cap-round closing half-round (issue #123). The loop runs test-then-dev and computes `converged`
// inside the same iteration, so at the cap it exits on a Developer-AI revision no Test-AI turn has
// evaluated: a cap-round resolution could never be recognised as convergence, and the ESCALATE
// grounds carried the Test AI's pre-revision counters. One Test-AI-only evaluation of that final
// revision closes the gap. It is the second half of the sixth exchange, not a seventh: no Dev turn
// is added and `round` is not incremented, so the returned `rounds` stays at the cap.
// The predicate reads `lastDev` only — a null cap-round Test verdict is exactly the case that most
// needs the closing turn, so it must not suppress it. An early-escalate reason (missing draft /
// consecutive null) is an infrastructure cause and is never routed into a design outcome.
// The predicate reads the run's own ceiling (issue #127): on the cold path `roundCeiling` IS
// MAX_ROUNDS, so this is the same expression; on a resume run it gives the single admitted round
// its closing Test-AI evaluation, which is what lets "exactly one round" end in CONVERGED rather
// than being structurally forced to ESCALATE.
if (!earlyEscalateReason && !converged && round === roundCeiling && accepted(lastDev)) {
  // Rendered HERE, after the cap round's own raise/applyDispositions, so the closing turn sees the
  // counters that round raised — the very concerns it exists to re-evaluate. The in-loop value is
  // computed at the top of a round, before its register mutations, and is not reusable for this.
  const closingCarry = renderCarry()
  // Mirror of the in-round `peer` clause: the counterpart's live verdict handed over as current.
  const closingPeer = ` The Developer AI has already completed round ${round} against the documents in their current state and returned a grounded ACCEPT on these verified dimensions — they are current, not carried: ${JSON.stringify((lastDev && lastDev.accept_grounds) || [])}.`
  const closing = await Promise.resolve()
    .then(() => agent(
      `You are the Test AI. This is the CLOSING evaluation of the Developer AI's final revision at the round cap (round ${round} of ${roundCeiling}): there is no further Developer-AI turn, and this verdict alone decides whether the run converges: a grounded ACCEPT converges it and a COUNTER/PARTIAL returns ESCALATE, after which the Reconcile check still decides whether a converged run returns CONVERGED or AC_CHANGE. Read the current ${feature} and ${verif}.${closingPeer} Apply the Discussion Protocol. If the feature design changed testability, UPDATE ${verif} in place. Respond ACCEPT ONLY when every acceptance criterion has a concrete verification method — a stated manual or mock alternative counts, except at a triggered composition contact point, where a mock or manual alternative is not acceptable and an oracle driving the real execution environment is owed — AND ${verif} carries the Verification depth determination, meaning every verification layer and every new spec file names a unique failure mode no other layer catches (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth); a layer that cannot name one is removed rather than argued down — AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds".${ISSUE_AC_COLUMN_RULE} Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${closingCarry}${resumeSeed} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: VERDICT, label: CLOSING_CALL_LABEL, phase: 'Converge', model: 'opus' },
    ))
    .catch(() => null)
  if (!closing) {
    // A missing closing judgment is an infrastructure failure, not a design disagreement.
    earlyEscalateReason = REASON_CLOSING_AGENT_MISSING
  } else {
    // Assign BEFORE the Ledger phase computes `acceptGrounds` from `lastTest`, so a CONVERGED run's
    // Test-side grounds are the closing verdict's, not the cap round's superseded ones.
    lastTest = closing
    converged = accepted(closing)
    // In-loop order (verdict, raise, dispose) applied to the test side alone: the raiser-only close
    // rule is why the missing turn had to be a Test-AI turn rather than an extra Developer-AI one.
    raise(closing.counters, 'test')
    applyDispositions(closing.dispositions, 'test')
    // Guard site B (issue #127, cycle 3) — the same precondition on the closing half-round, which
    // on a resume run IS the path to CONVERGED. Assigned again, superseding site A's decision for
    // the same reason `lastTest = closing` supersedes the cap round's verdict.
    openEntryDenied = resume && converged && hasOpenEntry()
    if (openEntryDenied) converged = false
    console.log(`closing half-round: test=${closing.response}(${(closing.counters && closing.counters.length) || 0})`)
  }
}

// Reconcile (issue #138) — the acceptance-criterion authority checkpoint, placed between Converge
// and Ledger. It runs ONLY when `converged` is true: a run already returning to the operator gains
// nothing from the check, and verdict precedence is ESCALATE before AC_CHANGE before CONVERGED —
// an infrastructure or non-convergence cause still outranks a design outcome, the same ordering
// `escalationReason` already uses. Minting happens here, before the Register phase serializes
// `entries`, so an AC_CHANGE register always carries an open entry and the operator's re-entry is
// not refused by the resume path's `no open entry` guard.
phase('Reconcile')
let acReason = null
let acChange = []
// The artifact whose unreadability caused the pause, used as the ledger grounds' fallback evidence.
let acEvidence = ''
if (converged) {
  const acDiff = await Promise.resolve()
    .then(() => agent(
      `You are a comparison channel, not a reviewer. Read three artifacts and return what they state under the given schema. (1) ${phaseB} — its "## Acceptance criteria" table. Set "ac_source_present" true only when that section exists AND parses as a table; when it does not, set it false and return the other fields as empty arrays. (2) ${verif} — its acceptance-criteria table, whose leading "Issue AC" column carries an AC id or "—". (3) ${ledger} — the issue decision ledger. Return "ac_rows" as ONE ROW PER AC ID in the ${phaseB} table, IN THAT TABLE'S ORDER, omitting none: "ac" is the AC id copied verbatim; "carried" is true when some ${verif} row's "Issue AC" cell equals that id; "disposition" is that carrying row's stated disposition mapped to exactly one of verified / declined / deferred / absent, and is "absent" if and only if "carried" is false; "method_executable" is true when the carrying row's Method cell names a file path, a command, or a manual-scenario file, and false when that cell is empty or "—"; "locator" is the carrying row's name, or "—"; "proposed" is that row's disposition wording copied verbatim. Return "ledger_ac_decisions" by pure grammar match, not by judgment: for each level-2 heading in ${ledger} whose text ends with the marker [ac-decision], copy the value of that entry's "- AC:" line. Copy nothing else into that list — not a paraphrase of a criterion, not a prose mention of an AC id, and not a "- AC:" line under any other marker or under no marker. Return "substituted" for each ${verif} row whose criterion asserts a DIFFERENT property than the ${phaseB} criterion of the same id. Exercise no judgment about whether any difference was justified, and do not decide whether an entry's disposition was appropriate — report presence and kind only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: AC_DIFF, label: 'ac-diff', phase: 'Reconcile', model: 'sonnet' },
    ))
    .catch(() => null)
  // Minting (issue #138): every AC_CHANGE path mints at least one OPEN entry, so the resume the
  // operator takes after ruling on the change is admissible. `raisedBy: 'test'` follows the
  // rehydrate coercion's own stated reason — only the raiser may close an entry, and `test` is the
  // side a resumed round starts on and the side the closing half-round belongs to.
  const mintAcEntry = (name, conclusion, evidence) => {
    raise([{ agenda: name, argument: conclusion, locator: evidence }], 'test')
  }
  if (!acDiffWellFormed(acDiff)) {
    // Null return or malformed payload. Fail-closed: the check could not run, so it did not pass.
    acReason = REASON_AC_RECONCILIATION_UNAVAILABLE
    acEvidence = `${phaseB}, ${verif}, ${ledger}`
    mintAcEntry(AC_ENTRY_RECONCILIATION_UNAVAILABLE, acReason, acEvidence)
  } else if (!acDiff.ac_source_present || acDiff.ac_rows.length === 0) {
    // An empty `ac_rows` set is treated exactly as an absent list, not as "no criteria differ".
    // From the script's side the two are indistinguishable: a channel that read the Phase B table
    // and transcribed nothing looks identical to one that found no table at all, and the second is
    // a silent pass on an unread source. GATE:PLAN's own AC-authority check already caps on an
    // "absent, empty or unparseable" table; Reconcile resolves the same way — fail-closed.
    acReason = REASON_AC_LIST_ABSENT
    acEvidence = phaseB
    mintAcEntry(AC_ENTRY_AC_LIST_ABSENT, acReason, acEvidence)
  } else {
    // The join, in the script. `findings` is script-local; the run observes it through `acChange`,
    // which on an input whose ledger authorizes nothing IS the whole list.
    const findings = []
    for (const row of acDiff.ac_rows) {
      if (!row || typeof row !== 'object') continue
      const kind = acKindOf(row)
      if (!kind) continue
      findings.push({
        ac: flatten(row.ac),
        kind,
        locator: flatten(row.locator) || LOCATOR_UNSPECIFIED,
        proposed: flatten(row.proposed),
      })
    }
    for (const sub of acDiff.substituted) {
      if (!sub || typeof sub !== 'object') continue
      findings.push({
        ac: flatten(sub.ac),
        kind: 'substituted',
        locator: flatten(sub.locator) || LOCATOR_UNSPECIFIED,
        proposed: flatten(sub.proposed),
      })
    }
    // Authority, in the script: exact-after-trim over the transcribed id list. Never a substring
    // and never a prefix — `AC10` must not be authorized by an entry naming `AC1`.
    const decisions = acDiff.ledger_ac_decisions.filter((d) => typeof d === 'string')
    const unauthorized = findings.filter((f) => !decisions.some((d) => d.trim() === f.ac.trim()))
    if (unauthorized.length) {
      acReason = REASON_AC_UNAUTHORIZED_CHANGE
      acEvidence = verif
      acChange = unauthorized
      for (const f of unauthorized) {
        mintAcEntry(`${AC_ENTRY_PREFIX}${f.ac}`, `${f.kind}: ${f.proposed}`, f.locator)
      }
    }
  }
}

phase('Ledger')
const verdict = !converged ? 'ESCALATE' : acReason ? 'AC_CHANGE' : 'CONVERGED'
// Cause-specific escalation reason: an early-exit reason (missing draft / artifact / consecutive
// null) survives verbatim; then the resume open-entry sentinel (issue #127, cycle 3) — ordered
// AFTER `earlyEscalateReason` because an infrastructure cause still outranks a design outcome, and
// BEFORE the generic text because the register, not round exhaustion, is what blocked this run;
// otherwise the generic round-exhaustion text.
const escalationReason = earlyEscalateReason
  || (openEntryDenied ? REASON_RESUME_OPEN_ENTRY_AT_CONVERGENCE : null)
  || `No mutual ACCEPT within ${roundCeiling} rounds (reached round ${round})`
// Only a CONVERGED run records settled decisions under "ARCHITECT mutual ACCEPT".
// A non-convergence run records a single outcome entry under a DISTINCT authority so
// the append-only ledger is never polluted with un-agreed content (which would later
// block legitimate re-deliberation under the "no re-litigation" rule).
const acceptGrounds = converged
  ? [...((lastDev && lastDev.accept_grounds) || []), ...((lastTest && lastTest.accept_grounds) || [])]
  : []
// Cross-session persistence (issue #67). A register lives for one run, so a REJECTED entry is
// written to the append-only ledger under its own authority; the open entries are the ESCALATE
// branch's grounds — every unresolved concern of the run with its conclusion, not just the last
// round's counters. Neither source is ever empty by construction: the ESCALATE branch falls back
// to the escalation reason when no entry is open.
const rejectedEntries = renderRegister(register, (e) => e.status === 'rejected')
const openEntries = renderRegister(register, (e) => e.status === 'open')
const rejectedClause = rejectedEntries
  ? ` Then append one further entry per rejected register issue below — the decision is that the issue is rejected; its grounds are the entry's own four lines; authority "ARCHITECT rejected"; cycle/phase "ARCHITECT":\n${rejectedEntries}`
  : ''
const escalateGrounds = openEntries
  ? `the open register entries below:\n${openEntries}`
  : `the register held no open entry, so the grounds are the escalation reason alone: ${escalationReason}`
// AC_CHANGE grounds (issue #138), built in the shape the non-convergence branch already uses for
// the same asymmetry. Rendering the unauthorized findings alone would leave the grounds EMPTY on
// exactly the two paths where the operator knows least — `acCheckFailed` and `!ac_source_present`
// carry `acChange: []` by construction — so the clause OPENS with the run's sentinel and continues
// with the rendered open register entries (the minted ones exist by construction here, since
// Reconcile mints before the Register phase serializes), falling back to the sentinel plus the
// artifact the check could not read. The invariant: this clause never renders empty and always
// names the run's `acReason` sentinel.
const acChangeGrounds = openEntries
  ? `${acReason}; the open register entries below:\n${openEntries}`
  : `${acReason}, over ${acEvidence}`
// Entry-identifier protocol (CLAUDE.md > Decision Ledger). This workflow cannot allocate the
// identifier itself — the Workflow runtime injects only args/phase/parallel/agent/console, with no
// fs and no exec — so the allocation is instructed in the prompt the ledger sub-agent executes.
// `F` is the facilitator delegate's namespace; per-entry allocation immediately before each append
// is what makes it collision-free against the orchestrator writing `O` entries concurrently.
const ENTRY_ID_RULE = ` Head each appended entry \`## <ID> — <title> (cycle <C>, ARCHITECT)\`, allocating <ID> by running \`bash scripts/ledger/ledger-entry-id.sh next ${ledger} F\` immediately before that entry's own append — one call per entry, never a serial incremented locally across the batch. After the appends, run \`bash scripts/ledger/ledger-entry-id.sh check ${ledger}\` and fix every defect it reports before returning.`
// Three-way (issue #138). The AC_CHANGE branch records NO settled decision, for the reason the
// non-convergence branch already states — an append-only ledger must never carry un-agreed content
// that the no-re-litigation rule would then lock in. Here the content is worse than un-agreed: it
// is exactly what awaits the operator's decision. Its authority literal `ARCHITECT ac-change` sits
// outside LEDGER_SEED_RULE's settled-authority set, so it is never seeded into a later
// deliberation as settled.
const ledgerPrompt = verdict === 'AC_CHANGE'
  ? `Append (do NOT rewrite or delete) to ${ledger} EXACTLY ONE outcome entry — do NOT record any design decision as settled: decision "ARCHITECT paused on an acceptance-criterion change — ${acReason}"; grounds — ${acChangeGrounds}; authority "ARCHITECT ac-change"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only.${ENTRY_ID_RULE} Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
  : converged
  ? `Append (do NOT rewrite or delete) to ${ledger} the settled ARCHITECT decisions. For each agreed design decision, append one entry: the decision (one line); its grounds (cite the verified dimensions ${JSON.stringify(acceptGrounds)} and the artifact path:line in ${feature} or ${verif}); authority "ARCHITECT mutual ACCEPT"; cycle/phase "ARCHITECT".${rejectedClause} If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only — never edit existing entries.${ENTRY_ID_RULE} Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
  : `Append (do NOT rewrite or delete) to ${ledger} EXACTLY ONE outcome entry — do NOT record any design decision as settled: decision "ARCHITECT did not converge — ${escalationReason}"; grounds — ${escalateGrounds}; authority "ARCHITECT non-convergence"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only.${ENTRY_ID_RULE} Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
// Terminal post-verdict call (issue #127): the verdict is already settled before this runs, so a
// failed ledger append degrades to a null acknowledgement instead of propagating and destroying a
// result the deliberation already earned. This call is also the EARLIER of the two terminal calls,
// so a propagated rejection here would additionally prevent the Register phase below from ever
// writing. The full `Promise.resolve().then(...)` form — not a bare `.catch` on the call — is what
// also converts a SYNCHRONOUS throw at the runtime boundary into the rejection `.catch` absorbs.
await Promise.resolve()
  .then(() => agent(ledgerPrompt, { label: 'ledger', phase: 'Ledger', model: 'opus' }))
  .catch(() => null)

// Terminal Register phase (issue #127): persist the register so a later resume can re-enter from
// it instead of cold-restarting. It runs on all three verdicts (CONVERGED / AC_CHANGE / ESCALATE) —
// the `registerHeld` guard below, not the verdict, decides — and writing on the CONVERGED branch is
// load-bearing rather than incidental — the `already converged` resume guard reads this file's own
// `verdict`, so skipping the write here would leave the file saying ESCALATE and let a later
// resume reopen a design the ledger already records under "ARCHITECT mutual ACCEPT".
// The script has no filesystem, so the write is a transcription channel too: the exact bytes are
// built here and the sub-agent is told to write them verbatim between the declared fences.
phase('Register')
let registerWritten = false
if (registerHeld) {
  const registerPayload = JSON.stringify({
    issue,
    lastRound: round,
    verdict,
    // Persisted for the operator's diagnosis; deliberately outside the closed load schema.
    escalation: converged ? null : escalationReason,
    // The AC pause's own carrier (issue #138), beside `escalation` rather than inside it, so a
    // resume reports the same cause the pause did and the two fail-closed causes stay distinct.
    acReason,
    // Every status, not only the open ones: after an ESCALATE the ledger carries no record of what
    // the prior run rejected (`rejectedClause` is interpolated on the CONVERGED branch alone), so
    // open-only persistence would let a resumed sub-agent re-raise a rejected concern with nothing
    // anywhere to point at.
    entries: [...register.values()],
    // Read by the operator, not by any control-flow path: which side stopped short, and on what
    // verdict. Not injected into the resume round prompt — the in-round `peer` clause frames a
    // verdict as current, and a verdict from a prior invocation is not.
    lastResponses: { dev: lastDev, test: lastTest },
  }, null, 2)
  const registerAck = await Promise.resolve()
    .then(() => agent(
      `You are a transcription channel, not an author. Write the text between the two fence markers below to ${registerPath}, byte for byte: no reformatting, no re-indentation, no added or dropped fields, no summarizing, no commentary in the file. Create the file if it does not exist and overwrite it if it does. Write exactly the bytes between the fences and nothing else, and do not write the fence markers themselves. Then return a one-line confirmation.\n${REGISTER_FENCE_START}\n${registerPayload}\n${REGISTER_FENCE_END}\nRun every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { label: 'register-write', phase: 'Register', model: 'sonnet' },
    ))
    .catch(() => null)
  // A failed write does not alter the already-decided verdict: it is absorbed to a null
  // acknowledgement and reported as `registerWritten: false`. The consequence lands on the NEXT
  // resume, which re-enters from the last successfully persisted state — the register an earlier
  // run left behind when one exists; when none exists the resume load guard escalates with
  // REASON_RESUME_REGISTER_ABSENT (zero rounds run), so the operator sees the gap rather than a
  // silent cold restart.
  registerWritten = !!registerAck
}

return {
  phase: 'architect',
  verdict,
  artifacts: [feature, verif],
  ledger,
  // Absolute, not per-invocation: a resume of a run that reached the cap returns the next number,
  // so "how long has this deliberation gone on" stays a single monotone count.
  rounds: round,
  summary: verdict === 'AC_CHANGE'
    ? `ARCHITECT paused on an acceptance-criterion change in ${round} round(s) — operator decision required (${acReason})`
    : converged
    ? `ARCHITECT converged in ${round} round(s)`
    : `ARCHITECT did not converge — escalate (${escalationReason})`,
  escalation: converged ? null : escalationReason,
  resumed: resume,
  register: registerPath,
  registerWritten,
  // Acceptance-criterion authority (issue #138). `acReason` carries the sentinel on AC_CHANGE and
  // is null on every other verdict; `acChange` is [] on every verdict other than AC_CHANGE and
  // carries the unauthorized findings — each with the kind the SCRIPT derived — on it. `escalation`
  // stays null on AC_CHANGE (the run is not escalating for a deliberation cause), which is why the
  // sentinel needs a field of its own.
  acReason,
  acChange,
}
