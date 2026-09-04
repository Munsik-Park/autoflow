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
*gate hook* classifies both channels identically regardless of the document's
contract (`H42-BEHAVIOR-EQ`). Neither proves that an **actual** anonymous
direct spawn's final turn text really does reach the orchestrator as a tool
return value, or that an **actual** named team spawn's final turn text really
is discarded unless delivered via `SendMessage`. That behavioral claim is
this file's M1.

---

## M1 — AC4 residual: anonymous direct vs. named team spawn, actual final-text delivery (Tier 3)

**Source AC:** AC4 (`docs/teammate-common-rules.md` > Result delivery path by
spawn mode) — the document states the delivery-path difference as an
*observed, harness-dependent* fact (`42-AC4-evidence-anchor`, citing the #40
cycle's 12/12 observation), not a guaranteed one. This scenario is how a
future session re-derives that observation instead of trusting a document
that could go stale if the runtime changes.

**Why not automated:** whether a spawned subagent's final response text
reaches the orchestrator's context, and by what path, is a property of the
Claude Code Agent Teams runtime — outside this repository's control and not
exercised by any script here. `H42-BEHAVIOR-EQ` proves the **gate hook**
treats both channels alike; it says nothing about **message delivery**, which
is a different subsystem (PreToolUse hook vs. teammate mailbox routing).

**Steps:**

1. During a live AutoFlow cycle, spawn one **anonymous direct** subagent (an
   `Agent` call with `subagent_type` set and no `team_name`/`name` — e.g. a
   DIAGNOSE Phase A/B/3 spawn, or an `autoflow-evaluator` spawn) that ends by
   returning a short, distinctive final message (e.g. a one-line summary
   containing a nonce string).
2. Confirm the nonce string appears in the orchestrator's context as the
   tool's own return value (synchronous) or as a task-completion notification
   (if backgrounded) — with **no** `SendMessage` call from that subagent.
3. During the same or a later cycle, spawn one **named team** teammate (an
   `Agent` call with `team_name` + a role-prefixed `name`, e.g. `test-42` or
   `impl-42`) and have it end its turn with a distinctive final message
   **without** calling `SendMessage`.
4. Record whether that final message text appears in the orchestrator's
   context, and by what path. This is the **version-dependent** step: on the
   #40 runtime it was silently discarded (`42-AC4-named-loss`); on 2.1.260 it
   arrived in the teammate's `idle_notification` `result` field (see **Data
   points** below).
5. Re-spawn the same named teammate (or address it via `SendMessage`) and
   have it explicitly call `SendMessage(to: "main", message: ...)` carrying
   the same nonce. Confirm the nonce now **does** appear in the
   orchestrator's context, delivered as a `SendMessage`-injected turn, not as
   the spawn's return value.
6. Record the outcome (pass/fail per direction) as a new data point alongside
   the #40-cycle 12/12 observation already cited in
   `docs/teammate-common-rules.md` — if step 2 or step 4 disagrees with the
   documented behavior, the document's evidence-anchor sentence
   (`42-AC4-evidence-anchor`) needs a follow-up correction, not this test.

**Pass condition:** anonymous-direct final text is observed to reach the
orchestrator without a `SendMessage` call (step 2), and the named-team
direction (steps 4–5) is recorded as a dated, versioned data point in
`docs/teammate-common-rules.md` > Result delivery path by spawn mode. The
scenario no longer asserts the asymmetry: since 2.1.260 the named-mode rule
rests on cost and consistency (ADR-0017 C8, ADR-0021 C7), not on the loss.

**Data points:**

| Runtime | Date | Named final text without `SendMessage` | Source |
|---|---|---|---|
| Agent Teams runtime of the #40 cycle | 2026-07-31 | lost, 12/12 matched the `SendMessage` count | issue #40 |
| Claude Code 2.1.260 | 2026-09-04 | delivered, 3/3, in the `idle_notification` `result` field | issue #168 |

**Non-goal:** this scenario does not test whether the Agent Teams runtime
*should* behave this way, only whether the current runtime *does* — matching
the document's own "observed, not guaranteed" framing.
