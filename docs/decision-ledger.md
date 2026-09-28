# Decision Ledger

The per-issue decision ledger, `.autoflow/issue-{N}-ledger.md`: what an entry records, how it is
identified, and the grammar of the entries a decision point produces — the advisor's first judgment
and the operator's override. The ledger's standing constraints —
append-only, no re-litigation without a new verified fact, host ownership, and identifier
allocation and check — are [`CLAUDE.md`](../CLAUDE.md) > Decision Ledger.

## Entries

- Each entry records: the decision (one line), its **grounds** (evidence: a commit SHA with `path:line` for a fact of this tree, a summary line with its command, or — for a provision of a long-lived document — the document, section heading and quoted sentence), its **authority** (what settled it — `ARCHITECT mutual ACCEPT`, `GATE:PLAN PASS (avg 8.2)`, `VERIFY Evaluation-AI arbitration`), and the cycle/phase.
- **The verified-error exception** to the rule that a recorded decision is not re-litigated without a new verified fact ([`CLAUDE.md`](../CLAUDE.md) > Decision Ledger). An entry whose grounds carry an objective contradiction, an arithmetic error or a wrong source may be superseded without a new fact when all three hold: (1) the error is **reproduced by command output** — a command run over the material the entry cites, whose summary line shows the two grounds contradicting each other, the miscalculation, or the cited source absent or saying otherwise; (2) the re-opening is **judged by the decision's original authority** — a gate verdict by a fresh Evaluation AI re-scoring that item, an ARCHITECT conclusion by re-deliberation on a `brief` naming the entry (an ARCHITECT re-entry, consuming that counter, unless the deliberation is still open), an advisor decision by a fresh advisor, an operator decision by the operator — and when that authority cannot say with confidence that the error changes the decision, it asks the advisor ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 3); (3) the superseding entry's grounds record the reproducing command and its summary line in the grounds form above and name the superseded entry's identifier. A change of preference or a re-interpretation of the same material is not an error and stays barred.

**Writers**. The advisor appends its answer to a decision point under the authority `advisor decision`, and it alone writes that authority (*Advisor decisions and operator overrides* below); the facilitator appends the deliberation's agreed conclusions under the authority `ARCHITECT agreed`; the orchestrator appends each gate's verdict after the gate, records a loop-check observation (complaint class, witness, prior-change shape, cycle) on **every** review-response attempt — at DIAGNOSE entry, or at HANDOFF step 6.5 for a thin route that runs no DIAGNOSE — appends the VERIFY detection record (the steps 3/4 outcomes, `verify-detection`-marked — a record, not a decision; see [`phases/verify.md`](phases/verify.md) > *Detection record*) at VERIFY exit, and appends an operator override of an advisor decision when the operator gives one.

## Entry identifier

A settled-decision entry is headed `## <ID> — <title> (cycle <C>, <PHASE>)`, where `<ID>` is a one-letter **writer namespace** followed by a serial that counts within that namespace only. An auto-triggered review-response entry carries its HANDOFF marker in the same grammar: `## O<n> — <title> (cycle <C>, HANDOFF) [review-autofix]` — the marker stays at the end of the heading. Record entries (`verify-detection`, `preflight-local-checks`) are level-3 headings and carry no identifier.

| Writer | Namespace |
|---|---|
| Orchestrator | `O` |
| Facilitator delegate | `F` |
| Advisor | `A` |
| Pre-protocol legacy entries (readable, never issued) | `E` |

This table is the mapping's only documentary home; other documents cite it rather than restate it.

- **Legacy ambiguity**. Entries written before this protocol may already share an identifier; they stay as they are. A citation that resolves to more than one entry is ambiguous. An ambiguous citation is not resolved — it is re-derived. The reader treats the cited decision as **unrecorded** and re-establishes it from its own grounds, instead of picking whichever colliding entry looks intended. The re-derivation is then appended as a new entry that names the ambiguous identifier it supersedes — the append-only rule is satisfied by adding the disambiguating record, never by editing the colliding pair.

## Decision-point entries

**Advisor decisions and operator overrides.** A decision point is answered first by the advisor
([`role-contracts.md`](role-contracts.md) > Advisor): an `A<n>` entry under the authority
`advisor decision`, carrying a `- Record:` line to the advisor's answer file
(`.autoflow/issue-{N}-advisor-<ID>.md`) and the marker and fields its kind requires below. Only the
advisor writes that authority or an `A` heading, and the advisor never writes `operator decision` or
an `O` / `F` / `E` heading — the gate hook denies both
([`role-contracts.md`](role-contracts.md) > Advisor > *Independence*). The operator reviews the
advisor's entries at the retry stage and may override one: the orchestrator — the main session, the
only writer the gate hook admits for an `O` entry or the `operator decision` authority — records the
override as an `O<n>` entry under the authority `operator decision`, with the same marker and fields
and an `- Overrides: A<n>` line. An override supersedes the advisor's entry without a new verified
fact — the operator's authority is the ground, the one supersession the no-re-litigation rule admits
besides the verified-error exception; an advisor never supersedes an operator entry.

**Replacement is explicit.** An entry is never edited to change a decision — the gate hook keeps the
ledger append-only ([`role-contracts.md`](role-contracts.md) > Advisor > *Independence*). A later
entry replaces an earlier one only by naming it: `- Supersedes: <id>` (the same authority, on a new
verified fact or the verified-error exception) or `- Overrides: A<n>` (the operator over the
advisor). Two standing entries on the same subject whose conclusions disagree, with neither naming
the other, are a **conflict**: nothing is settled by recency, and the conflict is resolved by a new
entry — the advisor's, naming the entries it resolves, unless an operator entry is among them, which
only the operator replaces. The same conclusion recorded twice is not a conflict. A `check` defect in
an entry already appended (a duplicate identifier) is likewise resolved by a new entry naming the
defective one, never by editing it.

