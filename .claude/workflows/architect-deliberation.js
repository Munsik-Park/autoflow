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
const REASON_SUBAGENT_MISSING = 'sub-agent missing' // full: `${REASON_SUBAGENT_MISSING} for N consecutive round(s)`
// The cap-round closing half-round's own sentinels (issue #123), in the same declare-once
// discipline. The reason is assigned BARE — no interpolation, no suffix — so an assertion can
// pin it by equality; it is a MISSING-judgment cause and must not be laundered into the generic
// round-exhaustion text. The label is distinct from every `<side>-r<N>` round label (no digit run
// after `-r`), so a consumer partitioning calls by the round-label shape keeps counting rounds.
const REASON_CLOSING_AGENT_MISSING = 'closing agent missing'
const CLOSING_CALL_LABEL = 'test-closing'
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
        return issue ? { issue } : {}
      }
    })()
  : (args || {})
// System boundary: reject a missing required arg loudly rather than proceeding with a placeholder path.
if (!argv.issue) throw new Error('architect-deliberation: args.issue is required')
const issue = argv.issue
const feature = `.autoflow/issue-${issue}-feature-design.md`
const verif = `.autoflow/issue-${issue}-verification-design.md`
const ledger = `.autoflow/issue-${issue}-ledger.md`
// Register mechanics (issue #67). Round prompts only: the Draft calls pass no `schema`, so a
// Draft agent has no `dispositions` channel and round 1's register is empty. Declared once and
// interpolated byte-identically into both round prompts. It states disposal in its own words —
// the carry-conditional "by dismissing it with the current" phrasing stays on the carry line,
// which round 1 never receives.
const REGISTER_RULE = ' The issue register carried below is this deliberation\'s record: refer to each entry by its short readable name, never by a serial number, and update an entry in place instead of appending a second one — entries are never renumbered. An entry marked `agreed` or `rejected` is not reopened without a newly verified fact. Dispose of every open entry before you ACCEPT: return one item in "dispositions" for each entry you close, naming it and giving it `agreed` or `rejected`. Only the side that raised an entry may close it — a disposition returned by the other side proposes a resolution, which is recorded in the entry\'s conclusion while its status stays open.'
// Ledger seeding (issue #67). Draft prompts only: the register is empty at Draft time, but the
// prior deliberation's ledger is the cross-session half of the no-re-litigation rule, and only a
// Draft agent (which has filesystem access; this script does not) can read it.
const LEDGER_SEED_RULE = ` Read ${ledger} first if it exists: every entry there under authority "ARCHITECT mutual ACCEPT" or "ARCHITECT rejected" is a settled registered issue — treat it as closed and do not re-litigate it unless you can cite a fact verified now, in that source's own reference mode, that was unavailable when the entry was written.`
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

phase('Draft')
console.log(`ARCHITECT facilitation for issue #${issue} (cap ${MAX_ROUNDS} rounds)`)

// Independent first drafts — the two perspectives do not see each other's draft yet.
const [devDraft, testDraft] = await parallel([
  () => agent(
    `You are the Developer AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md (issue analysis + plan inputs) and any repo code you need. Author the Feature Design Document — files to change, API interface, data structures, dependencies — and WRITE it to ${feature}. Honor docs/teammate-common-rules.md > Discussion Protocol and docs/submodule-common-rules.md > Change Surface Rules. Return a one-line summary only; the document body goes in the file, not the return.${ADOPTION_EVIDENCE_RULE}${LEDGER_SEED_RULE}${RECORD_DISCIPLINE_RULE} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'dev-draft', phase: 'Draft', model: 'opus' },
  ),
  () => agent(
    `You are the Test AI in AutoFlow ARCHITECT. Read .autoflow/issue-${issue}-*.md and the relevant code. Author the Verification Design Document — each acceptance criterion -> verification type (automated / manual / environment-dependent) -> method; testability assessment; design-change requests for untestable items; the composition-oracle determination per docs/autoflow-guide.md > ARCHITECT > Output artifacts > Composition oracle (a non-mock oracle per intersecting shared-state identifier, or an explicit no-intersection declaration); and the Verification depth determination per docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth (a risk line naming who is harmed if this change is wrong, plus one line per verification layer and per new spec file naming the failure mode no other layer catches — a justification form, not a quantity cap) — and WRITE it to ${verif}. Return a one-line summary only.${ADOPTION_EVIDENCE_RULE}${LEDGER_SEED_RULE}${RECORD_DISCIPLINE_RULE} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
    { label: 'test-draft', phase: 'Draft', model: 'opus' },
  ),
])

