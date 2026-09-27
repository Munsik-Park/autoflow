# DELIVER — Sub-Repo Push

> Phase playbook for DELIVER. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

DELIVER pushes the cycle's completed work to its remote branch(es). The orchestrator runs it ([`role-contracts.md`](../role-contracts.md) > Spawn mode by role lifetime): every implementation role is an anonymous direct spawn that has already ended by returning its report, so DELIVER spawns no role and has none to stop.

In a single-repo deployment (target-centric — the default; zero submodules, see [`CLAUDE.md`](../../CLAUDE.md) > Deployment Topology), DELIVER is a single `git push -u origin <branch>` by the orchestrator. There is no fork distinction.

*Secondary (multi-repo):* In a multi-repo deployment (one or more submodules), DELIVER fans out across the sub-repo forks:

- The orchestrator pushes each sub-repo branch to its fork (`git -C <submodule> push origin <branch>`).
- The host's dev branch is NOT pushed yet (that happens at HANDOFF, when the host PR is created). By the time the host PR is created, the host dev branch's `<submodule>` gitlink (the submodule pointer) must point to this cycle's sub-repo PR head. The commit that bumps that pointer is the **orchestrator's** (see [`CLAUDE.md`](../../CLAUDE.md) > Commit Ownership), and it is committed at HANDOFF step 4b, the single source of the pointer-bump commit format (DELIVER names the actor and target only; it does not restate the format).
