# ADR-0017: Teammate removal feasibility — Test AI and Developer AI as anonymous direct spawns

## Status

Accepted

Owner decision, 2026-08-10 (issue #54 thread). The blocking pilot recorded in the Decision
section remains outstanding and can still reverse the verdict.

## Context

AutoFlow spawns two roles as **named team spawns** — Test AI and Developer AI — and every other
role as an **anonymous direct spawn**. The named mode exists for one stated reason: those two roles
are re-entered across phases retaining their prior call's context (`CLAUDE.md` > Spawn mode by role
lifetime). It carries a measured cost: a named spawn's final turn text is discarded by the runtime,
and the #40 cycle lost 3 of 12 reports to that path (`docs/teammate-common-rules.md` > Result
delivery path by spawn mode).

Issue #51 asks whether the two named spawns can be replaced by anonymous direct spawns
(`.claude/agents/autoflow-tester.md`, `.claude/agents/autoflow-implementer.md`), which would remove
the mailbox delivery path entirely. The issue's own `## Goal` caps this cycle at the **verdict and
the migration conditions** — no migration is implemented here. This record is therefore a decision
document in the shape ADR-0016 established for a self-referential change to AutoFlow's own gate and
spawn policy: the decision now, the wiring split to a follow-up implementation slice.

The load-bearing worry the issue raises is that VERIFY step 3 (minimal-implementation check) and
step 4 (mock-boundary fidelity check) lean on what the Test AI remembers about why it wrote each
test, so a context-free spawn would perform both checks silently worse.

### Case collection

**Scope**: the in-repo specification and substrate for the two named roles, at HEAD, plus the
one prior cycle whose report-loss measurement motivates the migration.

**Queries run** (all re-derived at HEAD during ARCHITECT, not carried from the issue body):

- `docs/autoflow-guide.md` VERIFY steps 3 and 4 — their specified inputs.
- `docs/teammate-contracts.md` > Test AI versus `.claude/agents/autoflow-tester.md` — duty-by-duty
  comparison of the contract against the direct-spawn substrate.
- `grep -rn "TeamCreate"` across `*.md`, `*.sh`, `*.js` — one hit, prose in `CLAUDE.md` (one hit outside this ADR — its own Q4 discussion necessarily names the tool).
- `.claude/workflows/architect-deliberation.js` — whether context-free multi-round convergence is
  already demonstrated in-repo.
- `docs/cycle-digest.jsonl` — whether any recorded field reports a step-3 or step-4 detection.

**Result count**: five structural findings, all checkable by inspection; **zero** measurements of
live agent behavior under either spawn mode, because no instrumentation for that exists.

**Go / no-go**: go, conditionally. The structural findings are sufficient to settle that no new
transport mechanism must be invented and that the preconditions are enumerable today; they are not
sufficient to settle how a real context-free agent behaves, which is what the pilot in condition C7
must measure before the migration proceeds.

## Decision

**Migration is possible, conditionally.**

The answer is **derived from the specification, not measured**. The specification describes what a
compliant agent does; the issue's question is what a real agent does, and this cycle has no
measurement of the gap. That is why the pilot is a blocking precondition rather than a recorded
one.

The three findings the verdict rests on:

- The **specified inputs** of VERIFY steps 3 and 4 are durable at HEAD. Step 4 says to re-derive the
  real interface **at HEAD**, explicitly excluding a re-read of the test's own claims; step 3's
  inputs are the implementation diff, the test suite, and the acceptance criteria recorded in
  `.autoflow/issue-{N}-verification-design.md`. None is context-resident.
- The one element that is **not** artifact-guaranteed is step 4's **iteration set** — which doubles
  exist, and which real interface each stands for. It is recoverable from the test tree by grep, but
  no required element of any ARCHITECT output artifact obliges its declaration.
- The real gap is therefore **duty declaration**, not information transport.
  `.claude/agents/autoflow-tester.md` scopes the direct-spawn Test AI to RED plus Green
  re-confirmation; step 3 is declared only in `docs/teammate-contracts.md`, and step 4 in neither.
  Migrating today would silently drop step 4 — the exact loss the issue feared, from a cause the
  issue did not name.

The migration conditions, as an ordered list:

