# ADR-0025: Six functional units, each prescribed by its goal and its verification only

## Status

Accepted (operator verdict 2026-10-02, issue #369: steps 1–6 measured together on four llmroute issues, no step rolled back). Operator decisions 2026-09-28 recorded in D5, D6, D7 and D9; D8 amended by operator decisions 2026-09-29 and 2026-10-01; D1 and D3 amended by operator decision 2026-10-01, issue #392; D2 amended by operator decision 2026-10-02, issue #399; D1, D3, D4 and D6 amended by operator decision 2026-10-04, issue #421.

## Context

AutoFlow prescribes sixteen phases and, inside them, the method of each: a two-participant relay
for design, a per-round report from each participant, a Discussion Protocol, a fresh role spawn
per phase with a fixed derivation on entry, and an orchestrator that executes HANDOFF step by
step. The cost of that prescription was measured over the cycle issues the metrics collector
recorded (`scripts/metrics/cycle-metrics.py`, issue #268): 68 issues, 14.95B tokens; the relay
era (issue #179 onward) is 30 issues, 6.94B tokens, 231M tokens per issue.

- **Where the tokens go.** Grouping the phases into the six units whose ends are recorded gates:
  U1 PREFLIGHT 1.9%, U2 DIAGNOSE + GATE:HYPOTHESIS 4.6%, U3 ARCHITECT + GATE:PLAN 27.4%, U4
  DISPATCH..VALIDATE + AUDIT 45.8%, U5 GATE:QUALITY 7.4%, U6 DELIVER + INTEGRATE + HANDOFF 12.9%
  (relay era). Prompt-cache hit is 95–98% in every unit, so the volume is not a caching defect:
  it is calls × context, and the prescribed method sets both.
- **The prescribed dialogue is mostly not decision content.** In eight relay transcripts read
  and classified by character share, 27% is new decision content, 10% a real correction and 11%
  evidence; 38% is restatement, 8% protocol ceremony and 6% dispute whose design outcome is the
  same either way. The per-round reports are 27% of the transcript volume and 92% restatement.
  The two opening turns of a round carry 79% of the substance. 37% of transcript text sits in
  re-discussion rounds, 13 of whose 21 Briefs followed a GATE:PLAN FAIL.
- **The prescribed phase boundaries re-derive.** In U4 about 40% of the files a spawn reads were
  already read by an earlier spawn of the same issue (the design documents, `phase-b.md`, the
  ledger, `CLAUDE.md`); 0.97B tokens were spent before a RED / GREEN / REFINE spawn's first edit.
- **The prescribed execution carries the whole context.** U6 is 85% orchestrator: a median 61
  calls per issue at 400–500k tokens of context each, for steps that are deterministic.
- **The prescribed method does not buy correctness.** Issue #273 ran five llmroute issues both
  ways from the same base commit: AutoFlow $754.27, operator-led work $60.74 (about 12×).
  AutoFlow was adopted in four of five and asked the operator 0–3 decisions per issue against
  2–8; neither arm was defect-free. On llmroute#630 the design misread an asset and GATE:PLAN
  (8.25), AUDIT (8.40) and GATE:QUALITY (8.60) all passed it: a verification design fixed by the
  procedure could not be built for that issue. Errors that re-opened a design round were caught
  by gates, evaluators, VALIDATE and the reviewer, not by the two participants checking each
  other.

`CLAUDE.md` > Rule Scope already separates the two kinds of rule — "A rule exists only to bind
authority and to prevent self-certification" and "Which route to take, which tests to run, and
how far the work reaches are the working AI's judgment". The method prescriptions above are of
the second kind written as rules of the first.

## Decision

**D1 — Six functional units replace the sixteen phases as the unit of prescription (U4 Exit
amended by operator decision 2026-10-01, issue #392).**

| Unit | Former phases | Exit |
|---|---|---|
| U1 Preparation | PREFLIGHT | deterministic checks |
| U2 Analysis | DIAGNOSE, GATE:HYPOTHESIS | `gate_hypothesis` — one form for every issue, hook-gated for a bug issue (amended, issue #421) |
| U3 Design | ARCHITECT, GATE:PLAN | `gate_plan` |
| U4 Build and verify | DISPATCH, RED, GREEN, VERIFY, REFINE, VALIDATE, AUDIT | `audit` (its evaluator judges test-first) |
| U5 Completion evaluation | GATE:QUALITY | `gate_quality` |
| U6 Delivery | DELIVER, INTEGRATE, HANDOFF | CI green + configured-reviewer review clean |

A unit ends at a recorded gate, so a unit boundary is the point a new session resumes from.

**D2 — A unit is prescribed by four things only: its goal, its artifact contract, its
verification and its loop cap (evaluator clause added by operator decision 2026-10-02, issue
#399).** How the unit reaches the goal — what it reads, whether it
spawns helpers, whether it holds a dialogue, how it designs the issue's own verification — is the
unit agent's, recorded with its grounds in the unit's artifact (Rule Scope, principle 2). The
artifact contract names only what the verification needs. Relay, transcript grammar, per-round
reports, the Discussion Protocol as a required form, the per-phase fresh spawn, RED's derivation
steps and HANDOFF's step-by-step orchestrator execution are retired as prescriptions.

The latitude over method is the unit's and does not extend to the evaluator that verifies it: what
the evaluator confirms, the evidence a confirmation rests on and how far it goes, scaled to the size
and risk of the change, are prescribed in the evaluator's own document, which holds every gate's
rubric (`docs/evaluation-system.md` > *The evaluator's standard*). The gate evaluator and the
configured reviewer stay two quality procedures, neither replacing the other: the evaluator judges
the units' artifacts and holds the gate authority; the reviewer reviews each delivered pull
request's result.

**D3 — The authority rules stay as they are (amended by operator decisions 2026-10-01, issue
#392, and 2026-10-04, issue #421).** The push / `gh pr create` gate, the merge prohibition, the gate
score thresholds, the re-entry caps — GATE:HYPOTHESIS's excepted (issue #421): its FAIL re-entry is
the orchestrator's judgment with no count, and a PASS judged unreachable goes to the advisor and, on
its judgment, to the operator to confirm the close — evaluator independence (fresh spawn, never the author), the evidence rule (a run's
evidence is its log) and the lint-chain obligation at commit. A rule that existed to prevent
self-certification through a method is judged by the unit's independent evaluator, not enforced by
splitting two roles: the AUDIT evaluator judges the test-first rule from the build report and git as
"the Red run precedes the implementation commit and its failure is shown by its log", and a test
not so confirmed re-runs the unit on the AUDIT FAIL counter. No script reads the evidence in its place:
how a repository records it differs from one repository to the next, and the evaluator reads it
where the repository keeps it.

**D4 — AI imperfection is covered by three layers of verification, not by method.**
(1) The unit loop: a fresh evaluator scores the unit's artifacts; a FAIL returns its findings and
the previous artifacts to the unit agent, up to the existing caps — at GATE:HYPOTHESIS, until a PASS or the advisor's judgment that none is reachable (issue #421). (2) External verification: CI
and the configured reviewer. (3) Human verification at the pause points, as D7 routes them.

**D5 — The orchestrator sequences units and runs on Opus (operator decision).** It spawns one
fresh unit agent per unit with the goal and artifact paths, spawns the evaluator on return,
records the score and routes. It does not execute unit work, so its context stays small. A spawn
made by a unit agent is not restricted: it inherits the unit's gate class (operator decision 1).

**D6 — State (operator decisions 2 and 4; amended by operator decision 2026-10-04, issue #421).**
The four gated keys are kept as the unit exit gates (`gate_hypothesis`, `gate_plan`, `audit`,
`gate_quality`), so the hook's validator and the Resume procedure ("re-enter after the last passed
gate") carry over. GATE:HYPOTHESIS is one form for every issue, recorded under `gate_hypothesis`,
which replaces `gate_hypothesis_structure` and `gate_hypothesis_cause` (issue #421). A non-bug issue
keeps the `skipped (non-bug issue)` verdict for U2: the hook admits its ARCHITECT spawn without
reading the scores, and the orchestrator judges the PASS.

**D7 — An advisor makes the first judgment; the operator joins at the retry stage (operator
decision 3).** Every point that today pauses for an operator decision — an acceptance-criterion
change, a non-code root cause, an un-agreed design point, a `remedy_class: operator`, a
recommendation or finding the orchestrator cannot route with confidence — is answered first by a
dedicated advisor sub-agent: the highest-capability model at the highest effort, the effort
delivered by its agent definition's `effort:` line. Its answer is applied and recorded as a
ledger entry with its grounds, and the cycle continues. Two grounds: the orchestrator runs the
sequence, so a judgment's material stays out of its context; and a first judgment exists before
the operator is asked. The cycle stops for the operator only on what AI cannot perform — a call
blocked at the harness level (a permission denial, a tool or credential the environment does
not provide). Operator judgment moves from the forward path to the retry stage: when a unit loop
FAILs, a re-entry opens or a cap is reached, the operator may review the advisor's recorded
answers and override them, and that override is the authority (an `O` ledger entry, `operator
decision`). Claude Code's advisor tool (`advisorModel`, https://code.claude.com/docs/en/advisor)
is also enabled for in-task consultation; its model is configurable and its effort is not, which
is why the first-judgment advisor is a sub-agent. `CLAUDE.md` > Rule Scope, principle 1 names
acceptance-criterion content as the operator's; it is amended in the same change as the device
(Rule Scope, principle 4) to "the operator's by override at the retry stage, the advisor's first".

**D8 — A script reads and reports; every change is the orchestrator's own (amended by operator
decisions 2026-09-29 and 2026-10-01, issue #385).** The direction of this ADR is to stop fixing the
AI's method and state only what is asked. A method fixed in a script fits one repository shape and
misfits the next, and each case added to the script calls for another. So in U1 and U6 a script
confirms facts and reports them — the cycle's state files against their branches and pull requests,
CI on the PR head, which CI job ran an added test file, whether the reviewer run began, the review
triage case and its attempt count — and changes nothing: not git, not GitHub, not the cycle's state
under `.autoflow/`; it writes only its own report or log. What changes state — fetching and
syncing, clearing an earlier cycle, creating the dev branch and the state file, the review-response
setup, pushing, opening the pull request, attaching a label, the state transitions — is done by the
orchestrator directly, and the playbook gives it as direction: what is asked, the cautions, the
result owed, with no fixed order or command. `git push` and `gh pr create` in particular are issued
by the orchestrator as those commands, because the gate hook reads the command it issues. The
fail-closed checks that existed before stay as they are (`drift-check.sh`,
`check-review-backend.sh`, `local-checks.sh`, `confirm-ci-green.sh`, `codex-review-pr.sh`). Where an
interrupted cycle resumes is the orchestrator's judgment over the reported facts. The committer and
PR opener stay the orchestrator. AI judgment in U6 is kept for routing a reviewer finding and
classifying a CI failure.

**D9 — Migration (operator decision: operator-led sessions, not AutoFlow cycles).** On `main` in
small PRs, each released and installed (`/plugin marketplace update` → `/plugin update` →
re-stamp) before the next. The starting point is a version bump that releases what merged after
the last bump (0.2.17), tagged; rollback is a forward revert release from that tag; a version is
switched only while every state file reads `active:false`. Order: 0 baseline + this ADR; 1 common
frame (hook, state, agent definitions, spawn policy, collector keys); 2 U3; 3 U4; 4 U2; 5 U6/U1
scripts; 6 U5 and the document consolidation (sixteen playbooks → six unit documents). Each step
is measured against the baseline (tokens per issue per unit, gate first-pass rate, reviewer
Medium+ per PR, operator decisions per issue) on three to five real issues; a step whose reviewer
Medium+ rises above the baseline, or whose unit tokens do not fall, is rolled back.

## Alternatives Considered

- **Trim the procedure** (drop the reports, shorten closing turns, bound re-discussion). Estimated
  at 4–6% of relay-era tokens for the three dialogue items; the method stays prescribed and the
  issue-specific verification design stays impossible.
- **Keep the procedure, add an advisor.** Adds a stronger opinion without removing the cost that
  the prescription creates.
- **Operator-led work only (#273 arm B).** About 12× cheaper, but moves 2–8 decisions per issue
  back to the operator; D4 and D7 keep the verification and the autonomy.

## Consequences

### Positive

- The cost the prescription creates (relay, reports, re-derivation, large-context execution) is
  removed at its source; the unit agent chooses its own method per issue.
- A unit boundary is a recorded gate, so every unit boundary is a resumable session boundary.
- The issue's verification design is built for the issue, answering the #630 failure class.

### Negative

- The evaluator and the external layers carry the whole quality defence; an evaluator that
  passes a wrong artifact is caught only by CI, the reviewer or a human.
- A FAIL re-runs a unit, not a phase; the first-pass rate decides whether the saving holds.
- D7 moves the first judgment away from the operator; a wrong advisor answer is applied until a
  later layer or the operator's retry-stage review catches it.

### Neutral / Trade-Offs

- The change rewrites `CLAUDE.md`, the playbooks, the gate hook's role map, the agent
  definitions, the workflows, the spawn policy and the collector's phase keys; each migration
  step changes a rule and its device together.

## Related Issues / PRs

- #369 (this ADR's tracking issue).
- #268 (collector), #273 (A/B), #179 / ADR-0023 (relay), #166 (turn relay), #368 (workflow
  exposure — superseded by D2 if the workflows are retired first).

## Notes

- Baseline record: `~/.autoflow/_metrics/baseline-units-2026-09-28.md` (operator machine).
- "Highest-capability model" is taken as Fable 5.1 (`claude-fable-5-1`) at the time of writing.

<!--
Reference form (docs/records/design-rationale.md > Decision 16): cite another document's
provision by document, section heading and a verbatim fragment of its sentence.
-->
