# ADR-0038: Contract modules, run by the Coordinator, with no state file

## Status

Proposed (epic #507, sub-issue 3; the decisions of the design review
`docs/records/design-reviews/io-contract-modules.md` > Open decisions, Q1–Q24, settled by the
operator 2026-10-23 – 2026-10-26). Supersedes ADR-0025 D1, D5, D6 and D8, and the parts of D2, D3,
D4 and D7 named in *Relation to other decisions*; ADR-0029 D2–D6 and D8; ADR-0030 D2, D3, D5–D7
and D9; ADR-0032 D1–D2 and D5; ADR-0033 D1–D2; ADR-0036 D1–D7; ADR-0037 K1's base clause, K2–K4,
K6, D2's bound of the Coordinator and D3; ADR-0024 D1's `standing` declaration and D4's class-routed
re-entry; ADR-0034's start point and base. ADR-0029 D1, D7 and D9, ADR-0027, ADR-0035 and ADR-0037
K5, K7, K8 and D2's M1–M5 stand.

## Context

AutoFlow became modular by steps: seven functional units (ADR-0025, ADR-0033), a command per unit
(ADR-0032), a unit run alone on the abbreviated path (ADR-0036), and no procedure after the merge
(ADR-0037). The progression between steps stayed bound to one state file and one orchestrator. A
step could run when the state file's scores, `remedy_class` and the orchestrator's own count said
so, not when the previous step's output existed:

- the hook admits the design spawn, the build spawn, `git push` and `gh pr create` on the state
  file's scores (`docs/state-tracking.md` > Hook gates), and refuses push and PR while a gate's
  latest record carries a `remedy_class`;
- the re-entry counters — ARCHITECT, AUDIT, GATE:QUALITY — are "the orchestrator's own
  accounting", kept in no file (`docs/units/design.md` > Re-entry);
- the entry is evaluated from the state files, the pull requests and the criterion readiness by
  `scripts/preflight/cycle-status.sh` (ADR-0029 D4, ADR-0030 D3, ADR-0036 D6);
- no unit declares its inputs in a form a program reads; they are prose in each unit's *Unit
  spawn*, and three of the four gate reports have no path at all.

The operator's instruction of 2026-10-23 (epic #507): "입력 출력을 yaml 파일 형태로 정의하는 방안이
잇습니다 / 외부 조율자는 그것을 어떻게 사용할지 결정하지 모듈을 그냥 부품으로 동작합니다 / 따라서 state
file 은 완전히 없애려고 합니다 / 모듈에서 active 나 lock 을 걱정하지 않습니다 / 기본적으로 한 단계씩
수행하면 동작한다를 디폴트 값으로 상정합니다 / 그것을 수행 시키고 판정하는 것은 외부 모듈입니다 / 루프와
카운터는 외부에서 결정하고 모듈은 입력에 대해 출력 형식이 정해져서 그것을 맞춥니다".

Sub-issues 1 and 2 (#508, #509) settled the concept, the module boundaries, the contract format and
the invocation, wrote the fourteen contracts (`docs/contracts/*.json`), the validator
`scripts/contracts/contract.sh` and `scripts/contracts/criteria-apply.sh`, and ran the modules on a
test target in two rounds (the design review, §11). Nothing read the contracts: the cycle still ran
on the state file. This decision moves AutoFlow onto the modules.

Two facts from the test runs bear on what goes. The 27 module runs on the test target ran with no
AutoFlow attempt: the branch and the record directory were the Coordinator's, and each module was
given its branch, its record directory and its output directory in its invocation (the design
review, §5.3). And the coordinating session already builds a worktree of its own for each run, from
the base's latest commit, and keeps its own record directory per run (the operator's coordination
runbook, machine-local).

## Decision

**D1 — AutoFlow is a set of modules, each with a contract.** A module is an input, the work it
does, and an output (Q14). Its contract, `docs/contracts/<module>.json` (JSON, read with `jq`, Q17),
declares its parameters, its inputs and where each comes from, and its outputs with the form each
must meet. The modules are functional — criterion-screen, criterion-trace, criterion-in-depth,
criterion-reconcile, analysis, design, build, delivery, review —, evaluation — hypothesis, plan,
audit, quality — and deterministic — criteria-apply (the design review, §4). A module:

- runs on an invocation file the Coordinator writes, which names its parameters, its inputs, its
  output directory and, for a functional module, the attempt's record directory (§5.3, Q20);
