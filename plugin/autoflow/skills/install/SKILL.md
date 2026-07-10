---
name: install
description: >-
  Detect and report AutoFlow root-layer absence or drift in the current
  project, then — only after explicit user confirmation — stamp the thin-root bundle
  from the marketplace cache via init.sh and run drift-check. Detection and reporting
  are automatic and read-only; every write is opt-in. Triggers: "autoflow install",
  "stamp autoflow", "install autoflow into this repo", "/autoflow:install".
---

# install

`/autoflow:install` stamps (or re-stamps) the AutoFlow thin-root layer into the
current project from the marketplace cache — turning onboarding into three
commands (`/plugin marketplace add` → `/plugin install autoflow@autoflow`
→ `/autoflow:install`). It carries **no install logic of its own**: it detects,
reports, gates on a single confirmation, then delegates the write to the existing
`setup/init.sh --target` installer and re-runs the shipped `drift-check.sh`.

**Opt-in boundary (AC4).** Steps 0–2 are read-only (git queries, hash reads, a
`gh` existence probe). There is exactly **one** confirmation point (Step 3). No
filesystem write to the target happens before it. Declining leaves the target
byte-unchanged. This skill never commits — it guides the user to commit.

---

## Step 0: resolve script dir + roots

Resolve the skill's `scripts/` directory across install channels (plugin-root
candidate FIRST — the Claude Code loader inline-substitutes `${CLAUDE_PLUGIN_ROOT}`
inside skill content; on a project/`.claude` channel it is unset, so `-d` fails
and the loop falls through to the `$PWD/.claude/...` fallback):

```bash
for S in \
  "${CLAUDE_PLUGIN_ROOT}/skills/install/scripts" \
  "$PWD/.claude/skills/install/scripts"; do
  [ -d "$S" ] && break
done

# Source (where the tool lives): the marketplace-cache repo root, two levels up
# from the plugin root — it holds setup/init.sh and setup/manifest.json.
PLUGIN_CACHE_ROOT="${CLAUDE_PLUGIN_ROOT}/../.."

# Target (where the stamp/state goes): the consuming project root.
TARGET_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
```

Never conflate `PLUGIN_CACHE_ROOT` (source) with `TARGET_ROOT` (target) — the
same script-location vs state-location split the drift-check/hook layer enforces.

## Step 1: detect + report (automatic, NO write)

Run `detect.sh` and parse its `key=value` stdout:

```bash
TARGET_ROOT="$TARGET_ROOT" PLUGIN_CACHE_ROOT="$PLUGIN_CACHE_ROOT" sh "$S/detect.sh"
```

Detection runs the **cache's** known-good `drift-check.sh` against the target
tree — the target's own copy is *read and hashed*, never executed — so a drifted
or tampered target copy is reported as drift, not run. Nothing is written to the
target.

Then **narrate** the situation to the user (read-only — nothing has been
written):

- **Install state**: `INSTALL_STATE` (`absent` → not yet installed; `installed`).
- **Drift**: `DRIFT_STATE` (`clean` / `drift` / `na` / `error`). On `drift`,
  report `DRIFT_FAILS` and `DRIFT_FIRST` (the first content-drift finding). On
  `error`, the cache oracle `drift-check.sh` was unresolvable or could not run —
  surface it, do not treat it as clean.
- **Version skew**: if `VERSION_SKEW=yes`, note that a re-stamp will move the
  thin-root from `VERSION_INSTALLED` to `VERSION_CACHE`.
- **Derived identity** (display-only): `ORG` / `REPO` / `DEFAULT_BRANCH` /
  `TOPOLOGY`. Empty fields were omitted on purpose (non-GitHub / no remote) —
  do not ask the user for them.

<!-- AGENT-TEAMS-ENV-DISCLOSURE -->
- **Agent Teams enablement (disclose before confirming).** The settings pin
  merges `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` into the target's
  `.claude/settings.json`. This enables Claude Code's **experimental** Agent
  Teams feature (default-off upstream), which AutoFlow's Communication layer
  requires. Note the **token-cost implication**: multi-teammate coordination
  runs additional agents. Surface this so the user confirms the stamp
  (Step 3) informed.

