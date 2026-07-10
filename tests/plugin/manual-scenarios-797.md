# Manual Scenarios — Issue #797 [#785-S10] throwaway dummy-target E2E (PILOT gate)

**Test AI · RED · cycle 1 · 2026-07-06**

These scenarios cover the acceptance criteria typed **E** (environment-dependent)
or **M** (manual) in `.autoflow/issue-797-verification-design.md` §1 — the one
genuinely-unautomatable surface of #797: a **live** PREFLIGHT→HANDOFF AutoFlow
cycle, reasoning-driven by a real Claude Code LLM session, run inside the
throwaway dummy library target. Everything else #797 requires is covered by
the automated suite `tests/plugin/verify-e2e-dummy-target.sh` (EA-FIX through
EA-DEFECT / E1a-E5b) — that suite is the composed structural proxy that
de-risks this pilot; this document is the residual manual gate.

**None of these criteria are auto-PASS from automated suite output. Each is
marked NOT-automated below, with the reason it cannot be a deterministic
assertion.**

---

## E-M1 — Live AutoFlow LLM cycle inside the dummy target

**Type**: NOT-automated (E — environment-dependent: requires a live Claude
Code LLM session and live phase-gate hook evaluation)

**Why this cannot be scripted**: a real DIAGNOSE→ARCHITECT→...→HANDOFF cycle
requires an LLM actually reasoning about a throwaway issue, spawning
role-declared teammates, and evaluating gates — there is no deterministic
substitute for "the model reasoned correctly" that would not itself be a
fidelity-violating false-green (cf. the repo's own precedent: a scripted fake
of a live invocation is rejected the same way a `DOCKER_HOST=:1` mock was
rejected as a spurious PASS in a prior cycle). The automated suite instead
proves the **deterministic machinery** a live cycle would drive — state-file
gate transitions (E4a-e), install/manifest/drift composition (E1-E3) — but the
LLM-reasoning portion itself is irreducibly manual.

