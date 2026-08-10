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

**While a cycle-scoped lane lives, it is branch-scoped by construction** (issue
#75): its evaluation — the array's dereference, the `git diff --name-only`
feeding it, and its `resolve_base_ref` call — is dominated by a gate naming the
cycle's own issue number in `dev/*-issue-<N>` form, whose other arm emits an
uncounted `note_deferred` marker and credits no `TESTS`/`PASS`/`FAIL`. A merged
guard is then inert on every foreign branch, so a forgotten deletion is
harmless rather than red-making. `scripts/test/check-cycle-scope-guard.sh` is
the standing check that enforces this; it ships with a hermetic `--self-test`
and is registered in `.github/workflows/e2e-dummy-target.yml`.

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
| 799 "diff must not touch `CLAUDE.md`" prohibition | **dropped — cycle-local** | settled by issue #75, which deleted the off-window chain carrying it (the `claude_md_offwindow_changes` filter and its ADR / `repo-boundary-rules.md` arms). It was §1's construct in prose form — a hand-maintained inventory of admitted document *lines* a later cycle had to extend — and the file's own comment already recorded the hazard ("a bare literal … filter would pre-authorise any future CLAUDE.md fence insertion"). No forever-condition survives; in-flight containment is carried by `docs/submodule-common-rules.md` > Change Surface Rules |
| 16 AC5 manifest order-only baseline comparison | **dropped — cycle-local** | a one-time migration check ("the locale fix changed ordering, not content") against a snapshot captured on first run into the gitignored `.autoflow/fixtures/`. Its own header already labelled it cycle-scoped, and its cycle merged long ago. The snapshot could never be a genuine pre-fix oracle for anyone cloning after that merge — it froze whatever the manifest happened to be on that machine's first run, so the same code produced different verdicts per developer. Permanent intent carried by `test-issue-16` AC2 / `test-issue-953` AC6-regen-idempotence / `verify-package.sh` AC5d, none of which needs a snapshot |
| 18 AC1 / AC3-migration / AC-preserve | **dropped — subject retired** | all three guarded the 16 AC5 fixture itself: its path constant, its one-time top-level-residue migration, and its seed-then-compare sequence. With AC5 retired they assert a mechanism that no longer exists. `test-issue-18`'s durable pair survives untouched — AC2 (the hook's discovery surface is single-level: a non-state JSON at the `.autoflow` top level fail-closed blocks, the same file under `.autoflow/fixtures/` does not) and AC-scope (the hook is byte-unchanged) |
| ADR-0016 AC-R3-c manifest artifact-count allow-list | **dropped — cycle-local** | a count-shaped predicate, which §1-2 classifies as cycle-scoped by construction. It enumerated admissible counts (35/36/42/43/46) each behind a witness row and required a manual widening on every manifest addition; widened five times, the sixth addition arrived un-widened and reddened the suite for unrelated cycles. Same three regenerate-and-compare checks carry the durable property. AC-R3-a/b are unaffected — state predicates over two named sources, not a count |
| test-issue-27-composition-oracle.sh AC-27-21a manifest artifact-count fence | **dropped — cycle-local** | the same count-shaped defect class as the ADR-0016 AC-R3-c row above: a global `artifacts\|length == 47` fence, cycle-scoped by construction per §1-2, reddened on issue #51's legitimate ADR-0017 manifest row (witness: the count moving 47→48). Converted in place to the drift-immune named-source state predicate this row documents — three named sources B6 actually protects (`docs/autoflow-guide.md`, `docs/teammate-contracts.md`, `.claude/workflows/architect-deliberation.js`), each asserted to carry exactly one manifest row — matching the `test-issue-43-report-channel-contract.sh:134-143` origin_issue-scoped precedent, applied to named sources since the manifest schema carries no `origin_issue` field. Fixed at commit `5ecfeed`. |
| verify-install-into-target.sh AC-1 manifest artifact-count fence | **dropped — cycle-local** | the same count-shaped defect class as the two rows above: a global `artifacts\|length == 47` fence (AC-1's registration check for the 4 methodology-step scripts), cycle-scoped by construction per §1-2, reddened on the same issue #51 ADR-0017 manifest row (47→48) that reddened AC-27-21a above. Dropped outright rather than converted — AC-1's existing four named-source checks (`source==dest`, `tier==root-layer`, `kind==copy`, exactly one manifest row) already fully discharge the registration intent per script, so no replacement predicate was needed; the raw count is kept as an unasserted info line. Fixed at commit `37a15c2`. |
| test-issue-62-sequential-rounds.sh AC-62-21b manifest artifact-count fence | **dropped — cycle-local** | the same count-shaped defect class as the three rows above: a global `artifacts\|length == 47` fence, cycle-scoped by construction per §1-2, reddened on the issue #51 ADR-0017 manifest row (47→48) at the #51/#62 co-landing merge. Converted to a per-source row-count predicate over the three sources the suite's own AC-62-20 hash-freshness loop pins (`.claude/workflows/architect-deliberation.js`, `docs/teammate-contracts.md`, `docs/autoflow-guide.md`); the raw count is kept as an unasserted info line. Fixed in the #51 PR-#57 conflict-resolution merge. |
| test-issue-59-adoption-evidence-discipline.sh AC-59-16a manifest artifact-count fence | **dropped — cycle-local** | same class and same witness as the row above (issue #51 ADR-0017 manifest row, 47→48). Converted to a row-count predicate over the single source the suite's AC-59-9 pins (`.claude/workflows/architect-deliberation.js`); the raw count is kept as an unasserted info line. Fixed in the #51 PR-#57 conflict-resolution merge. |

### Issue #75 — cycle-scope-guard retirement

The recurrence #75 removes is one mechanism: a merged cycle's suite resolves
`BASE_REF` as `merge-base HEAD main`, so on any *later* branch the diff it
evaluates is the later cycle's files — files the merged cycle's hand-written
array cannot possibly name. The guard therefore reds every unrelated cycle
until a human edits a sibling cycle's array. Every row below is a removal of an
assertion that either asserts nothing (its subject no longer exists, or its
counted arm is unreachable) or forces that sibling edit.

| Retired guard | Disposition | Basis |
|---|---|---|
| the six unscoped path allow-list lanes (`952` G1, `955` AC-SCOPE, `798`/`846`/`848` AC10-scope, `55` `ALLOWLIST_55`, `52` `ALLOWLIST_52`) and `799`'s array + containment lane | **dropped — cycle-local** | each belongs to a merged cycle, where it protects nothing and can only force a sibling edit. Merged-cycle containment is carried by `docs/submodule-common-rules.md` > Change Surface Rules (trace rule + the pre-PR `git diff <base>...HEAD` self-audit) and by `scripts/test/check-host-purity-delta.sh`; in-flight containment stays machine-checked through each cycle's own branch-scoped lane, per §2 |
| `799` off-window arms (CLAUDE.md line filter, `docs/adr/**`, `docs/repo-boundary-rules.md`) | **dropped — cycle-local** | see the `799 "diff must not touch CLAUDE.md"` row above; the ADR and repo-boundary arms are the same hand-maintained-inventory shape |
| `7` `AC-7-7` allow-list membership lane; `62` `AC-62-33`/`AC-62-33b` | **dropped — subject retired** | their subject is the allow-list bodies deleted in the row above. Kept, `AC-62-33b` would extract empty blocks and red on its own issue branch, and `AC-7-7` would iterate zero times and pass vacuously — the class this cycle removes, manufactured by the removal itself |
| `964` AC2-B / AC2-B2 inventory cross-checks, AC1-A, AC1-C | **dropped — subject retired** | AC2-B/AC2-B2's counted arm is unreachable (the guard sweeps return no match today) and their `else` arms credit `TESTS`/`PASS` with no assertion; AC1-A/AC1-C read `tests/test-issue-949-manifest-regen-doc.sh`, deleted by #951. AC2-A/AC2-A2 stay — live repo-wide lints with real subjects |
| `964` AC4-A sibling re-run; `952` AC5 T2 | **dropped — redundant** | each re-invokes suites that are already their own top-level CI `run:` step (`798`/`799`/`955`/`846`/`848`; the install verifier and the whole E2E suite, which is CI step one and itself runs the install verifier). Whole-suite re-execution of a registered step adds no signal and misattributes an unrelated failure to the re-running step's name |
| `795` AC-INVENTORY part (a) (`inventory_keep_check`) | **dropped — subject retired** | its subject `docs/host-service-decoupling-plan.md` does not exist, so the `awk` fails to open it, the `while` loop makes zero iterations, and the function records a PASS having evaluated nothing. Part (b) is retained under the label `AC-DANGLING-REF` — a live STATE assertion over a real subject |
| `955` DC-4 | **dropped — subject retired** | its oracle subject `tests/test-issue-794-doc-assertions.sh` was deleted by #951; only the crediting arm was reachable |
| `985` `AC3-WORKFLOW-COUNT` count fence | **dropped — cycle-local** | a count-shaped predicate, cycle-scoped by construction per §1-2, and the same defect class as the four manifest artifact-count rows above: it names no file, so any future cycle adding a workflow reds a merged sibling suite. The per-filename existence conjunction beside it already fixes the set and keeps the label |
| `59` `AC-59-14b` / `AC-59-17a` / `AC-59-17b` / `AC-59-12c` | **dropped — cycle-local** | each re-runs a sibling suite and pins its assertion total against a hardcoded (or, for `AC-59-12c`, base-relative) literal, which every later cycle's legitimate assertion-count change must edit. `AC-59-12c` is additionally a blocker here: it pins `799`/`798` head totals against their base totals, which this cycle's own deletions lower |
| `59` sibling 0-failed narrowing (per subject) | **dropped — cycle-local, with recorded coverage loss** | none of the four removals above is a total pin *alone* — each conjoins a live 0-failed oracle. Surviving execution home per subject: `985` → `tests/test-issue-1-guard-contract.sh` `V6-985-exit0`, **exit-status only**; `27` → its own CI step and `tests/test-issue-62-sequential-rounds.sh` `AC-62-24`, exit-0; `1` → its own CI step, exit-0; `799`/`798` → `AC-62-37`, **exit-0 and 0-failed** (this pair loses nothing beyond the base-relative pin); `56` → `AC-62-24` and `tests/test-issue-67-deliberation-record.sh`, exit-0; `35` → **nothing but its own CI step**, exit-0. `35` is the single member losing its last cross-suite oracle, and `985` is left at exit-0 only in the cycle whose §5 routes CI registration of the unregistered-but-valid suites to a follow-up. Accepted and recorded, not silently absorbed |
| `59` retired yml-window control set (`AC-59-12c`'s own property) | **dropped — cycle-local, with recorded coverage loss** | `AC-59-12c`'s banner states the property it guards — *"the yml edit moves no other cycle's fixed CI window"* — and this cycle **is** a yml-editing cycle, so the commit performing the edit retires the tree's only standing automated guard against it. For this cycle the loss is covered by the placement rule (every new `paths:` entry is inserted strictly below its trigger block's last existing entry, so no existing entry moves and no fixed window is evicted) plus the class-A/class-B reader re-run set. After this cycle it is not covered, and that is the decision recorded here |
| `55` `registry-entries-added` | **dropped — redundant** | a second reader of the registry's own entries, which `tests/run-doc-invariants.sh` already evaluates as a registered CI step; it has no independent subject |
| `42`/`43` `GATE_SCHEMA`; `964` `FILE_949`; `7` `CANONICAL_PATHS` / `extract_allow_list_block` / `assert_allow_list_membership`; `62` `GUARD_SUITES` / `extract_allow_list_block` / `check_self_sibling_admission`; `955` `TEST_794`; `59` `DELTA_12C_LABEL_PATTERN`; `846`/`848` `BASE_REF`; `55` `BASEREF_LIB` | **dropped — subject retired** | dead symbols, each with no surviving reader once the lanes above are gone. Symbol closure is required in both directions: no orphaned definition, and every symbol a retained lane reads still defined |
| `tests/issue-92/test-boundary-nonviolation.bats` `T12-1a` diff half / `T12-1b`; `tests/issue-92/mock-gh/gh` `GH_MOCK_PR_VIEW_*` / `GH_MOCK_API_*` dispatch table | **dropped — cycle-local** | both bats halves compare against a fixed `origin/main` base, so their diff is unconditionally empty on any branch that does not touch the hook; the dispatch table's response env vars have no consumer across `tests/issue-92/*.bats`. `T12-1a`'s positive STATE half (the gate-label deny grep) is retained. Nothing executes these files, so what is verified is the **post-state** — symbol absence over committed bytes, asserted by this cycle's CI-registered suite |
| `40` `tests/test-issue-40-doc-assertions.sh` (whole file) | **promoted → runner Step 0** | its permanent content already lives in the registry under `origin_issue: 40`; its newline-literal meta guard is absorbed into `tests/run-doc-invariants.sh`'s Step 0, which **widens** it from `origin_issue==40` to every entry. The remainder was cycle-scoped for a merged cycle |

A guard that is *dropped — cycle-local* is proven non-occurring by the
state-only property (no registry entry reads a diff). A guard that is
*promoted* gets a positive registry entry. Nothing in the retired column is a
bare deletion.

The wider allow-list/base-ref family (798/799/843/844/846/952/953/955/964)
migrates incrementally under this same lifecycle rule; the registry is the
enabling mechanism they reuse.
