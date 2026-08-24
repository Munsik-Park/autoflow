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
  description: 'Isolated ARCHITECT facilitation: Developer-AI + Test-AI converge on feature + verification design in workflow sub-contexts; returns a single verdict. Invoke with args {issue: "N"} (issue number required), or {issue: "N", resume: "true"} to resume an ESCALATEd deliberation from its persisted register — skipping Draft and admitting one further exchange (two turns); {issue: "N", bounded: "true"} for a scope-bounded review-response cycle (Draft + the config\'s bounded turn ceiling).',
  phases: [
    { title: 'Draft', detail: 'dev drafts feature design, test drafts verification design (independent) — cold runs only' },
    { title: 'Resume', detail: 'load the persisted issue register and re-enter Converge at the prior run\'s turn — resume runs only' },
    { title: 'Converge', detail: 'alternating Test-AI / Developer-AI turns under the Discussion Protocol until two consecutive unmodified accepts or the turn ceiling' },
    { title: 'Reconcile', detail: 'on a converged run, compare the issue acceptance-criterion list against the converged verification design — converged runs only' },
    { title: 'Ledger', detail: 'append the settled decisions (append-only)' },
    { title: 'Register', detail: 'persist the issue register so a later resume can re-enter from it' },
  ],
}

// Turn ceilings are CONFIG values, not literals (issue #152): the cold and bounded ceilings are
// read from .claude/autoflow/spawn-policy.json > deliberation_caps below, so adjusting the cap is
// a one-row config edit. Decision 7's requirement — the loop's bound is in code and every
// invocation carries one — is unchanged: the ceiling is computed per invocation and the loop
// exits on its own bound.
// Stable escalation-reason literals (DCR-3): declared once, shared verbatim by this script
// and the regression test's `escalation`/ledger-prompt assertions so those are not brittle
// to prose rewording. Ported from verify-cause-branch.js's `missing`-sentinel discipline.
const REASON_DRAFT_AGENT_MISSING = 'draft agent missing'
const REASON_SUBAGENT_MISSING = 'sub-agent missing' // full: `${REASON_SUBAGENT_MISSING} for N consecutive turn(s)`
// Resume-path guard sentinels (issue #127), same declare-once discipline. Each is assigned BARE —
// no interpolation, no suffix — so an assertion pins it by equality and a load failure is never
// laundered into the generic round-exhaustion text. One literal per declared guard condition.
const REASON_RESUME_LOAD_AGENT_MISSING = 'resume register load agent missing'
const REASON_RESUME_REGISTER_ABSENT = 'resume register absent'
const REASON_RESUME_ARTIFACT_MISSING = 'resume design artifact missing'
const REASON_RESUME_NO_OPEN_ENTRY = 'resume register has no open entry'
const REASON_RESUME_ALREADY_CONVERGED = 'resume register already converged'
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
// Spawn-policy load sentinels (issue #150), same declare-once, assigned-BARE discipline. The
// per-site model/effort policy is loaded through a transcription channel (there is no filesystem
// here), and a run must never proceed on an unknown policy: degrading to session-inherited models
// is precisely the bypass the single-source policy exists to close. Each cause is distinct so the
// operator sees which half failed, and none is laundered into the generic round-exhaustion text.
const REASON_POLICY_LOAD_AGENT_MISSING = 'spawn policy load agent missing'
const REASON_POLICY_ABSENT = 'spawn policy absent'
const REASON_POLICY_MALFORMED = 'spawn policy malformed'
// Per-row totality sentinels (issue #150, cycle 2). The three causes above decide only that a
// policy arrived and carries a table for this workflow; they say nothing about the rows inside it.
// A required row that is absent or shapeless used to reach `site()`, whose synchronous throw every
// call site converts into a swallowed rejection — so an incomplete policy read as an unreachable
// agent. These two causes are distinct from each other and from the three above, so the operator
// sees which half failed.
const REASON_POLICY_ROW_INCOMPLETE = 'spawn policy row incomplete'
const REASON_POLICY_EFFORT_CONTRACT_UNUSABLE = 'spawn policy effort contract unusable'
// Turn-ceiling config sentinel (issue #152), same discipline. The cold and bounded turn ceilings
// live in the config's `deliberation_caps` table; a run must never proceed on a missing or
// shapeless ceiling — an invented default here would restore the hardcoded literal the config
// exists to replace.
const REASON_POLICY_CAPS_INCOMPLETE = 'spawn policy deliberation caps incomplete'
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
// The mandatory devil's-advocate sentence (issue #127): declared once so the resume path can lift
// it. A resume continues a deliberation that already had its first exchange, so manufacturing a
// further review surface there is exactly the cold-restart cost that path exists to remove.
// Renders on each side's FIRST turn of a cold run (turns 1 and 2), absent on a resume run. It is
// prompt guidance under the Discussion Protocol, not a structural convergence guard (issue #152):
// the termination condition itself does not special-case early turns beyond requiring a
// predecessor turn to pair with.
const FIRST_EXCHANGE_RULE = ' This is your first turn of this deliberation and it is a mandatory devil\'s-advocate review: do NOT return accept: true on this turn.'
// Agenda partition on a resume turn (issue #127). The open entries are the turn's agenda; the
// settled ones are carried under this heading as a record, NOT as work. Declared once — the
// acceptance criterion "loads only prior open items into the round prompt" is assertable as an
// equality against this constant rather than against matchable prose.
const SETTLED_BLOCK_RULE = ' Settled record from the prior run — the entries below were disposed of before this resume and are NOT the agenda for this turn; do not reopen one without a fact verified now that was unavailable when the entry was written:\n'
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
// Bounded admission (issue #135): a review-response cycle whose triage artifact carries
// `scope-bounded: true` runs Draft + the config's bounded turn ceiling instead of the full one.
// The flag is accepted only as a JSON / object argument — deliberately NOT salvaged from prose, so
// the catch-path above stays byte-identical to the harness mirror. Same strictness as `resume`: a
// malformed value fails loud rather than silently running the full cap. The first-turn
// devil's-advocate rule and the resume extension are unchanged; only the cold ceiling differs.
const boundedArg = argv.bounded
const bounded = boundedArg === true || boundedArg === 'true'
const boundedMalformed = ![true, 'true', false, 'false', undefined, null].includes(boundedArg)
// System boundary: reject a missing or malformed required arg loudly rather than proceeding with a
// placeholder path. Kept as the SINGLE throw site — the resume rule extends this guard, it does not
// add a second one.
if (!argv.issue || resumeMalformed || boundedMalformed) {
  throw new Error(!argv.issue
    ? 'architect-deliberation: args.issue is required'
    : resumeMalformed
      ? `architect-deliberation: args.resume must be true, "true", false, "false" or absent (got ${JSON.stringify(resumeArg)})`
      : `architect-deliberation: args.bounded must be true, "true", false, "false" or absent (got ${JSON.stringify(boundedArg)})`)
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
// read only by a resume run. It is what makes re-entry cost one further exchange instead of a cold restart.
const registerPath = `.autoflow/issue-${issue}-architect-register.json`
// Register mechanics (issue #67). Round prompts only: the Draft calls pass no `schema`, so a
// Draft agent has no `dispositions` channel and round 1's register is empty. Declared once and
// interpolated byte-identically into both round prompts. It states disposal in its own words —
// the carry-conditional "by dismissing it with the current" phrasing stays on the carry line,
// which round 1 never receives.
const REGISTER_RULE = ' The issue register carried below is this deliberation\'s record: refer to each entry by its short readable name, never by a serial number, and update an entry in place instead of appending a second one — entries are never renumbered. An entry marked `agreed` or `rejected` is not reopened without a newly verified fact. Dispose of every open entry before you return accept: true: return one item in "dispositions" for each entry you close, naming it and giving it `agreed` or `rejected`. Only the side that raised an entry may close it — a disposition returned by the other side proposes a resolution, which is recorded in the entry\'s conclusion while its status stays open.'
// Ledger seeding (issue #67). Draft prompts only: the register is empty at Draft time, but the
// prior deliberation's ledger is the cross-session half of the no-re-litigation rule, and only a
// Draft agent (which has filesystem access; this script does not) can read it.
// The authority set gains "operator decision" (issue #138): an operator's acceptance-criterion
// ruling is settled by the one authority this deliberation cannot outvote, so a resumed run must
// treat it as closed rather than re-arguing it. "ARCHITECT ac-change" is deliberately NOT in the
// set — that entry records content still awaiting the operator's decision, and seeding un-agreed
// content as settled is precisely what the no-re-litigation rule would then lock in.
const LEDGER_SEED_RULE = ` Read ${ledger} first if it exists: every entry there under authority "ARCHITECT mutual ACCEPT", "ARCHITECT rejected" or "operator decision" is a settled registered issue — treat it as closed and do not re-litigate it unless you can cite a fact verified now, in that source's own reference mode, that was unavailable when the entry was written.`
// The join key the Reconcile phase reads (issue #138). Declared once and interpolated into every
// Test-AI prompt that authors or revises the verification design — the Draft turn, every round
// turn, and the cap-round closing turn — because the column must exist before anything joins on
// it, and the composition-oracle / verification-depth obligations reached the authoring agent
// through these same prompt literals.
const ISSUE_AC_COLUMN_RULE = ` The acceptance-criteria table in ${verif} carries a leading "Issue AC" column: each row's value is either an AC id copied from the "## Acceptance criteria" table in ${phaseB}, or "—" for a criterion this verification design added on its own. Every AC id in that table gets a row, and a criterion you verify by anything other than an automated test keeps its row, states that disposition (existing-coverage / delivery-check / manual / environment-dependent / none) and states its Reason in one line — never drop the row. A design-added criterion ("—") is never a finding and owes no reason.`
// Test necessity (issue #153). Reaches the Test AI at Draft and every turn: the burden of proof
// lies on the test, and the two judgments are answered in the row that carries the verification.
// Policy body: docs/autoflow-guide.md > ARCHITECT > Output artifacts > Test necessity — this
// literal is a pointer plus the operative instruction, not a second home for the policy.
const TEST_NECESSITY_RULE = ' Test necessity (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Test necessity): begin from the issue acceptance criteria and the observable contracts they name, never from an enumeration of failure modes. For each verification you propose, state the required behavior it protects, the concrete cost of its absence (who loses what if this breaks after merge), whether an existing test, lint rule, schema, compiler check or build check already detects it, and why it should outlive this cycle. Prefer the lowest-cost reliable oracle. "none" is a legitimate disposition and is the default when those two judgments cannot both be answered — not writing a test needs no justification. Do not duplicate a literal that already lives in a config or sample file, and do not pin implementation structure (helper names, call order, private branches, internal representations). A test that would imply a new product behavior is a scope question for the operator, not a new obligation you may adopt.'
// Developer-AI counterpart of the same clause: the challenge direction, bounded so it cannot be
// used to strip verification for implementation convenience.
const TEST_NECESSITY_CHALLENGE_RULE = ' Test necessity (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Test necessity): challenge any proposed verification that constrains implementation details without protecting an observable contract. Do not remove verification solely to simplify the implementation; where two proposals give equal confidence, prefer the simpler evidence. Raise a proposed test that implies a new product requirement as a scope question rather than accepting it as an obligation.'
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
// agreement. Closed record, matching the discipline COUNTER and TURN already carry.
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

// The per-turn report (issue #152): two facts decide termination — whether this turn MODIFIED a
// design document, and whether this participant ACCEPTS the current design. No combination is
// restricted: `modified: true, accept: true` is a valid state ("I changed the proposal and I am
// satisfied with the result") that simply cannot terminate, because a modification occurred. The
// remaining fields are the deliberation's record (register + ledger grounds), not termination
// inputs — the retired ACCEPT/COUNTER/PARTIAL verdict enum and the grounded-ACCEPT structural
// requirements were convergence machinery this model no longer needs.
const TURN = {
  type: 'object',
  additionalProperties: false,
  properties: {
    // True iff this turn edited a design document (either one, in any way).
    modified: { type: 'boolean' },
    // True iff this participant accepts the current design as-is.
    accept: { type: 'boolean' },
    // Open concerns this party still has (recorded into the issue register).
    counters: { type: 'array', items: COUNTER },
    // On accept: the dimensions verified + why each passed (Discussion Protocol: an acceptance
    // names the dimensions verified). Feeds the CONVERGED ledger entry's grounds.
    accept_grounds: { type: 'array', items: { type: 'string' } },
    // Judgments on register entries this party is closing. Required, but an empty array is
    // valid — a turn that disposes of nothing returns []. The enum above states the intent;
    // the runtime guard is applyDispositions, since `schema` is opaque to this script.
    dispositions: { type: 'array', items: DISPOSITION },
  },
  required: ['modified', 'accept', 'counters', 'accept_grounds', 'dispositions'],
}

// Register load schema (issue #127). Closed, in the same discipline as COUNTER/DISPOSITION/TURN:
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
    lastTurn: { type: 'number' },
    // Carried so the resume guards can refuse a resume of a run that already converged — the
    // `no open entry` guard cannot make that refusal (a CONVERGED run may still hold open entries).
    // Widened for AC_CHANGE (issue #138) so a persisted AC_CHANGE register LOADS instead of
    // failing its own schema. The `already converged` guard stays keyed to CONVERGED alone, which
    // is what keeps an AC_CHANGE register resumable — the operator's whole re-entry path.
    verdict: { type: 'string', enum: ['CONVERGED', 'AC_CHANGE', 'ESCALATE'] },
    entries: { type: 'array', items: REGISTER_ENTRY },
  },
  required: ['found', 'artifacts_present', 'lastTurn', 'verdict', 'entries'],
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
    // 'reduced' collapses every non-automated disposition the verification-design vocabulary
    // admits — existing-coverage / delivery-check / manual / environment-dependent / none /
    // deferred — because the finding does not turn on WHICH reduction was chosen, only on
    // whether a reason was stated for it (issue #153).
    disposition: { type: 'string', enum: ['automated', 'reduced', 'absent'] },
    // The carrying row's Reason cell is non-empty and not '—'.
    reason_stated: { type: 'boolean' },
    // The carrying row's name, or '—'.
    locator: { type: 'string' },
    // The row's disposition wording, copied verbatim.
    proposed: { type: 'string' },
  },
  required: ['ac', 'carried', 'disposition', 'reason_stated', 'locator', 'proposed'],
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
// The kind table, in the script, first match wins — one finding per row at most. The set is
// narrowed to the states that reach the OPERATOR (issue #153): a reduced verification disposition
// is a verification-method choice the deliberation may make, so it is a finding only when no
// reason was stated for a reviewer to judge. A reasoned reduction passes to the PR body (tier 2,
// the external reviewer) and its reason quality is scored by GATE:PLAN's `Scope` depth items —
// judging a reason is the faculty this channel is forbidden to exercise.
const acKindOf = (row) => {
  if (!row.carried) return 'dropped'
  if (row.disposition === 'reduced' && !row.reason_stated) return 'unreasoned'
  return null
}
// Payload well-formedness. A schema is advisory to this script (it is opaque here, exactly as
// `applyDispositions` is the runtime guard behind DISPOSITION's enum), so a malformed return is
// treated as the channel not having delivered — fail-closed, not fail-open.
// Item level, not only top level: `acKindOf` reads `carried` / `reason_stated` by truthiness
// and matches `disposition` by `===`, so an item that is internally malformed but sits inside a
// top-level-correct payload yields no finding and converges silently. Both item predicates are
// module-local, take one item and return boolean; the required-field lists are not restated,
// since `undefined` fails every per-field clause on its own.
// `ac` is the only field carrying an emptiness clause: it is the identity key the authorization
// join compares after trim, and an empty id converges while naming no criterion. `locator` /
// `proposed` are display values the join already defaults, so emptiness there stays accepted.
// Shared by both item predicates below — `AC_ROW` and `AC_SUBSTITUTION` both carry this trio.
const acCoreFieldsWellFormed = (x) =>
  typeof x.ac === 'string' && x.ac.trim() !== '' &&
  typeof x.locator === 'string' && typeof x.proposed === 'string'
