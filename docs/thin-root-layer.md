# Thin Root Layer — Contract

> The durable specification of the **thin root layer**: the AutoFlow residue that
> must live at a consuming target's project root. This document is the single
> source of truth that the installer and drift self-verify detector consume.

---

## 1. Definition & tiering

AutoFlow is distributed across three tiers:

1. **Plugin tier** — everything the Claude Code plugin spec can carry
   (`skills/ commands/ agents/ hooks/hooks.json .mcp.json` …), shipped as the
   `autoflow` plugin (`plugin/autoflow/`, byte-parity with `.claude/{agents,hooks,skills}`).
2. **Thin-root tier** *(this document's scope)* — the residue the plugin channel
   cannot inject, which must land at the target's own project root.
3. **Reference tier** — the methodology prose itself (this repo's `CLAUDE.md` +
   the `docs/` usage-document tree routed by `docs/INDEX.md`), imported by the
   target's own `CLAUDE.md` through the shim (Item 1). The record tier under
   `docs/records/` (ADRs, design reviews, `design-rationale.md`) is not part
   of it: the manifest generator's link closure stops at that prefix, so a
   target never receives a record. The placement rule for a stamped target's
   `.claude/autoflow/`, `.autoflow/`, `docs/autoflow/` and remaining `docs/` is
   in ADR-0015 D1 > Superseding note 2026-09-16.

This document scopes to the **middle (thin-root) tier**: the artifacts'
**contents and their contract**, which the installer copies into an external
target and the drift detector checks.

## 2. Manifest — thin-root-layer contents

The artifact set a target receives at its project root:

| Artifact | Target-root location | Source in this repo | Kind |
|---|---|---|---|
| Methodology prose | target's own `CLAUDE.md` imports it | this repo's `CLAUDE.md` + the `docs/` usage documents (the link closure of `CLAUDE.md` + `docs/INDEX.md`, minus `docs/records/`) | reference |
| Always-on import shim | target `CLAUDE.md` managed block | `setup/thin-root-layer/claude-md-shim.md` | shim (Item 1) |
| Deliberation workflows | `.claude/workflows/*.js` | `.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js` | copied file (Item 2) |
| Settings pin | `.claude/settings.json` merge | `setup/thin-root-layer/settings-pin.json` | JSON merge (Item 3 env is §Item 3; jq-canonically equal to the `plugin/autoflow/README.md` fence) |
| Env contract | operator env / harness | this doc, Item 3 | documented requirement |

---

## Item 1 — the always-on `@import` shim

The minimal always-on block a target adds to its **own** root `CLAUDE.md` to pull
in AutoFlow's methodology. Artifact: `setup/thin-root-layer/claude-md-shim.md`.

```markdown
<!-- AUTOFLOW-IMPORT:BEGIN (managed by claude-autoflow — do not edit inside) -->
@./.claude/autoflow/METHODOLOGY.md
<!-- AUTOFLOW-IMPORT:END -->
```

- **Directive**: Claude Code's memory-import mechanism — a root `CLAUDE.md`
  pulls in another file via the `@<relative-path>` import token; a relative path
  resolves against the importing file's directory, and recursive imports reach
  at most four hops. "`@import`" in this document names that `@<path>` token. The
  shim's **first line** is this directive.
- **Import target path**: `./.claude/autoflow/METHODOLOGY.md` — a stable thin-root
  convention path where the installer lands this repo's methodology
  **entrypoint**. The methodology lives under `.claude/autoflow/` (not the target
  root); the shim is the only AutoFlow-managed region in the target's `CLAUDE.md`.
  The methodology is not one file — it is this repo's `CLAUDE.md` prose *plus* the
  `docs/` playbooks routed by `docs/INDEX.md`; the single `@import` targets an
  entrypoint (`METHODOLOGY.md`) that itself re-imports the installed playbook tree.
  This contract fixes only the convention path + the one import line; the tree
  layout under `.claude/autoflow/` and what `METHODOLOGY.md` re-imports are the
  installer manifest's decision.
- **Always-on**: the block is unconditional (no gating).
- **Marker contract**: the stamp and the drift detector act only on the block
  inside the `AUTOFLOW-IMPORT:BEGIN`/`:END` comment fence and never touch the
  target's own prose. Presence of the BEGIN marker ⇒ replace the enclosed region;
  absence ⇒ append the block.

---

## Item 2 — `.claude/workflows` residence

`.claude/workflows/architect-deliberation.js` and
`.claude/workflows/verify-cause-branch.js` are thin-root-layer artifacts.
The ARCHITECT discussion itself is an orchestrator relay of two persistent
participants over `.autoflow/issue-{N}-architect-transcript.md`, and
`architect-deliberation.js` is its Record phase; the workflow is REQUIRED for
that phase, `scripts/architect/relay-state.sh` ships beside it as a root-layer
copy — as does `scripts/architect/composition-oracle.sh`, the classifier the Record
phase runs over the verification design it writes — and the participants' prompt
rides the plugin channel in `agents/autoflow-planner.md`.
`CLAUDE_CODE_DISABLE_WORKFLOWS` is a load-bearing env constraint (Item 3).

---

## Item 3 — `CLAUDE_CODE_*` env contract

The thin-root layer's env dependencies.

| Variable | Provisioned by | Thin-root contract |
|---|---|---|
| `CLAUDE_PROJECT_DIR` | Claude Code **harness** (project root) | consumed by hooks & workflows; the target must run Claude Code from the project root — the **harness** sets it, it is not a user var. |
| `CLAUDE_PLUGIN_ROOT` | plugin **loader** (substituted in the plugin channel) | consumed only by the plugin channel (`hooks.json`, install `SKILL.md`); it never resolves `.autoflow`. **Loader**-provisioned, not host-required. |
| `CLAUDE_CONFIG_DIR` | Claude Code **harness** (its config-directory override; default `~/.claude`) | read, never required, by the shipped `scripts/lib/plugin-root.sh`: `drift-check.sh` D2/D4/D5/D6, `spawn-policy.sh check` and `/autoflow:install` Step 0 (the skill runs its own byte-identical copy of the resolver, shipped inside the plugin) locate the installed plugin and the marketplace clone through the harness's own registries under `${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/` when `CLAUDE_PLUGIN_ROOT` is unset (every plain-shell run — PREFLIGHT, the operator). Unset means the default; a value the harness would not itself use only makes those checks `SKIP` (or `check` fail closed naming the location), never mis-resolve. |
| `CLAUDE_CODE_DISABLE_WORKFLOWS` | operator / managed settings | **MUST remain unset / not be `1`**. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | **nobody** — not provisioned | The settings pin does not ship it and the thin root layer neither requires nor reads it. A `"1"` value in a target's settings is outside the contract (`setup/SETUP-GUIDE.md` > Prerequisites). |

**Runtime prerequisite**: Claude Code **v2.1.154+** — the `Workflow` runtime the
deliberation scripts depend on.
