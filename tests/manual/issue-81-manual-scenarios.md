# Issue #81 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

This is the **execution record** of the composition oracle for
**AC-REATTACH-PERMITTED** (`.autoflow/issue-81-verification-design.md` §
"Composition oracle determination"), not a manual-scenario substitute for it —
the same relation `docs/autoflow-guide.md` already uses when it walks the
INTEGRATE bundle's live effectiveness through
`tests/manual/issue-847-manual-scenarios.md`.

**Coverage boundary, stated plainly.** The automated lanes (new lanes in
`tests/test-issue-25-confirm-ci-green.sh`, and the `81-AC-*` entries in
`tests/fixtures/doc-invariants.json`) prove the mergeability tri-state
classifier and the *text* of the attach clause / re-review target set /
lifecycle description. None of that proves the attach command actually
succeeds when run **from inside the isolated reviewer subprocess** — the one
actor `.codex/review.md` § Review Method names as "the sole authorized
clearer" for this label. That live-runtime observation is this file's M1 and
M2.

**Ledger constraints this scenario honors** (`.autoflow/issue-81-ledger.md`
E19, carried constraint 2): the round-trip runs **only** against an **inert
scratch/draft PR** opened for the round-trip and closed after it — never a
`phase: "awaiting-external-review"` PR, even one belonging to a different,
already-handed-off issue. That PR is still a **live** merge signal
(`docs/external-review-sequencing.md:25` — the label is a live, human-honoured
signal on a PR awaiting external merge), so attaching `blocked-by-review` to
it inverts that PR's own termination/merge signal for the round-trip's
duration, and permanently if the teardown is interrupted — the same hazard
the constraint excludes for a PR belonging to a live cycle. No automated lane
in this repo stages this — the orchestrator's own Bash cannot perform the
teardown half at all (`.claude/hooks/check-autoflow-gate.sh:201` denies
`--remove-label blocked-by-review` unconditionally, independent of cycle
state or PR), so a probe run from the orchestrator would leave the label
attached mid-way with no recovery path outside the reviewer subprocess. Both
halves below run inside the reviewer subprocess.

---

## M1 — attach round-trip succeeds from the reviewer subprocess (positive case)

