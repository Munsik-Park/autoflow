# Issue #67 — Manual/Environment-Dependent Verification Scenarios

These two acceptance-adjacent outcomes are **not** covered by `test/workflows/run.mjs` or
`tests/test-issue-67-deliberation-record.sh` — both are model-behavior outcomes of a real
ARCHITECT deliberation, not script output the mock-runtime harness can observe. Delegated per the
verification design (`.autoflow/issue-67-verification-design.md` §2, rows `relitigation-actually-
prevented` and `document-stays-design-only`; §3 "Not automatable"): the automated lanes prove the
**mechanism** — the register persists a rejected/agreed entry, the ledger records it under
`ARCHITECT rejected`, the round prompts instruct disposal and no-relitigation, the design documents
receive `RECORD_DISCIPLINE_RULE` — never that a live sub-agent actually **obeys** the instruction.
That gap is exactly what these two scenarios exist to close, mirroring the boundary `#62` recorded
for its own outcome-level item (`tests/manual/issue-62-manual-scenarios.md`).

---

## M1 — Relitigation actually prevented (Tier 3, environment-dependent)

**Source AC:** `relitigation-actually-prevented` (verification design §2) / AC11 (ledger seed) +
AC10 (rejected authority) — a registered, rejected issue is not reopened by a **later**
deliberation without a newly verified fact.

**Why not automated:** `ledger-rejected-authority` (lane A) proves the ledger prompt names
authority `ARCHITECT rejected` and carries the rejected entry's four lines; `ledger-seed-rule-
drafts-only` (lane A) proves `LEDGER_SEED_RULE` instructs the Draft agents to read the ledger and
treat prior `ARCHITECT rejected` entries as non-reopenable. Neither proves the Test AI or
Developer AI sub-agent in a **subsequent, independent** deliberation actually honors that
instruction rather than re-raising the same point — that is a live model-behavior outcome across
two separate `architect-deliberation` Workflow invocations, which no mock-runtime fixture can
produce.

**Setup:**

1. Run one real `architect-deliberation` Workflow to `CONVERGED` on an issue whose design
   discussion produces at least one `rejected` register entry (a Test AI or Developer AI counter
   that the raiser ultimately rejects rather than resolves). Confirm the resulting
   `.autoflow/issue-{N}-ledger.md` carries that entry under authority `ARCHITECT rejected`.
2. On a **follow-up issue** whose design space plausibly touches the same concern (same file,
   same mechanism, or an explicit continuation), run a second real `architect-deliberation`
   Workflow that reads the same `.autoflow/issue-{N}-ledger.md` (per `LEDGER_SEED_RULE`'s Draft-
   time read instruction).

**Procedure:** Read the second deliberation's round-by-round transcript (or its Draft/round
prompts, if inspectable) and check whether the previously-rejected concern's **name** is re-raised
as a fresh open counter by either side, without citing a newly verified fact (a fact unavailable
when the original entry was rejected).

**Pass condition:** the previously-rejected name is either (a) not re-raised at all, or (b)
re-raised only with an explicit citation of a new, verified fact distinguishing it from the
original rejection — never re-raised as a bare restatement of the original concern.

**Fail:** the second deliberation re-raises the same name with no new grounds, i.e. the sub-agent
read the ledger-seed instruction (mechanically deliverable, per the automated lane) but did not
act on it.

---

## M2 — Design documents stay design-only, no round history, no tallies (Tier 3, environment-dependent)

**Source AC:** `document-stays-design-only` (verification design §2) / AC8 (transcription
mandate gone) + AC9 (readable naming, no tallies) — the produced Feature/Verification Design
Documents contain no per-round history section and no count/total statements.

**Why not automated:** the `RECORD_DISCIPLINE_RULE` lane-A test proves the instruction — "design
documents carry only the current design", "no totals or counts are written into the documents" —
reaches all four prompts. It does not prove the Developer AI or Test AI sub-agent actually writes
the resulting `.autoflow/issue-{N}-feature-design.md` / `-verification-design.md` that way; agent-
authored prose is not grep-checkable against "does this read as a round history" without a human
judgment call (a document could satisfy every doc-invariant/no-stale-literal check while still
reading as a change-log if the agent free-writes one under a heading the registry doesn't scope).

**Setup:** After the next real ARCHITECT deliberation converges (any issue after this cycle
lands, not necessarily #67 itself — this is a standing operator check, not a one-time regression),
open both produced design documents.

**Procedure:**

1. Confirm neither document contains a per-round history section (e.g. "Round 1:", "Round 2:",
   "Resolved this round" tables of the kind this issue's **own** feature/verification design used
   during its deliberation — those tables are the artifact of the OLD document-as-durable-channel
   practice this issue retires; a post-#67 document should not need them, since the register now
   carries that record).
2. Confirm neither document states a total or count (e.g. "N acceptance criteria", "M tests
   added", a tally of resolved vs. open concerns) as durable content — a one-off descriptive
   number in prose that is not tracking round-over-round state is not itself a violation; the
   distinguishing question is whether the number is *there to be updated next round* (a tally) or
   a plain factual statement.
3. Confirm every named concern in the document uses a short readable name, not a serial ID
   (`#1`, `C3`, etc.).

**Pass condition:** both documents read as a snapshot of the **current** design only — no
reader needs the round history to understand the current state, and no number in the document is
a running tally that the next round is expected to increment.

**Fail:** either document retains a per-round history section or a durable tally, indicating the
`RECORD_DISCIPLINE_RULE` instruction was delivered (mechanically proven) but not obeyed.
