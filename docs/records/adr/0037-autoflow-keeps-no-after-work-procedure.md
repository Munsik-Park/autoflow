# ADR-0037: AutoFlow keeps no after-work procedure — merging is the external review's, what follows it the Coordinator's

## Status

Accepted (issue #500: the operator's instruction of 2026-10-22 in the issue body, and the criteria
settled by the attempt's criterion review, entry O2, with the operator decisions of 2026-10-22 —
the intent that no single after-work practice is fixed and that replacing the current one with
another fixed one is no resolution, principles 1–3, the role-separation view and the scope
decision (c); and the operator decision of 2026-10-22, entry O16, that names the owner of what
follows a merge the Coordinator). Amends ADR-0029 D5, ADR-0033 D6, ADR-0034 D2 and ADR-0036 D6;
supersedes issue #386's operator decision to keep the reconcile rule. Consistent with ADR-0003,
which takes no amendment (*Relation to other decisions* below).

## Context

Up to 0.3.11 AutoFlow's documents stated what happens after the hand-off, and when a later cycle
meets an earlier attempt, as fixed commands, an order and a timing:

- the reconcile — "After a sub-repo pull request merges, the host keeps a clean state by a
  reconcile merge", with "the orchestrator reconciles when it is asked" (`docs/units/delivery.md` >
  Multi-repo delivery > *The rule*), restated by the core's Commit Ownership row ("Sub-repo pointer
  (gitlink) commit or reconcile merge"), `docs/repo-boundary-rules.md` ("the host reconcile on
  request") and `docs/submodule-common-rules.md` > Sub-repo pointer ("The host reaches that state by
  the reconcile rule");
- the merge order and method — the end report "names the order in which the pull requests merge"
  (`docs/units/review.md` > *End*, *Merge order*), "Recommended: Squash and Merge" and *Merge
  Sequencing* (`docs/git-workflow.md` > Merge Strategy), the steps of
  `docs/external-review-sequencing.md`, the "merges first / merges last" annotations of *Issue
  Auto-Close*, and the pull request template's merge-dependency checklist;
