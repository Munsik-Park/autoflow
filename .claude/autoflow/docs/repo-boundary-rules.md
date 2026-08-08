# Repository Boundary Rules

> Defines the scope of each AI agent's access and the rules for cross-repository coordination.

---

## Core Principle

**Each AI agent operates within its assigned repository only.**

Cross-repository modifications require explicit coordination through the Orchestrator, ensuring traceability and preventing conflicting changes.

---

## General Boundary Principles

Throughout these rules, **target** (equivalently **target scope**) means the scope that receives the work — the repository or directory whose source a change lands in — and, under the epic-#785 host↔target inversion, the development project that consumes AutoFlow as a versioned tool (see [`tool-delivery-contract.md`](tool-delivery-contract.md) and [ADR-0015](adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md)). Its opposite pole is the **host** repository and its **Orchestrator** — the coordinating source. A single reading holds under both layouts: today the target scope is a sub-repo; after the inversion it is the consuming project root. The three principles below are topology-agnostic — they hold whether the host contains zero submodules or many — and each restates an existing rule rather than adding one, with the multi-repo elaboration kept as secondary detail.

### Artifacts (산출물)

Every produced artifact belongs to the scope that owns the files it lives in: code and tests belong to the target scope that owns that source; the decision ledger and AutoFlow state belong to the host; a pull request is opened from the host regardless of which scope produced the commits. *Secondary (multi-repo):* the owning scope is a sub-repo directory, so each sub-repo's Submodule AI commits to its fork and the Orchestrator opens the PR. *Trace:* the Commit Ownership committer column and the Decision Ledger host-ownership rule (`CLAUDE.md`), and the own-repo Read + Write cells of the Permission Matrix (below) — the principle names an existing ownership, not a new obligation.

### Procedures (절차)

Coordination steps — work breakdown, sequencing, integration verification, and PR opening — belong to the Orchestrator; execution steps — writing code and tests, and committing them — belong to the target scope. No agent performs a step outside its scope. *Secondary (multi-repo):* cross-repo sequencing (sub-repo → pointer bump → host), merge ordering, and fork push are the Orchestrator's coordination surface. *Trace:* Rule 1, Rule 3, and Rule 4 (below), and the PR-opener = Orchestrator column of Commit Ownership (`CLAUDE.md`) — the narration subject shifts to the target, the obligations do not.

### Backlog (백로그)

Tracker placement follows each repo's composition (D4, settled in S12 #800): AutoFlow-framework tracking items — issues, sub-issues, and the tracking hub — live in this host repository (`Munsik-Park/autoflow`). Each item is routed to the scope that will execute it. *Secondary (multi-repo, where no service-host tracker is designated):* all tracking items live in that instance's host repository — each affected sub-repo has its own work item filed in the host and labeled with that sub-repo (no tracker lives inside the sub-repo); the sub-repo's PR cross-references the host issue as `Part of <host>#N`, and forks host no issues. *Trace:* Issue Management (`CLAUDE.md`), Rule 1's coordination path (below), and the Checklist for Cross-Repo Changes (below).

> **Transition note (epic #785):** The target-owned re-attribution — routing AutoFlow-framework issues
> to this host repository (`Munsik-Park/autoflow`) — was
> executed in S12 (#800), following the S11a (#798) host↔target flip; historical
> tracking placement was reconciled under the S12 go/no-go migration manifest.

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

**Why**: Cross-repo commits bypass that repo's AutoFlow evaluation cycle, creating unreviewed changes.

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
│       (claude-autoflow)         │
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

### Agent Teams Communication

Agents use `SendMessage` (Claude Code's built-in agent communication) to coordinate:

```
Orchestrator → Submodule AI (repo-backend):
  "Implement new /users endpoint per issue #42.
   See requirements in the orchestrator's plan for issue #42."

Submodule AI (repo-backend) → Orchestrator:
  "Implementation complete. New endpoint: GET /api/v1/users.
   Response schema documented in docs/api.md"

Orchestrator → Submodule AI (repo-frontend):
  "New backend endpoint available: GET /api/v1/users.
   Implement user list page per issue #43.
   Submodule PR: repo-backend#15"
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
