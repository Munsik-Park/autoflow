# Git Workflow

> Standard git procedures for projects using the AutoFlow methodology.

---

## Branch Strategy

| Type | Pattern | Purpose | Base |
|------|---------|---------|------|
| Feature  | `feature/<issue>-<desc>`  | New functionality | `main` |
| Fix      | `fix/<issue>-<desc>`      | Bug fixes | `main` |
| Refactor | `refactor/<issue>-<desc>` | Code improvements | `main` |
| Docs     | `docs/<issue>-<desc>`     | Documentation updates | `main` |
| Chore    | `chore/<issue>-<desc>`    | Maintenance tasks | `main` |

Examples:

```
feature/42-add-user-authentication
fix/87-resolve-memory-leak
docs/55-update-api-reference
```

---

## Commit Messages

### Format

```
<type>(#<issue>): <description>

Next: <next action>
```

`type`: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`.

The `Next:` line names the action the next session continues from (see
[`role-common-rules.md`](role-common-rules.md#session-protocol)).

---

## Pull Request Process

### Creating a PR

1. Verify all commits are clean and well-described.
2. Push the branch to remote (`git push -u origin <branch>`).
3. Create the PR using the template below.

```markdown
## Summary
[1-3 sentences describing the change]

## Changes
- [Bullet list of key changes]

## Issue
Closes #<issue-number>

## AutoFlow Evaluation
- Score: [X/10]
- Report: [link or inline]

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] No existing tests broken
```

### PR Review Checklist (Human Reviewers)

- Changes match the described issue.
- Code is readable and follows project conventions.
- Tests are adequate.
- No security concerns.
- AutoFlow evaluation score is acceptable.

---

## Post-Merge Cleanup

Merging, and what follows a merge or a close, are outside AutoFlow.

---

## Protected Branch Rules

### `main`

- No direct pushes (the hook denies a push to the default branch, `<autoflow-root>/hooks/check-autoflow-gate.sh`).
- Require PR with at least 1 approval.
- Require CI checks to pass.

---

## Issue Auto-Close

A change that touches no sub-repo is delivered on one PR, and that PR carries `Closes #N`.

*Secondary (multi-repo):* when the change touches a sub-repo, the delivery module opens a PR there too — the host PR carries the close keyword, each sub-repo PR references only:

```
# Host PR (closes the issue)
Closes #N

# Sub-repo PR (references only, does NOT close)
Part of <host-owner>/<host-name>#N
```

- Close keywords: `Closes`, `Fixes`, `Resolves` (case-insensitive).
- Cross-repo references are recognised in PR bodies only (commit messages do not trigger cross-repo close).
- **[MUST]** Sub-repo PRs do NOT use `Closes`.
- The host PR carries `Closes #N`; composing the PR body is the delivery module's, and nothing checks the line ([`units/delivery.md`](units/delivery.md) > *Push and pull request*).
- **[MUST]** PR bodies generated from `.github/pull_request_template.md` never inline a plain-text close-keyword token in the template itself. The template uses the marker `<!-- HOST-CLOSE-LINE -->`; the delivery module replaces the marker with the active `Closes #N` line when it writes the host PR body. Templates / docs / design notes that **describe** the close-keyword pattern must wrap the example in backticks or code-fences.
