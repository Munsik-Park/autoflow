# Issue #973 — Manual Verification Scenarios

Source: `.autoflow/issue-973-verification-design.md` §2 (AC1), §3.

These items are judgment-equivalence checks a script cannot cheaply assert
(diff-review confirmation that a mechanical edit preserved semantics). The
automated backstop for all of them is the edited suite exiting 0 with an
unchanged `Results: N passed` count, and the AC2-A2 zero-remaining scan.

## AC1 — Per-site transform review (10 sites / 4 files, scope-A)

For each of the 10 in-scope sites, confirm the edit is exactly the mechanical
transform `X | grep -qFLAGS T` → `ctx=$(X); printf '%s\n' "$ctx" | grep -qFLAGS T`
— i.e. only the pipe form changed, not the extractor call, the grep flags
(`-qF` / `-q .` / `-qiE`), the literal pattern `T`, or the `assert_true`/
`assert_false` wrapper around it.

**Historical note (rows 1–7):** `test-issue-800-doc-assertions.sh` was
transformed by this PR at the time this table was drafted, but the file has
since been retired (deleted) by #951's registry migration (content moved
into `tests/fixtures/doc-invariants.json` / `tests/run-doc-invariants.sh`,
`docs/doc-invariant-registry.md` disposition table). Rows 1–7 are kept below
as a historical record of the sites reviewed pre-retirement; they are not a
live checklist — the file/line anchors no longer resolve against the current
tree. The live scope-A surface is rows 8–10 (3 sites / 3 files), matching the
AC2-B2 baseline in `tests/test-issue-964-sigpipe-safe-pipes.sh`.

| # | File | Line | Producer fn | assert | grep flags |
|---|---|---|---|---|---|
| 1 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 139 | `claude_issue_mgmt_section` | true | `-qF` |
| 2 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 141 | `claude_issue_mgmt_section` | true | `-qF` |
| 3 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 143 | `boundary_backlog_section` | true | `-qF` |
| 4 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 167 | `claude_issue_mgmt_section` | false | `-qF` |
| 5 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 169 | `claude_issue_mgmt_section` | true | `-qF` |
| 6 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 171 | `boundary_backlog_section` | false | `-qF` |
| 7 | test-issue-800-doc-assertions.sh (historical — retired by #951) | 173 | `boundary_backlog_section` | true | `-qF` |
| 8 | test-issue-799-inert-cleanup.sh | 467 | `claude_md_offwindow_changes` | false | `-q .` |
| 9 | test-issue-846-doc-assertions.sh | 240 | `claude_regressions_line` | false | `-qiE` |
| 10 | test-issue-848-doc-assertions.sh | 335 | `commit_ownership_table` | true | `-qiE` |

**assert_false negation checkpoint** (sites 4, 6, 8, 9): confirm the captured-
string pipeline exit code is still what `assert_false` inverts — i.e.
`printf '%s\n' "$ctx" | grep -q… T` yields the same exit as the pre-fix
`X | grep -q… T` for identical `T`. The suite-level green (unchanged pass
count) is the automated backstop; this item is the human diff-level
confirmation.

**Empty-input nuance (site 8, `799:467 grep -q .`):** confirm that when
`claude_md_offwindow_changes` produces empty output, `printf '%s\n' ""` emits
one lone newline, so `grep -q .` (which requires a non-newline character)
still reports no match — identical to the pre-fix empty-producer direct path.

**Multi-line table producer (site 10, `848:335 commit_ownership_table`):**
confirm the target row (`CLAUDE.md:362`, the "Submodule pointer bump" row) is
a single physical line — `commit_ownership_table`'s output is intra-line for
this row, so the capture-then-printf transform preserves the per-row match
(a wrapped row would not match in either form, but the pre-fix assertion is
already known-PASS per ledger E11, so this is a closed anchor, not an open
risk).

## AC1 — Compound-`&&` review checkpoint (DCR-3)

Confirm that none of the 10 sites above was converted with a `;`-split that
severs an `&&` condition. Per verification design §4 DCR-3 / ledger E10, none
of the 10 in-scope sites is compound (no `&&` in the pre-fix scan output), so
this checkpoint is expected to be trivially satisfied — it guards against a
regression the current site set does not exercise, not an open risk in this
edit.

## AC3 — doc-prose review (non-gated)

Per verification design §2 AC3 row 2 / §4 DCR-2, confirm (by reading the
diff, not by an added test token) that `docs/submodule-common-rules.md`
Testing Standards item 6 gains the compound-`&&`/`$ctx`-reuse ordering
sentence (R3 sentence 2) alongside the gated `extractor` token. This is
intentionally NOT double-gated by a second automated assertion (over-fitting
risk noted in the verification design) — human confirmation only.
