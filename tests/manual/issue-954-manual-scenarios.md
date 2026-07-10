# Issue #954 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

These items are **not** covered by `tests/test-issue-954-cross-issue-scan.sh` —
they are cross-step temporal/procedural claims that require an actual live
PREFLIGHT + backlog-append across a real cycle, not a fact derivable from a
static repo tree or an isolated fixture run. Delegated per the verification
design (`.autoflow/issue-954-verification-design.md` §2, AC4 residual scope)
and the feature design's commit-batching description
(`.autoflow/issue-954-feature-design.md` §6). **These are tracking-only and
do not gate this cycle's VERIFY / VALIDATE / GATE:QUALITY** — the automated
tier (AC1 playbook wording + M/K literals + script boundedness, AC2 digest-
only corpus + `:598` DENY reconciliation, AC3 script threshold/format
behavior, AC4 script no-mutation guard + doc-assertion, AC5 maintained-docs
trigger, AC6 Decision-4 boundary, AC7 loop-check relationship) already covers
the falsifiable core.

---

## M1 (AC4 residual — commit-sequencing) — backlog append lands as a separate
## post-clean-tree dev-branch infra commit, never inside PREFLIGHT itself

**Why not automated / not this cycle:** a scripted test can prove the scan
script itself never dirties the working tree (`tests/test-issue-954-cross-issue-scan.sh`
AC4-no-mutation guard, isolated temp copy). It **cannot** prove that the
*orchestrator* actually sequences the real `docs/improvement-backlog.md`
append **after** PREFLIGHT's `git status` clean-tree gate (step 2) and **on**
the cycle's dev branch, rather than as a direct working-tree write during
PREFLIGHT or a commit to `main`. That ordering is a live, cross-step temporal
property only observable across an actual proceeding PREFLIGHT that hits a
real threshold breach.

**Steps** (run at the first live cycle whose PREFLIGHT step 1.5 scan reports a
breach — i.e. `docs/cycle-digest.jsonl` has accumulated enough distinct-issue
recurrence at K=3 within the M=20 window):

1. Confirm the orchestrator spawns exactly one
   `Agent(subagent_type:"autoflow-analyzer", model:"sonnet")` at PREFLIGHT
   step 1.5 (not step 2 or later), and that this spawn precedes the `git
   status` clean-tree check.
2. Confirm the subagent's report is the scratch `path` (`.autoflow/issue-{N}-xissue-scan.md`)
   + a one-line summary only — no candidate-block body pasted into the
   orchestrator's context (Cost Control / Orchestrator context discipline).
3. Confirm PREFLIGHT's `git status` clean-tree check (step 2) still passes
   with the scratch file present (it is gitignored — `.autoflow/*` — and is
   a `.md`, not `.autoflow/*.json`, so the gate hook's malformed-state scan
   does not see it).
4. Confirm the real append to `docs/improvement-backlog.md` happens **only
   after** the dev branch exists (new-issue mode: after step 5; review-
   response mode: the already-existing dev branch) — i.e. strictly after the
   clean-tree gate, never as a direct write during PREFLIGHT step 1.5/2.
5. Confirm the append is committed as a **standalone infra commit**
   (`chore(preflight-scan): append cross-issue recurrence candidate (class
   <c>, N issues)`), separate from any of the running issue's feature
   commits, and that the commit lands on the **dev branch**, never on `main`
   (no direct commit to `main` — `git log` / `git show <SHA>` confirms the
   branch).
6. Confirm the appended block matches the `--format=backlog` rendering that
   `scripts/preflight/scan-cross-issue-recurrence.sh` produced (byte-for-byte
   modulo the scan date), and that it is the standard `###` finding grammar
   (`docs/improvement-backlog.md:64-76`) so a human can promote it via the
   existing `§운영 규칙` flow.
7. If PREFLIGHT halts before a dev branch exists (another-issue-active
   report-and-hold, or a paused human-decision state) during this observed
   cycle, confirm **no** append happens that run — the scratch is left in
   place (gitignored) and the next proceeding PREFLIGHT re-derives the same
   candidate from the unchanged corpus (no lost signal, no premature write).

**Evidence to record:** the scratch-file `path:line`, the infra-commit SHA,
and the dev-branch name the commit landed on.
