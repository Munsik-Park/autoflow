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
  for the issue. The review is that session's own work; it spawns no AutoFlow role and writes no
  state file. What it reads and how — which code, documents and materials, the order, how far it
  follows a cause or an effect, which tool checks a fact — is its own, recorded under the record's
  `## Inputs` with what it read and why, and what it left out and why (Rule Scope, principle 2 —
  [`CLAUDE.md`](../CLAUDE.md)). The session carries both stages of the review (*Two stages in one
  session* below).
- **Reference model and effort.** The review session runs on Opus 5.5 (`claude-opus-5-5`) at effort
  `high`; another model or effort may be used, and the record's `## Inputs` names the one the
  session ran on. The setting lives here because the review is the session's own work, not an
  `Agent` spawn: `.claude/autoflow/spawn-policy.json` assigns models to spawns through the agent
  definitions they load.
- **What the reviewer never does.** It never edits the issue body or any criterion, and it never
  writes the confirmation. It proposes; the operator decides (*Authority* below).

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
policy in force, leaves out part of what the change affects or of the behavior the issue reports,
stops at a direct cause where a root cause produces the defect, leaves a term undefined, or cannot
be shown met. Its **object** is the issue's acceptance criteria together with the change they call
for, wherever that change reaches — not only the code a criterion names. The **quality
characteristics** it evaluates are, in stage 1, the review items below: fit with the code and
policy, coverage of the reported behavior, depth of cause, consistency, clarity, size, testability,
and verified premises; and, in stage 2, those of the impact analysis: the change's impact, reuse,
consistency with what is in force, and structural balance.

Which code, documents and materials the review reads to judge them, and how far it reads, is the
reviewer's own (*When and by whom* > *Reviewer*); the record's `## Inputs` states that scope.

## Two stages in one session

The review runs as two stages in one session. **Stage 1** checks the criteria on the review items
and records the resolution approach — how the change the criteria call for would be achieved.
**Stage 2**, the impact analysis, takes that approach as applied and evaluates what the change does
across the codebase. The order follows from what each stage can judge: the effect of a change can
be evaluated once the approach to the change is set, and stage 1 is where it is set. Stage 2 works
in the same session from stage 1's record, so what stage 1 confirmed — a cause, a policy in force,
the approach — is its starting point.

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

## Resolution approach (stage 1)

After the review items, stage 1 records how the change the criteria call for would be achieved,
each element with its grounds:

| Element | What it records |
|---|---|
| Approach | how the change resolves what the criteria require |
| Change location | the components, modules and layers the change lands in, and the responsibility it places in each |
| Behavior change | what users, callers and operations observe before and after the change — the intended change and the changes that come with it |
| Premises and constraints | the rules, contracts and interfaces the approach relies on or touches, and the work, data or configuration it presupposes |
| Method | how the work would carry the approach out |
| Tools | the tools the work would need |

The record states the change at the depth of components and their responsibilities; the files a
change touches are derived at BUILD ([U3 Design](units/design.md) > Output artifacts). The approach
is the premise stage 2 evaluates; settling it and comparing alternatives belong to the cycle's
ARCHITECT ([U3 Design](units/design.md)). Where the choice between approaches turns on the
operator's intent, it is recorded as an open question (*Review record* below).

## Impact analysis (stage 2)

Stage 2 takes stage 1's approach as applied and evaluates what the change does across the codebase.
Its scope is the points the approach changes directly and everything in the codebase the change
reaches once applied. Its purpose is to find, while the criteria can still change, an effect of the
change that the criteria leave unaddressed. It evaluates the quality characteristics below.

| Characteristic | The question |
|---|---|
| Impact | With the approach applied, what does the change do to other functions, to their users, and to operations — including each point besides the one the issue reports where the confirmed cause operates? Does a criterion address each such effect? An effect no criterion addresses is a finding. |
| Reuse | Does code or a rule already in the codebase provide the behavior the approach would add, or part of it? A behavior the approach would build again is a finding, recorded with what already provides it. |
| Consistency | Does the approach agree with the rules, structures and contracts in force, and does the behavior a criterion requires agree with the rules and behaviors the code already has? A disagreement is a finding, recorded with the rule or behavior it meets. |
| Structural balance | Does the approach place each responsibility where the codebase's composition places responsibilities of its kind, keeping the load across modules and layers as the composition distributes it? A placement that departs from that composition is a finding, recorded with the composition it departs from. |

Each finding states whether stage 1 already recorded it (`stage 1`) or stage 2 found it (`new`),
and carries its grounds as the review items' findings do. A finding that calls for a change to the
criteria is recorded as a proposed change or an open question for the operator's decision: in a
cycle the review record is read as an input, and what binds the cycle is the criteria the operator
confirmed ([U2 Analysis](units/analysis.md) > *Criterion review record*; *Authority* below).

## Review record

`.autoflow/{repo-key}-issue-{N}/issue-{N}-criterion-review.md`, written by the reviewer in the
issue's directory (the one the proposal record already lives in). Every section is present; a
section with nothing to record says `none`.

| Section | Holds |
|---|---|
| `## Inputs` | the issue body sha256 reviewed; the scope the reviewer set — what it read (each repository and the commit read, the policy documents, the materials opened) and why, and what it left out and why, a material that could not be opened included with the reason; how the review was done; and the model and effort the session ran on |
| `## Findings` | stage 1 — per criterion, each review item: `holds` or the finding, with its grounds; and *Actual and expected behavior* and *Size and separation* for the issue as a whole |
| `## Approach` | stage 1 — the resolution approach: approach, change location, behavior change, premises and constraints, method and tools, each with its grounds |
| `## Impact analysis` | stage 2 — each characteristic: `holds` or the finding, marked `stage 1` or `new`, with its grounds |
| `## Proposed changes` | per finding that calls for one, from either stage: the criterion, the disposition (`excluded` / `revised` / `split` / `added`), the proposed text, the grounds and the stage the finding came from — or `none` |
| `## Open questions` | each question that neither the code nor a policy settles and that only the operator's intent can answer (what a term is meant to cover, which of two readings the issue intends): the question, why the code and policy do not settle it, and each option with what it changes in the criteria and the work — or `none` |
| `## Unchecked` | what the review could not confirm and the tool or access it needed — or `none` |
| `## Operator decisions` | written after the operator decides: each proposed change `accepted` / `rejected` / `modified`, each open question's answer (the option taken, or the operator's own), and the issue edit that applied them |

The record is situation-first where the operator reads it to decide
([`CLAUDE.md`](../CLAUDE.md) > Execution Principles > *Human-decision presentation*): what each
finding means for the issue's behavior comes before its anchors.

## Authority

Acceptance-criterion content is never the working AI's ([`CLAUDE.md`](../CLAUDE.md) > Rule Scope,
principle 1). Inside a cycle the advisor decides it first so that the cycle keeps moving, and the
operator may override at the retry stage. Outside the cycle there is no forward path to keep
moving, so the **operator decides directly**: each proposed change is accepted, rejected or
modified by the operator, and the issue body is edited to match — by the operator, or by the
session on the operator's instruction. An open question is answered the same way, and its answer
is written into the criteria it bears on, so the cycle does not meet it again as a decision point;
the operator confirms once every proposed change and open question has its entry under
`## Operator decisions`. The criteria a cycle starts from are therefore the issue
body as the operator confirmed it, and the review record is the evidence it was confirmed on.

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
