# Criterion Review — Before a New-Issue Cycle

An issue's acceptance criteria are reviewed against the target's code and policy **outside the
cycle**, before the cycle commits to them, and the operator confirms them. PREFLIGHT starts a
`new-issue` cycle only on that confirmation
([U1 Preparation](units/preparation.md) > Stop conditions > *Criterion readiness*). This is the
Definition of Ready of backlog refinement: a criterion that presumes a fact that does not hold, that
conflicts with a policy already in force, or that leaves a term undefined is found while it is
still cheap to change — before a unit re-run, a gate re-score and an advisor spawn each find it one
at a time inside the cycle.

The review does not replace the in-cycle path for a criterion defect: DIAGNOSE still takes the
criteria as written, and from ARCHITECT on a criterion is still a hypothesis the work tests
([`decision-ledger.md`](decision-ledger.md) > Decision-point entries > *A criterion can be wrong*).
The review makes that premise hold more often; it does not change it.

## When and by whom

- **When.** Any time after the issue is filed and before its first `new-issue` cycle — and again
  after any edit to the issue body, since the confirmation is bound to the body it confirmed
  (*Confirmation* below). Filing an issue ([`issue-proposal.md`](issue-proposal.md)) is not
  confirming it.
- **After an earlier cycle is cleared, never before.** An issue taken up again after its earlier
  cycle's pull request was merged or closed still has that cycle's directory
  `.autoflow/{repo-key}-issue-{N}/` until it is archived, and PREFLIGHT archives it — ledger
  included — *before* it reads criterion readiness
  ([U1 Preparation](units/preparation.md) > *What is asked*). A confirmation written into that
  directory is therefore archived with it, and PREFLIGHT stops `NOT READY`. The order is: (1) clear
  the earlier cycle — the Post-Merge Cleanup ([`git-workflow.md`](git-workflow.md) > Post-Merge
  Cleanup, `scripts/cleanup/cleanup-issue.sh <N>` for the directory), or one PREFLIGHT run, which
  clears it and then stops at criterion readiness; (2) review and confirm, into the fresh directory;
  (3) run PREFLIGHT. `criterion-ready.sh status` reports `NOT READY` while the directory still holds
  an earlier cycle's state file, so a confirmation written too early is caught when it is checked.
- **Reviewer.** The session the operator asks for the review, working with no AutoFlow cycle active
  for the issue. The review is that session's own work, and it writes no state file. What it reads and how — which code, documents and materials, the order, how far it
  follows a cause or an effect, which tool checks a fact — is its own, recorded under the record's
  `## Inputs` with what it read and why, and what it left out and why (Rule Scope, principle 2 —
  [`CLAUDE.md`](../CLAUDE.md)). The session carries stage 1 itself, the screening included; stage 2,
  the in-depth analysis and the reconciliation run in fresh contexts it spawns —
  `autoflow-criterion-tracer`, `autoflow-criterion-analyzer` and `autoflow-criterion-reconciler`
  (*Stages of the review*, *Cause reach and rule conflict (stage 2)* and *In-depth analysis and
  reconciliation* below).
- **Reference model and effort.** The review session runs on Opus 5.5 (`claude-opus-5-5`) at effort
  `high`; another model or effort may be used. The setting for the session lives here because the
  review is the session's own work, not an `Agent` spawn. Its spawns take theirs from
  `.claude/autoflow/spawn-policy.json` like every other spawn ([`CLAUDE.md`](../CLAUDE.md) > Spawn
  Model): the model each declares is read with `bash scripts/spawn-policy/spawn-policy.sh model
  criterion-trace`, `… model criterion-in-depth` or `… model criterion-reconciliation`, and the
  effort is the one its agent
  definition carries. The record's `## Inputs` names the model and effort the session and each
  spawn ran on.
- **What the reviewer never does.** It never edits the issue body or any criterion, and it never
  writes the confirmation. It records its dispositions and proposes; the operator confirms
  (*Authority* below).

## Inputs

- **The issue as filed** — its body as GitHub holds it now, identified by the sha256
  `scripts/preflight/criterion-ready.sh hash --issue N` prints, and every material the body or a
  criterion references, opened by the reviewer; one that cannot be opened is recorded with the
  reason.
- **The target's code** — each repository the issue reaches, read at a named commit (the default
  branch's head unless the issue names another). In a project with sub-repos, each sub-repo is read
  at the commit the host's pointer names.
- **The target's policy** — the decision records and rule documents the criteria touch: the ADRs,
  the project's own information and rule files (a `README.md`, a `CLAUDE.local.md`, whatever the
  project keeps — [`CLAUDE.md`](../CLAUDE.md) > Project Information), and the documents of the
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
`.autoflow/{repo-key}-issue-{N}/issue-{N}-criterion-review-stage-2.md` and returns that path and a
one-line summary.

## In-depth analysis and reconciliation

**In-depth analysis.** For each criterion with an in-depth target, a fresh context examines each
target case: an `autoflow-criterion-analyzer` spawn the review session makes, which carries none of
the session's conversation. The session hands it one target file,
`.autoflow/{repo-key}-issue-{N}/issue-{N}-criterion-review-target-<criterion>.md`, holding only the
issue body, the criterion's text, the target cases, each case's code locations (`path:line`) and
the commit they were read at — no verdict, grounds or conclusion. The verdict rests on the code
that decides whether and how the required behavior occurs and the condition applied there, never
on the point where it shows alone. Where the behavior occurs only under a condition, the analysis
checks whether a situation that does not meet the condition actually arises — from which input,
state or usage flow; where one does, the behavior does not hold in that situation. It writes
`.autoflow/{repo-key}-issue-{N}/issue-{N}-criterion-review-in-depth-<criterion>.md` — per case the
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
in-depth context receives the target file and nothing of the session's verdicts or grounds. What each context reads, in what order and with
which tool, is its own (Rule Scope, principle 2 — [`CLAUDE.md`](../CLAUDE.md)). Each spawn
declares its role by its `subagent_type` and the model its policy row names
([`CLAUDE.md`](../CLAUDE.md) > Spawn Model), at most five are in flight at once
([`CLAUDE.md`](../CLAUDE.md) > Cost Control > *Concurrent spawns*), and its prompt states the
delivery as "return … as your report".

