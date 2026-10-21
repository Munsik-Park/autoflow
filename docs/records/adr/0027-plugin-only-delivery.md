# ADR-0027: AutoFlow Is Delivered by the Plugin Alone; the Thin Root Layer Is Retired

## Status

Accepted (operator decision 2026-10-17, issue #454: the operator approved the #454 design and
ordered its implementation). Supersedes ADR-0015 D1's thin-root tier and D2's attachment mechanism.
ADR-0015 D3 is unaffected. Amends `docs/tool-delivery-contract.md` R1, R2 and R4, and the wording
of ADR-0025 D8 that names `drift-check.sh`. D1–D3 implemented by issue #454 PR-3; D4 and D5
implemented by issue #454 PR-4, released together as plugin version 0.3.0. D2's command list
amended by ADR-0030 (issue #465): `/autoflow:cycle <N> [new] [unit=U1…U6]`, and
`/autoflow:criterion-review <N>` runs the cycle's criterion review stage alone. D2's compaction
bullets (the leading part within 18,000 bytes, the re-invocation first line) and the R1 budget
check amendment superseded by ADR-0031 (PR #475): AutoFlow does not consider compaction. D2's
*Commands* and *The core* amended, and Alternatives > *Per-unit commands* reversed, by ADR-0032
(issue #464): `/autoflow:cycle-u1` … `/autoflow:cycle-u6` run one unit with the core parts it uses.
D2's *Subagents* first and second bullets amended by ADR-0035 (issue #494): an agent definition
carries the core parts and documents it is bound by, and a helper's prompt their text.

## Context

ADR-0015 split delivery into two channels:

- **The plugin** carries the agents, the hooks and the install skill.
- **The thin root layer** is stamped into each target. It carries the `CLAUDE.md` methodology
  prose behind an always-on `@import`, the usage documents and the scripts.

ADR-0015 rested this split on one premise: "methodology prose cannot be injected by a plugin". It
also held that Claude Code reads `CLAUDE.md` only at the project root, so a root copy layer is
"needed anyway".

Issue #454 measured the cost of that layer on one llmroute cycle (#639, plugin 0.2.35):

- The always-on import put the whole core into **every** request: about 64KB of `CLAUDE.md` plus
  `docs/INDEX.md`.
- That was 2,597 core-carrying requests: 401 in the main sessions and 2,196 in subagents.
- Every worker session's first request was 73k tokens, whichever unit it ran.

Two measurements on Claude Code 2.1.302 then replaced the premise.

**What a plugin delivers** (issue #454, measurement M1):

- `${CLAUDE_PLUGIN_ROOT}` is substituted in an agent definition's body.
- A command or skill body is loaded when the command or skill is invoked.
- The plugin's `bin/` is on the Bash `PATH` in the main session and in every subagent.
  `CLAUDE_PLUGIN_ROOT` itself is absent from the Bash environment.
- A `CLAUDE.md` at the plugin root is never loaded.
- A `--plugin-dir` plugin with the same name, `autoflow`, silently replaces the installed one:
  its agents, skills and hooks all.
- A project-local `enabledPlugins` value of `false` removes the plugin's agents, skills and
  hooks from that project.

**What survives compaction** (issue #454, measurement M2):

- An invoked command or skill body stays in the invoking session. After compaction it is
  re-attached:
  - first 5,000 tokens per skill;
  - 25,000 tokens in total;
  - most recent first, oldest dropped.
- Invoking the skill again restores its full content.

Workflow plugins deliver their working rules the same way: in the body of the command that starts
a session, and in the agent definitions. None of them injects large rule text at session start.

## Decision

### D1 — The repository root is the plugin root

**Layout**

- `.claude-plugin/plugin.json` sits beside `.claude-plugin/marketplace.json`.
- The marketplace entry's `source` is `"./"`.
- The plugin's components sit at the repository root: `agents/`, `hooks/`, `skills/` and `bin/`.
- `docs/` and `scripts/` keep their positions. A path inside the repository is therefore the
  same path inside the installed plugin.

**Removed**

- the duplicate definitions under `.claude/agents/` and `.claude/hooks/`;
- the `plugin/autoflow/` package directory;
- their byte-parity checks.

**What the cache holds**

The installed plugin cache holds the whole tracked tree of the released version. Only components
are loaded; the rest is files a role reads or runs by path.

**Development**

`claude --plugin-dir <clone>` runs a session on a plain clone's working tree. Because the plugin
name is the same, `autoflow`, the clone replaces the installed version for that session.

### D2 — Rules reach a session through the command that starts it, and a subagent through its definition

No AutoFlow rule text is loaded into every request.

**Commands**

- **`/autoflow:cycle <N> [unit=U1…U6]`** is the orchestrator's command in both operating modes.
  - Without `unit`, one session runs PREFLIGHT to HANDOFF.
  - With `unit`, a session runs that unit only, from its entry to its exit transition. This is
    the coordination mode, whose launching procedure stays machine-local.
- **`/autoflow:criterion-review <N>`** starts the criterion review outside a cycle.

*Amending note (2026-10-19).* ADR-0030 (issue #465): the criterion review is the first stage of an
attempt's cycle (CRITERION-REVIEW, inside U1); `/autoflow:cycle <N> [new] [unit=U1…U6]` runs it,
`new` being the request for a new attempt, and `/autoflow:criterion-review <N> [new]` runs that
stage alone.

*Amending note (issue #464).* ADR-0032: `/autoflow:cycle <N> [new]` runs the whole cycle in one
session; a unit runs alone through its own command, `/autoflow:cycle-u1 <N> [new]` …
`/autoflow:cycle-u6 <N>`, and the `unit=` argument is retired.

**The core**

- The body of both commands is generated from one source, `docs/core.md`, the cross-unit
  invariants and authority rules. A regeneration check keeps the committed bodies equal to the
  generator's output.
- The rules that must hold after a compaction come first in the body. The first 18,000 bytes
  stay within the 5,000-token re-attach cap.
- The body's first line instructs a compacted session to invoke the command again, with the same
  arguments, before any other action.

*Superseding note (2026-10-19).* ADR-0031: the two compaction bullets above are superseded —
AutoFlow requires idle compaction off and keeps no device for compaction; the bodies have no
leading part, no size limit and no re-invocation line.

*Amending note (issue #464).* ADR-0032: every command body is generated from the core; the
whole-cycle body carries all of it, and a unit's body the parts its unit uses, by the
classification `scripts/skills/core-units.tsv`.

**Other homes**

- **Each unit's transitions** move into that unit's document. The unit document is already read
  on entering the unit.
- **The state file's schema detail** moves to `docs/state-tracking.md`. It is read when the
  state file is written.

**Subagents**

- Each agent definition declares the AutoFlow root through `${CLAUDE_PLUGIN_ROOT}`. It names, by
  path under that root, the sections it is bound by.
- A functional unit's `general-purpose` helper receives the root and those paths in the prompt
  the unit writes for it.
- No SessionStart or SubagentStart hook injects rule text.

*Amending note (issue #494).* ADR-0035: each agent definition carries, below its own text, the
core parts and the documents it is bound by, generated by the classification
`scripts/skills/role-docs.tsv`; a helper receives the text of the rules its work follows; a command
body carries its unit's documents after its core parts.

### D3 — AutoFlow paths are written relative to an explicit root

**In documents**

- An AutoFlow document writes an AutoFlow path as `<autoflow-root>/docs/…` or
  `<autoflow-root>/scripts/…`.
- A target path stays a bare relative path: `.autoflow/…`, `.claude/autoflow.local.json`, and
  the target's own files.
- Links between AutoFlow documents stay file-relative.

**In command and agent bodies**

`<autoflow-root>` is defined by one substituted line. A context with no such line runs
`autoflow-root`, the plugin's `bin/` entry, which prints the root.

**Scripts and the hook**

- Scripts resolve their siblings from their own location, and the target from the working
  directory's git toplevel.
- The gate hook resolves its helpers from `${CLAUDE_PLUGIN_ROOT}`. It never resolves them from
  the project directory.
- The spawn policy is read in this order:
  1. `$AUTOFLOW_SPAWN_POLICY`;
  2. the target's `.claude/autoflow/spawn-policy.json`;
  3. the plugin's own `.claude/autoflow/spawn-policy.json`, the default.

### D4 — The installed plugin is the single AutoFlow version

The target carries no committed version record.

**The PREFLIGHT ledger entry**

PREFLIGHT records which AutoFlow ran the cycle:

- the plugin's name and version, from `<autoflow-root>/.claude-plugin/plugin.json`;
- the root actually loaded;
- when that root is a git work tree, its `HEAD` and whether the tree is dirty.

The record shows a `--plugin-dir` replacement that `claude plugin list` does not show.

**Fail-closed stops**

The bundle-drift stop is replaced by one fail-closed stop:

- **Target check.** This keeps drift-check's D6 and D7 legs, run from the plugin root:
  - D6: the target's own spawn policy agrees with the agent definitions the session loads;
  - D7: on a target that opted into the suite plane, every spec declares its `# ci-subject:`
    header.

**What else checks the version**

- The manifest's version agrees with the marketplace entry's at packaging time, in CI.
- Whether a newer version exists is Claude Code's plugin update, not an AutoFlow check.

### D5 — The thin root layer is retired; stamped targets are migrated once

The following are removed:

- `setup/`: the installer, the manifest, its generator, the thin-root files and `drift-check.sh`;
- the install skill;
- the stamp-only test suites.

**Migration**

- Migration is a one-time change in the stamped target's own repository. AutoFlow ships no
  migration script and no PREFLIGHT check for it. The target's pull request removes what
  AutoFlow still owns, by R4's reconcile meaning:
  - **Removed:** every `copy` artifact whose content equals the installed manifest's, and the
    shim block.
  - **Kept:** a modified `copy`, every `scaffold`, and the `json-merge` settings key.

**Target-owned files**

The target keeps what it owns:

- `.autoflow/`;
- `.claude/autoflow.local.json`;
- optionally its own spawn policy;
- its project information files.

## Amendments

### ADR-0015

**D1, plugin tier.** The plugin carries agents, hooks, skills, `bin/`, the core
(`docs/core.md`), the usage documents and the scripts. State stays in
`${CLAUDE_PROJECT_DIR}/.autoflow`, the target, unchanged.

**D1, thin-root tier, and the #53, #245 and #253 notes.** Superseded by ADR-0027 D5. Nothing is
stamped into a target.

**D2.** Superseded: the plugin is the only attachment mechanism (ADR-0027 D1), and its installed
version is the version record (ADR-0027 D4).

ADR-0015's ground that "methodology prose cannot be injected by a plugin" is replaced by the
measured command-body and agent-body channels (issue #454).

### `docs/tool-delivery-contract.md`

**R1 — Tool version (new text).**

- **[MUST]** The AutoFlow version a target runs is the installed plugin's version
  (`<autoflow-root>/.claude-plugin/plugin.json` `.version`). The target commits no version
  record.
- **[MUST]** Every cycle records, in its PREFLIGHT ledger entry:
  - the plugin version;
  - the loaded root;
  - when the root is a git work tree, its `HEAD` and dirty state.
- The tool never records the target's version. The dependency stays one-way, target → tool.
- An unpinned (`latest`) plugin version is not a supported configuration; the packaging check
  enforces an explicit version.

**R2 — Rule delivery (new text).**

- The methodology prose is tool-versioned content. It reaches a session only through:
  - the body of the AutoFlow command that starts the session;
  - an AutoFlow agent definition;
  - an AutoFlow document a role reads by path under `<autoflow-root>`.
- **[DENY]** Copying AutoFlow rule text into a target's own files. A framework change goes
  upstream and arrives with a plugin update. Target-local behavior goes to the project's own
  files (R3).

**R3.** Unchanged.

**R4 — Packaging and runtime checks (new text).**

- **[MUST]** The plugin package is the repository's tracked tree at the released version. CI
  checks that:
  - every component resolves inside it;
  - every `<autoflow-root>/…` reference in a document, an agent definition or a command body
    resolves inside it;
  - the generated command bodies equal their generator's output;
  - each command body's leading section fits the compaction re-attach budget.
- **[MUST]** The following is a fail-closed PREFLIGHT stop, in the same class as the
  Git-clean hard stop:
  - a failed target check: the target's spawn policy against the loaded agent definitions, and
    the suite-plane headers on an opted-in target.
- The checks run from the plugin root and need no network access.

**Spawn policy.** The spawn policy is a sample the plugin ships and uses by default. A target may
own `.claude/autoflow/spawn-policy.json`, which then takes precedence. Its `check` against the
loaded agent definitions is part of the target check.

### ADR-0025

D8's "fail-closed checks that existed before stay as they are (`drift-check.sh`, …)" now reads
"… (the PREFLIGHT target check, …)".

## Alternatives Considered

**Keep the stamp beside the plugin for a transition period.**

Rejected:

- A stamped target would load its stamped core on every request and the plugin's command body
  as well: two versions of the rules in one context.
- The user-scope plugin is one version per machine, so the period could not separate targets
  by version anyway.
- The one stamped target, connev-llm/llmroute, migrates with a single pull request in that repository.

**Assemble a package under `plugin/autoflow/` in a packaging step.**

Rejected:

- A marketplace install copies the source directory without a build, so the assembled docs and
  scripts would have to be committed twice.
- A `--plugin-dir` session on a clone would read the copy, not the edited source, until the step
  ran again.

**Per-unit commands.**

Rejected (reversed by ADR-0032 — with a session per unit, each session invokes one command, and
ADR-0031 removed the compaction grounds):

- Unit documents (5–10k tokens) exceed the 5,000-token re-attach cap, so moving them into
  command bodies gains no compaction survival.
- A single-orchestrator session invoking six commands would carry the shared rules six times.
- After compaction, the 25,000-token budget would re-attach the same leading text five times.

**Session-start injection** (SessionStart / SubagentStart `additionalContext`).

Rejected:

- SubagentStart reaches every subagent, including a user's own `general-purpose` spawns in
  every repository where the plugin is enabled.
- No workflow plugin delivers rules this way.

**`--append-system-prompt-file` / `--add-dir` from a coordination session.**

Rejected: a session the operator starts directly would carry no AutoFlow rules, contrary to the
goal that installing the plugin is enough.

**Running Claude Code from the AutoFlow checkout against a target at another path.**

Rejected: the hook would keep state in the checkout, while the cwd-rooted scripts would read the
target (issue #454 inventory).

**Detecting whether a repository uses AutoFlow by a marker file.**

Rejected (issue #457, PR #458): where the plugin is active is decided only by Claude Code's
install scope and a per-repository `enabledPlugins` disable.

## Consequences

### Positive

- **Lower context cost.** On #639's numbers, cache read falls by an estimated 35–39M tokens:
  5.8–6.5% of the cycle, and 79–89% of what the core carried.
  - Subagent requests carry no core.
  - Main requests carry a command body of about 9k tokens instead of about 17k.
- **No AutoFlow files in a target, and no re-stamp pull requests.** A plugin update is the whole
  upgrade.
- **Development switch.** `--plugin-dir <clone>` runs a working tree's rules, documents and
  scripts with no build step. Without it, a cycle on the AutoFlow repository runs the released
  tool against the working tree as its target.
- **Explicit `<autoflow-root>` paths.** They end two collisions:
  - a target file with the same name as an AutoFlow file, such as `docs/security-checklist.md`;
  - the tool/target overlap in the AutoFlow repository itself.

### Negative

- **Compaction.**
  - A compacted orchestrator session must invoke `/autoflow:cycle` again; until it does, the
    body past the first 5,000 tokens is absent.
  - If the operator invokes more than four other skills in the same session after it, the
    25,000-token budget can drop the AutoFlow body entirely.
- **Larger cache.** The cache holds the whole tracked tree per version: about 2.1MB, against
  about 160KB.
- **Silent `--plugin-dir` replacement.** It shows only in the PREFLIGHT record and the debug
  log.
- **Mechanical rewrite.** About 340 path references and 113 `CLAUDE.md >` citations move to the
  new notation and homes.

### Neutral / Trade-Offs

- **Unchanged:**
  - the gate hook's decisions;
  - the ledger's writer authority;
  - the state schema's meaning;
  - the state location, `${CLAUDE_PROJECT_DIR}/.autoflow` in the target;
  - the routing of Flow Control.
- **The AutoFlow repository's own `CLAUDE.md`** keeps only what is specific to developing
  AutoFlow. The core's source is `docs/core.md`.

## Related Issues / PRs

- #454 — measurement and design (this ADR)
- #452, #453 — decision-point judgment; U4 helper spawn rows (`general-purpose`), kept unchanged
- #457 / PR #458 — marker-file detection, rejected
- ADR-0015 — superseded in D1 (thin-root tier) and D2
- ADR-0024 — the suite-plane devices it ships run from the plugin root; drift-check D7 becomes the
  target check's D7 leg (ADR-0024 > Amendment note (issue #454))
- ADR-0025 D8 — wording amended

## Notes

- The measurements behind the Context are recorded on issue #454: M1 (delivery channels) and
  M2 (compaction survival).
- Skill-body substitution of `${CLAUDE_PLUGIN_ROOT}` is documented, and the install skill relies
  on it. The implementing pull request that adds the command bodies (#454 PR-3) recorded a probe
  on Claude Code 2.1.302: a nested `claude -p --plugin-dir <clone> --model sonnet` session
  invoking `/autoflow:criterion-review` received the body with the root declaration line
  substituted to the clone's absolute path, and `$ARGUMENTS` substituted in the same body. The
  "Base directory for this skill" fallback is therefore not written into the bodies.
- codex's `workspace-write` sandbox read a file outside the workspace and outside its writable
  roots on macOS (codex-cli 0.163.0), while a write there was refused (#454 PR-1); the Linux
  sandbox was not measured.
