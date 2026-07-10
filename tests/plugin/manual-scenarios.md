# Manual Verification Scenarios — Issue #790 [#785-S4a] Plugin Packaging

These items cannot be discharged by `tests/plugin/verify-package.sh` — they
require a live Claude Code client / plugin runtime (environment-dependent,
type **E**) per `.autoflow/issue-790-verification-design.md` §1/§2 and
DCR-3. A green unit test that merely sets `CLAUDE_PLUGIN_ROOT` /
`CLAUDE_PROJECT_DIR` env vars does **not** discharge these — that tests the
script, not the harness contract that supplies those vars to plugin-shipped
hooks. Itemize at VALIDATE; do not mark any of these PASS from automated
output alone.

---

## M-1 — Manifest loads (AC1, type E)

**Setup**: from the repo root, run:

```
claude --plugin-dir ./plugin/autoflow
```

**Steps**: start the session; check `/context` or the plugin manager surface.

**Expected**: Claude Code recognizes `.claude-plugin/plugin.json` as a valid
plugin manifest and loads it without a schema-rejection error. The plugin
appears with name `autoflow`.

**Fail signal**: a manifest/schema error at startup, or the plugin not
appearing at all.

---

## M-2 — Marketplace add + install (AC2, type E)

**Setup**: from a scratch directory (or this repo):

```
/plugin marketplace add <path-to-this-repo>
/plugin install autoflow@autoflow
```

(or, once pushed, `/plugin marketplace add Munsik-Park/autoflow`).

**Expected**: the marketplace `autoflow` is added; `autoflow` is
discoverable and installs from the self-hosted `./plugin/autoflow` source
without a path-resolution error.

**Fail signal**: `plugin-not-found`, a relative-path resolution error, or the
marketplace failing to register.

---

## M-3 — Hooks fire via the plugin channel (AC3, type E)

**Setup**: install the plugin (per M-2) against a **scratch target repo** that
has **no** host-only `.claude/settings.json` hook registration (isolates the
plugin channel — do not touch this repo's own `.claude/settings.json`, which
stays registered per M-5).

**Steps**: in the scratch target, attempt an action the gate blocks
unconditionally regardless of state (e.g. run a tool call whose command is
`gh pr merge 1`).

**Expected**: the plugin-registered `PreToolUse` hook fires and blocks the
action (exit 2 / "BLOCKED: AutoFlow does not merge").

**Fail signal**: the action is not blocked — the plugin-fired hook never ran.

---

## M-4 — `${CLAUDE_PROJECT_DIR}` parity (AC-ENV, type E, **mandatory**)

This is the ADR-0015 Neutral consequence explicitly named as a re-verify-at-
S4a acceptance — the single highest-risk assumption (feature design §9). It
is **not** dischargeable by any in-repo test (DCR-3): the automated 8b check
in `verify-package.sh` proves the *script itself* reads
`${CLAUDE_PROJECT_DIR}`, but only a live client proves the *harness* actually
supplies the target's project directory to a *plugin-delivered* hook the same
way it does for a project-level one.

**Setup**: install the plugin (per M-2) against a scratch target repo at path
`<TARGET>`. Create an active AutoFlow state file at
`<TARGET>/.autoflow/issue-1.json` (any well-formed active state — see
`tests/fixtures/` for a template).

**Steps**: trigger a gated tool event (e.g. `git push` inside `<TARGET>`).

**Expected**: the plugin-fired hook resolves and acts on
`<TARGET>/.autoflow`'s state (i.e. the harness sets `${CLAUDE_PROJECT_DIR}` =
`<TARGET>` for the plugin-shipped hook, exactly as it would for a
project-level `.claude/hooks/*.sh`).

**Fail signal / escalation**: the hook does not see `<TARGET>/.autoflow`
(e.g. it resolves state relative to the plugin's own install directory, or
sees no state at all). If this scenario cannot be exercised deterministically
in the available client, **escalate — do not assume PASS.**

---

