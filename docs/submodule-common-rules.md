# Sub-Repository Common Rules

> Shared rules that apply to all sub-repositories in a multi-repo AutoFlow project.

---

## Applicability

These rules apply to every sub-repository (e.g., backend, frontend, infra, docs) that participates in the AutoFlow lifecycle under a central orchestrator.

---

## Required Files

Every sub-repository **must** contain:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Sub-repo operating manual |
| `.gitignore` | Must include `.autoflow/issue-*.json` |
| `README.md` | Project-specific documentation |

---

## AutoFlow State Ownership

AutoFlow state lives in the host (orchestrator) repository under `.autoflow/issue-{N}.json` — one file per issue. Sub-repos do not own AutoFlow state. A sub-repo that finds an `.autoflow/` directory locally should treat it as residual from a misconfigured run; the canonical state is in the host repo.

The host's hook (`.claude/hooks/check-autoflow-gate.sh`) reads the state file and computes pass/fail directly from raw `scores`. Sub-repo AIs do not write to the state file — they receive instructions through `SendMessage` from the orchestrator.

---

## Submodule URL & Pointer Policy

Applies to host repositories that operate a **host-private fork** as the submodule source — i.e., the fork carries host-private changes that are **not** bound for the upstream repository. The host repo's submodule pointer therefore lives in fork commits, not upstream commits.

In a multi-repo instance of this framework, the host's direct submodule is `services` = **`<org>/<service-host>`** (host-operated nesting repo). Nested `librechat` (`<org>/<submodule>` fork) and `librechat-deploy` are submodules **inside llmroute**; they follow the same host-operated fork model but at the llmroute level. (`claude-autoflow` itself no longer nests `services` — it was detached in #798 and is now single-repo; the example is illustrative of a multi-repo consumer.)

### URL — `.gitmodules` fixed to the host-operated fork

```
.gitmodules submodule.<name>.url → <host-operated fork URL>   (e.g., <org>/<service-host>)
```

- `.gitmodules` is **never modified** in a PR. PR diffs must not touch `.gitmodules` (URL is fixed at framework init).
- Local fork URL override is unnecessary: the URL is the fork to begin with.
- `setup/init.sh` substitutes the URL when the framework is propagated to another project, so each operator inherits the same model with their own fork.

### Pointer SHA — host main reachability

```
host main HEAD's submodule pointer SHA  →  reachable in the host-operated fork
```

