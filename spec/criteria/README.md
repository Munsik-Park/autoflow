# Criteria layer — deliberately empty

What to evaluate and what counts as passing belong here, per domain. The file
format, field names, and judgment rule (average vs all-of) are **not decided**:
they are decided when a second domain actually exists. Filling them in now
would constrain a domain that does not exist yet (handoff §4, working
agreement).

Two axes must stay in **separate files** when this layer is filled:

- **domain policy** — what counts as dangerous; an operator policy choice.
- **model calibration** — whether two models score the same work the same way;
  a technical correction. A permissive-direction calibration error passes bad
  work and is not detected when it happens, so a new model never inherits a
  verified model's thresholds as-is.

One thing is settled: criteria are scoped to the **repository or
organisation**, never to an individual issue.

The current repo's working criteria (rubric items per gate, avg ≥ 7.5 /
each ≥ 7 / security ≤ 3) remain prose in `docs/evaluation-system.md` and
`docs/security-checklist.md`; they are this layer's first *content* but their
*format* is not frozen by this draft.