const acRowWellFormed = (row) => !!row && typeof row === 'object' &&
  acCoreFieldsWellFormed(row) &&
  typeof row.carried === 'boolean' &&
  // No separate `typeof === 'string'` clause on `disposition`: the enum is an array of strings,
  // so `includes` rejects every non-string value on its own.
  AC_ROW.properties.disposition.enum.includes(row.disposition) &&
  typeof row.reason_stated === 'boolean' &&
  // One direction of AC_ROW's own stated rule ('absent' iff !carried): `absent` with
  // `carried: true` is an internally inconsistent transcription that `acKindOf` maps to no kind
  // at all. The reverse direction stays accepted on purpose — a `carried: false` row with a
  // non-absent disposition derives `dropped`, an operator pause that names the criterion, and
  // fail-closing it would replace that with a less informative one.
  !(row.disposition === 'absent' && row.carried === true)
const acSubstitutionWellFormed = (sub) => !!sub && typeof sub === 'object' && acCoreFieldsWellFormed(sub)
const acDiffWellFormed = (d) => !!d && typeof d === 'object' &&
  typeof d.ac_source_present === 'boolean' &&
  Array.isArray(d.ac_rows) && Array.isArray(d.ledger_ac_decisions) && Array.isArray(d.substituted) &&
  d.ac_rows.every(acRowWellFormed) && d.substituted.every(acSubstitutionWellFormed)

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
// declared with the register and read by the resume admission guards below. Convergence itself
// never reads it (issue #152): the register is the deliberation's record and the resume agenda,
// not a termination input.
const hasOpenEntry = () => [...register.values()].some((e) => e.status === 'open')
// Rehydration is defensive (issue #127): a loaded entry passes back through the same flatten +
// never-empty defaulting a raised counter does, so the four-labelled-lines-plus-terminator render
// invariant holds whatever the load agent returned. An out-of-enum `status` coerces to `open` (the
// conservative direction — it keeps the concern on the agenda); an out-of-enum `raisedBy` coerces
// to `test`, because applyDispositions lets only the raiser close an entry and an unrecognized
// value would make the entry permanently uncloseable. `test` is the side a resumed run's first
// turn belongs to.
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

