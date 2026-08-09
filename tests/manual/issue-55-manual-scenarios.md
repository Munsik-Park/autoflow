# Issue #55 — Manual/Operator Verification Scenarios (Tier-3)

This is an **operator record**, not a verification path. It discharges the single
non-automated acceptance criterion of this cycle — **instruction-is-followed** — per
the untestable-item disposition in `.autoflow/issue-55-verification-design.md` Part 2:
"the sole non-automatable item... model behavior, not repository state... automation
covers the instruction's *correctness*, never its *adoption*."

---

## M1 — instruction-is-followed: an Evaluation-AI/orchestrator session writes the admitted shape (Part 1)

**What ships automatically.** `CLAUDE.md`'s Score-recording instruction (section
`AutoFlow State Tracking (Hook integration)`) now carries a machine-shaped,
marker-anchored JSON fence — the value of `phases.<gate>.scores` — verified
extractable and hook-admissible by `tests/test-issue-55-score-format-contract.sh`
(producer-shape a/a2/b/c). What that suite cannot verify is whether a future session
actually *follows* the revised instruction when hand-authoring a state file, as
opposed to reading only the old unattributed sentence from habit.

**Why not automated:** whether a future model session reads and follows a documented
instruction is a fact about that session's behavior, not a fact derivable from
repository state at any single point in time. The revised instruction's own
*correctness* — that it carries a parseable, hook-admissible example — is fully
covered by the automated `producer-shape` and `single-source` criteria; only its
*adoption* is out of automation's reach.

**Steps (operator or a future AutoFlow session, next time a gate score is recorded):**

1. Open `CLAUDE.md` > `AutoFlow State Tracking (Hook integration)` > "Score
   recording" and read only that instruction (do not consult
   `docs/evaluation-system.md` directly, to isolate what the producer-side
   instruction alone conveys).
2. Following the instruction as written, hand-author a `phases.<gate>.scores` object
   for a real or fixture gate evaluation.
3. Install the authored object into a `.autoflow/issue-{N}.json` state file and run
   `.claude/hooks/check-autoflow-gate.sh` against a score-gated command (e.g. a
   `git push` on a branch with `active:true` and the corresponding gate's scores
   populated).
4. **Observable outcome:** the hook admits the file (no `BLOCKED: malformed AutoFlow
   state file` diagnostic) — i.e. the shape the instruction led the author to write
   is exactly the shape the hook's admission validator accepts.

**Disposition record:** note in the cycle's HANDOFF report whether step 4 passed on
first attempt (instruction sufficient) or required a second read/correction
(instruction ambiguous, follow-up warranted) — this is the qualitative signal the
automated suite cannot produce.
