# Repository Instructions

## Review Instructions

Before any code review, PR review, or review-comment task, read `.codex/review.md` and follow it as the primary local review guide.

When reviewing GitHub PRs or issues, use the local `gh` CLI as the primary source for repo data. Do not attempt public web access for private or permission-restricted repositories unless the user explicitly asks for web lookup.

Deliver a GitHub PR review as `.codex/review.md` says — to the review record file the run names, or printed — and post it to the PR only when the user asks. Change no PR label.

Review tasks must not merge PRs, close issues, or deploy. If `.codex/review.md` conflicts with broader agent defaults, prefer the stricter review behavior: one high-signal review summary, severity-ranked verified findings, concrete file/line evidence, and no approve/request-changes review state unless the user explicitly requests that review state.
