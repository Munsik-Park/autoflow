# Doc-Invariant Registry — Guard Lifecycle Rule

The **doc-invariant registry** (`tests/fixtures/doc-invariants.json`, run by
[`tests/run-doc-invariants.sh`](../tests/run-doc-invariants.sh)) is the single
source of truth for **permanent** documentation invariants. This document
states the rule that keeps the registry from re-accreting the false positives
it was built to eliminate: the **two-lane partition** between permanent
invariants and cycle-scoped guards, the **retirement** condition, and the
**promotion** procedure.

Background (issue #951): doc-invariant checks were historically written one
shell suite per issue, each authored under the implicit assumption that the
only diff it would ever be evaluated against was its own cycle's diff. On a
shared long-lived branch that assumption broke, producing four measured false
positives — every one of them originating in a check that was **diff-based or
line-based**. A check that instead asserts the **current STATE of a file** is
structurally immune to all four. The registry holds only that state lane.

---

## 1. Two lanes, one test each

A doc check is exactly one of two kinds:

| Lane | Nature | Home | Lifetime |
|---|---|---|---|
| **Permanent invariant** | STATE assertion — "this file/section currently contains / lacks / orders literal X", located by a durable heading anchor | the **registry** (declarative data + one runner) | forever; re-evaluated every run |
| **Cycle-scoped guard** | DELTA assertion — "*this cycle's* diff ⊆ allow-list / introduces no net-new `[MUST]`" | the cycle's own RED suite | retired when the cycle's PR merges; **never** accreted into the permanent registry |

- **Permanent invariants** are authored as **registry entries**: a state
  predicate (`present` | `absent` | `ordered`), a heading anchor (`section`),
  and `scope: "permanent"`. The runner **rejects** at load time any entry whose
  `scope` is not `"permanent"` or whose predicate is diff/count/delta-shaped —
  a cycle-scoped guard can never be shelved in the registry (fail-loud BLOCK,
  exit 1, before any evaluation).
- **Cycle-scoped guards** live in the cycle's own RED suite and use
  `resolve_base_ref` (see §4). They are governed by §2/§3, never by the
  registry.

Adding a new permanent invariant is a **data append** to `doc-invariants.json`
— no new script, no new CI step. Adding a cycle-scoped guard never touches the
registry.

---

## 2. Retirement (deactivation) condition

A cycle-scoped guard is valid **only while its cycle's PR is unmerged**. When
the cycle's PR merges, its cycle-scoped guard is **deleted** in the
merge/cleanup, along with any allow-list entries that named it.

A cycle-scoped guard left live past its cycle is a **defect**: it is the direct
source of the cross-cycle-bleed and self-referential false positives. The rule
makes its removal a required cleanup step, not optional hygiene.

---

## 3. Promotion procedure

If a guard's condition is meant to hold **forever**, it is **promoted**, not
left running as a DELTA check:

1. Rewrite the DELTA assertion as an equivalent **STATE predicate**. For
   example, a "diff must not touch `CLAUDE.md § X`" prohibition — unfixable by
   an allow-list — is promoted to a positive state invariant such as
   "`CLAUDE.md § X` still contains sentence Y", or **dropped** if it was only
   ever cycle-local.
2. Add the rewritten invariant to the registry with `scope: "permanent"`.

Promotion is a deliberate, reviewable registry edit — never an accidental
leftover script.

---

## 4. Base-ref resolution for cycle-scoped guards

Every cycle-scoped base-dependent RED suite sources
[`tests/lib/base-ref.sh`](../tests/lib/base-ref.sh) and calls
`resolve_base_ref` rather than re-inlining `merge-base HEAD main`. The resolver
is **fail-loud**: an unresolvable base ref returns non-zero, and the caller
MUST emit a visible `BLOCK`/`FAIL` — never a `SKIP` that still increments the
test count. This closes the silent-skip class where a base-dependent guard
quietly passed on a CI checkout lacking a local `main`.

The permanent registry itself reads **no** base ref (it is state-only), so the
runner has no base-ref consumer and no skip path of its own. `base-ref.sh` is
shipped as infrastructure with a hermetic self-test; the doc-invariant lane is
its single definition site — the standalone host-purity DELTA guard
(`scripts/test/check-host-purity-delta.sh`) keeps its own established
injectable `--base`/`--head` resolver and is out of scope.

---

## 5. Migration provenance — retired-guard dispositions (issue #951)

The five per-issue suites `test-issue-{794,796,797,800,949}` were migrated into
this registry and **deleted**. Each permanent (STATE) assertion became a
registry entry carrying its `origin_issue`; each cycle-scoped/diff/line
assertion was retired with a **recorded disposition** so that no coverage was
silently dropped. Every retired guard is one of exactly three dispositions:

| Retired guard | Disposition | Basis |
|---|---|---|
| 794 AC4 net-new `[MUST]` count | **dropped — cycle-local** | pure diff-delta; the permanent intent ("these `[MUST]`s exist") is carried by 794's preservation greps, now registry `present` entries |
| 796 AC3a net-new `[MUST]` + `exempt_955_patterns` | **dropped — cycle-local** | diff-delta + a per-issue exemption array; permanent content covered by 796 `present`/`absent` entries |
| 797 AC4 scope-containment (diff ⊆ base) | **dropped — cycle-local** | a this-cycle allow-list guard, no forever-condition |
| 800 AC6d deletion-audit / AC7-SCOPE allow-list (diff) | **dropped — cycle-local** | the cross-cycle-bleed false positive itself; made unrepresentable |
| 800 AC-CI-REGISTER | **promoted → runner CI-wiring** | the "a guard is registered in CI" intent survives as the runner's own single `run:`/`paths:` registration, guarded once |
| 949 AC1-EXEC / AC-CLOSURE `comm -12` manifest oracle | **dropped — redundant** | subsumed by CI `AC2e` (`verify-install-into-target.sh`), which fails an un-regenerated manifest source |
| 799 "diff must not touch `CLAUDE.md`" prohibition | **deferred** — not migrated this cycle | 799 remains a live cycle-scoped suite; this cycle only structurally bars such a DELTA guard from the registry. Its promotion-or-drop decision travels with the 799 migration follow-up |
| 16 AC5 manifest order-only baseline comparison | **dropped — cycle-local** | a one-time migration check ("the locale fix changed ordering, not content") against a snapshot captured on first run into the gitignored `.autoflow/fixtures/`. Its own header already labelled it cycle-scoped, and its cycle merged long ago. The snapshot could never be a genuine pre-fix oracle for anyone cloning after that merge — it froze whatever the manifest happened to be on that machine's first run, so the same code produced different verdicts per developer. Permanent intent carried by `test-issue-16` AC2 / `verify-package.sh` AC5d (the manifest-regeneration-idempotence pair; `test-issue-953` retired by #71), none of which needs a snapshot |
| 18 AC1 / AC3-migration / AC-preserve | **dropped — subject retired** | all three guarded the 16 AC5 fixture itself: its path constant, its one-time top-level-residue migration, and its seed-then-compare sequence. With AC5 retired they assert a mechanism that no longer exists. `test-issue-18`'s durable pair survives untouched — AC2 (the hook's discovery surface is single-level: a non-state JSON at the `.autoflow` top level fail-closed blocks, the same file under `.autoflow/fixtures/` does not) and AC-scope (the hook is byte-unchanged) |
| ADR-0016 AC-R3-c manifest artifact-count allow-list | **dropped — cycle-local** | a count-shaped predicate, which §1-2 classifies as cycle-scoped by construction. It enumerated admissible counts (35/36/42/43/46) each behind a witness row and required a manual widening on every manifest addition; widened five times, the sixth addition arrived un-widened and reddened the suite for unrelated cycles. Same three regenerate-and-compare checks carry the durable property. AC-R3-a/b are unaffected — state predicates over two named sources, not a count |
| test-issue-27-composition-oracle.sh AC-27-21a manifest artifact-count fence | **dropped — cycle-local** | the same count-shaped defect class as the ADR-0016 AC-R3-c row above: a global `artifacts\|length == 47` fence, cycle-scoped by construction per §1-2, reddened on issue #51's legitimate ADR-0017 manifest row (witness: the count moving 47→48). Converted in place to the drift-immune named-source state predicate this row documents — three named sources B6 actually protects (`docs/autoflow-guide.md`, `docs/teammate-contracts.md`, `.claude/workflows/architect-deliberation.js`), each asserted to carry exactly one manifest row — matching the `test-issue-43-report-channel-contract.sh:134-143` origin_issue-scoped precedent, applied to named sources since the manifest schema carries no `origin_issue` field. Fixed at commit `5ecfeed`. |
| verify-install-into-target.sh AC-1 manifest artifact-count fence | **dropped — cycle-local** | the same count-shaped defect class as the two rows above: a global `artifacts\|length == 47` fence (AC-1's registration check for the 4 methodology-step scripts), cycle-scoped by construction per §1-2, reddened on the same issue #51 ADR-0017 manifest row (47→48) that reddened AC-27-21a above. Dropped outright rather than converted — AC-1's existing four named-source checks (`source==dest`, `tier==root-layer`, `kind==copy`, exactly one manifest row) already fully discharge the registration intent per script, so no replacement predicate was needed; the raw count is kept as an unasserted info line. Fixed at commit `37a15c2`. |
| test-issue-62-sequential-rounds.sh AC-62-21b manifest artifact-count fence | **dropped — cycle-local** | the same count-shaped defect class as the three rows above: a global `artifacts\|length == 47` fence, cycle-scoped by construction per §1-2, reddened on the issue #51 ADR-0017 manifest row (47→48) at the #51/#62 co-landing merge. Converted to a per-source row-count predicate over the three sources the suite's own AC-62-20 hash-freshness loop pins (`.claude/workflows/architect-deliberation.js`, `docs/teammate-contracts.md`, `docs/autoflow-guide.md`); the raw count is kept as an unasserted info line. Fixed in the #51 PR-#57 conflict-resolution merge. |
| test-issue-59-adoption-evidence-discipline.sh AC-59-16a manifest artifact-count fence | **dropped — cycle-local** | same class and same witness as the row above (issue #51 ADR-0017 manifest row, 47→48). Converted to a row-count predicate over the single source the suite's AC-59-9 pins (`.claude/workflows/architect-deliberation.js`); the raw count is kept as an unasserted info line. Fixed in the #51 PR-#57 conflict-resolution merge. |
| 953 (`test-issue-953-cycle-digest.sh`) | **dropped — subject retired** | guarded the per-cycle digest data plane (`docs/cycle-digest.jsonl` schema, its append writer, the HANDOFF step-6.7 write-point). Issue #71 removes the digest emitter (`scripts/handoff/emit-cycle-digest.sh`) and the digest file by operator decision; the guarded subject no longer exists |
| 954 (`test-issue-954-cross-issue-scan.sh`) | **dropped — subject retired** | guarded the PREFLIGHT step-1.5 cross-issue complaint-class recurrence scan over `docs/cycle-digest.jsonl`. #71 removes the scan script (`scripts/preflight/scan-cross-issue-recurrence.sh`) by the same operator decision as 953; its only corpus (the digest) is gone |
| 1 (`test-issue-1-guard-contract.sh`) | **dropped — subject retired** | a meta-suite asserting that 953's and 985's premises about `docs/cycle-digest.jsonl`'s lifecycle state did not conflict. With 953 and the digest itself retired by #71, there is no conflict left to arbitrate |
| 6 (`test-issue-6-severity-parse-contract.sh`) | **dropped — subject retired** | guarded `scripts/handoff/emit-cycle-digest.sh`'s severity-parsing contract, reusing 953's isolated-temp-copy fixture pattern. The emitter is deleted by #71 |
| 7 (`test-issue-7-oracle-hardening.sh`) | **dropped — subject retired** | hardened `test-issue-1-guard-contract.sh`'s emitter-seeding oracle and temp-cleanup trap. With 1 (and its subject, the emitter) retired by #71, there is no oracle left to harden |
| 953/954 fixtures (`tests/fixtures/cycle-digest-954-*.jsonl`, `tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl`, `tests/fixtures/cycle-digest-schema.json`) | **dropped — subject retired** | fixture data for the 953/954/1/6/7 suites above; retired alongside the suites that were their only consumers |

A guard that is *dropped — cycle-local* is proven non-occurring by the
state-only property (no registry entry reads a diff). A guard that is
*promoted* gets a positive registry entry. Nothing in the retired column is a
bare deletion.

The wider allow-list/base-ref family (798/799/843/844/846/952/955/964)
migrates incrementally under this same lifecycle rule; the registry is the
enabling mechanism they reuse.
