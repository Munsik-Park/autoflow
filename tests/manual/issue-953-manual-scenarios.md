# Issue #953 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

These items are **not** covered by `tests/test-issue-953-cycle-digest.sh` —
they are runtime-behavior claims that require an actual live HANDOFF (a real
spawn producing a real record in a real PR), not a fact derivable from a
static repo tree or an isolated fixture run. Delegated per the verification
design (`.autoflow/issue-953-verification-design.md` §5) and the feature
design's write-point description (`.autoflow/issue-953-feature-design.md`
§3). **These are tracking-only and do not gate this cycle's VERIFY /
VALIDATE / GATE:QUALITY** — the automated tier (AC1 doc-wording, AC2 schema +
tracked-ness + F7 fixture append-only, AC3 doc-wording, AC4 hook regression,
AC5 whitelist absence, AC6 manifest/closure/ADR, AC7 doc-wording) already
covers the falsifiable core.

---

## M1 (AC1 / AC2 behavior) — live HANDOFF digest emission

**Why not automated / not this cycle:** whether the step-6.7 `autoflow-analyzer`
subagent actually runs, reads the three live inputs, and appends exactly one
well-formed record is only observable during a real HANDOFF — no fixture run
substitutes for the live spawn reading the live `.autoflow/issue-{N}.json` +
`-ledger.md` + `-review-findings.md` at the real terminal-cycle moment.

**Steps** (run at this issue's own HANDOFF — the dogfood bootstrap, feature
design §3):

1. At HANDOFF step 6.7 (after step 6.5 review triage resolves clean, before
   step 7's `active:false`), confirm the orchestrator spawns exactly one
   `Agent(subagent_type:"autoflow-analyzer", model:"sonnet")`.
2. Confirm the spawn's report is anchor + one-line summary only — no inlined
   record body pasted into the orchestrator's context (Cost Control /
   Orchestrator context discipline).
3. Confirm exactly one new line was appended to `docs/cycle-digest.jsonl`
   (line count grows by exactly 1 versus the pre-step-6.7 file state).
4. Confirm the appended line is a valid JSON object per the canonical §4
   schema (the same shape `tests/fixtures/cycle-digest-schema.json`
   validates) and that `gates.gate_plan.avg` is this issue's real terminal
   GATE:PLAN average (not `0`).

## M2 (AC3 behavior) — digest co-rides the cycle's own PR

**Why not automated / not this cycle:** whether the digest commit actually
lands in the *same* PR's file diff (rather than a separate PR) is only
observable by inspecting the live PR after the step-6.7 update-push.

**Steps:**

1. After HANDOFF step 6.7's push, run `gh pr diff <N> --name-only` (or view
   the PR's Files tab) and confirm `docs/cycle-digest.jsonl` appears in the
   diff.
2. Confirm no second PR was created for the digest (`gh pr list` shows only
   the one PR this cycle already opened at step 4).

## M3 (AC6 live) — digest not installed into a plugin/root-layer target

**Why not automated / not this cycle:** `tests/plugin/verify-install-into-target.sh`
exercises `setup/init.sh` against a real dummy target directory; running the
full installer is a heavier, environment-dependent check than the manifest
`jq`/closure-grep guards already asserted statically in
`tests/test-issue-953-cycle-digest.sh` AC6.

**Steps:**

1. After F1 (HANDOFF step 6.7)/F3 (ADR-0015 carve-out)/F4 (manifest regen)
   land, run `setup/init.sh` into a dummy target per
   `tests/plugin/verify-install-into-target.sh`.
2. Confirm `docs/cycle-digest.jsonl` is **not** present anywhere under the
   installed target's `.claude/autoflow/` tree.
