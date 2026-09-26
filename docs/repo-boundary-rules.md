# Repository Boundary Rules

> Defines the scope of each AI agent's access and the rules for cross-repository coordination.

---

## Core Principle

**Each AI agent operates within its assigned repository only.**

Cross-repository modifications require explicit coordination through the Orchestrator.

---

## General Boundary Principles

Throughout these rules, **target** (equivalently **target scope**) means the scope that receives the work — the repository or directory whose source a change lands in — and the development project that consumes AutoFlow as a versioned tool (see [`tool-delivery-contract.md`](tool-delivery-contract.md)). Its opposite pole is the **host** repository and its **Orchestrator** — the coordinating source. The three principles below are topology-agnostic — they hold whether the host contains zero submodules or many — with the multi-repo elaboration kept as secondary detail.

### Artifacts (산출물)

Every produced artifact belongs to the scope that owns the files it lives in: code and tests belong to the target scope that owns that source; the decision ledger and AutoFlow state belong to the host; a pull request is opened from the host regardless of which scope produced the commits. *Secondary (multi-repo):* the owning scope is a sub-repo directory, so each sub-repo's Submodule AI commits to its fork and the Orchestrator opens the PR. *See:* the Commit Ownership committer column and the Decision Ledger host-ownership rule (`CLAUDE.md`), and the own-repo Read + Write cells of the Permission Matrix (below).

### Procedures (절차)

Coordination steps — work breakdown, sequencing, integration verification, and PR opening — belong to the Orchestrator; execution steps — writing code and tests, and committing them — belong to the target scope. No agent performs a step outside its scope. *Secondary (multi-repo):* cross-repo sequencing (sub-repo → pointer bump → host), merge ordering, and fork push are the Orchestrator's coordination surface. *See:* Rule 1, Rule 3, and Rule 4 (below), and the PR-opener = Orchestrator column of Commit Ownership (`CLAUDE.md`).

### Backlog (백로그)

Tracker placement follows each repo's composition: AutoFlow-framework tracking items — issues, sub-issues, and the tracking hub — live in this host repository (`Munsik-Park/autoflow`). Each item is routed to the scope that will execute it. *Secondary (multi-repo, where no service-host tracker is designated):* all tracking items live in that instance's host repository — each affected sub-repo has its own work item filed in the host and labeled with that sub-repo (no tracker lives inside the sub-repo); the sub-repo's PR cross-references the host issue as `Part of <host>#N`, and forks host no issues. *See:* Rule 1's coordination path (below) and the Checklist for Cross-Repo Changes (below).

Issue labels: `ai:<agent>` (automation target, e.g. `ai:claude`), sub-repo name, priority.

---

## Permission Matrix

| Agent | Own Repo | Other Repos | Orchestrator Repo |
|-------|----------|-------------|-------------------|
| **Submodule AI** | Read + Write | Read only | Read only |
| **Test AI** | Read + Write (test files) | Read only | Read only |
| **Evaluation AI** | Read only | Read only | Read only |
| **Orchestrator AI** | — | Read only* | Read + Write |

*Exception: Orchestrator may make configuration-level changes in sub-repos when documented (see Exceptions below).

---

## Rules in Detail

### Rule 1: No Cross-Repo Direct Commits

An AI agent assigned to `repo-backend` **must not** commit to `repo-frontend`, even if the change is trivial (e.g., updating an API URL constant).

**Instead**: The Orchestrator files a work item in the host repository, labels it with the target repo, and dispatches it to that repo's Submodule AI; the target scope executes the work but hosts no tracker of its own.

### Rule 2: Read Access Is Allowed

Any agent can **read** files from other repos to understand interfaces, contracts, or dependencies. This is encouraged for:
- Understanding API contracts
- Checking shared type definitions
- Verifying integration points

### Rule 3: Orchestrator Coordinates, Doesn't Implement

The Orchestrator AI's job is to:
- Break down cross-repo work into per-repo issues
- Sequence the work to avoid conflicts
- Verify integration after individual repos merge

The Orchestrator should **not** write implementation code in sub-repos.

### Rule 4: Interface Changes Require Coordination

When a change in one repo affects the interface used by another:

1. Submodule AI raises a Discussion with proposed interface change
2. Orchestrator evaluates impact across all affected repos
3. Orchestrator files a work item in the host repository for each affected repo, labels it with that repo, and dispatches it to that repo's Submodule AI; no issue is created in the target repo
4. Changes are implemented repo-by-repo in dependency order
5. Integration testing validates the change across repos

---

## Exceptions

### Documented Orchestrator Cross-Repo Actions

The Orchestrator may make the following changes in sub-repos:

| Action | Scope | Condition |
|--------|-------|-----------|
| Update shared config files | `.env.example`, CI config | When coordinating infra changes |
| Update version references | `package.json`, `pyproject.toml` | When bumping shared dependency versions |
| Add integration test hooks | Test config files | When setting up cross-repo testing |

All exceptions must be:
- Documented in the PR description
- Limited to configuration, not implementation
- Reviewed by a human

---

## Communication Flow

```
┌─────────────────────────────────┐
│        Orchestrator AI          │
│           (host repo)           │
├─────────────────────────────────┤
│  - Creates sub-issues           │
│  - Coordinates merge order      │
│  - Verifies integration         │
└───────┬───────────┬─────────────┘
        │           │
   ┌──────────▼───────────┐  ┌──────────▼───────────┐
   │     Submodule AI     │  │     Submodule AI     │
   │    (repo-backend)    │  │    (repo-frontend)   │
   │──────────────────────│  │──────────────────────│
   │ Read/Write own repo  │  │ Read/Write own repo  │
   └──────────────────────┘  └──────────────────────┘
```

### Cross-Scope Communication

Roles do not message each other. The orchestrator spawns each scope's AI directly, states
the task in the spawn prompt, and reads the spawn's returned report; anything one scope
needs from another is carried by the orchestrator into the next spawn's prompt:

```
Orchestrator spawns Submodule AI (repo-backend):
  prompt: "Implement the /users endpoint in repo-backend.
           Inputs: <.autoflow/ document paths for this task>.
           Write your report under .autoflow/; return its path and a one-line
           summary as your final message."

Submodule AI (repo-backend) returns:
  "<report path> — GET /api/v1/users added. Commit: <40-char SHA>"

Orchestrator verifies the anchor, then spawns Submodule AI (repo-frontend):
  prompt: "Implement the user list page in repo-frontend.
           Inputs: <.autoflow/ document paths for this task> and the repo-backend
           report <report path>.
           Write your report under .autoflow/; return its path and a one-line
           summary as your final message."
```

---

## Conflict Resolution

When two repos need changes that conflict (e.g., incompatible interface changes):

1. **Detect**: Orchestrator identifies the conflict during coordination
2. **Pause**: Both repos pause their AutoFlow at current phase
3. **Resolve**: Orchestrator proposes resolution via Discussion Protocol
4. **Agree**: Resolution documented and agreed upon
5. **Resume**: Repos resume with the agreed approach

---

## Checklist for Cross-Repo Changes

Before starting a cross-repo change:

- [ ] Orchestrator has created tracking issue
- [ ] A host-repo work item exists for each affected repo (labeled with that repo); no issue is filed in the target repo
- [ ] Merge order is defined
- [ ] Interface contracts are documented
- [ ] Rollback plan exists (what if one repo's change fails?)
