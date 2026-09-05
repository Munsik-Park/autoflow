# Design review — deliberation participant lifetime: per-turn respawn vs persistent relay (issue #177)

**Question.** The ARCHITECT deliberation spawns a fresh sub-agent for every turn and hands it the
whole transcript (`.claude/workflows/architect-deliberation.js:245-272`). Should the two
participants instead persist across turns and be relayed by the orchestrator, or should the
per-turn respawn stay and the re-verification rule be narrowed? This review compares the two on
the 2026-09-05 measurement, states the runtime constraints that were measured, designs the pilot
that decides between them, and lists what a follow-on implementation issue would touch. The
decision itself is ADR-0023 (`docs/adr/0023-deliberation-participant-lifetime.md`).

**What is not re-opened.** The deliberation's *form* — fixed prompts, turn relay, conclusion
report, ending at the participants' own conclusion — is issue #166's decision and is kept by both
options. The Deliberation Isolation rule (`docs/design-rationale.md` > Decision 8: the orchestrator
never receives the round-by-round prose) is kept by both options; what differs is how it is
realized.

---

## 1. Baseline — the 2026-09-05 measurement

One ARCHITECT deliberation of issue #2 in this repository, run from the script at HEAD
(`e4e0257`, the #166 form), Claude Code 2.1.260, `claude-opus-5` at effort `xhigh` on every
governed site (the `policy-load` carve-out ran on the session model). Source: the workflow run's
sub-agent transcripts, `~/.claude/projects/<project>/<session>/subagents/workflows/wf_4ad22b86-446/agent-*.jsonl`
(21 files). Re-derived for this review with the method in §1.3.

### 1.1 Run totals

| Item | Value |
|---|---|
| Sub-agents / discussion turns | 21 / 16 (policy-load 1, turns 16, reports 2, scribe 1, ledger 1) |
| Wall clock | ≈ 91 min in-agent (turns 73 min; reports + scribe + ledger 19 min); 93 min end to end |
| API calls (distinct `requestId`) | 195 — 169 inside the 16 turns, 26 in policy-load / reports / scribe / ledger |
| API calls (streamed-record grouping) | 257 — the count the issue body cites; it splits a request whose streamed records straddle a tool result. Both counts index the same transcripts; §5 fixes the distinct-`requestId` count as the pilot metric |
| Tool calls | 246 `Bash` (220 inside turns), 21 `StructuredOutput`, 3 `ToolSearch`; no `Read` (the agent definitions route reads through `sed -n` / `grep`) |
| Model generation vs tool execution | 5,528 s vs 186 s — 97% of in-agent time is the model generating |
| Per-call duration | median 9.1 s, p90 60 s, max 230 s; 25 calls over 60 s |
| First-call prompt per turn | 58K tokens at turn 1 → 122K at turn 16 (max in-turn input 144K); cache read on the first call fixed at 21,202 tokens — the static prefix — on every turn |
| Turn message length | 6.5K–15.4K characters; each participant's report ≈ 20K; the scribe's consolidated report 25K |
| Tokens (issue body, same transcripts) | ≈ 2.6M |

### 1.2 Per turn

Turn 1 is the Developer AI; sides alternate. `calls` = distinct `requestId`; `first_in` = input
tokens of the turn's first call (the transcript prompt); `msg` = characters of the turn message.

| turn | side | calls | Bash | wall (s) | first_in | msg |
|---|---|---|---|---|---|---|
| 1 | dev | 16 | 25 | 276 | 58,452 | 13,185 |
| 2 | test | 11 | 18 | 275 | 63,707 | 14,910 |
| 3 | dev | 21 | 28 | 373 | 69,275 | 15,364 |
| 4 | test | 18 | 26 | 425 | 75,069 | 15,208 |
| 5 | dev | 12 | 15 | 328 | 80,660 | 14,363 |
| 6 | test | 10 | 11 | 343 | 86,323 | 12,869 |
| 7 | dev | 12 | 14 | 260 | 91,067 | 10,747 |
| 8 | test | 13 | 18 | 262 | 95,104 | 11,671 |
| 9 | dev | 5 | 7 | 189 | 99,239 | 8,742 |
| 10 | test | 8 | 10 | 281 | 102,409 | 14,092 |
| 11 | dev | 5 | 5 | 283 | 107,467 | 9,431 |
| 12 | test | 4 | 4 | 204 | 110,797 | 8,177 |
| 13 | dev | 7 | 7 | 179 | 113,699 | 6,520 |
| 14 | test | 9 | 11 | 217 | 115,993 | 7,939 |
| 15 | dev | 10 | 12 | 270 | 118,675 | 9,645 |
| 16 | test | 8 | 9 | 195 | 122,064 | 8,128 |

Turns 1–8 average 14.1 calls and 19.4 reads; turns 9–16 average 7.0 calls and 8.1 reads. The
late-turn floor — a participant that raises little still spends 4–10 calls — is the cost of
orienting a memoryless agent, and it is the floor the two options attack from different sides.

**Repeated reads.** Files read by at least 8 of the 21 sub-agents: `.claude/hooks/check-autoflow-gate.sh`
(14), `.autoflow/issue-2-ledger.md` (13), `.autoflow/.gitkeep` (12), `scripts/cleanup/cleanup-issue.sh`
(10), `docs/autoflow-guide.md` (9). Every participant verified the same files again because it
had no memory of the previous participant having done so.

**Where the wait goes.** In the 61 calls whose final usage record survived, the estimated hidden
thinking tokens correlate 0.82 with the wait before the first visible block, at 66–116 tokens/s
(issue #177 body, `think.py`). No Bash command, hook or retry stands out as a cause: tool
execution is 3% of in-agent time.

**Effort is a multiplier; the call count is the base.** A scan of the 155 recorded workflow
runs on this machine (`scanruns.py`, same grouping) shows the `xhigh` ARCHITECT runs of
2026-09-02 to 09-05 at 416–575 calls and 101–136 min, and the `medium`-effort runs of 2026-08-22
to 08-24 at 100–270 calls and 20–60 min per run (issue #177 body). Lowering effort shortens each
call; it does not remove calls. This review holds effort fixed and treats the effort row of
`.claude/autoflow/spawn-policy.json` as the operator's separate, target-owned lever (ADR-0023 >
Alternatives).

### 1.3 Method (so the numbers re-derive)

Per agent transcript, keep `assistant` and `user` records; one API call = one distinct
`requestId` among the assistant records; a turn's `first_in` = `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`
of its first assistant record; tool calls = `tool_use` blocks by `name`; wall = last minus first
record timestamp; model generation time = per-call span from the preceding `user` record to the
call's last record; tool execution = span from a `tool_use` record to the next `user` record. The
scripts that produced §1 (`apicalls.py`, `reads.py`, `think.py`, `scanruns.py`) lived in the
measuring session's scratchpad and are not in the repository; the pilot (§5) commits an
equivalent under `scripts/` so the metric is reproducible.

---

## 2. Constraints — measured 2026-09-05 on Claude Code 2.1.260

1. **A persistent participant cannot live inside a `Workflow`.** `agent()` is one-shot: the
   workflow reference documents no resume, continuation or wake for an in-script sub-agent, and
   the runtime replays a relaunched run by re-issuing `agent()` calls
   (<https://code.claude.com/docs/en/workflows> > Resume after a pause). Persistence exists only
   outside the workflow.
2. **Only the orchestrator can relay persistent participants.** A sub-agent that spawned and woke
   a named agent received nothing back: all three replies arrived in the parent session's main
   loop as idle notifications, and the sub-agent had no `ListAgents` to poll with (one probe,
   three wakes). The peer-facilitator shape issue #52 left "reopened" does not become executable
   this way either.
3. **Persistence buys no cache.** Waking a named agent 10 s and then 50 s after it went idle read
   22,312 tokens from cache both times and re-wrote the remaining ≈ 29K; a one-shot workflow
   sub-agent's first call in the same session read 21,202 — the same static prefix (§1.1). The
   47% of the prefix that ADR-0017 > Notes > C8 counted as "saved on a warm wake" is the part a
   fresh spawn also gets from cache. Recorded upstream at
   <https://github.com/anthropics/claude-code/issues/91971#issuecomment-5545302645>. The only
   gain persistence can deliver is **fewer calls** — no re-reading, shorter messages — and that is
   what §4 estimates.
4. **Documentary, not measured — an anonymous sub-agent is resumable by agent ID.** "Resumed
   subagents retain their full conversation history … Claude uses the `SendMessage` tool with the
   agent's ID or name as the `to` field to resume it. `SendMessage` doesn't require agent teams to
   be enabled … A completed subagent that receives a `SendMessage` auto-resumes in the background
   without a new `Agent` invocation" (<https://code.claude.com/docs/en/sub-agents> > Resume
   subagents). The gate hook keys its denial on the presence of `name` alone and states that
   resuming an anonymous spawn by raw agent ID is outside its surface
   (`.claude/hooks/check-autoflow-gate.sh:638-640`). Whether the resumed spawn's final text
   reaches the orchestrator as a task notification the way a named spawn's does (issue #168:
   3/3 in the `result` field) has **not** been measured; §5 makes it the pilot's step 0.

Also on record: with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — set in this repository's
`.claude/settings.local.json` — a named spawn launches as an in-process teammate, and
"`/resume` and `/rewind` do not restore in-process teammates"
(<https://code.claude.com/docs/en/agent-teams> > Limitations). A sub-agent transcript, by
contrast, "persist[s] within their session" and can be resumed after restarting Claude Code by
resuming the same session (sub-agents doc, same section).

---

## 3. Cause — two rules that compound

The call count is the product of two rules, each reasonable alone:

- **No memory.** Each turn is a new agent whose only memory is the transcript it is handed
  (`architect-deliberation.js:6-7`, deliberately — the #166 form).
- **VERIFY reads, memory is not enough.** The Discussion Protocol's step 2 — "actually **read**
  the relevant source files, schemas, and config. Memory alone is not enough"
  (`docs/teammate-common-rules.md` > Discussion Protocol) — applied to that memoryless agent means
  every turn re-verifies everything the transcript asserts before it can respond.

The re-verification is then narrated in the message (7K–15K characters), and the longer message
enlarges the next turn's uncached prompt — the self-reinforcing loop §1.2 shows in `first_in`.
Option A removes the first rule's effect; option B narrows the second rule's scope.

---

## 4. Options

### Option A — persistent participants, relayed by the orchestrator

The Developer AI and the Test AI are spawned once. Each turn, the orchestrator wakes one
participant; the participant appends its turn to a transcript file
(`.autoflow/issue-{N}-architect-transcript.md`) and ends with one line — turn number and whether
it has anything further to raise. The orchestrator wakes the other side, and the discussion ends
when two consecutive turns both say nothing further (#166 unchanged). Reports, scribe and ledger
are unchanged in substance; they take the transcript file as input instead of a script variable
(they can remain a small `Workflow`, given the transcript path, or run as direct spawns).

Two realizations, which differ only in how the participant is addressed:

- **A1 — named spawn.** `Agent(name: …)`; wake by `SendMessage(to: name)`. Under this
  repository's agent-teams setting the participant is an in-process teammate. Needs an exception
  in the hook's `resolve_spawn_role` (a name-carrying payload is denied while a cycle is active)
  and a partial supersede of ADR-0017 Q3's single declaration channel.
- **A2 — anonymous spawn resumed by agent ID.** `Agent(subagent_type: …)` with no `name`; the
  orchestrator keeps the agent ID the spawn returns and wakes by `SendMessage(to: <agentId>)`.
  The hook is untouched; `subagent_type` stays the sole declaration channel; the participant is a
  sub-agent, not a teammate, so no agent-teams flag is involved. Its delivery path is the
  unmeasured constraint 4.

**Isolation under A.** The turn's content goes to the file; only the one-line final text reaches
the orchestrator — as the wake's task notification `result`, which is exactly the channel issue
#168 measured. The isolation therefore holds by the participant's prompt discipline: a
participant that ends with a paragraph instead of a line puts discussion prose into the
orchestrator's context, which is the contamination Decision 8 exists to prevent. Nothing
structural enforces the line.

**Enforceability under A.** Relay order and the two-consecutive-`done` end move from the
workflow loop into an orchestrator procedure. A small decidable-state script (read the transcript
file, print the next side and whether the discussion has ended) keeps the *computation* in code;
obeying it stays in prose. This is the one remaining ground on which Decision 8 chose the
`Workflow` over a peer facilitator.

**Orchestrator cost under A.** Every wake ends in a notification the orchestrator answers with
the next wake — one orchestrator turn per participant turn (16–18 for a run like §1), each a
main-loop call over the session's full context (cache-read-dominated; ADR-0017 > Notes > C8
priced 81 such "no action" turns at $22 across two sessions).

### Option B — per-turn respawn kept; verification scope over the transcript

The script is unchanged. One sentence in the Discussion Protocol's VERIFY step, mirrored in the
turn prompt's `TURN_RULE`, states what the transcript already establishes: *a fact the transcript
cites with a `path:line` (or a command and its output) is verified for both participants; a
participant reads a file to ground a claim it is making or to dispute a cited one.* A new agent
still reads the transcript (one call) and still reads for what it wants to assert; it stops
re-deriving what the other side already anchored.

This is a scope statement on an existing rule, not a new check, cap or judgment — it does not
re-enter the class of additions #166 removed. It changes no spawn mode, no hook, no ADR and no
realization of Decision 8.

### Not exclusive

B applies under A as well: a persistent participant that re-reads what it already read is the
same waste. B is therefore the first step under either decision, and the pilot measures A's
*additional* effect on top of B.

---

## 5. Comparison

Estimates are projections from §1.2 and are replaced by the pilot's measurement (§6); they are
not acceptance thresholds.

| Axis | Baseline (§1) | B — scope over the transcript | A2 — persistent, anonymous, relayed | A1 — persistent, named |
|---|---|---|---|---|
| Calls per turn | 10.6 mean (14.1 early, 7.0 late) | ≈ 5–7: reads only for the turn's own claims and disputes; the late-turn floor is the guide | ≈ 2–4: a participant reads a file once for the whole discussion | same as A2 |
| Calls per run (16 turns + 26 fixed) | 195 | ≈ 105–135 (−30…−45%) | ≈ 60–90 sub-agent calls (−55…−70%) **plus** 16–18 orchestrator relay turns | same as A2 |
| Wall clock | 93 min | ≈ 55–70 min (fewer calls; shorter messages shorten each call's output) | ≈ 40–55 min in-agent, plus relay latency per wake | same as A2 |
| Uncached prompt per turn | 58K → 122K written once per turn | same growth, slower (shorter messages) | each wake re-writes everything past the 22K static prefix — the participant's own context (both sides' messages **and** its tool outputs), so per-wake writes are ≥ B's per-turn writes | same as A2 |
| Tokens | ≈ 2.6M | fewer cached reads and shorter outputs; writes ≈ unchanged | fewer cached reads; writes ≈ unchanged or larger; net direction not decidable from §1 — pilot measures | same as A2 |
| Isolation (Decision 8) | structural — `Workflow` returns one object | unchanged | prose — one-line final text; no structural guarantee | same as A2 |
| Relay order / termination | in code (workflow loop) | unchanged | orchestrator procedure + state script; obeyed in prose | same as A2 |
| Declaration channel / hook | `subagent_type`; name-carrying payload denied | unchanged | unchanged — `subagent_type` at spawn, resume by agent ID (outside the hook's surface, by its own text) | hook exception for a named participant; ADR-0017 Q3 partially superseded |
| Runtime dependencies | `Workflow` prerequisites (v2.1.154+, dynamic workflows on) | unchanged | `SendMessage` resume of a completed sub-agent; auto-resume in background; delivery path **unmeasured** (constraint 4) | agent-teams experimental flag; in-process teammates are not restored by `/resume` |
| Observability | `/workflows` progress view, run-level resume, script-held transcript | unchanged | lost — replaced by the transcript file and the orchestrator's task list | same as A2 |
| Documents / code touched | — | one protocol sentence, `TURN_RULE`, manifest hashes | CLAUDE.md > Deliberation Isolation `[MUST]` (Workflow as realization), > Spawn mode table (a within-phase row); `docs/teammate-contracts.md` > Facilitator > Realization; Decision 8's realization paragraph; `docs/autoflow-guide.md` > ARCHITECT (relay procedure); spawn-policy keys for the two participants; a relay-state script; participant agent definition; tests (`test/workflows/run.mjs` ARCHITECT section, harness); manifest | A2's list plus the hook branch and ADR-0017 Q3 |
| Failure modes introduced | — | a participant that over-trusts a wrong citation (the other side disputes it by reading — the protocol's "re-raise until resolved") | a leaked long final text; a mis-ordered wake; a session restart mid-discussion (resumable by resuming the session) | A2's plus teammate loss on `/resume` |

**Reading.** B removes roughly the re-verification half of the cost at no structural price. A
removes more of the per-turn floor, at the price of moving isolation and relay order from code to
procedure, adding an orchestrator turn per participant turn, and — for A1 only — re-opening the
declaration channel and the hook. A2 dominates A1: the same mechanics, none of the policy churn,
no dependence on the experimental flag. Constraint 3 rules out the cache axis for A entirely;
its case rests on the call count, which is what the measurement in §6 records. The operator's
decision on this comparison is in §7.

---

## 6. Pilot design — run as the effect record (operator decision, §7)

This section was written as the gate on adopting A2. The operator decided on 2026-09-05 to
proceed with the relay directly (§7, ADR-0023 D2), so the design below is kept as the
**effect record** of the change — the issue #146 form — with step 0 as an implementation
precondition rather than a decision gate.

**Arms.** Arm 0 — the script at HEAD (control). Arm A2 — persistent anonymous participants
relayed by the orchestrator, carrying the VERIFY-scope sentence (option B) in their prompt.
Arm B alone (the one-shot script with the sentence) is optional: it isolates the sentence's
share of the effect and is worth one run if the operator wants that split. A1 is not run.

**Step 0 (before the relay is implemented).** One anonymous `general-purpose` spawn on a small model, outside any
cycle, told to end with a nonce and call no tool; resume it twice by agent ID with a new nonce
each time; record whether each reply reaches the orchestrator as a task notification carrying
the text — the issue #168 procedure (`tests/manual/issue-42-manual-scenarios.md` > M1) with the
name replaced by the ID. A miss means A2 has no delivery path; the pilot stops at arm B.

**Target and controls.** The 2026-09-05 input (issue #2's `.autoflow/issue-2-*.md`) was not
preserved after the session, so the baseline is **produced in-cycle, not retrieved** — the
ADR-0021 method: every arm runs on the same frozen input (copy the issue's `phase-a`, `phase-b`
and ledger into a fixture directory before the first arm), the same tree SHA, the same
spawn-policy rows (model and effort), the same Claude Code version, on the same day,
**sequentially** (a concurrent run would share the prompt-cache prefix and the CPU cap). The
target is the next issue that reaches ARCHITECT, or issue #2 re-derived through DIAGNOSE.

**Metrics** (aggregation committed under `scripts/`, §1.3 method):

| Metric | Definition | Arm A2 addition |
|---|---|---|
| Calls | distinct `requestId` per sub-agent transcript, summed | plus the orchestrator's relay turns, counted separately from the session transcript |
| Reads | `Bash` `tool_use` count; the paths read by ≥ 8 agents | per participant across the whole discussion |
| Wall clock | first to last record, split Discuss / Report+Record | plus wake-to-notification latency per turn |
| Tokens | `cache_creation`, `cache_read`, `output` summed from `message.usage`, de-duplicated by `message.id` keeping the largest output (ADR-0017 C8 method) | the relay turns' usage from the session transcript |
| Prompt growth | `first_in` per turn | per-wake `cache_creation` per turn |
| Message length | characters of each turn message | same, from the transcript file |
| Outcome | turns, agreed / un-agreed counts, GATE:PLAN score of the resulting design from a fresh evaluator per arm | same |
| Isolation | — | the orchestrator's session transcript contains no turn-message text (grep each turn's first 200 characters against it) |

**Judgment.** The operator reads the direction and size of the before/after contrast — no fixed
cutoff, the issue #146 precedent. Two findings are defects to fix in the relay before it is used
in a cycle, not adoption gates: a design that FAILs GATE:PLAN where the control PASSes, and an
isolation check that finds turn text in the orchestrator's transcript. The record, with the
Claude Code version it ran on, is appended to ADR-0023.

---

## 7. Conclusion and follow-on scope

**Review's recommendation.** Adopt B now; treat A as re-opened but not adopted — the standing
Decision 8 gives the peer facilitator — with A2 admitted to a pilot and A1 rejected (§5).

**Operator decision (2026-09-05, issue #177 session).** The relay is adopted directly: the two
participants stay alive for the discussion and the orchestrator wakes them in turn. The review's
pilot gate is not taken; §6 runs as the effect record. B's sentence is carried into the
participants' prompt. The A2 realization (anonymous, resumed by agent ID) is the primary form and
A1 the fallback if step 0 fails. The sub-agent cache-TTL question is parked for a separate
discussion after this issue closes. Recorded as ADR-0023 (Accepted).

Implementation is not this issue's; it is one follow-on issue with the following scope.

**Follow-on issue — orchestrator-relayed persistent participants for ARCHITECT.**
- Step 0 delivery probe (§6) recorded with the Claude Code version; on a miss, the A1 fallback
  (hook `resolve_spawn_role` exception for the two participants, ADR-0017 Q3 partial supersede
  noted in ADR-0023).
- Participant spawn: `subagent_type: autoflow-planner` (the planning role, gated on
  GATE:HYPOTHESIS, which ARCHITECT already satisfies), model from a new spawn-policy phase key
  per participant; `.claude/agents/autoflow-planner.md` amended for the relay prompt — the fixed
  role prompt, the topic once, the VERIFY-scope sentence (option B), "append your turn to the
  transcript file, end with one line".
- Transcript file grammar (`.autoflow/issue-{N}-architect-transcript.md`, one `### Turn n — side`
  block per turn) and a relay-state script under `scripts/` (prints the next side and whether
  the discussion has ended: two consecutive "nothing further").
- Orchestrator procedure in `docs/autoflow-guide.md` > ARCHITECT: spawn both, wake by agent ID in
  alternation, wait by ending the turn (Wait discipline), read only the one-line notification,
  run the state script, stop at the end condition; reports, scribe and ledger from the
  transcript file (kept as a reduced `Workflow` given the path, or direct spawns).
- Rules and records: `CLAUDE.md` > Deliberation Isolation (the `Workflow` `[MUST]` names the
  relay as the ARCHITECT realization; the nested-team rejection stands) and > Spawn mode by role
  lifetime (a within-ARCHITECT row); `docs/teammate-contracts.md` > Facilitator > Realization and
  Return Contract; `docs/design-rationale.md` > Decision 8's realization paragraph;
  `docs/teammate-common-rules.md` > Discussion Protocol step 2 (the scope sentence).
- Tests: `test/workflows/run.mjs` ARCHITECT section and `tests/lib/architect-turn-harness.mjs`
  retired or re-pointed; a hermetic test of the relay-state script; manifest regenerated.
- Effect record (§6): the aggregation script committed under `scripts/`; arms 0 and A2 (B
  optional) on one frozen input; the record appended to ADR-0023.

**Out of scope.** The VERIFY cause-branch workflow (a single self-check round, no relay); every
other role's lifetime (the single-mode rule stands for them); the hook's name denial (unchanged
under A2); the effort row of the spawn policy (target-owned, the operator's lever); the sub-agent
cache TTL (separate discussion after this issue).