- the branch handling and the cleanup's timing — "Performed at PREFLIGHT of the next cycle once an
  attempt's PR is observed merged or closed", `git switch --detach origin/<default>` and `git branch
  -D <branch>` (`docs/git-workflow.md` > Post-Merge Cleanup), and `cleanup-issue.sh`'s "Run at
  PREFLIGHT prior-attempt resolution";
- the next cycle's start condition — "prior-cycle resolved" among PREFLIGHT's completion conditions
  (`docs/core.md` > Development Lifecycle), U1's Goal "every earlier attempt … cleared away" and
  its transition "earlier attempts resolved" (`docs/units/preparation.md`).

No device enforced any of it. The hook has no reconcile or gitlink gate; `cycle-status.sh` sets an
attempt that is not active and whose pull request is merged or closed aside by those facts alone
and never reads its local dev branch or its `completed` mark for the entry; `cleanup-issue.sh`
already touched no git ref.
The text alone held the next cycle and fixed one practice, so a session or a reviewer reading it
judged a repository that merges or cleans up otherwise — a dev branch kept and pruned later, a host
pointer brought up another way — a deviation from AutoFlow. The operator's intent (issue #500,
2026-10-22) is that several after-work practices are each valid, that the defect is the fixing of
one, and that replacing the current one with another fixed one is no resolution; AutoFlow offers the
environment-independent functions as modules, and the side that assembles AutoFlow decides what
depends on the environment.

## Decision

**D1 — What AutoFlow keeps.** After the hand-off, and when a later cycle meets an earlier attempt,
AutoFlow keeps only what holds in every environment and what binds its own authority:

- **K1** AutoFlow merges nothing, promotes no draft, and never pushes to the default branch or the
  attempt's base; every pull request it opens is a draft. Ground: an authority rule
  (`docs/core.md` > Rule Scope, principle 1 — "the merge prohibition"), which the hook enforces
  (`docs/state-tracking.md` > Hook gates — "`gh pr merge`, and any push to the default branch …
  **denied state-independently**"); the issue names "merge하지 않음" as what AutoFlow keeps.
- **K2** The hand-off: the state `active: false`, `phase: "awaiting-external-review"`, and an end
  report of facts — each pull request's URL and head commit, the review verdict, CI as recorded,
  and, for a host pull request whose pointer names a sub-repo pull request's commit, that
  dependency. Ground: AutoFlow's own record; the pull-request facts are what U6 already owes
  (`docs/units/delivery.md` > Multi-repo delivery — "Result owed: each pull request's URL and head
  commit"), the verdict and CI are U7's own, and none depends on a repository's practice. Any merge
  practice needs the dependency, and carrying it prescribes nothing.
- **K3** The PR Wait Rule on the `active` flag alone. Ground: an unchanged authority rule
  (`docs/core.md` > PR Wait Rule — "Use the `active` flag as the single start signal"); it never
  read the cleanup.
- **K4** The entry sets aside an attempt of this checkout that is not active and whose pull request
  is merged or closed, by those observed facts alone, and `cycle-status.sh` names it on a `cleanup:`
  line. Ground: a fact the entry already computes; "cleared" stays the word for this classification,
  as `cycle-status.sh` and ADR-0036 D6 use it, and is no longer tied to a cleanup action.
- **K5** AutoFlow's own steps — PREFLIGHT and `cleanup-issue.sh` — change nothing on the remote, and
  the script touches no git ref. Ground: a property of AutoFlow's functions, true in every
  environment; it no longer reads as a rule on what the Coordinator does with a remote branch.
- **K6** The record function `cleanup-issue.sh <dev branch>…`. Its precondition is an attempt of
  this checkout that is not active (it has no state file, or its state file's `active` is not
  `true`) and whose pull request is merged or closed — the attempt a `cleanup:` line names. It
  deletes the attempt's reserved `issue-<N>-local/disposable` and writes `completed`; a completed
  attempt is no longer listed and never entered again; it refuses another checkout's attempt and a
  name not in the dev-branch shape, follows no symbolic link, and is invoked by path, not as a bare
  `rm` (the existing `[MUST]` and allow-list). Ground: AutoFlow's own record format, read by
  `cycle-status.sh` and the hook; only AutoFlow knows its meaning and its guard, so the Coordinator
  uses it as a module rather than reimplementing it. The precondition's ground: the mark
  ends the attempt for the gate hook as well — the hook passes over a record directory marked
  `completed` when it looks for this checkout's active state, and with none found it gates nothing —
  so an attempt still running is never marked, even when its pull request was merged or closed out
  of band. The precondition is the base's own, which the base stated through a PREFLIGHT timing
  ("that `cycle-status.sh` reports on a `cleanup:` line"); it is now stated as a precondition.
- **K7** Multi-repo delivery before the hand-off: a changed sub-repo's pull request opened by the
  orchestrator's own commands, gated, draft, `Part of <host-owner>/<host-name>#N` with no close
  keyword; the host pull request's pointer names the sub-repo commit the cycle delivers; the pointer
  cautions, for the pointer moves the cycle itself makes. Ground: the cycle's own work before the
  hand-off, which AC1 does not reach; HANDOFF's pointer-conflict route resolves to it
  (`docs/units/delivery.md` > Failure and retry — "a sub-repo pointer → Multi-repo delivery"; the
  exit-`10` messages of `confirm-ci-green.sh`).
- **K8** The close-keyword placement: sub-repo pull requests carry no `Closes` (`[MUST]`), the host
  pull request carries `Closes #N`, the template's `HOST-CLOSE-LINE` marker. Ground: pull-request
  composition at HANDOFF, not an order of merging.

**D2 — What AutoFlow stops defining, and whose it is.** Two acts follow the hand-off, each with one
owner, both outside AutoFlow and on the side that assembles it; one person may hold both roles, and
AutoFlow prescribes the steps of neither.

- **M1** Merge order and method — whether and when a pull request merges, its sequence among
  dependent pull requests, its method, and the confirmations before it, the sub-repo pointer check
  included. Owner: **the external review**. Leaves the text: the end report's order; "Recommended:
  Squash and Merge" and the regular-merge guidance; *Merge Sequencing*; the external reviewer's
  promote-and-merge steps; the operator's pointer confirmation step; the "merges first / merges
  last" annotations; the template's merge-dependency checklist; the development guideline's
  sequencing contract. Ground: AC1 names it; no device enforces it; ADR-0003 gives it to external
  reviewers; the operator's intent rules out fixing one practice.
- **M2** The reconcile, or any other way a host pointer is brought up after a sub-repo merge.
  Owner: **the Coordinator**. Leaves the text: *The rule* of Multi-repo delivery, "the
  orchestrator reconciles when it is asked" and the after-reconcile result owed; Commit Ownership's
  "reconcile merge"; `docs/repo-boundary-rules.md`'s "host reconcile on request"; the Sub-repo
  pointer section's host-default-branch invariant and its reconcile pointer. Ground: AC1 names it;
  AutoFlow never writes the default branch (K1), so the state of the host's default branch is what a
  merge practice achieves, not something AutoFlow can keep.
