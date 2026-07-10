# Issue #798 — Manual Verification Scenarios (delegated to operator)

These acceptance criteria are **environment-dependent** and cannot run in the
bash harness (`tests/test-issue-798-topology-flip.sh`). They are delegated per
the verification design (`.autoflow/issue-798-verification-design.md` §2 AC4 /
AC8).

- **AC4 LOCAL-RESIDUE**: local `.git/config` `submodule.llmroute.*` section
  and the orphan `.git/modules/llmroute` gitdir are removed by
  `scripts/resync-submodules.sh`. This is **uncommitted local state** — a CI
  fresh clone never has it, so it cannot be a committed-tree assertion (R1).
  **The untracked `services/` working-tree checkout remaining on disk is the
  EXPECTED end-state, not a failure** (feature design DQ-3: with
  `.gitmodules` deleted, `git submodule status` prints nothing, so step 4's
  residue loop never iterates over `services/`).
- **AC8 HANDOFF-RECLASSIFY**: at *this cycle's* HANDOFF, the topology
  reconfirmation observes 0 submodules and classifies the repo single-repo.
  The flip is cycle-terminal — the detach commit lands in-cycle and
  reclassification is observed once, at HANDOFF, not mid-cycle. Behavioral
  and self-referential (the cycle performing the detach is the cycle that
  reconfirms); not reproducible in a unit harness.

---

## AC4 — local `.git/config` + `.git/modules` residue cleanup

**Why not automated:** `.git/config` and `.git/modules/` are per-clone local
state, never part of the committed tree. A fresh CI clone starts with neither
the stale section nor the orphan gitdir, so a CI assertion here would be
either vacuous or environment-sensitive (verification design §0 [MUST] /
R1).

**Precondition:** run only in a clone where `services` was previously an
active submodule (i.e., before this cycle's detach, `git submodule status`
showed the `llmroute` entry and `.git/config` carried a
`[submodule "llmroute"]` section).

**Steps:**

1. Confirm the residue exists before cleanup:
   ```bash
   git config --get-regexp '^submodule\.' | grep llmroute
   test -d .git/modules/llmroute && echo "orphan gitdir present"
   ```

2. Run the resync tool (idempotent, dry-run first to preview):
   ```bash
   bash scripts/resync-submodules.sh --dry-run
   bash scripts/resync-submodules.sh
   ```
   Expected: exits 0 (D-2 empty-`gm_names` run-through — steps 3–6 execute,
   not an early-exit, not a `pipefail` abort at the `gm_names` assignment).

3. Confirm the residue is gone:
   ```bash
   git config --get-regexp '^submodule\.'   # expect: no output
   test -d .git/modules/llmroute && echo "STILL PRESENT (fail)" || echo "gone (pass)"
   ```

4. Confirm the untracked `services/` working-tree checkout is **still
   present** (this is the expected end-state, not a failure — DQ-3):
   ```bash
   git status --porcelain services/ 2>/dev/null
   ```
   Expected: `services/` shows as untracked (`??`) if it still has content,
   or is simply absent from `git status` if empty/removed manually — either
   is acceptable; the oracle in step 3 does **not** require `services/` to
   be removed.

5. Idempotency: re-run `bash scripts/resync-submodules.sh` a second time.
   Expected: no-op, exits 0, no new changes reported.

**Pass condition:** after step 2, `git config --get-regexp '^submodule\.'`
returns no `llmroute` row and `.git/modules/llmroute` does not exist. The
persistence of the untracked `services/` directory is not a failure
condition.

---

## AC8 — HANDOFF topology reclassification (cycle-terminal)

**Why not automated:** HANDOFF topology reconfirmation is behavioral and
self-referential — the same cycle that performs the detach is the cycle
whose HANDOFF re-confirms topology (`CLAUDE.md` Deployment Topology:
"re-confirmed at HANDOFF"). Asserting this mid-cycle would contradict the
"flip is cycle-terminal" requirement; generic single-repo HANDOFF mechanics
are already covered end-to-end by `.github/workflows/e2e-dummy-target.yml`
(zero-submodule dummy target).

**When to run:** at this issue's (#798) own HANDOFF phase, after the detach
commit(s) have landed on the dev branch.

**Steps:**

1. Confirm the committed state is zero-submodule going into HANDOFF:
   ```bash
   git submodule status            # expect: empty
   git ls-tree HEAD -- .gitmodules # expect: empty
   git ls-tree HEAD -- services    # expect: empty
   ```

2. Observe HANDOFF's topology re-confirmation step classify the repository
   as **single-repo** (zero submodules), not multi-repo.

3. Confirm the resulting PR flow follows the single-repo procedure: exactly
   one PR (host), `Closes #798` present, **no** sub-repo PR, **no**
   `blocked-by-subrepo` label applied.

**Pass condition:** HANDOFF's topology reconfirmation reads single-repo and
the cycle produces a single PR with `Closes #798` and no multi-repo
sequencing artifacts (no `blocked-by-subrepo` label, no sub-repo PR).