// A null draft return is a skipped/errored sub-agent — the ARCHITECT analogue of VERIFY's
// `test ? test.verdict : 'missing'`. Record it as a distinct early-ESCALATE reason and skip
// Converge entirely, so the terminal `escalation` string stays truthful about the cause.
let earlyEscalateReason = null
if (!devDraft) earlyEscalateReason = `${REASON_DRAFT_AGENT_MISSING} (dev-draft returned null)`
else if (!testDraft) earlyEscalateReason = `${REASON_DRAFT_AGENT_MISSING} (test-draft returned null)`

// Artifact existence is NOT checked here. The Workflow runtime rejects `import(` at
// parse time (`SyntaxError: import() is not available in workflow scripts`) and injects
// no filesystem access, so a script-side check makes this file unlaunchable rather than
// degrading. The check lives with the orchestrator, which has a shell: see
// docs/autoflow-guide.md > ARCHITECT. Do not re-add `import(` to this file — issue #62.

phase('Converge')
let round = 0
let converged = false
// The issue register (issue #67): an insertion-ordered map keyed by the normalized concern name,
// holding EVERY entry raised in the run — open, agreed and rejected alike. Unlike the retired
// `openCounters`, it is never reassigned, so a disposed entry stays visible and the
// no-re-litigation rule has something to point at.
const register = new Map()
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
const renderCarry = () => register.size ? `${CARRY_NON_EVIDENTIARY} Issue register — address every entry whose status is open before ACCEPT, either by resolving it or by dismissing it with the current section or item that already satisfies it, and return that judgment in "dispositions":\n${renderRegister(register)}` : ''
let consecutiveNull = 0
const MAX_CONSECUTIVE_NULL = 2 // two consecutive both-null rounds => persistent infra failure, not a design split
while (!earlyEscalateReason && round < MAX_ROUNDS && !converged) {
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
      `You are the Test AI. Round ${round} of ARCHITECT convergence. Read the current ${feature} and ${verif}. Apply the Discussion Protocol. Round 1 is a mandatory devil's-advocate review: do NOT ACCEPT on round 1. If the feature design changed testability, UPDATE ${verif} in place. Respond ACCEPT ONLY when every acceptance criterion has a concrete verification method — a stated manual or mock alternative counts, except at a triggered composition contact point, where a mock or manual alternative is not acceptable and an oracle driving the real execution environment is owed — AND ${verif} carries the Verification depth determination, meaning every verification layer and every new spec file names a unique failure mode no other layer catches (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth); a layer that cannot name one is removed rather than argued down — AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${carry} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
      { schema: VERDICT, label: `test-r${round}`, phase: 'Converge', model: 'opus' },
    ))
    .catch(() => null)
  // The Developer AI answers within the SAME round, reading the Test AI's live verdict.
  const peer = test && test.counters && test.counters.length
    ? ` The Test AI has already completed round ${round} against the documents in their current state and returned ${test.response} with these open counters — they are current, not carried: ${JSON.stringify(test.counters)}. Dispose of each in THIS round: resolve it by editing ${feature}, or dismiss it by naming the section or item that already satisfies it.`
    : ''
  const dev = await Promise.resolve()
    .then(() => agent(
      `You are the Developer AI. Round ${round} of ARCHITECT convergence. Read the current ${verif} and ${feature}.${peer} Apply the Discussion Protocol (UNDERSTAND -> VERIFY -> EVALUATE -> RESPOND). Round 1 is a mandatory devil's-advocate review: do NOT ACCEPT on round 1. If the verification design exposes a gap in the feature design, UPDATE ${feature} in place. Respond ACCEPT ONLY when both documents are mutually consistent and complete AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${carry} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
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
  if (consecutiveNull >= MAX_CONSECUTIVE_NULL) {
    earlyEscalateReason = `${REASON_SUBAGENT_MISSING} for ${consecutiveNull} consecutive round(s)`
    break
  }
  // No agreement on the first exchange (round > 1), and both sides must give a grounded ACCEPT
  // with no open counters (a raised concern is never dropped).
  converged = round > 1 && accepted(dev) && accepted(test)
  // Register update, in the design's stated order: raise first (both sides), then dispose.
  raise(test && test.counters, 'test')
  raise(dev && dev.counters, 'dev')
  applyDispositions(test && test.dispositions, 'test')
  applyDispositions(dev && dev.dispositions, 'dev')
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
if (!earlyEscalateReason && !converged && round === MAX_ROUNDS && accepted(lastDev)) {
  // Rendered HERE, after the cap round's own raise/applyDispositions, so the closing turn sees the
  // counters that round raised — the very concerns it exists to re-evaluate. The in-loop value is
  // computed at the top of a round, before its register mutations, and is not reusable for this.
  const closingCarry = renderCarry()
  // Mirror of the in-round `peer` clause: the counterpart's live verdict handed over as current.
  const closingPeer = ` The Developer AI has already completed round ${round} against the documents in their current state and returned a grounded ACCEPT on these verified dimensions — they are current, not carried: ${JSON.stringify((lastDev && lastDev.accept_grounds) || [])}.`
  const closing = await Promise.resolve()
    .then(() => agent(
      `You are the Test AI. This is the CLOSING evaluation of the Developer AI's final revision at the round cap (round ${round} of ${MAX_ROUNDS}): there is no further Developer-AI turn, and this verdict alone decides CONVERGED versus ESCALATE. Read the current ${feature} and ${verif}.${closingPeer} Apply the Discussion Protocol. If the feature design changed testability, UPDATE ${verif} in place. Respond ACCEPT ONLY when every acceptance criterion has a concrete verification method — a stated manual or mock alternative counts, except at a triggered composition contact point, where a mock or manual alternative is not acceptable and an oracle driving the real execution environment is owed — AND ${verif} carries the Verification depth determination, meaning every verification layer and every new spec file names a unique failure mode no other layer catches (docs/autoflow-guide.md > ARCHITECT > Output artifacts > Verification depth); a layer that cannot name one is removed rather than argued down — AND you have no open concerns — then return empty "counters" and list the dimensions you verified + why each passed in "accept_grounds". Otherwise return COUNTER/PARTIAL, list every open concern in "counters", and leave "accept_grounds" empty.${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}${closingCarry} Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`,
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
    console.log(`closing half-round: test=${closing.response}(${(closing.counters && closing.counters.length) || 0})`)
  }
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
// Entry-identifier protocol (CLAUDE.md > Decision Ledger). This workflow cannot allocate the
// identifier itself — the Workflow runtime injects only args/phase/parallel/agent/console, with no
// fs and no exec — so the allocation is instructed in the prompt the ledger sub-agent executes.
// `F` is the facilitator delegate's namespace; per-entry allocation immediately before each append
// is what makes it collision-free against the orchestrator writing `O` entries concurrently.
const ENTRY_ID_RULE = ` Head each appended entry \`## <ID> — <title> (cycle <C>, ARCHITECT)\`, allocating <ID> by running \`bash scripts/ledger/ledger-entry-id.sh next ${ledger} F\` immediately before that entry's own append — one call per entry, never a serial incremented locally across the batch. After the appends, run \`bash scripts/ledger/ledger-entry-id.sh check ${ledger}\` and fix every defect it reports before returning.`
const ledgerPrompt = converged
  ? `Append (do NOT rewrite or delete) to ${ledger} the settled ARCHITECT decisions. For each agreed design decision, append one entry: the decision (one line); its grounds (cite the verified dimensions ${JSON.stringify(acceptGrounds)} and the artifact path:line in ${feature} or ${verif}); authority "ARCHITECT mutual ACCEPT"; cycle/phase "ARCHITECT".${rejectedClause} If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only — never edit existing entries.${ENTRY_ID_RULE} Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
  : `Append (do NOT rewrite or delete) to ${ledger} EXACTLY ONE outcome entry — do NOT record any design decision as settled: decision "ARCHITECT did not converge — ${escalationReason}"; grounds — ${escalateGrounds}; authority "ARCHITECT non-convergence"; cycle/phase "ARCHITECT". If ${ledger} does not exist, create it with a "# Decision Ledger — issue #${issue}" header first. Append-only.${ENTRY_ID_RULE} Return a one-line summary only. Run every Bash command in the foreground only — never run_in_background (see docs/teammate-common-rules.md > Bash Execution Mode).`
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
