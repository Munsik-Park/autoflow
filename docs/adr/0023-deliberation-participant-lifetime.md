# ADR-0023: Deliberation participant lifetime — verification scope over the transcript now; persistent participants pilot-gated

## Status

Proposed

## Context

The ARCHITECT deliberation (`.claude/workflows/architect-deliberation.js`, the issue #166 form)
spawns a fresh sub-agent for every turn and hands it the transcript so far. Measured on
2026-09-05 (issue #2, Claude Code 2.1.260, `claude-opus-5` `xhigh`): 16 turns, 195 API calls,
246 file reads, 93 minutes, ≈ 2.6M tokens; the per-turn prompt grew from 58K to 122K tokens with
only the 21K static prefix read from cache; 14 of 21 sub-agents read the gate hook, 13 read the
ledger. The cause is two rules compounding — each turn's agent has no memory, and the Discussion
Protocol's VERIFY step ("actually read … memory alone is not enough") makes that agent re-verify
everything the transcript asserts. The full measurement, the constraints and the option
comparison are in `docs/design-reviews/issue-177-deliberation-participant-lifetime.md` (the
review); this record states the decision and its relation to the earlier records.

Constraints measured on 2.1.260 that bound the decision (review §2): a persistent participant
cannot live inside a `Workflow` (`agent()` is one-shot); only the orchestrator can relay a
persistent participant (a sub-agent never receives the woken agent's reply); and persistence buys
no prompt cache (a wake re-writes everything past the same ≈ 22K static prefix a fresh spawn also
reads from cache — <https://github.com/anthropics/claude-code/issues/91971#issuecomment-5545302645>).
One documentary fact was added by the review: an anonymous sub-agent is resumable by agent ID
through `SendMessage` without agent teams, and the gate hook's name denial does not cover that
path by its own text (`.claude/hooks/check-autoflow-gate.sh:638-640`); its delivery path is
unmeasured.

## Decision

**D1 — Adopted now: the VERIFY step's scope over the transcript.** One sentence is added to the
Discussion Protocol's step 2 (`docs/teammate-common-rules.md`) and mirrored in the turn prompt's
`TURN_RULE`: *a fact the transcript cites with a `path:line` (or a command and its output) is
verified for both participants; a participant reads a file to ground a claim it is making or to
dispute a cited one.* The per-turn respawn, the `Workflow` realization, the hook and every spawn
rule are unchanged. This is a statement of an existing rule's scope, not a new check, cap or
judgment (the class issue #166 removed), and it applies under D2 as well.

**D2 — Re-opened, not adopted: persistent participants relayed by the orchestrator.** The
realization admitted to a pilot is **A2** — two anonymous direct spawns (`subagent_type`
declared, no `name`) kept for the length of one ARCHITECT discussion and resumed by agent ID; each
turn is appended to `.autoflow/issue-{N}-architect-transcript.md` and the participant's final
text is one line (turn number, anything further to raise); the orchestrator alternates the wakes
and ends the discussion at two consecutive "nothing further" (#166 unchanged); reports, scribe
and ledger read the transcript file. **A1** — a named spawn woken by name — is rejected: same
mechanics, but it re-opens the hook's name denial and ADR-0017 Q3, and under this repository's
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` it creates an in-process teammate that `/resume` does
not restore. A2 becomes adopted only through the pilot in D4; until then the single realization
stays the `Workflow`.

**D3 — Relation to the standing records (what is and is not superseded).**

| Record | Standing after this ADR |
|---|---|
| ADR-0017 Q3 (one declaration channel, `subagent_type`) | **Not superseded.** A2 declares through `subagent_type` at spawn; resumption by agent ID adds no channel. A1 would have superseded it, and is rejected. |
| CLAUDE.md > *Spawn mode by role lifetime* ("no role holds a lifetime spanning phases") | **Not superseded.** An A2 participant lives inside one phase. If A2 is adopted, the table gains a within-ARCHITECT row; the cross-phase rule stands for every role. |
| The hook's name-carrying-payload denial | **Unchanged** under D1 and A2. |
| ADR-0021 (C7 `EQUAL_OR_BETTER`, C8 cost) | **Stands.** It compared named vs direct spawns across phases; nothing here re-measures detection. Its C8 cache reading is corrected by constraint 3: the warm-wake "saving" is the static prefix a fresh spawn also gets. |
| `docs/design-rationale.md` > Decision 8 | **The rule stands; one clause is conditionally superseded.** Isolation of the orchestrator from round-by-round prose is kept by D1 and required of A2 (the isolation check in D4). The clause that binds the contract to the `Workflow` as the single realization that "enforces the relay order, the two-consecutive-`done` termination and the isolated report return in code" is superseded **only if** A2 is adopted, and then for the ARCHITECT participants only; A joins the peer facilitator in Decision 8's "reopened, not adopted" record until then. |
| `docs/teammate-contracts.md` > Facilitator > *Realization — the `Workflow` tool (single supported mechanism)*; CLAUDE.md > Deliberation Isolation `[MUST]` (`Workflow`, not a nested team) | **Unchanged now**; amended to "one of two realizations" only on A2 adoption. |
| Issue #166 (form: fixed prompts, relay, conclusion report, participants' own end) | **Kept** by D1 and D2. |
| Issue #168 (name denial rests on cost and consistency, not delivery) | **Kept**; constraint 3 removes the cache half of the cost ground for the deliberation participants specifically, leaving the call-count question to the pilot. |

**D4 — What decides A2, and who.** The pilot in the review §6: step 0 measures the anonymous
resume's delivery path; arms 0 (HEAD), B (D1) and A2 run on one frozen input, one tree, one
spawn policy, sequentially, and are aggregated by the committed script. The operator judges the
before/after contrast (issue #146 precedent, no fixed cutoff). Two outcomes disqualify an arm
regardless of cost: a GATE:PLAN FAIL where the control passes, and turn text found in the
orchestrator's transcript under A2. On adoption, the pilot record is appended to this ADR and its
status moves as the owner decides; on rejection, D2 is closed here and the `Workflow` stays the
single realization.

## Alternatives Considered

- **A1 — named participants.** Rejected (D2). Same call-count effect as A2 at the price of the
  hook exception, the ADR-0017 Q3 partial supersede and the agent-teams dependency.
- **Adopt A2 directly, without a pilot.** Rejected. Constraint 3 removed A's cache case; its
  remaining case — fewer calls — is a projection from the late-turn floor in the review §1.2
  (≈ 60–90 calls against ≈ 105–135 under D1), and the isolation and relay-order guarantees move
  from code to procedure. That trade is not made on a projection; ADR-0017 took the same
  position (conditional go, blocking pilot) for the spawn-mode migration.
- **Lower the turn sites' effort in `.claude/autoflow/spawn-policy.json`.** Not decided here.
  The 155-run scan shows `medium`-effort runs at 100–270 calls and 20–60 min against `xhigh` at
  416–575 calls and 101–136 min: effort multiplies each call's cost and does not remove calls,
  and the quality relation is unmeasured. The row is target-owned and the operator's; the pilot
  holds it fixed so the arms compare on structure alone.
- **A peer-teammate facilitator, or a facilitator sub-agent relaying persistent participants.**
  Not executable: constraint 2 (the woken agent's reply reaches only the session's main loop)
  and the standing Agent Teams limitation that a teammate cannot spawn teammates.
- **Do nothing.** Rejected on the measurement: the deliberation costs 200–575 calls and 45–136
  minutes per run at `xhigh` (review §1), roughly ten times the implementation phases of the
  same cycle (issue #166's #595 record), with no correctness defect that the cost buys.

## Consequences

### Positive

- D1 lands as one sentence in two places, with no change to spawn mode, hook, `Workflow`
  realization or any ADR, and is expected (review §5) to remove roughly the re-verification half
  of the per-turn cost.
- The decision on persistence is tied to a measurement with a control arm and an isolation
  check, not to the cache argument constraint 3 refuted.
- The declaration channel, the cross-phase single-mode rule and the hook stay exactly as ADR-0017
  Q3 and issue #168 left them, whatever the pilot returns.

### Negative

- D1 relies on the participants honoring a scope statement; a wrong citation is caught only by
  the other side reading and disputing it (the protocol's "re-raise until resolved"), not by the
  script.
- If A2 is adopted, isolation and relay order are held by procedure and a state script rather
  than by the workflow loop, one orchestrator turn is spent per participant turn, and the
  `/workflows` progress view and run-level resume are lost for ARCHITECT.
- The pilot costs three deliberations of one issue plus a delivery probe.

### Neutral / Trade-Offs

- Constraint 3 is a harness property (the resume path re-writes past the static prefix). A
  later Claude Code version that caches a wake fully would change the token column of the
  review §5, not the call-count column; the pilot record names the version it ran on.
- D1 slightly shortens turn messages by design (no narrated re-verification), which is also what
  slows the per-turn prompt growth in the review §1.2.

## Related Issues / PRs

- Issue #177 (this decision); issue #166 (deliberation form, kept); issue #168 (name denial
  grounds re-verified); issue #136 and ADR-0017 > Notes > C8 (wake cost measurement, corrected on
  the cache axis by constraint 3); issue #146 (before/after contrast as the judgment form);
  issues #51, #52, #74 and ADR-0021 (teammate removal, pilot and migration — stand).
- `docs/design-rationale.md` > Decision 8 (isolation rule; realization clause conditionally
  superseded); `docs/teammate-contracts.md` > Facilitator; CLAUDE.md > Deliberation Isolation and
  > Spawn mode by role lifetime.
- Upstream: `anthropics/claude-code#91971` (comment of 2026-09-04, the wake re-write
  measurement).
- Follow-on issues: the review §7 lists the two implementation issues this decision splits into.

## Notes

- The `Proposed` to `Accepted` transition is the owner's decision, per `docs/adr/README.md` >
  Status Values. D1 can be implemented under `Proposed`; D2's realization changes (the
  conditional supersedes in D3) are made only after the pilot record is appended here.
- Numbers in this record are the review's; the review is the single home of the measurement and
  its method, and this record does not restate its tables.
