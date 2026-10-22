# U7 Review — REVIEW

> Unit document for U7. [`core.md`](../core.md) > Unit Document Loading Contract routes to
> this file; the other units are listed in [`autoflow-guide.md`](../autoflow-guide.md) > Unit
> Documents.

REVIEW is one functional unit, U7 Review
([`ADR-0033`](../records/adr/0033-review-unit-and-script-reviewers.md)): the review of every pull
request [U6 Delivery](delivery.md) opened, its triage, and the hand-off that ends AutoFlow. U7 has
no unit agent: it is the orchestrator's own work ([`role-contracts.md`](../role-contracts.md) >
Spawn mode by role lifetime). A script only reads and reports. The orchestrator runs the reviewers,
writes the state file and the ledger, and makes the changes a route calls for; the aggregation of a
pull request's reviews into one verdict is made by a spawned role.

U7 is entered with the issue number or with nothing. Where the cycle stands — its attempt, its pull
requests and their rounds — is read from the current state: `bash <autoflow-root>/scripts/preflight/cycle-status.sh`
(with `--issue <N>` when given), the attempt's ledger and records, and the pull requests themselves.
An attempt with no state file whose pull request is open — an attempt on the abbreviated path — is
reviewed as *An attempt with no state file* below says, which takes the place of this unit's goal,
routing, cap and *End* for it.

- **Goal**: every pull request of the cycle reviewed, its aggregated review posted with no
  `Medium`+ finding that holds left and CI green on its head (or recorded on it as not run — [U6
  Delivery](delivery.md) > *CI*), and the state file handed off.
- **Artifact contract**: each reviewed PR's review records and findings file (*Reviewer review*,
  *Review aggregation*), and the ledger entries the routes record.
- **What a script reads and reports**: a reviewer run's start check (*Reviewer review*; the run
  itself is the reviewer's wrapper), and the triage case with its attempt count (*Review triage*).
  Each reports by exit code.
- **Verification**: the aggregated review clean and CI green, or CI's not running recorded — outside the orchestrator's own
  claim.
- **Loop cap**: auto-resolution of reviewer findings, 7 attempts ([`core.md`](../core.md) > Flow
  Control > Regressions).
- **Result owed**: the report of *End*, with each PR's URL and head commit, the review verdict and
  the merge order.

## Transitions

The Flow Control rows that leave this unit; the rows that leave no single unit, and the regression and escalation caps, are [`core.md`](../core.md) > Flow Control.

| Transition | Condition |
|------|------|
| REVIEW (review-triage) → thin route / design re-entry (auto) | the aggregated review verdict is `max_severity ≥ Medium` → each Medium+ finding is routed by its `remedy_class` (`<autoflow-root>/scripts/gate/remedy-route.sh route`): `design` → a re-entry within the cycle from DIAGNOSE or from ARCHITECT, the orchestrator's judgment recorded in the attempt's `[review-autofix]` ledger entry; `impl` / `test` / `doc` → the thin route; `operator` → the advisor fixes the class. A finding that does not hold is rejected, not routed (`<autoflow-root>/docs/units/review.md` > *Review triage*; the case is `<autoflow-root>/scripts/handoff/review-gate.sh` exit `10`) |
| REVIEW (review-triage) → advisor / user | auto-resolution hits an advisor criterion (`<autoflow-root>/docs/units/review.md` > *Routing*), or a rebutted finding the next round's aggregation keeps while the two sides still disagree → the advisor decides; the 7-attempt cap (`review-gate.sh` exit `11`) → `active:false`, `phase:"awaiting-user"` |
| REVIEW → end | every PR's aggregated verdict below Medium + Low triage resolved + CI green, or CI recorded as not run → the orchestrator sets the state `active:false`, `phase:"awaiting-external-review"` and reports the merge order → AutoFlow ends; external review reviews and merges out of band (`<autoflow-root>/docs/units/review.md` > *End*) |

## Reviewer review

Every pull request the cycle opened is reviewed on its own diff — the host PR and each sub-repo PR
alike; a sub-repo PR's review is required, not optional. A round of a PR's review runs every
reviewer, and their records go to one aggregation (*Review aggregation* below), which posts the
round's comment ([ADR-0026](../records/adr/0026-aggregated-review.md)).

