# Claude AutoFlow

A reusable framework for structured, evaluation-gated AI-assisted software development with [Claude Code](https://docs.anthropic.com/en/docs/claude-code), delivered as a Claude Code plugin.

AutoFlow is a set of modules — the criterion review, analysis, design, build, delivery, ci and review,
and the evaluations that score their work — each with a contract, built on multi-agent role
separation, independent analysis, and quantified evaluation. AutoFlow writes no file into the
project's tree (see [Quick Start](#quick-start)). Three properties set its scope:

1. **Terminal scope** — AutoFlow's last output is the reviewed PR; an external review process performs the merge. **AutoFlow never merges.**
2. **Modules with contracts** — a module checks its inputs' form, runs once, and checks its outputs against its contract (`docs/contracts/<module>.json`); modules compose through their inputs and outputs (ADR-0038).
3. **Work and evaluation apart** — the analysis, the design and the build each run as one unit agent prescribed by its goal and its output, and each is scored by an evaluation module of its own, a fresh Evaluation AI.

A project without sub-repos is the plain case (the delivery module pushes one branch and opens
one PR).

---

## What Is AutoFlow?

AutoFlow structures a code change through modules, each an input, the work it does, and an
output ([`docs/autoflow-guide.md`](docs/autoflow-guide.md) > Modules):

```
criterion review  criterion-screen, -trace, -in-depth, -reconcile — the issue's acceptance criteria reviewed against the code and policy, each item disposed of
criteria-apply    the applied acceptance criteria, computed from the analysis report and the [ac-decision] entries (a script)
analysis          current structure, gap, necessity, conclusion with its grounds   → scored by hypothesis
design            feature design + verification design                             → scored by plan
build             test-first implementation and verification: the commits and the build report → scored by audit (test-first and the security audit)
quality           the completion evaluation of the whole change
delivery          the push and the draft PRs that show the change working (as many, and in the repositories, as the change takes)
ci                CI's verdict on each PR's head with its ground — green, or recorded as not run
review            the configured reviewers, each run by its own script, and the target's own review bots → one aggregated comment and its findings file
```

External review merges the pull request out of band.

### Key Features

- **Multi-Agent Roles** — functional-unit agents (analysis, design, build), the criterion-review agents, Evaluation AI and advisor with separated responsibilities.
- **Analysis unit** — one analysis spawn states the current structure as fact, the gap to the request and whether code is the lever, heeding stated bias cautions; a fresh evaluator scores it.
- **Evaluations** — 10-point scoring, output with the reference pass values (average ≥ 7.5, each item ≥ 7, security ≤ 3 → rework).
- **Hook Enforcement** — a shell hook denies, in every session, `gh pr merge`, a push to the default branch, `gh issue create`, a ledger rewrite, a spawn without `model` and a backgrounded suite run.
- **Sub-Repo Support** — a changed sub-repo is delivered on its own PR and the host follows it by its pointer; the project's structure is read from its own information, not classified.

---

## Quick Start

AutoFlow is a **versioned tool your own dev project consumes**, delivered by a
Claude Code plugin alone: your project is the repository Claude Code runs in, and
AutoFlow writes no file into it: its records live under a record root outside
every project's tree (`~/.autoflow` by default).

Install the plugin once per machine, at user scope:

```
/plugin marketplace add Munsik-Park/autoflow
/plugin install autoflow@autoflow
```

`/plugin install` writes the enablement into `~/.claude/settings.json`, which
turns AutoFlow on in every project you open. To keep it **off** in one
repository, write `"enabledPlugins": {"autoflow@autoflow": false}` into that
repository's `.claude/settings.json`.

Then, in your project:

- **Run a module** on an invocation file — the module's parameters, its
  inputs, the attempt's record directory and the run's output directory
  ([`docs/core.md`](docs/core.md) > Development Lifecycle): `/autoflow:<module> <invocation.json>`,
  one command per module, carries the module's procedure (ADR-0038 D9).
- **Nothing to ignore**: every record — an attempt's ledger, each run's outputs and `local/`
  store, issue drafts — is under the record root (`autoflow-records root` prints it), each
  attempt's record directory there. Set
  `"record_root": "<absolute path>"` in `~/.autoflow/config.json` to move it; the file stays where
  it is.
- **Your reviewers are set once, for every project**, in
  `~/.autoflow/config.json`. AutoFlow's SessionStart hook creates it on the
  first session start in any project where the plugin is enabled — only when it
  is absent, outside your project's tree — with
  `{ "review": { "reviewers": [] } }` and tells you so. With no reviewer named,
  the default reviewers, `claude` and `codex`, review every pull request the
  review module is given; list the reviewers there to choose them, and each one's model, effort,
  rule file and lenses file ([`docs/reviewer-backend.md`](docs/reviewer-backend.md) >
  *Config location*). A broken file is reported, and the review goes on
  without those reviewers.
- **Declare what your project needs** in `.claude/autoflow.local.json` — the
  file is yours, and absent means none of the following
  ([`.claude/autoflow.local.json.example`](.claude/autoflow.local.json.example)):
  - `audit.security_checklist` — the repository-relative path of your security
    checklist, which AUDIT scores a change against ([`docs/units/build.md`](docs/units/build.md) > *Security checklist*);
  - `tests.suite_plane` — `true` only to adopt AutoFlow's suite plane.
- **Optionally own the spawn policy**: a `.claude/autoflow/spawn-policy.json` in
  your project overrides the plugin's default model per phase
  ([`docs/tool-delivery-contract.md`](docs/tool-delivery-contract.md) > *Spawn policy*).
  The `advisor` row ships on `fable`; an account without Fable access changes
  that row's `model` there.

**Updating** is the plugin update alone: `/plugin marketplace update` →
`/plugin update autoflow@autoflow`. Which AutoFlow ran a module — the plugin
version, the loaded root and, for a checkout, its `HEAD` — is recorded in the
run's `result.json` ([`docs/tool-delivery-contract.md`](docs/tool-delivery-contract.md) > R1).
The **target check** — your own spawn policy against the loaded agent
definitions, and, on an opted-in target, the suite headers
(`<autoflow-root>/scripts/preflight/target-check.sh`) — is a script for setting
up the environment ([`docs/tool-delivery-contract.md`](docs/tool-delivery-contract.md) > R4).

**Developing AutoFlow**: `claude --plugin-dir <clone>` runs a clone's working
tree in place of the installed plugin for that session.

**Prerequisites**: Claude Code v2.1.277+, `jq` and the GitHub CLI `gh`; a GitHub
repository (one per sub-repo, for a project with sub-repos).

---

## Repository Structure

```
autoflow/
│
├── README.md
├── CLAUDE.md                          # Notes for developing AutoFlow itself (the core is docs/core.md)
│
├── .claude-plugin/                    # plugin.json + marketplace.json — the repository root is the plugin root (ADR-0027 D1)
├── agents/                            # AutoFlow role subagent definitions
├── hooks/                             # Gate hook (check-autoflow-gate.sh), read-dedup hook, user-config SessionStart hook (ensure-user-config.sh: creates ~/.autoflow/config.json when absent, in every project), hooks.json
├── skills/                            # /autoflow:<module> — one command per module (generated from docs/core.md and the documents scripts/skills/role-docs.tsv names)
├── bin/                               # autoflow-root — prints the plugin root; autoflow-records — the record root and the issue drafts directory
│
├── .github/
│   └── workflows/                     # Advisory CI guards (.github/workflows/)
│
├── docs/                              # Usage documents — carried by each role's carrier where its role follows them, otherwise read by path under the plugin root
│   ├── INDEX.md                       # Router: usage documents vs records
│   ├── core.md                        # The core: the authority rules, how a module runs, the records and the hook
│   ├── autoflow-guide.md              # Index of the modules
│   ├── contracts/                     # One contract per module (JSON), checked by scripts/contracts/contract.sh
│   ├── evaluation-system.md           # Evaluation scoring details
│   ├── git-workflow.md                # Commit format, issue closing
│   ├── repo-boundary-rules.md         # Cross-repo coordination rules
│   ├── submodule-common-rules.md      # Sub-repo shared rules
│   ├── role-common-rules.md       # Shared role-spawn behavior rules
│   ├── security-checklist.md          # This repository's own security checklist (declared in .claude/autoflow.local.json)
│   ├── units/                         # Module procedure documents, by unit (docs/units/)
│   └── records/                       # Design & decision records — the source of no rule
│       ├── design-rationale.md        # Why every rule exists — read for a decision's grounds, routed per role
│       ├── adr/                       # Architecture Decision Records
│       └── design-reviews/            # Design reviews behind the ADRs
│
├── scripts/                           # Helper / handoff scripts (scripts/)
└── tests/                             # Guard & regression suites (tests/)
```

---

## How It Works

### 1. The Core Drives AI Behavior

[`docs/core.md`](docs/core.md) is the operating manual: how a module runs, the
authority rules, agent roles and permissions, evaluation criteria, and the Git
workflow. It reaches a session through the body of a module's command, `/autoflow:<module>`, which
carries the parts of the core its module uses, and a subagent through its agent definition; each
command body carries its module's document and the other documents the session follows after the
core, and each agent definition the core parts and documents its role follows (ADR-0035).

### 2. Multi-Agent Separation

| Agent | Role | Can Write To |
|-------|------|--------------|
| **Build unit (U4)** | Implements and verifies the design per target scope, test-first | Files within the assigned scope |
| **Evaluation AI** | Scores quality | Nothing (read-only) |

### 3. Evaluation Gates

At GATE:HYPOTHESIS, GATE:PLAN, AUDIT, and GATE:QUALITY, a freshly spawned
Evaluation AI scores the work and states its grounds. The reference pass values
— average ≥ 7.5, each item ≥ 7, a security score ≤ 3 → rework — are kept with
the rubrics and output with the scores. Categories and weights are
customisable per project.

### 4. Hook Enforcement

`check-autoflow-gate.sh` keeps the policy denies, in every session and with no
state: `gh pr merge`; a push to the remote default branch; `gh issue create`; a
ledger write that changes text already in it, or an authority written by a
writer that is not its own; an `Agent` spawn without an explicit `model`; and a
backgrounded suite run ([`docs/core.md`](docs/core.md) > Records and the hook).

---

## Customization

### Repository Structure

AutoFlow does not classify a project's repository structure. The AI reads the
project's own information and rule files where they exist — a `README.md`, a
`CLAUDE.local.md`, or whatever the project keeps — for the facts the work needs
(see `docs/core.md` > Project Information), and records a fact no file states,
and the repository does not show, as a tool request. In a project with sub-repos, which PRs a
change takes, a sub-repo's included, is the delivery module's judgment
(`docs/units/delivery.md` > *Push and pull request*); what follows a merge is
outside AutoFlow (`docs/git-workflow.md` > Post-Merge Cleanup).

### Evaluation Tuning

- Adjust category **weights** to match your priorities.
- The **reference pass values** are kept with the rubrics (`docs/evaluation-system.md` > PASS Criteria) and in each evaluation contract's `reference`, which an evaluation outputs with its scores.
- Add **custom categories** as needed.

---

## Documentation

| Document | Description |
|----------|-------------|
| [**Design Rationale**](docs/records/design-rationale.md) | Why every design decision was made — a record read for a decision's grounds; which documents a role receives is routed per role (`docs/core.md` > Context Injection — Role-Scoped Document Routing) |
| [AutoFlow Guide](docs/autoflow-guide.md) | Index of the modules: each one's kind, procedure document, and what it takes and gives |
| [Evaluation System](docs/evaluation-system.md) | Scoring, the reference pass values, output format |
| [Git Workflow](docs/git-workflow.md) | Commit format, issue closing |
| [Repo Boundary Rules](docs/repo-boundary-rules.md) | Cross-repo coordination |
| [Sub-Repo Common Rules](docs/submodule-common-rules.md) | Sub-repo rules, verification and reporting |
| [Security Checklist](docs/security-checklist.md) | This repository's own security items — a target declares its own checklist (`docs/units/build.md` > *Security checklist*) |
| [Tool Delivery Contract](docs/tool-delivery-contract.md) | The plugin as the single version, the target-owned files, the spawn policy, the runtime environment |

---

## Contributing

1. Fork this repository.
2. Create a feature branch (`feature/your-change`).
3. Follow the existing documentation style.
4. Submit a PR with a clear description.

---

## License

This project is licensed under the **Apache License 2.0** — see
[`LICENSE`](LICENSE) and [`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt).

Licensing metadata follows the [REUSE 3.3](https://reuse.software) specification:
every tracked file carries an SPDX header or is covered by [`REUSE.toml`](REUSE.toml),
and `reuse lint` is enforced in CI.
