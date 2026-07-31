# Issue #43 — Manual/Environment-Dependent Verification Scenarios (Tier 3)

This acceptance criterion is **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `43-AC*`) or `tests/test-issue-43-report-channel-contract.sh` —
it is a claim about live Claude Code Agent Teams runtime behavior and about
orchestrator conduct, neither of which is document text or reproducible in CI
(verification design `.autoflow/issue-43-verification-design.md` §4, §7
non-goals: "Agent Teams 런타임의 메시지 전달 자체를 테스트하지 않는다 → L3").

**Coverage boundary, stated plainly.** Automated coverage for #43 proves the
*documents* state the reporting obligation in the named-role contracts
(`docs/teammate-contracts.md`) and state the `[DENY]` + idle-reading rules in
`CLAUDE.md` > Execution Principles. It does **not** prove any agent obeys
them. The issue's own evidence — `test-red-40` ended on final text *after
receiving an explicit "SendMessage to main" instruction* — is the standing
counterexample, and it is the reason this cycle's value is contract coverage,
not behavioral guarantee.

---

## M1 — the `summary` field as the delivery signal (Tier 3)

**Source AC**: AC2's second half (summary-absent ⇒ report not sent).

**Why not automated**: the presence/absence of a `summary: "[to main] …"`
field on a teammate idle notification is a property of the Claude Code Agent
Teams runtime, outside this repository and not exercised by any script here.
This is the same underlying harness surface `tests/manual/issue-42-manual-scenarios.md`
M1 already exercises (anonymous-direct vs. named-team final-text delivery);
rather than restate that procedure, this scenario **cites** it and adds only
the `summary`-field observation and the two documented recovery paths.

**Steps**:

1. Run `tests/manual/issue-42-manual-scenarios.md` M1 steps 1-5 (or reuse a
   recent live-cycle observation of the same asymmetry) to (re-)establish
   that a named team spawn's final turn text is discarded unless delivered
   via `SendMessage`.
2. During that same live cycle, capture the idle notification the runtime
   emits for a teammate that **did** call `SendMessage(to: "team-lead")` and
   for one that ended on final text only (no `SendMessage`). Confirm the
   `summary: "[to main] …"` field is **present** on the first notification and
   **absent** on the second.
3. For the no-`summary` case, exercise both documented recovery paths:
   (a) shell-verify the teammate's `.autoflow/*` artifact directly, and
   (b) re-request the report via `SendMessage`. Confirm each recovers the
   report content.
4. Record the outcome alongside the #40-cycle 12/12 observation cited in
   `docs/teammate-common-rules.md` — if the `summary` field's presence does
   not correlate with delivery, `CLAUDE.md` > Execution Principles'
   `43-AC2-summary-absent` clause needs a follow-up correction, not this
   scenario.

**Re-derivation cadence**: re-check whenever the delivery claim in
`docs/teammate-common-rules.md` is re-checked (shared runtime dependency —
one re-derivation session covers both #42 M1 and this M1).

**Pass condition**: a delivered report's idle notification carries a
`summary` field; an undelivered report's does not; both recovery paths (a)
and (b) succeed.

**Non-goal**: this scenario does not test whether the Agent Teams runtime
*should* behave this way, only whether the current runtime *does* —
"Observed, not guaranteed," matching `docs/teammate-common-rules.md`'s own
framing.

---

## M2 — the `[DENY]` rule's effect on orchestrator prompt authoring (Tier 3)

**Source AC**: AC2's first half (`[DENY]` on the "final message" idiom in a
named-spawn prompt).

**Why not automated**: whether a future orchestrator turn writes "return …
as your final message" into a named-spawn prompt is model conduct, not file
state. The automated registry entries (`43-AC2-deny-marker`,
`43-AC2-deny-scope`, `43-AC2-idiom-anon-only`) prove only that the **rule
exists and is scoped to named spawns**. `CLAUDE.md` > Spawn role declaration
bars closing this gap with a prompt-keyword hook — deliberately, to avoid the
training-evasion failure mode already on record — so no automated lane exists
for this half by design.

**Steps**:

1. During a live cycle, review each `Agent` spawn prompt authored for a
   named team spawn (`team_name` + role-prefixed `name` — Test AI, Developer
   AI) before it is sent.
2. Confirm the prompt states the delivery action as `SendMessage(to:
   "team-lead")` and does **not** instruct the teammate to return its result
   "as your final message" (the anonymous-direct idiom).
3. If a prompt is found to use the forbidden idiom, that is a conduct defect
   in the orchestrator's own prompt authoring, not a test failure to fix in
   this repository's test suite — record it against the orchestrator's
   session, not against #43's acceptance criteria.

**Coverage boundary, stated plainly**: this scenario cannot be automated and
its pass condition is not machine-checkable across sessions. Its value is
naming the residual risk explicitly: the rule's existence (proven by the
automated registry entries) does not guarantee compliance. The issue body's
own evidence — `test-red-40` ended on final text *after* receiving an
explicit "SendMessage to main" instruction — is the standing counterexample,
and is the reason this cycle's value is contract coverage, not a behavioral
guarantee.

**Non-goal**: adding a machine validator for prompt wording is out of scope —
barred by the declared-role rule (see verification design AC3 devil's-advocate
discussion, D1).