- checks its inputs' form at the start (`contract.sh check-in`) and does not run when one fails;
  where an input came from, and whether the run that produced it was accepted, is not checked (Q19);
- runs once — an output short of its form is re-run by the Coordinator, not by a loop inside the
  module (Q3);
- writes its outputs and ends with `contract.sh check-out`, which writes `<out>/result.json`
  (`accepted` or `refused`, the defects, the tool requests);
- uses the tools its work needs; one that is missing is recorded as a tool request and the run still
  ends (Q10);
- is prescribed by its goal: a procedure says what the work must achieve, not a form that must be
  present (Q16). The contract checks the inputs and that the output disposes of every item the work
  owes — every applied criterion, every scope item the design includes (Q14).

The work and its evaluation are separate modules. A unit that bundled them (U2 = DIAGNOSE +
GATE:HYPOTHESIS, U3 = ARCHITECT + GATE:PLAN, U4 = BUILD + AUDIT) is two modules.

**D2 — The Coordinator runs the modules and judges their results.** The Coordinator is the role
ADR-0037 D2 named, with its bound widened from what follows a merge or a close to the whole
lifecycle; propositions 2 and 3 of its definition stand (the merge keeps its one owner; a role's
name only), proposition 4 changes with the orchestrator's removal (D3). What AutoFlow's text gave the
orchestrator and the cycle is the Coordinator's: which module runs next and on which inputs; a
re-run, and how many; the caps; applying the evaluation's reference values (Q2); where a finding's
fix is made (Q11); putting a question to the advisor (the design review, §4); recording a decision
in the ledger (Q4); editing the issue body to the criterion review's dispositions (Q9); the
worktree, the branch and the record directory (D4); checking the environment it builds (D4); a
model tier revert after a contradicted PASS. AutoFlow defines no step, order or timing for any of
it. The orchestrator role, the Flow Control table, each unit's Transitions and Re-entry, Modes,
Review-response setup, Resume and the PR Wait Rule leave AutoFlow's text. `/autoflow:cycle` and the
abbreviated path stop being paths the plugin defines; they are two ways the Coordinator composes the
modules (the design review, §4).

**D3 — There is no state file.** The state file `<attempt-dir>/issue-{N}.json` — `active`, `cycle`,
`mode`, `phase`, `phases.*` —, `docs/state-tracking.md`, the schema `tests/fixtures/gate-schema.json`,
the entry evaluation `scripts/preflight/cycle-status.sh`, the in-tree migration
`scripts/migrate/migrate-in-tree-records.sh` and the route `scripts/gate/remedy-route.sh` are
removed. An evaluation's result is its output file (`<out>/evaluation.json`), written verbatim by
the session that runs the evaluation module from what the evaluator returns (Q7). The rules the
removed document carried that stay — the policy denies (D5), the record location, the hook's
behavior with no `jq` — move to the documents that keep them.

**D4 — An attempt is the Coordinator's worktree, branch and record directory** (operator decision
2026-10-26: "워크트리로 작업이 변경됩니다. 브랜치 커밋 베이스 작업이 가능하음로 많은 것들이
간소화됩니다"). The Coordinator builds the worktree, the branch at the commit it starts from, and the
attempt's record directory, and names them in each invocation (`params.branch`, `records`, `out`;
the commits as a range, Q19). So AutoFlow keeps none of what made, owned, entered or cleared an
attempt:

- `autoflow-records new`, `claim`, `base` and `dir` are removed; `root` and `drafts` stay (the
  record root of ADR-0029 D1, and the issue drafts `scripts/issue/create-issue.sh` writes);
- the dev branch's name `dev-<stamp>-issue-<N>`, the record directory's `checkout` and `completed`
  files, one active attempt per checkout, the claim of an attempt whose checkout is gone, and
  `scripts/cleanup/cleanup-issue.sh` are removed;
- the git clean check and the start sync, which a fresh worktree from the base's latest commit has
  no use for, are removed;
- the cycle-layer store `<attempt-dir>/issue-{N}-local/` is each run's own `<out>/local/`, which a
  later functional run reads from the record directory (Q20);
- the record directory's ledger keeps its name, `issue-<N>-ledger.md`, which the hook's ledger check
  reads (D5); the Coordinator names it so;
- `scripts/preflight/target-check.sh` and `scripts/preflight/check-review-backend.sh` stay, as
  checks of the environment the Coordinator runs when it builds it — "checked when the environment
  is built, not on every run" (§5.3) —, not as a condition of any module.

