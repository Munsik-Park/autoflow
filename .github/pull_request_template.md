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

Sub-repo PR: use `Part of Munsik-Park/autoflow#N` (no close keyword).

Rules / infra PR: write `N/A` if there is no tracking issue.

Reference: docs/git-workflow.md > Issue Auto-Close,
CLAUDE.md > PR Issue Auto-Close.
-->

## Sub-repo merge dependency

<!--
For host PRs created at HANDOFF that include sub-repo changes, the
`blocked-by-subrepo` label is applied automatically by
scripts/handoff/create-host-pr.sh. The label is removed manually by the
operator at merge time (not by the workflow — see
docs/external-review-sequencing.md > Per-issue procedure).
-->

- [ ] This PR is **draft** until the sub-repo dependency is merged (host PRs at HANDOFF are created with `--draft`).
- [ ] Sub-repo PR (if any): _link the host's direct sub-repo PR here_ (e.g., `{{REPO_SERVICE_HOST}}#NNNN`; a PR nested below that sub-repo is the sub-repo's own concern).
- [ ] Sub-repo PR has been merged into `{{REPO_SERVICE_HOST}}:main`.
- [ ] Submodule pointer in this branch matches the sub-repo merge commit. **External reviewer**: see `docs/external-review-sequencing.md` for the pointer-bump procedure.
- [ ] The `blocked-by-subrepo` label has been removed from this PR (removed by the operator at merge time; if still present, remove it manually after confirming the sub-repo merge and the host pointer reconcile are complete).
- [ ] This PR has been promoted from draft to **ready for review**.

If this PR is **host-only** (no sub-repo change in the dev branch), mark every box above as N/A in the box label (e.g., `- [x] N/A — host-only PR`). The helper script omits the `blocked-by-subrepo` label entirely when `--no-subrepo-dep` is passed, so no label removal is needed.

## AutoFlow

- Issue: <!-- #N or N/A -->
- Phase: `awaiting-external-review`
- Evaluation summary: _link to `.autoflow/issue-N.json` or paste GATE:QUALITY summary line_

## Testing

- [ ] Unit / integration tests pass on CI
- [ ] Manual checklist items (if any) noted in PR description body

## Reviewer

Merging is performed **only by the external reviewer**, never by AutoFlow. See `docs/external-review-sequencing.md` for the merge sequence.
