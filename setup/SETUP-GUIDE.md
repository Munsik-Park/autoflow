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
| Settings pin (marketplace + `enabledPlugins` + `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) | `.claude/settings.json` | json-merge |
| Drift detector + drift references | `.claude/autoflow/drift-check.sh` | copy |
| Local overrides scaffold (never overwritten) | `CLAUDE.local.md` | scaffold |

The shim stamp is idempotent and only touches the `AUTOFLOW-IMPORT:BEGIN/END`
managed block — your own `CLAUDE.md` prose is preserved. The settings merge is a
deep-merge: your pre-existing `.claude/settings.json` keys are kept, and the
AutoFlow marketplace/`enabledPlugins` pin is added. The pin also stamps
`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`, enabling Claude Code's
experimental Agent Teams (default-off upstream) that the Communication — Agent
Teams layer requires. `CLAUDE.local.md` holds your target identity (R3) and is
never overwritten, even with `--force`.

### Self-verify with the drift detector

After installing, enable the plugin and run the shipped drift detector:

```bash
/plugin marketplace add Munsik-Park/autoflow
/plugin install autoflow@autoflow

# Target-local, network-free self-check (reads .claude/autoflow/manifest.json):
sh .claude/autoflow/drift-check.sh
```

`drift-check.sh` checks that every installed artifact still matches the manifest
(content hashes, the shim managed region, and the settings-pin keys) and that the
installed manifest `version` matches the plugin pin. A non-zero exit is a
**PREFLIGHT stop condition** — resolve the reported drift before starting a new
AutoFlow cycle. (Version-skew reports `SKIP`, not a failure, when the plugin root
is not locally resolvable.)

---

## Prerequisites

- Agent Teams enablement: the methodology's Communication — Agent Teams layer
  requires Claude Code's experimental Agent Teams
  (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, default-off upstream). The settings
  pin ships it set to `"1"`, so a stamped target needs no manual env setup.
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
