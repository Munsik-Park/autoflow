# U1 Preparation — PREFLIGHT

> Unit document for U1. [`CLAUDE.md`](../../CLAUDE.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

PREFLIGHT is functional unit U1 Preparation
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). U1 has no unit agent: it
is the orchestrator's own work. This file states what it is asked for, the cautions and the result
owed; the order of the work and the commands are the orchestrator's
([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2). A script only reads and reports (D8):
every change — to git, to GitHub, to the cycle's state — is made by the orchestrator itself.

- **Goal**: the requested issue starts, or continues, on a clean tree synced with the remote, with
  every earlier cycle whose pull request is merged or closed cleared away.
- **Artifact contract**: the state file `.autoflow/issue-{N}.json` and the dev branch checked out
  (*What is asked*), and the local-checks record in the ledger (*Stop conditions*).
- **Verification**: PREFLIGHT has no gate. Its readiness conditions are deterministic — the facts
  `scripts/preflight/cycle-status.sh` reports and the three *Stop conditions* — and DIAGNOSE does
  not begin until they hold.
- **Loop cap**: A condition that does not hold stops the cycle and is reported; PREFLIGHT
  runs again once it is resolved.
- **Result owed**: the state file, the dev branch and the local-checks record above. A resume also
  owes its re-entry point, recorded with grounds in the ledger (*Resume*).

## What is asked

```
bash scripts/preflight/cycle-status.sh --issue {N}
```

prints the facts the work is decided from and changes nothing: the working tree, the default branch
against its remote-tracking ref, and — for every `.autoflow/issue-*.json` — `active`, `phase`,
`mode`, `cycle`, the issue's dev branch (`dev/<date>-issue-<N>`) on each side and that branch's pull
request. Exit `3` means a fact could not be read (a `gh` lookup, an unreadable state file); the line
says which. From those facts the orchestrator brings about the following.

- **Earlier cycles are resolved.** A cycle whose pull request is merged or closed is cleared: its
  dev branch is deleted, locally and on the remote, and its `.autoflow/issue-{N}*` files are
  archived with `scripts/cleanup/cleanup-issue.sh` ([`git-workflow.md`](../git-workflow.md) >
  Post-Merge Cleanup). A cycle paused with no pull request keeps its files in place, and its
  pending decision is reported.
- **One issue runs at a time** (*PR Wait Rule*), and the requested issue takes the mode its own
  state names (*Modes*).
- **The tree is clean and synced.** No uncommitted change or untracked file in the working area,
  and the branch the mode works on — the default branch for a new issue, the issue's dev branch for
  a review-response — matches the remote ([`git-workflow.md`](../git-workflow.md) > Git Clean
  Check). In a project with sub-repos, syncing the host also brings each submodule to the commit
  the host's pointer names; this is the orchestrator's work item, and no script checks it.
- **The stop conditions pass** (*Stop conditions*): bundle drift, a readable reviewer configuration,
  the target-declared local checks.
- **A new issue gets its branch and its state**: the dev branch `dev/YYYY-MM-DD-issue-N` from the
  default branch, the state file from the Creation template with `mode: "new-issue"` and
  `phase: "in-progress"` ([`CLAUDE.md`](../../CLAUDE.md) > AutoFlow State Tracking), and the
  issue's `status:in-progress` label. A review-response gets *Review-response setup*.

Cautions:

- **A dirty tree is never resolved without the user.** What is stashed, committed or discarded is
  the user's to approve; PREFLIGHT does not reach DIAGNOSE on a dirty tree.
- **A branch that does not fast-forward, a fetch that fails, or a Git state that cannot be made
  clean is a hard stop**: report to the user. It is not worked around with a reset or a forced
  update.
- **A push is gated by the active cycle.** Deleting a remote dev branch is a push, and the hook
  admits a push only while no cycle is active or once the active one has passed AUDIT and
  GATE:QUALITY ([`CLAUDE.md`](../../CLAUDE.md) > Hook gates). A branch a cleared cycle left on the
  remote is therefore deleted before the requested issue's state file is created or reactivated;
  on a resume it waits until the hook admits a push.
- **The state file is created last.** A stop condition that fails, a hold or a pause leaves no
  state file and no dev branch for the requested issue behind.
- **A cycle is cleared only on an observed merged or closed pull request.** A state file whose dev
  branch is gone on both sides gives `cycle-status.sh` nothing to look its pull request up by; the
  orchestrator looks it up another way before it archives anything.

## PR Wait Rule

The readiness check that clears the requested issue to start. Its source of truth is AutoFlow's own
`.autoflow/issue-*.json` state files; the start signal is [`CLAUDE.md`](../../CLAUDE.md) > PR Wait
Rule.

- **[MUST]** An `active:false` state file (`phase: awaiting-external-review`) is **cleared and
  handed off**: its PR belongs to external review, which merges on its own schedule. Readiness is
  tied to the `active` flag alone.
- Another issue's `active:true` holds the requested one: report and hold, and finish or resolve
  that cycle first.

## Modes

The requested issue's mode follows from its own state file; none of these is a judgment:

| The issue's state | Mode |
|---|---|
| no state file (or one just cleared because its PR is merged or closed) | `new-issue` |
| `active:true` | `resume` — the in-progress cycle continues (*Resume*); it is not restarted |
| `active:false`, `phase` other than `awaiting-user`, with an open PR | `review-response` (*Review-response setup*) |
| `active:false` at `phase: "awaiting-user"` (a PR open or not), or `active:false` with no open PR | paused: the cycle waits on a human decision and is not cleared. The pending decision and its `.autoflow/issue-{N}-*.md` context are reported. Re-entry is driven by the user's new decision — never an automatic mode, never a silent restart: when the user decides to continue, the orchestrator sets `active: true` and continues where the pause was taken |

## Review-response setup

For a cycle entered at PREFLIGHT in `review-response` mode, and for a HANDOFF `design` re-entry
inside the session ([U6 Delivery](delivery.md) > *Routing*). On the issue's existing dev branch:

- **[MUST] The previous cycle's artifacts are preserved** before any phase of the new cycle writes:
  every `.autoflow/issue-{N}-<artifact>.md` is renamed to `.autoflow/issue-{N}-c{C}-<artifact>.md`,
  `C` being the previous cycle number. What spans cycles keeps its name — the ledger, the advisor
  records its entries point at (`issue-{N}-advisor-*.md`), the per-PR findings files
  (`issue-{N}-review-findings*.md`), the state file and the cycle-layer store `issue-{N}-local/` —
  and, only on a HANDOFF `design` re-entry judged to start at ARCHITECT, the analysis report that
  shape reuses in place.
- **The state file moves to the next cycle**: `mode: "review-response"`, `active: true`,
  `phase: "in-progress"`, `cycle` incremented, and `phases` reset to the Creation template (the
  `verdict` rule kept) — on the ARCHITECT re-design shape, only the gates that shape re-runs
  (GATE:PLAN, AUDIT, GATE:QUALITY).
- The local checks run with the incremented cycle number, and the state is set only once they pass.
- The issue carries `status:in-progress`, and the DIAGNOSE unit's prompt names the review comment
  or thread that triggered the cycle.

How much of the previous cycle's artifacts the new cycle reuses is the analysis and design units'
own ([U2 Analysis](analysis.md) > Unit spawn; [U3 Design](design.md) > *Re-entry*). The cycle-layer
store's retained set is reviewed, re-authored and re-executed at the new cycle's BUILD; a check that
did not execute is `not-run`, never `passed`.

## Resume

The requested issue's own state reads `active:true`: a cycle a session ended in the middle of.
`cycle-status.sh --issue {N}` reports what the resume is judged from — each gate's recorded scores,
`verdict` and `remedy_class`, the artifacts on disk, the ledger's last `[gate-autofix]`,
`[rebuttal]`, `[review-autofix]` and `[reentry-decision]` entries, and the last local-checks record
of the current cycle. It names no phase: **where the cycle re-enters is the orchestrator's judgment
over those facts**, recorded with its grounds in the ledger. Cautions:

- The cycle is continued, not restarted: a resume does not increment `cycle` and does not reset
  `phases`. It does not require a clean tree either — what the interrupted session left
  uncommitted belongs to the phase that re-enters.
- The issue's dev branch is checked out before any phase re-enters. A branch that is missing or
  matches more than one name, or facts that do not fit together, are reported to the user.
- A last local-checks record of the current cycle that is not `none declared` or `PASS …
  worktree=clean` means the local checks run now, before any phase re-enters (*Stop conditions*).
- A gate with no recorded scores has not passed. It is run, never assumed — the cycle re-enters no
  later than the phase whose artifact that gate scores.
- A gate whose record carries `remedy_class` has an open re-entry: a passed gate's open
  recommendation attempt ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*), which resumes
  on the route its last `[gate-autofix]` entry names and not past the gate; or a failed gate's FAIL
  route.
