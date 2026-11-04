# Tool Delivery Contract

> The delivery contract for AutoFlow as a consumed, versioned tool: the plugin.

---

## Scope

This document is the **policy source of truth** for how the AutoFlow tool is
delivered to a target project. The enforcing
mechanisms conform to these rules.

Terminology: the **plugin package** is the marketplace-distributed, versioned
tool — this repository's tracked tree at a released version, whose root is the
plugin root. Its components are `<autoflow-root>/agents/`, `<autoflow-root>/hooks/`,
`<autoflow-root>/skills/` and `<autoflow-root>/bin/`; `<autoflow-root>/docs/` and
`<autoflow-root>/scripts/` are the files its roles read and run by path. The target
holds only the files it owns (*Target-owned files* below). What the tool
writes, the operator-level file and the record root, is outside every target
(*Operator-level file* below).

---

## Tool Version

- **[MUST]** The AutoFlow version a target runs is the installed plugin's version
  (`<autoflow-root>/.claude-plugin/plugin.json` `.version`).
- Which AutoFlow a module ran on — the plugin version, the loaded root, and,
  when the root is a git work tree, its `HEAD` and dirty state — is recorded in
  the run's `<out>/result.json` (`autoflow`), which
  `<autoflow-root>/scripts/contracts/contract.sh` writes at check-in's refusal
  and at check-out (ADR-0027 D4).
- **[MUST]** The tool never records the target's version. The dependency stays
  one-way, target → tool.
- An unpinned (`latest`) plugin version is not a supported configuration; the
  packaging check enforces an explicit version.

## Rule Delivery

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
- A framework change goes upstream to the tool repository and arrives with a
  plugin update.

## Packaging and Runtime Checks

- **[MUST]** The plugin package is the repository's tracked tree at the released
  version. CI checks that every component resolves inside it; that every
  `<autoflow-root>/…` reference in a document, an agent definition or a command
  body resolves inside it; and that the generated command bodies equal their
  generator's output.
- The **target check** — the target's own spawn policy against the loaded agent
  definitions and the plugin's default, and the suite-plane headers on an
  opted-in target (`<autoflow-root>/scripts/preflight/target-check.sh`) — is a
  script for setting up the environment (ADR-0038 D4).
- The checks run from the plugin root and need no network access.

## Target-owned files

| Path in the target | Content |
|---|---|
| `.claude/autoflow.local.json` | the target's declarations — the security checklist, the suite-plane opt-in; written by the target, sample at `<autoflow-root>/.claude/autoflow.local.json.example`; absent means no checklist and no suite plane |
| `.claude/autoflow/spawn-policy.json` | optional: the target's own spawn policy (*Spawn policy* below) |

## Operator-level file

| Path | Content |
|---|---|
| `$HOME/.autoflow/config.json` | the operator's own values, one file per machine user: the reviewers AutoFlow runs in every project (`{ "review": { … } }`; [`reviewer-backend.md`](reviewer-backend.md) > *Config location*), and the record root (`"record_root": "<absolute path>"`, default `$HOME/.autoflow`) |
| the record root (`$HOME/.autoflow` by default) | every file AutoFlow writes: each attempt's record directory — the ledger and each run's subdirectory, its outputs and its `local/` store — the issue drafts `<repo-key>/drafts/`, proposal records `<repo-key>/proposals/` and `_metrics/`; outside every checkout's tree, and the scripts resolve it only through `<autoflow-root>/scripts/lib/records.sh` (`autoflow-records`, on the Bash `PATH`) ([`core.md`](core.md) > Records and the hook) |

The plugin's SessionStart hook
(`<autoflow-root>/hooks/ensure-user-config.sh`, wired in
`<autoflow-root>/hooks/hooks.json`) runs at every session start in every project
the plugin is enabled in and writes outside the target's tree: when the file is
absent it creates it with `{ "review": { "reviewers": [] } }` and tells the
operator where it is and what it holds; when it exists — valid or not — it
leaves it unchanged and says nothing. Concurrent session starts create it once
and never overwrite it. Its location is defined once, in
`<autoflow-root>/scripts/lib/user-config.sh` ([ADR-0028](records/adr/0028-user-level-reviewer-config.md)).

## Spawn policy

`<autoflow-root>/.claude/autoflow/spawn-policy.json` — the per-phase spawn model and effort policy ([`core.md`](core.md) > Spawn Model) — is a **sample carrying the values currently applied**, and the plugin uses it by default. A target may
own `.claude/autoflow/spawn-policy.json`, which then takes precedence (`$AUTOFLOW_SPAWN_POLICY` first,
the target's policy second, the plugin's default last), and configures it for its own runtime — its model
rows, its `general-purpose` helper rows' effort and its `workflow_sites` effort. A direct spawn of a shipped definition
takes its effort from the definition's `effort:` frontmatter (the spawn passes `model` per call and leaves
effort to the definition), and the definitions are versioned tool source every target loads from the plugin,
so the effort of a `phases[]` row on a shipped definition is
fixed per plugin version; the config row is the projection source at this repository and `check` fails
closed when it differs from the loaded definition. A row on a harness research type admits the inherit
sentinel only, and a row on `general-purpose` — a unit's helper, spawned with the row's effort as the Agent
tool's `effort` parameter, or with the parameter omitted for the inherit sentinel — admits any value in the
vocabulary (`effort_contract.phase_effort_ownership`, `sentinel_is_config_only`). Its
`effort_contract` is the effort vocabulary `check` applies to it — a runtime with a different
vocabulary is accommodated by editing that contract — and the
`effort` readout prints the inherit sentinel that contract declares. A
target's own policy is checked by the target check's D6 leg (*Packaging and Runtime Checks*) against the loaded definitions and the
default's row set; on a version bump the target adds any newly required row it names, or deletes its
copy to take the default.

The same file carries per-site values for a shipped workflow (`workflow_sites`; empty while
AutoFlow ships none). It also documents its own inheritance rule (`effort_contract`) and declares any shipped agent type the
policy governs no row for (`policy_unmapped_agent_types`).

## Runtime environment

| Variable | Provisioned by | Contract |
|---|---|---|
| `CLAUDE_PROJECT_DIR` | Claude Code (the project root) | the hook takes the session's checkout from it — whose remote default branch the push deny reads; Claude Code runs from the target's root |
| `CLAUDE_PLUGIN_ROOT` | the plugin loader | substituted in `<autoflow-root>/hooks/hooks.json`, the agent definitions and the command bodies, and set in the hook's environment; absent from a Bash command's environment, where `autoflow-root` (`<autoflow-root>/bin/autoflow-root`, on the Bash `PATH`) prints the root |
| `HOME` | the operator's shell | locates the operator-level file `$HOME/.autoflow/config.json` for the SessionStart hook, the review resolver and the record root, and the default record root `$HOME/.autoflow`; with `HOME` unset or empty there is no such file, and the record root is undetermined |
