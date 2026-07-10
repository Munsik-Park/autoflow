# Issue #847 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

This is the **live (ENV-dependent) half** of the two-layer split
(`.autoflow/issue-847-feature-design.md` §3 DCR-1): the trigger predicate
(`git diff --name-only <base>...HEAD | grep -E '<TRIGGER_REGEX>'`) is
deterministic and in-repo-verifiable, auto-tested by
`tests/test-issue-847-doc-assertions.sh`. The verification bundle
(a)/(b)/(c) itself exercises a **target service repo's** deploy scripts, CI
config, and host route — surfaces this single-repo framework repo does not
own (zero submodules, no `deploy-*.sh`, no host route). Their live
effectiveness is **not** auto-tested here; it is delegated to this file per
the verification design (`.autoflow/issue-847-verification-design.md` §4) and
surfaced through VALIDATE item 6.

**Explicitly excluded from this cycle's gates:** these scenarios are
tracking items for the **next** target-repo INTEGRATE cycle whose diff
matches the deploy/CI-path trigger, not manual tests the user must run now.
They do not block this cycle's VERIFY, VALIDATE, or GATE:QUALITY.

Run each scenario against a real target service repo (the `#774–#781`
class — e.g. `llmroute` / `librechat-deploy`) at the next INTEGRATE cycle
whose diff trips the trigger condition documented in
`docs/autoflow-guide.md` > INTEGRATE > `### Deploy/CI-path conditional
verification`.

---

## BUNDLE-LIVE-(a) — Deploy-script dry-run + recursive submodule init

**Trigger class:** diff touches `.gitmodules` or `deploy-*.sh`.
**Regression witness:** #774 (deploy-librechat.sh submodule not updated),
#778 (nested container path).

**Steps:**

1. On the target repo, confirm the diff for this cycle touches `.gitmodules`
   and/or a `deploy-*.sh` path.
2. Run `git submodule update --init --recursive` and confirm it resolves the
   **current** submodule pointers (no stale/dangling pointer).
3. Run the target's `deploy-*.sh` in dry-run / read-only mode (`--dry-run`,
   per PR #779 commits `08fa20c`/`4531d63` — gating host fetch so the
   dry-run is truly read-only).
4. Confirm the dry-run resolves the deploy path against the submodule
   pointers from step 2 without error, and that its reported target paths
   match the current submodule layout (catches the #774/#778 class: a
   deploy script referencing a submodule path that moved or was renamed).

**Pass condition:** the dry-run completes cleanly and its resolved paths
match the post-`--init --recursive` submodule layout.

**Fail condition / signal to re-open:** the dry-run errors, or resolves a
path that does not match the current submodule layout — this is a live
#774/#778-class regression; file it as its own issue rather than re-litigating
this cycle's already-settled INTEGRATE-rule scope.

---

## BUNDLE-LIVE-(b) — CI-config static validation

**Trigger class:** diff touches `.github/workflows/**` or `Jenkinsfile`.
**Regression witness:** #776 (Jenkinsfile Validate-Compose nested `.env`).

**Steps:**

1. On the target repo, confirm the diff for this cycle touches
   `.github/workflows/*` and/or a `Jenkinsfile`.
2. For a changed `.github/workflows/*.yml`: run `actionlint` (or the
   target's equivalent workflow linter / YAML-schema check) against the
   changed file.
3. For a changed `Jenkinsfile`: run the target's `jenkins
   declarative-linter` (or equivalent static Jenkinsfile validator).
4. Confirm the linter reports zero errors, and specifically that any nested
   `.env` / build-arg reference inside the CI config resolves to an
   existing path (catches the #776 class).

**Pass condition:** the CI-config linter passes cleanly on the changed
file(s).

**Fail condition / signal to re-open:** the linter reports an error, or a
nested `.env`/path reference inside the CI config does not resolve — a live
#776-class regression; file separately.

---

## BUNDLE-LIVE-(c) — Landing/host routing smoke check

**Trigger class:** diff touches `.env`, `.env.*`, or otherwise the diff's
CI-config change affects build wiring for a deployed host/landing route.
**Regression witness:** #781 (production build wiring).

**Steps:**

1. On the target repo, confirm the diff for this cycle touches an
   `.env`/`.env.*` path or a CI-config change that affects the built
   host/landing route's wiring.
2. Deploy (or redeploy in a staging environment) the built host/landing
   route per the target's normal deploy procedure.
3. Send a smoke request against the built host/landing route (health check
   or a routing-reachability check — e.g. `curl -sf https://<host>/` or the
   target's health endpoint).
4. Confirm the route responds with a healthy/expected status, and that no
   build-arg/env wiring error surfaces in the deploy logs (catches the #781
   class: production build wiring silently broken by an env change that
   passed dev-compose INTEGRATE).

**Pass condition:** the smoke request succeeds and no build-wiring error
appears in the deploy logs.

**Fail condition / signal to re-open:** the smoke request fails, or a
build-arg/env wiring error surfaces — a live #781-class regression; file
separately.

---

## Evidence recording

Record the observation (target repo, cycle/issue number, which of (a)/(b)/(c)
fired, PASS/FAIL per item) as a 1-line note in that target cycle's PR body or
decision ledger — this is the field-effectiveness confirmation of the
INTEGRATE deploy/CI-path rule this issue ships (verification design §4 /
feature design §3 DCR-1, two-layer split). This does not gate the current
cycle's VALIDATE/VERIFY/GATE:QUALITY — the rule + wiring ship now; the
bundle's live effectiveness is observed at the next matching target-repo
INTEGRATE.
