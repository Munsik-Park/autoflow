# Criterion Review

An issue's acceptance criteria are reviewed against the target's code and policy before the analysis
takes them, by each attempt for itself: an attempt — one run of the issue, on its own branch and
record directory — begins with its own criterion review and stays independent of every other
attempt from that review to its pull request. The review is four modules — criterion-screen,
criterion-trace, criterion-in-depth and criterion-reconcile, each with its contract
(`<autoflow-root>/docs/contracts/criterion-*.json`), this document the procedure of all four — and
it disposes of every item it finds, with its grounds, in its review record. A disposition that
changes a criterion's content is the advisor's decision, an `[ac-decision]` entry (*Authority*
below). This is the Definition of Ready of backlog refinement: a criterion that presumes
a fact that does not hold, that conflicts with a policy already in force, or that leaves a term
undefined is found while it is still cheap to change — before a re-run, a re-score and an advisor
spawn each find it one at a time in the later work.

The review does not replace the later path for a criterion defect: the analysis still takes the
criteria as written, and from the design on a criterion is still a hypothesis the work tests
([`decision-ledger.md`](decision-ledger.md) > Decision-point entries > *A criterion can be wrong*).
The review makes that premise hold more often; it does not change it.

## The four modules

- **criterion-screen** — stage 1: the review items and the screening (*Review items*, *Screening*
  below). It writes the review record, `<out>/criterion-review.md`, and one target file per
  criterion with an in-depth target, `<out>/targets/<criterion>.md`. It is run by a session of its
  own, which reads what it judges the review needs — which code, documents and materials, the
  order, how far it follows a cause or an effect, which tool checks a fact — and records under the
  record's `## Inputs` what it read and why, and what it left out and why (Rule Scope, principle 2
  — [`core.md`](core.md)).
- **criterion-trace** — stage 2, an `autoflow-criterion-tracer` agent on the model
  `bash <autoflow-root>/scripts/spawn-policy/spawn-policy.sh model criterion-trace` names: each
  confirmed cause's reach and each required behavior's conflict with the rules in force
  (*Cause reach and rule conflict* below). It writes `<out>/trace.md`.
- **criterion-in-depth** — one run per criterion with an in-depth target, an
  `autoflow-criterion-analyzer` agent on the model `… model criterion-in-depth` names, given that
  criterion's target file and nothing else (*In-depth analysis and reconciliation* below). It writes
  `<out>/in-depth.md`.
- **criterion-reconcile** — an `autoflow-criterion-reconciler` agent on the model
  `… model criterion-reconciliation` names, given the review record, the trace and every in-depth
  file: it settles in the code each case where they differ and writes the updated record,
  `<out>/criterion-review.md`.

- **Reference model and effort.** The session that runs criterion-screen runs on Opus 5.5
  (`claude-opus-5-5`) at effort `high`; another model or effort may be used. The setting for that
  session lives here because the screen is a session's own work, not an `Agent` spawn. The agents
  take theirs from `.claude/autoflow/spawn-policy.json` like every other spawn
  ([`core.md`](core.md) > Spawn Model), the effort the one each agent definition carries. The
  record's `## Inputs` names the model and effort each module ran on.
- **What a review module writes.** Its record, and criterion-screen its target files; a decision a
  module puts to the advisor is the advisor's ledger entry (*Authority* below). A run that does not
  reach its goal writes `<out>/failure.md` in their place — what it did and why it did not reach the
  goal ([`core.md`](core.md) > Development Lifecycle).
- **Result owed**: the record's path and a one-line summary naming each decision the module put to
  the advisor, by its ledger identifier.

## Inputs

- **The issue as filed** — its body as GitHub holds it now, identified by the sha256
  `<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints, and every material the body or a
  criterion references, opened by the reviewer; one that cannot be opened is recorded with the
  reason.
- **The target's code** — each repository the issue reaches, read at a named commit (the commit the
  attempt's branch starts from unless the issue names another). In a project with sub-repos, each sub-repo is read
  at the commit the host's pointer names.
- **The target's policy** — the decision records and rule documents the criteria touch: the ADRs,
  the project's own information and rule files (a `README.md`, a `CLAUDE.local.md`, whatever the
  project keeps — [`core.md`](core.md) > Project Information), and the documents of the
  sub-repos the issue reaches.

## Purpose and scope

The review's **purpose** is to find, before the work commits to the criteria, a criterion that would
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
module's own (*The four modules* above); the record's `## Inputs` states that scope.

