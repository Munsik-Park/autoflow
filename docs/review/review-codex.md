# Review Rules — `codex`

The rule file of the `codex` reviewer, run by `<autoflow-root>/scripts/review/codex-review-pr.sh`
(`<autoflow-root>/docs/reviewer-backend.md`).

**Purpose.** Find the defects the pull request carries, from the pull request and the repository it
is in.

**Input.**
- The pull request the run names — its diff, body and linked issue, read with `gh`
  (`--repo <owner/name>` on every call for a sub-repo pull request).
- `<autoflow-root>/docs/review/review.md` — the review rules, severity levels and Output Format.

**Output.** One review, in the `<autoflow-root>/docs/review/review.md` Output Format and in Korean,
written to the file the run names. You post no pull-request comment, change no label and do not
modify the change under review.
