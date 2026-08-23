# Reduced excerpt — issue #134 cycle-1 `gate-plan-3` Scope score (issue #138, AC3 replay input)

Reduced, verbatim excerpt from the archived
`$AUTOFLOW_ARCHIVE_ROOT/Munsik-Park__autoflow/issue-134-2026-08-23/issue-134-gate-plan-3.md`
(GATE:PLAN attempt 3), the exact input `.autoflow/issue-138-phase-b.md` >
Acceptance criteria > AC3 names: *"Re-evaluate the #134 cycle 1 `gate-plan-3`
input and confirm the verdict flips from PASS to FAIL."* Reproduced here as a
committed fixture so the manual replay scenario has a stable input independent
of archive pruning (`docs/doc-invariant-registry.md` testability note
`archive-fixture-is-out-of-tree`).

The score line, unedited:

> **Scope** | **8** | Three surfaces built, three refusals recorded with
> re-derived grounds rather than papered over: `duplicate-run-ac` NOT CARRIED
> (the offered replacement is an identity — `docs/autoflow-guide.md:975-976`
> makes `mismatch-cause: none` definitionally equivalent to
> `outcome: inherited`), `parallel-defer` deferred on the unmet isolation
> precondition (`run-suites.sh:171,184` shares the repo root),
> `foreground-record` withdrawn (`logs/` absent, hook has no filesystem
> write). Exactly two new spec files, each with a unique failure mode and the
> Admission four questions answered; existing carriers reused (`AC-2g` mirror
> diff, manifest FIXED POINT, three standing lints for `suite-ci-path`) with
> duplication explicitly declined per the leaf rule. `BG_SCAN` is not
> gold-plating: I confirmed `SCAN` reduces
> `bash "$ROOT/…/run-suites.sh" --all &` to `bash  --all &` (a real admit of
> the tree's own idiom) and that an unconditional strip would deny this
> cycle's own PR-body prose.

The 8 was scored with **no** cap applied ("Determination: no cap applied to
Feasibility or Scope") — the historical PASS this manual scenario re-evaluates
under the new `AC-authority check` (`docs/autoflow-guide.md` > GATE:PLAN):
the `duplicate-run-ac` difference between `tests/fixtures/issue-138-ac-phase-
b.md` (AC1) and `tests/fixtures/issue-138-ac-verification-design.md` (AC1: not
carried as a criterion) is covered by **no** `[ac-decision]` ledger entry in
`tests/fixtures/issue-138-ac-ledger-no-decision.md` — the shape the #134
cycle actually shipped with before the 13:33Z operator decision. Re-run this
Scope item under the amended GATE:PLAN rubric text against that no-decision
ledger variant: the AC-authority check must cap Scope at 6, flipping this
historical PASS toward FAIL. Re-run again against
`issue-138-ac-ledger-with-decision.md` (the `[ac-decision]` variant): the cap
must not apply.
