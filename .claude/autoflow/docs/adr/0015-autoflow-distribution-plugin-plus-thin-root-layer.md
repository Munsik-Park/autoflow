# ADR-0015: AutoFlow Distribution — Plugin plus Thin Root Layer; Retire the `subrepo-merged` Status-Check Machinery

## Status

Accepted (owner decision, 2026-07-05)

## Context

Epic #785 inverts the dependency direction between the AutoFlow framework and
the development project it serves. Today the framework repo (`claude-autoflow`)
*contains* the product repo as the `services` submodule, which forces a dual
merge dependency on every cycle (sub-repo PR merges first, then the host
gitlink must record that exact merge SHA). The root cause is not git submodules
but the requirement that the host record the sub-repo's exact version — a
version record that the *target* should own.

The inversion makes the target project the repo root and AutoFlow a versioned
development tool the target consumes. The AutoFlow engine is already
layout-agnostic (`CLAUDE_PROJECT_DIR`-relative — e.g.
`.claude/hooks/check-autoflow-gate.sh:42,99`), and single-repo mode
(zero submodules) is exactly the inverted, containment-free case. What remains
open — and what this ADR decides, gating slices S4a (#790), S4b (#791),
S5 (#792), and S8 (#795) — is:

1. The boundary between the **consumption bundle** (what a target receives)
   and the **root layer** (what must live at the target's project root).
2. The attachment mechanism: **plugin + thin root layer** vs
   **reverse submodule** (target embeds `claude-autoflow` as a submodule).
3. The fate of the `subrepo-merged` status-check publication machinery
   (`.github/workflows/handoff-sequence.yml` dispatch path and its step 7),
   narrowly scoped by #829: the merge-order gate itself was already settled
   as operator label removal (PR #830); only the machinery's keep/retire
   remained for this ADR.

Constraints verified during analysis:

- The Claude Code plugin spec (https://code.claude.com/docs/en/plugins,
  checked 2026-07-05) ships `skills/`, `commands/`, `agents/`,
  `hooks/hooks.json`, `.mcp.json`, `.lsp.json`, `monitors/`, `bin/`, and a
  limited `settings.json`. **`CLAUDE.md` and standalone `docs/` are not plugin
  components** — methodology prose cannot be injected by a plugin.
- Claude Code reads `.claude/` and `CLAUDE.md` only at the project root, so a
  submodule mounted at a subpath (`vendor/claude-autoflow/`) would need a
  copy/link layer into the target root regardless — nullifying the
  "gitlink-pinned, directly usable" advantage of a reverse submodule.
- The PILOT gate (#797) requires the install mechanism to work on an arbitrary
  target type, including a non-deploying library.
- `subrepo-merged` cannot be a GitHub required status check on this plan
  (branch-protection API returns 403 on the private repo); it is an advisory
  signal only. Its dispatch path has been loud-failing (9 of the 10 most
  recent dispatches, `SUBREPO_READ_TOKEN` unregistered, exit 81), and after
  the topology flip (S11a, #798) the multi-repo branch of
  `handoff-sequence.yml` is dead code.

## Decision

### D1 — Consumption bundle vs root layer boundary

Three tiers, refining the KEEP/TEMPLATIZE classification from the pre-epic
host/service decoupling plan §6/§10 (with that plan's
`services/librechat` framing updated to the current `llmroute` submodule):

- **Plugin package** (versioned, marketplace-distributed): `.claude/agents/*`,
  `.claude/hooks/*` (registered via the plugin's `hooks/hooks.json`, scripts
  shipped under `${CLAUDE_PLUGIN_ROOT}`), `.claude/skills/*`. Hook scripts keep
  resolving runtime state via `${CLAUDE_PROJECT_DIR}/.autoflow` — state stays
  in the target, never in the plugin.
- **Thin root layer** (installed into the target root by `init.sh`, S5):
  the `CLAUDE.md` methodology prose (template-stamped, always-on `@import`
  shim), the framework playbooks under `docs/` (autoflow-guide, phases,
  teammate contracts, etc.), `.claude/workflows/*.js` (ARCHITECT/VERIFY
  deliberation — the plugin spec has no workflow slot), the committed settings
  pin (`extraKnownMarketplaces`/`enabledPlugins`), and any `CLAUDE_CODE_*`
  env. Whether the Deliberation-Isolation workflows can migrate into a plugin
  skill is explicitly delegated to S4b (#791) as its acceptance criterion; if
  proven there, a superseding note moves them into the plugin tier.
- **Host-only** (never shipped): the tool repo's own CI workflows, gate/test
  suites, epic scratch, and the installer's development surface. Files the
  decoupling plan classifies MOVE/DELETE (service-coupled runbooks, service
  ADRs) are neither bundle nor root layer. The per-cycle operational digest
  `docs/cycle-digest.jsonl` (issue #953) is likewise Host-only host operational
  data, excluded from the plugin/root-layer distribution surface — structurally
  it never enters `artifacts[]` because the manifest closure walker follows
  `.md` links only, so a `.jsonl` target is never swept in.

### D2 — Attachment mechanism: plugin + thin root layer

AutoFlow is distributed as a Claude Code **plugin** carrying everything the
plugin spec supports, complemented by the **thin root layer** for what it
cannot carry. The version pin is owned by the target as a committed settings
pin (plugin version), satisfying the epic's "the target owns the version
record" requirement. The reverse-submodule alternative is rejected (see
Alternatives). Rule vocabulary downstream (S1, #787) uses plugin-version
terms.

Both candidate mechanisms create the same one-way, opt-in target→tool
dependency — that direction is the epic's goal, not a defect. The differences
are ergonomic, and they favor the plugin (see Alternatives).

### D3 — Retire the `subrepo-merged` status-check machinery

The `handoff-sequence.yml` dispatch path and its status-check publication
(step 7) are **retired**; removal is implemented in S8 (#795), including the
host-only self-dispatch branch. Owner rationale (2026-07-05): in the inverted
model, orchestrator/host commits and PRs and target-repo commits and PRs carry
**no merge dependency** — there is no merge order left to evidence. The
merge-order gate of the containment era was already redefined as operator
label removal (#829/PR #830) and dissolves entirely with the topology flip;
the host-only branch's integrity check ("diff excludes `services/`") loses its
object once the `services` submodule is detached (S11a).

## Alternatives Considered

- **Reverse submodule** (target embeds `claude-autoflow` under e.g.
  `vendor/`): git-native SHA pin, no marketplace infrastructure. Rejected
  because Claude Code only reads `.claude/`/`CLAUDE.md` at the project root,
  so a root copy/link layer is needed anyway (pin advantage nullified); it
  pollutes every target with `.gitmodules` + a submodule directory
  (`--recursive` clones), reproducing the containment coupling this epic
  removes, direction-flipped; and slices S4a/S4b would need redesign.
- **Keep the status-check machinery, host-only reduced**: preserves a machine
  evidence signal pre-merge. Rejected: after S11a the check's verification
  object no longer exists, while the dispatch token and workflow maintenance
  cost persist (current state is loud-fail, exit 81).
- **Parameterize-in-place without inversion**
  (the pre-epic decoupling plan as originally written): keeps the
  containment topology and its dual merge dependency; the epic supersedes it
  with inversion. The plan's file-level KEEP/TEMPLATIZE inventory remains the
  boundary reference for D1.

## Consequences

### Positive

- Distribution rides the official plugin channel with explicit, target-owned
  versioning; tool upgrades are opt-in pins, with no per-PR reconciliation
  between tool and target.
- Works for any target type, including non-deploying libraries (PILOT #797
  precondition).
- S4a/#790 and S4b/#791 proceed as already sliced; S8/#795 simplifies to
  removal of the dispatch/status-check machinery plus path parameterization.

### Negative

- Two delivery channels (plugin + root layer) can version-skew; this is the
  need the S1 (#787) rule set (version pin, CLAUDE.md re-stamp policy,
  manifest) and the S5 (#792) drift self-verify exist to cover.
- A marketplace (or equivalent source) must host the plugin.

### Neutral / Trade-Offs

- Until S11a lands, `claude-autoflow` itself remains a valid multi-repo
  instance and continues to operate under the current label-removal gate;
  retiring the machinery (S8, W3) precedes the flip (W4) per the epic's
  ordering, with the operator label procedure unaffected.
- Whether plugin-delivered hooks resolve `${CLAUDE_PROJECT_DIR}` identically
  to project-level hooks is asserted by the spec's project-root convention but
  is re-verified as part of S4a's acceptance.

## Related Issues / PRs

- Epic: #785 (host↔target inversion) — this ADR is S0 (#786).
- Gated slices: #790 (S4a plugin packaging), #791 (S4b thin root layer),
  #792 (S5 install-into-TARGET), #795 (S8 HANDOFF CI cleanup).
- Rule expression dependency: #787 (S1), allowlist self-reference: #788 (S2).
- Precedent: #829 / PR #830 (merge-order gate = operator label removal;
  machinery fate delegated to this ADR).
- Boundary reference: the pre-epic host/service decoupling plan §6/§10
  (inventory reference only; its containment model is superseded by #785).

## Notes

- Evidence dossiers for this ADR (repo-side and issue-side, with per-fact
  anchors) were compiled in `.autoflow/issue-786-repo-evidence.md` and
  `.autoflow/issue-786-issue-context.md` (gitignored scratch; durable record
  is this ADR plus the issue thread).
