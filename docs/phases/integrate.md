# INTEGRATE — Integration Verification

> Phase playbook for INTEGRATE. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

INTEGRATE is the part of U6 Delivery
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1) that looks at the change
as the system runs it, beyond what BUILD verified per acceptance criterion.

- **What is asked**: the delivered change is shown to work at the level above its own tests — the
  project's integration suite, a smoke test, or the built system across its sub-repos. Which checks that takes, and how they are run, is the orchestrator's, the way
  the target runs them ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification
  and Tools).
- **Result owed**: one line per check — its command and the summary line read from its log, the
  log kept under `.autoflow/issue-{N}-local/` — or the no-op line below. A check that was not run
  is `not-run`, never `passed`.
- **Failure**: INTEGRATE FAIL → BUILD — fixed `impl` class: a BUILD unit re-run with the failing
  check → exit check → AUDIT ([BUILD](build.md) > *Re-entry*).

Cautions:

- A project with no integration layer records `INTEGRATE: no-op (no integration suite)`. That is
  a stated no-op, not a skipped check.
- In a project with sub-repos the system is built in the dev environment and what crosses sub-repos
  is what is verified: each affected sub-repo builds (for example
  `docker compose -f docker-compose.dev.yml up -d --build <services>`), each service's health check
  passes, the functional integration tests pass, and the cross-cutting concerns the change touches
  (auth, network ingress) are looked at.

## Deploy/CI-path conditional verification

A **diff-path-conditional** requirement keyed on the class of surface being integrated. It applies to every project; a class the project does not ship resolves to a defined no-op.

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD main`). The condition **fires** iff any changed path matches the trigger glob set:

| Class | Glob(s) |
|---|---|
| Submodule layout | `.gitmodules` |
| CI config | `.github/workflows/**`, `**/Jenkinsfile`, `Jenkinsfile` |
| Deploy scripts | `deploy-*.sh`, `**/deploy-*.sh` |
| Env / build-arg | `.env`, `.env.*`, `**/.env`, `**/.env.*` |

Stated as one command (the frozen predicate):

```
git diff --name-only <base>...HEAD \
  | grep -E '(^|/)\.gitmodules$|(^|/)\.github/workflows/|(^|/)Jenkinsfile$|(^|/)deploy-[^/]*\.sh$|(^|/)\.env(\.[^/]*)?$'
```

Non-empty ⇒ the verification bundle below is owed, each item PASS or FAIL. Empty ⇒ record `INTEGRATE deploy/CI-path: no-op (diff touched no deploy/CI-path surface)` — a defined no-op, not a discretionary skip.

**Verification bundle** (owed only when the predicate's output is non-empty; each item is itself a defined no-op when the target ships no such surface):

- **(a) Deploy-script dry-run, incl. recursive submodule init** — the target's `deploy-*.sh` in dry-run (`--dry-run` / read-only) with `git submodule update --init --recursive`, confirming the deploy path resolves the current submodule pointers. *No-op* when the target ships no deploy script.
- **(b) CI-config static validation** — a lint / schema check of the changed CI file itself (`.github/workflows/*` via `actionlint` / YAML-schema; `Jenkinsfile` via the target's `jenkins declarative-linter` or equivalent). *No-op* when no CI file changed.
- **(c) Landing/host routing smoke check** — a smoke request against the built host / landing route (health / routing reachability). *No-op* when the target exposes no host / landing route.

A bundle item that misses a real breakage on the target where it runs is filed back as an issue. A bundle item that fails is an **INTEGRATE FAIL → BUILD** (`impl` class; the re-run above).
