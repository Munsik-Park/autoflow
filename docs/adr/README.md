# Architecture Decision Records

This directory records architecture decisions that affect implementation,
deployment, repository boundaries, tenant isolation, agent workflow, or
operational responsibility.

## Status Values

- `Proposed`: Drafted for review or owner confirmation.
- `Accepted`: Confirmed as project policy.
- `Deprecated`: No longer recommended, but kept for history.
- `Superseded`: Replaced by a later ADR.

## When to Create an ADR

Create or update an ADR before implementation when a change affects:

- Host/submodule responsibility boundaries.
- Deployment topology or CI/CD authority.
- Tenant isolation, accounting ownership, file visibility, or access control.
- Secret/config management.
- Agent workflow gates, evaluation policy, or merge authority.
- External service dependencies.

Start from [0000-adr-template.md](0000-adr-template.md).

## Current Drafts

| ADR | Status | Topic |
| --- | --- | --- |
| [0003-autoflow-ends-at-handoff.md](0003-autoflow-ends-at-handoff.md) | Proposed | AutoFlow creates PRs and hands off; external reviewer merges. |
| [0015-autoflow-distribution-plugin-plus-thin-root-layer.md](0015-autoflow-distribution-plugin-plus-thin-root-layer.md) | Accepted | AutoFlow ships as plugin + thin root layer; `subrepo-merged` status-check machinery retired. |
| [0016-adr-conformance-gate-scoring.md](0016-adr-conformance-gate-scoring.md) | Accepted | ADR-conformance scoring at ARCHITECT/GATE:PLAN/GATE:QUALITY. |
| [0017-teammate-removal-feasibility.md](0017-teammate-removal-feasibility.md) | Accepted | Test AI / Developer AI as anonymous direct spawns: conditional go, with ordered preconditions and a blocking pilot. |
| [0018-verification-depth-justification.md](0018-verification-depth-justification.md) | Proposed | Verification depth governed by a per-layer unique-failure-mode justification, not a quantity cap; GATE:PLAN `Scope` widened to the verification design. |
| [0019-scope-fit-verification-policy.md](0019-scope-fit-verification-policy.md) | Proposed | Interim verification runs the selection-derived set with suite-grained inheritance; the whole tree executes once per cycle at VALIDATE as the coverage floor; evaluator citation-inheritance, sampling default and wall-clock cap. |
| [0020-acceptance-criterion-authority.md](0020-acceptance-criterion-authority.md) | Accepted, amended by ADR-0022; ARCHITECT halt superseded by issue #166 | Changing an issue's acceptance criteria is the operator's authority: the orchestrator puts an acceptance-criterion content change to the operator before GATE:PLAN, the decision is recorded as an `[ac-decision]` ledger entry, and GATE:PLAN / GATE:QUALITY cap on an uncovered difference. |
| [0021-c7-pilot-spawn-mode-result.md](0021-c7-pilot-spawn-mode-result.md) | Proposed | C7 pilot verdict `EQUAL_OR_BETTER`: the anonymous direct spawn matches the named-spawn baseline, so ADR-0017's migration proceeds; C8 measured, token cost unmeasured. |
| [0022-test-necessity-and-three-tier-ac-guard.md](0022-test-necessity-and-three-tier-ac-guard.md) | Accepted; Reconcile tier-3 trigger superseded by issue #166 | A test exists only when it is needed (required behavior + cost of absence, default `none`); acceptance-criterion reductions pass deliberation → external reviewer → operator, and tier 3 is reached through the orchestrator's routing of the deliberation report and the two gates' AC-authority checks. |
| [0023-deliberation-participant-lifetime.md](0023-deliberation-participant-lifetime.md) | Proposed | Deliberation participant lifetime: the VERIFY step's scope over the transcript is adopted now (per-turn respawn kept); orchestrator-relayed persistent participants (anonymous, resumed by agent ID) are re-opened and pilot-gated, the named form rejected; ADR-0017 Q3, the hook's name denial and Decision 8's isolation rule stand. |

**Numbering gap.** ADR numbers 0002, 0004–0014 are intentionally absent here:
they were migrated to `services/librechat-deploy` during the 2026-06-27
services-nesting split, so the sequence in this directory is deliberately
non-contiguous. The records in this directory are the authoritative set.