**Acceptance-criterion decisions** (`[ac-decision]`). Changing an issue's acceptance **content** is
never a deliberation's or a working role's: the **advisor** decides it first and the **operator** may
override at the retry stage ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 1); choosing how a
criterion is *verified* is the deliberation's, provided the row states its reason, which the external
reviewer then judges at HANDOFF (the three-tier guard — [`phases/architect.md`](phases/architect.md) >
*Report routing*). A content change reaches the advisor from wherever it surfaces: an agreed conclusion
of the ARCHITECT deliberation, before GATE:PLAN; a problem a role meets during GREEN, VERIFY or
REFINE and raises in its report; or a gate recommendation that records a criterion defect, or whose
triage hits the acceptance-criterion pause criterion ([`phases/architect.md`](phases/architect.md) > *Report routing*,
[`phases/gate-quality.md`](phases/gate-quality.md) > *Recommendation triage*). The change excludes, revises or splits a criterion, or adds one. The
answer is recorded as one entry per decided AC, in the same trailing-marker grammar:
the heading `## A<n> — <title> (cycle <C>, <PHASE>) [ac-decision]` (an override: `## O<n> — …`),
`<PHASE>` being the phase the change surfaced in, followed by the entry's own `- AC: <ac id>` line (for
an added criterion, the id it takes), a `- Disposition:` line valued `excluded` / `revised` / `split` /
`added`, and the ordinary Decision / Grounds / Authority lines with the authority value
`advisor decision` (an override: `operator decision`).

**A criterion can be wrong; from ARCHITECT on, the work tests it**. DIAGNOSE takes the criteria as written — it
analyzes the problem as the issue states it and runs no test of the criteria of its own. That says how
DIAGNOSE works, not when a defect may be raised: a defect observed as a fact is raised wherever it is
observed, a gate before ARCHITECT included. From ARCHITECT on — the deliberation, GREEN,
VERIFY, REFINE and every gate after them — a criterion is a hypothesis the work tests, not a truth the
work is bent to fit: wherever the work and a criterion disagree, *is the criterion wrong?* is one of the
answers the judgment weighs, beside *how is it satisfied?* A criterion is **defective** when (a) a fact
it presumes does not hold — a device, a phase or a state it takes for granted; or (b) the scope it draws does not fit the problem — too
narrow, when the same cause reaches past what it names, and the question is then whether the issue saw
the problem as local and the approach itself must change, not only whether to include the rest (a
widening: `revised` / `added`); or too wide, when it binds in a problem separate from this issue (a
split: `split` / `excluded`). A defect so judged is raised as a decision point — the advisor first;
it is never resolved by keeping the criterion's letter. One signal of a defect: a document has to add a rule the criterion did
not state in order to keep the criterion's letter. This paragraph is the principle's single home;
the playbooks and agent definitions cite it.

The marker sits at the **end** of the heading. The authority over an acceptance criterion maps to
these literals and nothing else: the entry's authority **value** is `advisor decision` on an `A<n>`
entry or `operator decision` on an `O<n>` entry, and the entry is **located** by the `[ac-decision]`
heading marker. The two gate backstops key on the marker; the ARCHITECT topic's seed sentence names
both authorities as settled. When the entries for one AC disagree, an operator entry wins. When the
disposition is `revised`, `split` or `added`, the Phase B acceptance-criterion table is edited to
match before re-entry, and this entry is the record of who authorized the edit. An `added` entry
covers no difference in either gate backstop: the criterion it adds is owed its verification-design
row and its discharging site like any other.

**Security-checklist decisions** (`[checklist-decision]`). The security checklist AUDIT scores
against is the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist`,
and a cycle's AUDIT reads it as of the cycle's base commit ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 1). Changing it inside a cycle — the file, or the
declaration that points at it — is never the cycle's own to accept: the **advisor** decides first
and the **operator** may override. When `scripts/gate/security-checklist.sh status` reports the
change at AUDIT entry, the orchestrator spawns the advisor, and the answer is recorded in the same
trailing-marker grammar: the heading `## A<n> — <title> (cycle <C>, AUDIT) [checklist-decision]` (an
override: `## O<n> — …`), followed by a `- Checklist:` line (the declared path at HEAD, or `none` when
the declaration is dropped), a `- Blob:` line (the `git rev-parse HEAD:<path>` of the approved
version, or `none`), a `- Disposition:` line valued `accepted` / `rejected`, and the ordinary
Decision / Grounds / Authority lines with the authority value `advisor decision` (an override:
`operator decision`), plus the `- Supersedes:` / `- Overrides:` line when it replaces an entry. The
script counts an entry only when its Decision and Grounds lines are non-empty, its Disposition is
`accepted` or `rejected`, and its Authority matches its namespace (`advisor decision` on `A<n>`,
`operator decision` on `O<n>`), and only while its Checklist and Blob equal HEAD's, so a later edit to
the checklist is a new change owed its own decision. An entry stands unless a later counted entry
replaces it by name (*Replacement is explicit* above; an advisor entry never replaces an operator
entry). The standing entries decide only when they agree: all `accepted` → the change is covered; all
`rejected` → it is not, and the change is reverted before AUDIT; both → a conflict, reported as
`conflict=<ids>` on an undecided (exit `3`) record and resolved by a new entry, never by recency.