**D5 — The hook keeps the policy denies, and the push deny only for the default branch** (operator
decision 2026-10-26: "브랜치의 푸시는 막을 사유가 줄었어요. 머지는 여전히 운영자 권한이고 푸시는
현재가지 운영상 보면 제한을 제거하도록 합니다", then, on the recommendation that the default branch
stay denied, "수용"). The hook keeps, in every session and with no state: `gh pr merge`; a push to
the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; the
ledger's append-only and authorship checks; an explicit `model` on every spawn; a backgrounded
`run-suites.sh`; and, with no `jq`, the same denies read from the raw input. A push to the default
branch is a merge that skips the pull request and its review, and no remote device stops it on the
targets in use (`gh api repos/<owner>/<repo>/branches/main/protection`, 2026-10-26: "Branch not
protected" for `Munsik-Park/autoflow` and `Munsik-Park/opensre`; protection not available on the
plan for `connev-llm/llmroute`), so this deny is part of the merge prohibition. Removed: the score
gates on the design and build spawns, `git push` and `gh pr create`; the `remedy_class` block; the
doc-remedy sweep gate; the base-branch push deny and the dev-branch test it rests on; the
undeclared-spawn and teammate-`name` denies and the role-to-gate mapping, which only those gates
read and which, made state-independent, would refuse ordinary spawns in every session the plugin is
installed in; the record-root fail-closed on a dev branch; and the non-gating ledger advisory that
scanned this checkout's attempts.

**D6 — An evaluation outputs scores and grounds.** It outputs a score and its grounds per rubric
item and its recommendations, each with its severity; AutoFlow keeps the reference pass values
(average ≥ 7.5, each item ≥ 7, security ≤ 3 reworks) with the rubric whose scale they are set on, and
applying them is the Coordinator's (Q2). `verdict`, `remedy_class` (Q11), `blocking_issues` (Q15)
and `fail_hypothesis` (Q12) leave the output; the pre-scoring FAIL search stays a rule of the
evaluator's conduct. `remedy_class` leaves every document and device: the evaluator's tagging, the
FAIL routing, the review aggregation's tag on each `Medium`+ finding and the findings-file check
that requires it. The AI acting on a finding judges where its fix is made and states a question for
the advisor when it cannot.

**D7 — The verification design carries no classification, and no tool declaration.** `Type`,
`Kind`, the `standing` token and the per-column rules of `Reason` and `Failure mode` leave the
verification design and the rubric items and scripts that read them
(`scripts/gate/verification-layer-check.sh`); what the table owes is a disposition for every applied
criterion and included scope item (Q8, Q14). The test-first rule is stated as its goal — a test that
verifies a required behavior is seen failing before the implementation it verifies. The
deployment-level checks a repository commits (`packaging`, `manifest`) stay the repository's tests;
only their declaration in the table goes. The verification design's `## Tools`, GATE:PLAN's `Tools`
item, the per-attempt local checks and the pause for a missing tool or a referenced material go;
each is a tool request (Q10).

**D8 — The ledger holds decisions.** Entries that settle what a module cannot settle itself —
`[criterion-ready]`, `[ac-decision]`, `[checklist-decision]`, a design point — under their authority
(Q4). The Coordinator's own records — the attempts counted for a cap, the cap-window reset,
`[rebuttal]`, the gate verdict entries, the PREFLIGHT records — leave it. An `[ac-decision]` that
revises, adds or splits a criterion carries the criterion's text (`- Text:`, `- Into:`), from which
`criteria-apply.sh` computes the applied criteria every later module takes (Q5). An entry's heading
names no cycle or phase.

**D9 — A module's command carries its module's guidance.** `/autoflow:cycle`, `/autoflow:cycle-u1`
… `/autoflow:cycle-u7` and `/autoflow:criterion-review` are replaced by one command per module,
generated by `scripts/skills/gen-skill-bodies.sh` under the classifications it reads, now by
module. A module's command names the place a spawn's model is read
(`spawn-policy.sh model <phase-key>`), and a functional module's command names the record directory
as the place earlier runs left their work (the design review, §8). `docs/abbreviated-path.md` is
removed.

**D10 — The run metrics read the records left before this change** (operator decision 2026-10-26,
"수용"). `scripts/metrics/` finds an attempt by its state file; it stays for those records and is
documented as such. Measuring module runs, whose results are the Coordinator's, is the
Coordinator's.

## Alternatives Considered

- **Keep the state file as the Coordinator's record.** Rejected: the operator's instruction removes
  it entirely, and with the gates gone nothing in AutoFlow reads it.
