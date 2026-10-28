# Repository Boundary Rules

> Defines the scope of each AI agent's access and the rules for a change that crosses repositories.

---

## Core Principle

**Each AI agent operates within its assigned repository only.**

A change another repository needs is made by a module run in that repository's scope.

---

## General Boundary Principles

Throughout these rules, **target** (equivalently **target scope**) means the scope that receives the work — the repository or directory whose source a change lands in — and the development project that consumes AutoFlow as a versioned tool (see [`tool-delivery-contract.md`](tool-delivery-contract.md)). Its opposite pole is the **host** repository. The three principles below hold whatever the project's repository structure — with the elaboration for a project with sub-repos kept as secondary detail.

### Artifacts (산출물)

Every produced artifact belongs to the scope that owns the files it lives in: code and tests belong to the target scope that owns that source; the decision ledger lives in the attempt's record directory, outside every repository; a pull request is opened from the host regardless of which scope produced the commits. *Secondary (multi-repo):* the owning scope is a sub-repo directory, so the build unit commits on that sub-repo's branch and the delivery module opens the PR. *See:* the Commit Ownership committer column and Records and the hook (`<autoflow-root>/docs/core.md`), and the own-repo Read + Write cells of the Permission Matrix (below).

### Procedures (절차)

Integration verification, the push and PR opening are the delivery module's; execution steps — writing code and tests, and committing them — belong to the target scope. Each agent performs the steps of its own scope. *Secondary (multi-repo):* the sub-repo push and the host pointer are the delivery module's ([`units/delivery.md`](units/delivery.md) > *Multi-repo delivery*); merging, and what follows it, are outside AutoFlow ([`git-workflow.md`](git-workflow.md) > Post-Merge Cleanup). *See:* Rule 1 and Rule 3 (below), and the PR-opener column of Commit Ownership (`<autoflow-root>/docs/core.md`).

### Backlog (백로그)

Tracking items — issues, sub-issues, and the tracking hub — live where the project's information says ([`core.md`](core.md) > Project Information); a project that names no other tracker keeps them in the host repository. Each item is routed to the scope that will execute it. *Secondary (multi-repo):* unless the project names another tracker, a sub-repo's work item is filed in the host and labeled with that sub-repo; the sub-repo's PR cross-references the host issue as `Part of <host-owner>/<host-name>#N`. *See:* Rule 1 (below) and the Checklist for Cross-Repo Changes (below).

Issue labels: `ai:<agent>` (automation target, e.g. `ai:claude`), sub-repo name, priority.

---

## Permission Matrix

| Agent | Own Repo | Other Repos | Host Repo |
|-------|----------|-------------|-------------------|
| **Build unit (U4)** | Read + Write | Read only | Read only |
| **Evaluation AI** | Read only | Read only | Read only |

---

## Rules in Detail

### Rule 1: No Cross-Repo Direct Commits

An AI agent assigned to `repo-backend` **must not** commit to `repo-frontend`, even if the change is trivial (e.g., updating an API URL constant).

**Instead**: the run reports the change the other repository needs in its output, and a build run in that repository's scope makes it; the work item that tracks it lives where *Backlog* above says, and the target scope hosts no tracker of its own.

### Rule 2: Read Access Is Allowed

Any agent can **read** files from other repos to understand interfaces, contracts, or dependencies. This is encouraged for:
- Understanding API contracts
- Checking shared type definitions
- Verifying integration points

### Rule 3: Interface Changes Are Made Repo by Repo

When a change in one repo affects the interface used by another:

1. The build unit reports the proposed interface change in its report
2. Each affected repo's change is made by a build run in that repo's scope, in dependency order
3. Integration testing validates the change across repos — before the hand-off, by the integration module ([`units/delivery.md`](units/delivery.md) > Integration)

---

## Conflict Resolution

When two repos need changes that conflict (e.g., incompatible interface changes), the module that meets the conflict puts its resolution to the advisor and follows the decision, which the decision ledger records (`<autoflow-root>/docs/role-contracts.md` > Advisor).

---

## Checklist for Cross-Repo Changes

Before starting a cross-repo change:

- [ ] A host-repo work item exists for each affected repo (labeled with that repo); no issue is filed in the target repo
- [ ] Interface contracts are documented
- [ ] Rollback plan exists (what if one repo's change fails?)
