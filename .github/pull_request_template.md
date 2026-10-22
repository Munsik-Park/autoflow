## Summary

<!-- 1-3 sentences describing the change. -->

## Changes

<!-- Bullet list of key changes. -->

## Design / ADR

<!-- Name the documents this PR used as decision basis, reachable from this PR.
     Do NOT link <attempt-dir>/* — the attempt's records are outside the tree. -->

- Design note: <path > section, or N/A>
- ADR: <path, or "ADR not required: <one-line reason>">
- Architecture context: <path > section, or N/A>

Check exactly one:

- [ ] No architecture impact.
- [ ] Architecture impact — ADR linked above.
- [ ] Design impact, ADR not required — design note linked above + reason stated.
- [ ] N/A - docs, tests, or operational maintenance only.

## Acceptance criteria

<!-- The reviewer must be able to reach the AC from this PR. One line per
     criterion: met or not, the commit it was confirmed at, where the evidence
     is; the head names the commit the results stand at
     (docs/pr-body-guide.md > 수용 기준 대조). -->

- AC: linked issue #N > Acceptance Criteria  (or stated inline in the PR body)

`<sha>` 시점의 결과.

- <criterion> — <met / not met> · `<sha>` · <evidence location>

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

## AutoFlow

- Issue: <!-- #N or N/A -->
- Phase: `awaiting-external-review`
- Evaluation summary: _paste the GATE:QUALITY summary line (from `<attempt-dir>/issue-N.json`, outside the tree)_

## Testing

- [ ] Unit / integration tests pass on CI
- [ ] Manual checklist items (if any) noted in PR description body

## Reviewer

Merging is performed **only by the external reviewer**, never by AutoFlow.
