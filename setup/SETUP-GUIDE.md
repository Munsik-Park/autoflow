# Manual Setup Guide

> **Install-into-TARGET** (below) is the only supported model for consuming
> AutoFlow as a versioned tool inside your own dev project. Run
> `setup/init.sh --target <path>`, or follow the manual steps below.

---

## Install as a consumed tool

Epic #785 inverts the dependency direction: your dev project is the repo root
(host) and AutoFlow is a **versioned tool it consumes**. Onboarding is **3
commands**, run from a Claude Code session rooted in your project:

```
1. /plugin marketplace add Munsik-Park/autoflow
2. /plugin install autoflow@autoflow
3. /autoflow:install        # detects → confirms → stamps → drift-checks
```

Step 3 is the `/autoflow:install` skill. It detects root-layer absence or drift
and reports the derived org/repo/branch/topology (read-only), asks for a
**single** confirmation, then stamps the thin-root bundle from the marketplace
cache and runs `drift-check.sh` automatically. Nothing is written to your
project before you confirm, and the skill never commits — you own the version
record (R1). Maintenance later is just `/plugin marketplace update` →
`/autoflow:install` (re-stamp).

### Manual / CI-scripted install (`init.sh --target`)

The `/autoflow:install` skill wraps exactly this call; run it by hand when you
need a scripted install (CI) or want to stamp before enabling the plugin.
Instead of copying templates by hand, run the installer against your target
project root:

```bash
# From a checkout of claude-autoflow, install the bundle into your project:
setup/init.sh --target /path/to/your-project

# Re-run any time to upgrade / re-stamp (idempotent):
setup/init.sh --target /path/to/your-project --force
```

The install is **manifest-driven**: `setup/manifest.json` is the exhaustive,
machine-readable list of every artifact the installer writes, with a per-file
`source`, `dest` (target-root-relative), `tier`, `kind`, and `sha256`. Nothing
is hardcoded in `init.sh`; the manifest is the single source of truth and is
itself copied into the target (`.claude/autoflow/manifest.json`) so the target
can self-describe and self-verify offline.

### What lands in the target (thin-root artifacts)

| Artifact | Target-root location | Kind |
|----------|----------------------|------|
| Import shim (managed `AUTOFLOW-IMPORT` block in your `CLAUDE.md`) | `CLAUDE.md` | shim-stamp |
| Methodology entrypoint + framework prose | `.claude/autoflow/METHODOLOGY.md`, `.claude/autoflow/CLAUDE.md`, `.claude/autoflow/docs/**` | copy |
| Deliberation workflows | `.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js` | copy |
| Settings pin (marketplace + `enabledPlugins`) | `.claude/settings.json` | json-merge |
| Drift detector + drift references | `.claude/autoflow/drift-check.sh` | copy |
| Plugin / marketplace-clone resolver (used by the drift detector and by `spawn-policy.sh check`) | `scripts/lib/plugin-root.sh` | copy |
| Local overrides scaffold (never overwritten) | `CLAUDE.local.md` | scaffold |
| Spawn policy sample (target-configured, never overwritten) | `.claude/autoflow/spawn-policy.json` | scaffold |

The shim stamp is idempotent and only touches the `AUTOFLOW-IMPORT:BEGIN/END`
managed block — your own `CLAUDE.md` prose is preserved. The settings merge is a
deep-merge: your pre-existing `.claude/settings.json` keys are kept, and the
AutoFlow marketplace/`enabledPlugins` pin is added. The pin carries no `env`
block — the Agent Teams channel is retired (ADR-0017 / ADR-0021), so the
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enablement an earlier pin stamped is no
longer provisioned (see Prerequisites for targets stamped by that earlier pin).
`CLAUDE.local.md` holds your target identity (R3) and is never overwritten, even
with `--force`. `.claude/autoflow/spawn-policy.json` is scaffolded for the same
reason: it is a sample carrying the values currently applied, which you configure
for your own runtime, so a re-stamp will not overwrite a configured policy and
`drift-check.sh` reports it as target-owned rather than as content drift. On a
version bump your obligation is to run
`bash scripts/spawn-policy/spawn-policy.sh check` and add any newly required row —
a scaffold is never refreshed for you. `check` validates the config's agent types
against the agent definitions the session actually loads: `.claude/agents/` when
that directory holds `autoflow-*.md` files (the framework repository, or a target
carrying its own copies), otherwise the installed plugin's `agents/` — resolved
through `scripts/lib/plugin-root.sh` from `CLAUDE_PLUGIN_ROOT` (hook context) or,
in a plain shell, from the harness's own registries under
`${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/`. A thin-root target ships no
`.claude/agents/`, so the plugin is where `check` reads them; when the lookup
cannot see the plugin, point it there: `CLAUDE_PLUGIN_ROOT=<plugin dir> bash
scripts/spawn-policy/spawn-policy.sh check`. With no definitions anywhere `check`
fails closed and lists every location it consulted.

