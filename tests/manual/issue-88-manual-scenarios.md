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

**Steps (dry-walk the shipped VERIFY step 1 / REFINE step 2 text against each entry state
below, without consulting this design document or the ledger — only the guide text itself):**

1. **First VERIFY of a cycle (no register entry exists yet).** Read VERIFY step 1 as shipped.
   Confirm a reader with no prior context concludes: no `green-tree` entry for the current
   cycle exists yet → the predicate's condition 2 cannot be satisfied → mismatch (cause
   `no-entry`) → run the full suite. Confirm the text does not read as ambiguous between "skip
   the run because nothing is recorded yet" and "run because nothing is recorded yet" — the
   feature design's asymmetry (`.autoflow/issue-88-feature-design.md` §1) states VERIFY's first
   entry always runs; confirm the shipped clause states this outcome directly rather than
   leaving it to be inferred from the general rule.
2. **Dirty worktree at capture point (either site).** Confirm the shipped text states plainly
   that a non-empty `git status --porcelain` at the capture point is itself a mismatch
   (`dirty-worktree`), independent of whether a matching `tree` hash could otherwise be found —
   i.e., a reader does not need to reason through the capture-atomicity clause separately to
   reach this branch.
3. **Absent recorded hash (register exists for a prior cycle only, or is empty for this
   cycle).** Confirm the shipped text's marker-scoped, cycle-scoped selection rule reads
   unambiguously as "no entry, full stop" rather than as licensing a reader to fall back to a
   different cycle's entry or to a `green-tree-use` entry — i.e., the non-chaining and
   cycle-scoping rules are stated where a reader would need them (at or adjacent to the
   predicate's condition 2), not only in a separate register-block subsection a reader at VERIFY
   step 1 might not consult.
4. **Match (identical tree, clean worktree, current-cycle entry with a pass result).** Confirm
   the shipped text tells the reader to skip the run and states what to write in its place (the
   inheritance line citing the source entry, and the `inherited` — never `passed` — reported
   word), so a reader does not default back to re-running "to be safe."
5. **REFINE step 2 specifically.** Confirm the re-aimed `[MUST]` reads as "evaluate the
   predicate" rather than as silently downgraded to optional — a reader skimming only the
   `[MUST]` line and not the surrounding prose should still land on "always evaluate," never
   "run only if you feel like it."

**Pass condition:** a person reading only the shipped `docs/autoflow-guide.md` VERIFY step 1 /
REFINE step 2 text (no other file) reaches the intended branch for all five states above,
without needing to cross-reference the feature design or the ledger to resolve an ambiguity.
