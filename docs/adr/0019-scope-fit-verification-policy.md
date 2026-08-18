# ADR-0019: Verification cost tracks change size; the whole tree executes once per cycle as the floor

## Status

Proposed

## Context

A cycle's local verification runs the whole enumerated suite tree at every capture point that is not
covered by the green-tree register's whole-tree fast path — GREEN step 5, VERIFY step 1, REFINE
step 2. The register's inheritance key is one whole-repository hash (`docs/autoflow-guide.md` >
VERIFY > *Tree-identity predicate*, condition 2), so **any** tracked change invalidates **every**
suite's verdict, and a documentation-only commit late in a cycle re-executes the tree.

CI does not work this way. `scripts/test/select-suites.sh` is the tree's sole owner of "which suites
does this change require", keyed on each suite's declared `# ci-subject:` header, and both CI and
the local driver `scripts/test/run-suites.sh` consume it. The declaration CI already trusts to
decide *execution* is therefore available to decide *inheritance* as well, at the same grain.

Two properties bound how far that can be taken. First, the whole-tree key is coarse enough to mask
an exposure the register itself excludes from its guarantee: a suite whose assertions resolve a
comparison base through `resolve_base_ref` (fallback `git merge-base HEAD origin/main`,
`tests/lib/base-ref.sh`) can change answer while the tree is untouched. Per-suite keying widens that
exposure, because it inherits across a HEAD advance exactly when the suite's declared reach did not
move. Second, inheritance correctness rests entirely on `ci-subject` declaration quality, and
detecting under-declaration is not solved here.

## Decision

1. **Selection-based intermediate verification.** Interim capture points — GREEN step 5, VERIFY
   step 1, REFINE step 2 — accept on the selection-derived run set rather than on the whole
   enumerated tree. The whole enumerated set executes **once per cycle at a named step**, VALIDATE
   step 1, unconditionally and evaluating no inheritance predicate, as the coverage floor before
   AUDIT / GATE:QUALITY / hand-off. The floor moves; it is not removed. A VALIDATE full-sweep
   failure routes `VALIDATE → RED`, matching the shipped `INTEGRATE FAIL → RED` disposition.

2. **Suite-grained verdict inheritance.** The green-tree register keys inheritance **per suite** on
   that suite's own declared `ci-subject` reach, not on a whole-tree hash. The shipped whole-tree
   predicate survives verbatim as the fast path, so the new predicate's answer is never below
   today's floor except where this ADR deliberately tightens it: a suite declaring
   `# out-of-tree-inputs: yes` is excluded from inheritance entirely and executes unconditionally.
   That declaration is a property of the suite, declared where the suite's other properties are
   declared, and its presence on every suite the shipped base-ref call-site criterion matches is
   held true by a lint arm rather than by a hand-kept list.

3. **Evaluator execution discipline.** A gate evaluator resolves a suite-verdict anchor against the
   host's own record before executing anything, and cites what it inherited in a declared field of
   its own report (`inherited_verdicts` in `docs/evaluation-system.md` > *Evaluation Output
   Format*), never in the gate state file. A blind-spot search over a repeated surface takes a
   representative sample per rubric item by default and escalates to exhaustive enumeration only on
   a hit. An evaluation declares a wall-clock cap and, on reaching it, records every unsearched item
   as `not-searched` — never as clean.

The three commitments are one decision, not three. They share a single thesis — the `ci-subject`
declaration CI already trusts becomes the unit of both execution and inheritance — and each is inert
without the others: selection-based interim verification without suite-grained inheritance still
re-runs everything after any commit, and the evaluator discipline has nothing to cite without the
per-suite record.

## Alternatives Considered

- **Seed coverage from the integration branch's CI result.** It would remove the cycle's first wide
  run entirely. Rejected: it grounds an in-tree inheritance decision on out-of-tree state the
  register explicitly excludes from its guarantee, and on an advisory CI signal.
- **Leave the base-ref widening as a prose caveat.** The register already carries a caveat that
  base-ref-dependent assertions are outside the inheritance guarantee. Rejected: a caveat is not an
  answer to a widening this decision itself introduces — under the coarse key the caveat had no
  teeth to lose, and under per-suite keying it becomes the only thing standing between a
  base-ref-dependent suite and a silently inherited stale verdict. A declared header field the
  resolver reads mechanically is the answer; a sentence a reader must remember is not.

## Consequences

### Positive

- A cycle's interim verification cost tracks the size of its change instead of the size of the tree.
- Inheritance and execution are decided by one predicate owner (`select-suites.sh`), so the
  inheritance boundary is the selection boundary by construction rather than by agreement between
  two implementations.
- The per-suite record makes a step's coverage claim re-derivable: `inherited-suites` and
  `ran-suites` partition the enumerated set, so a reader can tell "correctly narrowed" from
  "nothing ran".

### Negative

- Inheritance correctness rests on `ci-subject` declaration quality. Hardening the detection of
  under-declaration is **out of scope** here; the unconditional VALIDATE sweep bounds the damage an
  under-declared header can do to a single cycle rather than letting it reach the reviewer, but it
  is a containment measure, not a detector.
- The mechanism is stateful reasoning over an append-only ledger, which is new machinery on the
  verification path. It is realized as a script with a hermetic self-test rather than as playbook
  prose for exactly that reason.

### Neutral / Trade-Offs

- A suite declaring `# out-of-tree-inputs: yes` executes unconditionally, which is **narrower** than
  the shipped whole-tree key would have allowed. This is deliberate and is the one direction in
  which this decision does not widen.
- What CI executes is unchanged. `scripts/test/select-suites.sh` is not modified.

## Related Issues / PRs

- Issue #112 — scope-fit testing requirement.
- ADR-0016 (`docs/adr/0016-adr-conformance-gate-scoring.md`) — the same self-referential
  gate-policy class recorded as an ADR trigger.
- ADR-0018 (`docs/adr/0018-verification-depth-justification.md`) — the evaluation-policy precedent
  this decision follows.

## Notes

`docs/adr/README.md` > *When to Create an ADR* lists "Agent workflow gates, evaluation policy, or
merge authority" among the classes requiring an ADR before implementation. This change meets that
trigger in three independent places: two `[MUST]`s added to `docs/teammate-contracts.md` >
Evaluation AI, the `inherited_verdicts` key added to `docs/evaluation-system.md` > *Evaluation
Output Format*, and the `VALIDATE → RED` row added to `CLAUDE.md` > Flow Control.
