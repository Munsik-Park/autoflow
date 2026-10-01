## Summary

<!-- 1-3 sentences describing the change. -->

## Changes

<!-- Bullet list of key changes. -->

## Design / ADR

<!-- Name the documents this PR used as decision basis, reachable from this PR.
     Do NOT link .autoflow/*. -->

- Design note: <path > section, or N/A>
- ADR: <path, or "ADR not required: <one-line reason>">
- Architecture context: <path > section, or N/A>

Check exactly one:

- [ ] No architecture impact.
- [ ] Architecture impact — ADR linked above.
- [ ] Design impact, ADR not required — design note linked above + reason stated.
- [ ] N/A - docs, tests, or operational maintenance only.

## Acceptance criteria

<!-- The reviewer must be able to reach the AC from this PR. -->

- AC: linked issue #N > Acceptance Criteria  (or stated inline in the PR body)

## Issue link

<!-- HOST-CLOSE-LINE -->

<!--
Host PR (HANDOFF): the orchestrator replaces the line above with the literal
close-keyword reference (e.g., the GitHub-recognised `Closes` pattern + issue
number).

Sub-repo PR: use `Part of <host-owner>/<host-name>#N` (no close keyword).

Rules / infra PR: write `N/A` if there is no tracking issue.

Reference: docs/git-workflow.md > Issue Auto-Close.
-->

## Sub-repo merge dependency

<!--
A host PR whose sub-repo pointer depends on an unmerged sub-repo PR is created
with the `blocked-by-subrepo` label (docs/phases/handoff.md > Multi-repo
delivery). The operator removes it once the sub-repo PR has merged and the host
pointer equals its merge commit (docs/external-review-sequencing.md >
Merge-order clearance).
-->

- [ ] Sub-repo PR (if any): _link the host's direct sub-repo PR here_.
- [ ] Sub-repo PR merged, and this branch's pointer equals its merge commit (`git ls-tree HEAD <sub-repo>`).
- [ ] `blocked-by-subrepo` removed by the operator.

If this PR has no sub-repo dependency, mark the boxes above N/A (e.g., `- [x] N/A — no sub-repo dependency`).

## AutoFlow

- Issue: <!-- #N or N/A -->
- Phase: `awaiting-external-review`
- Evaluation summary: _link to `.autoflow/issue-N.json` or paste GATE:QUALITY summary line_

## Testing

- [ ] Unit / integration tests pass on CI
- [ ] Manual checklist items (if any) noted in PR description body

## Reviewer

Merging is performed **only by the external reviewer**, never by AutoFlow. See `docs/external-review-sequencing.md` for the merge sequence.