// -- Spawn policy load (issue #150) -------------------------------------------
// The per-phase / per-site spawn policy lives in exactly ONE machine-readable
// place, .claude/autoflow/spawn-policy.json, and no `model:` literal remains in
// this file. The Workflow runtime injects no filesystem access and rejects
// `import(` at parse time, so the file arrives through a transcription
// sub-agent -- the same closed-schema channel `register-load` already uses.
//
// This loader is the ONE bootstrap exemption to CLAUDE.md > Spawn Model's
// explicit-`model` rule: it cannot read its own model from the policy it is
// loading, so it omits `model` and inherits the resolved session model (the
// runtime's own documented default). The call is a verbatim file transcription
// under a closed schema, where model tier is not load-bearing. It is also the
// only call in this script that carries no `site()` spread.
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
const policyLoaded = await Promise.resolve()
  .then(() => agent(
    `You are a transcription channel, not a reviewer. Read ${POLICY_PATH} and return its raw contents verbatim in "content" -- do not summarize, reword, add, drop or re-order anything, and do not re-serialize or pretty-print the JSON. Set "found" true only when the file exists AND is non-empty; when it does not, set "found" false and "content" to the empty string. Exercise no judgment about the policy itself. Run every Bash command in the foreground only -- never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { schema: POLICY_FILE, label: 'policy-load', phase: 'Draft' },
  ))
  .catch(() => null)
let policy = null
if (policyLoaded && policyLoaded.found) {
  try { policy = JSON.parse(policyLoaded.content) } catch (_) { policy = null }
}
// The site keys this script spreads, declared once, in a fixed grep-parsable shape: one BARE quoted
// key per line between the two markers, never written in the site-call syntax -- the contract CI extracts
// call-site keys by grepping that syntax over the file OUTSIDE this range, so a declaration written
// in it would be absorbed into the set it is joined against and the join would satisfy itself.
// The three-way equality (declaration = call sites = config rows) lives in
// tests/test-spawn-policy-single-source.sh > required-key-declaration-join.
const REQUIRED_SITE_KEYS = [
  /* site-keys:begin */
  'dev-draft',
  'test-draft',
  'register-load',
  'test-round',
  'dev-round',
  'ac-diff',
  'ledger',
  'register-write',
  /* site-keys:end */
]
// Universally quantified over the DECLARED list, never over the loaded table's own keys: a walk
// over `Object.keys(table)` simply has fewer rows to check on a short table and passes, which is
// the failure this check exists to close. The empty table is the widest instance of the same
// quantifier, so it needs no branch of its own. `effort` must be PRESENT — the config's own
// `effort_contract.absent_means` states that a row carrying no `effort` key is a validation error
// rather than an inherit, and `scripts/spawn-policy/spawn-policy.sh` already rejects it.
// The contract clause is checked here too, and first: `site()` reads
// `effort_contract.config_inherit_sentinel`, so an unusable contract would ship every shipped row's
// `inherit` to the harness as a literal effort value — the same fail-open class, one field over.
// Value ADMISSION is deliberately absent: that is `spawn-policy.sh check`'s job, which reads the
// admitted vocabulary out of the config itself.
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
  // Turn ceilings (issue #152): both ceilings must be integers >= 2 — a ceiling below one full
  // exchange could never converge (termination needs a predecessor turn to pair with), so it is a
  // config defect, not a small budget.
  const caps = p.deliberation_caps && p.deliberation_caps[WORKFLOW_NAME]
  const capOk = (v) => Number.isInteger(v) && v >= 2
  if (!caps || typeof caps !== 'object' || Array.isArray(caps)
      || !capOk(caps.max_turns) || !capOk(caps.bounded_max_turns)) {
    return `${REASON_POLICY_CAPS_INCOMPLETE} (deliberation_caps.${WORKFLOW_NAME})`
  }
  return null
}
// The policy-unusable condition, kept separate from `earlyEscalateReason` at large: the latter is
// also set AFTER Draft on REASON_DRAFT_AGENT_MISSING, where the policy is valid and the terminal
// ledger entry is both writable and wanted.
let policyUnusable = false
if (!policy || !policy.workflow_sites || !policy.workflow_sites[WORKFLOW_NAME]) {
  earlyEscalateReason = !policyLoaded
    ? REASON_POLICY_LOAD_AGENT_MISSING
    : !policyLoaded.found
    ? REASON_POLICY_ABSENT
    : REASON_POLICY_MALFORMED
  policyUnusable = true
} else {
  const defect = policyRowDefect(policy)
  if (defect) {
    earlyEscalateReason = defect
    policyUnusable = true
  }
}

// The site opts helper. Every spawn call site reads its model (and its effort,
// when the row declares an override) from the loaded policy through this one
// resolver, spread into the opts object beside that site's own label / phase /
// schema. An INHERITING row yields an opts object with no `effort` key at all,
// which is exactly how the runtime is documented to inherit -- the config
// sentinel `inherit` is this policy's own vocabulary and is never written to a
// harness channel.
//
// [MUST] The key is a STRING LITERAL at every call site -- never a variable, a
// template string or any computed expression. Contract CI is pure bash + jq
// with no node, so the join between call sites and config rows has no run-time
// oracle: a literal key is what keeps that join decidable by static set
// comparison (tests/test-spawn-policy-single-source.sh > site-key-join).
const site = (key) => {
  const row = policy.workflow_sites[WORKFLOW_NAME][key]
  if (!row || !row.model) throw new Error(`${WORKFLOW_NAME}: no spawn-policy row for workflow site "${key}"`)
  // The inherit sentinel is the value the config's own contract names — one spelling, one home. No
  // fallback literal: a fallback would both restore the copy this removes and ship the sentinel to
  // the harness as a concrete effort value. The load-time clause above is what keeps this read
  // fail-closed, so this line runs only under a contract it has already validated.
  const inheritSentinel = policy.effort_contract.config_inherit_sentinel
  // The sentinel -- and only the sentinel -- means inherit. Every other value the row carries is a
  // concrete effort and reaches the opts unchanged, including an admitted falsy one such as the
  // integer zero. Do not re-add a truthiness conjunct as a null-safety improvement: it would drop
  // that value silently, and row presence is already guaranteed by the load-time contract clause.
  return row.effort !== inheritSentinel
    ? { model: row.model, effort: row.effort }
    : { model: row.model }
}

// The validated turn ceilings (issue #152), null exactly when the policy is unusable — every read
// below runs only on a usable policy (the Draft/Resume branches and the Converge loop are all held
// behind `earlyEscalateReason`).
const caps = policyUnusable ? null : policy.deliberation_caps[WORKFLOW_NAME]

if (earlyEscalateReason) {
  // Fail-closed: neither Draft nor Resume runs on an unknown policy. The
  // terminal escalation below carries the cause verbatim.
} else if (!resume) {
  phase('Draft')
  console.log(`ARCHITECT facilitation for issue #${issue} (ceiling ${bounded ? caps.bounded_max_turns : caps.max_turns} turns${bounded ? ', scope-bounded review-response' : ''})`)

// Independent first drafts — the two perspectives do not see each other's draft yet.
const [devDraft, testDraft] = await parallel([
  () => agent(
    `You are the Developer AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md (issue analysis + plan inputs) and any repo code you need. Author the Feature Design Document — files to change, API interface, data structures, dependencies — and WRITE it to ${feature}. Honor docs/teammate-common-rules.md > Discussion Protocol and docs/submodule-common-rules.md > Change Surface Rules. Return a one-line summary only; the document body goes in the file, not the return.${ADOPTION_EVIDENCE_RULE}${LEDGER_SEED_RULE}${RECORD_DISCIPLINE_RULE} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'dev-draft', phase: 'Draft', ...site('dev-draft') },
  ),
  () => agent(
    `You are the Test AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md and the relevant code. Author the Verification Design Document — each acceptance criterion -> verification type (automated / existing-coverage / delivery-check / manual / environment-dependent / none) -> method -> one-line Reason for every non-automated type, plus the test kind (driving / regression / characterization) on each automated row; testability assessment; design-change requests for untestable items; the composition-oracle determination per docs/autoflow-guide.md > ARCHITECT > Output artifacts > Composition oracle (a non-mock oracle per intersecting shared-state identifier, or an explicit no-intersection declaration); and the Verification depth determination per docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth (a risk line naming who is harmed if this change is wrong, plus one line per verification layer and per new spec file naming the failure mode no other layer catches — a justification form, not a quantity cap) — and WRITE it to ${verif}. Return a one-line summary only.${TEST_NECESSITY_RULE}${ISSUE_AC_COLUMN_RULE}${ADOPTION_EVIDENCE_RULE}${LEDGER_SEED_RULE}${RECORD_DISCIPLINE_RULE} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'test-draft', phase: 'Draft', ...site('test-draft') },
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
      `You are a transcription channel, not a reviewer. Read ${registerPath} and return its contents under the given schema, verbatim — do not summarize, reword, add, drop or re-order anything. Set "found" true only when the file exists AND parses as JSON; when it does not, set "found" false and return the other fields as empty defaults. Set "artifacts_present" true only when BOTH ${feature} and ${verif} exist and are non-empty. Copy "lastTurn", "verdict" and every element of "entries" (name, conclusion, evidence, status, raisedBy) exactly as the file states them. Exercise no judgment about the design itself. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: REGISTER_FILE, label: 'register-load', phase: 'Resume', ...site('register-load') },
    ))
    .catch(() => null)
  // Resume guards, in declared order. Each resolves to its OWN bare sentinel so a load failure is
  // attributable and is never laundered into the generic turn-exhaustion text. A guard failure is
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
    // resume is not the instrument for that — a deliberate refusal, not a degenerate empty turn.
    if (!hasOpenEntry()) earlyEscalateReason = REASON_RESUME_NO_OPEN_ENTRY
    // The refusal the row above cannot make: a run converges on two consecutive unmodified accepts regardless
    // of whether every entry was disposed of, so a CONVERGED run can persist open entries. Resuming
    // there would reopen a design the ledger already records under "ARCHITECT mutual ACCEPT".
    else if (loaded.verdict === 'CONVERGED') earlyEscalateReason = REASON_RESUME_ALREADY_CONVERGED
  }
}

// Register write eligibility (issue #127), evaluated HERE because it is a property of the RUN, not
// a branch of the resume path: a run writes the register only if it ever held a faithful copy of
// it. Both ineligible shapes are exactly the pre-Converge early escalations — a resume that failed
// a load guard (it could not read the file it would overwrite) and a cold run that early-escalates
// on a null draft (its register is empty and `turn` stays 0, so a terminal write would destroy an
// existing register with `{lastTurn: 0, entries: []}`). The second is reachable by the operator's
// most natural action after an ESCALATE, a plain re-invocation, which is why the predicate is
// stated over run shapes rather than over `resume`.
const registerHeld = !earlyEscalateReason

phase('Converge')
// Turn bounds (issue #152). A cold run starts at 0 and is bounded by the config ceiling (the
// bounded ceiling on a scope-bounded run). A resume run continues the PERSISTED turn number —
// never a number taken from an argument — and admits exactly one further exchange (two turns):
// the operator-decided extension. The loop still terminates on its own bound (Decision 7), not on
// a count of resumes taken.
const startTurn = resume && loaded ? (Number(loaded.lastTurn) || 0) : 0
let turn = startTurn
const turnCeiling = resume
  ? startTurn + 2
  : (caps ? (bounded ? caps.bounded_max_turns : caps.max_turns) : 0)
// The mandatory first-turn rule and the cross-session ledger seed are the two run-level switches
// the resume path flips. `firstExchange` renders on each side's first turn of a cold run (turns 1
// and 2) and never on a resume, which continues a deliberation whose first exchange already
// happened.
const firstExchange = (t) => (!resume && t <= 2) ? FIRST_EXCHANGE_RULE : ''
// Draft prompts carry LEDGER_SEED_RULE on the cold path; resume skips Draft outright, so without
// this the cross-session half of the no-re-litigation rule would be silently dropped. Renders the
// empty string on the cold path, leaving those prompts byte-identical.
const resumeSeed = resume ? LEDGER_SEED_RULE : ''
let converged = false
// Raise path: upsert as `open`. A re-raise updates the existing entry in place; `raisedBy` and
// the display `name` are fixed at first creation, so a carried name token is stable across turns.
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
// The termination test (issue #152): this participant accepted the current design WITHOUT
// modifying it. Deliberation converges only when two consecutive turns — one per side — both
// satisfy it; a turn that modified a document can never converge, whatever its `accept` says,
// because the modified design still owes the other side a review.
const agreedWithoutChange = (t) => !!(t && t.accept === true && t.modified === false)
// The register carry, rendered from the register's CURRENT state.
// Agenda partition (issue #127) is a property of the RUN, not of the call, so it is read from the
// enclosing `resume` flag rather than from a parameter.
// Cold: every entry, as today. Resume: the open entries as the agenda, then the settled ones under
// SETTLED_BLOCK_RULE as a record — never deleted, since after an ESCALATE the ledger holds no
// record of what the prior run rejected.
const renderSettled = () => {
  if (!resume) return ''
  const settled = renderRegister(register, (e) => e.status !== 'open')
  return settled ? `${SETTLED_BLOCK_RULE}${settled}` : ''
}
const renderCarry = () => register.size ? `${CARRY_NON_EVIDENTIARY} Issue register — address every entry whose status is open before you return accept: true, either by resolving it or by dismissing it with the current section or item that already satisfies it, and return that judgment in "dispositions":\n${renderRegister(register, resume ? (e) => e.status === 'open' : null)}${renderSettled()}` : ''
let consecutiveNull = 0
const MAX_CONSECUTIVE_NULL = 2 // two consecutive null turns (one per side) => persistent infra failure, not a design split
// The immediately-preceding turn's report — the other half of the termination pair. Starts null on
// BOTH paths (issue #152): a resume does not restore the escalated run's last turn, so its first
// turn is predecessor-less and structurally cannot converge alone — the same rule the cold first
// turn already carries, at the cost of at most one extra turn.
let prevTurn = null
while (!earlyEscalateReason && turn < turnCeiling && !converged) {
  turn++
  // Alternation by parity, Test AI first (issue #62): the verification design challenges the
  // feature design, so a test-then-dev order makes each exchange a complete challenge-and-response.
  // A resume continues the persisted parity, so the alternation is unbroken across invocations.
  const side = turn % 2 === 1 ? 'test' : 'dev'
  // Thread the whole register into this turn so a fresh sub-agent sees every issue raised so far
  // with its conclusion and status. Rendering is done HERE, by the script.
  const carry = renderCarry()
  // The predecessor's live report, handed over as current — including its counters, which THIS
  // turn is asked to dispose of.
  const peerName = side === 'test' ? 'Developer AI' : 'Test AI'
  const peer = prevTurn
    ? ` The ${peerName} completed turn ${turn - 1} against the documents in their current state and returned modified: ${prevTurn.modified}, accept: ${prevTurn.accept}${prevTurn.counters && prevTurn.counters.length ? `, with these open counters — they are current, not carried: ${JSON.stringify(prevTurn.counters)}. Dispose of each in THIS turn: resolve it by editing the design, or dismiss it by naming the section or item that already satisfies it` : ''}.`
    : ''
  // Shared turn-report instruction: `modified` is a fact about THIS turn's edits, never a strategy
  // knob — the design's own rule (issue #152) is that a modification keeps the conversation open,
  // so an improvement is never suppressed to protect convergence.
  const turnReportRule = ` Report two facts about THIS turn: set "modified" true if you edited ${feature} or ${verif} in this turn and false if you made no edit; set "accept" per the condition above. A turn that modified a document continues the deliberation regardless of "accept" — never withhold an improvement to reach convergence, and never report an edit you made as unmodified.`
  // Two call sites, one per side, so each carries its site key as a STRING LITERAL — the [MUST]
  // above site(): contract CI joins call-site keys against config rows by static set comparison,
  // and a computed key would be invisible to that join.
  // The `.catch(() => null)` wrap preserves the Draft phase's error semantics — the MISSING path
  // below consumes a null, which a bare `await` would replace with a propagated rejection.
  const result = await Promise.resolve()
    .then(() => side === 'test'
      ? agent(
          `You are the Test AI. Turn ${turn} of ARCHITECT convergence (ceiling ${turnCeiling} turns).${peer} Read the current ${feature} and ${verif}. Apply the Discussion Protocol.${firstExchange(turn)} If the feature design changed testability, UPDATE ${verif} in place. Set "accept" true ONLY when every acceptance criterion carries a row with a stated disposition — an automated method, or any reduced disposition (existing-coverage / delivery-check / manual / environment-dependent / none) whose Reason cell states in one line why it is the right answer — except at a triggered composition contact point, where a mock or manual alternative is not acceptable and an oracle driving the real execution environment is owed — AND ${verif} carries the Verification depth determination, meaning every verification layer and every new spec file names a unique failure mode no other layer catches (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth); a layer that cannot name one is removed rather than argued down — AND you have no open concerns — then list the dimensions you verified + why each passed in "accept_grounds". Otherwise set "accept" false and list every open concern in "counters".${turnReportRule}${TEST_NECESSITY_RULE}${ISSUE_AC_COLUMN_RULE}${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${carry}${resumeSeed} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
          { schema: TURN, label: `test-t${turn}`, phase: 'Converge', ...site('test-round') },
        )
      : agent(
          `You are the Developer AI. Turn ${turn} of ARCHITECT convergence (ceiling ${turnCeiling} turns).${peer} Read the current ${verif} and ${feature}. Apply the Discussion Protocol (UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND).${firstExchange(turn)} If the verification design exposes a gap in the feature design, UPDATE ${feature} in place. Set "accept" true ONLY when both documents are mutually consistent and complete AND you have no open concerns — then list the dimensions you verified + why each passed in "accept_grounds". Otherwise set "accept" false and list every open concern in "counters".${turnReportRule}${TEST_NECESSITY_CHALLENGE_RULE}${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${carry}${resumeSeed} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
          { schema: TURN, label: `dev-t${turn}`, phase: 'Converge', ...site('dev-round') },
        ))
    .catch(() => null)
  const turnMissing = !result
  consecutiveNull = turnMissing ? consecutiveNull + 1 : 0
  // A null turn is a MISSING judgment, not a design disagreement. One transient null lets the
  // other side's next turn proceed (its predecessor is simply absent, so no convergence pairs
  // across the gap); two consecutive — one per side — is a persistent infra failure, exited early
  // with a distinct reason rather than laundered into the generic no-convergence text. The
  // bound-aware disjunct (issue #127) keeps a resume's final-turn null a MISSING judgment: with no
  // further turn to retry it, falling through would spend the operator's decided extension to say
  // the wrong thing.
  if (consecutiveNull >= MAX_CONSECUTIVE_NULL || (resume && turnMissing && turn === turnCeiling)) {
    earlyEscalateReason = `${REASON_SUBAGENT_MISSING} for ${consecutiveNull} consecutive turn(s)`
    break
  }
  // The termination condition (issue #152), and the whole of it: the previous turn and this turn
  // both accepted the design without modifying it. A null predecessor (run start, or a missing
  // turn) fails the test structurally. No other machinery decides convergence — no verdict
  // history, no register state, no closing evaluation.
  converged = agreedWithoutChange(prevTurn) && agreedWithoutChange(result)
  // Register update, in the design's stated order: raise first, then dispose. Record only —
  // convergence above is already decided.
  raise(result && result.counters, side)
  applyDispositions(result && result.dispositions, side)
  if (side === 'dev') lastDev = result
  else lastTest = result
  console.log(`turn ${turn} (${side}): ${result ? `modified=${result.modified} accept=${result.accept}` : 'missing'}(${(result && result.counters && result.counters.length) || 0})`)
  prevTurn = result
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
      `You are a comparison channel, not a reviewer. Read three artifacts and return what they state under the given schema. (1) ${phaseB} — its "## Acceptance criteria" table. Set "ac_source_present" true only when that section exists AND parses as a table; when it does not, set it false and return the other fields as empty arrays. (2) ${verif} — its acceptance-criteria table, whose leading "Issue AC" column carries an AC id or "—". (3) ${ledger} — the issue decision ledger. Return "ac_rows" as ONE ROW PER AC ID in the ${phaseB} table, IN THAT TABLE'S ORDER, omitting none: "ac" is the AC id copied verbatim; "carried" is true when some ${verif} row's "Issue AC" cell equals that id; "disposition" is that carrying row's stated verification type mapped to exactly one of automated / reduced / absent — "automated" when the row's type is automated, "reduced" for every other stated type (existing-coverage, delivery-check, manual, environment-dependent, none, deferred, or any other non-automated wording), and "absent" if and only if "carried" is false; "reason_stated" is true when the carrying row's Reason cell is non-empty and is not "—", and false otherwise; "locator" is the carrying row's name, or "—"; "proposed" is that row's disposition wording copied verbatim. Return "ledger_ac_decisions" by pure grammar match, not by judgment: for each level-2 heading in ${ledger} whose text ends with the marker [ac-decision], copy the value of that entry's "- AC:" line. Copy nothing else into that list — not a paraphrase of a criterion, not a prose mention of an AC id, and not a "- AC:" line under any other marker or under no marker. Return "substituted" for each ${verif} row whose criterion asserts a DIFFERENT property than the ${phaseB} criterion of the same id. Exercise no judgment about whether any difference was justified, and do not decide whether an entry's disposition was appropriate — report presence and kind only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: AC_DIFF, label: 'ac-diff', phase: 'Reconcile', ...site('ac-diff') },
    ))
    .catch(() => null)
  // Minting (issue #138): every AC_CHANGE path mints at least one OPEN entry, so the resume the
  // operator takes after ruling on the change is admissible. `raisedBy: 'test'` follows the
  // rehydrate coercion's own stated reason — only the raiser may close an entry, and `test` is the
  // side a resumed run's first turn belongs to.
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
// null) survives verbatim; otherwise the generic turn-exhaustion text.
const escalationReason = earlyEscalateReason
  || `No convergence within ${turnCeiling} turns (reached turn ${turn})`
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
// Held under the POLICY-UNUSABLE condition (issue #150, cycle 2), not under `earlyEscalateReason`
// at large: no governed spawn runs under a policy the run has just declared incomplete, whichever
// key is missing — while a valid-policy draft-agent-missing escalation still writes its entry. The
// escalation is not lost: the cause returns in `escalation`, and the ledger is host-owned (CLAUDE.md
// > Decision Ledger — the orchestrator appends the outcome after the phase).
if (!policyUnusable) {
  await Promise.resolve()
    .then(() => agent(ledgerPrompt, { label: 'ledger', phase: 'Ledger', ...site('ledger') }))
    .catch(() => null)
}

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
    lastTurn: turn,
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
    // verdict. Not injected into the resume turn prompt — the in-turn `peer` clause frames a
    // verdict as current, and a verdict from a prior invocation is not.
    lastResponses: { dev: lastDev, test: lastTest },
  }, null, 2)
  const registerAck = await Promise.resolve()
    .then(() => agent(
      `You are a transcription channel, not an author. Write the text between the two fence markers below to ${registerPath}, byte for byte: no reformatting, no re-indentation, no added or dropped fields, no summarizing, no commentary in the file. Create the file if it does not exist and overwrite it if it does. Write exactly the bytes between the fences and nothing else, and do not write the fence markers themselves. Then return a one-line confirmation.\n${REGISTER_FENCE_START}\n${registerPayload}\n${REGISTER_FENCE_END}\nRun every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { label: 'register-write', phase: 'Register', ...site('register-write') },
    ))
    .catch(() => null)
  // A failed write does not alter the already-decided verdict: it is absorbed to a null
  // acknowledgement and reported as `registerWritten: false`. The consequence lands on the NEXT
  // resume, which re-enters from the last successfully persisted state — the register an earlier
  // run left behind when one exists; when none exists the resume load guard escalates with
  // REASON_RESUME_REGISTER_ABSENT (zero turns run), so the operator sees the gap rather than a
  // silent cold restart.
  registerWritten = !!registerAck
}

return {
  phase: 'architect',
  verdict,
  artifacts: [feature, verif],
  ledger,
  // Absolute, not per-invocation: a resume of a run that reached the ceiling returns the next
  // number, so "how long has this deliberation gone on" stays a single monotone count.
  turns: turn,
  summary: verdict === 'AC_CHANGE'
    ? `ARCHITECT paused on an acceptance-criterion change in ${turn} turn(s) — operator decision required (${acReason})`
    : converged
    ? `ARCHITECT converged in ${turn} turn(s)`
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
