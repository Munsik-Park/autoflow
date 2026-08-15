# Issue #85 — Manual/Environment-Dependent Verification Scenarios

`.autoflow/issue-85-verification-design.md` > AC-main-green names one leg that cannot be produced
before the merge: the actual hosted CI run on the `main` push trigger. The automated reproduction
(`tests/test-push-context-base-ref.sh`, a scratch clone with `origin/main == HEAD`) discharges the
**mechanism** — the base-ref resolution that produced the observed failure. It cannot discharge the
**observation** that the real hosted run is green, because the push trigger only fires post-merge
and AutoFlow does not merge (`CLAUDE.md` > Development Lifecycle).

---

## M1 — Hosted `main` push-trigger run is green (Tier 3, environment-dependent)

**Source AC:** AC-main-green (verification design > Acceptance criteria → verification) —
"the push-trigger context on `main` is green, with a post-merge reproduction condition."

**Why not automated:** `tests/test-push-context-base-ref.sh` reproduces the push-trigger base-ref
resolution (`merge-base HEAD origin/main == HEAD`) in an isolated scratch clone and requires the
subjects it executes there to exit 0. Since issue #99 that execution is **delta-scoped**: the
subject set is still derived every run, but only the subset this run's own change surface could
have altered is executed in the scratch clone (reported on the run's `SELECTED:` /
`NOT-SELECTED:` lines), while every unselected subject's backstop is its own native run in the
push topology — asserted, per subject, by the `NATIVE-COVERAGE:` premise lines. That proves the
resolution mechanism this cycle fixes is correct in isolation, and it makes the hosted push-to-main
run below the *primary* evidence for the unselected remainder rather than a corroboration of it.
It cannot observe the actual hosted `contract-suites` / `e2e-dummy-target` workflow
runs that GitHub Actions fires on a real push to `main`, because that trigger does not exist before
the external merge, and AutoFlow's own authority ends at an open PR (`CLAUDE.md` > Development
Lifecycle) — it never merges.

**Setup:** After this cycle's host PR is merged externally (out of band, per `CLAUDE.md` > PR Flow),
locate the resulting push-triggered runs of `contract-suites.yml` and `e2e-dummy-target.yml` against
the `main` branch (GitHub Actions run list, filtered to the push event on `main` at or after the
merge commit).

**Procedure:**

1. Open the push-triggered `contract-suites.yml` run for the merge commit. Confirm every job step
   completes with a green check, in particular the standing push-context suite's own step
   (`tests/test-push-context-base-ref.sh`) and the steps for every retired/renamed/folded-in #76
   artefact's replacement (`tests/test-workflow-trigger-conformance.sh`,
   `tests/test-standing-lint-drives.sh`, the fold-in leg inside `tests/test-run-doc-invariants.sh`).
2. Open the corresponding `e2e-dummy-target.yml` push-triggered run and confirm it is green — this
   workflow hosts most of the base-ref-consuming subjects the derived subject set names
   (`.autoflow/issue-85-feature-design.md` §3.3 "base-ref 소비자 클래스의 현황 명시").
3. If either run is red, read the failing step's log and classify: (a) a genuine push-context
   defect this cycle's reproduction should have caught but did not (record as a follow-up issue
   against the reproduction's subject-set derivation or attribution logic), or (b) a defect
   unrelated to base-ref resolution (pre-existing, outside this cycle's scope).

**Pass condition:** both push-triggered workflow runs for the merge commit are green.

**Fail:** either run is red. If classified (a) above, the reproduction suite's coverage has a gap
that a future cycle must close (`tests/test-push-context-base-ref.sh`'s subject-set derivation or
its attribution oracle did not model the real failure mode). If classified (b), the failure is
recorded but does not indict this cycle's fix.

**Checked at:** INTEGRATE/HANDOFF (pre-merge, best-effort — the trigger does not exist yet, so this
step can only confirm the reproduction ran clean) and again after the external merge, per the
verification design's "Environment-dependent item" note.
