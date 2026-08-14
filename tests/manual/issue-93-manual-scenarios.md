# Issue #93 — Manual/Environment-Dependent Verification Scenarios

This carrier holds the manual-scenario criteria the verification design assigns
across both cycles. Cycle 1 (`.autoflow/issue-93-verification-design.md`
archived revision, acceptance-criterion row `lint-chain-followable`) is the first
section below. Cycle 2's review-response revision adds the second section,
acceptance-criterion row `both-branches-walkable`, verifying the `not-run`
reason-class split introduced to close the VALIDATE pass-through. Every other
automated criterion in either cycle's design is discharged by
`tests/fixtures/doc-invariants.json` (`origin_issue: 93` entries) or by the
pre-existing standing lints `scripts/test/check-manifest-regen-clean.sh` and
`tests/run-doc-invariants.sh --self-test`.

---

## AC lint-chain-followable — a committing role can walk the rule end-to-end in this checkout (Tier 2, runnable here)

**Why not automated:** the doc-invariant registry can only observe that the rule is
*stated*; it cannot observe a role *executing* the discovery order, obtaining a
command, running it, and reporting one of the outcome words. No CI-reproducible
fixture repository is introduced for this cycle (feature design §6, Enforcement
limit) — the scenario runs directly against this repository's own lint chains,
which the verification design's Testability assessment confirms exist here:
`.github/workflows/reuse.yml` (action-only, non-convertible) and the `run:`-bodied
standing lints registered on `.github/workflows/contract-suites.yml`.

### Fixed inputs

**Discovery routes, as they resolve in this checkout at the time of writing** (route
1 first, route 2 second, first hit per chain wins):

- Route 1 — `CLAUDE.md` > Development Commands `Lint` / `Format` entries: this
  repository's `CLAUDE.md` declares no Development Commands section, so route 1 is
  empty here.
- Route 2 — pull-request CI lint steps restricted to `run:`-bodied steps:
  - `.github/workflows/reuse.yml:25-26` — `REUSE Compliance Check` is a pinned
    `uses:` action step with no `run:` body → **not convertible** (conversion limit).
  - `.github/workflows/contract-suites.yml` — four `run:`-bodied standing lints on
    the `pull_request` trigger, each convertible to a directly invocable command:
    `bash scripts/test/check-suite-ci-coverage.sh` (`contract-suites.yml:271-272`),
    `bash scripts/test/check-tests-tree-hygiene.sh` (`:274-275`),
    `bash scripts/test/check-manifest-regen-clean.sh` (`:277-278`),
    `bash tests/run-doc-invariants.sh --self-test` (`:280-281`).

**Staged-file fixture**: a scratch file that a convertible chain covers and that a
deliberate violation makes that chain report a finding attributable to the staged
file. `check-tests-tree-hygiene.sh` is the chosen chain — its subject is the
embedded-NUL-byte absence of every file under `tests/**` (`scripts/test/check-tests-tree-hygiene.sh:6-7`),
and it ships its own `--self-test` planted-NUL fixture, so the violation is
reproducible without hand-crafting a binary byte in a shell here.

### Procedure

