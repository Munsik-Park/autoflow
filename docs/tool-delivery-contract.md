# Tool Delivery Contract

> The four delivery-contract rules for AutoFlow as a consumed, versioned tool
> (epic #785, slice S1 / issue #787). Governing decision:
> [ADR-0015](adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md)
> (plugin + thin root layer). Per ADR-0015 D2, rule vocabulary uses
> **plugin-version** terms; the reverse-submodule (gitlink-SHA) form was
> rejected there and appears below only as rejected vocabulary.

---

## Scope and Status

This document is the **policy source of truth** for how the AutoFlow tool is
delivered to a target project and kept consistent with it. It is
code-change-free: the enforcing mechanisms land in later slices and must
conform to these rules.

| Rule | Enforced by (slice) |
|------|---------------------|
| R1 — Tool version pin | S4a #790 (plugin packaging, settings pin) |
| R2 — CLAUDE.md delivery + version-skew re-stamp | S4b #791 (root layer), S5 #792 (installer) |
| R3 — Target-identity separation (`CLAUDE.local.md`) | S4b #791, S5 #792 |
| R4 — Install artifact manifest + drift test | S5 #792 |

Terminology (ADR-0015 D1): the **plugin package** is the
marketplace-distributed, versioned component (`agents/`, `hooks/`, `skills/`);
the **thin root layer** is what the installer stamps into the target's project
root (`CLAUDE.md` methodology prose, framework playbooks under `docs/`,
`.claude/workflows/*.js`, the committed settings pin). "Delivered surface"
below means both tiers together.

---

## R1 — Tool Version Pin (target-owned)

- **[MUST]** The target owns the AutoFlow version record: a **committed
  settings pin** in the target repository (`extraKnownMarketplaces` /
  `enabledPlugins` naming an explicit plugin version). Consuming an
  unpinned ("latest") plugin is not a supported configuration.
- **[MUST]** The tool never records the target's version. There is no
  host-side gitlink, pointer file, or per-PR reconciliation between tool and
  target — the dependency is one-way, target → tool.
- A tool upgrade is an explicit edit to the pin in the target's history. The
  pin edit and the matching root-layer re-stamp (R2) belong to the same
  change, so the target's history always identifies which tool version
  governed which commits.
- Rejected vocabulary: a gitlink-SHA pin (reverse submodule) is not a valid
  form of this rule — ADR-0015 rejects the mechanism it would ride on.

## R2 — CLAUDE.md Delivery and Version-Skew Re-Stamp

- The `CLAUDE.md` methodology prose is **tool-versioned content**, not
  target-authored content. It is delivered as part of the thin root layer by
  the installer's template stamp and is replaceable in full by a re-stamp.
- **[MUST]** The stamped root layer records the tool version that produced it
  (a stamp marker written at install/upgrade time).
- **[MUST]** **Version skew** — the pinned plugin version (R1) differing from
  the stamped root-layer version — is resolved by **re-stamping the root
  layer** before starting a new AutoFlow cycle. The two delivery channels
  (plugin, root layer) are the skew surface ADR-0015 names; skew detection is
  part of the drift self-verify shipped under R4.
- **[DENY]** Hand-editing the delivered prose in place to diverge from the
  pinned tool version. A framework change goes upstream to the tool
  repository (and arrives via a pin upgrade); target-local behavior goes to
  the target-identity overlay (R3). This is what keeps a re-stamp
  loss-free.

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
- Consequence: combined with R2's [DENY], a re-stamp is destructive-safe by
  construction — the delivered `CLAUDE.md` contains no target-authored
  content, so replacing it wholesale loses nothing.

## R4 — Install Artifact Manifest (exhaustive) + Drift Test

- **[MUST]** Every install and upgrade is described by an **exhaustive
  artifact manifest**: every file the installer delivers, with its tier
  (plugin / root layer) and the source tool version. No delivered artifact
  may land outside the manifest — manifest coverage is total, and the
  manifest is the authoritative file list for upgrade re-stamp and removal.
- **[MUST]** The manifest ships together with a **schema-hook-contract drift
  test** the target can run to self-verify bundle consistency: installed
  artifacts match the manifest, the root-layer stamp version matches the
  settings pin (R2 skew check), and the plugin-delivered hook contracts match
  the root-layer schema/state expectations (state stays in
  `${CLAUDE_PROJECT_DIR}/.autoflow`, per ADR-0015 D1). The detector is
  delivered with the hooks (implementation: S5 #792).
- A drift-test failure is a **stop condition** for starting a new AutoFlow
  cycle on the target, in the same class as PREFLIGHT's Git-clean hard stop:
  resolve the drift (re-stamp, pin fix, or reinstall) first.

---

## Related

- Epic: #785 (host↔target inversion); this rule set is slice S1 (#787).
- Governing ADR: [ADR-0015](adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md)
  — D1 (tier boundary), D2 (plugin + thin root layer, plugin-version
  vocabulary), Consequences > Negative (two-channel skew is the need this
  rule set covers).
- Implementing slices: #790 (S4a), #791 (S4b), #792 (S5).
- Local overlay example: `CLAUDE.local.md.example` (R3 scaffold source).