- **Keep `autoflow-records new` as a tool the Coordinator runs**, as ADR-0037 K6 kept the record
  function. Rejected: the Coordinator already builds a worktree, a branch and a record directory per
  run, and the test runs used neither the command nor its branch name.
- **Remove every push deny.** Rejected: a push to the default branch is a merge, and no remote
  protection stands in for the hook on the targets in use (D5).
- **Keep the base-branch push deny, with the delivery module setting the branch's `gh-merge-base`
  from a `base` parameter.** Rejected by the operator decision of D5: it needs a setting per branch
  whose only producer, `autoflow-records new`, goes, for a push the operator's practice does not
  need to stop.
- **Make the role declaration state-independent.** Rejected: it would refuse every undeclared spawn
  in every session of every target the plugin is installed in, and the gate classes it served are
  gone.

## Consequences

### Positive

- A module's admission is the form of its inputs, which a program checks; no score, flag or count
  stands between one module's output and the next module's run.
- One record directory per attempt lets a re-run read how the previous run worked (Q20).
- The hook's state lookup — the largest part of the script — and the scripts that served it go.

### Negative

- Every sequencing, counting and judging rule now lives outside AutoFlow; a Coordinator that does
  not apply the reference values or the caps is not stopped by anything AutoFlow ships.
- A push to a base other than the default branch is no longer denied.
- The run metrics cover no attempt made after this change.

### Neutral / Trade-Offs

- The operator's `security-checklist.md` names the hook's state validation; its text changes with
  the operator's acceptance, as the file's maintainer rule requires.

## Relation to other decisions

- **ADR-0025** — D1 (units ending at a recorded gate), D5 (the orchestrator sequences, records and
  routes), D6 (the four gated state keys) and D8 (every change is the orchestrator's own; the hook
  reads the command it issues) are superseded by D1–D3. D2's loop cap, D3's push gate and re-entry
  caps, D4's unit loop and D7's `remedy_class: operator` point go to the Coordinator (D2, D6). D2's
  evaluator clause, D3's merge prohibition and evaluator independence, and D7's advisor as the first
  judgment stand.
- **ADR-0029** — D1 (one record root), D7 and D9 stand. D2 (the attempt keyed by its dev branch,
  the `checkout` and `completed` files), D3, D4 (the printed entry), D5 (cleanup), D6 (the hook
  gates per checkout) and D8 (migration) are superseded by D3–D5.
- **ADR-0030** — D2 (the cycle creates the attempt, the state file written last), D3 (entries),
  D5 (the stage run alone), D6 (the hook during the stage), D7 (the PR Wait Rule's signal) and D9
  (the script reports, the session judges the way on) are superseded by D2–D4 and D9. D1's stage
  becomes the four criterion modules; D4's rule that a new attempt is the operator's request is the
  Coordinator's.
- **ADR-0032** — D1 (a command per unit, with its entry check), D2 (the classification by unit) and
  D5 (the core retains the router, the caps and the state rules) are superseded by D9; D3 and D4
  stand for the module commands.
- **ADR-0033** — D1 (U7's routing by `remedy_class`, its cap, its end state) and D2 (U7 reads the
  current state) are superseded by D2, D3 and D6; D3–D5 (the reviewers as scripts, the rule files,
  the reviewer configuration) stand.
- **ADR-0036** — superseded whole by D2: the abbreviated path is one of the Coordinator's
  compositions.
- **ADR-0037** — K1's base clause is superseded by D5 (the default branch stays); K2's state, K3
  (the PR Wait Rule), K4 (the entry sets an attempt aside) and K6 (the record function) by D3–D4; D2's
  bound of the Coordinator by D2; D3 is moot with PREFLIGHT gone. K5, K7, K8 and D2's M1–M5 stand.
- **ADR-0024** — D1's `standing` list and its `Type`-cell declaration are superseded by D7; D4's
  class-routed CI re-entry by D6. The two-layer model's committed deployment-level checks stand.
- **ADR-0034** — the start point and the base the attempt keeps (`--base`, `--commit`,
  `gh-merge-base`) are the Coordinator's (D4); D2's hand-off without CI stands.
- **ADR-0020, ADR-0022** — the acceptance-criterion authority stands; its application is
  criteria-apply's output (D8).

## Related Issues / PRs

- Epic #507; sub-issues #508, #509 and sub-issue 3.

## Notes

- The survey this decision rests on, the open decisions and their operator's words are
  `docs/records/design-reviews/io-contract-modules.md`.
