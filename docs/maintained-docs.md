# Maintained Documents

> A registry of documents that must be kept up to date as the project evolves.

---

## Purpose

This file tracks which documents exist, who is responsible for maintaining
them, and when they should be updated. The Orchestrator AI (and Developer AI
for code-side docs) consults this registry during DIAGNOSE (step 7 — affected
docs) and again during VALIDATE (step 4 — maintained-docs check) to ensure
documentation stays in sync with code.

**Scope**: this registry covers the **host (orchestrator) repository only**.
Documents inside `services/librechat/` belong to the sub-repo and are tracked
by that sub-repo's own maintained-docs registry (when introduced). The
orchestrator does not modify sub-repo files — see
[`repo-boundary-rules.md`](repo-boundary-rules.md).

---

## Document Registry

### Host (Orchestrator) — `Munsik-Park/autoflow`

#### Operating manual

| Document | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| Main Operating Manual | `CLAUDE.md` | AutoFlow rules, role contracts, or flow control changes | Orchestrator AI / Human |
| Local Override Example | `CLAUDE.local.md.example` | Override mechanism guidance changes | Human |
| Project README | `README.md` | High-level overview or quickstart changes | Orchestrator AI |
| Documentation Index | `docs/INDEX.md` | New baseline/review/ADR docs are added, renamed, or routing changes | Orchestrator AI |
| Development Guideline | `docs/development-guideline.md` | Work-type, issue, ADR, PR, refactoring, testing, or documentation policy changes | Orchestrator AI / Human |

#### Methodology docs (`docs/`)

