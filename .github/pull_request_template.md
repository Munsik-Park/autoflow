## Summary

<!-- 1-3 sentences describing the change. -->

## Changes

<!-- Bullet list of key changes. -->

## Design / ADR

<!-- Name the documents this PR used as decision basis, reachable from this PR.
     Reviewers use only what is linked here plus context they discover while tracing
     the changed surface. Do NOT link .autoflow/* (gitignored, unreachable from the PR). -->

- Design note: <path > section, or N/A>
- ADR: <path, or "ADR not required: <one-line reason>">
- Architecture context: <path > section, or N/A>

Check exactly one:

- [ ] No architecture impact.
- [ ] Architecture impact — ADR linked above.
- [ ] Design impact, ADR not required — design note linked above + reason stated.
- [ ] N/A - docs, tests, or operational maintenance only.

## Acceptance criteria

<!-- The reviewer must be able to reach the AC from this PR. Prevents repeated false
     `High` findings from reviewing against an assumed contract. -->

- AC: linked issue #N > Acceptance Criteria  (or stated inline in the PR body)

## Issue link

<!-- HOST-CLOSE-LINE -->

<!--
Host PR (HANDOFF): the orchestrator replaces the line above with the literal
close-keyword reference (e.g., the GitHub-recognised `Closes` pattern + issue
number) so external merge closes the issue.

Sub-repo PR: use `Part of Munsik-Park/autoflow#N` (no close keyword —
sub-repo PRs merge first; closing the issue prematurely is the documented
incident from issue #82 cycles).

Rules / infra PR: write `N/A` if there is no tracking issue.

Reference: docs/git-workflow.md > Issue Auto-Close,
CLAUDE.md > PR Issue Auto-Close.
-->

## Sub-repo merge dependency

<!--
This block is the R2 enforcement of the merge-sequencing contract from
docs/external-review-sequencing.md. For host PRs created at HANDOFF that
include sub-repo changes, the `blocked-by-subrepo` label is applied
automatically by scripts/handoff/create-host-pr.sh. The label is removed
manually by the operator at merge time (not by the workflow — see
docs/external-review-sequencing.md > Per-issue procedure).
-->

- [ ] This PR is **draft** until the sub-repo dependency is merged (host PRs at HANDOFF are created with `--draft`).
- [ ] Sub-repo PR (if any): _link the host's direct sub-repo (llmroute) PR here_ (e.g., `{{REPO_SERVICE_HOST}}#NNNN`; nested LibreChat/librechat-deploy PRs are llmroute's internal concern).
- [ ] Sub-repo (llmroute) PR has been merged into `{{REPO_SERVICE_HOST}}:main`.
- [ ] Submodule pointer in this branch (`services`) matches the sub-repo merge commit (llmroute PR merge commit). **External reviewer**: see `docs/external-review-sequencing.md` for the pointer-bump procedure.
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