**Scenario**: instantiate a **fresh** throwaway dummy target (structurally
like, but independent from, the suite's own generated fixture — a real scratch
directory, not the suite's `mktemp -d`), install AutoFlow into it, open a
Claude Code session rooted there, and drive one throwaway issue through the
full AutoFlow lifecycle to an open (never-merged) draft PR.

**Steps**:
1. Create a scratch project outside this repo:
   ```sh
   mkdir /tmp/pilot-dummy-lib && cd /tmp/pilot-dummy-lib
   git init
   printf '{"name":"pilot-dummy-lib","private":true}\n' > package.json
   mkdir src && printf 'module.exports = 1;\n' > src/index.js
   printf '# pilot-dummy-lib\n' > README.md
   printf '# pilot-dummy-lib notes\n' > CLAUDE.md
   git add -A && git commit -m "initial commit"
   ```
2. Install AutoFlow into the scratch target from the claude-autoflow checkout:
   ```sh
   bash <path-to-claude-autoflow>/setup/init.sh --target /tmp/pilot-dummy-lib
   ```
3. Confirm the install is clean:
   ```sh
   sh /tmp/pilot-dummy-lib/.claude/autoflow/drift-check.sh
   ```
   (exit 0 expected — if not, this pilot is blocked; file the drift-check
   defect per the recording template below before continuing.)
4. Open a **real** Claude Code session rooted at `/tmp/pilot-dummy-lib`, with
   the `autoflow@autoflow` plugin installed and enabled
   (`/plugin marketplace add Munsik-Park/autoflow`, then
   `/plugin install autoflow@autoflow`).
5. Create one throwaway GitHub issue against a scratch/private repo backing
   `/tmp/pilot-dummy-lib` (a real remote is required for `gh pr create` in
   step 8 — see E-M2). A trivial `test`- or `chore`-type issue is sufficient;
   the goal is exercising the full phase sequence, not a meaningful feature.
6. Drive the AutoFlow lifecycle in-session per `CLAUDE.md` > Development
   Lifecycle: PREFLIGHT → DIAGNOSE → ... → HANDOFF, observing that:
   - each gate (`GATE:HYPOTHESIS`/`GATE:PLAN`/`AUDIT`/`GATE:QUALITY`) actually
     runs and records scores in `.autoflow/issue-<N>.json`;
   - the installed `check-autoflow-gate.sh` hook (single-repo topology — no
     `.gitmodules` in the scratch target) admits/denies exactly as the
     automated suite's E4a-e arms predict for the corresponding state;
   - HANDOFF opens **one** host PR, in draft, with `blocked-by-review` and
     **no** `blocked-by-subrepo` label (single-repo path).
7. Confirm no phase attempts a merge and no phase pushes directly to the
   scratch repo's default branch (AutoFlow hands off an open draft PR only).
8. Record the outcome (pass/fail per phase) using the template below.

**Pass condition**: the cycle reaches HANDOFF with exactly one open draft PR
carrying `blocked-by-review` and no `blocked-by-subrepo`, no merge attempted,
and every gate transition matches what the automated suite (E4a-e) predicts
for the corresponding seeded state.

---

## E-M2 — Real `gh pr create` against a live GitHub remote

**Type**: NOT-automated (E — environment-dependent: requires a live GitHub
remote; the automated suite's E4a/E4f-g simulate only the *gate verdict* and
the *label argv*, never a live network call)

**Why this cannot be scripted**: the automated suite's `gh` stub (E4f-h)
proves `create-host-pr.sh` builds the correct argv and never calls
`gh pr merge`, but it never actually talks to GitHub — that would require a
live remote and would violate the suite's hermetic/network-independent
constraint (issue's 비배포형 requirement). This scenario is the residual
network-touching step.

**Scenario**: as part of E-M1 step 6/8, confirm the host PR that
`scripts/handoff/create-host-pr.sh` opens against the live scratch remote is
actually created as a real draft PR (visible via `gh pr view` or the GitHub
UI), not merely a locally-recorded argv.

**Pass condition**: `gh pr view` on the scratch remote shows a real, open,
draft PR with the expected labels; no merge occurred.

---

## Generalization-defect recording template

Per the issue's item-8 requirement ("generalization-defect → trace to
originating S-stage/#-issue"), record every defect surfaced during E-M1/E-M2
here, tracing it to the **mechanism/stage that owns it** rather than
mis-filing it against `claude-autoflow` generically. The automated suite's
`failc()` (E5b) already self-attributes failures in the **structural** suite
to their owning stage — this template extends the same discipline to defects
found only in the live pilot.

| # | Symptom (what broke) | Originating S-stage / mechanism | GitHub issue # | Notes |
|---|---|---|---|---|
| _(example)_ | drift-check.sh false-FAILs after a clean install | S5 / #792 (install + manifest + drift) | _(file against claude-autoflow, Part of #785)_ | reproduce with `CLAUDE_PROJECT_DIR` unset vs set |
| | | | | |

**Filing rule**: a defect whose root mechanism traces to S2 (#788
host-purity), S4a/S4b (#790/#791 packaging/thin-root), S5 (#792
install/manifest/drift), S6-S9 (#793-#796), or the single-repo HANDOFF
docs/runtime is filed as a follow-up issue against `claude-autoflow` (the tool
repo), never against the pilot's throwaway scratch project — the scratch
project is disposable; the tool is not. A defect that is instead a
**genuinely new #797 gap** (the composition itself, not a delegated
mechanism) is filed against #797's own follow-up, referencing this pilot run.

---

## Itemization note (VALIDATE)

At VALIDATE, the assignee should confirm:

- [ ] E-M1: a real Claude Code session drove at least one throwaway issue
      through PREFLIGHT→HANDOFF inside an installed dummy target, and every
      gate transition matched the automated suite's E4a-e predictions
- [ ] E-M2: the resulting host PR is a real, open, draft PR on a live remote
      with `blocked-by-review` and no `blocked-by-subrepo`, and was never
      merged by AutoFlow itself
- [ ] Any defect surfaced during the pilot is recorded in the table above and
      filed against its owning S-stage/#-issue, not against the scratch
      project
