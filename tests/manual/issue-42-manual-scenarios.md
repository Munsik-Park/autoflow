# Issue #42 — Manual/Environment-Dependent Verification Scenarios (Tier-2/Tier-3)

This acceptance criterion is **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `42-AC*`) or
`tests/test-issue-223-schema-hook-contract.sh` (`H42-BEHAVIOR-EQ`) — it is a claim
about live Claude Code Agent Teams runtime behavior, not about document text or
hook logic, and is not reproducible in CI (verification design
`.autoflow/issue-42-verification-design.md` §5-D4, §7 non-goals: "Agent Teams
runtime의 메시지 전달 자체를 테스트하지 않는다 → L3").

**Coverage boundary, stated plainly.** Automated coverage for #42 proves the
*document* correctly and consistently states which spawn mode each role uses
and where its final text lands (registry STATE assertions), and proves the
*gate hook* denies a `name`-carrying payload inside an active cycle
regardless of its prefix or `subagent_type` (`H42-BEHAVIOR-EQ`, post-migration
form). Neither proves that an **actual** anonymous direct spawn's final turn
text really does reach the orchestrator as a tool return value, or *where* an
**actual** named spawn's final turn text lands on the runtime in use — a fact
that has already changed once (lost on the #40 runtime unless delivered via
`SendMessage`; delivered in the idle notification's `result` field on 2.1.260,
issue #168). Those runtime-behavioral observations are this file's M1.

---

## M1 — AC4 residual: anonymous direct vs. named team spawn, actual final-text delivery (Tier 3)

**Source AC:** AC4 (`docs/teammate-common-rules.md` > Result delivery path by
spawn mode) — the document records where each spawn mode's final text lands
as an *observed, runtime-version-dependent* fact (`42-AC4-evidence-anchor`):
dated data points (the #40 cycle's 12/12 loss; the 2.1.260 3/3 delivery,
issue #168), never a guarantee. This scenario is how a future session
re-derives the observation on the runtime it is running, and adds the next
data point, instead of trusting a record that goes stale when the runtime
changes. The single-mode rule itself does not rest on this observation — its
grounds are cost and consistency (that section's grounds table).

**Why not automated:** whether a spawned subagent's final response text
reaches the orchestrator's context, and by what path, is a property of the
Claude Code runtime — outside this repository's control and not exercised by
any script here. `H42-BEHAVIOR-EQ` proves what the **gate hook** does with a
`name`-carrying payload inside a cycle; it says nothing about **message
delivery**, which is a different subsystem (PreToolUse hook vs. the runtime's
notification routing).

**Steps:**

1. During a live AutoFlow cycle, spawn one **anonymous direct** subagent (an
   `Agent` call with `subagent_type` set and no `team_name`/`name` — e.g. a
   DIAGNOSE Phase A/B/3 spawn, or an `autoflow-evaluator` spawn) that ends by
   returning a short, distinctive final message (e.g. a one-line summary
   containing a nonce string).
2. Confirm the nonce string appears in the orchestrator's context as the
   tool's own return value (synchronous) or as a task-completion notification
   (if backgrounded) — with **no** `SendMessage` call from that subagent.
3. **Outside any active cycle** — no `.autoflow/issue-*.json` reads
   `active:true`; inside one the hook denies every `name`-carrying spawn
   (`resolve_spawn_role`), so this step cannot run there — spawn one
   **named** subagent: an `Agent` call with `name` set (e.g. `probe-<issue>`),
   an explicit `model`, and any `subagent_type` (`team_name` is deprecated
   and ignored on current runtimes). Have it end its turn with a distinctive
   final message **without** calling `SendMessage`.
4. Record whether that final message text appears in the orchestrator's
   context, and by what path. This is the **version-dependent** step: on the
   #40 runtime it was silently discarded (`42-AC4-named-loss`); on 2.1.260 it
   arrived in the teammate's `idle_notification` `result` field (see **Data
   points** below).
5. Re-wake the same named subagent with `SendMessage(to: "<name>")` carrying
   a new nonce, twice — once inside the prompt-cache TTL and once past it —
   and record for each wake (a) whether and how the nonce reaches the
   orchestrator, and (b) the wake's `cache_read_input_tokens` /
   `cache_creation_input_tokens` from the subagent's transcript
   (`~/.claude/projects/<project>/<session>/subagents/agent-*.jsonl`,
   `message.usage`, de-duplicated by `message.id` — the aggregation in
   ADR-0017 > Notes > C8). The second fact is the per-wake cost of a
   persistent participant, which the #166 addendum asks for in the same
   experiment. On a runtime that loses the final text (the #40 direction),
   additionally have the subagent call `SendMessage(to: "main")` with the
   nonce and confirm that path delivers.
6. Record the outcome as a dated, versioned data point — runtime version,
   date, delivery direction and path, wake usage — in the **Data points**
   table below and in `docs/teammate-common-rules.md` > Result delivery path
   by spawn mode. A direction that differs from the latest data point there
   means that document's measurement paragraph needs a follow-up correction,
   not this test; the rule's grounds (cost, consistency) are re-examined only
   if the wake cost also changes.

**Pass condition:** anonymous-direct final text is observed to reach the
orchestrator without a `SendMessage` call (step 2), and the named-team
direction (steps 4–5) is recorded as a dated, versioned data point in
`docs/teammate-common-rules.md` > Result delivery path by spawn mode. The
scenario no longer asserts the asymmetry: since 2.1.260 the named-mode rule
rests on cost and consistency (ADR-0017 C8, ADR-0021 C7), not on the loss.

**Data points:**

| Runtime | Date | Named final text without `SendMessage` | Per-wake prefix re-write | Source |
|---|---|---|---|---|
| Agent Teams runtime of the #40 cycle | 2026-07-31 | lost, 12/12 matched the `SendMessage` count | not measured per wake (cycle-level shares: ADR-0017 > Notes > C8) | issue #40 |
| Claude Code 2.1.260 | 2026-09-04 | delivered, 3/3, in the `idle_notification` `result` field | 53% warm (+57 s), 100% cold (+14 min 35 s) | issue #168 |

**Non-goal:** this scenario does not test whether the Agent Teams runtime
*should* behave this way, only whether the current runtime *does* — matching
the document's own "observed, not guaranteed" framing.