The reviewers are the ones the `reviewers:` line of `bash <autoflow-root>/scripts/preflight/check-review-backend.sh`
names, read rather than recalled — those the operator's `~/.autoflow/config.json` lists, and
`claude` and `codex` when it lists none ([`reviewer-backend.md`](../reviewer-backend.md) > *Config
location*). Each runs as its own script, launched in the background:

```
bash <autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>] [--records <attempt-dir>]
bash <autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> --expected-head <branch> [--repo <owner/name>]
bash <autoflow-root>/scripts/review/review-start-check.sh --pr <N> --reviewer <name> [--repo <owner/name>] [--log <the run's captured output>]
```

Each wrapper stops when the PR it is given is not that OPEN PR on that head branch, then runs its
reviewer over the PR with that reviewer's rule file and, where one is configured, its lenses file
([`reviewer-backend.md`](../reviewer-backend.md) > *Rule files*), on the model and effort the same
file names; the reviewer writes its review and nothing else. `--records` names the attempt's record
directory, where the `claude` reviewer reads the cycle's design artifacts — the analysis report,
the feature design, the verification design, the decision ledger and the build report.
`<record>` is the review record's absolute path below; nothing a wrapper or its reviewer writes
stays in the target's tree.

**The reviews of the target's side.** A review a system on the target's side runs on the pull
request by itself — a review bot's review or review comment — is a review of the round too. It is
not launched and leaves no record: the aggregator reads it from the pull request (*Review
aggregation*). Whether to wait for one that has not yet arrived is the orchestrator's judgment.

**An unreadable operator file.** When the operator's `~/.autoflow/config.json` cannot be read as
configured, `check-review-backend.sh` exits `6` and each wrapper starts no reviewer and exits `6`;
each prints the marker line `user-config: UNREADABLE <path> — <error>`, which
`review-start-check.sh` reports as exit `4`. The orchestrator asks the operator, situation-first,
with the path and the error, whether to proceed without those reviewers. Proceeding runs the round
on the reviews of the target's side alone, and the aggregation names the missing reviewers with
that reason. Stopping pauses the round until the operator has fixed the file; the step then runs
again and reads it anew.

Each review lands in a **review record**,
`<attempt-dir>/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md` — `<reviewer>` the
reviewer's name (`claude`, `codex`), `<k>` the PR's review round from `1`.

`review-start-check.sh` confirms a run began with a signal scoped to its own PR and reviewer — that
reviewer's process or a codex session rollout whose prompt names that pull request, or the
wrapper's completion marker:

| Exit | Meaning | What follows |
|---|---|---|
| `0` | started, or already completed with exit 0 | the orchestrator ends its turn and waits for the run's completion notification ([`core.md`](../core.md) > Execution Principles > *Wait discipline*) |
| `1` | no signal within the window (30 s) | launch the review again once; a second miss makes that reviewer unavailable for the round |
| `3` | the wrapper completed with a non-zero exit — the review run failed or left no record | one internal retry; a second failure makes that reviewer unavailable for the round |
| `4` | the wrapper's output carries `user-config: UNREADABLE …` — no reviewer started | the operator is asked (*An unreadable operator file* above); no relaunch |

A reviewer that is unavailable for a round — its CLI absent (PREFLIGHT reports it), its run failing
twice, or the operator's choice to proceed past an unreadable operator file — does not hold the
round: the aggregation runs on the reviews that exist, and its comment names the reviewer that is
missing and why. A round in which no configured reviewer left a record, other than by that choice of
the operator's, does not go on: it is a review-infrastructure failure, put to the operator
([`core.md`](../core.md) > Flow Control > *Advisor at a decision point*).

Cautions:

- A review that started is left to finish on its own clock, however long that takes; it is not
  relaunched because it is slow.
- Every round runs every reviewer again on each PR of the cycle whose head this cycle advanced
  (`gh pr view <N> --json headRefOid`).
- Several reviews may run at once (the host PR plus each sub-repo PR, each with its reviewers);
  each run is confirmed with its own `--pr` and, for a sub-repo PR, `--repo`.

## Review triage

Per reviewed PR, after its round's reviews complete and before *End*. While it runs the state's
marker is `review-triage`, set by the orchestrator.

### Review aggregation

**1. The reviews are aggregated by a spawned analysis role.** The orchestrator does not read the
review records or the comment body itself (Cost Control). An anonymous direct subagent —
`subagent_type: autoflow-analyzer`, on the model the policy names for `handoff-review-triage` — is
the aggregator. Its prompt names the PR as `<owner>/<name>#<N>`, the round, the record paths, any
reviewer unavailable for the round with the reason, the decision ledger, and, for a PR whose repository has
submodules, their paths (its `.gitmodules`) — the locations outside that review's target. It also
reads the reviews of the target's side from the pull request itself and names each one's author as
its source.