### Self-verify with the drift detector

After installing, enable the plugin and run the shipped drift detector:

```bash
/plugin marketplace add Munsik-Park/autoflow
/plugin install autoflow@autoflow

# Target-local, network-free self-check (reads .claude/autoflow/manifest.json):
sh .claude/autoflow/drift-check.sh
```

`drift-check.sh` runs five checks, all target-local and network-free:

| Check | What it compares | On mismatch |
|-------|------------------|-------------|
| D1 | every installed artifact vs the installed manifest (content hashes, the shim managed region, the settings-pin keys; a scaffold is presence-only) | FAIL — repair the installed file |
| D2 | installed manifest `version` vs the installed plugin's `plugin.json` | FAIL — re-stamp |
| D3 | settings wiring never binds `.autoflow` state to the plugin root | FAIL — fix the wiring |
| D4 | installed manifest vs the **marketplace clone's** `setup/manifest.json`, per artifact by sha256 — a bundle that is self-consistent (D1 PASS) but older than what the clone would stamp today, including upstream changes merged without a version bump | FAIL — re-stamp (`/autoflow:install`, or `<clone>/setup/init.sh --target <root> --force`); a changed `scaffold` sample or an artifact upstream no longer ships is a `WARN` you dispose of by hand |
| D5 | the installed plugin's files vs the clone's `plugin/<name>/` source — the hooks a session runs and the docs it reads must come from the same source | FAIL — `/plugin update autoflow@autoflow` |

A non-zero exit is a **PREFLIGHT stop condition** — resolve the reported drift
before starting a new AutoFlow cycle. D2, D4 and D5 do **not** need the
hook-only `CLAUDE_PLUGIN_ROOT` variable: `scripts/lib/plugin-root.sh` resolves
the installed plugin and the marketplace clone from the harness's own registries
(`${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/installed_plugins.json`,
`known_marketplaces.json`, then the `cache/` and `marketplaces/` directories), so
the same result is produced from a plain shell, which is where PREFLIGHT runs it.
Each of the three reports `SKIP`, not a failure, when its side is not locally
resolvable (no plugin installed, no clone), naming the locations it consulted.
If the clone itself is behind upstream, refresh it first
(`/plugin marketplace update autoflow`) — D4 compares against the clone you have,
which is also what a re-stamp would deliver.

---

## Prerequisites

- No Agent Teams enablement: the methodology no longer uses Claude Code's
  experimental Agent Teams (the channel is retired — every role is an
  anonymous direct `Agent` spawn), so the settings pin ships no
  `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. A target stamped by a pin older
  than this change still carries `"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }`
  in `.claude/settings.json`: the stamp is a deep-merge and cannot delete a key,
  so remove that entry by hand if you do not want the experimental feature
  enabled. `drift-check.sh` does not flag the leftover (its D1 check is a
  pin-subset test).
- A GitHub repository (or multiple repos for multi-sub-repo setup).
- For a private host repo and/or private submodule: an SSH key (or a
  per-repo deploy key) registered with GitHub and available to every
  automation context (CI agent, webhook container, developer clone).
  Clone with `git clone --recurse-submodules git@github.com:<org>/<repo>.git`.
- Claude Code installed and configured.
- Reviewer backend (HANDOFF step-6 external review): `codex` by default (the
  OpenAI Codex CLI), or `claude` as an opt-in fallback (the Claude CLI +
  subscription/OAuth). The choice lives in the target-owned scaffold
  `.claude/autoflow.local.json` (`{"review":{"backend":"codex"}}`; absent ⇒
  `codex`), delivered by `init.sh` and never overwritten on re-install.
  Install (and any later backend switch) runs an advisory on-demand `--probe`
  auth check (one real round-trip); **PREFLIGHT itself stays presence-only**.
  PREFLIGHT is **fail-closed** on the configured backend: if its CLI is absent,
  `scripts/preflight/check-review-backend.sh` stops the cycle before DIAGNOSE.
  See [`../docs/reviewer-backend.md`](../docs/reviewer-backend.md).
- Basic familiarity with the AutoFlow methodology
  (see [`docs/autoflow-guide.md`](../docs/autoflow-guide.md)).

---

## Troubleshooting

### Hook not running
- Confirm the hook is executable: `chmod +x .claude/hooks/check-autoflow-gate.sh`.
- Confirm `CLAUDE_PROJECT_DIR` is set by Claude Code.

### Evaluation not working
- Confirm `.autoflow/issue-{N}.json` exists and `active` is `true`.
- Confirm the evaluation JSON follows the schema in `docs/evaluation-system.md`.
- Confirm the PASS thresholds in `CLAUDE.md` and `check-autoflow-gate.sh` agree.
