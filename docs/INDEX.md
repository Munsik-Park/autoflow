# Documentation Index

Use this page as the first stop before assigning or implementing an issue.
It routes two document classes that live in separate trees (ADR-0015 D1 >
Superseding note 2026-09-16): the **usage documents** an agent reads and
follows while a cycle runs — the source of the rules, stamped to every target
— and the **design and decision records** under `docs/records/`, read for a
decision's history and grounds, the source of no rule, and never stamped.

## Issue-number provenance

This framework was generalized out of a predecessor repository,
`connev-llm/claude-autoflow` (archived, private). Bare issue references in the
range `#600`–`#999` — in the playbooks, ADRs, and shipped scripts — point at
that tracker and are kept as historical provenance for the rule they sit
beside; they are not navigable from a consuming project and do not resolve in
`Munsik-Park/autoflow`, whose own issues are numbered from `#1`. Where a
predecessor reference carried an open decision, the decision is re-recorded in
this repository (e.g. ADR-0015 D1 > Superseding note).

## Usage documents

### Decision and Issue Readiness

| Document | Use When |
| --- | --- |
| [Development Guideline](development-guideline.md) | You need the work-type, issue, ADR, PR, refactoring, test, and docs policy. |

### Existing Operating Documents

These documents are the operating source of truth.

| Document | Role |
| --- | --- |
| [CLAUDE.md](../CLAUDE.md) | AutoFlow operating manual and phase router. |
| [AutoFlow Guide](autoflow-guide.md) | Phase-by-phase lifecycle details. |
| [DIAGNOSE Analysis Playbook](phases/analysis.md) | Existing issue analysis and necessity-evaluation procedure. |
| [Repo Boundary Rules](repo-boundary-rules.md) | Host/submodule/cross-repo responsibility boundaries. |
| [External Review Sequencing](external-review-sequencing.md) | Merge sequencing and external review flow. |
| [Tool Delivery Contract](tool-delivery-contract.md) | Version pin, CLAUDE.md re-stamp, target-identity separation, and install-manifest rules for AutoFlow as a consumed tool (epic #785 S1; ADR-0015). |
| [Reviewer Backend Contract](reviewer-backend.md) | HANDOFF external-reviewer backend abstraction: inputs/obligations, codex default + `claude -p` opt-in table, config location, per-backend oracle, isolation basis (issue #979). |
| [Issue Proposal Contract](issue-proposal.md) | Draft grammar and filing procedure for new issues: the `gh issue create` deny, the `scripts/issue/create-issue.sh` wrapper that re-runs the duplicate search, and the operator prompt (issue #96). |
| [Security Checklist](security-checklist.md) | Security review checklist for this host scope. |
| [Thin Root Layer Contract](thin-root-layer.md) | The artifacts that must live at a consuming target's project root and the `CLAUDE_CODE_*` env contract. |

### Quick Routing

| If the issue touches... | Read first |
| --- | --- |
| AutoFlow rules, gates, agent roles, or hook behavior | `CLAUDE.md`, `docs/autoflow-guide.md`, `docs/phases/analysis.md` |
| Sub-repo implementation (multi-repo instances) | `docs/repo-boundary-rules.md` |
| Issue decomposition or readiness | `docs/development-guideline.md` |
| Filing a new issue | `docs/issue-proposal.md` |
| Tool distribution, install/upgrade, or version pinning | `docs/tool-delivery-contract.md`, `docs/thin-root-layer.md` |
| External review backend (codex/claude), step-6 review mechanics | `docs/reviewer-backend.md`, `docs/external-review-sequencing.md` |

## Design and decision records

Not the source of any rule, and not stamped to targets — a citation from a
usage document to a record resolves in this repository only.

| Record tree | Use When |
| --- | --- |
| `docs/records/` — [Design Rationale](records/design-rationale.md), the ADRs registered in [ADR README](records/adr/README.md) (drafts start from its template), [design reviews](records/design-reviews/issue-177-deliberation-participant-lifetime.md) | You need the history or grounds of a decision: why a rule exists, when and by whom it was settled, which alternatives were rejected, or you are creating or amending an ADR. |

