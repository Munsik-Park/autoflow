# Issue #848 — Manual/Environment-Dependent Verification Scenarios (Tier-2/Tier-3)

These acceptance criteria are **not** covered by
`tests/test-issue-848-doc-assertions.sh` — they are semantic judgments a grep
cannot make, or they depend on a live multi-repo cycle that is
non-reproducible in this host (single-repo; zero submodules). Delegated per
the verification design (`.autoflow/issue-848-verification-design.md` §3/§5):
this cycle is documentation-only (Type 2) — no application source, script, or
`.claude/hooks/*` change is in scope.

---

## AC2 ⇄ AC4 — re-bump / batching timing coherence (Tier 2)

**Why not automated:** the scripted suite pins the presence of the step-3
`[MUST]` re-bump clause and the step-6.5 batching norm as literal tokens, and
guards that step 3 never mandates a per-push re-bump. Whether the two rules
name the **same single firing point** (one bump at the clean point, not one
per fix push) — i.e. that they are timing-coherent rather than merely
non-contradictory in wording — is a semantic read.

**Steps:**

1. Read HANDOFF step 3's `[MUST]` re-bump clause and HANDOFF step 6.5's
   Propagation-batching bullet in `docs/autoflow-guide.md`.
2. Confirm both resolve to a single firing point: the host `services`
   pointer is bumped **once**, at the moment the sub-repo PR's
   `blocked-by-review` label clears — not once per fix push, and not
   eagerly before the label clears.
3. Confirm step 3's gating precondition ("the sub-repo PR's
   `blocked-by-review` has cleared") is the same condition step 6.5 uses to
   release the deferred bump.
4. Confirm the exceptional interim bump (`chore(#N): interim services bump:
   <reason>`) is the only sanctioned deviation and requires a recorded reason.

**Pass condition:** a reader following step 3 and step 6.5 together arrives at
exactly one bump per clean point with no timing contradiction.

---

## AC4 — tier-agnosticism of the batching rule (Tier 2)

**Why not automated:** the guard asserts the step-6.5 block carries no
`nested`/`multi-tier`/`grandparent` token. Whether the rule as written
actually *generalizes* across submodule depth — i.e. the parent-pointer /
sub-repo-PR mechanism holds regardless of how many repos deep the change
sits — is a judgment about mechanism, not token presence.

**Steps:**

1. Read the step-6.5 Propagation-batching bullet.
2. Confirm the norm is stated purely in terms of the general "host
   `services` pointer ↔ sub-repo PR" relation, with no dependence on a
   specific nesting topology (`librechat` / `librechat-deploy` chains).
3. Confirm it is consistent with `CLAUDE.md` > Deployment Topology ("One
   submodule and N submodules follow the identical contract").

**Pass condition:** the rule reads correctly for both a one-level and an
N-level submodule composition without rewording.

---

## AC5 — ADR-0015 conformance (Tier 2)

**Why not automated:** the suite asserts the presence of a `#795` / `ADR-0015`
retirement anchor in `docs/git-workflow.md` and that the HANDOFF procedure
never revives `subrepo-merged` as a live status check. Whether the corrected
prose is *faithful* to ADR-0015 D1/D3 (the actual decision text) is a
cross-document semantic check.

**Steps:**

1. Read `docs/adr/0015-*.md` (D1 and D3), `docs/adr/README.md`, and
   `docs/external-review-sequencing.md`'s Merge-order clearance note.
2. Confirm the corrected `docs/git-workflow.md` Merge Sequencing and Pointer
   reconciliation prose agrees verbatim with those records: the
   `handoff-sequence.yml` dispatch path and its `subrepo-merged` status-check
   publication are **retired and physically removed** (S8 / #795), the signal
   was advisory-only, and the manual `git ls-tree HEAD services` check is now
   the sole stale-pointer defense.
3. Confirm the new `CLAUDE.md` Commit Ownership pointer-bump row is
   consistent with ADR-0015 D3's "no merge dependency" model (a pointer bump
   is a normal host dev-branch commit, not a merge-order gate).

**Pass condition:** no divergence between the corrected prose and the ADR /
retirement records.

---

## AC1 / AC2 — live multi-repo pointer-bump behavior (Tier 3)

**Why not runnable here:** this host is single-repo (zero submodules), so no
`services` gitlink exists to bump. Observable only in a real multi-repo
consumption cycle.

**Deferred check (future multi-repo cycle):**

1. In a multi-repo cycle, at HANDOFF step 4b confirm the orchestrator commits
   the host `services` pointer with `chore(#N): bump services pointer to
   <short-sha>` and that `git ls-tree HEAD services` equals the sub-repo PR
   head.
2. In review-response, confirm the re-bump fires once after the sub-repo PR's
   `blocked-by-review` clears (step 3 `[MUST]`).

---

## AC4 — batching cost observation (Tier 3)

**Why not runnable here:** requires a real Codex-review-driven fix loop across
a host + sub-repo PR pair.

**Deferred check:** confirm that deferring the host pointer bump until the
sub-repo PR is review-clean collapses the repeated host-CI re-run + sub-repo
re-review churn (the #778 / #760 observation) into a single bump per clean
point.
