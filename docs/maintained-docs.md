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
| Evaluation System | `docs/evaluation-system.md` | Scoring categories, thresholds, the pre-scoring evaluation procedure, or output format change | Orchestrator AI |
| Teammate Contracts | `docs/teammate-contracts.md` | Role contract or evaluation procedure changes | Orchestrator AI |
| Design Rationale | `docs/design-rationale.md` | New design decisions or rule justifications | Orchestrator AI / Human |
| Git Workflow | `docs/git-workflow.md` | Branch naming, commit rules, or PR flow changes | Orchestrator AI |
| Repo Boundary Rules | `docs/repo-boundary-rules.md` | Cross-repo coordination rules change | Orchestrator AI |
| Submodule Common Rules | `docs/submodule-common-rules.md` | Sub-repo Discussion Protocol or fork-and-PR contract changes | Orchestrator AI |
| Teammate Common Rules | `docs/teammate-common-rules.md` | Shared teammate behavior rules change | Orchestrator AI |
| Gate-Matching Standard | `docs/gate-matching-standard.md` | Hook command-matching rule (P1), unconditional-deny ordering (P2), declared-role spawn classification (P3), or the udcim reference commit changes | Orchestrator AI |
| Doc-Invariant Registry | `docs/doc-invariant-registry.md` | The permanent-vs-cycle-scoped guard-lifecycle rule, the registry schema/runner contract (including the `section_kind` anchor kinds and the `--self-test` mutation-teeth mode), or a retired-guard disposition table changes (issues #951, #76, #85) | Orchestrator AI |
| Security Checklist | `docs/security-checklist.md` | New threat surface in host scope, or stack changes | Human |
| External Review Sequencing | `docs/external-review-sequencing.md` | The reviewer-facing merge-sequencing procedure (label, draft, dispatch, status check) or the host-only dispatch shortcut changes (issue #92) | Orchestrator AI |
| PR Body Guide | `docs/pr-body-guide.md` | New principles added or existing wording revised | Orchestrator AI / Human |
| Issue & PR Title Guide | `docs/title-guide.md` | Naming convention changed (format, type values, or examples revised) | Orchestrator AI / Human |
| Tool Delivery Contract | `docs/tool-delivery-contract.md` | Delivery-contract rules change (version pin, re-stamp policy, identity separation, manifest), or ADR-0015 is superseded | Orchestrator AI |
| Reviewer Backend Contract | `docs/reviewer-backend.md` | Reviewer-backend contract changes (backend table, config location, per-backend oracle, isolation basis), or the SETUP-GUIDE "Reviewer backend" prerequisites subsection changes (issue #979) | Orchestrator AI |
| Improvement Backlog | `docs/improvement-backlog.md` | A backlog item is promoted to an issue, resolved by other work (record the disposition on the item), or a new methodology audit adds findings | Orchestrator AI / Human |
| This Document | `docs/maintained-docs.md` | New docs added or removed in host scope | Orchestrator AI |

#### ADRs (`docs/adr/`)

| Document | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| ADR README | `docs/adr/README.md` | ADR process, status values, or ADR list changes | Orchestrator AI / Human |
| ADR Template | `docs/adr/0000-adr-template.md` | ADR format changes | Orchestrator AI / Human |
| Handoff Authority ADR | `docs/adr/0003-autoflow-ends-at-handoff.md` | AutoFlow merge/handoff authority changes | Orchestrator AI / Human |
| ADR-Conformance Gate-Scoring ADR | `docs/adr/0016-adr-conformance-gate-scoring.md` | ADR-conformance gate-scoring policy (ARCHITECT/GATE:PLAN/GATE:QUALITY) changes | Orchestrator AI / Human |
| Teammate-Removal Feasibility ADR | `docs/adr/0017-teammate-removal-feasibility.md` | The teammate-removal verdict or its migration conditions C1–C8 change, or the pilot (C7) reverses the verdict | Orchestrator AI / Human |
| Verification-Depth Justification ADR | `docs/adr/0018-verification-depth-justification.md` | The verification-depth obligation, its justification form, or the GATE:PLAN `Scope` widening changes | Orchestrator AI / Human |
| Scope-Fit Verification Policy ADR | `docs/adr/0019-scope-fit-verification-policy.md` | The interim-run scope, the suite-grained inheritance key, the VALIDATE coverage floor, or the evaluator execution discipline changes | Orchestrator AI / Human |

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
| Suite Governance | `scripts/test/suite-manifest.sh` + `scripts/test/invocation-scan.sh` + `scripts/test/check-suite-manifest.sh` + `scripts/test/check-suite-leaf.sh` + `tests/lib/harness-pins.sh` | The suite header grammar (`ci-subject` / `lane` / `retire-with` / `cycle-arm` / `budget-secs`), the subject-set enumeration or its exclusions, `SUITE_BUDGET_CEILING_SECS`, the invocation relation's single home — the command-position admission rule, the two length-preserving views, or the workflow step record — the leaf rule's closed shape table (D1–D5 / I1–I4), the shared harness ok-count pin, or the governed step-id value rules — the `s-<basename>` value conformance, the governed-set basename-collision lint, or the id derivation's single home (`suite_step_id`) — change (issues #103, #108) | Orchestrator AI |
| Suite Selection and Execution | `scripts/test/select-suites.sh` + `scripts/test/run-suites.sh` + `scripts/test/check-step-reconciliation.sh` | The selection predicate, the push / empty-delta full-set rule, the fail-loud base contract (an unresolvable base OR an absent / empty `ci-subject` header), the reconciler's evidence precondition or its out-of-job accounting, the runner's de-duplication or `timeout`-based budget enforcement, the CI `select` step's output shape, the sentinel-delimited `if:` guard / step-`id` convention the reconciliation reads, the reconciler's cascade grading (the `--job-status` arm, the outcome-map arm, or the `CASCADE-SKIP` class and its count), the runner's per-suite output capture and full replay on FAIL / TIMEOUT, or the valued-flag fail-closed contract (`--root` / `--base` / `--event` / `--selected` / `--steps` / `--governed` / `--job-status`) changes, the selector's boolean `--include-worktree` flag — its default-off opt-in, the committed∪uncommitted union in `resolve_delta`, its widening-only property against the full-set / BLOCK / push-event rules, or the set of call sites that pass it — changes, or the runner's explicit-plan flag `--selected <path>` — its whole-plan membership validation against `suite_enumerate`, its mutual exclusion with `--all`, or the deliberate absence of a stdin form — changes (issues #103, #108, #112) | Orchestrator AI |
| Scope-Fit Verdict Inheritance | `scripts/test/suite-coverage.sh` + `docs/adr/0019-scope-fit-verification-policy.md` | The resolver's resolution order (out-of-tree declaration, dirty worktree, whole-tree fast path, coverage fold, reach test, non-candidate record), its candidate-set source — the `--include-worktree` selection call that makes the candidate set the committed delta unioned with the uncommitted worktree, and the reach call that deliberately omits the flag — its stdout/stderr contract or exit codes, the declared per-suite reason vocabulary — the `reason-tokens` block in the resolver's header, which is that vocabulary's one normative home, every other passage carrying these tokens being derived from it and held to it by `tests/test-suite-coverage-agreement.sh` — the BLOCK-degrades-to-executing fallback, the `--candidates selection|all` modes, the entry-admission value gate that decides which parsed green-tree entries reach the selectable arrays (`worktree` admits only `clean`; any other value is a malformed entry and BLOCKs), the ledger-derived head validation, the `# out-of-tree-inputs:` header field or its presence obligation, or the phase-step idiom's exit-status guard changes (issue #112) | Orchestrator AI |
| Dummy-Target E2E CI | `.github/workflows/e2e-dummy-target.yml` + `tests/plugin/verify-e2e-dummy-target.sh` + `tests/plugin/manual-scenarios-797.md` + `tests/fixtures/e2e-bundle-purity-baseline.txt` | The install-into-target composition surface changes — `setup/init.sh --target` behavior, `setup/manifest.json` artifact set, `drift-check.sh` classes, the gate hook's scores-gated admit/deny contract (delivery-path resolution is Plugin Package CI's AC4), `scripts/handoff/create-host-pr.sh` argv, or the bundle-purity ratchet baseline (burns down via epic #785 S11a/S11b; converges to an absolute scan) (issue #797) | Orchestrator AI |

#### HANDOFF automation

| Artifact | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| Host PR Template | `.github/pull_request_template.md` | Host PR body shape, sub-repo merge dependency checklist, or the `<!-- HOST-CLOSE-LINE -->` marker contract changes (issue #92) | Orchestrator AI |
| Host PR Creation Script | `scripts/handoff/create-host-pr.sh` | The `--draft` / `--no-subrepo-dep` / label contract or the body-file rendering contract changes (issue #92) | Orchestrator AI |
| CI-Green Confirm Script | `scripts/handoff/confirm-ci-green.sh` (+ `tests/test-issue-25-confirm-ci-green.sh`, `tests/test-issue-30-confirm-ci-green.sh`) | The mergeable-precheck / early-block / finite-poll / exit-code contract (`0`/`10`/`11`/`12`/`13`/`14`/`64`), the `CI_POLL_TIMEOUT_SECS`/`CI_POLL_INTERVAL_SECS` tunables, or the rollup latest-per-identity dedup classification (issue #30) change (issue #25) | Orchestrator AI |
| Phase-Marker Emitter Script | `scripts/canary/emit-phase-marker.sh` (+ `tests/test-issue-35-phase-marker.sh`) | The four-flag CLI (`--issue`/`--cycle`/`--phase`/`--event`), the `.autoflow/issue-{N}-phases.jsonl` record schema (`issue`/`cycle`/`phase`/`event`/`ts`/`schema_version`), the single-`ts`-producer contract, or the stdout `path:line` anchor contract changes (issue #35) | Orchestrator AI |
| Ledger Entry-ID Script | `scripts/ledger/ledger-entry-id.sh` (+ `tests/test-ledger-entry-id.sh`) | The `next <ledger> <O\|F>` / `check <ledger>` command surface, the level-2 entry-ID grammar or writer→namespace mapping (`CLAUDE.md` > Decision Ledger > *Entry identifier*), the exit-code contract (`0`/`1`/`2`), the `unidentified-entry` sanitisation bound (control-char strip, 117+`...` truncation), or the hook's Section-1c advisory wiring changes (issue #97) | Orchestrator AI |

#### Issue creation

| Artifact | Path | Update When | Maintainer |
|----------|------|-------------|------------|
| Issue Proposal Contract | `docs/issue-proposal.md` + `scripts/issue/create-issue.sh` (+ `tests/test-issue-create-gate.sh`, `tests/test-issue-create-wrapper.sh`) | The draft grammar (`## Title` / `## Grounds` / `## Duplicate check` / `## Body`), the `.autoflow/` top-level containment rule, the term-derivation rule (leading-tag strip, ASCII-range lowercase, ASCII-punctuation separators with non-ASCII bytes never separating, the two locale-free codepoint floors 4/2, dedup, the 8-term cap) and its fixed-constant status, the `--state all` per-term query and the `--limit 100` truncation refusal, the candidate-disposition invariant, the exit-code contract (`0`/`64`/`65`/`70`), the `issue-<N>-proposal.md` rename, or the hook's `gh issue create` deny changes (issue #96) | Orchestrator AI |

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

The four carve-out rows this index held were removed in #103 — after the #798
detach the paths they listed no longer exist on disk — and the Git history
remains the record of what was tracked.

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