- **M3** Branch handling after a merge or a close — the attempt's dev branches, local and remote.
  Owner: **the Coordinator**. Leaves the text: `git switch --detach origin/<default>`,
  `git branch -D <branch>`, the remote dev branch kept as "the record the attempt left". Ground: AC1
  names it; the operator's intent: deleting at each merge and keeping and pruning later are both
  valid.
- **M4** The submodule update after a merge. Owner: **the Coordinator** (the confirmation
  before a merge is M1's). Leaves the text: every statement of it — the reconcile's pointer move, the
  operator's `git ls-tree` confirmation. Ground: AC1 names it.
- **M5** What is cleaned up, when and how — whether and when the record function runs included.
  Owner: **the Coordinator**. Leaves the text: the PREFLIGHT step "Earlier attempts are
  resolved"; "Performed at PREFLIGHT of the next cycle … or by the live session"; `cleanup-issue.sh`'s
  "Run at PREFLIGHT prior-attempt resolution"; `docs/repo-boundary-rules.md`'s "Verify integration
  after individual repos merge", which becomes the integration verification before the hand-off.
  Ground: AC1 names "무엇을 언제 어떻게 정리하는지"; the operator's role-separation view puts the
  cleanup policy with the Coordinator.

**The Coordinator.** The owner of M2–M5 is the **Coordinator**, a role's name, defined once in
`docs/git-workflow.md` > Post-Merge Cleanup (D5) by four propositions, each with its source:

1. *The role.* The Coordinator is the role outside AutoFlow that assembles AutoFlow's functional
   and evaluation modules — each takes an input, such as a work branch or an issue number, and
   produces a result — into a pipeline; AutoFlow's text names it the owner of what follows a merge
   or a close (M2–M5), and of nothing else. Source: the operator decision (entry O16) gives the
   name, the assembly view and the ownership of the work after the merge — that work varies by
   repository and environment, so it is not AutoFlow's. The bound to what follows a merge or a
   close is this decision's own, on the operator decision's scope, which replaces no other
   "operator" in AutoFlow's documents.
2. *The merge keeps its one owner.* Merging stays the external review's (M1), and one party may
   hold both roles. Source: the operator decision ("Merging stays the external review's"), ADR-0003
   and M1; "one party may hold both roles" is D2's lead above.
3. *A role's name only.* AutoFlow names no person, session or repository that holds the role,
   defines no step, order or timing for it, and makes no link that reads its procedure. Source: the
   operator decision (a role's name; no particular session implementation or its repository; no
   link that reads that party's procedure) and the scope decision (c); "no step, order or timing"
   is AC1's ("명령·순서·시점으로 규정하지 않고") and the boundary statement's (D5).
4. *Not the orchestrator.* The orchestrator is AutoFlow's own role: it runs a cycle and ends at the
   hand-off, and the Coordinator's work lies outside AutoFlow. Source: this decision's own, on the
   fact that AutoFlow's documents describe the orchestrator with the same root word ("coordinates
   role spawns", `docs/core.md` > Team Structure); the operator decision does not state it.

"Operator" stays AutoFlow's word for the person who sets the project up, decides and configures
(`docs/core.md` > Project Information); a role that a person, a session or a pipeline can hold is
not that person, so the owner of M2–M5 has a name of its own.

**D3 — PREFLIGHT's progression stops depending on the cleanup.** "prior-cycle resolved", "earlier
attempts resolved", "cleared away" and the core's "prior-attempt resolution (cleanup after external
merge/close)" leave PREFLIGHT's conditions, and the *What is asked* bullet that deleted the local
dev branch and marked the attempt becomes a fact: such an attempt is set aside by the entry (K4),
and what is then done with its branches and records, and when, is the Coordinator's (M3, M5).
PREFLIGHT's conditions are the entry, a clean tree, a synced remote and the stop conditions — the
conditions that already decided the device's answer. No script behavior changes.

**D4 — The end report carries facts, not an order.** U7's Result owed, *End*, its `REVIEW → end`
transition, the core's U7 line and the README name K2's facts; the *Merge order* subsection goes,
and its `[MUST]` — AutoFlow merges nothing and promotes no draft, and the hook denies `gh pr merge`
and a push to the default branch — moves into *End* without "of this order it performs only the
reconcile".

**D5 — One home for the boundary.** `docs/git-workflow.md` > Post-Merge Cleanup keeps its heading
and states, in place of the fixed procedure: merging is the external review's and what follows it is
the Coordinator's; AutoFlow defines no step, order or timing for either, and none of its steps
waits on them; the Coordinator's one definition (D2); what AutoFlow keeps there (K1, K4, K5); and
the record function (K6) with what an attempt left unmarked costs (*Consequences* below). Every
other place that stated or relied on the cleanup links there, and every other place that names the
Coordinator uses the term without defining it. The heading stays because it names a topic, and
renaming it would break the citations in force (ADR-0024 > Amendment note (issue #316); ADR-0036;
two `role-docs.tsv` rows; the core's U1 references).

**D6 — `docs/external-review-sequencing.md` is removed.** Its procedure is M1 and M2 whole, and its
one other statement — each pull request is reviewed on its own diff over its own repository — is
already the rule of `docs/units/review.md` > Reviewer review and `docs/review/review.md` > Before
Reviewing. Its pointers go with it: the core's U7 Unit references item, the two `role-docs.tsv` rows
that carried it into the U7 and `/autoflow:cycle` bodies, and the links in the index, the template,
the reviewer rules, the development guideline and the unit and git documents.

**D7 — No device changes (open question 3).** No hook or script presupposes a repository structure:
no reconcile or gitlink gate exists, `scripts/resync-submodules.sh` derives submodule names from
`.gitmodules` and is referenced by nothing, and `cycle-status.sh` and `cleanup-issue.sh` presuppose
neither a structure nor a branch practice. The authority denies stay (principle 1). Principle 4 is
met by the scripts' usage text — `cleanup-issue.sh` states K6's precondition and that when it runs is
the Coordinator's, `cycle-status.sh` states what a `cleanup:` line names — the classification
(`role-docs.tsv` loses D6's two rows; `core-units.tsv` is unchanged) and the regenerated carriers.

**The issue's open questions.** (1) What stays: D1 — the `completed` mark stays as a standalone
function (K6), and prior-attempt resolution as a PREFLIGHT step and a readiness condition does not
(D3). (2) Where a single-session operation reads the repository's procedure: AutoFlow defines no
reading site. After this decision no AutoFlow step needs the procedure — the hand-off ends AutoFlow
and the next cycle's entry does not wait on it — and a session that carries the procedure out does
so on the operator's instruction or the project's own files, under the existing rule that a session
reads the project's information and asks the operator for a fact no file states (`docs/core.md` >
Project Information). (3) Hooks and scripts that presuppose a structure: none does (D7).

## Alternatives Considered

- **PREFLIGHT keeps running `cleanup-issue.sh` on `cleanup:` lines, without branch deletion.** It
  would still fix when AutoFlow cleans and what — the M5 item AC1 leaves to the Coordinator — and
  would be one fixed practice replacing another.
- **Remove `cleanup-issue.sh` and leave the whole cleanup to the Coordinator.** The mark is
  AutoFlow's record format, read by `cycle-status.sh` and the hook; a practice would have to
  reimplement AutoFlow internals and the checkout guard.
- **Split `cleanup-issue.sh` into a mark and a delete.** No criterion needs it; a behavior change
  with no gain.
- **PREFLIGHT asks the operator at each start what to clean, or keeps the step as optional.** A step
  AutoFlow adds where the Coordinator already decides; an optional step at a fixed time still names
  a timing.
- **Keep the merge order in the end report as advice.** An order AutoFlow names is what a reviewer
  reads as the procedure — the defect the issue reports.
- **Remove the whole of Multi-repo delivery.** The pre-hand-off delivery is the cycle's own work, and
  HANDOFF's pointer-conflict route would point at nothing.
- **Keep the reconcile as a default the Coordinator may replace.** A default AutoFlow states is
  still the procedure a reader applies and judges against.
- **Reduce `docs/external-review-sequencing.md` to a stub.** A document whose only content is a
  pointer invites a reader to look there for a procedure; D5 states the boundary.
- **A project-information key AutoFlow reads and runs at PREFLIGHT.** AutoFlow would read and run the
  environment-specific procedure — the reverse of the role separation — with a schema and a device
  no criterion asks for.
- **State the precondition as a timing ("not while a cycle runs on it").** AutoFlow naming a timing
  (M5) where the device already computes the fact, and a reader could not check it against anything
  `cycle-status.sh` prints.
- **The Coordinator owns M1 as well.** The merge would have two owners, against ADR-0003 and the
  kept template line, or ADR-0003 would have to hand the merge's sequencing to the Coordinator;
  no criterion asks for that change to an authority allocation.
- **The external review owns all of M1–M5.** That would put the Coordinator's work on the operator's
  own checkout, its branches and its record root with the party that reviews pull requests, which
  neither ADR-0003 nor the base text does.
- **The pull-request body alone as the record.** It would leave four governing ADRs stating replaced
  decisions, and the record would live only in a pull request's text.

## Consequences

### Positive

- A repository that merges, brings up a pointer or cleans up in any way is not judged a deviation
  by AutoFlow's text, and the next cycle starts whatever the earlier attempt's branches and mark are.
- What AutoFlow keeps is stated once, with the authority rules unchanged and the record function
  usable on its own.

### Negative

- An attempt left unmarked stays listed and has its pull request looked up on every
  `cycle-status.sh` run. A lookup that fails is a fact not read: the run exits `3`, and the entry
  for the requested issue, read from the attempt's other facts, can name it unread until a run reads
  the lookup. It keeps its `issue-<N>-local/disposable/` on disk. While its pull request can be read,
  it changes no other issue's entry and no exit code; marking takes it out of the lookup.
- `cleanup-issue.sh` does not check its precondition itself, so a practice that marks attempts at
  each merge relies on the stated precondition to leave a running attempt alone. A refusal by the
  device — the script reading the state file, or the hook treating a `completed` directory that
  holds an active state file as found — needs a decision of its own (an unreadable state file, an
  attempt with no state file, a stale `active: true` left by a stopped session) and is not taken
  here. The operator decided on 2026-10-22 that the stated precondition suffices and that no
  separate issue proposes such a refusal: marking a running attempt `completed` is a deliberate
  departure from the procedure that shows at once, so no device guards it in advance, and an actual
  occurrence is handled when it arises.

### Neutral / Trade-Offs

- The fixed text leaves the documents, and the practice that replaces it is the Coordinator's,
  outside AutoFlow; no reading site for it is defined.

## Relation to other decisions

- **ADR-0003** — consistent; no amendment. It gives the merge — its sequencing, the sub-repo merge
  confirmation, the final readiness checks and its execution — to external reviewers. This decision
  keeps that allocation and names the Coordinator only for what follows a merge, which ADR-0003
  does not allocate. What it removes is AutoFlow's own prescription of the sequence
  (`docs/external-review-sequencing.md`, the end report's merge order). That is not ADR-0003's
  rejected alternative "Remove external review sequencing and rely only on automation": the
  sequencing stays with the external review, and no automation takes it over.
- **Issue #386's operator decision** — superseded. It kept the rule that the host is reconciled to a
  sub-repo pull request's merge commit, on the operator's request. The operator's instruction of
  2026-10-22 in issue #500 is later and moves the after-work procedure out of AutoFlow.
- **ADR-0029 D5 (*Cleanup is local and marks; nothing moves*)** — amended: the local branch deletion
  and the cleanup as a PREFLIGHT step leave AutoFlow (M3, M5); `cleanup-issue.sh`, its guard, its
  precondition as K6 states it, and "no remote branch is deleted, no push is made and no PR is
  changed" by AutoFlow's own steps stand.
- **ADR-0033 D6 (*No label*)** — amended: the end report names no merge order (D4); the labels'
  retirement and the merge prohibition stand.
- **ADR-0034 D2** — amended: the multi-repo reconcile leaves D2's list of what follows the attempt's
  base, and the cleanup's `git switch --detach origin/<default>` its list of what is left as it is;
  neither is a step of AutoFlow's any longer (M2, M3).
- **ADR-0036 D6** — amended: the `cleanup:` line stands; what is done on it is the Coordinator's.
- **ADR-0024 D2 and Amendment note (issue #316)** — unchanged: the reserved path and its deletion
  by `cleanup-issue.sh` stand, and the cited heading Post-Merge Cleanup resolves.

## Related Issues / PRs

- Issue #500.
- Issue #386 (the reconcile rule this decision supersedes).

## Notes

- The boundary, the Coordinator's definition and the record function are `docs/git-workflow.md` >
  Post-Merge Cleanup; the entry that sets a merged or closed attempt aside is
  `docs/units/preparation.md` > *What is asked*, *Modes*; the end report is `docs/units/review.md` >
  *End*.
