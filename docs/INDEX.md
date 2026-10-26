# Documentation Index

Use this page as the first stop before assigning or implementing an issue.
It routes two document classes that live in separate trees: the **usage
documents** an agent reads and follows while a module runs — the source of the
rules — and the **design and decision records** under
`<autoflow-root>/docs/records/`, read for a decision's history and grounds, the source of no
rule. Both ship in the plugin; a role's carrier carries the usage documents its
work follows (`<autoflow-root>/docs/core.md` > Context Injection), and a role
reads any other by its path under `<autoflow-root>`.

## Usage documents

### Decision and Issue Readiness

| Document | Use When |
| --- | --- |
| [Development Guideline](development-guideline.md) | You need the work-type, issue, ADR, PR, refactoring, test, and docs policy. |

### Existing Operating Documents

These documents are the operating source of truth.

| Document | Role |
| --- | --- |
| [Core](core.md) | AutoFlow operating manual — the authority rules, how a module runs, the records and the hook — and the source of the module command bodies, `/autoflow:<module>`, each with the parts of the core its module uses (ADR-0027 D2, ADR-0038 D9). |
| [AutoFlow Guide](autoflow-guide.md) | Index of the modules: each one's kind, procedure document, and what it takes and gives. |
| Module contracts (`<autoflow-root>/docs/contracts/<module>.json`) | Each module's parameters, inputs and outputs, checked by `<autoflow-root>/scripts/contracts/contract.sh` (ADR-0038 D1). |
| [U2 Analysis](units/analysis.md) | The analysis module: goal, cautions and analysis report; the other modules are listed in the AutoFlow Guide. |
| [Decision Ledger](decision-ledger.md) | The per-attempt decision ledger's entry grammar, identifiers, and decision-point entries (`[ac-decision]`, `[checklist-decision]`). |
| [Repo Boundary Rules](repo-boundary-rules.md) | Host/submodule/cross-repo responsibility boundaries. |
| [Tool Delivery Contract](tool-delivery-contract.md) | The installed plugin as the single version, rule delivery through the carrier each role starts with (command bodies, agent definitions, reviewers' rule files), target-identity separation, the packaging check and the target check, and the target's own spawn policy. |
| [Reviewer Contract](reviewer-backend.md) | The review module's reviewers: the reviewers the operator file names, each run by its own script, and the reviews of the target's side, their inputs, rule files and review records, the aggregator's outputs, config location, model/effort, availability, start-confirmation oracle. |
| [Criterion Review](criterion-review.md) | The criterion review's four modules: an attempt's review of the issue's acceptance criteria against the target's code and policy, each item disposed of with its grounds in the review record. |
| [Issue Proposal Contract](issue-proposal.md) | Draft grammar and filing procedure for new issues: the `gh issue create` deny, the `<autoflow-root>/scripts/issue/create-issue.sh` wrapper that re-runs the duplicate search, and the operator prompt. |

### Quick Routing

| If the issue touches... | Read first |
| --- | --- |
| AutoFlow rules, gates, agent roles, or hook behavior | `<autoflow-root>/docs/core.md`, `<autoflow-root>/docs/autoflow-guide.md`, `<autoflow-root>/docs/units/*.md` |
| Sub-repo implementation (a project with sub-repos) | `<autoflow-root>/docs/repo-boundary-rules.md` |
| Issue decomposition or readiness | `<autoflow-root>/docs/development-guideline.md` |
| Filing a new issue | `<autoflow-root>/docs/issue-proposal.md` |
| An attempt's criterion review | `<autoflow-root>/docs/criterion-review.md` |
| Tool distribution, install/upgrade, or version pinning | `<autoflow-root>/docs/tool-delivery-contract.md` |
| Reviewers, review aggregation | `<autoflow-root>/docs/reviewer-backend.md` |

## Design and decision records

Not the source of any rule — a usage document cites a record for its grounds,
and no role follows a record.

| Record tree | Use When |
| --- | --- |
| `<autoflow-root>/docs/records/` — [Design Rationale](records/design-rationale.md), the ADRs registered in [ADR README](records/adr/README.md) (drafts start from its template), [design reviews](records/design-reviews/issue-177-deliberation-participant-lifetime.md) | You need the history or grounds of a decision: why a rule exists, when and by whom it was settled, which alternatives were rejected, or you are creating or amending an ADR. |