**What the review leaves to the later work.** The review judges the criteria against the code and policy
as they stand; it does not set how the change will be made. What shows only once an approach
exists — the change's effect on other functions, the reuse of existing code, where a
responsibility is placed, an approach that meets a rule in force — is the later work's: the design
is the design module's ([U3 Design](units/design.md)), and a change's side effects are derived at
BUILD, not predicted at design ([`evaluation-system.md`](evaluation-system.md) > GATE:PLAN: "Affected files
and side effects are not scored here"). A criterion defect found there takes the path
([`decision-ledger.md`](decision-ledger.md) > Decision-point entries > *A criterion can be
wrong*). A choice of how to make the change is neither asked here nor written into a criterion;
what a criterion keeps is the behavior a user, a caller or an operator observes.

## Stages of the review

**Stage 1** — criterion-screen — checks the criteria on the review items and screens the cases
each criterion applies to, selecting the ones for in-depth analysis. **Stage 2** — criterion-trace —
starts from what stage 1 confirmed — each cause the code shows and the behavior each criterion
requires — and asks how far they reach, assuming no fix (*Cause reach and rule conflict (stage 2)*
below). The **in-depth analysis** — criterion-in-depth — examines the selected cases, criterion by
criterion, and the **reconciliation** — criterion-reconcile — settles where a stage 2 finding or an
in-depth verdict differs from the record. Stage 2, the in-depth analysis and the reconciliation
each run in a fresh context.

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
Each module's inputs are what keeps it independent: stage 2 takes the screen's record, a
criterion's in-depth analysis its target file, and the reconciliation the record, the trace and
every in-depth file.

## Review items (stage 1)

Each criterion is checked on the items below — *Actual and expected behavior* and *Size and
separation* once for the issue as a whole; an item that does not apply to a criterion says so.
Each finding carries its grounds: a commit SHA with `path:line` for a fact of the code, or the
document, its section heading and a quoted sentence for a provision of a policy document.

| Item | The question |
|---|---|
| Code and policy fit | Does the code behave as the criterion presumes, and does the criterion agree with the policies in force (an ADR, a rule document)? A criterion that presumes a behavior the code does not have, or one that a standing policy contradicts, is a finding. |
| Cause | Where the issue reports a defect, does the criterion address only the direct cause — the point where the failure shows — or also the root cause that produces it? A criterion narrower than the cause the code shows is a finding, recorded with which of the two it covers. Establishing the cause is the analysis module's work ([U2 Analysis](units/analysis.md)); the review judges what the criterion covers against the cause the code shows. |
| Actual and expected behavior | Set side by side, does the state the criteria describe as done cover the behavior the issue reports as it actually occurs? A criterion set that covers only part of the actual behavior is a finding, recorded with the part left uncovered. |
| Contradiction | Can every criterion hold at once? Two criteria that cannot both be met, or one that undoes another, is a finding. |
| Terms and scope | Is every term a test would turn on defined — a threshold ("exceeds"), a surface ("the conversation screen"), a set ("every page")? An undefined term, or a scope with no stated bound, is a finding. |
| Size and separation | Is the issue one piece of work a single change can carry to done, or does it bundle areas that are each complete on their own — separate surfaces, separate causes, criteria that share no code or test? Several independently completable areas in one issue is a finding, recorded with the areas and a proposed split (`split`). |
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

The criterion-trace module runs as an `autoflow-criterion-tracer` agent — a fresh context that
carries none of the screen's conversation — given the issue and the review record the screen wrote.
Starting from each cause the record confirms in the code and the behavior each criterion requires,
it judges two questions:

| Question | What it judges |
|---|---|
| Cause reach | Does a confirmed cause operate beyond the points the issue reports — the same defect showing at another point, surface or element the cause reaches? A point where it does that no criterion covers is a finding. |
| Rule conflict | Does the behavior a criterion requires agree with the rules and behaviors the code already has, in every case the criterion applies to? A rule or behavior in force that keeps the required behavior from holding is a finding, recorded with the rule and the case. |

How the change will be made is not yet set, and stage 2 assumes no fix: an effect that would follow
only from a particular approach is outside it (*Purpose and scope* > *What the review leaves to the
later work*). Each finding states whether stage 1 already recorded it (`stage 1`) or stage 2 found it
(`new`), and carries its grounds as the review items' findings do. It writes `<out>/trace.md` and returns that path and a one-line
summary.

## In-depth analysis and reconciliation

**In-depth analysis.** For each criterion with an in-depth target, a fresh context examines each
target case: the criterion-in-depth module, an `autoflow-criterion-analyzer` agent, which carries
none of the screen's conversation. It is given one target file, the screen's
`targets/<criterion>.md`, holding only the issue body, the criterion's text, the target cases, each
case's code locations (`path:line`) and the commit they were read at — no verdict, grounds or
conclusion. The verdict rests on the code that decides whether and how the required behavior occurs
and the condition applied there, never on the point where it shows alone. Where the behavior occurs
only under a condition, the analysis checks whether a situation that does not meet the condition
actually arises — from which input, state or usage flow; where one does, the behavior does not hold
in that situation. It writes `<out>/in-depth.md` — per case the verdict, the deciding code and
condition, and the grounds — and returns that path and a one-line summary.

**Reconciliation.** The criterion-reconcile module, an `autoflow-criterion-reconciler` agent —
again a fresh context — is given the review record, the trace and the in-depth files. Where a stage
2 finding or an in-depth verdict differs from the record, it confirms in the code which one holds and
settles it. A criterion that does not hold in a case it applies to is a finding for that case,
recorded with the rule or condition that prevents it — never summarized as holding conditionally. An
item it cannot decide with confidence it puts to the advisor (*Authority* below). It
updates `## Findings`, `## Screening` and `## Dispositions` to match, writes
`## Cause reach and rule conflict` and `## Reconciliation`, writes the record to
`<out>/criterion-review.md`, and returns its path and a one-line summary.

**What the procedure fixes.** The artifacts — the screening, the stage 2 findings, the in-depth
verdicts and the reconciliation record — and the independence of the fresh contexts: stage 2
receives the issue and the stage 1 record and none of the screen's conversation, and the
in-depth context receives the target file and nothing of the review's verdicts or grounds. Each
context's agent definition carries its part of this document ([`core.md`](core.md) >
Context Injection); what else it reads, in what order and with which tool, is its own (Rule Scope,
principle 2 — [`core.md`](core.md)). Each agent is spawned as its `subagent_type` on the model its
policy row names ([`core.md`](core.md) > Spawn Model), at most five are in flight at once
([`core.md`](core.md) > Cost Control > *Concurrent spawns*), and its prompt states the delivery as
"return … as your report".

