# ADR-0015: AutoFlow Distribution — Plugin plus Thin Root Layer; Retire the `subrepo-merged` Status-Check Machinery

## Status

Accepted (owner decision, 2026-07-05)

Amended 2026-08-24 (operator decision, Munsik-Park/autoflow#53): the D1
delegation to S4b is closed — the Deliberation-Isolation workflows stay in the
thin root layer. See *D1 > Superseding note*.

Amended 2026-09-13 (Munsik-Park/autoflow#245): D1's thin-root enumeration of the
committed settings pin drops `enabledPlugins` — the pin declares the marketplace
only, and plugin enablement is a one-time user-scope step. See *D1 > Superseding
note (2026-09-13)*.

Amended 2026-09-16 (Munsik-Park/autoflow#253): D1's thin-root enumeration of
"the framework playbooks under `docs/`" is narrowed to the **usage documents**;
the design and decision **records** move to `docs/records/` and are not shipped,
and the placement rule for a stamped target's tree (`.claude/autoflow/`,
`.autoflow/`, `docs/autoflow/`, the rest of `docs/`) is fixed. See *D1 >
Superseding note (2026-09-16)*.

Issue numbers `#600`–`#999` cited in this ADR belong to the predecessor
tracker `connev-llm/claude-autoflow` (archived, private) and are retained as
historical provenance only; they do not resolve in `Munsik-Park/autoflow`. See
`docs/INDEX.md` > Issue-number provenance.

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
  pin (`extraKnownMarketplaces`), and any `CLAUDE_CODE_*`
  env. Whether the Deliberation-Isolation workflows can migrate into a plugin
  skill is explicitly delegated to S4b (#791) as its acceptance criterion; if
  proven there, a superseding note moves them into the plugin tier.

  **Superseding note (2026-08-24, operator decision, Munsik-Park/autoflow#53).**
  The S4b delegation is closed as **not migrated**: the workflows remain in
  the thin root layer, and no successor issue is opened for the migration. The
  predecessor-tracker slice `#791` is unreachable from this repository, so the
  question it was to answer is settled here instead. Grounds: the project's
  direction is to implement AutoFlow without depending on Claude Code-only
  features (independence from the harness's roadmap; portability across
  platforms), and moving the workflows into the plugin tier would bind them
  more tightly to Claude Code packaging — the opposite direction. The
  successor to the workflow scripts is a harness-neutral agent-invocation
  module, which is separate work outside this ADR; the plugin tier is not the
  destination. Feasibility was not the blocker — the skills
  `architect-deliberation` / `verify-cause-branch` already wrap the workflow
  scripts — the decision is one of direction.

  **Superseding note (2026-09-13, Munsik-Park/autoflow#245).** The enumeration
  above previously read `extraKnownMarketplaces`/`enabledPlugins`. The tier
  assignment is unchanged — the committed settings pin is a thin-root artifact,
  and the target owns a committed version record — but the pin's content is
  narrowed to `extraKnownMarketplaces`, and that key is the target's record of
  *which marketplace* its AutoFlow comes from, not a version pin. Ground: a
  repo-level `enabledPlugins["autoflow@autoflow"]: true` declaration makes
  Claude Code create and freeze a project-scope installation record, which
  nothing refreshes, so every stamped repository minted its own frozen version
  pin at the next session start; a `false` declaration mints none — it is the
  record-free per-repo opt-out — `extraKnownMarketplaces` alone never does, and
  the user-scope `enabledPlugins` is what actually enables the plugin.
  The target's version record is the installed manifest
  `.claude/autoflow/manifest.json` (`.version`), compared against the installed
  plugin's `plugin.json` by the drift detector (D2). See
  `docs/tool-delivery-contract.md` > R1 > *Superseding note (2026-09-13…)*.

  **Superseding note (2026-09-16, Munsik-Park/autoflow#253).** The `docs/` tree
  of this repository holds two document classes, and only one of them is
  thin-root content:

  - **Usage documents** — what an agent reads and follows while a cycle runs:
    `CLAUDE.md` and the playbooks, rules, contracts and checklists under `docs/`
    that `docs/INDEX.md` routes. They are the source of the rules and ship as
    the reference tier, landing at `.claude/autoflow/docs/**`.
  - **Record documents** — dated design and decision records, read for a
    decision's history and grounds but the source of no rule: the ADRs
    (`docs/records/adr/`), the design reviews (`docs/records/design-reviews/`)
    and `docs/records/design-rationale.md`. They live under `docs/records/` and
    are **never shipped**: the manifest generator's markdown-link closure
    neither emits nor traverses a link that resolves under that prefix
    (`setup/gen-manifest-hashes.sh` > `RECORD_TIER_PREFIX`). A usage document
    may still cite a record for its grounds; the citation resolves in this
    repository, not in a target. `docs/INDEX.md` routes the two classes in
    separate tables — the usage rows name no record, and one row points at the
    records for "why / when was this decided".

  Grounds. (1) Issue #196: two documents describing the same decision as of
  different moments split an agent's judgment by which one it happened to read;
  a decision's history belongs in the record tier and its current form in the
  usage tier, so the location says which is which. (2) The stamped copies of
  the 15 record files (13 under `docs/adr/`, one design review,
  `design-rationale.md`) were bytes a target's agent had no reason to read, and
  two of them (ADR-0015, `adr/README.md`) carried host-purity hits that the
  ratchet baseline `tests/fixtures/e2e-bundle-purity-baseline.txt` had to
  allow; dropping them from the bundle ratchets that baseline down.

  Location alternative rejected: moving the usage documents to
  `docs/autoflow/` in this repository (the issue's other candidate). The
  stamped dest already namespaces them under `.claude/autoflow/docs/`, the
  separation the issue asks for is obtained by the records subtree alone, and
  the move would rewrite every inbound reference to the usage tree
  (`docs/autoflow-guide.md` alone is named in 68 files) for no change in what a
  target receives. `docs/autoflow/` is reserved for the target side, below.

  **Target placement.** A stamped target's tree follows this rule; the
  installer and the drift detector enforce the first two rows, the last two
  are the convention a target is told to keep:

  | Path in the target | Owner | Content |
  |---|---|---|
  | `.claude/autoflow/` | AutoFlow — stamped, read-only for the target, reconciled on re-stamp (`docs/tool-delivery-contract.md` R4) | the installed manifest, `METHODOLOGY.md`, `CLAUDE.md`, the `docs/**` usage documents, `drift-check.sh`, the settings-pin copy. The read-only stamped documents **stay here** rather than moving under `docs/autoflow/`: the shim imports `./.claude/autoflow/METHODOLOGY.md` (`docs/thin-root-layer.md` Item 1), every installer, drift and purity check keys on this path, and a directory the target edits must not share a tree with bytes a re-stamp overwrites — which is the mixing this amendment removes. |
  | `.autoflow/` | AutoFlow scratch (gitignored) | per-issue state, ledger and analysis artifacts, and the cycle-layer store `.autoflow/issue-{N}-local/`; archived off-tree at cleanup (ADR-0024 D2). |
  | `docs/autoflow/` | target — committed, target-authored; AutoFlow reads it | files AutoFlow uses that the target writes and maintains (its test conventions, the runbooks behind `preflight.local_checks[]`, and the like). AutoFlow never stamps or overwrites a file here. No shipped script reads a fixed file at this path today; the row fixes where such a file goes when one is introduced, so it lands neither in `.claude/autoflow/` (overwritten by a re-stamp) nor loose in the target's own `docs/`. |
  | `docs/` (the rest) | target | the target's own documentation, its own ADRs included; outside AutoFlow's surface. |

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
cannot carry. The version record is owned by the target as the committed
installed manifest (`.claude/autoflow/manifest.json` `.version`), beside a
committed settings pin that declares which marketplace the plugin comes from
(`extraKnownMarketplaces`; amended by #245 — the pin itself carries no version),
satisfying the epic's "the target owns the version record" requirement. The reverse-submodule alternative is rejected (see
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
