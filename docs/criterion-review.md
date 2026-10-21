# Criterion Review — The First Stage of an Attempt's Cycle

An issue's acceptance criteria are reviewed against the target's code and policy in the **first
stage of the cycle**, CRITERION-REVIEW, before DIAGNOSE takes them, by each attempt for itself: an
attempt — one run of the issue, in one checkout — begins with its own criterion review and stays
independent of every other attempt from that review to its pull request. The session settles the
criteria under the policy the operator set (*Authority* below) and records the settled decisions
in a `[criterion-ready]` entry in the attempt's ledger — the stage's exit condition; PREFLIGHT
writes that attempt's state file only on that record
([U1 Preparation](units/preparation.md) > *The criterion review stage*, Stop conditions >
*Criterion readiness*). This is the
Definition of Ready of backlog refinement: a criterion that presumes a fact that does not hold, that
conflicts with a policy already in force, or that leaves a term undefined is found while it is
still cheap to change — before a unit re-run, a gate re-score and an advisor spawn each find it one
at a time inside the cycle.

The review does not replace the in-cycle path for a criterion defect: DIAGNOSE still takes the
criteria as written, and from ARCHITECT on a criterion is still a hypothesis the work tests
([`decision-ledger.md`](decision-ledger.md) > Decision-point entries > *A criterion can be wrong*).
The review makes that premise hold more often; it does not change it.

## When and by whom

- **When.** As the first stage of each attempt's cycle, inside PREFLIGHT before the attempt's state
  file — `/autoflow:cycle <N>`, or the U1 session `/autoflow:cycle-u1 <N>`, enters it on the entries `new` and `criterion-review` — and again, on
  that attempt's dev branch, after any edit to the issue body before the state file, since the
  `[criterion-ready]` entry is bound to the body it records (*Confirmation* below). Filing an issue
  ([`issue-proposal.md`](issue-proposal.md)) does not make it ready. Run alone
  (`/autoflow:criterion-review <N>`), the stage is also the entry of the abbreviated path
  ([`abbreviated-path.md`](abbreviated-path.md)): a `READY` attempt goes on by `/autoflow:cycle <N>`
  or on that path, and an attempt on that path, which never has a state file, changes a criterion by
  this review run again on its dev branch.