| # | Condition | Verifiable by | Order |
|---|---|---|---|
| C1 | `.claude/agents/autoflow-tester.md` declares VERIFY step 3 and step 4 as Test-AI duties | file inspection | before migration |
| C2 | `docs/teammate-contracts.md` > Test AI names the mock-boundary fidelity check | file inspection | before migration |
| C3 | The agent-definition contract pointer names VERIFY: `.claude/agents/autoflow-tester.md` points at `docs/autoflow-guide.md` > VERIFY, not only > RED | file inspection | before migration |
| C4 | The `SendMessage(to: "team-lead")` obligations in both role contracts are rewritten to the direct-spawn delivery path, not merely deleted | file inspection | before migration |
| C5 | The step-4 iteration set is a declared obligation — which doubles exist, and the real interface each stands for — either as a required element of the verification-design format, or as an explicit duty line in the tester agent definition requiring re-enumeration from the test tree at HEAD | file inspection | before migration |
| C6 | The detection-outcome instrumentation gap is recorded: `gates.gate_quality.items.minimal_implementation` is a GATE:QUALITY rubric score and `regressions.verify` is a regression count that an ordinary test failure also increments, so **no** field records whether VERIFY steps 3 or 4 *detected* anything, and the pilot's comparison needs a recording channel defined in the migration slice | file inspection | before migration |
| C7 | Pilot, blocking: one migrated cycle runs the Test AI as an anonymous direct spawn, and its step-3 and step-4 detection outcomes are compared against the named-spawn baseline | pilot in the migration slice, not executable in this cycle | blocking, at migration |
| C8 | Cost and latency (Q6) measured on the same pilot cycle and recorded | pilot in the migration slice | at migration |

The ordering is itself part of the decision, because reversing it produces a quality loss no gate
catches. The ordering constraint, stated verbatim:
**every precondition C1-C6 is discharged before any spawn-mode change is made**, and the migration
does not proceed past its first migrated cycle until the pilot's detection outcomes are compared
against the named-spawn baseline.

C7 is blocking rather than advisory because the pilot can reverse the verdict: a negative comparison
against the named-spawn baseline reverses this decision, and the correction is then recorded as a
later ADR that supersedes this one.

### Q1

*Do VERIFY steps 3 and 4 depend on context a named Test AI retains across phases?*

**No, on the specification — and this answer is a derivation from spec, not a measurement.**
`docs/autoflow-guide.md` > ARCHITECT > Output artifacts enumerates the verification design's
required elements — the acceptance-criterion to verification-method table, the untestable-item
reason and alternative, the design-change requests, the committed-surface allow-list, and the
composition-oracle determination. Step 3's need is an acceptance-criterion to test mapping
sufficient to attribute each implementation hunk to a test, and element (i) of that enumeration
supplies it by format. Step 4's input is live repository state by its own wording at
`docs/autoflow-guide.md` > VERIFY step 4, which directs a re-derivation of the real interface at HEAD rather
than a re-read of the test's claims.

The exception, stated because it is the one place the answer is not clean:
step 4's **iteration set is not a required element** of any artifact the enumeration names.
It is recoverable from the test tree, but recovery is not declaration, so a fresh spawn's coverage of that set is a property of
its duty declaration rather than of the artifact format. Condition C5 closes it.

### Q2

*Would the two checks silently degrade under a context-free spawn?*

**Today, yes — but from a duty-declaration gap, not from lost context.**
`docs/teammate-contracts.md` > Test AI declares the minimal-implementation check and omits the
mock-boundary fidelity check; `.claude/agents/autoflow-tester.md` declares neither, scoping the
direct-spawn Test AI to RED plus Green re-confirmation. Migrating before C1 and C2 are discharged
would drop step 4 entirely and leave step 3 declared only where the agent definition does not point.
That relocates the precondition from verification-design template enrichment — which would need the
pilot to justify — to agent-definition and contract completion, which is verifiable by inspection.

### Q3

*What becomes of the hook's role-prefix declaration path?*

The recorded decision is to **remove jointly with the migration slice** — not before, and not as a
permanent back-compat path. The prefix branch in `.claude/hooks/check-autoflow-gate.sh` is today the sole declaration
channel for named spawns, so removing it ahead of the migration would deny every Test-AI and
Developer-AI spawn while a cycle is active. Retaining it after the migration would leave an
unreachable branch that still name-prefix-overrides `subagent_type` — dead code with a live
precedence rule attached.

### Q4

*What becomes of `TeamCreate` and the cross-service coordination channel?*

