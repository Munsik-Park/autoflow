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
| R1 — Tool version pin | plugin packaging, settings pin |
| R2 — CLAUDE.md delivery + version-skew re-stamp | root layer, installer |
| R3 — Target-identity separation (`CLAUDE.local.md`) | root layer, installer |
| R4 — Install artifact manifest + drift test | installer |

Terminology: the **plugin package** is the
marketplace-distributed, versioned component (`agents/`, `hooks/`, `skills/`);
the **thin root layer** is what the installer stamps into the target's project
root (`CLAUDE.md` methodology prose, framework playbooks under `docs/`,
`.claude/workflows/*.js`, the committed settings pin). "Delivered surface"
below means both tiers together.

---

## R1 — Tool Version Pin (target-owned)

- **[MUST]** The target owns the AutoFlow version record: a **committed version
  record** in the target repository — the installed manifest
  `.claude/autoflow/manifest.json` (`.version`), a `copy`-kind thin-root
  artifact, which the drift detector compares against the installed plugin's
  `plugin.json` (D2). The committed **settings pin** (`extraKnownMarketplaces`)
  is committed beside it and declares *which marketplace* the target's AutoFlow
  comes from. Consuming an unpinned ("latest") plugin is not a supported
  configuration.

  **What the pin does and does not carry.** No pinned key names a version — the
  marketplace entry is `{"source":"github","repo":"Munsik-Park/autoflow"}` — and
  the pin carries no enablement key: the stamp does not write a repo-level
  `enabledPlugins["autoflow@autoflow"]` declaration, and enabling the plugin is
  a one-time **user-scope** step. The version record is the artifact named
  above. Read the "explicit edit to the pin" below as an edit to that version
  record: a re-stamp refreshes `.claude/autoflow/manifest.json`, which is the
  commit the target's history carries.
- **[MUST]** The tool never records the target's version. There is no
  host-side gitlink, pointer file, or per-PR reconciliation between tool and
  target — the dependency is one-way, target → tool.
- A tool upgrade is an explicit edit to the pin in the target's history. The
  pin edit and the matching root-layer re-stamp (R2) belong to the same
  change.
- A gitlink-SHA pin (reverse submodule) is not a valid form of this rule.

## R2 — CLAUDE.md Delivery and Version-Skew Re-Stamp

- The `CLAUDE.md` methodology prose is **tool-versioned content**, not
  target-authored content. It is delivered as part of the thin root layer by
  the installer's template stamp and is replaceable in full by a re-stamp.
- **[MUST]** The stamped root layer records the tool version that produced it
  (a stamp marker written at install/upgrade time).
- **[MUST]** **Version skew** — the pinned plugin version (R1) differing from
  the stamped root-layer version — is resolved by **re-stamping the root
  layer** before starting a new AutoFlow cycle. The two delivery channels
  (plugin, root layer) are the skew surface; skew detection is
  part of the drift self-verify shipped under R4.
- **[DENY]** Hand-editing the delivered prose in place to diverge from the
  pinned tool version. A framework change goes upstream to the tool
  repository (and arrives via a pin upgrade); target-local behavior goes to
  the target-identity overlay (R3).

## R3 — Target-Identity Separation via `CLAUDE.local.md` [MUST]

- **[MUST]** Target identity — organization and repository names, default
  branch, stack and deployment specifics, service names, and any
  target-local operating rules — never lives in the delivered `CLAUDE.md`.
  It lives in **`CLAUDE.local.md`** (Claude Code's native project-root
  overlay, loaded alongside `CLAUDE.md`), or in target-owned documents that
  `CLAUDE.local.md` references.
- **[MUST]** The tool never ships, stamps, or overwrites `CLAUDE.local.md`.
  It is outside the delivered surface and outside the manifest (R4); the
  installer may scaffold it from `CLAUDE.local.md.example` only when it does
  not exist.
- Whether the target commits `CLAUDE.local.md` or keeps it ignored is the
  target's own policy; this contract fixes only the boundary — identity
  content sits outside the tool-delivered surface.

## R4 — Install Artifact Manifest (exhaustive) + Drift Test

- **[MUST]** Every install and upgrade is described by an **exhaustive
  artifact manifest**: every file the installer delivers, with its tier
  (plugin / root layer) and the source tool version. No delivered artifact
  may land outside the manifest — manifest coverage is total, and the
  manifest is the authoritative file list for upgrade re-stamp and removal.
