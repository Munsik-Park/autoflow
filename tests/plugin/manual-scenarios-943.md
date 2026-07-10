# Manual Scenarios — Issue #943 `/autoflow:install` skill

These scenarios cover the acceptance criteria typed **M/E** (manual /
environment-dependent) in `.autoflow/issue-943-verification-design.md` §1/§2
— the irreducible LLM-orchestration surface of `/autoflow:install`: the
detect → report → **await confirmation** → stamp → auto-drift-check
sequencing, and the opt-in "declined → zero writes" behavior, are behaviors
of the LLM reading `SKILL.md`, not deterministically unit-testable. Every
other automation-grade surface (`detect.sh`, `scaffold-identity.sh`) is
covered by `tests/plugin/verify-install-skill-scripts.sh`; the static
`SKILL.md` structural guards are covered by `tests/plugin/verify-package.sh`
(AC1a/AC1b/AC4a/AC5a-d).

**None of these criteria are auto-PASS from automated suite output. Each is
marked NOT-automated below, with the reason it cannot be a deterministic
assertion.**

---

## AC2c — full skill orchestration (detect → report → confirm → stamp → auto-drift)

**Type**: NOT-automated (M/E — live-LLM-cycle: requires a real Claude Code
session reasoning over `SKILL.md` prose, not a scripted substitute)

**Why this cannot be scripted**: the sequencing itself — narrate, then gate
on a single confirmation, then write, then auto-run drift-check — is an
instruction the *LLM* follows when reading `SKILL.md`; there is no
deterministic oracle for "the model asked before writing" that would not
itself be a fidelity-violating scripted fake of the very LLM behavior under
test (cf. `tests/plugin/manual-scenarios-797.md` E-M1's identical rationale
for a live AutoFlow cycle).

**Scenario**:
1. Create a scratch, uninstalled target repo (no `.claude/autoflow/manifest.json`).
2. Install the `autoflow@autoflow` plugin in a Claude Code session rooted there.
3. Invoke `/autoflow:install`.
4. Observe: a detect/report step runs automatically (no write); the report
   states install-state=absent and the derived org/repo/branch/topology
   summary; a single confirmation prompt appears before any write.
5. Confirm at the prompt.
6. Observe: `scaffold-identity.sh` writes a `CLAUDE.local.md` draft (if
   absent), `init.sh --target` stamps the bundle, and `drift-check.sh` runs
   automatically afterward, reporting `0 failed`.

**Pass condition**: the full detect→report→confirm→stamp→auto-drift sequence
completes in the stated order, with exactly one confirmation prompt, and the
final drift-check reports `0 failed`.

---

## AC3c — re-stamp proposal + result on an installed+drifted fixture

**Type**: NOT-automated (M/E — live-LLM-cycle)

**Scenario**:
1. Install AutoFlow into a scratch target (`setup/init.sh --target`), then
   hand-mutate one stamped artifact (e.g. append a line to
   `.claude/autoflow/METHODOLOGY.md`).
2. Invoke `/autoflow:install` in a Claude Code session rooted there.
3. Observe: the report states drift is present and proposes a re-stamp.
4. Confirm.
5. Observe: after confirmation, `drift-check.sh` re-runs and reports
   `0 failed` (drift cleared).

**Pass condition**: drift is reported before confirmation, the re-stamp
clears it, and the final drift-check reports `0 failed`.

---

## AC4b — declined confirmation → zero writes (the load-bearing opt-in check)

**Type**: NOT-automated (M/E — live-LLM-cycle; this is the safety-critical
arm of AC4, since the static `SKILL.md` guard in `verify-package.sh` AC4a
only proves the *instruction ordering*, not that a real declined prompt
produces zero writes)

**Scenario**:
1. Create a scratch, uninstalled target repo. Snapshot its full file tree
   (`find . -type f | sort` + content hashes).
2. Invoke `/autoflow:install` in a Claude Code session rooted there.
3. At the confirmation prompt, **decline**.
4. Re-snapshot the target's file tree and compare against step 1.