## Review record

`<out>/criterion-review.md`, written by criterion-screen and, updated, by criterion-reconcile, each
in its own run directory. It names the issue body reviewed by its sha256, as
`<autoflow-root>/scripts/preflight/criterion-ready.sh hash --issue N` prints it, and records what the
table below lists; the headings and the form are the module's, and a matter with nothing to record
is said to have none.

| Section | Holds |
|---|---|
| `## Inputs` | the scope the review set — what it read (each repository and the commit read, the policy documents, the materials opened) and why, and what it left out and why, a material that could not be opened included with the reason; how the review was done; and the model and effort each module ran on |
| `## Findings` | stage 1 — per criterion, each review item: `holds` or the finding, with its grounds; and *Actual and expected behavior* and *Size and separation* for the issue as a whole |
| `## Screening` | stage 1 — per criterion, each case it applies to: where the required behavior shows and the code that decides it (`path:line`), the verdict (`finding` / `holds` / `unconfirmed`), the reach of its grounds (`shows` / `decides`), and whether it is an in-depth target; a criterion with no target says so |
| `## Cause reach and rule conflict` | stage 2 — each finding, by question (cause reach / rule conflict), marked `stage 1` or `new`, with its grounds, as the reconciliation settled it — or `none` |
| `## Reconciliation` | per stage 2 finding and per in-depth case: its verdict, how the reconciliation took it — `applied`, `rejected` or `unresolved` — and the grounds, with the file it came from |
| `## Dispositions` | every item the review found — each criterion, and each problem found beyond the criteria — with the disposition the review decided, its grounds and where the item came from (`stage 1`, `stage 2` or `in-depth`). A criterion is kept, revised (with its text as revised), split (with the criteria it becomes), or excluded; one is established or added where the issue states none or lacks it; a problem found is included in this issue or separated from it. An item the module put to the advisor carries the advisor's decision as its disposition, and names the ledger entry. How the change will be made is never an item here (*Purpose and scope* > *What the review leaves to the later work*) |
| `## Unchecked` | what the review could not confirm and the tool or access it needed — or `none` |

The record is situation-first where a person reads it — to follow what was decided and why
([`core.md`](core.md) > Execution Principles > *Human-decision presentation*): what each finding means
for the issue's behavior comes before its anchors.

## Authority

The review decides the disposition of every item it finds: an item the code or a policy settles, or
one the review can reasonably choose, it decides and records with its grounds, and the dispositions
are the only list it writes. A change to a criterion's content, and an item a module of the review
cannot decide with confidence — in the record it writes, criterion-screen's or criterion-reconcile's —,
the module puts to a fresh advisor and decides as the advisor decided ([`role-contracts.md`](role-contracts.md) > Advisor;
[`core.md`](core.md) > Development Lifecycle > *Decisions within a module*); the row names the advisor's ledger entry, and an
advisor decision on a criterion's content is an `[ac-decision]` entry
([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*).

The record criterion-reconcile writes holds the review's decisions and names, by
its sha256, the body they were made on (*Review record* above). The criteria the later work takes are criteria-apply's output — the issue's criteria, as the
analysis report restates them, with the `[ac-decision]` entries applied
([`core.md`](core.md) > Development Lifecycle) —, and the review record is the evidence the decisions
were made on.

## What reads it

- **The analysis module** — the review record is one of its inputs
  ([U2 Analysis](units/analysis.md) > *Criterion review record*).
- **criteria-apply** — the `[ac-decision]` entries the dispositions that change a criterion are
  recorded as ([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*).

## Issues filed before this procedure

No issue is exempt by its filing date, and no bulk back-fill is run: an issue is reviewed when an
attempt of it is begun, and an issue taken up again after an earlier attempt is reviewed again by
the new attempt, whatever the earlier one left: every attempt begins with its own review.
