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
| [0018-verification-depth-justification.md](0018-verification-depth-justification.md) | Proposed, amended by issue #198 (failure-mode column; Decision 3 superseded) | Verification depth governed by a per-layer unique-failure-mode justification, not a quantity cap; GATE:PLAN `Scope` widened to the verification design. |
| [0019-scope-fit-verification-policy.md](0019-scope-fit-verification-policy.md) | Proposed; superseded by ADR-0024 (decisions 1 and 2 in full; decision 3 in part) | Interim verification runs the selection-derived set with suite-grained inheritance; the whole tree executes once per cycle at VALIDATE as the coverage floor; evaluator citation-inheritance, sampling default and wall-clock cap. |
| [0020-acceptance-criterion-authority.md](0020-acceptance-criterion-authority.md) | Accepted, amended by ADR-0022; ARCHITECT halt superseded by issue #166 | Changing an issue's acceptance criteria is the operator's authority: the orchestrator puts an acceptance-criterion content change to the operator before GATE:PLAN, the decision is recorded as an `[ac-decision]` ledger entry, and GATE:PLAN / GATE:QUALITY cap on an uncovered difference. |
| [0021-c7-pilot-spawn-mode-result.md](0021-c7-pilot-spawn-mode-result.md) | Proposed | C7 pilot verdict `EQUAL_OR_BETTER`: the anonymous direct spawn matches the named-spawn baseline, so ADR-0017's migration proceeds; C8 measured, token cost unmeasured. |
| [0022-test-necessity-and-three-tier-ac-guard.md](0022-test-necessity-and-three-tier-ac-guard.md) | Accepted; Reconcile tier-3 trigger superseded by issue #166; `delivery-check`'s definition amended by ADR-0024; decision 1's retention role replaced by ADR-0024 D1 (issue #222) | A test exists only when it is needed (required behavior + cost of absence, default `none`); acceptance-criterion reductions pass deliberation → external reviewer → operator, and tier 3 is reached through the orchestrator's routing of the deliberation report and the two gates' AC-authority checks. |
| [0023-deliberation-participant-lifetime.md](0023-deliberation-participant-lifetime.md) | Accepted; implemented by issue #179 (A2 realization) | Deliberation participant lifetime: the ARCHITECT participants persist for the discussion and the orchestrator relays them (anonymous, resumed by agent ID; named form is the fallback), with the VERIFY step's scope over the transcript; ADR-0017 Q3, the hook's name denial and Decision 8's isolation rule stand, Decision 8's Workflow-realization clause is superseded for ARCHITECT. |
| [0024-two-layer-verification-and-target-owned-tests.md](0024-two-layer-verification-and-target-owned-tests.md) | Proposed; D1 revised by issue #222; S1 + S2 implemented and D4 revised by issue #225 | Verification splits into a `standing` layer (the defect surfaces only after deployment — four closed categories; verdict at CI) and a `cycle` layer (the default for `automated`: one-shot, uncommitted under `.autoflow/issue-{N}-local/`, result recorded); AutoFlow phases invoke the target's declared test command and the suite plane becomes opt-in; the CI-layer verdict is HANDOFF step 5 with class-routed re-entry; supersedes ADR-0019 and amends ADR-0022. |

**Numbering gap.** ADR numbers 0002, 0004–0014 are intentionally absent here:
they were migrated to `services/librechat-deploy` during the 2026-06-27
services-nesting split, so the sequence in this directory is deliberately
non-contiguous. The records in this directory are the authoritative set.
