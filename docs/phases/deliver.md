# DELIVER — Push

> Phase playbook for DELIVER. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

DELIVER, INTEGRATE and HANDOFF are one functional unit, U6 Delivery
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). DELIVER puts the cycle's
completed work on its remote branch. The orchestrator runs it
([`role-contracts.md`](../role-contracts.md) > Spawn mode by role lifetime): every unit agent has
already ended by returning its report, so DELIVER spawns no role.

- **What is asked**: the cycle's branch is on the remote, at the commit GATE:QUALITY passed.
- **The rules that always hold** are [HANDOFF](handoff.md) > *Push and pull request*: the push is
  the orchestrator's own `git push` command, which the gate hook sees and gates, and it never goes
  to the default branch. Which remote, which flags and when are the orchestrator's.
- **Result owed**: the pushed branch and its head commit, carried in HANDOFF's change summary.

A changed sub-repo's branch is pushed the same way, by the orchestrator's own
`git -C <sub-repo> push …`, to the remote the project's information names for it; the host
pointer that follows it is [HANDOFF](handoff.md) > *Multi-repo delivery*.