<!-- REVIEWER-BACKEND-DISCLOSURE -->
- **Reviewer backend (disclose before confirming; issue #979).** Read
  `REVIEW_BACKEND` (configured backend, default `codex`), `REVIEW_CODEX_PRESENT`,
  and `REVIEW_CLAUDE_PRESENT` from the Step-1 report. The install delivers the
  target-owned scaffold `.claude/autoflow.local.json` with its **`codex`
  default** (never overwritten on re-install). **When `REVIEW_CODEX_PRESENT=no`,
  DISCLOSE** that HANDOFF step-6 external review will **fail-closed at PREFLIGHT**
  (`scripts/preflight/check-review-backend.sh`) until either the `codex` CLI is
  installed or the backend is switched to `claude` (requires the `claude` CLI +
  subscription/OAuth; note the vendor-independence trade-off — `claude` loses
  cross-vendor blind-spot coverage). Offer the backend choice at the single
  Step-3 confirmation. **No silent downgrade:** never auto-write
  `backend:claude`; only rewrite the scaffold to `claude` on the operator's
  **explicit** selection. Declining a switch **leaves the scaffold at `codex`**
  (it then fails closed on codex-CLI absence, never a silent switch). **When
  `REVIEW_BACKEND` is neither `codex` nor `claude` (e.g. `invalid`), DISCLOSE**
  that `.claude/autoflow.local.json` is present but **unparseable or has an empty
  `.review.backend`** — it must be hand-fixed before HANDOFF review (the
  consumers fail closed rather than treat a corrupt config as a clean codex
  default), not silently downgraded. **After** the selection is persisted, the
  install runs an advisory on-demand `--probe` auth check (one real
  authenticated round-trip against the configured backend); it narrates the
  result but never aborts the install, and PREFLIGHT itself stays
  presence-only. See
  [`docs/reviewer-backend.md`](../../../../docs/reviewer-backend.md).

## Step 2: [multi-repo only] fork-URL proposal (display-only)

If `TOPOLOGY=multi`, include the derived `FORK_PROPOSAL` and `FORK_EXISTS`
(`yes` / `no` / `unknown`) **inside the Step 1 report** — as information, not a
separate prompt.

## Step 3: confirm — the single opt-in gate

Ask the user **once** whether to stamp (in multi-repo, this same prompt also
confirms the fork-URL shown above). This is the only confirmation across both
topologies. **If the user declines, STOP here — perform zero writes** (the fork
proposal and the stamp are both abandoned; the target stays byte-unchanged).

## Step 4: on confirmation — stamp (writes begin here)

Only after the user confirms at Step 3:

**a. Scaffold the identity draft (if absent).** Write a derived
`CLAUDE.local.md` draft *before* the stamp, so `init.sh`'s own scaffold step
no-ops and the derived identity wins over the generic boilerplate. When
`CLAUDE.local.md` already exists this is a no-op (R3 — never overwrite):

```bash
TARGET_ROOT="$TARGET_ROOT" ORG="$ORG" REPO="$REPO" \
  DEFAULT_BRANCH="$DEFAULT_BRANCH" TOPOLOGY="$TOPOLOGY" \
  sh "$S/scaffold-identity.sh"
```

**b. Stamp the bundle** by delegating to the reused installer:

```bash
bash "$PLUGIN_CACHE_ROOT/setup/init.sh" --target "$TARGET_ROOT"
```

**c. Persist the reviewer-backend selection (only on an explicit switch).**
<!-- REVIEWER-BACKEND-PERSIST -->
The stamp (step b) shipped `.claude/autoflow.local.json` with its `codex`
default. If — and only if — the operator **explicitly** chose `claude` at the
Step-3 confirmation (the disclosed switch, `REVIEW_CODEX_PRESENT=no` path),
record that choice now into `.claude/autoflow.local.json`; otherwise skip this
sub-step and leave the `codex` default in place (no silent downgrade):

```bash
TARGET_ROOT="$TARGET_ROOT" BACKEND=claude sh "$S/set-review-backend.sh"
```

**d. Probe the configured reviewer backend's auth (advisory; issue #979).**
<!-- REVIEWER-BACKEND-PROBE -->
Now that the selection is persisted (step c, or the retained `codex` default),
run the shipped on-demand `--probe` against the just-persisted backend. This is
one real authenticated round-trip over the identical channel HANDOFF step 6
uses — it verifies the operator will not hit a silent auth failure on their
first cycle. Runs for **both** the `codex` default and an explicit `claude`
switch:

```bash
bash "$TARGET_ROOT/scripts/preflight/check-review-backend.sh" --probe
```

**Advisory only — narrate the outcome, never abort the install** on a
non-zero exit (the probe is an operator diagnostic, not a gate; PREFLIGHT stays
presence-only). Map the exit code:
- `0` → "auth verified — the configured backend is authenticated and responsive."
- `1` → "the configured backend's CLI is not installed — install it (see the
  presence remedy in the drift-check output)."
- `3` → "could not verify auth in this environment (timeout / no-TTY) — it will
  surface at HANDOFF step 6."
- `4` → "the configured backend is present but the auth round-trip failed — you
  will hit this at HANDOFF step 6; fix credentials before your first cycle."

**e. Self-verify** by re-running the shipped drift detector:

```bash
CLAUDE_PROJECT_DIR="$TARGET_ROOT" sh "$TARGET_ROOT/.claude/autoflow/drift-check.sh"
```

**f. Report the drift-check result and guide the user to commit.** Do NOT
commit on their behalf — the target owns its version record via its own commits
(R1). End here.
