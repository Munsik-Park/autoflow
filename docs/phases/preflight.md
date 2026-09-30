# PREFLIGHT — U1 Preparation

> Phase playbook for PREFLIGHT. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

PREFLIGHT is functional unit U1 Preparation
([`ADR-0025`](../records/adr/0025-outcome-gated-functional-units.md) D1). Its fixed steps run as
one script call (D8). What the script reports is fact; what a fact leaves open — where an
interrupted cycle resumes, how a dirty tree is disposed of — is the orchestrator's judgment or the
operator's decision ([`CLAUDE.md`](../../CLAUDE.md) > Rule Scope, principle 2).

- **Goal**: the requested issue starts, or continues, on a clean tree synced with the remote, with
  every earlier cycle whose pull request is merged or closed cleared away.
- **What runs**: `bash scripts/preflight/preflight.sh enter --issue {N}`.
- **Verification**: the script's exit code. PREFLIGHT has no gate; its readiness conditions are
  deterministic checks, and DIAGNOSE does not begin on any exit but `0`.
- **Result owed**: the record `.autoflow/issue-{N}-preflight.md` (written on exit `0`), the state
  file `.autoflow/issue-{N}.json`, and the local-checks record in the ledger.

## The run

`preflight.sh enter` does, in one call, what is fixed:

- **Prior-cycle resolution.** It reads every `.autoflow/issue-*.json` against that issue's dev
  branch (`dev/<date>-issue-<N>`) and the branch's pull request. A cycle whose PR is merged or
  closed is cleared: its local dev branch is deleted and its `.autoflow/issue-{N}*` files are
  archived by `scripts/cleanup/cleanup-issue.sh` ([`git-workflow.md`](../git-workflow.md) >
  Post-Merge Cleanup). A dev branch such a cycle left on the remote stops the run (exit `12`)
  before the requested issue's state is touched. An issue paused with no PR keeps its files in
  place and is reported.
- **PR Wait Rule** (below) and the **mode** of the requested issue (*Modes*).
- **Sync.** `git fetch origin`; the default branch (new issue) or the issue's dev branch
  (review-response) is checked out and fast-forwarded from the remote. A resume checks its dev
  branch out as it stands.
- **Stop conditions** (below): bundle drift, reviewer-backend availability, target-declared local
  checks.
- **New issue**: the dev branch `dev/YYYY-MM-DD-issue-N` from the default branch, the state file
  from the Creation template ([`CLAUDE.md`](../../CLAUDE.md) > AutoFlow State Tracking), and the
  issue's `status:in-progress` label. **Review-response**: *Review-response setup* below.

| Exit | Meaning | What follows |
|---|---|---|
| `0` | ready — the output names `mode: new-issue`, `review-response` or `resume` | DIAGNOSE (new issue, review-response), or *Resume* |
| `10` | another issue's state reads `active:true` | report and hold — one issue runs at a time |
| `11` | the requested issue is paused for a human decision — inactive at `phase: awaiting-user`, or inactive with no open PR | report the pending decision and its `.autoflow/issue-{N}-*.md` context; re-entry is the user's decision (*Modes*) |
| `12` | a cleared cycle left its dev branch on the remote, named on `remote-branch-to-delete:` lines; the requested issue is untouched | the orchestrator deletes each with its own `git push origin --delete <branch>` and runs the script again |
| `20` | the working tree is dirty; the paths are listed | the dirty state is resolved — stash, commit, or discard **with the user's approval** — and the script is run again |
| `21` | `git fetch` failed, or the branch does not fast-forward from the remote | stop and report to the user |
| `22` | the requested issue's dev branch is missing, matches more than one name, exists with no state file, or cannot be checked out or created | the cycle cannot be continued from this checkout: report to the user |
| `30` / `31` / `32` / `33` | a stop condition failed — drift / reviewer backend / a local check / an unreadable local-check declaration | *Stop conditions* |
| `40` / `41` / `42` | a `gh` read failed / a state file is unreadable / archiving failed | fix the named cause and run again; a second failure is reported to the user |

Cautions:

- **The script never pushes.** A remote dev branch a cleared cycle left behind is deleted by the
  orchestrator's own `git push origin --delete <branch>`, a command the gate hook sees
  ([HANDOFF](handoff.md) > *Push and pull request*). The hook gates every push on the active
  cycle's AUDIT and GATE:QUALITY, so the run stops at exit `12` while no cycle is active yet; on a
  resume, where the cycle is already active, the branch is only named and its deletion waits until
  the hook admits a push.
- **A dirty tree is never resolved without the user.** A tree dirty at entry changes nothing; when
  the local checks leave it dirty, the mode's branch is already checked out. Either way what is
  stashed, committed or discarded is the user's to approve.
- **An exit other than `0` is a stop, not a step to work around.** The state file and the dev
  branch are created only on exit `0`.

`bash scripts/preflight/preflight.sh status [--issue {N}]` prints the same facts without changing
anything.

## PR Wait Rule