**Pass condition**: the target working tree is byte-unchanged — no
`.claude/**` directory created, no `CLAUDE.md` AUTOFLOW-IMPORT fence added,
no `CLAUDE.local.md` written. Any new or modified file is a fail signal: the
opt-in boundary (AC4) was violated.

---

## AD3 (behavioral) — multi-repo fork-URL confirmation (the single 1× confirm)

**Type**: NOT-automated (M/E — live-LLM-cycle; the `gh`-mocked detect.sh arms
in `verify-install-skill-scripts.sh` cover the derivation/existence-check
logic only, never the actual confirmation UX)

**Scenario**: repeat AC2c/AC3c inside a **multi-repo** scratch target (one
registered submodule). Observe that the fork-URL proposal (`FORK_PROPOSAL`)
and `FORK_EXISTS` are folded into the *same* Step 1-3 report/confirmation —
never a second, separate prompt.

**Pass condition**: exactly one confirmation point across the whole cycle,
covering both the stamp and (when multi-repo) the fork-URL proposal.

---

## M-3-style residual — `${CLAUDE_PLUGIN_ROOT}` inline-substitution inside the install skill body

**Type**: NOT-automated (E — environment-dependent; mirrors
`tests/plugin/manual-scenarios.md` M-R1 for `epic-dash`)

**Why this cannot be scripted**: whether the Claude Code loader
inline-substitutes the literal `${CLAUDE_PLUGIN_ROOT}` token inside the
*install* skill's body is a claim about the harness, not about the shipped
text — a green `verify-package.sh` only proves `SKILL.md` names the right
candidate first in the portable resolution loop, never that the harness
resolves it (feature-design §5 residual).

**Scenario**: install the plugin against a scratch target with **no**
`.claude/skills/install/` tree (a plugin-only install target — this skill
ships with no host twin at all, so this is the *only* resolution path).
Invoke `/autoflow:install` and probe the resolved script directory the skill
actually runs (e.g. have `detect.sh` echo its own resolved path before use)
— do not rely on a bare `echo $CLAUDE_PLUGIN_ROOT`, which reads empty even
when substitution works correctly (the mechanism is inline content
substitution inside the skill body, not a live shell env var).

**Expected**: the first loop candidate
`${CLAUDE_PLUGIN_ROOT}/skills/install/scripts` inline-substitutes to the
real packaged scripts directory and `detect.sh`/`scaffold-identity.sh`
execute successfully (no "file not found").

**Fail signal / escalation**: the scripts fail to execute, or resolution
falls through to the `.claude/`-anchored fallback (dead on a plugin-only
target, since this skill ships no host twin). If this scenario cannot be
exercised deterministically in the available client, **escalate — do not
assume PASS.**

---

## Itemization note (VALIDATE)

At VALIDATE, the assignee should confirm:

- [ ] AC2c: a real Claude Code session drove the full
      detect→report→confirm→stamp→auto-drift sequence on an uninstalled
      scratch target, ending with `drift-check.sh` reporting `0 failed`
- [ ] AC3c: the same session, against an installed+drifted target, reported
      drift, proposed re-stamp, and cleared drift after confirmation
- [ ] AC4b: a declined confirmation left the target working tree
      byte-unchanged (no `.claude/**`, no `CLAUDE.md` fence, no
      `CLAUDE.local.md`)
- [ ] AD3: the multi-repo fork-URL proposal was folded into the single
      Step 1-3 confirmation, never a second prompt
- [ ] The `${CLAUDE_PLUGIN_ROOT}` inline-substitution residual was exercised
      on a plugin-only target (no `.claude/skills/install/`), or escalated
      if not exercisable
- [ ] Any defect surfaced during these scenarios is filed against
      `claude-autoflow` (Part of epic #785), tracing to the owning
      surface (`SKILL.md` orchestration vs `detect.sh`/`scaffold-identity.sh`)
