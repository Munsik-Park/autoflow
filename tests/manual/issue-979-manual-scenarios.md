# Issue #979 — Manual/Environment-Dependent Verification Scenarios

These items are **not** covered by the automated suites
(`tests/test-issue-979-review-backend.sh`,
`tests/test-issue-979-preflight-backend-check.sh`,
`tests/test-issue-979-bundle-delivery.sh`,
`tests/test-issue-979-doc-neutrality.sh`,
`tests/test-issue-979-probe.sh` — cycle 9, the `--probe` surface) — they require a live CLI /
account / interactive install session, per
`.autoflow/issue-979-verification-design.md` §1/§2 and the feature design
§6/§8. Itemize at VALIDATE; do not mark any of these PASS from automated
output alone.

---

## M-1 (AC-1b, [MUST] — REQUIRED VALIDATE gate, not optional) — live `claude -p`
## reviewer actually clears/retains `blocked-by-review`

**Why not automated:** whether neutral-cwd `claude -p` loads the target
project's `.claude/settings.json` gate hook is an intrinsic runtime property
of the `claude` CLI's settings-discovery behavior — no in-suite test can
observe it without invoking the real binary. This is the sole evidence for
the claude branch's load-bearing correctness property (§3
isolation-preservation of the feature design); it cannot be deferred or
downgraded to an optional smoke.

**Setup:** a disposable PR in a scratch repo (or a throwaway branch of this
repo) carrying the `blocked-by-review` label, with `.claude/autoflow.local.json`
set to `{"review":{"backend":"claude"}}` and a live, authenticated `claude`
CLI on `PATH`.

**Steps:**
1. Run `scripts/review/codex-review-pr.sh --pr <N>` against a **clean** diff
   (no seeded findings).
2. Confirm a Korean review comment is posted to the PR.
3. Confirm `blocked-by-review` is **removed** from the PR.
4. Repeat against a diff with a seeded Medium+ finding.
5. Confirm the comment is posted and `blocked-by-review` is **retained**.

**Expected:** step 3 clears the label (proving the target's gate hook did
**not** deny `--remove-label` from the claude session); step 5 leaves it
in place.