## M-5 — Self-dogfooding preserved (DCR-6, type E, downgraded to a static
guard by the additive model — confirm as a regression guard)

**Setup**: none beyond the current repo — `.claude/settings.json` is left
byte-for-byte intact by D-1 (asserted statically by
`verify-package.sh`'s AC5 empty-diff check).

**Steps**: in this repo's own Claude Code session, attempt a known-blocked
action (e.g. `gh pr merge`).

**Expected**: this repo's own gate enforcement still blocks it via the
existing `.claude/settings.json` inline registration — unaffected by the new
plugin channel.

**Fail signal**: the action is not blocked in this repo's own session.

---

## M-R1 — Packaged skill resolves scripts on a plugin-only install (AC-R1, type E, **mandatory**)

This is the residual, in-repo-unverifiable claim behind AC-R1's static loop
check: whether the Claude Code loader **inline-substitutes** the literal
`${CLAUDE_PLUGIN_ROOT}` token inside a **skill**'s bash content, the same way
it is documented to do for hook commands (verification design §1
AC-R1/§2). The repo has demonstrated this substitution only for **hooks**
(`plugin/autoflow/hooks/hooks.json`) — never for a skill body. A green
`verify-package.sh` run does **not** discharge this; it only proves the
SKILL.md text names the right candidate, not that the harness resolves it.

**Setup**: install the plugin (per M-2) against a **scratch target repo that
has no `.claude/skills/epic-dash/` tree** (a plugin-only install target —
isolates the plugin channel from the `.claude/` fallback candidate).

**Steps**: invoke the packaged `epic-dash` skill through Step 2-6. Probe the
**resolved path the skill actually runs** (e.g. have the script log `$S`
before use) — do **not** rely on `echo $CLAUDE_PLUGIN_ROOT`, which reads
empty even when the fix works (the mechanism is inline content substitution
inside the skill body, not a live shell env var supplied to the skill's
subprocess).

**Expected**: the first loop candidate
`${CLAUDE_PLUGIN_ROOT}/skills/epic-dash/scripts` inline-substitutes to the
real packaged scripts directory, `[ -d "$S" ]` hits it, and
`extract_deps.py` / `build_pipeline.py` / `render_dash.py` execute
successfully (no "file not found").

**Fail signal / escalation**: the scripts fail to execute (file-not-found,
or resolution falls through to the `.claude/`-anchored fallback which is
dead on this plugin-only target). If this scenario cannot be exercised
deterministically in the available client, **escalate — do not assume
PASS.**

---

## M-R2 — Skill namespace observed empirically (informational, OOS-1)

Not a code gate this cycle (verification design §3 OOS-1) — Codex claim 2
(bare `/epic-dash` vs a possible `/autoflow:epic-dash` namespacing) is
recorded as an observation to close empirically, not actioned as a defect.

**Setup**: install the plugin (per M-2).

**Steps**: invoke the packaged `epic-dash` skill and note how it is exposed
(bare `epic-dash` vs plugin-namespaced `autoflow:epic-dash`).

**Expected / record**: whichever form is observed, note it for the VALIDATE
doc sweep. This does not gate PASS/FAIL this cycle; if namespacing is
observed, the bare-`/epic-dash` usage-block example (SKILL.md:20-23,
withdrawn from cycle 2's change surface per ledger E23) becomes a candidate
follow-up, not a re-open of this cycle's fix.

---

## M-6 — Skill namespace (feature §9 devil's-advocate, doc-sweep note, not a
code change)

**Setup**: install the plugin (per M-2).

**Steps**: invoke the packaged skill.

**Expected**: it is discoverable/invocable as `/autoflow:epic-dash` (plugin
namespacing) — not the bare `/epic-dash` (that bare form only applies to
this repo's own host-only `.claude/skills/epic-dash` self-use, which is
unaffected).

**Follow-up**: flag any doc or invocation on the *shipped* surface that still
references the bare `epic-dash` name for the VALIDATE doc sweep. This is a
documentation check, not a code change.
