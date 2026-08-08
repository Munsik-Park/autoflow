# ADR-0003: AutoFlow Ends at Handoff

## Status

Proposed

## Context

The README and PR template state that AutoFlow creates PRs and hands them to
external review. Merge, issue closure, and deployment authority are not owned by
AutoFlow itself.

## Decision

AutoFlow should end at PR handoff. External reviewers own merge sequencing,
sub-repo merge confirmation, final readiness checks, and merge execution.

## Alternatives Considered

- Let AutoFlow merge when gates pass.
- Let AutoFlow close issues directly after host PR creation.
- Remove external review sequencing and rely only on automation.

## Consequences

### Positive

- Preserves human/external reviewer authority over irreversible actions.
- Reduces risk from automated merge or premature issue closure.
- Aligns with the existing `blocked-by-review` and `blocked-by-subrepo` gate
  model.

### Negative

- Requires humans to operate the final merge path correctly.
- Advisory CI checks may be missed if external review discipline is weak.

### Neutral / Trade-Offs

- Automation can improve the PR handed off, but should not own final merge.

## Related Issues / PRs

- Existing handoff sequencing and PR template contracts.

## Notes

- This ADR records observed current policy; owner should confirm whether this
  remains permanent.

