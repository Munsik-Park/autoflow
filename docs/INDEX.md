# Documentation Index

Use this page as the first stop before assigning or implementing an issue.
It routes two document classes that live in separate trees: the **usage
documents** an agent reads and follows while a cycle runs — the source of the
rules — and the **design and decision records** under
`<autoflow-root>/docs/records/`, read for a decision's history and grounds, the source of no
rule. Both ship in the plugin; a role reads a usage document by its path under
`<autoflow-root>`.

## Usage documents

### Decision and Issue Readiness

| Document | Use When |
| --- | --- |
| [Development Guideline](development-guideline.md) | You need the work-type, issue, ADR, PR, refactoring, test, and docs policy. |

### Existing Operating Documents

These documents are the operating source of truth.

| Document | Role |
| --- | --- |
| [Core](core.md) | AutoFlow operating manual and phase router — the source of the `/autoflow:cycle` and `/autoflow:criterion-review` command bodies (ADR-0027 D2). |
| [State Tracking](state-tracking.md) | The state file's naming, schema and fields, the hook gates, and its state at completion. |
| [AutoFlow Guide](autoflow-guide.md) | Lifecycle overview and diagram; index of the functional-unit documents under `units/`. |
| [U2 Analysis](units/analysis.md) | The U2 Analysis unit: goal, cautions, analysis report and routing; the other units are listed in the AutoFlow Guide. |
| [Decision Ledger](decision-ledger.md) | The per-attempt decision ledger's entry grammar, identifiers, and decision-point entries — the advisor's first judgment and the operator's override (`[ac-decision]`, `[checklist-decision]`). |
| [Repo Boundary Rules](repo-boundary-rules.md) | Host/submodule/cross-repo responsibility boundaries. |
| [External Review Sequencing](external-review-sequencing.md) | Merge sequencing and external review flow. |
| [Tool Delivery Contract](tool-delivery-contract.md) | The installed plugin as the single version, rule delivery through command bodies and agent definitions, target-identity separation, the packaging and PREFLIGHT checks, and the target's own spawn policy. |
| [Reviewer Contract](reviewer-backend.md) | HANDOFF reviewers: the built-in review and the configured external reviewers, their inputs and review records, the aggregator's outputs, config location, model/effort, availability, start-confirmation oracle. |
| [Criterion Review](criterion-review.md) | The review of a new issue's acceptance criteria against the target's code and policy outside the cycle, the `[criterion-ready]` entry recording the review's settled decisions, and the readiness fact PREFLIGHT reads. |
| [Issue Proposal Contract](issue-proposal.md) | Draft grammar and filing procedure for new issues: the `gh issue create` deny, the `<autoflow-root>/scripts/issue/create-issue.sh` wrapper that re-runs the duplicate search, and the operator prompt. |

### Quick Routing

| If the issue touches... | Read first |
| --- | --- |
| AutoFlow rules, gates, agent roles, or hook behavior | `<autoflow-root>/docs/core.md`, `<autoflow-root>/docs/autoflow-guide.md`, `<autoflow-root>/docs/units/*.md` |
| Sub-repo implementation (a project with sub-repos) | `<autoflow-root>/docs/repo-boundary-rules.md` |
| Issue decomposition or readiness | `<autoflow-root>/docs/development-guideline.md` |
| Filing a new issue | `<autoflow-root>/docs/issue-proposal.md` |
| Making a filed issue ready for its first cycle | `<autoflow-root>/docs/criterion-review.md` |
| Tool distribution, install/upgrade, or version pinning | `<autoflow-root>/docs/tool-delivery-contract.md` |
| Reviewers (built-in + external), review aggregation | `<autoflow-root>/docs/reviewer-backend.md`, `<autoflow-root>/docs/external-review-sequencing.md` |

## Design and decision records

Not the source of any rule — a usage document cites a record for its grounds,
and no role follows a record.

| Record tree | Use When |
| --- | --- |
| `<autoflow-root>/docs/records/` — [Design Rationale](records/design-rationale.md), the ADRs registered in [ADR README](records/adr/README.md) (drafts start from its template), [design reviews](records/design-reviews/issue-177-deliberation-participant-lifetime.md) | You need the history or grounds of a decision: why a rule exists, when and by whom it was settled, which alternatives were rejected, or you are creating or amending an ADR. |