- **The cycle makes the attempt before the stage.** On `criterion-review` the stage reviews the
  attempt that entry names — this checkout's attempt of N with no state file: a re-review after a
  body edit, a review left unfinished — and adds its new entry to that attempt's ledger. On `new`
  the cycle creates a new attempt first, before the stage writes anything:
  `autoflow-records new --issue N` — on a clean tree, with no active attempt in this checkout — fetches
  `origin`, makes the attempt's record directory under the record root with this checkout as its
  owner, and checks out a new dev branch `dev-<date>-<time>-issue-<N>` at the latest commit of the
  attempt's base — the remote default branch, or the branch the operator names (`--base`) — or at
  the commit the operator names (`--commit`), local only and, in the full cycle, with no commit of its own until the
  attempt's state file is written. The attempt's key is that branch's name, and every record of the review — the review
  record, the stage 2 and in-depth files, the advisor records, the ledger with its
  `[criterion-ready]` entry — is in that directory, as the cycle's later records are. While an
  attempt of N with an open pull request, a paused one, or one whose review is unfinished is still
  in this checkout, the entry is that attempt's, and a new attempt is made only on the operator's
  explicit request (`/autoflow:cycle <N> new` or `/autoflow:cycle-u1 <N> new`; [U1 Preparation](units/preparation.md) > *Modes*).
  An attempt that already has a state file takes no `[criterion-ready]` entry: a criterion change
  inside its cycle is an `[ac-decision]`. An attempt begun and then left is reported by PREFLIGHT
  like any other until the operator runs it or leaves it (its branch and records stay, as a paused
  attempt's do).
- **Reviewer.** The session that runs the stage: the `/autoflow:cycle <N>` session — or the U1
  session, `/autoflow:cycle-u1 <N>` — or a `/autoflow:criterion-review <N>` session, which runs this stage
  alone and ends at its exit; no other attempt of its checkout is active. The review is that
  session's own work, and the stage writes no state file. What it reads and how — which code, documents and materials, the order, how far it
  follows a cause or an effect, which tool checks a fact — is its own, recorded under the record's
  `## Inputs` with what it read and why, and what it left out and why (Rule Scope, principle 2 —
  [`core.md`](core.md)). The session carries stage 1 itself, the screening included; stage 2,
  the in-depth analysis and the reconciliation run in fresh contexts it spawns —
  `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and `autoflow-criterion-reconciler`
  (*Stages of the review*, *Cause reach and rule conflict (stage 2)* and *In-depth analysis and
  reconciliation* below).
- **Reference model and effort.** The review session runs on Opus 5.5 (`claude-opus-5-5`) at effort
  `high`; another model or effort may be used. The setting for the session lives here because the
  review is the session's own work, not an `Agent` spawn. Its spawns take theirs from
  `.claude/autoflow/spawn-policy.json` like every other spawn ([`core.md`](core.md) > Spawn
  Model): the model each declares is read with `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model
  criterion-trace`, `… model criterion-in-depth` or `… model criterion-reconciliation`, and the
  effort is the one its agent
  definition carries. The record's `## Inputs` names the model and effort the session and each
  spawn ran on.
- **What the reviewer never does.** It never edits the issue body or a criterion except to apply
  the settled decisions, never writes the `[criterion-ready]` entry while a decision is unsettled,
  and never asks the operator to confirm, approve or re-check a settled decision or waits on the
  operator for one (*Authority*, *Report to the operator* below).

## Inputs

- **The issue as filed** — its body as GitHub holds it now, identified by the sha256
  `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints, and every material the body or a
  criterion references, opened by the reviewer; one that cannot be opened is recorded with the
  reason.
- **The target's code** — each repository the issue reaches, read at a named commit (the commit the
  attempt's dev branch starts from unless the issue names another). In a project with sub-repos, each sub-repo is read
  at the commit the host's pointer names.
- **The target's policy** — the decision records and rule documents the criteria touch: the ADRs,
  the project's own information and rule files (a `README.md`, a `CLAUDE.local.md`, whatever the
  project keeps — [`core.md`](core.md) > Project Information), and the documents of the
  sub-repos the issue reaches.

## Purpose and scope

The review's **purpose** is to find, before a cycle commits to the criteria, a criterion that would
lead the work wrong or short of done: one that presumes a fact that does not hold, conflicts with a
policy in force, leaves out part of where the cause reaches or of the behavior the issue reports,
stops at a direct cause where a root cause produces the defect, leaves a term undefined, or cannot
be shown met. Its **object** is the issue's acceptance criteria together with the behavior they
require, wherever in the code the reported cause and the required behavior reach — not only the
code a criterion names. The **quality characteristics** it evaluates are, in stage 1, the review
items below: fit with the code and policy, coverage of the reported behavior, depth of cause,
consistency, clarity, size, testability, and verified premises — and, in the screening, whether
each criterion holds in every case it applies to, judged on the code that decides the behavior;
and, in stage 2, the reach of each confirmed cause beyond the points the issue reports and the
agreement of each required behavior with the rules and behaviors the code already has.

Which code, documents and materials the review reads to judge them, and how far it reads, is the
reviewer's own (*When and by whom* > *Reviewer*); the record's `## Inputs` states that scope.

**What the review leaves to the cycle.** The review judges the criteria against the code and policy
as they stand; it does not set how the change will be made. What shows only once an approach
exists — the change's effect on other functions, the reuse of existing code, where a
responsibility is placed, an approach that meets a rule in force — is the cycle's: the design is
ARCHITECT's ([U3 Design](units/design.md)), and a change's side effects are derived at BUILD, not
predicted at design ([`evaluation-system.md`](evaluation-system.md) > Evaluation Types — Plan
evaluation (GATE:PLAN): "affected files and side effects are derived at BUILD by the build unit,
not predicted and scored here"). A criterion defect found there takes the in-cycle path
([`decision-ledger.md`](decision-ledger.md) > Decision-point entries > *A criterion can be
wrong*). A choice of how to make the change is neither asked here nor written into a criterion;
what a criterion keeps is the behavior a user, a caller or an operator observes.

## Stages of the review

**Stage 1** checks the criteria on the review items and screens the cases each criterion applies
to, selecting the ones for in-depth analysis. **Stage 2** starts from what stage 1 confirmed — each
cause the code shows and the behavior each criterion requires — and asks how far they reach,
assuming no fix (*Cause reach and rule conflict (stage 2)* below). The **in-depth analysis**
examines the selected cases, criterion by criterion, and the **reconciliation** settles where a
stage 2 finding or an in-depth verdict differs from the record. Stage 2, the in-depth analysis and
the reconciliation each run in a fresh context.

The screening is wide — every case a criterion applies to, criterion by criterion; stage 2 crosses
the criteria — a cause one criterion's cases show may operate where another criterion, or none,
applies; the in-depth analysis is deep — the code that decides each selected case. A judgment made
early in a session is carried through the rest of it: a later sign against it in the same session —
or in a session handed its record — does not reliably overturn it. A single pass also leaves out
cases the issue does not report, and rests a verdict that a behavior already exists on the point
where it shows rather than on the code that decides it (issue #442). Stage 2 therefore runs apart
from the session that wrote stage 1, so the places that session looked do not bound where stage 2
looks; it is handed the record as its starting point, and asks a question the record did not. The
in-depth analysis receives the cases and their code locations but no earlier verdict or grounds.
Stage 2 may start once stage 1's record is written, and a criterion's in-depth analysis once the
screening has selected its cases; the two may run alongside each other. The reconciliation runs
after stage 2 and every in-depth analysis, since it applies both to the record.

## Review items (stage 1)

Each criterion is checked on the items below — *Actual and expected behavior* and *Size and
separation* once for the issue as a whole; an item that does not apply to a criterion says so.
Each finding carries its grounds: a commit SHA with `path:line` for a fact of the code, or the
document, its section heading and a quoted sentence for a provision of a policy document.

| Item | The question |
|---|---|
| Code and policy fit | Does the code behave as the criterion presumes, and does the criterion agree with the policies in force (an ADR, a rule document)? A criterion that presumes a behavior the code does not have, or one that a standing policy contradicts, is a finding. |
| Cause | Where the issue reports a defect, does the criterion address only the direct cause — the point where the failure shows — or also the root cause that produces it? A criterion narrower than the cause the code shows is a finding, recorded with which of the two it covers. Establishing the cause is DIAGNOSE's work inside the cycle ([U2 Analysis](units/analysis.md)); the review judges what the criterion covers against the cause the code shows. |
| Actual and expected behavior | Set side by side, does the state the criteria describe as done cover the behavior the issue reports as it actually occurs? A criterion set that covers only part of the actual behavior is a finding, recorded with the part left uncovered. |
| Contradiction | Can every criterion hold at once? Two criteria that cannot both be met, or one that undoes another, is a finding. |
| Terms and scope | Is every term a test would turn on defined — a threshold ("exceeds"), a surface ("the conversation screen"), a set ("every page")? An undefined term, or a scope with no stated bound, is a finding. |
| Size and separation | Is the issue one piece of work a single cycle can carry to done, or does it bundle areas that are each complete on their own — separate surfaces, separate causes, criteria that share no code or test? Several independently completable areas in one issue is a finding, recorded with the areas and a proposed split (`split`). |
| Testability | Can the criterion be shown met or unmet by an observation, and does the environment provide what that observation needs? A criterion no observation can settle is a finding. |
| Estimates verified | Is each estimate the body states as fact — a cause, a reproduction, an affected path — confirmed by the code or an observation? An estimate left unconfirmed is a finding, recorded as unconfirmed rather than as wrong. |

## Screening (stage 1)

After the review items, stage 1 screens the cases each criterion applies to:

- **Cases.** For each criterion, every case it applies to: the cases the issue reports, and every
  case in which the object or the state the criterion's words name varies — another surface the
  same cause operates on, or a path where a rule already in the code could prevent the required
  behavior.
- **Locations.** For each case, where the required behavior shows, and the code that decides
  whether and how it occurs — each as `path:line` at the commit read.
- **Verdicts.** For each criterion and case: `finding`, `holds` or `unconfirmed`, with its grounds
  and how far they reach — `shows` (the point where the behavior shows) or `decides` (the code that
  decides it and the condition applied there).
- **In-depth targets.** Every `finding`, and every `holds` or `unconfirmed` whose grounds do not
  reach `decides`. A criterion with no target is recorded as such, and has no in-depth analysis.

## Cause reach and rule conflict (stage 2)

Once stage 1's record is written, one `autoflow-criterion-tracer` spawn — a fresh context that
carries none of the session's conversation — receives the issue body and the stage 1 record.
Starting from each cause the record confirms in the code and the behavior each criterion requires,
it judges two questions:

| Question | What it judges |
|---|---|
| Cause reach | Does a confirmed cause operate beyond the points the issue reports — the same defect showing at another point, surface or element the cause reaches? A point where it does that no criterion covers is a finding. |
| Rule conflict | Does the behavior a criterion requires agree with the rules and behaviors the code already has, in every case the criterion applies to? A rule or behavior in force that keeps the required behavior from holding is a finding, recorded with the rule and the case. |

How the change will be made is not yet set, and stage 2 assumes no fix: an effect that would follow
only from a particular approach is outside it (*Purpose and scope* > *What the review leaves to the
cycle*). Each finding states whether stage 1 already recorded it (`stage 1`) or stage 2 found it
(`new`), and carries its grounds as the review items' findings do. It writes
`<attempt-dir>/issue-{N}-criterion-review-stage-2.md` and returns that path and a
one-line summary.

## In-depth analysis and reconciliation

**In-depth analysis.** For each criterion with an in-depth target, a fresh context examines each
target case: an `autoflow-criterion-analyzer` spawn the review session makes, which carries none of
the session's conversation. The session hands it one target file,
`<attempt-dir>/issue-{N}-criterion-review-target-<criterion>.md`, holding only the
issue body, the criterion's text, the target cases, each case's code locations (`path:line`) and
the commit they were read at — no verdict, grounds or conclusion. The verdict rests on the code
that decides whether and how the required behavior occurs and the condition applied there, never
on the point where it shows alone. Where the behavior occurs only under a condition, the analysis
checks whether a situation that does not meet the condition actually arises — from which input,
state or usage flow; where one does, the behavior does not hold in that situation. It writes
`<attempt-dir>/issue-{N}-criterion-review-in-depth-<criterion>.md` — per case the
verdict, the deciding code and condition, and the grounds — and returns that path and a one-line
summary.

**Reconciliation.** After stage 2 and every in-depth analysis, one `autoflow-criterion-reconciler`
spawn — again a fresh context — receives the review record, the stage 2 file and the in-depth
files. Where a stage 2 finding or an in-depth verdict differs from the record, it confirms in the
code which one holds and settles it. A criterion that does not hold in a case it applies to is a
finding for that case, recorded with the rule or condition that prevents it — never summarized as
holding conditionally. It updates `## Findings`, `## Screening`, `## Proposed changes` and
`## Open questions` to match, writes `## Cause reach and rule conflict` and `## Reconciliation`,
and returns the record's path and a one-line summary.

**What the procedure fixes.** The artifacts — the screening, the stage 2 findings, the in-depth
verdicts and the reconciliation record — and the independence of the fresh contexts: stage 2
receives the issue body and the stage 1 record and none of the session's conversation, and the
in-depth context receives the target file and nothing of the session's verdicts or grounds. Each context's agent definition carries its part of this document ([`core.md`](core.md) >
Context Injection); what else it reads, in what order and with which tool, is its own (Rule Scope,
principle 2 — [`core.md`](core.md)). Each spawn
declares its role by its `subagent_type` and the model its policy row names
([`core.md`](core.md) > Spawn Model), at most five are in flight at once
([`core.md`](core.md) > Cost Control > *Concurrent spawns*), and its prompt states the
delivery as "return … as your report".

## Review record

`<attempt-dir>/issue-{N}-criterion-review.md`, written by the reviewer in the
attempt's record directory (`autoflow-records dir` on its dev branch). Every section is present; a
section with nothing to record says `none`.

| Section | Holds |
|---|---|
| `## Inputs` | the issue body sha256 reviewed; the scope the reviewer set — what it read (each repository and the commit read, the policy documents, the materials opened) and why, and what it left out and why, a material that could not be opened included with the reason; how the review was done; and the model and effort the session and each stage 2, in-depth analysis and reconciliation spawn ran on |
| `## Findings` | stage 1 — per criterion, each review item: `holds` or the finding, with its grounds; and *Actual and expected behavior* and *Size and separation* for the issue as a whole |
| `## Screening` | stage 1 — per criterion, each case it applies to: where the required behavior shows and the code that decides it (`path:line`), the verdict (`finding` / `holds` / `unconfirmed`), the reach of its grounds (`shows` / `decides`), and whether it is an in-depth target; a criterion with no target says so |
| `## Cause reach and rule conflict` | stage 2 — each finding, by question (cause reach / rule conflict), marked `stage 1` or `new`, with its grounds, as the reconciliation settled it — or `none` |
| `## Reconciliation` | per stage 2 finding and per in-depth case: its verdict, how the reconciliation took it — `applied`, `rejected` or `unresolved` — and the grounds, with the file it came from |
| `## Proposed changes` | per finding that calls for one, from either stage or the reconciliation: the criterion, the disposition (`excluded` / `revised` / `split` / `added`), the proposed text, the grounds and where the finding came from (`stage 1`, `stage 2` or `in-depth`) — or `none` |
| `## Open questions` | each point the review could not settle itself (what a term is meant to cover, which of two readings the issue intends) and put to the advisor (*Authority* below): the question, stated as the behavior it concerns, why the code and policy do not settle it, each option with what it changes in the criteria, and the advisor's answer with its ledger entry — or `none`. How the change will be made is never a question here (*Purpose and scope* > *What the review leaves to the cycle*) |
| `## Unchecked` | what the review could not confirm and the tool or access it needed — or `none` |
| `## Operator decisions` | each decision the operator gave when they chose to — an override of an advisor answer (with its `O` override entry) or of a disposition, or an instruction (a re-run and its scope, a text) — with what it changed; or `none`. It is not an item-by-item operator verdict on the dispositions and advisor answers, and the `[criterion-ready]` entry does not wait on it (*Authority* below) |
| `## Session decisions` | the session's own judgments after the review, apart from the operator's decisions: each detail an operator decision leaves open, with its grounds; whether the review was run again and over what scope when the body the entry records differs from the one `## Inputs` names, with its grounds (*Confirmation* below); and the issue edit that applied the decisions, with the edited body's sha256 — or `none` |

The record is situation-first where the operator reads it — to follow what was decided and to
override any of it ([`core.md`](core.md) > Execution Principles > *Human-decision presentation*):
what each finding means for the issue's behavior comes before its anchors.

## Authority

The review follows the same authority over acceptance-criterion content as the cycle, under the
policy the operator set for it: the review session judges, the advisor decides a point the session
cannot settle or is not confident of, and the operator overrides when they choose
([`core.md`](core.md) > Rule Scope, principles 1 and 3). The reviewer judges
each finding and records its disposition with its grounds — a proposed change to the criterion, or
the criterion kept as written; a point the code or a policy settles, or that it can reasonably
choose, it settles and records. A point it cannot settle, or is not confident of, is a decision point: the review session
puts it to a fresh advisor by the advisor's procedure, taking the orchestrator's part, with
`cycle 0` and the phase `CRITERION-REVIEW` ([`role-contracts.md`](role-contracts.md) > Advisor);
an answer that decides a criterion's content is an `[ac-decision]` entry
([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*), and the record
carries it under `## Open questions`. The advisor's answer is itself the decision: it is applied
as recorded and does not wait on the operator's review.

The operator overrides an advisor answer or a disposition, or gives an instruction, when they
choose; it is recorded under `## Operator decisions`, an override of an advisor answer also as any
override is ([`decision-ledger.md`](decision-ledger.md) > *Advisor decisions and operator
overrides*). A detail an operator decision does not itself settle — one that does not change the
decision — is the session's to judge: the session records it with its grounds under
`## Session decisions`, as its own judgment apart from the operator's decision. Such a detail is
not an item for an operator verdict and is not put back to the operator; a detail the session
cannot settle, or is not confident of, goes to the advisor first.

Once every decision is settled — each disposition, each advisor answer and each operator decision
given — the session edits the issue body to match and records the `[criterion-ready]` entry
(*Confirmation* below), without waiting on an operator response or confirmation. The condition for
the entry is that the decisions are settled, not an operator verdict on each of them. The operator
is asked only for a harness-level block ([`role-contracts.md`](role-contracts.md) > Advisor >
*Decision points and harness-level blocks*). The criteria a cycle starts from are therefore the
issue body as those decisions left it, and the review record is the evidence they were made on.

## Confirmation

The confirmation — the `[criterion-ready]` entry — is the record of the decisions made under the
policy the operator set (*Authority* above). The review session writes it once every decision is
settled, as a decision-ledger entry in the attempt's ledger
`<attempt-dir>/issue-{N}-ledger.md` — an `O<n>` entry under the authority
`operator decision`, which the gate hook admits from the main session only
([`state-tracking.md`](state-tracking.md) > Hook gates; grammar: [`decision-ledger.md`](decision-ledger.md) >
Decision-point entries > *Criterion-readiness confirmations*):

```markdown
## O<n> — criteria settled for a cycle (cycle 0, CRITERION-REVIEW) [criterion-ready]
- Decision: the acceptance criteria of #N, as the issue body now states them, are settled for a cycle
- Record: issue-<N>-criterion-review.md
- Issue body sha256: <criterion-ready.sh hash --issue N, run after the last edit>
- Grounds: the decisions recorded — the dispositions, the advisor answers (their A entries), any operator decision, the session decisions — and, when the body differs from the one ## Inputs names, the re-run judgment under ## Session decisions
- Authority: operator decision
```

The identifier comes from `bash <autoflow-root>/scripts/ledger/ledger-entry-id.sh next <ledger> O`, called
immediately before the append ([`core.md`](core.md) > Decision Ledger). `cycle 0` marks an
entry written before the attempt's state file — in its criterion review stage, ahead of the cycle
number the state file starts at. `- Record:` names a file in the attempt's record
directory, by its name alone: a path to another attempt's record is not read.

**The confirmation is bound to the attempt and to the body.** `<autoflow-root>/scripts/preflight/criterion-ready.sh status --issue N`
reads the last `[criterion-ready]` entry in the ledger of the attempt on the checked-out dev branch
(`--branch` names another) — never another attempt's — and reports `READY` only when the attempt
has no state file yet, the entry is an `O` entry under `operator decision`, its record exists, and
its `- Issue body sha256:` equals the sha256 of the issue body read from GitHub now. Any edit to the
body after the entry leaves the attempt not ready until its own review runs again and a new entry
in its ledger records the edited body — another attempt's entry, of this checkout or another, never
stands in for it — written as the first one is: once the decisions are
settled — an operator override included — with no operator confirmation asked. When the body an
entry records differs from the body the record read (the sha256 under `## Inputs`) — an edit after
an entry, or a body edited before the first entry to apply the decisions — whether the review is run
again, and over what (in whole, the changed criteria only, or not at all), is the session's
judgment: it records the judgment with its grounds under `## Session decisions`, and the new entry's
grounds point to it. The session does not ask the operator for it. An operator instruction on the
re-run or its scope is the decision; a session that cannot settle it, or is not confident of it,
asks the advisor.

## Report to the operator

The review session's report to the operator is situation-first ([`core.md`](core.md) >
Execution Principles > *Human-decision presentation*) and tells what the session decided as
recorded — "recorded", not a request: the dispositions; each advisor answer with its `A` entry; each operator
decision applied; the session decisions — the details within an operator decision and the re-run
judgment; and the edited body's sha256 with the `[criterion-ready]` entry. The only thing it asks
the operator is a harness-level block ([`role-contracts.md`](role-contracts.md) > Advisor >
*Decision points and harness-level blocks*), and it asks for no other confirmation, approval or
review: an override is the operator's to give when they choose, not something the report requests.
`## Unchecked` is reported as fact and is put to the operator only where it is a harness-level
block. While a harness-level block leaves a decision unsettled, the entry is not written and the
report says which decision waits on it. A report after an operator override or instruction takes
the same form.

## What reads it

- **PREFLIGHT** — the stage's exit, read again on an attempt's start only, as a fail-closed
  condition before the state file is created: it reads the fact the script reports for that attempt
  and never judges the review's content ([U1 Preparation](units/preparation.md) > Stop conditions >
  *Criterion readiness*). A `review-response`, a resume or a paused cycle does not run it.
- **DIAGNOSE** — the attempt's review record is one of the U2 unit's inputs in a `new-issue` cycle
  ([U2 Analysis](units/analysis.md) > *Criterion review record*).
- **The abbreviated path** — its start: an attempt goes on outside a cycle on its
  `[criterion-ready]` entry for the current body, and `cycle-status.sh` reports it
  `criterion-review` while the entry is not valid ([`abbreviated-path.md`](abbreviated-path.md)).

## Issues filed before this procedure

No issue is exempt by its filing date, and no bulk back-fill is run: an issue filed without a
`[criterion-ready]` entry is reviewed on its turn, when an attempt of it is next begun — its cycle's
criterion review stage — and the review records the entry once its decisions are settled. An issue that already has a
state file — a cycle active, paused, or waiting on external review — is not affected, because those
modes do not run the check. An issue taken up again after an earlier attempt is reviewed again by
the new attempt, whatever the earlier one left: every attempt begins with its own review (*When and
by whom* > *The cycle makes the attempt before the stage*). A `[criterion-ready]` entry a target recorded inside its
tree before the record root (`.autoflow/<repo-key>-issue-<N>/`) belongs to no attempt and is not
read: a new attempt's own criterion review stage records its own.
