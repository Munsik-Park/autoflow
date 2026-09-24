# Decision Ledger

The per-issue decision ledger, `.autoflow/issue-{N}-ledger.md`: what an entry records, how it is
identified, and the grammar of the operator-decision entries. The ledger's standing constraints —
append-only, no re-litigation without a new verified fact, host ownership, and identifier
allocation and check — are [`CLAUDE.md`](../CLAUDE.md) > Decision Ledger.

## Entries

- Each entry records: the decision (one line), its **grounds** (evidence: a commit SHA with `path:line` for a fact of this tree, a summary line with its command, or — for a provision of a long-lived document — the document, section heading and quoted sentence), its **authority** (what settled it — `ARCHITECT mutual ACCEPT`, `GATE:PLAN PASS (avg 8.2)`, `VERIFY Evaluation-AI arbitration`), and the cycle/phase.
- **The verified-error exception** to the rule that a recorded decision is not re-litigated without a new verified fact ([`CLAUDE.md`](../CLAUDE.md) > Decision Ledger). An entry whose grounds carry an objective contradiction, an arithmetic error or a wrong source may be superseded without a new fact when all three hold: (1) the error is **reproduced by command output** — a command run over the material the entry cites, whose summary line shows the two grounds contradicting each other, the miscalculation, or the cited source absent or saying otherwise; (2) the re-opening is **judged by the decision's original authority** — a gate verdict by a fresh Evaluation AI re-scoring that item, an ARCHITECT conclusion by re-deliberation on a `brief` naming the entry (an ARCHITECT re-entry, consuming that counter, unless the deliberation is still open), an operator decision by the operator — and when that authority cannot say with confidence that the error changes the decision, it asks the operator ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 3); (3) the superseding entry's grounds record the reproducing command and its summary line in the grounds form above and name the superseded entry's identifier. A change of preference or a re-interpretation of the same material is not an error and stays barred.

**Writers**. The facilitator appends the deliberation's agreed conclusions under the authority `ARCHITECT agreed`; the orchestrator appends each gate's verdict after the gate, records a loop-check observation (complaint class, witness, prior-change shape, cycle) on **every** review-response attempt — at DIAGNOSE entry, or at HANDOFF step 6.5 for a thin route that runs no DIAGNOSE — appends the VERIFY detection record (the steps 3/4 outcomes, `verify-detection`-marked — a record, not a decision; see [`phases/verify.md`](phases/verify.md) > *Detection record*) at VERIFY exit, and — when a match pauses for the user — appends the user's re-entry decision as a separate entry after they answer.

## Entry identifier

A settled-decision entry is headed `## <ID> — <title> (cycle <C>, <PHASE>)`, where `<ID>` is a one-letter **writer namespace** followed by a serial that counts within that namespace only. An auto-triggered review-response entry carries its HANDOFF marker in the same grammar: `## O<n> — <title> (cycle <C>, HANDOFF) [review-autofix]` — the marker stays at the end of the heading. Record entries (`verify-detection`, `preflight-local-checks`) are level-3 headings and carry no identifier.

| Writer | Namespace |
|---|---|
| Orchestrator | `O` |
| Facilitator delegate | `F` |
| Pre-protocol legacy entries (readable, never issued) | `E` |

This table is the mapping's only documentary home; other documents cite it rather than restate it.

- **Legacy ambiguity**. Entries written before this protocol may already share an identifier; they stay as they are. A citation that resolves to more than one entry is ambiguous. An ambiguous citation is not resolved — it is re-derived. The reader treats the cited decision as **unrecorded** and re-establishes it from its own grounds, instead of picking whichever colliding entry looks intended. The re-derivation is then appended as a new entry that names the ambiguous identifier it supersedes — the append-only rule is satisfied by adding the disambiguating record, never by editing the colliding pair.

## Operator decisions

**Acceptance-criterion decisions** (`[ac-decision]`). Changing an issue's acceptance **content** is the
**operator's** authority, never a deliberation's; choosing how a criterion is *verified* is the
deliberation's, provided the row states its reason, which the external reviewer then judges at
HANDOFF (the three-tier guard — [`phases/architect.md`](phases/architect.md) >
*Report routing*). A content change reaches the operator from wherever it surfaces: an agreed conclusion of
the ARCHITECT deliberation, presented before GATE:PLAN; a problem a role meets during GREEN, VERIFY or
REFINE and raises in its report; or a gate recommendation that records a criterion defect, or whose
triage hits the acceptance-criterion pause criterion ([`phases/architect.md`](phases/architect.md) > *Report routing*,
[`phases/gate-quality.md`](phases/gate-quality.md) > *Recommendation triage*). The change excludes, revises or splits a criterion, or adds one. The
orchestrator presents it to the operator, and the operator's answer is recorded as one entry per
decided AC, in the same trailing-marker grammar:
the heading `## O<n> — <title> (cycle <C>, <PHASE>) [ac-decision]`, `<PHASE>` being the phase the
change surfaced in, followed by the entry's own `- AC: <ac id>` line (for an added criterion, the id it
takes), a `- Disposition:` line valued `excluded` / `revised` / `split` / `added`, and the ordinary
Decision / Grounds / Authority lines with the authority value `operator decision`.

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
split: `split` / `excluded`). A defect so judged is raised for the operator; it is never resolved by
keeping the criterion's letter. One signal of a defect: a document has to add a rule the criterion did
not state in order to keep the criterion's letter. This paragraph is the principle's single home;
the playbooks and agent definitions cite it.

The marker sits at the **end** of the heading. The operator's authority over an acceptance
criterion maps to exactly two literals and nothing else: the entry's authority **value**
is `operator decision`, and the entry is **located** by the `[ac-decision]` heading marker. The
two gate backstops key on the marker; the ARCHITECT topic's seed sentence names `operator decision`
as settled. When the
disposition is `revised`, `split` or `added`, the Phase B acceptance-criterion table is edited to
match before re-entry, and this entry is the record of who authorized the edit. An `added` entry
covers no difference in either gate backstop: the criterion it adds is owed its verification-design
row and its discharging site like any other.

**Security-checklist decisions** (`[checklist-decision]`). The security checklist AUDIT scores
against is the target's own, declared at `.claude/autoflow.local.json` > `audit.security_checklist`,
and a cycle's AUDIT reads it as of the cycle's base commit ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principle 1). Changing it inside a cycle — the file, or the
declaration that points at it — is the **operator's** authority. When
`scripts/gate/security-checklist.sh status` reports the change at AUDIT entry, the orchestrator
presents it to the operator, and the answer is recorded in the same trailing-marker grammar: the
heading `## O<n> — <title> (cycle <C>, AUDIT) [checklist-decision]`, followed by a `- Checklist:` line
(the declared path at HEAD, or `none` when the declaration is dropped), a `- Blob:` line (the
`git rev-parse HEAD:<path>` of the approved version, or `none`), a `- Disposition:` line valued
`accepted` / `rejected`, and the ordinary Decision / Grounds / Authority lines with the authority value
`operator decision`. The script counts an entry only when it is `accepted`, its Decision and
Grounds lines are non-empty and its Authority is `operator decision`, and only while its Checklist
and Blob equal HEAD's, so a later edit to the checklist is a new change owed its own decision; a
`rejected` entry records the answer, and the change is reverted before AUDIT.