Its purpose is one verdict over every review of the PR. How it groups duplicates, settles a
severity the reviews disagree on, and weighs each finding (*Whether a finding holds*) is its own; what
it leaves behind is fixed:

- **One PR comment**, in Korean, per round: each finding once, with the reviewers that raised it;
  a finding only one reviewer raised kept like any other; each rejected finding listed apart with the
  grounds it does not hold; a reviewer unavailable for the round named with the reason. Its body is kept as
  `<attempt-dir>/issue-{N}-local/review/comment-<owner>.<name>-<pr>-r<k>.md`.
- **The findings file** (below).

It returns `{max_severity, findings}`.

- **[MUST] One findings file per reviewed PR.** Each PR's aggregation writes `<attempt-dir>/issue-{N}-local/review/findings-<owner>.<name>-<pr>.md` for the reviewed PR `<owner>/<name>#<pr>` — the whole identity; an owner name holds no `.`, so the first `.` separates it. A single-PR cycle follows the same rule. Only that PR's aggregation writes the file, and a later round of the same PR **overwrites** it. The file carries a `pr: <owner>/<name>#<N>` line naming the reviewed PR, exactly one `max_severity: <level>` line — the highest level among the findings that hold, `Low Confidence` included, in colon notation, `max_severity: None` when none remains (never an omitted line) — and one table row per finding, `| <Severity> | <path>:<line> | <remedy_class> | <finding> | <source> | <disposition> |` — severity first, location second (a path relative to the reviewed PR's repository root), `remedy_class` on every Medium+ row that holds, `<source>` the names of the reviewers that raised it (`claude`, `codex`, a review bot's login), and `<disposition>` empty, or `rejected` for a finding that does not hold — always the row's last cell, so a `|` quoted in the finding cell moves no cell the script reads. A `rejected` row is a record: it counts toward no verdict. `<autoflow-root>/scripts/handoff/review-gate.sh` reads the file and exits `2` on one that does not keep this contract; the aggregator is then spawned again.
- **[MUST] A PR's review covers its own repository.** A review's target is what the reviewed PR's repository tracks directly — every file of its tree, a submodule's pointer included, never a submodule's contents (`<autoflow-root>/docs/review/review.md` > Before Reviewing). Every finding therefore belongs to the reviewed PR, and its `max_severity` rests on that PR's own findings alone. A host PR whose diff is a submodule pointer is reviewed over the host repository like any other PR; the sub-repo code behind the pointer is judged by the sub-repo PR's review. A finding a review raises inside a submodule misreads that target: the aggregator rejects it as a finding that does not hold. The order in which a host PR and its sub-repo PR merge is the operator's, reported at *End*.
- **[MUST] `remedy_class` per Medium+ finding.** The aggregator tags **every** `Medium`+ finding that holds with a `remedy_class` from the same vocabulary the late-gate evaluator uses (`doc` / `test` / `impl` / `design` / `operator`, defined at [U5 Completion evaluation](completion-evaluation.md) > *FAIL routing*) and writes it in that finding's row. The classifying question is **not** how large the fix is: it is **does clearing this finding discard or change a decision the design settled?** Yes → `design`. No → the class of change that clears it. Not classifiable with confidence → `operator`, never a guess.

### The case

**2. The case is read by script.**

```
bash <autoflow-root>/scripts/handoff/review-gate.sh --issue {N} --pr <P> [--repo <owner/name>]
```

It reads the verdict (`max_severity`) and the auto-resolution attempts on record, and names the
case:

| Exit | Case | What follows |
|---|---|---|
| `0` | `clean` — no finding | *End* (once every PR of the cycle is there) |
| `13` | `low-only` — findings below `Medium` | the orchestrator's judgment, with no fixed rule: a finding that holds and is worth fixing now goes through the same resolution as below (a `Low` alone raises no advisor request unless an advisor criterion is hit); otherwise *End*, optionally with a one-line PR note that the findings were reviewed and deferred. A `Low` on a target comment's divergence or disallowed content is the orchestrator's direct commit or it is left ([U5 Completion evaluation](completion-evaluation.md) > *Code comments in a target*) |
| `10` | `resolve` — a `Medium`+ verdict | *Routing* below |
| `11` | `cap` — a `Medium`+ verdict with 7 attempts on record | pause for the operator (*Attempt cap*) |
| `2` | the findings file is absent or breaks its contract | the aggregator is spawned again |
| `3` | a `gh` read failed | run again (internal retry) |

