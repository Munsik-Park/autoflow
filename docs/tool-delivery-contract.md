# Tool Delivery Contract

> The four delivery-contract rules for AutoFlow as a consumed, versioned tool.
> Rule vocabulary uses **plugin-version** terms.

---

## Scope and Status

This document is the **policy source of truth** for how the AutoFlow tool is
delivered to a target project and kept consistent with it. The enforcing
mechanisms conform to these rules.

| Rule | Enforced by |
|------|-------------|
| R1 — Tool version | plugin packaging; every run's `result.json` records the AutoFlow that ran it |
| R2 — Rule delivery | the command bodies, the agent definitions and the reviewers' rule files, generated and checked (regen-clean); the reviewer wrappers' prompts |
| R3 — Target-identity separation (the project's own files) | the plugin package |
| R4 — Packaging and runtime checks | CI; the target check, a script for setting up the environment |

Terminology: the **plugin package** is the marketplace-distributed, versioned
tool — this repository's tracked tree at a released version, whose root is the
plugin root. Its components are `<autoflow-root>/agents/`, `<autoflow-root>/hooks/`,
`<autoflow-root>/skills/` and `<autoflow-root>/bin/`; `<autoflow-root>/docs/` and
`<autoflow-root>/scripts/` are the files its roles read and run by path. Nothing is
written into a target's tree by the tool: the target holds only the files it
owns (R3, *Target-owned files* below). The one file the tool writes is outside
every target, under the operator's `$HOME` (*Operator-level file* below).

---

## R1 — Tool Version

- **[MUST]** The AutoFlow version a target runs is the installed plugin's version
  (`<autoflow-root>/.claude-plugin/plugin.json` `.version`). The target commits no
  version record.
- Which AutoFlow a module ran on — the plugin version, the loaded root, and,
  when the root is a git work tree, its `HEAD` and dirty state — is recorded in
  the run's `<out>/result.json` (`autoflow`), which
  `<autoflow-root>/scripts/contracts/contract.sh` writes at check-in's refusal
  and at check-out (ADR-0027 D4); it is not a ledger entry
  ([ADR-0038](records/adr/0038-contract-modules-with-no-state-file.md) D8).
- **[MUST]** The tool never records the target's version. The dependency stays
  one-way, target → tool.
- An unpinned (`latest`) plugin version is not a supported configuration; the
  packaging check enforces an explicit version.

## R2 — Rule Delivery

- The methodology prose is tool-versioned content. It reaches a role only
  through the carrier the role starts with — a session through the body of
  the AutoFlow command that starts it (`/autoflow:<module>`, one per module,
  carrying the parts of the core the module uses — ADR-0038 D9), a subagent
  through its
  AutoFlow agent definition, a reviewer through its rule file, which its
  wrapper's prompt carries, and a spawn with no AutoFlow definition through
  the prompt its spawner writes — or as an AutoFlow document a role reads by
  path under `<autoflow-root>` beyond its guidance
  (`<autoflow-root>/docs/core.md` > Context Injection).
- **[DENY]** Copying AutoFlow rule text into a target's own files. A framework
  change goes upstream to the tool repository and arrives with a plugin update;
  target-local behavior goes to the project's own files (R3).

## R3 — Target-Identity Separation [MUST]

- **[MUST]** Target identity — organization and repository names, default
  branch, repository structure, stack and deployment specifics, service names,
  and any target-local operating rules — never lives in the delivered rules. It
  lives in the project's own information and rule files
  (`<autoflow-root>/docs/core.md` > Project Information); which files, and what
  they say, are the project's.
- **[MUST]** The tool never ships, writes, or overwrites a project information
  file. Such a file is outside the delivered surface.
- Whether the target commits such a file or keeps it ignored is the target's
  own policy; this contract fixes only the boundary — identity content sits
  outside the tool-delivered surface.

## R4 — Packaging and Runtime Checks

- **[MUST]** The plugin package is the repository's tracked tree at the released
  version. CI checks that every component resolves inside it; that every
  `<autoflow-root>/…` reference in a document, an agent definition or a command
  body resolves inside it; and that the generated command bodies equal their
  generator's output.
- The **target check** — the target's own spawn policy against the loaded agent
  definitions and the plugin's default, and the suite-plane headers on an
  opted-in target (`<autoflow-root>/scripts/preflight/target-check.sh`) — is a
  script for setting up the environment (ADR-0038 D4).
- The checks run from the plugin root and need no network access. Whether a
  newer version exists is Claude Code's plugin update, not an AutoFlow check.

### Target-owned files

| Path in the target | Content |
|---|---|
| `.claude/autoflow.local.json` | the target's declarations — the security checklist, the suite-plane opt-in; written by the target, sample at `<autoflow-root>/.claude/autoflow.local.json.example`; absent means no checklist and no suite plane. The reviewers are not declared here (*Operator-level file* below) |
| `.claude/autoflow/spawn-policy.json` | optional: the target's own spawn policy (*Spawn policy* below) |
| the project's information and rule files | R3 |

### Operator-level file

| Path | Content |
|---|---|
| `$HOME/.autoflow/config.json` | the operator's own values, one file per machine user: the reviewers AutoFlow runs in every project (`{ "review": { … } }`; [`reviewer-backend.md`](reviewer-backend.md) > *Config location*), and the record root (`"record_root": "<absolute path>"`, default `$HOME/.autoflow`) |
| the record root (`$HOME/.autoflow` by default) | every file AutoFlow writes: each attempt's record directory — the ledger and each run's subdirectory, its outputs and its `local/` store — the issue drafts `<repo-key>/drafts/`, proposal records `<repo-key>/proposals/` and `_metrics/`; outside every checkout's tree, so a target needs no ignore rule for AutoFlow, and the scripts resolve it through `<autoflow-root>/scripts/lib/records.sh` (`autoflow-records`, on the Bash `PATH`), never from the plugin root or the target ([`core.md`](core.md) > Records and the hook) |

It is neither target-owned nor shipped. The plugin's SessionStart hook
(`<autoflow-root>/hooks/ensure-user-config.sh`, wired in
`<autoflow-root>/hooks/hooks.json`) runs at every session start in every project
the plugin is enabled in and writes outside the target's tree: when the file is
absent it creates it with `{ "review": { "reviewers": [] } }` and tells the
operator where it is and what it holds; when it exists — valid or not — it
leaves it unchanged and says nothing. Concurrent session starts create it once
and never overwrite it. Its location is defined once, in
`<autoflow-root>/scripts/lib/user-config.sh` ([ADR-0028](records/adr/0028-user-level-reviewer-config.md)).

### Spawn policy

`<autoflow-root>/.claude/autoflow/spawn-policy.json` — the per-phase spawn model and effort policy ([`core.md`](core.md) > Spawn Model) — is a **sample carrying the values currently applied**, and the plugin uses it by default. A target may
own `.claude/autoflow/spawn-policy.json`, which then takes precedence (`$AUTOFLOW_SPAWN_POLICY` first,
the target's policy second, the plugin's default last), and configures it for its own runtime — its model
rows, its `general-purpose` helper rows' effort and its `workflow_sites` effort. The effort of a `phases[]` row
on a shipped definition is **not** a target lever: a direct spawn of that definition takes its effort from the
definition's `effort:` frontmatter (the spawn passes `model` per call and leaves effort to the definition),
and the definitions are versioned tool source every target loads from the plugin, so that value is
fixed per plugin version; the config row is the projection source at this repository and `check` fails
closed when it differs from the loaded definition. A row on a harness research type admits the inherit
sentinel only, and a row on `general-purpose` — a unit's helper, spawned with the row's effort as the Agent
tool's `effort` parameter, or with the parameter omitted for the inherit sentinel — admits any value in the
vocabulary (`effort_contract.phase_effort_ownership`, `sentinel_is_config_only`). Its
`effort_contract` is the effort vocabulary `check` applies to it — a runtime with a different
vocabulary is accommodated by editing that contract, never by patching the checker — and the
`effort` readout prints the inherit sentinel that contract declares rather than a fixed literal. A
target's own policy is checked by the target check's D6 leg (R4) against the loaded definitions and the
default's row set; on a version bump the target adds any newly required row it names, or deletes its
copy to take the default.

The same file carries per-site values for a shipped workflow (`workflow_sites`; empty while
AutoFlow ships none). It also documents its own inheritance rule (`effort_contract`) and declares any shipped agent type the
policy governs no row for (`policy_unmapped_agent_types`).

## Runtime environment

| Variable | Provisioned by | Contract |
|---|---|---|
| `CLAUDE_PROJECT_DIR` | Claude Code (the project root) | the hook takes the session's checkout from it — whose remote default branch the push deny reads; Claude Code runs from the target's root |
| `CLAUDE_PLUGIN_ROOT` | the plugin loader | substituted in `<autoflow-root>/hooks/hooks.json`, the agent definitions and the command bodies, and set in the hook's environment; absent from a Bash command's environment, where `autoflow-root` (`<autoflow-root>/bin/autoflow-root`, on the Bash `PATH`) prints the root; it never resolves a record path |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | not provisioned | AutoFlow neither requires nor reads it |
| `HOME` | the operator's shell | locates the operator-level file `$HOME/.autoflow/config.json` for the SessionStart hook, the review resolver and the record root, and the default record root `$HOME/.autoflow`; with `HOME` unset or empty there is no such file, and the record root is undetermined |
