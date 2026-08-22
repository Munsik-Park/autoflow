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
   today's floor except where this ADR deliberately tightens it. Two tightenings are deliberate.
   First, a suite declaring `# out-of-tree-inputs: yes` is excluded from inheritance entirely and
   executes unconditionally. That declaration is a property of the suite, declared where the suite's
   other properties are declared, and its presence on every suite the shipped base-ref call-site
   criterion matches is held true by a lint arm rather than by a hand-kept list. Second, **head resolvability**
   is a condition of the fast path selecting an entry at all: an entry whose `head` names no commit
   in the repository is not selectable, because a match cites that head as the anchor a reader
   re-derives. Both tightenings are monotone toward execution — each can only move a
   suite from inheritance to running — so the floor argument above holds unchanged.

   *Amended for issue #130 — the key's content form, and the register's scope.* Two things decision 2
   left implicit are now fixed, and both were needed for the same reason: a suite whose inputs did not
   move was still re-running whenever anything else did.

   - **The key's content form is a per-suite input hash.** A suite's *input closure* is exactly the
     path set the selection predicate reads — the suite's own path, every tracked path matching a
     token of its `# ci-subject:` header, and every tracked path under `tests/lib/**` — and the key is
     a hash over `(blob sha, path)` for every closure member at the certifying tree, carried on the
     entry as `<repo-relative path>@<input-hash>` tokens. When a covering entry's hash for a suite
     equals that suite's hash at the captured tree, the suite inherits without a reach test. The
     `tests/lib/**` member is load-bearing: the selector selects **every** suite when a shared library
     moves, so a key omitting it would be narrower than the selection boundary and the
     "the inheritance boundary IS the selection boundary" contract would become false rather than
     tightened. The bare-path token form keeps shipping and simply carries no certificate.
   - **The register is repo-scoped, not scoped to the minting issue's ledger.** Certificates are
     written to both the issue's own decision ledger and a **shared store** outside the repository
     tree, at `$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/green-trees/register.md` — a location resolved
     **absolutely**, its archive-root half anchored at the `--root` the archive-root guard was
     invoked for rather than at whichever process later interpolates the variable, so a relative
     `$AUTOFLOW_ARCHIVE_ROOT` names one directory for the writer and the reader alike — so a later
     issue reads a certificate an earlier one minted at the same tree — the cross-issue cold start that made every
     new issue re-run the tree from scratch. The shared store is a **cache, not a ledger**: it carries
     no authority, it may be pruned, and a malformed entry in it is skipped with one warning rather
     than treated as a BLOCK, because skipping a foreign certificate narrows inheritance while
     guessing at a malformed local one widens it.

   Neither addition weakens the two tightenings. Both stay ahead of the new paths: the out-of-tree
   declaration is tested before any store read or key comparison, and head resolvability is tested
   before the input-hash comparison — so an inheritance is never admitted on an anchor a reader
   cannot re-derive. The monotone argument is preserved in the form it was made: the two tightenings
   move suites only toward execution, and the two additions move suites toward inheritance **only on
   a content certificate** — an exact tree identity, or an exact identity of the suite's own input
   closure.

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
- The mechanism is stateful reasoning over an append-only ledger **and a repo-scoped cache**, which is
  new machinery on the verification path. It is realized as a script with a hermetic self-test rather
  than as playbook prose for exactly that reason. The cache half carries **no authority**: losing it,
  pruning it, or skipping an unreadable entry can only remove certificates, and a missing certificate
  resolves to executing the suite. It is never a gate input — no gate verdict, retry cap or phase
  transition reads it.

### Neutral / Trade-Offs

- A suite declaring `# out-of-tree-inputs: yes` executes unconditionally, which is **narrower** than
  the shipped whole-tree key would have allowed. This is deliberate and is the one direction in
  which this decision does not widen.
- What CI executes is unchanged. `scripts/test/select-suites.sh` gains an opt-in `--include-worktree` flag that no CI call passes.

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
