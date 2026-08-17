# Issue #51 — Manual/Operator Verification Scenarios (Tier-3)

This is an **operator record**, not a verification path. It discharges the single
non-automated acceptance criterion of this cycle — **AC13** — per the untestable-item
disposition in `.autoflow/issue-51-verification-design.md` §3: "Exactly **one**
non-automated item, with a stated reason and a stated alternative: AC13 — the
`Proposed` → `Accepted` transition is an ownership decision, not a property of the
artifact; alternative M1."

---

## M1 — Owner confirmation of ADR-0017's `Status` transition (AC13, lane M)

**What ships automatically.** This cycle's decision record,
`docs/adr/0017-teammate-removal-feasibility.md`, ships with `## Status` reading
`Proposed` (mirroring `docs/adr/0003-autoflow-ends-at-handoff.md`, which is also
still `Proposed`).

**Why not automated:** whether the migration verdict recorded in ADR-0017 becomes
project policy is an ownership decision, not a fact derivable from repository state
— `docs/adr/README.md`'s Status Values section defines `Accepted` as "Confirmed as
project policy," a confirmation only the owner can make.

**The checklist entry must record that no automated lane obstructs the transition**
(verification design §7):

- `AC1(c)` admits all four `docs/adr/README.md` status values (`Proposed` /
  `Accepted` / `Deprecated` / `Superseded`) — accepting the ADR does not violate it.
- `AC1(d)`, which read only *this PR's own diff* of the `## Status` value, was
  retired in #107 — it was a dormant `dev/*-issue-51` branch gate over an
  already-merged cycle (`docs/doc-invariant-registry.md` §12.1). Its concern is
  moot for the same reason it was inert: an owner acceptance performed after this
  PR merged is a later PR's diff, not this one's.
- `AC7` and registry entry `51-reg-readme` grep the ADR's **filename** in
  `docs/adr/README.md` > Current Drafts, not the row's Status cell — the Status cell
  the owner's acceptance rewrites is untouched by that assertion.
- No `origin_issue: 51` registry entry (`tests/fixtures/doc-invariants.json`) anchors
  a `## Status` section — re-derived at RED: `jq '[.invariants[]|select(.origin_issue==51 and .section=="Status")]|length'` against the live registry returns `0`.

**Steps (operator, after this cycle's PR merges):**

1. Read `docs/adr/0017-teammate-removal-feasibility.md` in full — the verdict, the
   Q1–Q6 answers, and the ordered migration conditions (`C1`–`C8`).
2. Decide whether to accept the recorded verdict as project policy.
3. If accepting: edit `## Status` to `Accepted` (optionally with an owner-decision
   date, mirroring `docs/adr/0015-*.md`'s `Accepted (owner decision, 2026-07-05)`
   form) and update the `docs/adr/README.md` > Current Drafts row's Status cell to
   match.
4. If not accepting, or deferring: leave `Proposed` (or record the reason as a dated
   note under `## Notes`).
5. Confirm CI stays green after the edit — re-running
   `tests/test-issue-51-teammate-removal-verdict.sh` and
   `bash tests/run-doc-invariants.sh` locally is sufficient; per the grounds above,
   neither lane obstructs the transition.

**Pass condition:** the owner's decision is recorded in `## Status` (and, if
accepted, the README row), and no automated lane reds as a result of that edit
alone.

---

**Change-surface note.** This file is itself part of this cycle's change surface and
is registered by filename (alongside
`tests/test-issue-51-teammate-removal-verdict.sh`) at the **TAIL** of both the
`pull_request` and `push` `paths:` blocks in
`.github/workflows/e2e-dummy-target.yml` (AC12).