### Whether a finding holds

Handling a finding — the reviewer's, or a gate's recommendation ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*) — weighs *does it hold?* beside *how is it cleared?* A finding does not hold when what it claims does not: it does not reproduce, the source it cites says otherwise, or it misreads a rule. It holds in part when its claim does not hold but the problem that prompted it is real; the real problem is then what gets fixed, not the claim's letter. The aggregator, the one that reads the review records, weighs each finding and writes a finding that does not hold, or holds in part, into the finding cell of its row with the grounds that show it — a command and its output, a `path:line` at a commit, a document's section and quoted sentence. A rebuttal without grounds is not a rebuttal, and the finding is handled as holding. A role the route hands a finding to that finds in its work that the finding does not hold reports it with the same grounds.

The aggregator's judgment over a reviewer finding is its disposition: a finding that does not hold is `rejected` — recorded with its grounds in the findings file and the comment, and counted toward no verdict ([ADR-0026](../records/adr/0026-aggregated-review.md)). A finding that a role the route hands it to finds does not hold is a rebuttal: the orchestrator posts it with its grounds on the PR and runs *Reviewer review* on that PR again — a new round, also when the round only rebuts and changes no code — and that round's reviews and aggregation judge it. A gate recommendation's rebuttal is judged by the recommending gate's re-score. A finding that does not hold is not routed and its `rejected` row needs no `remedy_class` — nothing reads one there — and one that holds in part is routed by the class its real problem needs. Each rebuttal is recorded with its grounds in the ledger entry of its round: the attempt's `[review-autofix]` entry, or, for a round that only rebuts and so routes nothing, an `O` entry whose heading ends in `[rebuttal]`, which no cap counts. At a gate that entry is also what an interrupted session resumes from ([U1 Preparation](preparation.md) > *Resume*). When a rebutted finding is kept and the two sides still disagree, the orchestrator asks the advisor ([`role-contracts.md`](../role-contracts.md) > Advisor; [`core.md`](../core.md) > Rule Scope, principle 3). When to ask is its judgment and no count decides it.

**This section is the rule's only home** ([`development-guideline.md`](../development-guideline.md) > Documentation Policy). Its search terms:

```
git grep -n -i -E 'rebut|holds in part|finding (that )?does not hold|whether (a|each) (finding|recommendation|item) holds'
```

### A repeated complaint

