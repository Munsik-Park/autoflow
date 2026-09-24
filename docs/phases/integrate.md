# INTEGRATE — Integration Verification

> Phase playbook for INTEGRATE. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

In a single-repo deployment (target-centric — the default), INTEGRATE runs the project-level integration test suite (or a smoke test). A project with no integration layer reports "INTEGRATE: no-op (single-repo / no integration suite)" in the completion notes — this is a registry-driven no-op, not a discretionary skip.

In a multi-repo deployment (one or more submodules), INTEGRATE builds the system in the dev environment and verifies cross-sub-repo behavior:

```
1. Build all affected sub-repos in dev (e.g., docker compose -f docker-compose.dev.yml up -d --build <services>).
2. Health checks pass for each service.
3. Functional integration tests pass.
4. Cross-cutting concerns (auth, network ingress, etc.) verified.
```

**Failure**: INTEGRATE FAIL → GREEN — fixed `impl` class → VERIFY step 1 → REFINE → VALIDATE; existing GREEN↔VERIFY round-trip rules apply.

## Deploy/CI-path conditional verification

This check adds a **diff-path-conditional** gate keyed on the class of surface being integrated. It is topology-independent — it lives outside the single-repo / multi-repo branch above and applies in both; in a single-repo target the submodule / deploy classes resolve to a defined no-op.

**Trigger predicate (deterministic).** Let the diff be `git diff --name-only <base>...HEAD` (base = `git merge-base HEAD main`). The condition **fires** iff any changed path matches the trigger glob set:

| Class | Glob(s) |
|---|---|
| Submodule layout | `.gitmodules` |
| CI config | `.github/workflows/**`, `**/Jenkinsfile`, `Jenkinsfile` |
| Deploy scripts | `deploy-*.sh`, `**/deploy-*.sh` |
| Env / build-arg | `.env`, `.env.*`, `**/.env`, `**/.env.*` |

Stated as an enforceable one-liner (the frozen predicate):

```
git diff --name-only <base>...HEAD \
  | grep -E '(^|/)\.gitmodules$|(^|/)\.github/workflows/|(^|/)Jenkinsfile$|(^|/)deploy-[^/]*\.sh$|(^|/)\.env(\.[^/]*)?$'
```

Non-empty ⇒ the verification bundle below is a **mandatory PASS/FAIL gate** for this cycle. Empty ⇒ record `INTEGRATE deploy/CI-path: no-op (diff touched no deploy/CI-path surface)` — a defined no-op, not a discretionary skip.

**Verification bundle** (runs only when the trigger is non-empty; each item is itself a defined no-op when the target ships no such surface):

- **(a) Deploy-script dry-run, incl. recursive submodule init** — run the target's `deploy-*.sh` in dry-run (`--dry-run` / read-only) with `git submodule update --init --recursive`, confirming the deploy path resolves the current submodule pointers. *No-op* when the target ships no deploy script.
- **(b) CI-config static validation** — lint / schema-check the changed CI file itself (`.github/workflows/*` via `actionlint` / YAML-schema; `Jenkinsfile` via the target's `jenkins declarative-linter` or equivalent). *No-op* when no CI file changed.
- **(c) Landing/host routing smoke check** — a smoke request against the built host / landing route (health / routing reachability). *No-op* when the target exposes no host / landing route.

A bundle item that misses a real breakage on the target where it runs is filed back as an issue.

**Failure**: a bundle item that fails is an **INTEGRATE FAIL → GREEN** (`impl` class; existing GREEN↔VERIFY round-trip rules apply).
