# Documentation Index

Use this page as the first stop before assigning or implementing an issue.
It links the current project baseline, existing operating manuals, and the
review outputs that decide whether an issue is ready for implementation.

## Decision and Issue Readiness

| Document | Use When |
| --- | --- |
| [Development Guideline](development-guideline.md) | You need the work-type, issue, ADR, PR, refactoring, test, and docs policy. |
| [ADR README](adr/README.md) | You need to create, read, or update ADRs. |
| [ADR Template](adr/0000-adr-template.md) | You need a new ADR draft. |

## Existing Operating Documents

These documents remain the operating source of truth. The review baseline does
not replace them.

| Document | Role |
| --- | --- |
| [CLAUDE.md](../CLAUDE.md) | AutoFlow operating manual and phase router. |
| [AutoFlow Guide](autoflow-guide.md) | Phase-by-phase lifecycle details. |
| [DIAGNOSE Analysis Playbook](phases/analysis.md) | Existing issue analysis and necessity-evaluation procedure. |
| [Design Rationale](design-rationale.md) | Why the AutoFlow rules exist. |
| [Maintained Documents](maintained-docs.md) | Registry of documents that must stay current. |
| [Improvement Backlog](improvement-backlog.md) | Durable registry of verified audit findings and their dispositions — the shared future-improvement backlog. |
| [Repo Boundary Rules](repo-boundary-rules.md) | Host/submodule/cross-repo responsibility boundaries. |
| [External Review Sequencing](external-review-sequencing.md) | Merge sequencing and external review flow. |
| [Doc-Invariant Registry](doc-invariant-registry.md) | Guard-lifecycle rule for the permanent doc-invariant registry (`tests/fixtures/doc-invariants.json`): two-lane partition, retirement, and promotion. |
| [Tool Delivery Contract](tool-delivery-contract.md) | Version pin, CLAUDE.md re-stamp, target-identity separation, and install-manifest rules for AutoFlow as a consumed tool (epic #785 S1; ADR-0015). |
| [Reviewer Backend Contract](reviewer-backend.md) | HANDOFF external-reviewer backend abstraction: inputs/obligations, codex default + `claude -p` opt-in table, config location, per-backend oracle, isolation basis (issue #979). |
| [Security Checklist](security-checklist.md) | Security review checklist for this host scope. |

## Quick Routing

| If the issue touches... | Read first |
| --- | --- |
| AutoFlow rules, gates, agent roles, or hook behavior | `CLAUDE.md`, `docs/design-rationale.md`, `docs/phases/analysis.md`, `docs/adr/0016-adr-conformance-gate-scoring.md` |
| Sub-repo implementation (multi-repo instances) | `docs/repo-boundary-rules.md` |
| Issue decomposition or readiness | `docs/development-guideline.md` |
| Tool distribution, install/upgrade, or version pinning | `docs/tool-delivery-contract.md`, `docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md` |
| External review backend (codex/claude), step-6 review mechanics | `docs/reviewer-backend.md`, `docs/external-review-sequencing.md` |