| Document | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| AutoFlow Guide | `docs/autoflow-guide.md` | Phase definitions, transitions, or regressions change (phase-body source of truth; `CLAUDE.md` routes to it via the Phase Playbook Loading Contract) | Orchestrator AI |
| DIAGNOSE Analysis Playbook | `docs/phases/analysis.md` | The DIAGNOSE 3-Phase analysis procedure (Phase A/B/3 isolation rules), the Type 1 / Type 2 necessity scoring rubric and PASS/FAIL disposition, or the structure- / confirmation-bias safeguards change (single source of truth for DIAGNOSE; issue #222) | Orchestrator AI |
| Evaluation System | `docs/evaluation-system.md` | Scoring categories, thresholds, or output format change | Orchestrator AI |
| Design Rationale | `docs/design-rationale.md` | New design decisions or rule justifications | Orchestrator AI / Human |
| Git Workflow | `docs/git-workflow.md` | Branch naming, commit rules, or PR flow changes | Orchestrator AI |
| Repo Boundary Rules | `docs/repo-boundary-rules.md` | Cross-repo coordination rules change | Orchestrator AI |
| Submodule Common Rules | `docs/submodule-common-rules.md` | Sub-repo Discussion Protocol or fork-and-PR contract changes | Orchestrator AI |
| Teammate Common Rules | `docs/teammate-common-rules.md` | Shared teammate behavior rules change | Orchestrator AI |
| Gate-Matching Standard | `docs/gate-matching-standard.md` | Hook command-matching rule (P1), unconditional-deny ordering (P2), or the udcim reference commit changes | Orchestrator AI |
| Doc-Invariant Registry | `docs/doc-invariant-registry.md` | The permanent-vs-cycle-scoped guard-lifecycle rule, the registry schema/runner contract, or the retired-guard disposition record changes (issue #951) | Orchestrator AI |
| Security Checklist | `docs/security-checklist.md` | New threat surface in host scope, or stack changes | Human |
| External Review Sequencing | `docs/external-review-sequencing.md` | The reviewer-facing merge-sequencing procedure (label, draft, dispatch, status check) or the host-only dispatch shortcut changes (issue #92) | Orchestrator AI |
| PR Body Guide | `docs/pr-body-guide.md` | New principles added or existing wording revised | Orchestrator AI / Human |
| Issue & PR Title Guide | `docs/title-guide.md` | Naming convention changed (format, type values, or examples revised) | Orchestrator AI / Human |
| Tool Delivery Contract | `docs/tool-delivery-contract.md` | Delivery-contract rules change (version pin, re-stamp policy, identity separation, manifest), or ADR-0015 is superseded | Orchestrator AI |
| Reviewer Backend Contract | `docs/reviewer-backend.md` | Reviewer-backend contract changes (backend table, config location, per-backend oracle, isolation basis), or the SETUP-GUIDE "Reviewer backend" prerequisites subsection changes (issue #979) | Orchestrator AI |
| Improvement Backlog | `docs/improvement-backlog.md` | A backlog item is promoted to an issue, resolved by other work (record the disposition on the item), a new methodology audit adds findings, or the cycle-driven PREFLIGHT cross-issue recurrence scan appends a candidate finding (#954) | Orchestrator AI / Human |
| This Document | `docs/maintained-docs.md` | New docs added or removed in host scope | Orchestrator AI |

#### ADRs (`docs/adr/`)

| Document | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| ADR README | `docs/adr/README.md` | ADR process, status values, or ADR list changes | Orchestrator AI / Human |
| ADR Template | `docs/adr/0000-adr-template.md` | ADR format changes | Orchestrator AI / Human |
| Handoff Authority ADR | `docs/adr/0003-autoflow-ends-at-handoff.md` | AutoFlow merge/handoff authority changes | Orchestrator AI / Human |
| ADR-Conformance Gate-Scoring ADR | `docs/adr/0016-adr-conformance-gate-scoring.md` | ADR-conformance gate-scoring policy (ARCHITECT/GATE:PLAN/GATE:QUALITY) changes | Orchestrator AI / Human |

> Service-specific documents (deployment runbooks, scripts, clients, infra, review baseline, epic breakdowns, and service ADRs 0002/0004–0014) have moved to `services/librechat-deploy`.

#### Setup

| Document | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| Setup Guide | `setup/SETUP-GUIDE.md` | Manual setup steps change | Orchestrator AI |
| Setup Script | `setup/init.sh` | Setup wizard input or output changes | Orchestrator AI |

#### Hooks

| Artifact | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| AutoFlow Gate Hook | `.claude/hooks/check-autoflow-gate.sh` | Gate enforcement logic or PASS thresholds change. **Any change to a numeric threshold (7.5 / 7 / 3), a gated phase key, the dual-language security key set, or the canonical `active` / `verdict` jq path MUST also update `tests/fixtures/gate-schema.json`** — otherwise the `tests/test-issue-223-schema-hook-contract.sh` contract test fails (by design — that is the schema↔hook drift guard, issue #223) | Orchestrator AI |
| State-Schema ↔ Gate-Hook Contract Test | `tests/test-issue-223-schema-hook-contract.sh` + `tests/fixtures/gate-schema.json` (canonical contract source: thresholds, gated phase keys, security keys, jq paths) + `tests/fixtures/autoflow-state-canonical.json` (canonical state-file fixture) | The contract between the runtime AutoFlow state JSON and the hook's hardcoded jq paths / thresholds changes — keep `gate-schema.json` as the single source of truth in lockstep with the hook; the test asserts equality in both directions (bash-3.2 portable) (issue #223) | Orchestrator AI |
| Schema-Hook Contract CI | `.github/workflows/schema-hook-contract.yml` | The contract test's trigger paths, the pinned `actions/checkout` commit SHA, or the advisory-enforcement framing changes; runs `tests/test-issue-223-schema-hook-contract.sh` on PRs touching the hook, the fixtures, the test, or `CLAUDE.md` (ADVISORY, mirrors `workflow-regression.yml`) (issue #223) | Orchestrator AI |

#### Methodology CI (`.claude/workflows/` deliberation scripts)

| Artifact | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| Workflow Regression CI | `.github/workflows/workflow-regression.yml` | The mock-runtime regression's trigger paths, the pinned `actions/checkout` / `actions/setup-node` commit SHAs or node version, the advisory-enforcement framing, or the gated subject (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`, `test/workflows/run.mjs`) changes (issue #153) | Orchestrator AI |
| Host-Purity DELTA Guard CI | `.github/workflows/host-purity-delta.yml` + `scripts/test/check-host-purity-delta.sh` + `tests/fixtures/host-purity-{tokens,paths}.txt` | The token denylist, the include/exclude/allow path policy, the scanner's diff-scoping contract (`--base`/`--head`, `--find-renames`, added-line-only), or the advisory-enforcement framing changes (issue #788) | Orchestrator AI |
| Plugin Package CI | `.github/workflows/plugin-package.yml` + `tests/plugin/verify-package.sh` + `tests/plugin/manual-scenarios.md` | The plugin package surface changes — `plugin/autoflow/**` (byte-copy parity set: hooks/agents/skills vs `.claude/` originals), `.claude-plugin/marketplace.json`, `plugin/autoflow/.claude-plugin/plugin.json`, the README settings-pin fence, the `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PROJECT_DIR}` anchoring contract, or the workflow's trigger paths / pinned `actions/checkout` SHA (issue #790) | Orchestrator AI |
| Thin Root Layer Contract | `docs/thin-root-layer.md` + `setup/thin-root-layer/{claude-md-shim.md,settings-pin.json}` + `tests/plugin/verify-thin-root-layer.sh` | The thin-root residue set, the `@import` shim marker contract or convention path, the settings-pin form / README-fence parity, the `SKILL-SUBSTITUTION`/`WORKFLOW` residence verdict, or the `CLAUDE_CODE_*` env contract changes (issue #791) | Orchestrator AI |
| Dummy-Target E2E CI | `.github/workflows/e2e-dummy-target.yml` + `tests/plugin/verify-e2e-dummy-target.sh` + `tests/plugin/manual-scenarios-797.md` + `tests/fixtures/e2e-bundle-purity-baseline.txt` | The install-into-target composition surface changes — `setup/init.sh --target` behavior, `setup/manifest.json` artifact set, `drift-check.sh` classes, the gate hook's scores-gated admit/deny contract (delivery-path resolution is Plugin Package CI's AC4), `scripts/handoff/create-host-pr.sh` argv, or the bundle-purity ratchet baseline (burns down via epic #785 S11a/S11b; converges to an absolute scan) (issue #797) | Orchestrator AI |

#### HANDOFF automation

| Artifact | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| Host PR Template | `.github/pull_request_template.md` | Host PR body shape, sub-repo merge dependency checklist, or the `<!-- HOST-CLOSE-LINE -->` marker contract changes (issue #92) | Orchestrator AI |
| Host PR Creation Script | `scripts/handoff/create-host-pr.sh` | The `--draft` / `--no-subrepo-dep` / label contract or the body-file rendering contract changes (issue #92) | Orchestrator AI |
| CI-Green Confirm Script | `scripts/handoff/confirm-ci-green.sh` (+ `tests/test-issue-25-confirm-ci-green.sh`, `tests/test-issue-30-confirm-ci-green.sh`) | The mergeable-precheck / early-block / finite-poll / exit-code contract (`0`/`10`/`11`/`12`/`13`/`14`/`64`), the `CI_POLL_TIMEOUT_SECS`/`CI_POLL_INTERVAL_SECS` tunables, or the rollup latest-per-identity dedup classification (issue #30) change (issue #25) | Orchestrator AI |

### Sub-repo (`services/librechat`)

> **N/A under zero-submodule topology (see #798).** The `services` submodule was
> detached in #798; `claude-autoflow` is now single-repo, so this host-owned
> carve-out index has no live sub-repo to track here. The section is retained as
> a historical record of the pre-#798 nesting era; re-attribution of tracking
> ownership is deferred to #800 (S12).

**Upstream LibreChat 자체 문서**는 sub-repo의 자체 registry에서 관리한다
(아직 도입 전). 이 영역은 [`repo-boundary-rules.md`](repo-boundary-rules.md)에
따라 sub-repo AI의 own scope이다.

**Carve-out 문서** — 서비스 도메인(멀티테넌시 × 회계 owner, 파일 가시성
같은 service-specific 책임 영역)을 sub-repo 안에 두는 host-책임 문서 — 는
host registry에 인덱스 형태로 등록한다. orchestrator AI가 이 carve-out
문서의 유지보수를 책임진다.

| Document | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| File visibility (`tenantId` × `visibility`) | `services/librechat/docs/file-visibility.md` | The three-axis ACL evaluation order, the `evaluateFileVisibilityAccess` source of truth, or the legacy lazy-coercion contract changes (issue #116) | Orchestrator AI |
| Ownership and isolation (`tenantId` × accounting owner) | `services/librechat/docs/ownership-and-isolation.md` | The `tenantId` / `Balance.user` / `OrganizationBalance.organizationId` concept definitions, the #101 ARCHITECT Q3 cardinality (1:N tenant:org, N:M user:org-within-tenant, 1:1 org:orgBalance), the Q4 schema decision (separate `OrganizationBalance` collection, not polymorphic Balance), or the `allocation_transfer` transaction extension fields change (issues #71, #101, #162) | Orchestrator AI |
| Model resolution (new-conversation model precedence) | `services/librechat/docs/model-resolution.md` | The new-conversation model precedence rows (esp. `preferences.defaultModel` via `preferredModelForNewConvo` / `buildDefaultConvo.preferredModel`), the Extended-Thinking-is-orthogonal rule, or the title-generation `titleModel` decision (issue #532) | Orchestrator AI |
| Date-range boundary semantics (org endpoints) | `services/librechat/docs/org-date-range-boundaries.md` | The Family 1 (`$lt` exclusive) / Family 2 (`$lte` inclusive) endpoint classification, the client-seam end-bound normalization contract (canonical `toExclusiveEndBound` import from `~/utils/orgDateRange`), or a new date-only consumer surface changes (issue #868) | Orchestrator AI |

---

## Update Protocol

### When to Check

- **DIAGNOSE step 7** — identify affected docs based on the issue.
- **VALIDATE step 4** — confirm impacted docs are updated.
- **LAND** — the PR description lists which docs were updated.

### How to Update

1. Identify which documents are affected by the change.
2. Update the document content.
3. Include the doc update in the same PR as the code change.
4. Note in the PR description which docs were updated.

### What NOT to Do

- Do not create new documents without adding them to this registry.
- Do not remove documents without updating this registry.
- Upstream LibreChat 코드 영역(`services/librechat/` 하위)은 sub-repo AI가
  책임진다 — [`repo-boundary-rules.md`](repo-boundary-rules.md)의 own scope.
  orchestrator는 sub-repo 안에 두는 host-책임 carve-out 문서(`Sub-repo` 섹션
  인덱스 참조)에 한해서만 작성·유지보수한다.

---

## Sync Rules

- **KO translations**: any update to an EN doc that has a KO counterpart triggers a corresponding KO update.
- **README ↔ docs**: high-level summaries in `README.md` must not contradict detailed rules in `docs/*.md`.