The readiness check that clears the requested issue to start. Its source of truth is AutoFlow's own
`.autoflow/issue-*.json` state files; the start signal is [`CLAUDE.md`](../../CLAUDE.md) > PR Wait
Rule.

- **[MUST]** An `active:false` state file (`phase: awaiting-external-review`) is **cleared and
  handed off**: its PR belongs to external review, which merges on its own schedule. Readiness is
  tied to the `active` flag alone.
- Another issue's `active:true` is exit `10`: that cycle is finished or resolved first.

## Modes

The script selects the requested issue's mode from its own state file; none of these is a judgment:

| The issue's state | Mode |
|---|---|
| no state file (or one just cleared because its PR is merged or closed) | `new-issue` |
| `active:true` | `resume` — the in-progress cycle continues (*Resume*); it is not restarted |
| `active:false`, `phase` other than `awaiting-user`, with an open PR | `review-response` (*Review-response setup*) |
| `active:false` at `phase: "awaiting-user"` (a PR open or not), or `active:false` with no open PR | paused (exit `11`): the cycle waits on a human decision and is not cleared. Re-entry is driven by the user's new decision — never an automatic mode, never a silent restart. When the user decides to continue, the orchestrator sets the cycle active again (`bash scripts/state/set-phase.sh --issue {N} --phase in-progress`) and continues where the pause was taken |

## Review-response setup

Run by `preflight.sh enter` when it selects `review-response`, and by HANDOFF for a `design`
re-entry inside the session (`bash scripts/preflight/preflight.sh review-response --issue {N}
[--keep-analysis]`; [HANDOFF](handoff.md) > *Review triage*). On the issue's existing dev branch it:

- runs the target-declared local checks with the next cycle's number;
- **preserves the previous cycle's artifacts**: every `.autoflow/issue-{N}-<artifact>.md` is renamed
  to `.autoflow/issue-{N}-c{C}-<artifact>.md`, `C` being the previous cycle number. What spans cycles
  keeps its name — the ledger, the advisor records its entries point at (`issue-{N}-advisor-*.md`),
  the per-PR findings files (`issue-{N}-review-findings*.md`), the state file and the cycle-layer
  store `issue-{N}-local/`. With `--keep-analysis` the analysis report stays in place as well;
- sets the state file to `mode: "review-response"`, `active: true`, `phase: "in-progress"`,
  increments `cycle`, and resets `phases` to the Creation template — with `--keep-analysis`, only
  the gates that re-entry re-runs (GATE:PLAN, AUDIT, GATE:QUALITY);
- adds the issue's `status:in-progress` label.

What stays the orchestrator's: naming the reviewer comment or thread that triggered the cycle (the
DIAGNOSE target) in the unit's prompt. How much of the previous cycle's artifacts the new cycle
reuses is the analysis and design units' own ([DIAGNOSE](analysis.md) > Unit spawn;
[ARCHITECT](architect.md) > *Re-entry*). The cycle-layer store's retained set is reviewed,
re-authored and re-executed at the new cycle's BUILD; a check that did not execute is `not-run`,
never `passed`.

## Resume

`mode: resume` — the requested issue's own state reads `active:true`: a cycle a session ended in
the middle of. The script checks out the dev branch, re-runs the local checks when the last record
of the current cycle is not a passing one, and reports the facts: each gate's recorded scores,
`verdict` and `remedy_class`, the artifacts on disk, the ledger's last `[gate-autofix]`,
`[rebuttal]`, `[review-autofix]` and `[reentry-decision]` entries. It names no phase: **where the
cycle re-enters is the orchestrator's judgment over those facts**, recorded with its grounds in the
ledger. Cautions:

- The cycle is continued, not restarted: a resume does not increment `cycle` and does not reset
  `phases`. It does not require a clean tree either — what the interrupted session left
  uncommitted is reported as a count, and belongs to the phase that re-enters.
- A gate with no recorded scores has not passed. It is run, never assumed — the cycle re-enters no
  later than the phase whose artifact that gate scores.
- A gate whose record carries `remedy_class` has an open re-entry: a passed gate's open
  recommendation attempt ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*), which resumes
  on the route its last `[gate-autofix]` entry names and not past the gate; or a failed gate's FAIL
  route.
- A `[rebuttal]` entry with no verdict entry of that gate after it resumes at that gate's re-score
  ([HANDOFF](handoff.md) > *Whether a finding holds*).
- An artifact the next phase consumes that is absent is not written by the orchestrator: the phase
  that produces it runs again. Exit `22`, or facts that do not fit together, are reported to the
  user.

## Stop conditions

Each is a fail-closed hard stop: DIAGNOSE does not begin until the script exits `0`.

