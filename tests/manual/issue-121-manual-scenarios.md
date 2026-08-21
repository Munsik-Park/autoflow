# Issue #121 — Manual verification scenarios

Two acceptance criteria of this cycle are **environment-dependent**. Each is delegated
here as a recorded observation rather than converted into an assertion or a mock, and
each delegation is a design decision taken at ARCHITECT
(`.autoflow/issue-121-verification-design.md` > *Untestable items and their disposition*;
`.autoflow/issue-121-feature-design.md` §9), not a RED-time discovery.

Neither is asserted against a threshold, and neither is simulated. The composition-oracle
rule forbids a fixture register standing in for the real state an oracle reads
(`.autoflow/issue-121-verification-design.md` > *Composition oracle determination*), which
is precisely why M1 is delegated instead of given a leg in
`tests/test-issue-121-declaration-release.sh`.

---

## M1 — `inheritance-observed`: a converted suite really is inherited

**Criterion**: A8's second half — each converted suite reaches an `INHERIT:` record
against **this cycle's own** green-tree register.

**Why it is not a suite leg.** The register lives under `.autoflow/`, which `.gitignore:6`
excludes from the tree. It therefore does not exist in the environment where the new
cycle-scoped suite must run, and that suite must run there because
`scripts/test/check-suite-ci-coverage.sh` admits no unreachable suite under `tests/**`.
Substituting a fixture register would violate the composition-oracle rule and would in any
case duplicate `scripts/test/suite-coverage.sh --self-test`, which drives register-backed
inheritance over its own fixture repository and is registered **unconditionally** in CI
(`.github/workflows/contract-suites.yml`, the `suite-coverage.sh --self-test` step) — a
fixture-register leg would name no failure mode that step does not already carry.

What this cycle *changes* — the per-suite declaration and the reason token it produces —
stays fully automated, in `tests/test-issue-121-declaration-release.sh` leg **L2**
(`declaration-reason-token`), which the resolver decides from the header alone.

**Who records it, and when.** The **orchestrator**, at the **VERIFY step-1 capture point**,
from the real resolver run against the real register — the same run that writes the cycle's
`green-tree` entry. It is not recorded by a teammate and not recorded twice.

**Procedure**

1. At the VERIFY step-1 capture point, with this cycle's `green-tree` register entry already
   written to `.autoflow/issue-121-ledger.md`, run the real resolver against the real
   register:

   ```
   bash scripts/test/suite-coverage.sh \
     --root <the real repository root> \
     --ledger <this cycle's register file> \
     --cycle 121 \
     --candidates all
   ```

   `--ledger` and `--cycle` are **mandatory arguments, not omissions**:
   `scripts/test/suite-coverage.sh:889-892` rejects a missing *or empty* value with `exit 2`
   before any per-suite record is emitted, under which the observation below would be made
   over the empty set.

2. Read the per-suite records on **stderr** (`RUN: <suite> <reason>` /
   `INHERIT: <suite> <reason>`).

**What to record** — in the cycle report and, as a `green-tree-use` record, in
`.autoflow/issue-121-ledger.md`:

- which of the seven converted suites drew an `INHERIT:` record;
- the register entry each resolved against (the source heading, `head` hash and `result`
  line the record cites);
- for any converted suite that drew `RUN:` instead, its reason token — **`no-entry`** (a
  clean tree with no covering register entry) and **`dirty-worktree`** are the two remaining
  non-`out-of-tree-inputs` causes and are ordinary, not failures of this cycle;
- explicitly, that **no** converted suite's record carries the reason token
  `out-of-tree-inputs`. That clause is the one this cycle owns, and it is also asserted
  automatically by L2 — the observation records the resolver's behaviour in a live cycle,
  not the correctness of the header edit.

**PASS condition**: at least one converted suite reaches an `INHERIT:` record against a real
register entry, and no converted suite's record carries `out-of-tree-inputs`.

---

## M2 — `sweep-cost-recorded`: the local sweep-time comparison

**Criterion**: the wall-clock comparison the issue asks for.

**Why it is not a suite leg.** A local duration is host- and contention-dependent, and the
library that owns the cross-clock ratio (`scripts/test/suite-manifest.sh`, the
`SUITE_LOCAL_SLOWDOWN_FACTOR` block at `:85-121`) states in its own comment that a local
overrun is **no evidence** about the CI-clock number. The two clocks are not comparable, so
the measurement is **never asserted against a threshold** — an assertion would encode a
comparison the constant's own rule refuses.

**Who records it, and when.** The **orchestrator**, at VALIDATE, alongside the whole-tree
sweep it already runs.

**Procedure**

1. Run the unconditional whole-tree sweep and time it:

   ```
   time bash scripts/test/run-suites.sh --all
   ```

2. Repeat on the pre-change tree only if a comparison base is wanted; a single post-change
   number with its context stated also satisfies the criterion.

**What to record** — as a number with its context, never as a verdict:

- the wall-clock duration;
- the **host** it was measured on (machine / OS / core count);
- whether the run was **contended** (other CPU-heavy processes running concurrently);
- the tree state (commit SHA), so the number is re-derivable.

**PASS condition**: the number is on the issue with host and contention stated. There is no
threshold, and a slower-than-expected number is not a failure of this cycle — it is data.

---

## Not delegated

Everything else this cycle owes is automated. In particular:

- the `out-of-tree-inputs` **declaration** removal and the resolver's **reason token** —
  `tests/test-issue-121-declaration-release.sh` legs L1 and L2;
- the four residue classes (`ci-subject`, symbol closure, header id inventory, arm
  consumers) — legs L3, L4, L5 and L6;
- the registry provenance rows and the promoted entries' shape — leg L7;
- the subsumption and residue **differentials** — legs L8 and L9, driven into scratch copies
  of the tree against the real carriers, never against a mock;
- `§12`'s array-bearing enumeration — leg L10;
- the standing lints, the registry runner's teeth self-test, the baseline keystone and the
  cross-file id inventory — the whole-tree sweep, under each of those executables' own
  names (leaf rule, `scripts/test/check-suite-leaf.sh`).

One method row of the verification design is **refuted and not implemented**, recorded here
so a reader does not look for it: `ci-subject-accuracy`'s method (a), which drives
`scripts/test/select-suites.sh` over a `tests/lib/base-ref.sh`-only delta and requires
suites 67/69/27 not to be SELECTED. The selector short-circuits on `tests/lib/**`
(`scripts/test/select-suites.sh:191-194`, consumed at `:208`) **before** it reaches the
`ci-subject` token loop at `:217-227`, so every enumerated suite is SELECTED on such a delta
whether or not it declares the token — the leg would be green on the defective tree and
green on the correct one. A12 states the property over tokens and reads rather than over the
selector, and leg L3's token/reference predicate holds it.