1. In a clean, uncommitted working tree, run the discovery order by hand against
   this checkout and record which of the four route-2 chains converts (expect: all
   four `contract-suites.yml` standing lints; `reuse.yml`'s check does not).
2. Stage a scratch file under `tests/**` carrying an embedded NUL byte (the same
   planted-fixture shape `check-tests-tree-hygiene.sh --self-test` already uses) and
   run the converted command directly: `bash scripts/test/check-tests-tree-hygiene.sh`.
   Confirm it exits non-zero and names the staged path.
   - **Expected outcome-word mapping**: `check-tests-tree-hygiene.sh` → `detected`
     (findings attributable to the staged file; commit does not proceed);
     `check-suite-ci-coverage.sh`, `check-manifest-regen-clean.sh`,
     `tests/run-doc-invariants.sh --self-test` → run against the same staged
     surface and record `clean` (no attributable findings) since the violating
     scratch file is outside their subjects.
   - `reuse.yml`'s REUSE check → `not-run`, naming `.github/workflows/reuse.yml:25`
     (step `REUSE Compliance Check`) as the non-convertible step, per the
     conversion limit.
3. Remove the violating scratch file (clean surface) and re-run all four converted
   commands plus the non-convertible REUSE check's `not-run` determination. Confirm
   every chain now reports `clean`, except REUSE, which stays `not-run` (its
   non-convertibility does not depend on the staged surface).
4. Confirm no step of the walk required a fixture repository, a package manager, or
   any tool not already present in this checkout — route 1's empty result and route
   2's four conversions are both observed directly from the files named above, not
   simulated.

### Expected outcome — both conditions must hold

1. **Route 1 empty, route 2 converts four chains, one chain (REUSE) does not
   convert** — matches the Testability assessment's determination, re-derived
   independently by walking the discovery order rather than trusting the design
   document's own account of it.
2. **Every reachable outcome word above is legally reportable** — `detected` on the
   violating surface, `clean` on the clean surface (for the three convertible
   chains whose subject the violation did not touch, and for all four once the
   violation is removed), and `not-run` for the REUSE step in both cases. No state
   encountered during the walk is left without a legal word from the outcome
   vocabulary (feature design §3).

### Pass condition record

Record, in the cycle report:

- The discovery-route result (route 1 empty; route 2's four conversions; REUSE's
  non-conversion), each with the `path:line` it was read from.
- The outcome word observed for each of the five chains on the violating surface and
  again on the clean surface.
- Confirmation that no fixture repository or external tool was needed.

**Pass condition:** both expected-outcome conditions hold and the pass-condition
record above is complete.

---

## AC both-branches-walkable — one staged file produces both `not-run` reason-class dispositions at VALIDATE step 7 (Tier 2, runnable here, cycle 2)

**Why not automated:** the doc-invariant registry holds only permanent STATE
predicates (`docs/doc-invariant-registry.md` > *Two lanes, one test each*); it
cannot execute VALIDATE's classification or the operator's resolution path. This
scenario walks the reason-class split — `ci-deferred` (clears, evidenced by a
named covering pull-request job) versus `unexecuted` (does not clear) — against a
real staged file in this checkout, then discharges the refusal so both the
refusal and the resolution are demonstrated.

### Fixed inputs

**Single staging set**: `tests/plugin/manual-scenarios-792.md` alone. This file
is covered by two discovered chains that classify oppositely:

- **REUSE chain** — `.github/workflows/reuse.yml:25-26`, a pinned `uses:` step
  with no `run:` body (Conversion limit, non-convertible). `REUSE.toml`'s
  `**/*.md` bulk annotation covers the staged file. The workflow's
  `on: pull_request` (`.github/workflows/reuse.yml:12-15`) carries no `paths:`
  filter, so a covering pull-request job exists for every diff, this one
  included → expected disposition `not-run (ci-deferred)`, **clears**.
- **doc-invariant runner chain** — route 2, `run: bash tests/run-doc-invariants.sh`
  at `.github/workflows/e2e-dummy-target.yml:309`. The staged file is covered:
  `tests/fixtures/doc-invariants.json` carries entries whose `file` is
  `tests/plugin/manual-scenarios-792.md` (e.g. `797-AC1a-792-bash-dialect`). No
  covering pull-request job can be named for this diff: matching the staged path
  against every `paths:` pattern in every workflow file (exact and glob) selects
  it nowhere — the `tests/plugin/` entries present in `contract-suites.yml` and
  `e2e-dummy-target.yml` each name a specific `.sh` file, never this `.md` file,
  and no `paths:` list carries `tests/plugin/**` unfiltered → expected
  disposition `not-run (unexecuted)`, **does not clear**.

**Working-tree-only staging**: `tests/plugin/manual-scenarios-792.md` already
hosts landed registry entries, so `git add` of the file unmodified stages
nothing. The walk therefore appends a throwaway line to the file in the working
tree to produce a real diff, and reverts it (`git restore --staged --worktree
tests/plugin/manual-scenarios-792.md`) before this cycle's own commit — the
appended line must leave every existing registry-anchored literal on its own
line intact, and the committed tree must never carry the throwaway edit.

### Procedure

1. Confirm the working tree is clean, then append one throwaway line (e.g. a
   trailing comment line) to `tests/plugin/manual-scenarios-792.md` without
   altering any existing line, and `git add` it so it is staged.
2. Re-derive the REUSE chain's disposition: read
   `.github/workflows/reuse.yml:12-15` and confirm `on: pull_request` carries no
   `paths:` filter; read `REUSE.toml`'s `**/*.md` bulk annotation and confirm it
   covers the staged file; read `.github/workflows/reuse.yml:25-26` and confirm
   the step is a pinned `uses:` action with no `run:` body. Record disposition
   `not-run (ci-deferred)`, naming the covering job (`.github/workflows/reuse.yml`
   `REUSE compliance` / `REUSE Compliance Check`) and its trigger evidence
   (unfiltered `on: pull_request`).
3. Re-derive the doc-invariant runner chain's disposition: confirm
   `.github/workflows/e2e-dummy-target.yml:309` runs
   `bash tests/run-doc-invariants.sh` on `pull_request`; confirm the staged file
   is covered by reading its `file` occurrences in
   `tests/fixtures/doc-invariants.json`; collect every `paths:` pattern across
   every `.github/workflows/*.yml` file and confirm none — exact string or glob —
   matches `tests/plugin/manual-scenarios-792.md`. Record disposition
   `not-run (unexecuted)` — no covering pull-request job can be named, so under
   the fail-closed default the chain does not clear.
4. Take resolution path 1 for the non-clearing chain (feature design > *When the
   step does not clear*): run `bash tests/run-doc-invariants.sh` over the staged
   surface, confirm it exits 0 and reports no attributable finding, and
   re-report the chain's outcome as `clean`. Confirm VALIDATE step 7 now
   re-evaluates and clears (`clean` plus the REUSE chain's `not-run
   (ci-deferred)` both sit inside the clearing set).
5. Revert the throwaway edit: `git restore --staged --worktree
   tests/plugin/manual-scenarios-792.md`. Confirm `git status` shows the file
   unmodified and no trace of the throwaway line remains staged or on disk.

### Expected outcome — both conditions must hold

1. **The two chains classify oppositely from one staged file** — REUSE resolves
   `not-run (ci-deferred)` with re-derivable covering-job and trigger evidence;
   the doc-invariant runner resolves `not-run (unexecuted)` with no covering job
   nameable, matching the feature design's *Realizing the `unexecuted` walk*
   determination re-derived independently here rather than trusted from the
   design text.
2. **The refusal is not terminal** — resolution path 1 discharges the
   `unexecuted` chain inside this same walk: running the chain locally and
   re-reporting `clean` lets VALIDATE clear. The user-pause exit (resolution
   path 2) is not claimed by this scenario — every chain discovered here is
   either executable or covered, so that exit has no walkable subject in this
   checkout.

### Pass condition record

Record, in the cycle report:

- Each chain's disposition (`not-run (ci-deferred)` / `not-run (unexecuted)`)
  with the `path:line` evidence it was read from.
- Confirmation that resolution path 1 discharged the non-clearing chain and
  VALIDATE re-evaluated to clear.
- Confirmation that the throwaway staging edit was reverted before this cycle's
  own commit, leaving `tests/plugin/manual-scenarios-792.md` byte-identical to
  its pre-walk state.

**Pass condition:** both expected-outcome conditions hold and the pass-condition
record above is complete.
