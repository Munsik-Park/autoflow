# ADR-0018: Verification depth is governed by a per-layer justification, not a quantity cap

## Status

Proposed

## Context

ARCHITECT's verification-design obligations govern *what* is verified and *how* — coverage,
method, consistency, and (since ADR-0016's sibling cycle) a composition oracle at shared-state
contact points. Nothing governs *how deep*.

Re-derived at HEAD during ARCHITECT for issue #69:

- The Output-artifacts obligations, the composition-oracle clause and the Agreement criteria in
  `docs/autoflow-guide.md` > ARCHITECT contain no depth criterion. The composition-oracle clause is
  a **floor** — it mandates one real-environment oracle per intersecting shared-state identifier —
  never a justification requirement on layers added beyond it.
- On the scored side, GATE:PLAN's `Scope` row already names over-engineering ("no redundant new
  mechanism where an extension suffices"), but the paragraph that interprets it casts the concern
  entirely as a *feature-design* one ("a plan that duplicates an existing mechanism…").

The asymmetry is the defect: under-verification is penalised, over-verification is not. A
verification design may add layers and spec files that duplicate an existing layer's coverage, and
no gate has a stated basis to dock it.

## Decision

1. **Justification form, not a quantity cap.** Verification depth is governed by three obligations
   authored into the verification design, recorded as `#### Verification depth` under
   `docs/autoflow-guide.md` > ARCHITECT > Output artifacts:
   - a **risk line** — one line naming who is harmed and how if the change is wrong;
   - a **per-layer unique failure mode** — every verification layer and every new spec file states
     in one line the failure mode it catches that no other layer catches; a layer that cannot name
     one is removed from the agreement rather than argued down;
   - an **amendment clause** — a risk discovered mid-deliberation may raise depth when the reason
     is recorded in the verification design's depth determination (since issue #166 the
     deliberation keeps no register; the design documents are written from the participants'
     report, and an agreed amendment reaches the decision ledger through that report).

   The clause carries the composition-oracle clause's two structural properties: the determination
   is stated once and its absence is not read as "not applicable", and it is **effective-from**,
   binding designs authored after it lands.

2. **The scored resolution is a widening of the existing `Scope` criterion's subject**, not a new
   check: GATE:PLAN's interpretive paragraph names the verification design alongside the plan, so
   an unjustified layer fails `Scope` through the pre-existing each-item ≥ 7 rule. No new scored
   item, no new subsection, no cap language, no PASS-threshold change, no new `scores` key.

3. **Enforcement reaches the executing agent through the two Test-AI prompt literals** in
   `.claude/workflows/architect-deliberation.js` — the Draft prompt's authoring instruction and the
   round prompt's ACCEPT condition — so an unjustified layer blocks convergence rather than riding
   to GATE:PLAN. The obligation is Test-AI-owned; no Developer-AI literal is added.

## Alternatives Considered

- **A quantity cap** (layer count, file count, line budget). Rejected: a proxy for depth that
  invites the distortions it is meant to prevent — blocking a needed layer, or merging distinct
  layers into one file to dodge a count.
- **A named GATE:PLAN subsection with its own cap**, in the shape of ADR-0016's ADR-conformance
  check. Rejected: `Scope` already names over-engineering, so a separate mechanism is exactly the
  redundancy that criterion penalises — the weakest possible form for a decision whose thesis is
  over-build. ADR-0016 reached for a named check because ADR conformance was a concern **no**
  existing criterion named; that condition does not hold here.
- **A GATE:QUALITY regression backstop.** Rejected: verification depth is settled at design time
  and frozen by GATE:PLAN, so a second scored surface would be the depth creep this decision
  exists to stop. (ADR-0016 placed one because ADR divergence can re-enter during implementation.)

## Consequences

### Positive

- Over-verification becomes determinate at GATE:PLAN: the evaluator is told what to inspect and
  what fails, rather than recording a duplicated layer with no basis to dock.
- An unjustified layer is caught at ARCHITECT, before test code is written.
- Diverse layers survive on their merits; only undiversified duplication is removed.

### Negative

- The verification design carries a small authoring cost per layer — one line each.
- The obligation is enforced by prose and prompt text, not by a machine check; a verification
  design that states a hollow failure mode passes the letter of the clause.

### Neutral / Trade-Offs

- Effective-from, so in-flight cycles are not retroactively deficient — at the cost of a period in
  which older designs sit unjustified.
- The amendment route adds no artifact of its own: the reason lives in the verification design's
  depth determination, and an agreed amendment reaches the decision ledger through the
  deliberation's report (issue #166 retired the issue register this route first used).

## Related Issues / PRs

- `Munsik-Park/autoflow#69` — verification-depth justification at ARCHITECT / GATE:PLAN.
- [`0016-adr-conformance-gate-scoring.md`](0016-adr-conformance-gate-scoring.md) — the precedent
  for recording a self-referential change to AutoFlow's own gate policy as an ADR, and the
  named-check form this decision deliberately does not follow.

## Notes

- Status `Proposed` is sufficient for the record to govern: the governing-ADR definition at
  `docs/autoflow-guide.md` > GATE:PLAN > ADR-conformance check admits `Accepted`/`Proposed` alike.
- Unlike ADR-0016, whose empirical base was zero incidents, this decision rests on a measured
  cycle, so the wiring lands in the same cycle as the decision rather than being split to a
  follow-up.