- **[MUST]** A re-stamp **reconciles** the target against the manifest it
  previously installed (`.claude/autoflow/manifest.json`, read before the
  stamp overwrites it): an artifact the previous manifest lists
  and the new manifest does not is removed only when AutoFlow still owns it —
  kind `copy`, on-disk sha256 equal to the previous manifest's recorded value.
  A `copy` whose hash differs (target-modified) and every `scaffold` /
  `shim-stamp` / `json-merge` artifact are kept and reported with the reason;
  a target with no previous installed manifest, or one that cannot be read,
  has nothing removed. The installer prints one `REMOVED:` / `KEPT:` /
  `ABSENT:` line per dest and `/autoflow:install` reports them; the commit
  stays the operator's. Whether target code still references a removed file
  is the install skill's read-only probe, not the installer's decision: a
  reference it surfaces is to a tool file the new manifest does not ship, and
  the judgment on it belongs with the operator who commits.
- **[MUST]** The manifest ships together with a **schema-hook-contract drift
  test** the target can run to self-verify bundle consistency: installed
  artifacts match the manifest, the root-layer stamp version matches the
  settings pin (R2 skew check), and the plugin-delivered hook contracts match
  the root-layer schema/state expectations (state stays in
  `${CLAUDE_PROJECT_DIR}/.autoflow`). The detector is delivered with the
  hooks.
- **[MUST]** The drift test also compares the installed bundle with **upstream
  as locally available**: the installed manifest against the marketplace
  clone's `setup/manifest.json` per artifact by sha256 (drift-check D4), and
  the installed plugin's files against the clone's plugin source (D5). A
  self-consistent bundle that is older than what the clone would stamp is a
  reported drift, not a silent pass. Both legs, and the R2 skew check (D2),
  resolve the plugin and the clone from the harness's local registries
  (`scripts/lib/plugin-root.sh`, shipped with the bundle) rather than from the
  hook-only `CLAUDE_PLUGIN_ROOT`; each reports `SKIP`, never a failure, when
  its side is not locally resolvable. No network access. The
  same test also checks the one artifact a re-stamp never refreshes against
  the tool it must agree with (D6): the target-owned
  `.claude/autoflow/spawn-policy.json` scaffold is run through
  `scripts/spawn-policy/spawn-policy.sh check` against the agent definitions
  the session loads (phase-row effort equals the definition's `effort:`
  frontmatter; every `agent_type` is shipped), and its row set is compared
  with the clone's sample; the comparison names a row the current version
  requires, or an `agent_type` it renamed.
  A finding is a FAIL with the rows to fix listed; the remedy is a hand edit
  of the scaffold, never a re-stamp. It likewise checks the one precondition
  of the shipped suite selector that lives in target-owned files (D7),
  **on a target that opted into AutoFlow's suite plane** (the opt-in is
  `.claude/autoflow.local.json` > `tests` > `suite_plane: true`, resolved
  through the shipped `scripts/test/suite-manifest.sh` — the plane's one
  resolver, run from the detector's own tree): every
  executable spec under the target's `tests/**` declares a usable
  `# ci-subject:` header, or `scripts/test/select-suites.sh` BLOCKs every
  selection. The check is the selector's own `--check-headers` stage run from
  the detector's tree, each header-less suite is a FAIL, and the remedy is
  back-filling the header — a re-stamp never touches `tests/**`. A target
  that has not opted in owes no header and PASSes without the selector being
  consulted; a declaration file that is present but unreadable is a FAIL;
  and a scaffold that has no `tests` object is named by a `HINT` beside the
  PASS, pointing at the clone's
  `.claude/autoflow.local.json.example`. The
  `/autoflow:install` skill resolves the clone it detects against and stamps
  from through the same resolver — a byte-identical copy shipped inside the
  plugin — with the plugin root's `../..` as the last candidate (a directly
  loaded clone), never as the derivation.
- A drift-test failure is a **stop condition** for starting a new AutoFlow
  cycle on the target, in the same class as PREFLIGHT's Git-clean hard stop:
  resolve the drift (re-stamp, pin fix, plugin update, or reinstall) first.

---

## Related

- Local overlay example: `CLAUDE.local.md.example` (R3 scaffold source).
