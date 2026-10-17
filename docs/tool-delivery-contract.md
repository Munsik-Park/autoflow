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
| R1 — Tool version | plugin packaging, the PREFLIGHT plugin record |
| R2 — Rule delivery | the command bodies, the agent definitions |
| R3 — Target-identity separation (the project's own files) | the plugin package |
| R4 — Packaging and runtime checks | CI, the PREFLIGHT target check |

Terminology: the **plugin package** is the marketplace-distributed, versioned
tool — this repository's tracked tree at a released version, whose root is the
plugin root. Its components are `<autoflow-root>/agents/`, `<autoflow-root>/hooks/`,
`<autoflow-root>/skills/` and `<autoflow-root>/bin/`; `<autoflow-root>/docs/` and
`<autoflow-root>/scripts/` are the files its roles read and run by path. Nothing is
written into a target's tree by the tool: the target holds only the files it
owns (R3, *Target-owned files* below).

---

## R1 — Tool Version

- **[MUST]** The AutoFlow version a target runs is the installed plugin's version
  (`<autoflow-root>/.claude-plugin/plugin.json` `.version`). The target commits no
  version record.
- **[MUST]** Every cycle records, in its PREFLIGHT ledger entry, the plugin
  version, the loaded root, and — when the root is a git work tree — its `HEAD`
  and dirty state ([U1 Preparation](units/preparation.md) > *What is asked*).
- **[MUST]** The tool never records the target's version. The dependency stays
  one-way, target → tool.
- An unpinned (`latest`) plugin version is not a supported configuration; the
  packaging check enforces an explicit version.

## R2 — Rule Delivery

- The methodology prose is tool-versioned content. It reaches a session only
  through the body of the AutoFlow command that starts the session
  (`/autoflow:cycle`, `/autoflow:criterion-review`), an AutoFlow agent
  definition, or an AutoFlow document a role reads by path under
  `<autoflow-root>`.
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
  body resolves inside it; that the generated command bodies equal their
  generator's output; and that each command body's leading section fits the
  compaction re-attach budget.
- **[MUST]** A failed **target check** is a fail-closed PREFLIGHT stop, in the
  same class as the Git-clean hard stop: the target's own spawn policy against
  the loaded agent definitions and the plugin's default, and the suite-plane
  headers on an opted-in target
  (`<autoflow-root>/scripts/preflight/target-check.sh`; [U1
  Preparation](units/preparation.md) > *Stop conditions*).
- The checks run from the plugin root and need no network access. Whether a
  newer version exists is Claude Code's plugin update, not an AutoFlow check.

### Target-owned files

| Path in the target | Content |
|---|---|
| `.autoflow/` | per-issue state, ledger and analysis artifacts, and the cycle-layer store (gitignored); the hook and the scripts resolve it from the target, never from the plugin root |
| `.claude/autoflow.local.json` | the target's declarations — external reviewers, local checks, the security checklist, the suite-plane opt-in; written by the target, sample at `<autoflow-root>/.claude/autoflow.local.json.example`; absent means no external reviewer, no local check, no checklist and no suite plane |
| `.claude/autoflow/spawn-policy.json` | optional: the target's own spawn policy (*Spawn policy* below) |
| the project's information and rule files | R3 |

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
| `CLAUDE_PROJECT_DIR` | Claude Code (the project root) | the hook resolves the target's `.autoflow/` from it; Claude Code runs from the target's root |
| `CLAUDE_PLUGIN_ROOT` | the plugin loader | substituted in `<autoflow-root>/hooks/hooks.json`, the agent definitions and the command bodies, and set in the hook's environment; absent from a Bash command's environment, where `autoflow-root` (`<autoflow-root>/bin/autoflow-root`, on the Bash `PATH`) prints the root; it never resolves `.autoflow` |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | not provisioned | AutoFlow neither requires nor reads it |

**Runtime prerequisite**: Claude Code **v2.1.277+** — the release that removed the
blocking `TaskOutput` tool, whose removal *Wait discipline* relies on in place of
a hook deny (`<autoflow-root>/docs/records/design-rationale.md` > Decision 34).
