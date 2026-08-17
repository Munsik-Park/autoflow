# Issue #56 — Manual/Environment-Dependent Verification Scenarios

These acceptance criteria are **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `56-AC*`), `test/workflows/run.mjs`, or
`tests/test-issue-56-carry-evidence-discipline.sh` — they depend on a live opus
sub-agent's response to prompt text, which is non-deterministic and has no
deterministic oracle. Delegated per the verification design
(`.autoflow/issue-56-verification-design.md` §2, §3): the automated acceptance
criteria verify the **channel** (the discipline text is constructed, symmetric,
conditional where it should be, and delivered) — the maximum deterministic
coverage available for a prompt-text change. The **outcome** — whether the
discipline actually stops a sub-agent from raising a stale counter — is delegated
here.

**Coverage boundary, stated plainly.** M1/M2 below are the sole carriers of the
issue's behavioral claim (Phase 3: the cost of a stale counter in a live ARCHITECT
round). This contact point is not a triggered composition contact point
(verification design §4: the intersecting elements are the file and the manifest
row, both of which have non-mock oracles — see `tests/test-issue-56-carry-evidence-discipline.sh`
AC-56-9/10), so a manual scenario with a stated reason is acceptable here per
`docs/autoflow-guide.md` > ARCHITECT > Testability-driven design.

---

## M1 — Live-cycle citation discipline (Tier 3, environment-dependent)

**Source AC:** AC-56-13 — behavioral: in a real ARCHITECT run, a round-N+1 counter
that would have been stale is either dropped at authoring time or carries a
`path:line` citation to the current file.

**Why not automated:** requires a live opus sub-agent exchange across ARCHITECT
Converge rounds; the mock runtime (`test/workflows/run.mjs`) stubs the counterparty
`agent()` calls, so it can prove the prompt carries the discipline text but cannot
prove a real model obeys it.

**Steps:**

1. Run one real `architect-deliberation` on a live issue:
   `Workflow({ name: "architect-deliberation", args: { issue: "N" } })`.
2. Let the deliberation reach round ≥ 3 (so at least one counter has been carried
   across at least one round boundary).
3. For every entry in `counters[]` returned at round ≥ 2, record:
   (a) whether the entry cites a `path:line` in the counterpart document, or
       names the section where the missing content would belong (the absence-case
       escape, A7);
   (b) whether the entry is a verbatim or near-verbatim repeat of a prior round's
       counter with no new citation.

**Pass condition:** every `counters[]` entry from round ≥ 2 either cites a
`path:line` (or, for an absence-case counter, names the target section) or is not
re-raised from a prior round.

---

## M2 — Stale-carry probe (Tier 3, environment-dependent)

**Source AC:** AC-56-13 (same source AC as M1 — the drop/dismiss half of the
behavioral claim, R1's specific complaint: carried text reads as current after the
counterpart has already edited it).

**Why not automated:** requires observing a real sub-agent's response to a document
that changed underneath a carried counter — the exact non-deterministic judgment
call the discipline text is meant to induce.

**Steps:**

1. During the same or a separate live `architect-deliberation` run, identify a round
   where one side raises a counter and the counterpart's next-round edit
   (`UPDATE ${feature}` / `UPDATE ${verif}` in place) demonstrably resolves it —
   confirm by diffing the artifact file between the two rounds.
2. Observe the following round's response from the side that originally raised the
   counter.

**Pass condition:** the counter is dropped (not repeated) or explicitly
acknowledged as resolved, citing the counterpart's edit; it is not re-argued
against the pre-edit form of the document.

---

## M3 — Live-runtime smoke (reused, not new)

**Source AC:** none directly — a parse/runtime-error fence for the template-literal
edit itself, distinct from the behavioral claim M1/M2 carry.

**Why not automated in this file:** `node --check` (AC-27-20d in
`tests/test-issue-27-composition-oracle.sh`, the standing home for this harness
measurement per `docs/doc-invariant-registry.md` §12.1 — AC-56-8's own
branch-scoped copy was retired in #107) covers the parse; only a real Workflow
invocation covers the runtime.

**Steps:**

1. Invoke `Workflow({ name: "architect-deliberation", args: { issue: "N" } })`
   after the GREEN edit lands.
2. Confirm it reaches its first `agent()` call without a runtime error.

**Pass condition:** no runtime error; `phase('Draft')` observed.

---

## Note on scope

M1/M2/M3 are the only scenarios for this issue — the automated acceptance criteria
(AC-56-1a through AC-56-15a) cover every deterministic dimension of the change
(verification design §1). No composition contact point in this cycle is discharged
by a manual scenario: `T ∩ S = {T1, T2}` (the file, the manifest row) is covered by
real-execution oracles (O1/O2/O3, verification design §4), and AC-56-13's manual
delegation sits outside that intersection.