## Review record

`.autoflow/{repo-key}-issue-{N}/issue-{N}-criterion-review.md`, written by the reviewer in the
issue's directory (the one the proposal record already lives in). Every section is present; a
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
| `## Operator decisions` | written after the operator reviews the record: each proposed change and each advisor answer `accepted` / `rejected` / `modified` — a rejected or modified advisor answer is an override — and the issue edit that applied them |

The record is situation-first where the operator reads it to decide
([`CLAUDE.md`](../CLAUDE.md) > Execution Principles > *Human-decision presentation*): what each
finding means for the issue's behavior comes before its anchors.

## Authority

Acceptance-criterion content is never the working AI's, and the review follows the same authority
as the cycle: the advisor first, the operator by review and override
([`CLAUDE.md`](../CLAUDE.md) > Rule Scope, principles 1 and 3; ADR-0025 D7). The reviewer judges
each finding and records its disposition with its grounds — a proposed change to the criterion, or
the criterion kept as written; a point the code or a policy settles, or that it can reasonably
choose, it settles and records. A point it cannot settle is a decision point: the review session
puts it to a fresh advisor by the advisor's procedure, taking the orchestrator's part, with
`cycle 0` and the phase `CRITERION-REVIEW` ([`role-contracts.md`](role-contracts.md) > Advisor);
an answer that decides a criterion's content is an `[ac-decision]` entry
([`decision-ledger.md`](decision-ledger.md) > *Acceptance-criterion decisions*), and the record
carries it under `## Open questions`. The operator reviews the record's dispositions and the
advisor's answers and accepts, rejects or modifies each — an override of an advisor answer is
recorded as any override is ([`decision-ledger.md`](decision-ledger.md) > *Advisor decisions and
operator overrides*) — and the issue body is edited to match, by the operator or by the session on
the operator's instruction. The operator confirms once every proposed change and advisor answer
has its entry under `## Operator decisions`. The criteria a cycle starts from are therefore the
issue body as the operator confirmed it, and the review record is the evidence it was confirmed on.

## Confirmation

The operator's confirmation is a decision-ledger entry in the issue's ledger
`.autoflow/{repo-key}-issue-{N}/issue-{N}-ledger.md` — an `O<n>` entry under the authority
`operator decision`, which the gate hook admits from the main session only
([`CLAUDE.md`](../CLAUDE.md) > Hook gates; grammar: [`decision-ledger.md`](decision-ledger.md) >
Decision-point entries > *Criterion-readiness confirmations*):

```markdown
## O<n> — criteria confirmed for a cycle (cycle 0, CRITERION-REVIEW) [criterion-ready]
- Decision: the acceptance criteria of #N, as the issue body now states them, are confirmed for a cycle
- Record: .autoflow/<repo-key>-issue-<N>/issue-<N>-criterion-review.md
- Issue body sha256: <criterion-ready.sh hash --issue N, run after the last edit>
- Grounds: the record's findings and each proposed change's disposition
- Authority: operator decision
```

The identifier comes from `bash scripts/ledger/ledger-entry-id.sh next <ledger> O`, called
immediately before the append ([`CLAUDE.md`](../CLAUDE.md) > Decision Ledger). `cycle 0` marks an
entry written before the issue's first cycle.

**The confirmation is bound to the body.** `scripts/preflight/criterion-ready.sh status --issue N`
reads the last `[criterion-ready]` entry and reports `READY` only when it is an `O` entry under
`operator decision`, its record exists, and its `- Issue body sha256:` equals the sha256 of the
issue body read from GitHub now. Any edit to the body after the confirmation leaves the issue not
ready until a new entry confirms the edited body; whether the edit needs the review run again, in
whole or for the changed criteria, is the operator's call, recorded in that entry's grounds.

## What reads it

- **PREFLIGHT** — in `new-issue` mode only, a fail-closed stop condition before the state file and
  the dev branch are created: it reads the fact the script reports and never judges the review's
  content ([U1 Preparation](units/preparation.md) > Stop conditions > *Criterion readiness*). A
  `review-response`, a resume or a paused cycle does not run it.
- **DIAGNOSE** — the review record is one of the U2 unit's inputs in a `new-issue` cycle
  ([U2 Analysis](units/analysis.md) > *Criterion review record*).

## Issues filed before this procedure

No issue is exempt by its filing date, and no bulk back-fill is run: an issue filed without a
confirmation is reviewed and confirmed on its turn, when it is next taken up for a `new-issue`
cycle. PREFLIGHT stops on it and reports the review as the next step. An issue that already has a
state file — a cycle active, paused, or waiting on external review — is not affected, because those
modes do not run the check. An issue taken up again in `new-issue` mode after an earlier cycle is
reviewed again, once that cycle is cleared: the archive moves its ledger, and with it any earlier
confirmation, out of the issue's directory (*When and by whom* > *After an earlier cycle is
cleared, never before*).
