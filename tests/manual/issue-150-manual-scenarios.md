# Issue #150 — Manual Scenarios (M1, M2)

Source: `.autoflow/issue-150-verification-design.md` > section 2 "Manual scenarios
(delegated, recorded in `tests/manual/`)" and section 4 "Not automatable, stated".
Both scenarios are **operator-authorized** splits, not verification-design
deferrals: M1 narrows AC4 (ledger `O2 [ac-decision]`), M2 narrows AC2 (ledger
`O1 [ac-decision]`). Neither is a composition-oracle contact point (no settled
decision names the harness's effort channel, or the orchestrator's own spawn
composition, as shared state) — see the verification design's Composition
oracle section (§3) and its close (§4, "Not automatable, stated").

Run each scenario once after GREEN lands (before HANDOFF), and record the
observed outcome inline in this file (a `## Result` subsection under each
scenario), so the manual delegation leaves a durable record rather than a
one-time unrecorded observation.

---

## M1 — the harness honors the effort channel (narrows AC4)

**What is not automatable and why.** AC4's declaration side (a row that omits
`effort` states inheritance, and the config documents this) is fully covered
by the automated **inherit-marker** and **effort-value-admission** legs in
`tests/test-spawn-policy-single-source.sh`. What those legs cannot observe is
whether the *harness itself* actually changes its behavior when a concrete
`effort` value is supplied on either channel — that is a property of the
installed Claude Code binary's runtime scheduling, not of this repository's
tree, and no static or CI-executed check can read it.

**Procedure.**

1. **Workflow `agent()` opts channel.** Pick one `workflow_sites` call site
   (e.g. `architect-deliberation` > `ledger`). In a throwaway branch, edit its
   config row to a distinctive, clearly-extreme `effort` value (e.g. `"max"`)
   and run one real ARCHITECT deliberation far enough to reach that call site.
   Compare the sub-agent's observable behavior (response latency, depth of
   reasoning visible in its returned artifact, or — if the harness surfaces it
   — an explicit effort indicator in its trace) against the same call site
   left at `"inherit"` on an otherwise identical run.
2. **Agent-definition frontmatter channel.** Pick one `.claude/agents/autoflow-*.md`
   definition whose policy row is `"inherit"` today. In the same throwaway
   branch, add a concrete `effort:` line (e.g. `effort: low`) to its
   frontmatter and spawn that agent type directly through the `Agent` tool.
   Compare its observable behavior against the same type with the frontmatter
   line removed (the shipped `inherit` state).
3. Revert both edits — this scenario is diagnostic only and its edits must
   never land.

**Pass condition.** The two observed behaviors in each channel differ in the
direction the effort value predicts (a `max`/high-effort call visibly does
more work than an `inherit` call at the same site; a `low`-effort direct spawn
visibly does less than an `inherit` one). A pass confirms the harness's
documented effort-inheritance behavior (feature design §1's *Workflow
`agent()` opts* and *Agent definition frontmatter* rows) actually holds at
runtime, on the installed binary, for both channels this design wires.

**Environment dependence.** The result is a property of the installed Claude
Code binary and its runtime scheduling, not of this tree — a version change
could alter or remove the observable difference without any change to
`.claude/autoflow/spawn-policy.json` or the workflow scripts. Re-run this
scenario after any Claude Code version bump that touches effort handling.

### Result

Date: 2026-08-24
Disposition: DECLINED
Authorized-by: operator (issue #150 cycle-2 session decision)

- Rationale: the config is a sample the user edits at stamp time; proving the
  installed harness's runtime effort semantics for the sample's default values
  guarantees nothing once the user changes them, and any observation is a
  one-session, one-binary snapshot (this scenario's own environment-dependence
  clause). Runtime-semantics verification is outside this issue's scope (the
  issue adopts a config-defined format; format, delivery and validation are
  closed by the automated legs).
- Incidental observation retained: two spawns in this session recorded
  `"effort":"medium"` (the session default) in their transcripts with no
  effort declared — the omitted-value → session-inheritance fallback was
  directly observed at the transcript level. A mid-session agent-definition
  frontmatter edit was NOT reloaded (the `effort: low` spawn also ran
  `medium`), so frontmatter-channel observation requires a fresh session.

---

## M2 — the orchestrator's direct spawn carries the resolved values (narrows AC2)

**What is not automatable and why.** AC2's workflow-site and hook-surrogate
legs (`resolver-propagation`, `site-key-join`, `site-spread-totality`,
`hook-advisory`, `advisory-silence-on-empty-set`) are fully automated in
`tests/test-spawn-policy-single-source.sh` and the `tests/test-gate-hardening.sh`
extension. What remains uncovered is the **orchestrator's own act** of typing
`model` (and, where declared, `effort`) into a direct `Agent` call by reading
`scripts/spawn-policy/spawn-policy.sh model <phase-key>` rather than from
memory of the old CLAUDE.md table or a stale cached value — a human/harness
behavior with no in-repo oracle (CLAUDE.md's own `[MUST]`, amended by this
design's §8, states the obligation; nothing in the tree can observe the
orchestrator's own reasoning process that produced a spawn call).

**Procedure.**

1. Run one gated phase end-to-end that reaches a direct `Agent` spawn (e.g.
   DIAGNOSE Phase A, or GATE:PLAN evaluation) on a live issue after GREEN
   lands.
2. Before the spawn, independently run
   `bash scripts/spawn-policy/spawn-policy.sh model <phase-key>` (and
   `... effort <phase-key>` if the row declares a concrete value) for that
   phase's key.
3. Compare the resolver's printed value against the `model` (and `effort`,
   where applicable) parameter the orchestrator actually declared on the
   `Agent` call.
4. Check the hook's stderr for that spawn: no `WARNING: … (advisory — this
   call is NOT blocked)` line should appear, since a spawn typed from the
   resolver's own output is by construction inside the config's admitted set
   for that `subagent_type`.

**Pass condition.** The declared `model` (and `effort`, if the row is
concrete) matches the resolver's output exactly, and the hook emits no
advisory line for that spawn.

**Environment dependence.** This is not environment-dependent in the sense M1
is — the tree fully determines what the *correct* value is. What it lacks is
an in-repo oracle for the orchestrator's own compliance: nothing in the
codebase can mechanically verify that a human/agent session actually ran the
resolver before typing the parameter, as opposed to recalling the right value
by coincidence. That is why it is delegated to a recorded manual check rather
than claimed as automated.

### Result

Date: 2026-08-24
Disposition: PASS

- Phase exercised: cycle-2 diagnostic analysis spawn (`autoflow-analyzer`, phase key `diagnose-phase-a`) on live issue #150, after cycle-2 GREEN (d6e2ab6).
- Resolver output: `spawn-policy.sh model diagnose-phase-a` → `sonnet`; `spawn-policy.sh effort diagnose-phase-a` → `inherit`.
- Declared spawn parameters: `model: "sonnet"` (matches resolver output exactly); no `effort` parameter declared (matches the `inherit` sentinel — inheritance is expressed by omission on the spawn channel).
- Hook advisory: no `WARNING: … (advisory — this call is NOT blocked)` line appeared for the spawn; the call proceeded silently through the PreToolUse hook.