**Source AC:** AC-REATTACH-PERMITTED (verification design § "Composition
oracle determination"). Discharges the element `blocked-by-review` of `T ∩ S`
(ledger E11).

**PR selection (constraint above):** open a scratch draft PR against a
throwaway branch in the target repo (e.g. a one-line no-op commit on a
`scratch/issue-81-reattach-probe` branch) **solely** for this round-trip, and
close it once teardown (step 4) is confirmed. Do **not** reuse any pre-existing
PR — not one belonging to the cycle currently running #81, not one whose state
file reads `active: true`, and not a `phase: "awaiting-external-review"` PR
either (ledger E19 constraint 2: that PR is still awaiting a live external
merge decision, so it is not inert).

**Steps:**

1. Confirm the selected PR does **not** currently carry `blocked-by-review`
   (`gh pr view <N> --json labels`).
2. From inside the configured reviewer subprocess (the same isolated session
   `.codex/review.md` runs in — `scripts/review/codex-review-pr.sh --pr <N>
   [--repo <owner/name>]`, or a manual invocation of the same primary command
   the amended `.codex/review.md` attach clause prescribes), run the primary
   attach: `gh pr edit <N> --add-label blocked-by-review` (add `--repo
   <owner/name>` for a sub-repo PR).
3. Read back: `gh pr view <N> --json labels` and confirm `blocked-by-review`
   is present.
4. Teardown, from the **same** reviewer subprocess: run the existing removal
   clause of `.codex/review.md` (primary `gh pr edit <N> --remove-label
   blocked-by-review`, verified by a second `gh pr view <N> --json labels`
   read confirming absence) to restore the PR's prior label state.

**Pass condition:** step 2 exits 0 (or, on primary failure, the fallback `gh
issue edit <N> --add-label blocked-by-review` exits 0), step 3's read-back
shows the label present, and step 4's teardown removes it again — read back
confirmed absent before ending the scenario.

**Fail condition / signal to re-open:** the attach command is unavailable or
denied from inside the reviewer subprocess (permission-model regression — the
reviewer subprocess must retain `--add-label` authority the same way it
retains `--remove-label` authority today), or the read-back in step 3 shows
the label still absent after a reported "success" (a false-positive report,
masking the exact failure mode AC-REATTACH-PERMITTED exists to catch). Either
outcome blocks GATE:QUALITY for #81 until re-verified; file it as its own
issue rather than re-litigating this cycle's already-settled design.

---

## M2 — missing-label probe (negative case, `gh` surface behaviour half)

**Source AC:** AC-REATTACH-PERMITTED, negative case, discharge mechanism 1 of
2 (verification design § "Negative case — two predicates with different
discharge mechanisms"). Discharge mechanism 2 (the reporting instruction) is
**not** re-verified here — it is a static-text property already covered by
the `81-AC-ATTACH-CLAUSE-*` registry entries in
`tests/fixtures/doc-invariants.json`, and the design states explicitly that
this probe run cannot fail on it.

**Steps:**

1. From inside the same reviewer subprocess used in M1, choose a label name
   that exists in **no** repo reachable from this probe (e.g.
   `blocked-by-review-issue81-probe-nonexistent`) — a name distinct from the
   real gate label, so nothing about the real `blocked-by-review` label is
   touched.
2. Run the primary attach against that probe name: `gh pr edit <N> --add-label
   blocked-by-review-issue81-probe-nonexistent` (same `<N>` as M1, or any PR
   satisfying the same PR-selection constraint).
3. On primary failure, run the fallback: `gh issue edit <N> --add-label
   blocked-by-review-issue81-probe-nonexistent`.
4. Read back: `gh pr view <N> --json labels` and confirm the probe label name
   is **absent**.

**Pass condition:** both surfaces (step 2 and step 3) fail — neither silently
succeeds nor auto-creates the label — **and** the read-back in step 4 shows
the probe label absent. Nothing is created or deleted by this scenario, so the
target repo is left byte-identical (verified by a `gh label list` diff before
and after, or by the read-back alone being sufficient given no label-create
command is ever issued).

**Fail condition / signal to re-open:** either surface reports success on a
label name that exists in no repo, or auto-creates the label — this would
make the attach clause's fallback-then-report structure unreachable (a
"success" that silently invents a new label defeats the operator-setup-gap
report the clause exists to produce). File it as its own issue.

---

## M3 — live mergeability field round-trip (`mergeable` / `mergeStateStatus` vocabulary, no regression on a settled read)

**Source AC:** AC-LIVE-FIELD-VOCABULARY (`.autoflow/issue-81-verification-design.md`
§ "Acceptance criteria → verification type → method", cycle-2 row; § "Composition
oracle determination" — "Live mergeability round-trip"). Discharges the `mergeable` /
`mergeStateStatus` element of `T ∩ S` (ledger E53).

**Coverage boundary, stated plainly (verification design § "Testability
assessment").** A *genuinely transient* live `mergeStateStatus=UNKNOWN` cannot be
scheduled — it is GitHub-side, short-lived, and not inducible from this repository.
This scenario verifies the parts of the live contact point that **are** observable
on demand: field presence, enum vocabulary, and no regression on a settled read. The
transient unsettled window itself stays an unforced observation, recorded only when
it happens to be seen live — it is **not** a claim of coverage over that window.

**Read-only in both halves — no PR-selection constraint beyond "open".** Unlike
M1/M2, this scenario performs no write: `gh pr view` is a read, and
`scripts/handoff/confirm-ci-green.sh` is itself observe-only by contract (no merge,
no CI re-trigger, no label write — script header, `docs/autoflow-guide.md` step 5).
Any open PR may be used; prefer this issue's own PR (currently PR #82, a draft at
HANDOFF) so the observation is recorded against the surface it governs.

**Steps:**

1. `gh pr view <N> --json mergeable,mergeStateStatus` against the chosen open PR —
   the exact `--json` selector the script's own precheck call uses
   (`scripts/handoff/confirm-ci-green.sh:275`).
2. Confirm both `mergeable` and `mergeStateStatus` are returned **non-empty**.
3. Confirm the observed `mergeStateStatus` value is drawn from the documented enum
   (`CLEAN`, `DIRTY`, `UNKNOWN`, `BLOCKED`, `BEHIND`, `UNSTABLE`, `HAS_HOOKS`,
   `DRAFT` — script header tri-state comment block).
4. Run `scripts/handoff/confirm-ci-green.sh --pr <N>` against the same PR, with a
   small `CI_POLL_TIMEOUT_SECS` (e.g. `CI_POLL_TIMEOUT_SECS=30`) so a slow-CI wait
   does not extend this scenario.
5. If the read in step 1 was a settled state (any value other than `UNKNOWN`),
   confirm the script does **not** regress to exit `14` — a settled read must still
   reach its contracted verdict (`0` on an all-green rollup, or another non-`14`
   deadline code per the exit-code contract), never the "could not confirm mergeable"
   code on a PR whose mergeability was, in fact, settled.
6. If the read in step 1 happens to observe `mergeable=MERGEABLE` +
   `mergeStateStatus=UNKNOWN` (the unforced transient window — not scheduled, only
   recorded if seen), note it as a genuine live witness of the pairing this cycle's
   fix targets, and confirm the script does not exit `0` on that same read.

**Pass condition:** step 2 and step 3 hold for every run; step 5 holds whenever the
observed state is settled (the expected case, and sufficient for this scenario to
pass). Step 6 is opportunistic — its absence across a run is not a failure, only a
missed opportunity to witness the transient pairing live.

**Fail condition / signal to re-open:** either field comes back empty or absent
under the script's own selector (field/selector drift against the live API — no
mocked lane can see this, since every mocked lane passes against its own fixtures
by construction); the observed `mergeStateStatus` value falls outside the documented
enum (an unrecognised value the fixed predicate misclassifies); or a settled read
regresses to exit `14` (the over-widening failure mode — the direct falsifier of the
predicate rejecting more than just `UNKNOWN`). File it as its own issue rather than
re-litigating this cycle's already-settled design.

**Verified now (recorded observation, not a scheduled run):** a live read of PR #82
taken during this deliberation returned `mergeable=MERGEABLE`,
`mergeStateStatus=CLEAN` (feature design § "Design decision", § "Dependencies and
blast radius"; verification design § "Composition oracle determination" — Live
mergeability round-trip row) — a settled, non-`UNKNOWN` read, satisfying step 5's
condition and not step 6's. Re-run this scenario per the Recording convention below
rather than relying solely on this recorded observation.

---

## Recording convention

Run M1 and M2 once per GATE:QUALITY pass for #81 (or on any later change to
the attach path / permission model); run M3 once per GATE:QUALITY pass for
#81 (or on any later change to the `mergeable`/`mergeStateStatus` classifier
or its `--json` field selectors). Record the outcome (date, PR number used,
pass/fail per scenario) as a comment on the tracking issue or PR rather than
editing this file — this file states the reusable procedure, not a per-run
log.
