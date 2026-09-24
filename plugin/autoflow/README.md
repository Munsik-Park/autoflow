# AutoFlow plugin

The AutoFlow methodology engine packaged as a Claude Code plugin: the phase-gate
hooks (`check-autoflow-gate.sh`, `check-read-dedup.sh`), the five role subagents
(`autoflow-analyzer` / `-planner` / `-implementer` / `-tester` / `-evaluator`),
and the `install` and `epic-dash` skills.

This plugin ships the **engine** only. The methodology prose (`CLAUDE.md`, `docs/`)
is delivered separately as the thin root layer; per-issue runtime state lives in the
target project's `.autoflow/` directory, resolved via `${CLAUDE_PROJECT_DIR}` — never
under the plugin root.

## What it installs

| Component | Source | Runtime |
|-----------|--------|---------|
| PreToolUse gate | `hooks/check-autoflow-gate.sh` (via `hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}`-anchored) | reads state at `${CLAUDE_PROJECT_DIR}/.autoflow` |
| PostToolUse read-dedup guard | `hooks/check-read-dedup.sh` | — |
| Role subagents | `agents/*.md` | invoked as `autoflow-*` subagent types |
| Epic dashboard skill | `skills/epic-dash/` | invoked as `/autoflow:epic-dash` |

The hook **scripts** are located by the harness through `${CLAUDE_PLUGIN_ROOT}`, while
the per-project **state** they read and write is always rooted at `${CLAUDE_PROJECT_DIR}`.
The two path variables are never conflated: no shipped script resolves `.autoflow`
through `${CLAUDE_PLUGIN_ROOT}`.

## Installing

Enabling the plugin is a **one-time user-scope step**, done once per machine and
not once per repository. Attach the self-hosted marketplace with the git-add form,
then install it:

```sh
/plugin marketplace add Munsik-Park/autoflow
/plugin install autoflow@autoflow
```

> Note: use the `owner/repo` git-add form above, not a raw-URL marketplace add.

`/plugin install` writes the enablement into your **user** settings
(`~/.claude/settings.json`), which is what turns the plugin on in every project
you open. A per-repository stamp (`/autoflow:install`) delivers the thin root
layer and the version record into one target; it does not enable the plugin, and
updating the plugin is `/plugin marketplace update` at user scope followed by a
re-stamp of each target.

## Marketplace declaration in project settings (reference)

A target project records **which marketplace its AutoFlow comes from** in its own
`.claude/settings.json`. The stamp merges this in:

```json
{
  "extraKnownMarketplaces": {
    "autoflow": {
      "source": { "source": "github", "repo": "Munsik-Park/autoflow" }
    }
  }
}
```

The `extraKnownMarketplaces` key is the marketplace name (`autoflow`), and the
entry names the repository to clone — **not** a plugin version. The target's
version record is the installed manifest `.claude/autoflow/manifest.json`
(`.version`), which the drift detector compares against the installed plugin's
`plugin.json` (D2).

The pin carries **no `enabledPlugins` key**. Do not add an `enabledPlugins` key
set to `true`. A repository that wants AutoFlow **off** writes
`"enabledPlugins": {"autoflow@autoflow": false}` into its own
`.claude/settings.json` by hand, and a re-stamp preserves it
(`setup/SETUP-GUIDE.md` > Prerequisites).

The pin carries no `env` block either. A target that carries
`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` can remove it by hand
(`setup/SETUP-GUIDE.md` > Prerequisites).

This snippet is a **reference only** — this package does not stamp it into any target.