A review-response can loop: each fix answers the case the reviewer named while the property the
reviewer asserts stays unmet, and the next review names another case. No spawn checks for this on
every attempt. Whoever reads the finding — the aggregator here, or the DIAGNOSE unit — and sees that it repeats the complaint of the previous
attempt (the same property asserted, a different witness case; the previous attempt's
`[review-autofix]` entry and the previous cycle's artifacts are what it compares against) says so
where it writes the finding: in the finding's cell of the findings file, or under the analysis
report's `## Decision points`. The orchestrator then decides the re-entry — its depth, or none;
for example restating the acceptance criterion as one rule over the whole input, or a further
case-specific change — and records it with its grounds in the attempt's `[review-autofix]` entry;
where those grounds do not settle it, or it is not confident, it puts it to the advisor
([`role-contracts.md`](../role-contracts.md) > Advisor) with a request written situation-first,
and the advisor's `A` entry decides it. A
redefined criterion is recorded as `[ac-decision]` entries and the cycle restarts from DIAGNOSE on
it. A complaint already decided is not decided again without a new verified fact
([`core.md`](../core.md) > Decision Ledger). The same finding with the same witness — a fix
that did not take — is not this case; it is routed like any finding.

### Routing

A `Medium`+ verdict does not end the cycle. Route by `bash <autoflow-root>/scripts/gate/remedy-route.sh route <class>...` over the classes of the Medium+ findings that hold, in whole or in part (mixed → farthest; `operator` anywhere stops routing and goes to the advisor) — the same single owner of the mapping the late gates use:

| Route | What the orchestrator runs | Re-review |
|---|---|---|
| `ARCHITECT` (from `design`) | the design owns the moved decision; a re-entry within the cycle whose start is the orchestrator's recorded judgment (below) | *Reviewer review*, per-PR |
| `BUILD` (from `impl` / `test`) | a BUILD unit re-run naming the finding fixes it on the finding's own surface — the implementation, or the test asset ([U4 Build and verify](build.md) > *Re-entry*) | *Reviewer review*, per-PR |
| `DOC_COMMIT` (from `doc`) | orchestrator doc commit → the local run the doc diff requires | *Reviewer review*, per-PR |
| `PAUSE` (from `operator`) | the advisor fixes the class ([`role-contracts.md`](../role-contracts.md) > Advisor), and the cycle takes that class's route | that route's |

The `ARCHITECT` route is the one whose depth is judged. It re-enters within the cycle, as the cycle's other `design` re-entries do ([U3 Design](design.md) > *Re-entry*). **Where it starts, and what it re-derives and re-scores, is the orchestrator's judgment** ([`core.md`](../core.md) > Rule Scope, principle 2), recorded with its grounds in this attempt's `[review-autofix]` ledger entry before the routed work starts. While the attempt is open, `design` is recorded as `phases.gate_quality.remedy_class` ([`core.md`](../core.md) > AutoFlow State Tracking > *Remedy class recording*), so the change is not pushed before GATE:QUALITY re-scores it. The other routes are **thin**: one BUILD unit re-run or one doc commit, execution verification, a delta recorded in the ledger, and the next review round — no DIAGNOSE, no ARCHITECT, no GATE:PLAN, no fresh evaluator re-read. **Every independent check is retained on every route** — the fix is pushed and its CI confirmed as in [U6 Delivery](delivery.md) (*Push and pull request*, *CI*), the next review round judges it, and the attempt cap below applies unchanged.

Every route is recorded in `<attempt-dir>/issue-{N}-ledger.md` with a `review-autofix` marker — a level-2 heading of the form `## O<n> — <title> (cycle <C>, REVIEW) [review-autofix]` ([`decision-ledger.md`](../decision-ledger.md) > *Entry identifier*) — and the entry names the routed class and, on the `ARCHITECT` route, the judged start with its grounds. The advisor criteria below take precedence over any route.

- **Put to the advisor** (a request written situation-first per [`core.md`](../core.md) > Execution Principles > Human-decision presentation — [`role-contracts.md`](../role-contracts.md) > Advisor; the cycle does not pause) when the attempt hits **any** of: (a) the fix needs a contract or acceptance-criterion change — a finding that shows a criterion defective included — that the orchestrator cannot settle on the finding's grounds ([`decision-ledger.md`](../decision-ledger.md) > *Acceptance-criterion decisions*), (b) the fix direction is ambiguous, (c) the finding repeats the previous attempt's complaint and its grounds do not settle the re-entry (*A repeated complaint* above). The advisor's `A` entry selects re-entry. A rebutted finding kept while the two sides still disagree reaches the advisor by the orchestrator's judgment (*Whether a finding holds* above), not by a criterion here.
- **Attempt cap = 7.** The count is the number of auto-resolution attempts not yet checked with the user: the `[review-autofix]` entries in the ledger after the last entry whose heading ends in `[reentry-decision]`, or all of them when there is none. `review-gate.sh` prints it (`attempts: <k> of 7`) and exits `11` when a `Medium`+ verdict meets 7 on record: the orchestrator stops auto-resolving and pauses for the user (`active:false`, `phase:"awaiting-user"`). A gate's recommendation attempt carries its own marker, `[gate-autofix]`, on its own window ([U5 Completion evaluation](completion-evaluation.md) > *Recommendation triage*), and a `[rebuttal]` round is not an attempt, so neither is counted here. The user approving continuation at that pause is the **re-entry decision**: the orchestrator records it as an `O` entry under `operator decision` whose heading ends in `[reentry-decision]` and sets the cycle active again; the entry resets the window — the next auto-entry starts a fresh budget of 7. Nothing else resets it.
- **Durable record (host PR).** Post a one-line comment on the **host PR** via `gh pr comment <hostPR> --body "[autoflow:review-autofix] …"` for two events: (i) when the cap fired — the 7th consecutive attempt paused for the user — and (ii) when a user **re-entry decision** approved continuation (the window-reset event).

## End

Once every pull request of the cycle is clean — `review-gate.sh` reports `clean` or `low-only` on
each of them and the Low findings are triaged — and CI is green, or recorded on the pull request as
not run ([U6 Delivery](delivery.md) > *CI*), the orchestrator hands the
cycle off:

- the state file reads `active: false`, `phase: "awaiting-external-review"`, with nothing else in
  it changed.
- the report names the order in which the pull requests merge (*Merge order* below).

Cautions:

- The hand-off is not made while a pull request of the cycle has a `Medium`+ verdict.
- A pause for the user is the other `active:false` transition (`phase: "awaiting-user"`).

Report: "PR #N open (draft) — aggregated review posted — handed to external review." with
each PR's URL and head commit, and the merge order. AutoFlow ends; the session may terminate.

The cleanup that follows an external merge or rejection runs at PREFLIGHT of the next cycle in this checkout (or in the live session if it observes the decision before terminating) — the local dev branch's deletion and the attempt's completed mark; its records stay in `<attempt-dir>/`, and its remote branch and pull request are left as they are; see [U1 Preparation](preparation.md) > *What is asked*.

### Merge order

Merging is outside AutoFlow ([`external-review-sequencing.md`](../external-review-sequencing.md)).
The report names the order for the operator: a pull request with no sub-repo dependency in any
order; a host pull request whose pointer depends on a sub-repo pull request after it — the
sub-repo pull request merges first, the host is reconciled to its merge commit ([U6
Delivery](delivery.md) > *Multi-repo delivery*), and the host pull request then merges.

**[MUST]** AutoFlow merges nothing and promotes no draft; of this order it performs only the
reconcile, on the operator's request. The hook denies `gh pr merge` and a push to the default
branch.

## An attempt with no state file

The attempt of the abbreviated path ([`abbreviated-path.md`](../abbreviated-path.md)) has no state
file, and its pull request was opened from its dev branch outside a cycle. U7 reviews it alone,
entered by `/autoflow:cycle-u7 <N>`, and returns its result to the coordinating session, which
decides what follows.

- **Where it runs.** In a checkout of the repository — the same origin — whose checked-out branch
  is the attempt's dev branch at the pull request's head: the `claude` reviewer reads that working
  tree beside the pull request's diff, and `review-gate.sh` finds the attempt's record directory
  from the checkout's origin and the checked-out branch. It need not be the checkout that owns the
  attempt. The attempt and its pull request are read from the `dir:` and `pr:` lines
  `cycle-status.sh --issue <N>` prints for it in any checkout; its entry — `abbreviated <key>` in
  the owning checkout, `stop other-checkout <key>` in another — is not a condition of the review.
- **What runs.** *Reviewer review*, with `--records <attempt-dir>`; *Review aggregation*,
  unchanged — one PR comment and the findings file per round, every `Medium`+ row that holds tagged
  with its `remedy_class` — with the aggregator's prompt also naming the review records and the
  comments of the pull request's earlier rounds, which *A repeated complaint* compares against in
  place of a `[review-autofix]` entry; and *The case*, whose `case:` line is the verdict —
  `clean`, `low-only` or `resolve` (a `Medium`+ verdict). A rebuttal from the work is posted on the
  pull request with its grounds and judged by the next round's aggregation (*Whether a finding
  holds*).
- **CI.** Read with `bash <autoflow-root>/scripts/handoff/confirm-ci-green.sh --pr <P>` and returned
  as it is: green (exit `0`), red (`12`), no check published (`11`) together with whether the pull
  request records that CI does not run for it, or no verdict, not mergeable or inconclusive (`13`,
  `10`, `14`). Nothing is read as green, and the review records no not-run itself.
- **What it does not do.** No state file is created, read or required: no `review-triage` marker
  and no *End* write. A `Medium`+ row's class routes nothing — no `remedy-route.sh`, no BUILD unit
  re-run, no ARCHITECT re-entry, no `phases.gate_quality.remedy_class`, no `[review-autofix]`
  entry, no advisor criteria of *Routing*; the rework is the work outside AutoFlow. No attempt cap
  and no `[autoflow:review-autofix]` comment: `review-gate.sh`'s `attempts:` line and `cap` case
  count `[review-autofix]` entries, which the path never writes, and are not read.
- **The return.** The end report carries the pull request's URL and head commit, the verdict, the
  findings file and the round's comment, the CI result as read, and the round count: this round's
  `k`, which every review record's name carries — a new round's `k` is one more than the highest
  the attempt's review store holds for that pull request — with the rework count `k − 1`.
