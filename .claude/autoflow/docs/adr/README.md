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

**Numbering gap.** ADR numbers 0002, 0004–0014 are intentionally absent here:
they were migrated to `services/librechat-deploy` during the 2026-06-27
services-nesting split, so the sequence in this directory is deliberately
non-contiguous. The authoritative cross-repo registry is
[`docs/maintained-docs.md`](../maintained-docs.md) > ADRs.