**Fail signal:** the label is never cleared on the clean-diff run (the
neutral-cwd assumption is wrong, or the target's gate hook still fires), or
the label is cleared on the Medium+ run (label-authority sentence not
respected).

---

## M-2 (AC-2, OAuth-used) — claude backend actually runs on subscription OAuth,
## not metered API

**Why not automated:** confirming which billing surface actually charged the
call requires a real account and cannot be observed from a stubbed
subprocess (`tests/test-issue-979-review-backend.sh`'s AC-5 assertion only
proves the key is *unset from the subprocess's env*, not which billing plane
served the request).

**Steps:** run the wrapper with backend=claude against a real PR, with
`ANTHROPIC_API_KEY` unset in the shell and a valid `claude` subscription
login. Check the Anthropic Console / subscription usage dashboard for the
session; confirm no metered-API charge appears.

**Fail signal:** a metered API charge appears for the review session.

---

## M-3 (AC-2, presence probe symmetry — auth-state disclosure, non-blocking)
## claude auth failure surfaces at HANDOFF step 6, not PREFLIGHT

**Why not automated:** by design (C1 RESOLVED), PREFLIGHT's
`check-review-backend.sh` only probes CLI **presence**, not auth; a
present-but-unauthenticated `claude` must pass PREFLIGHT and fail later.

**Steps:** with `claude` installed but logged out, and backend=claude
configured, run PREFLIGHT (or `check-review-backend.sh --backend claude`
directly) — confirm exit 0. Then run
`scripts/review/codex-review-pr.sh --pr <N>` for real — confirm the claude
auth failure surfaces there (at HANDOFF step 6), with a message pointing to
`docs/reviewer-backend.md`.

**Fail signal:** PREFLIGHT itself fails closed on the unauthenticated
session (contradicts the presence-only design), or the HANDOFF-step failure
gives no actionable pointer to fix auth.

---

## M-4 (AC-3b) — install-skill interactive disclosure + backend selection

**Why not automated:** the `/autoflow:install` skill's interactive
confirmation flow (Step 3) is a live Claude Code session interaction, not a
non-interactive script path (`tests/test-issue-979-bundle-delivery.sh`
exercises only the non-interactive `init.sh --target` path).

**Steps:** run `/autoflow:install` in a scratch target where `codex` is
absent from `PATH`. Confirm the skill:
1. Discloses that `codex` is absent and that step-6 review will fail closed
   at PREFLIGHT unless a backend is selected.
2. Prompts for a backend choice at the existing Step-3 confirmation.
3. On selecting `claude`, writes `{"review":{"backend":"claude"}}` to
   `.claude/autoflow.local.json` in the target.
4. On declining, leaves the scaffold at `backend:"codex"` (no silent
   auto-write of `claude`).

**Fail signal:** the skill silently proceeds without disclosure, or writes
`claude` without an explicit operator selection.

---

## M-5 (AC-4, deferred per maintained-docs registry convention) — SETUP-GUIDE
## Reviewer-backend subsection registration

**Why not automated:** `tests/test-issue-979-bundle-delivery.sh` asserts the
subsection's *presence and content*; whether it is correctly registered in
`docs/maintained-docs.md` (single-row registration convention, mirrors
AC4c/d precedent in `tests/plugin/manual-scenarios-792.md`) is a docs-registry
bookkeeping check deferred to VALIDATE.

**Steps:** confirm `docs/maintained-docs.md` carries a row for the new
"Reviewer backend" SETUP-GUIDE subsection (owner, trigger, last-reviewed).

**Fail signal:** the subsection exists but is unregistered, so future edits
to the reviewer-backend contract have no doc-maintenance trigger.

---

## M-6 (C9-AC-9, DCR-3) — live `--probe` round-trip actually confirms
## authenticated vs logged-out state

**Why not automated:** the automated suite
(`tests/test-issue-979-probe.sh`) proves the probe **dispatches** the
configured backend's CLI with the correct isolation (C9-AC-2/-3/-7) using a
stub that reports `ok`/`fail`/`hang` on command — it does not prove a
**real** model round-trip actually authenticates. No side-effect-free
auth-encoding command exists (the same premise E8/R3 already rests on), so
only a live run against a real backend witnesses this — the same inherent
gap as M-2/C8-AC-6.

**Setup:** backend=claude with a real `CLAUDE_CODE_OAUTH_TOKEN` (or an
interactive `claude` login); symmetrically, backend=codex with a real,
authenticated `codex` CLI.

**Steps:**
1. With the backend authenticated, run
   `scripts/preflight/check-review-backend.sh --backend <claude|codex> --probe`.
   Confirm exit **0** ("auth verified").
2. Log out / revoke the token (claude: unset `CLAUDE_CODE_OAUTH_TOKEN` and
   any stored OAuth login; codex: revoke/remove its credentials). Re-run the
   same `--probe` invocation. Confirm exit **4** (present but auth-failed —
   the condition that surfaces at HANDOFF step 6).

**Fail signal:** an authenticated backend reports anything other than exit
0, or a logged-out/revoked backend reports exit 0 (a false "auth verified"
would mask a real HANDOFF step-6 failure from the operator).

---

## M-7 (C9-AC-4, DCR-3) — install-time interactive `--probe` invocation
## (B3a auto-invoke)

**Why not automated:** the `/autoflow:install` skill's Step 4 flow (the
`--probe` sub-step between 4c persist and 4d drift-check) runs inside a
live Claude Code session's interactive tool-call sequence, not a
non-interactive script path — sibling to M-4's interactive-disclosure gap
(`tests/test-issue-979-bundle-delivery.sh` exercises only the
non-interactive `init.sh --target` path, and
`tests/test-issue-979-probe.sh`'s C9-AC-4 only proves the SKILL.md text
names the step, not that a live install session actually executes it).

**Steps:** run `/autoflow:install` against a scratch target, confirming the
Step-3 backend selection (default `codex`, or an explicit switch to
`claude`).
1. Confirm the skill runs `check-review-backend.sh --probe` against the
   just-persisted selection after Step 4c (persist) and before Step 4d
   (drift-check).
2. Confirm the skill narrates the outcome (auth verified / CLI not
   installed / auth failed / could not verify) without aborting the
   install regardless of the probe's exit code.
3. Repeat for both the retained `codex` default and an explicit `claude`
   switch.

**Fail signal:** the probe step is skipped, runs at the wrong point in the
flow (before persist, or not before drift-check), or a non-zero probe exit
aborts the install (violates R3 — the probe is advisory, never a gate).
