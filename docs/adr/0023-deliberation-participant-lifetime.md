# ADR-0023: Deliberation participant lifetime — orchestrator-relayed persistent participants adopted; verification scope over the transcript

## Status

Accepted — operator decision of 2026-09-05 (issue #177 session): the ARCHITECT participants are kept
alive for the length of the discussion and the orchestrator wakes them in turn. The review had
proposed gating this on a pilot; the operator chose to proceed directly, and the measurement in D4
is kept as an effect record. **Implemented by issue #179 (2026-09-05)** in the A2 realization —
the step-0 probe of D4 delivered 3/3 — with the realization changes of D3 made; the step-0 record
and the effect record are in *Implementation record* below.

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
judgment (the class issue #166 removed). It is carried into the persistent participants' prompt
under D2: a participant that re-reads what it or the other side already anchored is the same
waste.

**D2 — Adopted: persistent participants relayed by the orchestrator (operator decision,
2026-09-05).** The Developer AI and the Test AI are spawned once per ARCHITECT discussion and
kept for its length. Each turn is appended to `.autoflow/issue-{N}-architect-transcript.md` and
the participant's final text is one line (turn number, anything further to raise); the
orchestrator alternates the wakes and ends the discussion at two consecutive "nothing further"
(#166 unchanged); reports, scribe and ledger read the transcript file. The realization is **A2**
— two anonymous direct spawns (`subagent_type` declared, no `name`) resumed by agent ID through
`SendMessage`. **A1** — a named spawn woken by name — is rejected as the primary realization: the
same mechanics, but it re-opens the hook's name denial and ADR-0017 Q3, and under this
repository's `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` it creates an in-process teammate that
`/resume` does not restore. A1 is the fallback only if the delivery precondition in D4 fails for
A2, since the operator's decision is the relay itself, not the addressing form.

**D3 — Relation to the standing records (what is and is not superseded).**

| Record | Standing after this ADR |
|---|---|
| ADR-0017 Q3 (one declaration channel, `subagent_type`) | **Not superseded.** A2 declares through `subagent_type` at spawn; resumption by agent ID adds no channel. A1 would have superseded it, and is rejected. |
| CLAUDE.md > *Spawn mode by role lifetime* ("no role holds a lifetime spanning phases") | **Not superseded.** A relayed participant lives inside one phase. The table gained a within-ARCHITECT row (issue #179); the cross-phase rule stands for every role. |
| The hook's name-carrying-payload denial | **Unchanged** under A2. Touched only if the A1 fallback in D2 is taken. |
| ADR-0021 (C7 `EQUAL_OR_BETTER`, C8 cost) | **Stands.** It compared named vs direct spawns across phases; nothing here re-measures detection. Its C8 cache reading is corrected by constraint 3: the warm-wake "saving" is the static prefix a fresh spawn also gets. |
| `docs/design-rationale.md` > Decision 8 | **The rule stands; its realization clause is superseded for the ARCHITECT participants.** Isolation of the orchestrator from round-by-round prose is kept and is required of the relay (the isolation check in D4). The clause that binds the contract to the `Workflow` as the single realization that "enforces the relay order, the two-consecutive-`done` termination and the isolated report return in code" no longer holds for ARCHITECT: relay order and the end condition are computed by a decidable-state script over the transcript file and obeyed by the orchestrator's procedure. The VERIFY cause-branch keeps its `Workflow`. |
| `docs/teammate-contracts.md` > Facilitator > *Realization — the `Workflow` tool (single supported mechanism)*; CLAUDE.md > Deliberation Isolation `[MUST]` (`Workflow`, not a nested team) | **Amended by issue #179**: the orchestrator relay is the ARCHITECT realization (Discuss + Report), the `architect-deliberation` `Workflow` is its Record phase, and the `Workflow` remains the VERIFY cause-branch realization. The nested-team rejection stands. |
| Issue #166 (form: fixed prompts, relay, conclusion report, participants' own end) | **Kept** by D1 and D2. |
| Issue #168 (name denial rests on cost and consistency, not delivery) | **Kept**; constraint 3 removes the cache half of the cost ground for the deliberation participants specifically; the call-count effect is what D4 records. |

**D4 — Delivery precondition, and what the measurement records.** Before the relay is
implemented, one probe outside any cycle measures whether an anonymous sub-agent resumed by agent
ID returns its final text to the orchestrator as a task notification (the review §6, step 0 —
the issue #168 procedure with the name replaced by the ID). A miss switches the realization to
A1 (D2); it does not re-open the decision. The measurement in the review §6 is then run as an
**effect record**, the issue #146 form: the script at HEAD and the relay on one frozen input, one
tree, one spawn policy, sequentially, aggregated by the committed script, with GATE:PLAN scored
per arm by a fresh evaluator and the isolation check on the orchestrator's transcript. A GATE:PLAN
FAIL or turn text found in the orchestrator's transcript is a defect to fix in the relay, not an
adoption gate. The record is appended to this ADR.

## Alternatives Considered

- **A1 — named participants.** Rejected (D2). Same call-count effect as A2 at the price of the
  hook exception, the ADR-0017 Q3 partial supersede and the agent-teams dependency.
- **Pilot-gated adoption (the review's recommendation: D1 now, the relay only after a
  three-arm pilot).** Not taken. The review argued that A's remaining case — fewer calls — is a
  projection from the late-turn floor (≈ 60–90 calls against ≈ 105–135 under D1 alone) and that
  isolation and relay order move from code to procedure, and proposed the ADR-0017 form
  (conditional go, blocking pilot). The operator decided on 2026-09-05 to proceed with the relay
  directly; the pilot's arms are retained as the effect record in D4.
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

- The participants keep what they read: a file is read once per discussion, not once per turn,
  and the narrated re-verification that lengthened every message (review §3) has no reason to
  exist. Together with D1 this attacks both halves of the per-turn floor.
- The declaration channel, the cross-phase single-mode rule and the hook stay exactly as ADR-0017
  Q3 and issue #168 left them under the A2 realization.
- The effect is recorded against a control arm on the same input, with an isolation check, so the
  cost case rests on a measurement rather than on the cache argument constraint 3 refuted.

### Negative

- D1 relies on the participants honoring a scope statement; a wrong citation is caught only by
  the other side reading and disputing it (the protocol's "re-raise until resolved"), not by the
  script.
- Isolation and relay order are held by the participants' prompt, the orchestrator's procedure
  and a state script rather than by the workflow loop; one orchestrator turn is spent per
  participant turn; the `/workflows` progress view and run-level resume are lost for ARCHITECT.
- A session restart mid-discussion depends on the sub-agent transcripts surviving and the session
  being resumed (constraint 4's documentation); under the A1 fallback it loses the participants.
- The effect record costs two deliberations of one issue plus the delivery probe.

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
- Follow-on issue: #179 (the review §7 scope) — `scripts/architect/relay-state.sh`,
  `scripts/architect/isolation-check.sh`, `scripts/architect/deliberation-metrics.py`, the
  Record-only `.claude/workflows/architect-deliberation.js`, the participant prompt in
  `.claude/agents/autoflow-planner.md`, the `architect-dev-participant` /
  `architect-test-participant` policy rows, the procedure at `docs/autoflow-guide.md` > ARCHITECT
  > *Relay procedure*, and `tests/test-issue-179-relay-state.sh`.

## Notes

- Status was set to `Accepted` on the operator's decision in the issue #177 session
  (2026-09-05), per `docs/adr/README.md` > Status Values. The realization changes in D3 are made
  by the follow-on implementation issue; the effect record in D4 is appended here when it exists.
- Numbers in the sections above are the review's; the review is the single home of the baseline
  measurement and its method, and this record does not restate its tables. The *Implementation
  record* below carries the numbers issue #179 produced with the committed aggregation script.

## Implementation record (issue #179)

### Step 0 — delivery precondition (D4), Claude Code 2.1.261, 2026-09-05

One anonymous `general-purpose` spawn (Haiku 4.5, `model: haiku`, no `name`), outside any cycle,
told to end with a nonce line and to call no tool; resumed twice by `SendMessage` to its agent ID
with a new nonce each time. `subagentPromptCacheTtl: 1h` (user settings);
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json`, unused by this path.

| Step | Sent (UTC) | Answer (UTC) | Reached the orchestrator as | cache read / write | output |
|---|---|---|---|---|---|
| spawn (turn 1) | 05:09:24 | 05:09:26 | task notification, `result` = the nonce line verbatim | 0 / 44,593 | 4 |
| wake 1 (+44 s) | 05:10:08 | 05:10:10 | task notification of the same spawn, `result` verbatim | 44,593 / 190 | 82 |
| wake 2 (+55 s) | 05:11:03 | 05:11:05 | task notification of the same spawn, `result` verbatim | 44,783 / 159 | 1 |

Delivery 3/3 → realization **A2** (anonymous, resumed by agent ID); the A1 fallback was not taken,
so the gate hook's name denial and ADR-0017 Q3 are untouched, as D3 anticipated. Wake cost on this
path: each wake wrote only the new message and read the whole prefix from cache; constraint 3 of
the review (the ≈ 22K-static-prefix re-write) was measured on the named path at the 5-minute
TTL and did not reproduce here — recorded as a data point at `tests/manual/issue-42-manual-scenarios.md`
> M1 and `docs/teammate-common-rules.md` > Result delivery path by spawn mode. Procedure and raw
usage: issue #179's session; the same probe re-runs by the M1 steps with the name replaced by the ID.

### Effect record (D4) — arm 0 vs arm A2

<!-- EFFECT-RECORD -->
