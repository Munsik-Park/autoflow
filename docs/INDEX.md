# Documentation Index

Use this page as the first stop before assigning or implementing an issue.
It links the current project baseline, existing operating manuals, and the
review outputs that decide whether an issue is ready for implementation.

## Issue-number provenance

This framework was generalized out of a predecessor repository,
`connev-llm/claude-autoflow` (archived, private). Bare issue references in the
range `#600`–`#999` — in the playbooks, ADRs, and shipped scripts — point at
that tracker and are kept as historical provenance for the rule they sit
beside; they are not navigable from a consuming project and do not resolve in
`Munsik-Park/autoflow`, whose own issues are numbered from `#1`. Where a
predecessor reference carried an open decision, the decision is re-recorded in
this repository (e.g. ADR-0015 D1 > Superseding note).

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
| [Improvement Backlog](improvement-backlog.md) | Durable registry of verified audit findings and their dispositions — the shared future-improvement backlog. |
| [Repo Boundary Rules](repo-boundary-rules.md) | Host/submodule/cross-repo responsibility boundaries. |
| [External Review Sequencing](external-review-sequencing.md) | Merge sequencing and external review flow. |
| [Tool Delivery Contract](tool-delivery-contract.md) | Version pin, CLAUDE.md re-stamp, target-identity separation, and install-manifest rules for AutoFlow as a consumed tool (epic #785 S1; ADR-0015). |
| [Reviewer Backend Contract](reviewer-backend.md) | HANDOFF external-reviewer backend abstraction: inputs/obligations, codex default + `claude -p` opt-in table, config location, per-backend oracle, isolation basis (issue #979). |
| [Issue Proposal Contract](issue-proposal.md) | Draft grammar and filing procedure for new issues: the `gh issue create` deny, the `scripts/issue/create-issue.sh` wrapper that re-runs the duplicate search, and the operator prompt (issue #96). |
| [Security Checklist](security-checklist.md) | Security review checklist for this host scope. |

## Quick Routing

| If the issue touches... | Read first |
| --- | --- |
| AutoFlow rules, gates, agent roles, or hook behavior | `CLAUDE.md`, `docs/design-rationale.md`, `docs/phases/analysis.md`, `docs/adr/0016-adr-conformance-gate-scoring.md`, `docs/adr/0017-teammate-removal-feasibility.md`, `docs/adr/0018-verification-depth-justification.md`, `docs/adr/0019-scope-fit-verification-policy.md`, `docs/adr/0020-acceptance-criterion-authority.md` |
| Sub-repo implementation (multi-repo instances) | `docs/repo-boundary-rules.md` |
| Issue decomposition or readiness | `docs/development-guideline.md` |
| Filing a new issue | `docs/issue-proposal.md` |
| Tool distribution, install/upgrade, or version pinning | `docs/tool-delivery-contract.md`, `docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md` |
| External review backend (codex/claude), step-6 review mechanics | `docs/reviewer-backend.md`, `docs/external-review-sequencing.md` |