`TeamCreate` has exactly one occurrence in the repository outside this ADR, and it is prose, in `CLAUDE.md`
> Communication — Agent Teams. No script, hook, workflow, or test invokes it. The cross-service
`SendMessage` coordination path is therefore **unexercised in this topology** — a host with zero
submodules. Pruning `TeamCreate` from the contract is admissible in the migration slice, and a
future multi-repo topology re-opens the question through a new ADR rather than by reviving this one.

### Q5

*What becomes of the rules premised on teammates?*

The recorded decision is to **rewrite, not delete**, with the targets enumerated here so the
migration slice has no discovery step: `docs/teammate-common-rules.md` > Result delivery path by spawn mode (the table and the #40
observation), `CLAUDE.md` > Execution Principles (the "final message" prohibition and the
named-spawn non-delivery reading), and the two `SendMessage` obligations in
`docs/teammate-contracts.md` > Test AI and > Submodule AI. Deleting the #40 record would erase the
measurement that justifies the migration in the first place.

### Q6

*What does the migration cost in tokens and latency?*

This is **not measured in this cycle**, and no direction is asserted. No instrumentation exists for either
spawn mode: `docs/cycle-digest.jsonl` records gate scores and regression counts, and nothing in it
reports the resource cost of a spawn. Fabricating a direction would be an ungrounded claim, so the
question is deferred to the pilot cycle as condition C8, which measures it on the same migrated
cycle that measures the detection outcomes. See also `docs/autoflow-guide.md` and issue #51 for the
scope fence that keeps this cycle from producing the measurement itself.

## Alternatives Considered

- **Record the decision as a `docs/design-rationale.md` Decision entry instead of an ADR.**
  Rejected: that file records why existing rules exist, while this decides a future change, and
  `docs/adr/README.md` names agent workflow gates and evaluation policy as an ADR trigger.
- **An archive-incidence corpus audit over `~/.autoflow-archive`, correlating prior verification
  designs against a real-interface anchor predicate, as empirical corroboration for Q1.**
  This alternative was **considered and rejected**, on three grounds re-derived independently: the
  anchor predicate fires on
  every audited document, making it non-discriminating — it measures nothing, so it corroborates
  nothing; the corpus is one project under two renamed keys with disjoint issue sets, not two
  independent projects; and this repository contributes zero documents to it, because `.autoflow/*`
  is gitignored scratch. Dropping it removes no measurement, which is precisely why the pilot in C7
  is blocking rather than advisory.
- **Implement the migration in this cycle.** Rejected as out of the issue's stated scope: the
  deliverable is the verdict and the conditions, and the preconditions C1-C6 are themselves edits to
  the files this cycle fences off.

## Consequences

### Positive

- The migration's preconditions are enumerable and inspectable today, so the follow-up slice starts
  with a checklist rather than a discovery phase.
- Two real defects are recorded independently of whether the migration proceeds: the missing
  VERIFY-pointer in `.claude/agents/autoflow-tester.md`, and the undeclared step-4 iteration set.
- The detection-outcome instrumentation gap is named at the record, so a reviewer who greps
  `minimal_implementation` or `regressions.verify` cannot read C6 as already discharged.

### Negative

- Q1's answer rests on a single leg — a derivation from the specification — with no empirical
  support, which is why C7 blocks rather than advises.
- The cost question stays open, so the migration cannot be justified on efficiency grounds until the
  pilot measures it.

### Neutral / Trade-Offs

- This cycle defers every migration-slice edit; no gate hook, role contract, agent definition,
  workflow script, or governing doc is modified by this record, so the conditions are stated where
  they cannot yet be enforced.
- If the pilot reverses the verdict, supersession replaces this record with a later ADR rather than
  rewriting this body, so this record continues to state what ADR-0017 decided, which stays true of a
  superseded record.

## Related Issues / PRs

- Issue #51 — the feasibility question this record answers.
- Issue #40 — the cycle whose report-loss measurement motivates the migration.
- ADR-0016 (`docs/adr/0016-adr-conformance-gate-scoring.md`) — the precedent for recording a
  self-referential AutoFlow policy decision as an ADR and splitting the wiring to a follow-up.
- ADR-0003 (`docs/adr/0003-autoflow-ends-at-handoff.md`) — the record that the owner, not AutoFlow,
  holds the authority this ADR's `## Status` transition belongs to.

## Notes

- The `Proposed` to `Accepted` transition is the owner's decision, delegated per
  `docs/adr/README.md` > Status Values. No automated check in this cycle obstructs it.
- The condition identifiers C1 through C8 are stable and are referenced by the migration slice; a
  later cycle adding a condition appends rather than renumbers.
