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

In a single-repo deployment (target-centric — the default; zero submodules, see [`CLAUDE.md`](../../CLAUDE.md) > Deployment Topology), that is one push of the dev branch to `origin`. There is no fork distinction.

*Secondary (multi-repo):* In a multi-repo deployment (one or more submodules), DELIVER fans out across the sub-repo forks:

- The orchestrator pushes each sub-repo branch to its fork (`git -C <submodule> push origin <branch>`).
- The host's dev branch is NOT pushed yet (that happens at HANDOFF, when the host PR is created). By the time the host PR is created, the host dev branch's `<submodule>` gitlink (the submodule pointer) must point to this cycle's sub-repo PR head. The commit that bumps that pointer is the **orchestrator's** (see [`CLAUDE.md`](../../CLAUDE.md) > Commit Ownership), and it is committed at HANDOFF ([HANDOFF](handoff.md) > *Multi-repo delivery*, the single source of the pointer-bump commit format; DELIVER names the actor and target only).
