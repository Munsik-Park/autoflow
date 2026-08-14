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

**Execution point.** AutoFlow holds no merge authority (`CLAUDE.md` > Development Lifecycle), so
the deletion is executed in the cycle's final commit before the DELIVER push, together with the
guard's disposition row and its CI registration. GATE:QUALITY's `test-asset disposition` check
asks whether it was. This section stays the single source of the criterion; the gate item
references it rather than restating it.

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
| `955` `AC4-CLOSURE` manifest source-row DELTA | **deferred** — routed to follow-up #76 | the one residual of §1's mechanism this cycle does **not** remove. It is an unconditional (ungated) DELTA comparing the manifest's source-row set at the base ref against HEAD, so a merged cycle's lane evaluates on every later branch, and its admission chain has been widened in-file six times already — #951's registry-closure row, #979's six-row and seven-row delivery sets, #25's `confirm-ci-green.sh` row, #51's ADR-0017 row, #69's ADR-0018 row — each widening a sibling cycle's edit to a merged suite, which is exactly the tax this issue measures (`tests/test-issue-955-subagent-background-ban.sh:428`). It is **not** in this cycle's surface because it is not a path allow-list: the subject is `setup/manifest.json`'s `artifacts[].source` set, so it falls outside `scripts/test/check-cycle-scope-guard.sh`'s array-shaped subject discovery and outside §3.7's deletion criterion. Widening either to reach it is a design change, not an application of this design — the issue's own inspection table routes `955`'s STATE migration to the follow-up, and this row records the residual there rather than leaving it only in the cycle ledger |
| `75` `tests/test-issue-75-scope-guard-retirement.sh` (whole file) + `tests/manual/issue-75-manual-scenarios.md` | **dropped — cycle-local** | this cycle's own cycle-scoped guard, retired by the §2 merge-time rule it enforces — applied on the PR branch at the operator's merge decision (first application of the merge-time retirement procedure, issue #76 record). Its subjects are this cycle's landed post-states, all verified across the branch's CI runs including the post-#71 reconcile; its permanent residue already lives outside it (the `scripts/test/check-cycle-scope-guard.sh` standing lint and the runner Step 0 gate, both retained with their CI registration). The suite's NUL-byte-absence check is a promotion candidate routed to #76 |

A guard that is *dropped — cycle-local* is proven non-occurring by the
state-only property (no registry entry reads a diff). A guard that is
*promoted* gets a positive registry entry. Nothing in the retired column is a
bare deletion.

The wider allow-list/base-ref family (798/799/843/844/846/952/955/964)
migrates incrementally under this same lifecycle rule; the registry is the
enabling mechanism they reuse.

---

## 6. Migration provenance — retired-guard dispositions (issue #76)

Issue #76 executes the §3 promotion lifecycle on the suites §5 already named as
pending, gives every valid-but-unexecuted suite a real execution path, and
disposes of the one-shot cycle evidence under `tests/manual/`. The rows below
are that cycle's dispositions. The same rule §5 closes with applies here:
nothing in the retired column is a bare deletion.

| Retired guard | Disposition | Basis |
|---|---|---|
| `955 AC4-CLOSURE` manifest source-row DELTA (the row §5 deferred and routed here) | **retired — enforcement is the widening inventory; intent narrowed and promoted** | the DELTA is a *change-review gate over the manifest's source-row set*, not a closure-completeness check: it fires when the set differs between base and HEAD and is silenced by an admission entry. It never detected a source **delivered without being registered** — such a delivery leaves the row set identical at base and HEAD and passes — so the earlier framing of its intent as "a newly delivered root-layer source is registered" overstated it and is withdrawn here. Its enforcement *is* the hand-maintained admission list §1-2 retires by construction, so the review-gate content is not promotable. What is promotable needs no inventory: **the committed manifest is a fixed point of the generator over the current tree**, promoted to `scripts/test/check-manifest-regen-clean.sh` and registered in `.github/workflows/contract-suites.yml`. §5's row is thereby closed rather than routed forward again |
| the residual half of the row above — the **general root-layer registration gap** (a file delivered under `scripts/handoff/**`, `scripts/review/**` or `.claude/workflows/**` with no `emit_row` call written for it) | **retired — not machine-checkable without a second inventory** | the emit list *is* the declaration of what ships at the root-layer tier; there is no independent source of truth for "this file should ship" to compare it against, so any checker over the general case must re-declare the intended set — the hand-maintained widening inventory §1-2 retires, and the exact shape whose retirement is this cycle's subject. Routing it to a further follow-up would be routing an obligation known to be unsatisfiable under this repository's own rules. One sub-lane **is** derivable and is carried rather than retired: `setup/thin-root-layer/**` is a directory whose stated purpose is to hold the stamped bundle, so membership in it is its own declaration, and the lint's second leg requires every member to appear as an `artifacts[].source` |
| `75` NUL-byte-absence check (the promotion candidate §5's `75` row routed here) | **promoted → `scripts/test/check-tests-tree-hygiene.sh`** | the condition is permanent and its subject is a **tree**, not a named document, so the registry structurally cannot hold it — an entry's `file` is one path. Promoted to a standing lint carrying the byte test verbatim, including its non-`grep -P` implementation and its fail-loud-on-unusable-tool property: `grep -aP '\x00'` exits 2 on this host's BSD grep and a bare `! grep -aP …` reads that exit 2 as "no match", manufacturing a vacuous PASS. Its planted-NUL `--self-test` runs before the real-tree result is reported, since a clean tree cannot distinguish a working detector from a broken one |
| `951` cycle-completion legs at the `tests/test-run-doc-invariants.sh` split — the pre-flight target-file presence block, the capture-before-delete baseline reproduction and its `tests/fixtures/doc-invariants-baseline.txt` fixture, the per-`origin_issue` coverage-floor loop, the registry-volume estimate, the window-equivalence spot-check, AC5 (G) CI convergence, Deletion (H), Manifest closure (I), §DR-6 (J) and §DR-7 (K) | **dropped — cycle-local** | each asserts #951's own landed post-state (the five migrated suites gone, their CI steps gone, the manifest-closure row present, no residual per-issue exemption array, the new infra self-registered in the yml `paths:` blocks), verified across that cycle's CI runs and merged. They are the cycle-scoped half of a suite whose other half is the runner's durable contract; §2's merge-time rule retires them, and the durable half is retained under the subject name `tests/test-run-doc-invariants.sh` rather than deleted with them |
| `951` in-suite `mutation_teeth_check` mutator and its `mutate_remove` helper | **promoted → `tests/run-doc-invariants.sh --self-test`** | the equivalence question the promotion path had no mechanism for — "does the migration keep what the original assertion kept" — is answered by the same binary that evaluates the registry, so it inherits the runner's existing CI registration instead of sitting in a suite nothing executes. The retained suite asserts the mode's **contract** (exhaustive denominator, credit only on the entry's own `FAIL`, and each of the four non-credit paths driven hermetically); keeping a second mutator there would reinstate exactly what the promotion removed |
| `tests/issue-92/*.bats` count-shaped assertions — `T1-1` (`>= 6` checklist items), `T1-2` (marker appears exactly once), `T5-1b` (5 numbered steps) | **dropped — cycle-local** | a count fence is cycle-scoped by construction under §1-2 and the registry's predicate enum admits no count: a count names no file region, so any later cycle legitimately changing it reds a merged sibling. Same class as the `985 AC3-WORKFLOW-COUNT` row in §5. The positive half of each survives where it has one — `T1-2`'s marker is required by the `<!-- HOST-CLOSE-LINE -->` substitution rule in `CLAUDE.md` > PR Issue Auto-Close, and `T1-3`'s checker invocation is ported to `tests/test-issue-92-host-pr-execution.sh` |
| `tests/manual/` one-shot scenario documents for `issue-26`, `issue-43`, `issue-844`, `issue-949`, `issue-951`, `issue-952`, `issue-973`, `issue-979` | **dropped — cycle-local, no live dependent** | a scenario document is retired exactly when, after this cycle's suite deletions, no live dependent remains: no registry entry targets it, no surviving suite asserts on it, no `docs/maintained-docs.md` row registers it, no prose document cites it as evidence, and no **retained** scenario document cites it. Enumerated per document by repository-wide basename search, each hit read and classified. A workflow `paths:` entry is explicitly **not** a dependent — an entry naming a deleted file can never match, so it neither fails CI nor protects anything; `issue-26` was the only retired document carrying one, and both its entries are removed in the same commit as the deletion, below the fragile window's last guarded literal. Destination is deletion with this row rather than an out-of-repo archive (which duplicates git history while making the material unreachable to a reviewer) or a `docs/` subtree (which re-enters the maintained-document surface and rebuilds the tax this issue removes) — the disposition §5's `75` row already sets for exactly this pair |
| `843` `A3-CONSISTENCY-a` (`gate_hypothesis_structure` absent from `gate-schema.json:gated_phase_keys`) | **dropped — subject retired as a text predicate** | its oracle is a `jq` query over a JSON array's membership, not a text predicate over a document region, so the registry structurally cannot hold it — an entry evaluates `grep` over an extracted body. The property itself is live and carried by `tests/test-issue-245-schema-validation.sh`, which this cycle registers in `.github/workflows/contract-suites.yml` with `tests/fixtures/gate-schema.json` as a declared `ci-subject` path, so a schema edit fires it |
| `843` `A3-CONSISTENCY-c` (no doc surface reintroduces `gate_hypothesis_structure` as hook-gated) | **dropped — unexpressible shape** | an `absent` predicate whose pattern is an ERE alternation spanning three files. The registry admits one `file` per entry, and `absent` + `match:"regex"` is the one shape the mutation-teeth oracle names as unexpressible — literal injection cannot synthesise a witness string in an arbitrary ERE's language — so an entry in this shape could never demonstrate teeth and would be a permanent named non-credit in `--self-test`. Its positive counterparts are migrated: the two `A3-STATE` entries and the `A3-EVALSYS` entry state the corrected reading directly, on each of the three surfaces |
| `843` `AC-CI-a` / `AC-CI-b` / `AC-CI-c` and their `else`-arm occurrences; `844` `AC-CI-a` / `AC-CI-b` / `AC-CI-c` and their `else`-arm occurrences | **dropped — subject retired; property promoted** | each asserts that its **own** suite is named in `e2e-dummy-target.yml`'s `paths:` and `run:` blocks, so the assertion's subject disappears with the suite it guards. The general property they instanced — a suite has an execution path, and that path fires on an edit to the suite's own subject — is promoted to two standing mechanisms this cycle adds: `scripts/test/check-suite-ci-coverage.sh`, which makes the orphan class unrepresentable rather than merely empty, and the `# ci-subject:` registration-effectiveness oracle, which is strictly stronger than the retired form (the retired one accepted registration under a trigger list that does not name the suite's own subject, which is the defect that leaves a suite "registered" yet unable to fire) |
| `844` `AC4-h` (the `(N+1)th`-FAIL arithmetic is stated **exactly once** in `CLAUDE.md`) | **dropped — cycle-local** | a count fence: its predicate is `grep -oE … | wc -l` equal to a literal `1`. The registry's predicate enum is `present|absent|ordered` and admits no count-shaped predicate by construction (§1), and a count names no file region — any later cycle that legitimately states the arithmetic a second time (a new playbook, a translated mirror) reds a merged sibling. The property it guarded is single-definition, and its positive half survives as `844-AC4-f-regressions-line`, which pins the arithmetic to the `Regressions` line where it belongs; the "and nowhere else" half is the count fence and goes with the class |
| the ten partially-touched suites' doc-STATE assertions (`846`, `847`, `848`, `955`, `798`, `799`, `985`, `adr-0016`, `16`, `795`) | **migrated → registry entries**, the assertion removed from its suite; the suite itself retained | each moved occurrence was recorded in the cycle's migration map (`tests/fixtures/issue-76-migration-map.md`) against the registry `id` that now carries it, and every occurrence that did **not** move was recorded there too, against a §6.1 disposition naming why it is not registry-expressible. That map was a recording artefact for the #76 migration itself and has since been emitted — retired by issue #85 with the row in §7 below; the §6.1 label set it used is retained here as the durable half. The split is not by suite but by shape: a single-file, case-sensitive, single-conjunct predicate over a whole file or a resolvable anchor moves; a diff, an exit status, a count, a JSON query, a computed region, a case-insensitive match, an `absent` ERE, or a predicate spanning two files stays where it is. Migrating an inexpressible region under whole-file scope instead would discard the scoping that IS the assertion — the ground on which `844` was held unmigratable until `section_kind` landed |
| `tests/issue-92/*.bats` STATE assertions with a live carrier — `T10-1a` (handoff-sequence.yml gone), `T10-1b`/`T10-1c` (`subrepo-merged` absent from the guide / the sequencing doc), `T1-0`/`T1-3` (template exists; no raw close keyword) | **retired against an existing carrier** | each is already asserted by a live, CI-registered subject. `T10-1a` and the two `subrepo-merged` absences are `tests/test-issue-795-handoff-removal.sh`'s `AC-DEL-WF` and `AC-DEL-DISPATCH` legs — the latter two migrated by this cycle into registry entries `795-AC-DEL-DISPATCH-guide` and `795-AC-DEL-DISPATCH-extrev`. `T1-0`/`T1-3` are carried by `tests/test-issue-92-host-pr-execution.sh`, which asserts the template exists and drives the close-keyword checker over it |
| `tests/issue-92/*.bats` STATE assertions with NO prior carrier — `T12-1a` (positive half), `T10-1d`, `T10-2` | **migrated → registry entries under `origin_issue: 92`** | seven entries, each a single fixed-string predicate over one whole file, so each moves without any loss of scope: `92-T12-1a-gate-label-deny` (the deny pattern `blocked-by-(review\|subrepo)` present in `.claude/hooks/check-autoflow-gate.sh`); `92-T10-1d-helper` / `-template` / `-maintained-docs` (`subrepo-merged` absent from the host-PR helper, the PR template and the maintained-docs registry); `92-T10-2-extrev` / `-helper` / `-template` (`blocked-by-subrepo` present in the sequencing doc, the helper and the template). This row also discharges the §5 `T12-1a` row's claim that its positive STATE half "is retained" — that claim referred to the bats file, which this cycle deletes, so the half is carried by `92-T12-1a-gate-label-deny` instead |
| `tests/issue-92/test-boundary-nonviolation.bats` `T11-1b` (host tracks no blobs under `services/`) | **retired against an existing carrier** | its own body records that a diff-based check would mis-flag the gitlink restructure, so it asserts the invariant on the **HEAD tree state** — and `tests/test-issue-798-topology-flip.sh` already asserts the strictly stronger `AC2a` (`git ls-tree HEAD -- services` is empty) and `AC2b` (no `160000` row in `git ls-files -s -- services`), both live and CI-registered. Nothing is lost |
| `tests/issue-92/test-boundary-nonviolation.bats` `T11-1a-i…iv` (four forbidden command patterns over three delivered files) | **dropped — coverage loss, recorded** | these are NOT base-relative diffs: each greps the current content of `.github/pull_request_template.md`, `scripts/handoff/create-host-pr.sh` and `docs/external-review-sequencing.md` for an ERE (`gh[[:space:]]+pr[[:space:]]+merge\b`, `…ready\b`, `git[[:space:]]+push[[:space:]]+(\S+[[:space:]]+)?origin[[:space:]]+(main\|master)\b`, `git[[:space:]]+submodule[[:space:]]+update[[:space:]]+--remote\b`). They are STATE, and the earlier basis text calling them diff-shaped was wrong. They are still not migratable: an `absent` predicate over an ERE is the one shape the mutation-teeth oracle cannot express (see `76-RETAIN-ABSENT-REGEX`), and re-expressing them as fixed literals would narrow an absence guard — a whitespace variant such as `gh  pr  merge` would pass a guard whose whole purpose is to forbid it. Authoring the narrowed form would be the bare deletion this table exists to prevent, in a subtler shape: an entry that looks like the guard while admitting what the guard forbade. **What is lost** is the static content scan over those three files. **What remains**: the operational boundary is enforced at runtime by the gate hook's `gh pr merge` / default-branch-push deny, exercised by `tests/test-gate-hardening.sh` P2 (live, CI-registered), and `tests/test-issue-25-confirm-ci-green.sh` `AC6` keeps the same static scan over its own sibling script. **State at deletion**: all twelve pattern-by-file combinations were verified to hold at HEAD — zero matches — so nothing is being dropped to avoid a red |

### 6.1 Disposition labels for the issue #76 migration map

The #76 migration map accounted for **every** assertion occurrence of every
touched suite exactly once, migrated or not. An occurrence that moved named its
carriers; an occurrence that **stayed where it was** named a disposition from the
table below, with the reason it is not registry-expressible. The map itself is
retired (§7); the labels below are the durable half — the vocabulary in which a
later cycle states why a given assertion cannot become a registry entry.

Two shapes recur and are worth stating once. The registry evaluates a
`present`/`absent`/`ordered` text predicate over **one** file's extracted region,
so anything whose oracle is a diff, an exit status, a count, a JSON structure, or
a second file is outside it by construction (§1). And a region the registry's
anchor kinds cannot resolve is deliberately **not** migrated under whole-file
scope: widening the scope would drop the region-scoping that *is* the assertion's
content, which is the same ground on which `844` was held unmigratable until the
`section_kind` extension landed.

| Label | Meaning | Why the registry cannot hold it |
|---|---|---|
| `76-RETAIN-GIT-PLUMBING` | retained in place — a repository-wide `git` sweep (`git ls-files`, `git log`, `git grep`) with a pathspec exclusion list | its subject is the repository's tracked-file set, not one document's region; the registry's `file` is a single path and its predicate reads committed content, not an index query |
| `76-RETAIN-DELTA` | retained in place — a base-ref/diff-shaped guard | DELTA guards are cycle-scoped by construction (§1) and are explicitly barred from the registry: the runner reads no base ref, which is what makes a foreign cycle's diff unable to contaminate it |
| `76-RETAIN-EXEC` | retained in place — execution-shaped: it invokes a script or suite and asserts an exit status, an argv trace, or captured output | the registry evaluates committed file content; it runs nothing and has no exit-status oracle |
| `76-RETAIN-JSON-SHAPE` | retained in place — a `jq` query over a JSON document's structure (array membership, key presence, cross-field equality) | a structural query is not a text predicate over a region; expressing it as `grep` would match the same token anywhere in the file, which is a different assertion |
| `76-RETAIN-COUNT` | retained in place — a count fence (`wc -l` compared to a literal, "appears exactly once") | the predicate enum is `present\|absent\|ordered` and admits no count; a count also names no region, so any later cycle legitimately changing it reds a merged sibling |
| `76-RETAIN-CI-REGISTRATION` | retained in place — asserts the suite's own `paths:`/`run:` wiring in a workflow | its subject is the suite's registration, which is live only while the suite is. For a suite this cycle **retains**, the leg is retained with it; the general property is additionally covered by `scripts/test/check-suite-ci-coverage.sh` and the `# ci-subject:` registration-effectiveness oracle |
| `76-RETAIN-REGION-INEXPRESSIBLE` | retained in place — no `section_kind` resolves the region its source extractor read. Two causes occur here: the region is **computed** rather than anchored (a `grep -A<N>` sub-context of an already-extracted body, a multi-anchor join, a loop-built window), or its **terminator literal is not unique file-wide** — a body that ends at the next closing code fence cannot use `section_end: "```"`, because Step 0b resolves `section_end` to exactly one line and a fence recurs throughout the document, so the entry is rejected as an ambiguous anchor | migrating under whole-file scope instead would discard exactly the scoping the assertion exists to impose. The fence-terminated case is load-bearing rather than incidental: `846`'s own extractor comment records that stopping at the fence is what keeps its `host PR` discriminator from matching unrelated prose after the fence, so a widened body would make the assertion vacuously true |
| `76-RETAIN-ABSENT-REGEX` | retained in place — an `absent` predicate whose pattern is an ERE | `absent` + `match:"regex"` is the one shape the mutation-teeth oracle names as unexpressible: literal injection cannot synthesise a witness string in an arbitrary ERE's language, so such an entry could never demonstrate teeth and would be a permanent named non-credit in `--self-test` |
| `76-RETAIN-NEGATED-CONJUNCTION` | retained in place — an `assert_false` over a conjunction, i.e. "these two literals do not **coexist**" | a registry entry holds one `literal`, so the pair decomposes only into two independent `absent` entries — which assert that *neither* appears. That is strictly stronger than "not both" and would red on a document where one of them legitimately stands alone |
| `76-RETAIN-MULTI-FILE` | retained in place — one predicate ranges over two or more files | an entry holds one `file`; splitting it into per-file entries changes a disjunction into a conjunction (or the reverse) and so changes the assertion |
| `76-RETAIN-TRIGGER-REGEX` | retained in place — the frozen `TRIGGER_REGEX` and the assertions that execute it against candidate paths | the regex is an executable oracle, not document content: its positive and negative legs run it against filenames and read the match result. The design's file table names TRIGGER_REGEX assertions as staying with their suite |
| `76-RETAIN-FILE-EXISTENCE` | retained in place — asserts a path exists (or does not) rather than what it contains | the registry's predicate reads a file's content; a missing `file` already records FAIL, so an entry cannot express intended absence, and an existence-only claim has no literal to evaluate |
| `76-RETAIN-CASE-INSENSITIVE` | retained in place — the predicate matches case-insensitively (`grep -qi` / `grep -qiE`) | the registry has no case-insensitive mode. Migrating an `absent` check as a case-sensitive literal would NARROW it and let a differently-cased occurrence through, which inverts the guard; migrating it as a regex character-class produces the `absent` + `match:"regex"` shape that cannot demonstrate teeth |
| `76-RETAIN-SELF-SUBJECT` | retained in place — the assertion's subject is the suite file itself (a self-referential guard against a command or token reappearing in its own source) | its subject lives and dies with the suite, so it has nothing to migrate to; the suite is retained, and the guard is retained with it |
| `76-RETAIN-OUT-OF-MIGRATION-SCOPE` | retained in place — expressible, but outside the migration this cycle's file table names for that suite | the file table is the authority on what moves. `tests/test-issue-795-handoff-removal.sh`'s row scopes its migration to the *residual absence* assertions; its `AC-KEEP-LABEL` preservation legs stay with the retained suite. Migrating beyond a named row would be scope the plan did not evaluate |
| `76-DROP-AC4-CLOSURE` | **dropped** — the `955 AC4-CLOSURE` manifest source-row DELTA and its admission list, removed from the suite by this cycle | disposed in full by the `955 AC4-CLOSURE` row above: enforcement retired as the widening inventory, the fixed-point half promoted to `scripts/test/check-manifest-regen-clean.sh`, the general root-layer half retired as not machine-checkable without a second inventory |


---

## 7. Migration provenance — retired-guard dispositions (issue #85)

Issue #85 applies §1/§2's two-lane judgement to the test assets issue #76 left behind,
and — in the same cycle — makes that judgement a checkpoint of the flow itself
(GATE:QUALITY's `test-asset disposition` blind-spot check, and the RED naming
rule that makes the file name the first signal of its lane). The rows below are
this cycle's dispositions. The closing rule §5 and §6 share applies here too:
nothing in the retired column is a bare deletion.

The criterion, restated once so each row can cite it: a **cycle-scoped** asset
either depends on a base ref / diff (a DELTA assertion) or asserts its own
cycle's landed state; a **standing** asset states a property that must hold of
the tree forever. §2 fixes when a cycle-scoped asset is deleted.

| Asset | Disposition | Basis |
|---|---|---|
| `tests/test-issue-76-migration-map-total.sh` | **retired — cycle-scoped (DELTA)** | it resolved a base ref and materialised, from that snapshot, suites its own cycle had deleted. In a push-trigger context the base resolves to `HEAD` itself, where that snapshot does not exist — the two most recent `main` push runs failed at exactly this step. The equivalence it proved (every deleted assertion has a carrier) was emitted in the pre-merge pull-request context it was written for |
| `tests/lib/issue-76-extract-assertions.sh` | **retired — single-consumer library of the row above** | the retired suite was its only `source` site. `scripts/test/check-suite-ci-coverage.sh` excludes `tests/lib/*.sh` from its subject set, so a leftover would not have surfaced as an orphan — the deletion has to be explicit |
| `tests/fixtures/issue-76-migration-map.md` | **retired — recording artefact, with its consumer** | its only driver was the suite in the first row. Its content is the #76 migration's per-occurrence ledger, already discharged: the migrated occurrences are registry entries, and the occurrences that stayed are labelled by §6.1, which is retained. What the file cost while it lived was the exemption chain four sibling suites carried for it (see the carve-out row below) |
| `tests/test-issue-76-manual-doc-retirement.sh` | **retired — cycle-scoped (own landed state)** | its own header records that the retired/retained scenario-document lists were **frozen** at #76 design time, and it asserts them as literals. The other half — that no workflow `paths:` entry names a deleted file — is not a coverage loss: §6's `tests/manual/` row already settles that an entry naming a deleted file can never match and is therefore not a dependent |
| `tests/manual/issue-76-manual-scenarios.md` | **retired — cycle-local, no live dependent** | the same five-kind `manual-doc-closure` test §6's `tests/manual/` row defines: after this cycle's edits no registry entry targets it, no surviving suite asserts on it, no `docs/maintained-docs.md` row registers it, no prose document cites it, and no retained scenario document cites it |
| `tests/test-issue-76-runner-self-test-contract.sh` | **folded in → `tests/test-run-doc-invariants.sh`** | its own header named that file as the fold-in destination and itself as the temporary CI-facing home until the fold-in happened. The runner `--self-test` contract legs (AC-a-3), the anchor negative-coverage legs (AC-f), the teeth-mode anchor-destruction legs and the retained-scenario-document closure leg are all hermetic STATE and moved verbatim |
| ─ that suite's `AC-f` body-equality leg | **retired — cycle-scoped (DELTA)** | it materialised a deleted suite through `git show <base>:<path>` to re-derive that suite's own extractor, the same class as the migration-map suite above. Its subject — that the migrated `block` extractor reads the region the old extractor read — was settled at migration time and is not a property the tree must keep re-proving |
| `tests/test-issue-76-orphan-registration.sh` | **renamed → `tests/test-workflow-trigger-conformance.sh` — standing** | the glob-dialect conformance table, hosting-workflow-scoped coverage, `paths:` entry shape, `# ci-subject:` grammar, the block-parse fixture and the coverage-lint drive are all permanent properties of the workflow directory, none of them tied to #76's diff. Renamed to its subject per the RED naming rule this cycle adds, with its self-path literals and CI registration moved in the same commit |
| ─ that suite's `AC-c-2` trigger-window preservation leg | **retired against an existing carrier** | the six literals it required inside the fixed 40-line window, and the window computation itself, are asserted by `tests/test-issue-799-inert-cleanup.sh`'s `AC6-ci` — a live, CI-registered suite. An eviction is caught there |
| ─ that suite's `deleted-suite-still-read` sweep leg | **retired — cycle-local, not derivable** | its `DELETED_TARGETS` inventory is #76's own deletion set and its provenance exemptions name the very files this cycle retires. Generalising it needs a second, hand-maintained inventory of "names that should be gone" — the shape §6's `tests/manual/` row already fixes as not machine-checkable |
| `tests/test-issue-76-standing-lints.sh` | **renamed → `tests/test-standing-lint-drives.sh` — standing** | its subjects (`scripts/test/check-manifest-regen-clean.sh`, `check-tests-tree-hygiene.sh`) are the permanent lints §6 promoted, and this suite is what drives each to a real FAIL in a scratch worktree. A clean tree cannot distinguish a working lint from a broken one, so the drive is permanently required. Its scratch fixture filenames were neutralised with the rename |
| `tests/fixtures/issue-76-anchor-*-registry.json`, `tests/fixtures/issue-76-anchor-fixture-doc.md` | **renamed → `tests/fixtures/anchor-resolution-*` — standing** | hermetic fixtures for the anchor-kind coverage that moved into the fold-in destination; they assert the runner's resolution contract, which is permanent. The rename moved four classes of reference in one commit — the six file names, each registry's own `file` value, the fixture document's self-describing prose, and the inline registry literal in the destination suite — because the runner's load-time anchor gate rejects a dangling `file` |
| the map's carve-outs in `tests/test-issue-985-doc-assertions.sh`, `tests/test-issue-795-handoff-removal.sh`, `tests/test-issue-71-digest-removal.sh`, and the map row in the residual-token inventory fixture under `tests/fixtures/` | **removed with their subject** | each was a pathspec exclusion or exemption-array entry naming the retired map, plus the rationale prose that justified it. A carve-out whose target no longer exists is a dangling reference, and the sweeps pass silently with a dead exemption — so the removal is verified positively, by this cycle's retirement-closure assertion, not by the sweeps themselves |

### 7.1 This cycle's own new spec files (the rule applied to itself)

The same judgement is applied to the two spec files this cycle **adds**, in the
same commit series — otherwise this section's own carrier becomes the next
accretion, which is the defect the issue reports.

| New spec | Disposition | Basis |
|---|---|---|
| `tests/test-push-context-base-ref.sh` | **standing** | subject-named, no issue number. It asserts that every base-ref-consuming spec registered by a `push: branches: [main]` workflow exits 0 under the push-trigger resolution — a permanent property of the tree and its CI wiring. It **fixes** the base ref as an input condition rather than depending on a diff, so it is a STATE assertion, not a DELTA one. Its `run:` step and `paths:` entries are permanent |

## 8. Migration provenance — retired-guard dispositions (issue #73)

Issue #73 discharges ADR-0017's preconditions C1–C6 and moves that record's
`## Status` to `Accepted`. Its permanent residue is a data append to
`tests/fixtures/doc-invariants.json` (14 entries, `origin_issue: 73`); the one
new spec file states its own disposition below, per §1/§2 and the §7.1 rule
applied to this cycle.

| New spec | Disposition | Basis |
|---|---|---|

## 9. Migration provenance — retired-guard dispositions (issue #88)

Issue #88 replaces the two guaranteed-redundant unchanged-tree full re-runs (VERIFY
step 1, REFINE step 2) with a host-written Green-tree register plus a tree-identity
predicate. Its permanent residue is a data append to `tests/fixtures/doc-invariants.json`
(`jq '[.invariants[]|select(.origin_issue==88)]|length' tests/fixtures/doc-invariants.json`
entries, `origin_issue: 88`, `scope: "permanent"` — standing, not retired with the
cycle). Its two cycle assets — `tests/test-issue-88-tree-identity.sh` (cycle-scoped)
and `tests/manual/issue-88-manual-scenarios.md` (cycle-local) — were retired at the
cycle's merge-decision point per §1/§2 and the §7.1 rule: suite and manual doc deleted,
the suite's `run:` step and both `paths:` entries removed from
`.github/workflows/contract-suites.yml`, and their disposition rows removed with them,
per the #73 precedent (commit `ff68814`).

## 10. Migration provenance — retired-guard dispositions (issue #96)

Issue #96 adds the three-layer AI-initiated issue-creation gate: an unconditional
hook deny on `gh issue create` (and its same-segment REST form), a wrapper
(`scripts/issue/create-issue.sh`) that re-runs the duplicate-issue query itself
from a draft's own title rather than trusting the drafting agent's self-report,
and an operator permission layer this repository documents but cannot ship. Its
permanent residue is a data append to `tests/fixtures/doc-invariants.json`
(`jq '[.invariants[]|select(.origin_issue==96)]|length' tests/fixtures/doc-invariants.json`
→ 5 entries, `origin_issue: 96`, `scope: "permanent"`). Its new spec files, their
fixture tree, and its one manual-scenario document state their own disposition
below, per §1/§2 and the §7.1 rule applied to this cycle — caught by GATE:QUALITY
attempt 1 (avg 8.0, `test_quality` capped at 6): both suites shipped RED
issue-numbered despite being standing, permanently-CI-registered state
assertions, with no disposition stated anywhere.

| New asset | Disposition | Basis |
|---|---|---|
| `tests/test-issue-create-gate.sh` (renamed from `tests/test-issue-96-issue-create-gate.sh`) | **standing** | subject-named, no issue number, per the RED naming rule (`docs/autoflow-guide.md` > RED > Naming). It asserts permanent properties of the tree — the hook's `gh issue create` / REST-form deny, its segment-scoped co-occurrence with the pre-existing denies, and the two composition oracles (`.autoflow/` filename-namespace coexistence with `scripts/cleanup/cleanup-issue.sh`, and the hook's scan-path composition) — none of which depends on this cycle's own diff. It is a STATE assertion, not a DELTA one. Its `run:` step, both `paths:` entries, its `# ci-subject:` header, and its own self-path literals are permanent. Its retained internal fixture content that happens to read `issue-96`/`issue-97` (the namespace-coexistence oracle's seeded example state files) is not a path reference — it is the same class of self-referential example content the §7/§8 precedents (`tests/test-workflow-trigger-conformance.sh`, `tests/test-standing-lint-drives.sh`) already carry post-rename |
| `tests/test-issue-create-wrapper.sh` (renamed from `tests/test-issue-96-issue-create-wrapper.sh`) | **standing** | same basis — it asserts the permanent behavior contract of `scripts/issue/create-issue.sh` (argument/precondition validation, the draft grammar, the term-derivation and duplicate-query invariants, creation and rename binding) under the corpus-backed `gh` PATH shim, none of it tied to this cycle's diff |
| `tests/issue-create/mock-gh-search/gh`, `tests/issue-create/fixtures/corpus.jsonl` (renamed from `tests/issue-96/mock-gh-search/gh`, `tests/issue-96/fixtures/corpus.jsonl`) | **standing — fixtures of the row above** | the shim and its seeded corpus are permanent test doubles the wrapper suite depends on; renamed alongside it in the same commit so no dangling reference is left, the same treatment the `tests/fixtures/anchor-resolution-*` row in §7 gives its own renamed fixture pair |
| `tests/manual/issue-96-manual-scenarios.md` | **cycle-local (manual-scenario lane) — stays issue-named** | discharges the one non-automatable acceptance criterion (`Permission-Ask-Prompts` — the operator's harness permission prompt, decided before any in-repo process runs and therefore not observable in-repo). This is a **different lane** from the two suites above: per the live precedent this repository already carries (`tests/manual/issue-42-manual-scenarios.md`, `tests/manual/issue-52-manual-scenarios.md`, `tests/manual/issue-847-manual-scenarios.md`), a manual-scenario document is not renamed to its subject — it stays issue-named and is retired only when, per §6's `tests/manual/` disposition, no live dependent remains (no registry entry targets it, no surviving suite asserts on it, no `docs/maintained-docs.md` row registers it, no prose document cites it). Not retired at this commit: the manual doc is cited from `tests/test-issue-create-gate.sh` and remains the live operator record for `Permission-Ask-Prompts` |
