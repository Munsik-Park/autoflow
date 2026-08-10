# Issue #75 — Manual/Operator Verification Scenarios (Tier-3)

This is an **execution venue**, not a weaker verification type. Per
`.autoflow/issue-75-verification-design.md` (layers table, "Execution-graph
invocation-count measurement over one composed run" and "Full-sweep driver run"),
both scenarios below are real runs of real scripts with deterministic oracles — only
their wall-clock budget keeps them out of an inline CI step, so this file is where they
execute rather than a separate, weaker layer.

---

## M1 — Full-sweep driver run: no suite this cycle's acceptance criteria omit regresses

**What this discharges.** The full-sweep driver (`tests/issue-59-full-sweep-driver.sh`)
is the only layer whose oracle is "the set of regressing suites ⊆ the set this cycle's
acceptance criteria name" — a suite this design never mentions regressing is invisible
to every other layer, which only asserts what it was told to assert.

**Why not automated inline:** the driver's own wall-clock exceeds any inline CI step
budget (it runs every `tests/test-issue-*.sh` suite in the tree, sequentially), and its
`INCONCLUSIVE` path exists precisely so a short/interrupted run is never miscounted as
a pass.

**Steps (operator, at VERIFY):**

1. From the repo root, on branch `dev/2026-08-10-issue-75`, run:
   ```
   bash tests/issue-59-full-sweep-driver.sh
   ```
   and let it run to completion — its own budget, not a truncated one.
2. Read the driver's summary. It must not report `INCONCLUSIVE` (a short run is not a
   pass).
3. **Observable outcome:** the driver's unnamed-regression line lists no suite outside
   the set `.autoflow/issue-75-verification-design.md`'s acceptance table and §5
   already name as touched or removed this cycle (§3.2's `test-issue-40-doc-assertions.sh`
   deletion, §3.3's `964` lane removals, §3.4's `795` lane removal, §3.5/§3.5a/§3.5b's
   `952`/`955`/`985` removals, §3.6's `59` removals, §3.7/§3.7a's array-lane and reader
   deletions in `952`/`955`/`798`/`846`/`848`/`55`/`52`/`7`/`62`, §3.9's workflow
   registration edit and its class-A/class-B fixed-window readers, §3.10's small
   dead-symbol removals in `42`/`43`/`55`/the `92` bats files, and this cycle's own new
   suite/lint).
4. If the driver names a regressing suite outside that set, treat it as a real
   regression this design did not anticipate — do not dismiss it as noise, and do not
   widen the acceptance set after the fact to absorb it; escalate per VERIFY's cause
   branch.

**Disposition record:** note the driver's exit status and any regressing-suite line in
the cycle's HANDOFF report.

---

## M2 — Composed-run invocation count: duplicate execution is resolved, not relocated

**What this discharges.** Duplicate execution persists or is merely moved — every
static layer passes identically whether a suite ran once or four times, so only a
count of real invocations in one composed run distinguishes "resolved" from
"relocated". This is the measured half of the duplicate-execution acceptance
criterion; the static half (no direct invocation of the install/E2E verifiers from
`tests/test-issue-952-wizard-removal.sh`) is a CI-registered assertion inside
`tests/test-issue-75-scope-guard-retirement.sh` and is not repeated here.

**Why not automated inline:** the composed run re-executes
`tests/plugin/verify-e2e-dummy-target.sh`, whose wall-clock exceeds any inline suite
budget.

**Steps (operator, at VERIFY):**

1. From the repo root, run the composed set — `tests/plugin/verify-e2e-dummy-target.sh`
   together with the CI step list — in one shell, with a wrapper that logs every `bash`
   invocation it spawns. A minimal wrapper:
   ```bash
   #!/usr/bin/env bash
   LOGFILE="${INVOCATION_LOG:?set INVOCATION_LOG}"
   real_bash="$(command -v bash)"
   trap - DEBUG
   PS4='+ $BASH_SOURCE:$LINENO: '
   exec {BASH_XTRACEFD}>>"$LOGFILE"
   set -x
   "$real_bash" "$@"
   ```
   or equivalent — any mechanism that produces a per-invocation log of every
   `bash <path>` / `bash "$VAR"` spawn is sufficient; the property under test is the
   per-suite invocation multiset, not the logging mechanism.
2. Run the composed set once at HEAD (`dev/2026-08-10-issue-75`) and once at the merge
   base (`git merge-base HEAD main`), producing two invocation multisets.
3. **Observable outcome, three clauses (per the acceptance table's method column):**
   - **(1) Named reductions land**: the invocation counts of
     `tests/plugin/verify-install-into-target.sh` and
     `tests/plugin/verify-e2e-dummy-target.sh` fall to the value implied by §3.5's
     removal; the suites §3.3 names under `964`'s `AC4-A` lane lose their re-run entry
     entirely; the five suites §3.6's `AC-59-12c` spawns in the working tree
     (`tests/test-issue-59-adoption-evidence-discipline.sh:553-557` at HEAD before this
     cycle) plus its five base-ref worktree re-measurements are gone.
   - **(2) No count rises**: no suite's invocation count at HEAD exceeds its merge-base
     value — this is what catches a "resolved by relocation" GREEN.
   - **(3) Every surviving multiplicity is declared**: the set of suites whose HEAD
     count remains above one is exactly `.autoflow/issue-75-verification-design.md`
     §3.13's invocation table (`59` at five sites; `798`/`799` at
     `tests/test-issue-62-sequential-rounds.sh:626`/`:629`; `964` at `:634`; `27`/`56`
     at `:278`, `56` additionally at `tests/test-issue-67-deliberation-record.sh:155`),
     and `docs/doc-invariant-registry.md` §5 carries that residual as a named
     out-of-scope row.
4. Take the composed run and its merge-base counterpart off any `dev/*-issue-62`
   branch (`tests/test-issue-62-sequential-rounds.sh:573-574` also spawns `798`/`799`
   inside a `dev/*-issue-62`-gated arm, which would otherwise contaminate the
   measurement).
5. Record the elapsed time of both runs as supporting evidence (not asserted) — a
   drop in composed-run wall-clock is expected if the relocation removed real
   duplicate work, but is not itself the oracle.

**Disposition record:** attach the two invocation multisets (or a diff of them) and
the clause-by-clause verdict to the cycle's HANDOFF report.
