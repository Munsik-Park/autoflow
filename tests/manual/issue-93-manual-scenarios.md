# Issue #93 — Manual/Environment-Dependent Verification Scenarios

This carrier holds the one criterion the verification design assigns to a manual
scenario (`.autoflow/issue-93-verification-design.md`, acceptance-criterion row
`lint-chain-followable`). Every other automated criterion in that design is
discharged by `tests/fixtures/doc-invariants.json` (`origin_issue: 93` entries) or
by the pre-existing standing lints `scripts/test/check-manifest-regen-clean.sh` and
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
