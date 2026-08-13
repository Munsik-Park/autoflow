# Issue #88 — Manual/Environment-Dependent Verification Scenarios

Per `.autoflow/issue-88-verification-design.md`, every acceptance criterion except
`AC:agent-executable` is automated (permanent registry entries plus the cycle suite
`tests/test-issue-88-tree-identity.sh`). This document carries the single manual row.

---

## AC:agent-executable — the shipped clause is unambiguous to the agent that must execute it

**Why not automated:** the fact this criterion establishes — that a reader-agent (the
orchestrator, at a future VERIFY step 1 entry or REFINE step 2 entry) takes the intended
branch of the tree-identity predicate from the shipped text alone — has no deterministic
oracle. A simulated reader would assert only the simulation, not that the *actual* prose in
`docs/autoflow-guide.md` reads unambiguously to an agent encountering it cold. Per the
verification design's *Testability assessment*, this stays a manual scenario with the reason
stated, not an environment-dependent item routed to a mock.

**Steps (dry-walk the shipped GREEN step 5 / VERIFY step 1 / REFINE step 2 text against each
entry state below, without consulting this design document or the ledger — only the guide text
itself):**

1. **GREEN step 5, a cycle's first GREEN (no register entry exists yet).** Read GREEN step 5 as
   shipped. Confirm a reader with no prior context concludes: no `green-tree` entry for the
   current cycle exists yet → the predicate's condition 2 cannot be satisfied → mismatch (cause
   `no-entry`) → the acceptance run happens, executed by the orchestrator itself, and — if the
   run is all-PASS over a clean, fully committed tree and covers the registrable scope — a
   `green-tree` entry is written with `runner: GREEN step 5`. Confirm the text is unambiguous
   that the run is the *orchestrator's own* rerun of the test-summary anchor (never a
   transcription of the Developer AI's report) and that a reader does not mistake this for a
   shortcut around the existing `CLAUDE.md` > *Verify teammate claims* obligation.
2. **First VERIFY of a cycle, immediately after a GREEN step 5 that registered a Green.** Read
   VERIFY step 1 as shipped. Confirm a reader concludes: the GREEN-exit entry is selectable
   (same cycle, tree unchanged, clean worktree) → the predicate matches → **inherit**, do not
   re-run. Confirm the reader is not tempted to re-run "to be safe" — the shipped text states
   inheriting is the intended branch here, not a shortcut being declined.
3. **First VERIFY of a cycle where GREEN step 5 registered nothing** (its own run was narrower
   than the registrable scope, its capture point was dirty, or it was not all-PASS). Confirm a
   reader concludes: no selectable entry → mismatch, cause `no-entry` → run the full suite —
   the pre-existing fallback behavior, reached correctly even though a GREEN-exit step now
   exists upstream.
4. **Dirty worktree at capture point (any of the three sites).** Confirm the shipped text states
   plainly that a non-empty `git status --porcelain` at the capture point is itself a mismatch
   (`dirty-worktree`) — or, at GREEN step 5, that it simply suppresses the write and the
   acceptance run still discharges its own anchor — independent of whether a matching `tree`
   hash could otherwise be found.
5. **`VERIFY → GREEN` re-entry landing no tracked change.** Read GREEN step 5's re-entry
   disposition. Confirm a reader concludes: the prior VERIFY-exit entry is still selectable and
   the tree is unmoved → the step **inherits without re-running** — this is the mechanism
   working as intended, not a hole that skips verification of an unresolved fix.
6. **REFINE step 2 specifically.** Confirm the re-aimed `[MUST]` reads as "evaluate the
   predicate" rather than as silently downgraded to optional — a reader skimming only the
   `[MUST]` line and not the surrounding prose should still land on "always evaluate," never
   "run only if you feel like it."

**Pass condition:** a person reading only the shipped `docs/autoflow-guide.md` GREEN step 5 /
VERIFY step 1 / REFINE step 2 text (no other file) reaches the intended branch for all six states
above, without needing to cross-reference the feature design or the ledger to resolve an
ambiguity.
