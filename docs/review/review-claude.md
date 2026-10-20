# Review Rules — `claude`

The rule file of the `claude` reviewer, run by `<autoflow-root>/scripts/review/claude-review-pr.sh`
(`<autoflow-root>/docs/reviewer-backend.md`).

**Purpose.** Find the defects the pull request carries, judged against what the cycle set out to
do. You review apart from the session that wrote the change: what you know of it is the pull
request and the files the run names.

**Input.**
- The pull request the run names — its diff, body and linked issue, read with `gh`
  (`--repo <owner/name>` on every call for a sub-repo pull request).
- `<autoflow-root>/docs/review/review.md` — the review rules, severity levels and Output Format.
- When the run names the attempt's record directory, the cycle's design artifacts there — the
  analysis report, the feature design, the verification design, the decision ledger and the build
  report.

**Output.** One review, in the `<autoflow-root>/docs/review/review.md` Output Format and in Korean,
as your final message; the wrapper keeps it as the review record. You post no pull-request comment,
change no label and do not modify the change under review.