**Bundle drift** (exit `30`). On a target that carries an installed manifest (`.claude/autoflow/manifest.json` — every thin-root target; the framework repository itself carries none and skips this check), the script runs `sh .claude/autoflow/drift-check.sh`. It asserts the installed files match the installed manifest (D1), the manifest version matches the installed plugin (D2), state never resolves from the plugin root (D3), the installed bundle matches the **marketplace clone** per artifact by sha256 (D4 — a self-consistent bundle that is older than what the clone would stamp, with or without a version bump, is drift), the installed plugin matches the clone's plugin source (D5), and the target-owned `.claude/autoflow/spawn-policy.json` scaffold agrees with the agent definitions the session loads (D6 — `scripts/spawn-policy/spawn-policy.sh check` over the scaffold, plus its row set against the clone's sample: a `phases` / `workflow_sites` row the current version requires and the scaffold lacks, or a `phases` row whose `agent_type` changed, is named here), and — on a target that opted into AutoFlow's suite plane (`.claude/autoflow.local.json` > `tests.suite_plane: true`; the leg resolves the opt-in through the shipped `scripts/test/suite-manifest.sh` and a target that has not opted in PASSes without the selector being consulted) — every executable spec under the target's `tests/**` declares the usable `# ci-subject:` header the shipped selector requires (D7 — the selector's own `--check-headers` stage); a declaration file that is present but unreadable is a D7 FAIL, and a scaffold with no `tests` object at all is named by a `HINT` beside the PASS (a re-stamp never adds it). The plugin and the clone are resolved from the harness's local registries by the shipped `scripts/lib/plugin-root.sh`, not from the hook-only `CLAUDE_PLUGIN_ROOT`; a side that is not locally resolvable reports `SKIP`, never a failure. Remedies: D1/D3 → repair the file; D2/D4 → re-stamp (`/autoflow:install`, or `<clone>/setup/init.sh --target <root> --force`; refresh the clone first with `/plugin marketplace update` if it is the side that is behind); D5 → `/plugin update`; D6 → edit the scaffold by hand (a re-stamp never overwrites it): set each named row to the loaded definition's values and add each missing row from `<clone>/.claude/autoflow/spawn-policy.json` — model values and `workflow_sites` effort are the target's own and are never findings; D7 → back-fill each named suite's header per [BUILD](build.md) > Header contract > *Adopting the contract over existing suites* (the suites are target-owned; a re-stamp never touches `tests/**`), or repair the unreadable `.claude/autoflow.local.json` it names. A `WARN` (a changed scaffold sample, an artifact the current manifest does not ship) does not stop the cycle; the orchestrator reports it. See `setup/SETUP-GUIDE.md` > *Self-verify with the drift detector*.

**Reviewer-backend availability** (exit `31`). The script runs `scripts/preflight/check-review-backend.sh`, which reads the configured HANDOFF review backend from `.claude/autoflow.local.json` (`.review.backend`, default `codex`; absent ⇒ codex) and probes the CLI presence-only (`command -v codex` / `command -v claude`; auth is not probed — a present-but-unauthenticated backend passes here and surfaces its auth failure at the HANDOFF reviewer review). The cycle does not begin until the configured backend's CLI is installed or the backend is switched in `.claude/autoflow.local.json`. See [`reviewer-backend.md`](../reviewer-backend.md).

**Target-declared local checks** (exit `32`; `33` for an unreadable declaration; `20` when the checks pass and leave the tree dirty). The script runs the target repository's **own** readiness procedure through `scripts/preflight/local-checks.sh --ledger .autoflow/issue-{N}-ledger.md --cycle <C>` — after prior-cycle resolution and before the dev branch and the state file are created; `<C>` is the cycle the state file will carry (`1` on a new issue, the incremented value on review-response entry). The target declares that procedure in the target-owned scaffold `.claude/autoflow.local.json` under `preflight.local_checks[]` — one entry per step, each `{ "name", "check", "repair"? }`, where `check` is the command run (exit 0 = ready) and the optional `repair` is run once on a failed `check`, followed by a re-check whose exit is the verdict. A target whose docs name a per-clone setup step (a commit-hook installer, a generated config, a toolchain probe) declares it here; the framework knows **no specific tool** — it runs what is declared and reads only the exit status. **Absent declaration ⇒ no-op**: the record is the single line `PREFLIGHT local checks: none declared`. A declared check that does not pass (after repair, when one is declared) stops the cycle: run the declared repair, or fix the declaration, then run PREFLIGHT again. A declaration that cannot be read as declared (malformed JSON, wrong types, an entry without a string `check`) also stops — never a silent no-op. A passing run additionally asserts `git status --porcelain` is empty afterwards: a dirty tree is not a failed check, but the clean-tree condition already broken, so it is resolved with the user's approval and PREFLIGHT is run again. The outcome is written **only** as a ledger record — a level-3 heading `### preflight-local-checks | cycle: <C>` with one `- result:` line whose verdict token is `none declared`, `PASS <name>=PASS[(repaired)] … worktree=clean`, `DIRTY <name>=PASS[(repaired)] … worktree=dirty(<n>)` or `FAIL <name>=FAIL[(…)] … worktree=n/a` (`PASS` is written only when the run passed and the tree is clean) — an identifier-free record entry; the state file is untouched, and the gate hook reads the ledger advisorily only. The commit-time lint-chain obligation (`submodule-common-rules.md` > *Lint chain on the staged surface*) applies on its own: a declared check that installs the lint chain does not replace running it.