- A `[rebuttal]` entry with no verdict entry of that gate after it resumes at that gate's re-score
  ([U6 Delivery](delivery.md) > *Whether a finding holds*).
- An artifact the next phase consumes that is absent is not written by the orchestrator: the phase
  that produces it runs again.

## Stop conditions

Each is a fail-closed hard stop, run by the orchestrator before the state file is created: DIAGNOSE does not begin until all three pass.

**Bundle drift.** On a target that carries an installed manifest (`.claude/autoflow/manifest.json` — every thin-root target; the framework repository itself carries none and skips this check), PREFLIGHT runs `sh .claude/autoflow/drift-check.sh`; a non-zero exit stops the cycle. It asserts the installed files match the installed manifest (D1), the manifest version matches the installed plugin (D2), state never resolves from the plugin root (D3), the installed bundle matches the **marketplace clone** per artifact by sha256 (D4 — a self-consistent bundle that is older than what the clone would stamp, with or without a version bump, is drift), the installed plugin matches the clone's plugin source (D5), and the target-owned `.claude/autoflow/spawn-policy.json` scaffold agrees with the agent definitions the session loads (D6 — `scripts/spawn-policy/spawn-policy.sh check` over the scaffold, plus its row set against the clone's sample: a `phases` / `workflow_sites` row the current version requires and the scaffold lacks, or a `phases` row whose `agent_type` changed, is named here), and — on a target that opted into AutoFlow's suite plane (`.claude/autoflow.local.json` > `tests.suite_plane: true`; the leg resolves the opt-in through the shipped `scripts/test/suite-manifest.sh` and a target that has not opted in PASSes without the selector being consulted) — every executable spec under the target's `tests/**` declares the usable `# ci-subject:` header the shipped selector requires (D7 — the selector's own `--check-headers` stage); a declaration file that is present but unreadable is a D7 FAIL, and a scaffold with no `tests` object at all is named by a `HINT` beside the PASS (a re-stamp never adds it). The plugin and the clone are resolved from the harness's local registries by the shipped `scripts/lib/plugin-root.sh`, not from the hook-only `CLAUDE_PLUGIN_ROOT`; a side that is not locally resolvable reports `SKIP`, never a failure. Remedies: D1/D3 → repair the file; D2/D4 → re-stamp (`/autoflow:install`, or `<clone>/setup/init.sh --target <root> --force`; refresh the clone first with `/plugin marketplace update` if it is the side that is behind); D5 → `/plugin update`; D6 → edit the scaffold by hand (a re-stamp never overwrites it): set each named row to the loaded definition's values and add each missing row from `<clone>/.claude/autoflow/spawn-policy.json` — model values and `workflow_sites` effort are the target's own and are never findings; D7 → back-fill each named suite's header per [U4 Build and verify](build.md) > Header contract > *Adopting the contract over existing suites* (the suites are target-owned; a re-stamp never touches `tests/**`), or repair the unreadable `.claude/autoflow.local.json` it names. A `WARN` (a changed scaffold sample, an artifact the current manifest does not ship) does not stop the cycle; the orchestrator reports it. See `setup/SETUP-GUIDE.md` > *Self-verify with the drift detector*.

**Reviewer configuration.** PREFLIGHT runs `scripts/preflight/check-review-backend.sh`, which reads the external reviewers HANDOFF runs beside the built-in review from `.claude/autoflow.local.json` (`.review.reviewers`, or the earlier `.review.backend`; none when both are absent) and probes each one's CLI presence-only (`command -v`; auth is not probed). Exit `2` — a review configuration that cannot be read as configured — stops the cycle until it is fixed. Exit `1` — a configured reviewer's CLI absent — does not: the orchestrator records it in the ledger's PREFLIGHT entry, and HANDOFF runs the built-in review without that reviewer and names it on the aggregated comment. See [`reviewer-backend.md`](../reviewer-backend.md) > *Availability*.

**Target-declared local checks.** PREFLIGHT runs the target repository's **own** readiness procedure through `scripts/preflight/local-checks.sh --ledger .autoflow/issue-{N}-ledger.md --cycle <C>` — after prior-cycle resolution and before the state file is created; `<C>` is the cycle the state file will carry (`1` on a new issue, the incremented value on review-response entry). The target declares that procedure in the target-owned scaffold `.claude/autoflow.local.json` under `preflight.local_checks[]` — one entry per step, each `{ "name", "check", "repair"? }`, where `check` is the command run (exit 0 = ready) and the optional `repair` is run once on a failed `check`, followed by a re-check whose exit is the verdict. A target whose docs name a per-clone setup step (a commit-hook installer, a generated config, a toolchain probe) declares it here; the framework knows **no specific tool** — it runs what is declared and reads only the exit status. **Absent declaration ⇒ no-op**: the record is the single line `PREFLIGHT local checks: none declared`. A declared check that does not pass (after repair, when one is declared) is exit `1` and stops the cycle: run the declared repair, or fix the declaration, then run PREFLIGHT again. A declaration that cannot be read as declared (malformed JSON, wrong types, an entry without a string `check`) is exit `2` and also stops — never a silent no-op. A passing run additionally asserts `git status --porcelain` is empty afterwards: a dirty tree is exit `3` — not a failed check, but the clean-tree condition already broken — so it is resolved with the user's approval and PREFLIGHT is run again. The outcome is written **only** as a ledger record — a level-3 heading `### preflight-local-checks | cycle: <C>` with one `- result:` line whose verdict token is `none declared`, `PASS <name>=PASS[(repaired)] … worktree=clean`, `DIRTY <name>=PASS[(repaired)] … worktree=dirty(<n>)` or `FAIL <name>=FAIL[(…)] … worktree=n/a` (`PASS` is written only when the run passed and the tree is clean) — an identifier-free record entry; the state file is untouched, and the gate hook reads the ledger advisorily only. The commit-time lint-chain obligation (`submodule-common-rules.md` > *Lint chain on the staged surface*) applies on its own: a declared check that installs the lint chain does not replace running it.
