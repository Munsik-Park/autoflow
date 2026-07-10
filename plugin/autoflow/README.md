# AutoFlow plugin

The AutoFlow methodology engine packaged as a Claude Code plugin: the phase-gate
hooks (`check-autoflow-gate.sh`, `check-read-dedup.sh`), the five role subagents
(`autoflow-analyzer` / `-planner` / `-implementer` / `-tester` / `-evaluator`),
and the `epic-dash` skill.

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

Attach the self-hosted marketplace with the git-add form (the marketplace repo is
cloned, so the plugin's relative `source: ./plugin/autoflow` resolves):

```sh
/plugin marketplace add Munsik-Park/autoflow
/plugin install autoflow@autoflow
```

> Note: use the `owner/repo` git-add form above. A raw-URL marketplace add fetches
> only the marketplace JSON and would not resolve the relative plugin `source`.

## Pinning in project settings (reference)

To enable the plugin non-interactively, a target project pins it in its own
`.claude/settings.json`. The plugin is version-pinned by the marketplace entry, so a
target only receives updates when the pin id's resolved version is bumped (unpinned
"latest" is not a supported configuration). Merge this into the target's settings:

```json
{
  "extraKnownMarketplaces": {
    "autoflow": {
      "source": { "source": "github", "repo": "Munsik-Park/autoflow" }
    }
  },
  "enabledPlugins": { "autoflow@autoflow": true },
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }
}
```

The `enabledPlugins` key is the `"<plugin>@<marketplace>"` composition
(`autoflow@autoflow`), and the `extraKnownMarketplaces` key is the marketplace
name (`autoflow`). The `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` key enables
Claude Code's experimental Agent Teams — the methodology's Communication layer requires
it, and it is default-off upstream, so the pin ships it set to `"1"`.

This snippet is a **reference only** — this package does not stamp it into any target.
The installer that writes it into a target's settings is a separate deliverable.
