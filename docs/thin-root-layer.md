# Thin Root Layer — Contract

> The durable specification of the **thin root layer**: the AutoFlow residue that
> must live at a consuming target's project root because the AutoFlow **plugin
> package** (S4a / #790) structurally cannot carry it. This document is the single
> source of truth that #792's installer and drift self-verify detector consume.
>
> Governing decision: [`docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md`](adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md) > D1/D2.

---

## 1. Definition & tiering

ADR-0015 D1 distributes AutoFlow across three tiers:

1. **Plugin tier** — everything the Claude Code plugin spec can carry
   (`skills/ commands/ agents/ hooks/hooks.json .mcp.json` …), shipped as the
   `autoflow` plugin (`plugin/autoflow/`, byte-parity with `.claude/{agents,hooks,skills}`; #790).
2. **Thin-root tier** *(this document's scope)* — the residue the plugin channel
   cannot inject, which must land at the target's own project root.
3. **Reference tier** — the methodology prose itself (this repo's `CLAUDE.md` +
   the `docs/` playbook tree routed by `docs/INDEX.md`), imported by the target's
   own `CLAUDE.md` through the shim (Item 1).

This document scopes to the **middle (thin-root) tier**. The installer that copies
these artifacts into an external target, plus the drift detector, is #792 (S5) —
#791 produces only the artifacts' **contents and their contract**.

## 2. Manifest — thin-root-layer contents

The artifact set a target receives at its project root:

| Artifact | Target-root location | Source in this repo | Kind |
|---|---|---|---|
| Methodology prose | target's own `CLAUDE.md` imports it | this repo's `CLAUDE.md` + `docs/` playbooks | reference (installed by #792) |
| Always-on import shim | target `CLAUDE.md` managed block | `setup/thin-root-layer/claude-md-shim.md` | shim (Item 1) |
| Deliberation workflows | `.claude/workflows/*.js` | `.claude/workflows/architect-deliberation.js`, `.claude/workflows/verify-cause-branch.js` | copied file (Item 2) |
| Settings pin | `.claude/settings.json` merge | `setup/thin-root-layer/settings-pin.json` | JSON merge (Item 3 env is §Item 3; pin form §3.3 of the feature design) |
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
  pulls in another file via the `@<relative-path>` import token. The issue/ADR
  call it "`@import`" loosely; the actual Claude Code token is `@<path>`. The
  shim's **first line** is this directive, pinned as a design-time deliverable.
- **Import target path**: `./.claude/autoflow/METHODOLOGY.md` — a stable thin-root
  convention path where #792's installer lands this repo's methodology
  **entrypoint**. Placing the methodology under `.claude/autoflow/` (not the target
  root) keeps the target's own `CLAUDE.md` authorship-owned; the shim is the only
  AutoFlow-managed region in the target's `CLAUDE.md`. The methodology is not one
  file — ADR-0015 D1 lists it as this repo's `CLAUDE.md` prose *plus* the `docs/`
  playbooks routed by `docs/INDEX.md`; the single `@import` targets an entrypoint
  (`METHODOLOGY.md`) that itself re-imports the installed playbook tree. #791
  fixes only the convention path + the one import line; how #792 lays out the tree
  under `.claude/autoflow/` and what `METHODOLOGY.md` re-imports is #792's manifest
  decision (a contract boundary, not a flattening mandate).
- **Always-on**: the block is unconditional (no gating) — the gate hook and phase
  playbooks assume the methodology is always loaded. A plugin cannot inject it
  because it does not own the target's `CLAUDE.md`.
- **Marker contract**: the `AUTOFLOW-IMPORT:BEGIN`/`:END` comment fence makes the
  block idempotently stampable and drift-detectable by #792 without touching the
  target's own prose. Presence of the BEGIN marker ⇒ replace the enclosed region;
  absence ⇒ append the block. #791 defines the marker; #792 consumes it.

### Spec citation (dated) — Claude Code memory-import mechanism

The `@<path>` token's correctness against the live Claude Code spec is an
environment-dependent (E-type) criterion; per the #790 loader-spec-citation
precedent it is recorded here as a dated citation rather than a self-contained
automated assertion:

- **Source**: Claude Code memory documentation, `https://code.claude.com/docs/en/memory`
  — fetched **2026-07-06**.
- **Confirms**: a `CLAUDE.md` file imports additional files using the
  `@path/to/import` syntax; both relative and absolute paths are allowed;
  relative paths resolve against the importing file's directory; recursive imports
  are permitted up to a **maximum depth of four hops**. This substantiates the shim's
  first-line token `@./.claude/autoflow/METHODOLOGY.md` (a relative-path import
  resolving from the target root's `CLAUDE.md`) and the single-hop entrypoint →
  re-import design in Item 1.
- **Live end-to-end resolution** (the `@<path>` resolving in a stamped target)
  remains a manual scenario deferred to #792 (needs a stamped target root + the
  installed `METHODOLOGY.md` import target, which #791 does not ship).

---

## Item 2 — `.claude/workflows` residence (skill-substitutability AC)

**Question** (ADR-0015 D1 delegated to S4b): can a Claude Code **plugin skill**
replace the isolated-`Workflow` facilitator that CLAUDE.md > Deliberation Isolation
assigns to `.claude/workflows/architect-deliberation.js` /
`.claude/workflows/verify-cause-branch.js`? If yes, the residence question
dissolves (the skill runs from the plugin's own `skills/` dir); if no, the
workflows are irreducible thin-root residents.

**Verdict (grep-checkable):**

```
SKILL-SUBSTITUTION = REJECTED
WORKFLOW = REQUIRED
```

**Grounds (concrete deciding constraint, all repo-anchored):**

- The isolation property required is that **intermediate deliberation results stay
  out of the caller's (orchestrator's) context**. `docs/design-rationale.md:158,160`
  states the `Workflow` runtime is "the one runtime mechanism documented to keep
  intermediate results out of the caller's context," binding the contract to it
  "rather than to an abstract 'sub-context'." `.claude/workflows/architect-deliberation.js:3-5`
  encodes the same: the Developer-AI/Test-AI sub-agents converge inside the
  workflow and their round-by-round exchange never enters the orchestrator's
  context.
- A **skill** is injected instruction content that executes **in the invoking
  agent's own context** — it provides no separate sub-context that shields the
  caller from the round-by-round messages, so it fails the exact
  context-non-contamination property (`docs/design-rationale.md:166`) that
  motivates Decision 8. A skill could hold the *protocol prose* but not the
  *isolation boundary*.
- Independently, the plugin spec has **no plugin `workflows/` component slot**
  (ADR-0015 Context, checked against the Claude Code plugin spec: it ships
  `skills/ commands/ agents/ hooks/hooks.json .mcp.json .lsp.json monitors/ bin/`
  and a limited `settings.json` — no `workflows/`). Even setting isolation aside,
  the `.js` scripts cannot ride the plugin channel.

**Consequence**: `.claude/workflows/architect-deliberation.js` and
`.claude/workflows/verify-cause-branch.js` are thin-root-layer artifacts (ADR-0015
D1's default branch holds; no superseding note moves them into the plugin tier).
The isolated-`Workflow` boundary is the **one documented isolation mechanism**, so
the workflow-residence verdict rests on it directly. Because the workflows are
required, `CLAUDE_CODE_DISABLE_WORKFLOWS` becomes a load-bearing env constraint
(Item 3).

---

## Item 3 — `CLAUDE_CODE_*` env contract

The thin-root layer's env dependencies. The enumeration is **complete** with
respect to the thin-root census boundary (`.claude/workflows/`, `.claude/hooks/`,
`setup/thin-root-layer/`, this doc) — `plugin/**` refs are #790-owned and covered
by that suite's own census.

| Variable | Provisioned by | Thin-root contract |
|---|---|---|
| `CLAUDE_PROJECT_DIR` | Claude Code **harness** (project root) | consumed by hooks (`.claude/hooks/check-autoflow-gate.sh:42,99`) & workflows; the target must run Claude Code from the project root — the **harness** sets it, it is not a user var. |
| `CLAUDE_PLUGIN_ROOT` | plugin **loader** (substituted in the plugin channel) | consumed only by the plugin channel (`hooks.json`, epic-dash `SKILL.md`); it never resolves `.autoflow`. **Loader**-provisioned, not host-required. |
| `CLAUDE_CODE_DISABLE_WORKFLOWS` | operator / managed settings | **MUST remain unset / not be `1`** — the ARCHITECT/VERIFY workflows are REQUIRED (Item 2). Setting it to `1` disables the deliberation isolation boundary. This is the load-bearing env line of the thin root layer. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | thin-root **settings pin** (stamped into `.claude/settings.json`) | Enables Agent Teams (experimental, default-off upstream). REQUIRED for the Communication — Agent Teams layer; the pin sets it to `"1"`. Token-cost implication (experimental multi-teammate coordination). |

**Runtime prerequisite**: Claude Code **v2.1.154+** — the `Workflow` runtime the
deliberation scripts depend on (`.claude/workflows/architect-deliberation.js:6`).

---

## AC checklist — the checkable deliverable

| # | AC | Status | Artifact / anchor |
|---|----|--------|-------------------|
| 1 | Always-on import shim defined & artifact present | PASS | `setup/thin-root-layer/claude-md-shim.md` (marker fence + pinned `@./.claude/autoflow/METHODOLOGY.md`) |
| 2 | Workflow-residence resolved | PASS | `SKILL-SUBSTITUTION = REJECTED` / `WORKFLOW = REQUIRED` (Item 2) |
| 3 | `CLAUDE_CODE_*` env contract enumerated | PASS | four-var table (Item 3), `CLAUDE_CODE_DISABLE_WORKFLOWS` MUST-not-be-`1`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` pin-provisioned |
| — | Settings pin present & README-parity | PASS | `setup/thin-root-layer/settings-pin.json` (jq-canonically equal to `plugin/autoflow/README.md` fence) |

E-type items (not self-contained here; dated citations / deferred to #792): the
`@<path>` live memory-import resolution (Item 1 spec citation, dated 2026-07-06)
and the live `Workflow({name})` invocation from a stamped target.
