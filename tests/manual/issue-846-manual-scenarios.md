# Issue #846 — Manual/Environment-Dependent Verification Scenarios (Tier-2/Tier-3)

These acceptance criteria are **not** covered by
`tests/test-issue-846-doc-assertions.sh` — they are semantic judgments a grep
cannot make, or they depend on live GitHub state that is non-reproducible in
CI. Delegated per the verification design
(`.autoflow/issue-846-verification-design.md` §2/§5): this cycle is
documentation-only (Type 2) — no application source, script, or
`.claude/hooks/*` change is in scope.

---

## AC1 — ordering / procedural correctness (Tier 2)

**Why not automated:** the fallback command, the `--repo` note, and the
`--json labels` verification are literal tokens a grep can find, but whether
the *ordering* ("verify **before** reporting success or failure") is
logically sound, and whether the fallback and the verification target the
**same** PR entity, is a semantic read a grep cannot make.

**Steps:**

1. Open `.codex/review.md`'s label-removal bullet.
2. Confirm the procedure reads, in order: (a) primary `gh pr edit
   <PR_NUMBER> --remove-label blocked-by-review`; (b) on primary failure,
   fallback `gh issue edit <PR_NUMBER> --remove-label blocked-by-review`
   (same `<PR_NUMBER>`, same label); (c) verification `gh pr view
   <PR_NUMBER> --json labels` confirming `blocked-by-review` is absent；
   (d) only then report success or failure.
3. Confirm both the primary and the fallback add `--repo <owner/name>` when
   the PR is a sub-repo PR, and that the verification step does too.
4. Confirm the failure report is gated on the verification result (not on
   the exit code of the `gh issue edit`/`gh pr edit` call alone) — i.e. a
   `0` exit code from the fallback without the label actually clearing (per
   the `gh pr view --json labels` check) must still route to the
   "report the failure clearly" path.

**Pass condition:** the ordering above holds and every step operates on the
same PR entity (no cross-repo/PR-number drift between primary, fallback, and
verification).

---

## AC2-COHERENCE — reset-at-re-entry dissolves the monotone re-fire (Tier 2)

**Why not automated:** whether the new count-window definition actually
*fixes* the reported bug (a monotone total re-firing the pause immediately
after a user has already approved continuation) is a logical/behavioral
judgment over prose, not a fixed-string match.

**Steps:**

1. Read the canonical window phrase as landed in `docs/autoflow-guide.md`
   step 6.5 and `docs/design-rationale.md` Decision 9.
2. Walk the PR #214 scenario from the feature design (§1, AC2 row): 10
   `review-autofix`-marked ledger entries with one user re-entry decision
   after the 7th. Confirm that, under the landed window definition, the
   count resets to 0 at the re-entry decision, so entries 8–10 are counted
   against a **fresh** budget of 7 (not accumulated against the prior total)
   — i.e. the pause does not immediately re-fire on entry 8.
3. Confirm the **sole** reset anchor is the user re-entry decision — no
   reading of the landed prose permits a label-clear (or per-PR clear) to
   reset the window (feature design §3 rejection; guarded automatically by
   `AC2-NOLABELCLEAR` in the Tier-1 suite, but re-confirm the semantic
   reading here).

**Pass condition:** the window definition, read as prose, dissolves the
post-approval re-fire the issue reports, and no alternate reset path exists.

---

## AC3-PLACEMENT — durable record survives ledger cleanup (Tier 2)

**Why not automated:** whether the host-PR comment placement actually
*survives* the PREFLIGHT prior-cycle ledger archival (#978: the local copy
is moved to the external archive, no longer deleted) is a judgment about the
interaction between two documented lifecycles (the ledger's archive rule in
CLAUDE.md > Decision Ledger / AutoFlow State Tracking, and HANDOFF's
Merge Sequencing), not a single-file grep.

**Steps:**

1. Confirm the durable-record clause in `docs/autoflow-guide.md` step 6.5
   names the **host PR** (not a sub-repo PR, not `.autoflow/*`) as the
   comment location for both the cap-fire event and the user re-entry
   decision event.
2. Cross-check CLAUDE.md > AutoFlow State Tracking's ledger-archive rule
   ("Once the PR is observed merged or closed, prior-cycle resolution
   **archives** the issue's `.autoflow/issue-{N}*` files (moves them to
   `$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/`, outside the repo tree) as
   cleanup") — confirm the host-PR comment is a GitHub-side artifact
   independent of that local lifecycle: the local `.autoflow` copy is MOVED
   to the external archive (#978, no longer deleted), and the GitHub-side
   record stays the durable cycle anchor either way, readable on the
   PR/issue thread after the local copy has left the repo tree.
3. Confirm the record is scoped to the **host** PR specifically — in a
   multi-repo cycle a sub-repo PR merges first and is not the durable cycle
   anchor (feature design §2.2 / request §3.5).

**Pass condition:** the record's placement (host PR, GitHub-side) is
consistent with — and independent of — the ledger's documented local
lifecycle end (the #978 archive move out of the repo tree): the GitHub
record remains the durable anchor regardless of where the local copy went.

---

## Tier-3 (not run this cycle) — recorded for completeness

- **AC1 live efficacy**: an actual `gh issue edit <PR_NUMBER> --remove-label
  blocked-by-review` call succeeding where `gh pr edit` failed — already
  evidenced (librechat PR #194, 2026-06-22, exit 0 on the fallback surface).
  No live GitHub mutation is fired this cycle; this is a documentation-only
  change (Phase B §4).
- **AC3 live posted comment**: an actual `[autoflow:review-autofix]`-prefixed
  host-PR comment posted on a real cap-fire or user re-entry decision — this
  requires a future review-response cycle that actually exercises the
  attempt cap; not exercised by this docs-only change.
