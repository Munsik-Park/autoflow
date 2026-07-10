# Repository Instructions

## Review Instructions

Before any code review, PR review, or review-comment task, read `.codex/review.md` and follow it as the primary local review guide.

When reviewing GitHub PRs or issues, use the local `gh` CLI as the primary source for repo data. Do not attempt public web access for private or permission-restricted repositories unless the user explicitly asks for web lookup.

After completing a GitHub PR review, post the review result to the PR with the local `gh` CLI unless the user explicitly says not to comment. This default covers comments only, not approve/request-changes review states.

Review tasks must not merge PRs, close issues, or deploy. If `.codex/review.md` conflicts with broader agent defaults, prefer the stricter review behavior: one high-signal review summary, severity-ranked verified findings, concrete file/line evidence, and no approve/request-changes review state unless the user explicitly requests that review state.