- A commit that exists only on a fork **feature branch** (not yet merged into the fork's `main`) **must not** appear as the submodule pointer on host `main`. Fork feature branches can be deleted or force-pushed at any time; relying on them is a stale-pointer footgun.
- **Dev branch exception**: while a host PR's dev branch is open, the submodule pointer may temporarily reference a fork feature-branch SHA (this is normal for in-progress work). Reachability against fork `main` is enforced at host-`main`-merge time.

### Multi-developer concurrent work

- `.gitmodules` is **never** modified — URL stays fixed.
- Each developer commits **only the submodule pointer** for their issue's dev branch.
  - The "developer" who commits that pointer on the host dev branch is the **orchestrator** — the host `services` gitlink is a host-file change it owns (see [`CLAUDE.md`](../CLAUDE.md) > Commit Ownership > Submodule pointer bump); the two rules name the same actor, not two.
- No per-developer local URL override is required (the URL is already the fork).

### Sub-repo cycle close-out

When a sub-repo work cycle is complete:

1. Merge the fork feature branch (e.g., `feat/<issue>-<topic>`) into the fork's `main`.
2. Reconcile the host's submodule pointer to this cycle's sub-repo merge commit on fork `main` (in the host PR's dev branch, before host PR merge). **[MUST]** When several cycles are in external review at once, reconcile **against the current `origin/main`**, not the branch's stale fork point: host-PR merges (one at a time) advance `main`'s pointer, so a stale-base bump leaves the host PR `CONFLICTING` and fails the Jenkins `pr-merge` build `NOT_MERGEABLE`. Resolve by fork ancestry — if this cycle's merge commit (`TARGET`, the llmroute PR's merge commit; nested librechat/deploy pointer reconcile inside llmroute is llmroute's internal concern) is a **descendant** of the current `main` pointer, set the dev gitlink to `TARGET` first (`git -C services checkout <TARGET>; git add services; git commit`) **then** merge `origin/main` (with the dev pointer at `TARGET` ⊇ `MAIN`, the submodule stays at `TARGET`, no content conflict); if `main`'s pointer is a descendant (a regression) or the two diverge, **escalate to the operator**. **[MUST]** The end-state pointer must equal `TARGET` — verify `git ls-tree HEAD services == TARGET` before pushing (a bare `git merge origin/main` from a `BASE` dev pointer resolves the gitlink to `MAIN`, failing the operator's pointer-equality reconcile check). Full procedure + the post-reconcile mergeable/Jenkins gate: [`external-review-sequencing.md`](external-review-sequencing.md) > Reconcile preflight.
3. The fork feature branch may then be deleted; the pointer SHA is preserved on fork `main`.

This is the lifecycle that makes the **Pointer SHA — host main reachability** rule hold without requiring branch-protection rules on every fork feature branch.

### Framework propagation

Operators initializing this framework on a different project run `setup/init.sh`, which substitutes the submodule URL to point at the operator's own fork (same model — host-operated fork, host-private changes allowed). The Pointer SHA rule is unchanged: host `main` always points at a commit reachable in the operator's fork.

### Transition note (issue #91)

The original wording in `docs/autoflow-guide.md > HANDOFF > Merge Sequencing` / `docs/external-review-sequencing.md` was authored under issue #92 cycle 4 with an "upstream merge" framing (i.e., sub-repo PR → `danny-avila/LibreChat:main`). The services-nesting refactor (2026-06-27) updated the host-level sub-repo identity: the host's direct submodule is now `services` = `<org>/<service-host>`. `docs/external-review-sequencing.md` has been reconciled to reflect llmroute as the `SUBREPO` target. This section remains the authoritative pointer URL & pointer SHA policy. **As of #798 (2026-07) `claude-autoflow` carries zero submodules and is single-repo — the `services` submodule was detached; the present-tense wording above is a historical record of the pre-#798 nesting era and applies to a multi-repo consumer operating such a host-private fork.**

---

## CLAUDE.md Requirements

Each sub-repo's `CLAUDE.md` must define:

### 1. Repo Identity
```markdown
## This Repository
- **Name**: <repo-name>
- **Role**: [backend / frontend / infra / docs / ...]
- **Orchestrator**: <org>/<host-repo>
```

### 2. Tech Stack & Commands
```markdown
## Development Commands
- **Build**: `<build command>`
- **Test**: `<test command>`
- **Lint**: `<lint command>`
- **Format**: `<format command>`
```

### 3. Scope Boundaries
```markdown
## Scope
This AI agent may only modify files within this repository.
For cross-repo changes, raise a Discussion to the Orchestrator.
```

### 4. AutoFlow Reference
```markdown
## AutoFlow
This repository follows the AutoFlow lifecycle defined in:
<org>/<host-repo>/CLAUDE.md

All AutoFlow phases, evaluation criteria, and gate rules apply.
```

---

## Agent Behavior Rules

### DO
- Follow the AutoFlow phases in order
- Run tests before marking the TDD cycle complete
- Use the Discussion Protocol for ambiguities
- Reference the orchestrator's CLAUDE.md for process questions

### DO NOT
- Skip the evaluation gate (GATE:QUALITY)
- Modify files in other repositories
- Push directly to `main`
- Ignore evaluation feedback during revision (REVISION)
- Inline document body, full file text, or raw verbose test output in reports — see Reporting Format below

---

## Change Surface Rules

Every changed line must trace to the issue's acceptance criteria or the agreed plan. The scope of a cycle is exactly what the issue asked for — adjacent improvements belong to a separate issue.

### Trace rule
- **[MUST]** Each touched file/line answers the question: "which AC or plan item requires this?" If the answer is "none — I noticed it while I was here", revert that line.
- **[MUST]** Before opening the PR, run `git diff <base>...HEAD` and self-audit: any hunk without an AC ID in its rationale is removed.

### Surrounding code
- **[MUST]** Match the existing style and naming in the file you edit, even if you would write it differently in a greenfield.
- **[MUST]** Leave adjacent code, comments, formatting, and import order untouched unless an AC requires the change.
- **[MUST]** Pre-existing dead code, suspicious patterns, or stylistic inconsistencies you notice in passing are reported in the cycle report (one line each, with file:line). Filing a separate issue is the follow-up path; do not remove or "improve" them in this cycle.

### Over-engineering guard
The trace rule rejects scope creep *across* the change surface; this guard rejects depth creep *inside* it. Keep the solution to the minimum the current AC needs:
- **Scope**: don't add features, configurability, or "improvements" beyond the AC. A bug fix doesn't clean up surrounding code; a simple feature doesn't gain extra options.
- **Documentation**: don't add docstrings, comments, or type annotations to code you didn't change. Comment only where the logic isn't self-evident.
- **Defensive coding**: don't add error handling, fallbacks, or validation for scenarios that can't occur. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- **Abstractions**: don't create helpers or abstractions for a one-time operation, and don't design for hypothetical future requirements.

### Orphans from this cycle
- **[MUST]** Imports, variables, and functions that **your** changes rendered unused are removed in the same commit.
- **[MUST]** Do not remove pre-existing unused symbols unless an AC explicitly requires it.

### Derived artifacts
- **[MUST]** `setup/manifest.json` is a **derived member of the change surface**
  whenever the surface includes a manifest-registered source. If
  `git diff --name-only <base>...HEAD` intersects
  `jq -r '.artifacts[].source' setup/manifest.json` on any path other than
  `setup/manifest.json` itself, the manifest must be regenerated
  (`setup/gen-manifest-hashes.sh`) and staged in the **same commit** — its
  updated `sha256` rows trace to that same edit, so they do not violate the
  trace rule. CI `AC2e` (`tests/plugin/verify-install-into-target.sh`) fails the
  PR otherwise (#798/#799/#800 precedent).

### REFINE scope
REFINE applies the same trace rule: refactor suggestions that touch code outside the cycle's change surface are rejected, recorded in the report, and (if worth pursuing) filed as a new issue. The refactor tool's findings are advisory, not licence to expand the change surface.

### GATE:QUALITY linkage
GATE:QUALITY's `Minimal implementation` item is scored against this section's trace rule: a diff with hunks that do not trace to an AC fails the item regardless of code quality.

---

## Reporting Format

When a teammate reports to the orchestrator (or to another teammate via `SendMessage`), the message must follow this shape to keep token cost bounded (see host [`CLAUDE.md`](../CLAUDE.md) > Cost Control). This format governs **AI↔AI / AI↔orchestrator** messages, whose audience is an AI that re-derives anchors deterministically. It does **not** govern a **human-facing decision pause** — that follows the situation-first contract in host [`CLAUDE.md`](../CLAUDE.md) > Execution Principles > Human-decision presentation (situation → decision/options → anchors-as-evidence).

1. **Reference paths, not bodies**: cite `.autoflow/*` files, source files, and commit hashes by path/hash. Do NOT paste full file bodies or document sections into messages.
2. **One-line summaries**: each finding, fix, or status item gets one line. Tables of ≤ 10 rows are allowed for structured results (test counts, coverage percentages).
3. **Test output**: report jest summary line (e.g., "Tests: 147 passed, 147 total") + coverage percentage. Never paste per-case PASS/FAIL lines or the full coverage report.
4. **Cited code excerpts**: when quoting code is unavoidable (e.g., to point out a bug), keep excerpts ≤ 10 lines AND verify the excerpt against the live file at quoting time — stale working-memory snapshots are a known incident pattern.
5. **Evidence anchor (mandatory)**: every "done" / "PASS" / "fixed" claim must end with one verifiable anchor — pick whichever fits:
   - code change → full 40-char commit SHA
   - test pass  → the exact `Tests: N passed, N total` (or equivalent) summary line, with the command that produced it
   - file state → `path:line` plus the verbatim content of that line

   Anchors must be deterministically re-derivable by the orchestrator (`git show <SHA>` / re-running the test command / `git show HEAD:<file>`). Reports without an anchor are rejected, not interpreted.

6. **Facilitator return (deliberation phases)**: the facilitation `Workflow` returns one structured result, specific to the phase — ARCHITECT: `{ verdict: CONVERGED|ESCALATE, artifact paths, ledger, summary }`; VERIFY: `{ test/impl self-check, next_action: RED|GREEN|SEQUENTIAL_FIX|EVALUATION_AI, ledger, summary }`. It carries no round-by-round messages and no duplicate dual reports. Shape and rationale: [host `CLAUDE.md`](../CLAUDE.md#deliberation-isolation-delegated-facilitation) > Deliberation Isolation and [`teammate-contracts.md`](teammate-contracts.md) > Facilitator > Return Contract.

---

## Testing Standards

Every sub-repo must maintain:

1. **Unit tests** for business logic
2. **Integration tests** for API endpoints / component interactions
3. **No broken tests on `main`** — all tests must pass before merge
4. **Test commands documented** in `CLAUDE.md` so Test AI can run them
5. **Cost-aware execution**: invoke jest with `--silent --reporters=summary` when running for a teammate report (verbose output is for local debugging only). Coverage reports use the summary reporter; per-file HTML reports stay on disk and are referenced by path, not pasted.
6. **SIGPIPE-safe assertion pipes**: under `set -o pipefail`, do not pipe a *streaming/context* producer (`grep -A/-B/-C`, and awk/section-extractor functions whose buffered output is still flushing when the consumer exits, and other producers that keep writing past the match) directly into a *short-circuiting* consumer (`grep -q`, `grep -m`, `head`) when the pipeline's exit status is the assertion verdict. The consumer's early exit can send the producer `SIGPIPE` (exit 141), which `pipefail` promotes to a pipeline failure — flipping a logically-passing assertion to a flaky FAIL (`grep: write error: Broken pipe`). Capture the producer first, then match the captured string — `ctx=$(<producer>); printf '%s\n' "$ctx" | grep -q <pattern>` — or drop `-q` so the consumer reads to EOF. When the assertion chains `grep` checks with `&&`, capture once and reuse `$ctx` across every branch — do not re-split the capture per branch (a bare `;` drops the `&&` ordering and silently weakens the assertion). (issues #964, #973)

### Bash execution mode

> Canonical: docs/teammate-common-rules.md > Bash Execution Mode.

- **[MUST]** A spawned teammate runs **every** Bash command in the **foreground** and never uses `run_in_background` — for any command, test/build verification runs included, **and specifically including a command the agent itself chooses to background for its own verification run** (a self-selected `run_in_background:true` on the agent's own test/build, with no such instruction given, is a violation of this clause). This binds every direct `autoflow-*` subagent (analyzer, planner, implementer, tester, evaluator) **and** every in-script Developer-AI / Test-AI sub-agent inside a facilitation `Workflow` (`.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js`). Run the command, wait for its result, then report.
- **Why (lifecycle contract):** the harness's background-task contract — *re-invoke the owning agent when the task completes* — holds only for an agent that has a future turn. A spawned subagent terminates with its final response, so any still-pending background process is **reaped at teardown**: its output is lost and no completion notification is ever delivered, stalling the orchestrator on a report that never arrives (issue #952 — 71-minute orchestrator deadlock, 2026-07-07). A background CPU-heavy process can also starve the agent's own foreground verification and distort the pass/fail verdict (issue #287). The background + completion-notification pattern is therefore **orchestrator-only** (the main loop is the sole actor with future turns).

---

## Dependency Management

### Internal Dependencies (Between Repos)
- Use **versioned APIs** or **published packages** — never import directly from sibling repos
- Document dependency versions in a central tracking document
- Coordinate version bumps through the Orchestrator

### External Dependencies
- Pin major versions to prevent breaking changes
- Run vulnerability scans as part of CI
- Document any known CVE exceptions with rationale

---

## Shared Conventions

To maintain consistency across all sub-repos:

### Code Style
- Follow the language-specific style guide chosen for the project
- Use automated formatters (Prettier, Black, gofmt, etc.)
- Enforce via CI — no style debates in reviews

### Documentation
- Update docs when changing public interfaces
- Keep README.md current
- API changes require updating the API documentation

### Error Handling
- Use consistent error formats across repos
- Log errors with enough context to diagnose
- Don't swallow errors silently

---

## CI/CD Integration

Each sub-repo should have CI that:

1. Runs on every PR
2. Executes: lint → build → test
3. Reports results back to the PR
4. Blocks merge on failure

### AutoFlow Gate Integration
The `check-autoflow-gate.sh` hook can be integrated into CI to verify:
- Evaluation score meets threshold
- All AutoFlow phases completed in order
- State files are consistent
