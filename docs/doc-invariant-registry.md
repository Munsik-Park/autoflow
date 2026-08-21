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
| `tests/test-push-context-base-ref.sh` | **standing** | subject-named, no issue number. It asserts that every base-ref-consuming spec registered by a `push: branches: [main]` workflow exits 0 under the push-trigger resolution — a permanent property of the tree and its CI wiring. It **fixes** the base ref as an input condition rather than depending on a diff, so it is a STATE assertion, not a DELTA one. Since issue #99 the asserted **property** stays STATE while the per-run **evidence budget** is delta-scoped: the subject set is still re-derived every run, but only the subset this run's change surface could have altered is executed, and every unselected subject's native push-topology backstop is asserted per subject (`NATIVE-COVERAGE:` lines). An unresolvable comparison base is a terminal BLOCK, never an empty selection. Its `run:` step and `paths:` entries are permanent |

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
| `tests/manual/issue-96-manual-scenarios.md` | **cycle-local (manual-scenario lane) — stays issue-named** | discharges the one non-automatable acceptance criterion (`Permission-Ask-Prompts` — the operator's harness permission prompt, decided before any in-repo process runs and therefore not observable in-repo). This is a **different lane** from the two suites above: per the live precedent this repository already carries (`tests/manual/issue-42-manual-scenarios.md`, `tests/manual/issue-52-manual-scenarios.md`, `tests/manual/issue-847-manual-scenarios.md`), a manual-scenario document is not renamed to its subject — it stays issue-named and is retired only when, per §6's `tests/manual/` disposition, no live dependent remains (no registry entry targets it, no surviving suite asserts on it, no `docs/maintained-docs.md` row registers it, no prose document cites it). Not retired at this commit: the manual doc remains the live operator record for `Permission-Ask-Prompts` (it cites the gate suite as its verification counterpart; the `docs/maintained-docs.md` row registers it) |

## 11. Migration provenance — retired-guard dispositions (issue #97)

Issue #97 adds the decision-ledger entry-identifier protocol (`scripts/ledger/ledger-entry-id.sh`
`next`/`check`, the CLAUDE.md grammar/namespace rules, and the gate hook's non-gating advisory
step). Its permanent residue is a data append to `tests/fixtures/doc-invariants.json`
(`jq '[.invariants[]|select(.origin_issue==97)]|length' tests/fixtures/doc-invariants.json`
→ 8 entries, `origin_issue: 97`, `scope: "permanent"`). Its standing spec file,
`tests/test-ledger-entry-id.sh`, is subject-named (no issue number) per the RED naming rule
from the start and needed no rename; its one cycle-scoped asset states its own disposition
below, per §1/§2 and the §7.1 rule applied to this cycle.

| Retired asset | Disposition | Basis |
|---|---|---|
| `tests/test-issue-97-ledger-id-registration.sh` | **retired — cycle-scoped (own landed state), coverage promoted rather than dropped** | its `AC-suite-registered` assertion — that `tests/test-ledger-entry-id.sh` appears in both `contract-suites.yml` `paths:` blocks and carries a `run:` step — named a fact about *this cycle's own diff*, not a forever-condition: once that registration lands, re-asserting it by literal string match is the exact `76-RETAIN-CI-REGISTRATION` shape §6 already resolves for a suite whose *own* wiring is checked. The retired assertion's subject disappears with the suite that named it (same disposition class as the `843 AC-CI-a/b/c` row in §6), and the **general property it instanced — every suite under `tests/**` has a real, effective CI execution path — is not dropped**: it is carried permanently, and more strongly, by the two standing mechanisms already registered before this cycle: `scripts/test/check-suite-ci-coverage.sh` (makes an unregistered suite an unrepresentable orphan rather than merely absent) and `tests/test-workflow-trigger-conformance.sh`'s `# ci-subject:` registration-effectiveness oracle (asserts `tests/test-ledger-entry-id.sh`'s own `# ci-subject:` paths — `scripts/ledger/ledger-entry-id.sh CLAUDE.md docs/teammate-contracts.md` — appear in the triggering `paths:` blocks, which the retired suite's literal-match form did not check at all). Retired per §2's execution point: its `run:` step and both `paths:` entries removed from `.github/workflows/contract-suites.yml` in the same commit as the suite's deletion, per the #73/#88 precedent |

---

## 12. The two-lane rule, extended to bash suites (issue #103)

§1 governs *document* assertions. Issue #103 extends the same lane distinction to the
executable specs under `tests/**`, because the property it was protecting — an assertion that
belongs to one cycle must not outlive it, and one that asserts permanent state must not be
retired with a merge — is the same property in both places. What was missing for suites was not
the rule but a **declaration**: the lane lived in a filename convention that nothing enforced.

Each suite now carries a header block whose grammar has one definition site,
`scripts/test/suite-manifest.sh`, and one enforcer, `scripts/test/check-suite-manifest.sh`. The
grammar and each field's meaning are documented at `docs/autoflow-guide.md` > RED > *Header
contract*; the lane semantics are §1's, unchanged:

- `lane: standing` — asserts permanent state, lives forever. §1's STATE lane.
- `lane: cycle-scoped` — asserts its own cycle's landed diff, inert off its own dev branch, and
  retired at the merge its `retire-with` names. §2's retirement condition, now with a
  machine-readable subject for the first time.

**Why the coupling is one-directional.** `lane: cycle-scoped` requires a path allow-list array,
which is what keeps the declaration inside `scripts/test/check-cycle-scope-guard.sh`'s subject
set. The converse is deliberately **not** asserted: a *standing* suite may carry a cycle-scoped
**arm** — a change-surface allow-list guarding its own PR — inside a body of otherwise permanent
assertions. This tree's one such suite (`tests/test-issue-71-digest-removal.sh`) is standing, and an
`array ⇒ cycle-scoped` rule would mark it for immediate retirement at an already-merged issue.
Two further suites stood here until issue #121, whose branch-gated arms were inert on every
branch that still exists once their cycles merged; the arms, their arrays and their `cycle-arm`
fields left together. §16 names both files and carries the dispositions. The separate `cycle-arm` field is what keeps such an arm governed.

**The array-less shape is non-conforming** (issue #107). A `dev/*-issue-<N>` branch gate carried
by a suite that declares neither `cycle-arm` nor a path allow-list array is outside
`check-cycle-scope-guard.sh`'s subject set by construction — that lint states its subject as every
enumerated spec **declaring a path allow-list array** (`scripts/test/check-cycle-scope-guard.sh:8-9`),
so nothing holds an array-less gate to §2's off-branch discipline, and §2 already classifies a
cycle-scoped guard living past its cycle's merge as a defect. Such a gate is therefore not a
tolerated third form; it is a defect awaiting disposition, and the disposition is decided by what
the gate's **body** asserts, never by the gate itself:

- the body asserts a **permanent property** — the gate is the defect. **Ungate** it, leaving the
  assertion unconditional. If the gate was silently supplying the body's premise, the premise is
  made hermetic in the same change rather than the gate kept (issue #107's AC-62-36(iii)).
- the body asserts a **merged cycle's own diff** — the subject no longer exists on any branch the
  tree will see again. **Delete** it, with its now-unread dependencies in the same edit.
- the body genuinely asserts a **live** cycle's diff — it declares `# cycle-arm: #<N>` and a path
  allow-list array, joining the governed form above.

An off-branch arm that credits a `PASS` counter is never merely dormant: it reports a passing
assertion about a diff it never measured, which is the vacuous-PASS class
`check-cycle-scope-guard.sh:44-47` exists to keep out, and which the array-less shape escapes only
because it falls outside that lint's subject set.

**`# ci-subject:` tokens are backed by the body, not by commentary** (issue #107). A declared
token must correspond to a **non-comment** reference to that path in the file body. A comment
mention is documentation, not a subject relation: a token backed by commentary alone selects the
suite for a delta on a file it asserts nothing about, and survives the deletion of the last
assertion that gave the declaration its meaning. This is the predicate `header-matches-content`
reads, and the same non-comment-line rule a sourcing claim about another suite is held to.

**Backlog, declared rather than retired.** Most suites in the tree carry an issue number while
asserting permanent state, which `docs/autoflow-guide.md` > RED already prohibits. This cycle
makes that backlog *enumerable* — every suite now declares its lane, so the mismatch between a
`lane: standing` declaration and an issue-numbered filename is a list a later cycle can work
through mechanically. It does not execute the renames.

### 12.1 Retired-guard dispositions

| Retired asset | Disposition | Basis |
|---|---|---|
| `tests/issue-59-full-sweep-driver.sh` (and its named exclusion in `scripts/test/check-suite-ci-coverage.sh`) | **deleted — superseded, properties re-homed** | its function was to enumerate every suite and execute the tree under an honest wall-clock budget. That is `bash scripts/test/run-suites.sh --all`, which unlike the driver has a real execution path (the driver was the tree's only spec with no `run:` step, carried by a named exclusion). The three properties its call sites asserted are re-homed, not dropped: unresolvable-base behaviour onto `scripts/test/select-suites.sh`'s fail-loud `BLOCK` contract and its `--self-test` BLOCK leg; budget honesty onto `run-suites.sh`'s per-suite `timeout <budget-secs>` and `TIMEOUT` record, driven by an over-budget/under-budget stub pair; sandbox containment structurally, since the runner creates no worktree at all |
| Sibling-suite invocations in `tests/test-issue-{59,62,67,69,71}-*.sh` (AC-59-11d/21/18, AC-59-19b, AC-59-22a/b, AC-59-25…35b, AC-62-22, AC-62-24, AC-62-31, AC-62-36(ii), AC-62-37, AC-67-DOCINV, AC-67-ANCHOR-a1/a2, AC-71-COLLATERAL-\*, AC-71-UNCOND-\*) | **retired — duplicate execution of an already-covered surface** | each callee carries its own `run:` step, so a regression in it reds CI under its own name, once per pass rather than twice — and attributing a failure to the right suite is precisely what per-step registration buys. The general property is now enforced rather than remembered: `scripts/test/check-suite-leaf.sh` denies the shapes, over a closed table whose residual it states, and `scripts/test/check-suite-ci-coverage.sh` proves no callee lost its only execution path when the calls went away |
| The shared harness ok-count pin's foreign homes and their text-form dependents (`tests/test-issue-27-composition-oracle.sh`'s literal, `tests/test-issue-59-adoption-evidence-discipline.sh`'s `EXPECTED_OK`, AC-59-14\*, AC-62-31\*, AC-67-OKCOUNT, AC-69-HARNESS-PINS\*) | **retired — subject removed by single-sourcing** | every one of them asserted a **bump discipline**: that a harness change updated both foreign literal homes in the same commit, and that no stale generation survived. With the literal single-sourced into `tests/lib/harness-pins.sh` there are no foreign homes and no synchronised bump, so the subject is gone; the staleness half would be vacuously true over a literal that no longer exists anywhere, which is the vacuous-PASS class §1 removes rather than keeps. What survives moves: *one authoring home* to `check-suite-manifest.sh`'s single-authorship arm, and *the pin still detects* to `tests/test-issue-27-composition-oracle.sh` comparing the sourced constant against the live `node test/workflows/run.mjs` measurement — the pin stays a **committed literal**, never a generated value, because a regenerated value agrees with itself and detects nothing |
| `scripts/test/check-suite-ci-coverage.sh`'s transitive-closure reachability clause | **narrowed — protected nothing, and the leaf rule makes it unsatisfiable** | the clause admitted a suite reachable only as a subprocess of a reachable suite. Checked at the branch point, every enumerated spec but the deleted driver already carried its own `run:` step, and the suite the lint's own header named as the closure instance (`tests/test-issue-40-hook-additive.sh`) has had a direct step since `contract-suites.yml` registered it — so the clause protected nothing while advertising a protection a later cycle would re-derive. With the leaf rule a closure edge is itself a violation, so it is not a route a conforming tree can offer. The stale header paragraph is corrected in the same change |
| Sibling-suite invocations the pre-#103 leaf lint could not see (`tests/test-issue-30-confirm-ci-green.sh` AC-30-10/-21/-30/-38, `tests/test-issue-979-probe.sh` C9-AC-5/-6 regression pins, `tests/test-issue-16-manifest-locale-invariance.sh` AC4's execution half, `tests/test-issue-create-gate.sh`'s `#96` coexistence re-run, `tests/test-issue-71-digest-removal.sh` AC-71-DUALPIN-oracle's execution, `tests/plugin/verify-e2e-dummy-target.sh` E-Rc's execution half, `tests/test-issue-103-workflow-conformance.sh`'s real-tree conformance drive) | **retired — duplicate execution of an already-covered surface** | the same basis as the row above, applied to the population the row's own claim did not actually cover: each of these drove a sibling through a QUOTED literal or a variable holding one, which the lint's masker erased before any denied row could read it, so the tree reported clean over a class the registry said was emptied. Each callee carries its own registered `run:` step. Two scopes are kept distinct: the EXECUTION at `tests/test-issue-71-digest-removal.sh` is removed, while its `*_SUITE=` assignment block STAYS — most of those names are live `grep` file operands of assertions this cycle does not touch, and deleting the block would remove the operands of live assertions while the lint reported the file clean, which is this cycle's own failure class. Only the five names with no reader at all (`PEER_FACILITATOR_SUITE`, `TOPOLOGY_FLIP_SUITE`, `DOC846_SUITE`, `DOC848_SUITE`, `BACKGROUND_BAN_SUITE`) are deleted, by symbol closure |
| Sibling-suite invocations written under the `sh` interpreter word (`tests/plugin/verify-e2e-dummy-target.sh` E-Ra/E-Rb, `tests/plugin/verify-install-into-target.sh` AC-Ra/AC-Rb, `tests/plugin/verify-thin-root-layer.sh` AC5a) | **retired — duplicate execution of an already-covered surface** | the same basis as the two rows above, applied to the population a `bash`-keyed grammar could not see at all. The pre-#103-cycle-3 lint matched the command word `bash` and nothing else, so five whole-suite re-runs written `sh "$SUITE"` — the form the POSIX-sh plugin suites use throughout — sat outside every denied row while the lint reported the tree clean, which is the same "registry says the class is emptied, tree still carries it" failure the row above records. Each callee carries its own registered `run:` step: `verify-install-into-target.sh` at `contract-suites.yml:317`, `verify-package.sh` at `plugin-package.yml:93`, `verify-thin-root-layer.sh` at `contract-suites.yml:329`. The EXECUTION half is removed and the PRESENCE half kept in each case, following the E-Rc disposal above — each caller composes against the callee's subject elsewhere in its own body, so the file reference stays live. One scope note: `verify-thin-root-layer.sh` AC5a additionally carried a design §8-C1 *driver* expectation (verify-package.sh's AC6d flipping RED once a settings-pin lands without the §3.5 edit). That expectation is about verify-package.sh's own AC, so it is discharged by that suite's registered step rather than dropped; AC5c(b) retains this file's static half. The mechanism is now enforced rather than remembered: the interpreter word set is closed at `{bash, sh}` at a single definition site (`invscan_interp_alt` in `scripts/test/invocation-scan.sh`), read identically by the leaf lint and by `check-suite-ci-coverage.sh`'s reachability relation, with three new self-test arms (a literal and a variable-mediated `sh` invocation, plus an I5 negative control proving a word merely *ending* in `sh` is not an interpreter word) and a residual paragraph that now names the interpreters left outside |
| `tests/test-issue-43-report-channel-contract.sh` S43-UNTOUCHED (with its `BASE_REF` resolution and `tests/lib/base-ref.sh` sourcing) | **deleted — cycle diff of a merged cycle** | the arm asserted that issue #43's own PR touched none of three named files. Its own preamble recorded that it had been narrowed from unconditional to branch-scoped precisely because those files are ones other cycles legitimately edit — so off issue #43's dev branch the promise has no subject at all, and #43 merged. The base resolution had no other reader and went with it |
| `tests/test-issue-51-teammate-removal-verdict.sh` AC1(d) and AC6(b)/(c) (with `on_issue_51_branch`, `FENCE_FILES`, `note_deferred` and the `tests/lib/base-ref.sh` sourcing) | **deleted — cycle diff of a merged cycle** | both members of the file's "lane A-delta" tier asserted properties of issue #51's landed diff against its base — the ADR `Status` value unchanged, the fenced migration-slice files untouched. Both are unevaluable off that merged cycle's branch. The whole tier is gone, so every remaining assertion in the file is unconditional |
| `tests/test-issue-52-peer-facilitator-premise.sh` scope-fence-held(b) (with `BASE52` and the `tests/lib/base-ref.sh` sourcing) | **deleted — vacuous PASS off-branch** | this arm is the one in the set that was not inert. Its off-branch arm assigned `WORKFLOW_TOUCHED=0` and fell through to an `assert_true` that credited `TESTS`/`PASS`, so on every foreign branch the suite reported a passing assertion about a diff it never measured — the exact shape `check-cycle-scope-guard.sh:44-47` names, escaped only because the array-less suite is outside that lint's subject set. Deleting it removes a passing count that measured nothing; that is a correction, not a coverage loss |
| `tests/test-issue-56-carry-evidence-discipline.sh` AC-56-8 and AC-56-9a/9b (with `BASEREF_LIB`, `B4_SHA`, `VERIFY_JS`, `HEAD_BRANCH`, `note_deferred` and the `tests/lib/base-ref.sh` sourcing) | **deleted — stale pin, subject covered unconditionally elsewhere** | AC-56-8 pinned `EXPECTED_OK=37` while the live single-sourced pin is `HARNESS_OK_COUNT` in `tests/lib/harness-pins.sh`, and the same harness measurement runs unconditionally in `tests/test-issue-27-composition-oracle.sh`, so the arm was both stale and duplicative. AC-56-9a/9b bound issue #56's own `.claude/` diff subset and pinned a cycle-era `verify-cause-branch.js` sha |
| `tests/test-issue-59-adoption-evidence-discipline.sh` AC-59-10, AC-59-11a/11b and AC-59-15a (with the `tests/lib/harness-pins.sh` sourcing, the `BASE_REF` resolution, `note_deferred` and `HEAD_BRANCH`) | **deleted — cycle diff of a merged cycle** | AC-59-10 duplicates the unconditional harness measurement in `tests/test-issue-27-composition-oracle.sh` against the same single-sourced constant — the row above already homes that property there. AC-59-11a/11b bound issue #59's own diff subset and a cycle-era sha; AC-59-15a's own deferral message stated it is "meaningless without this cycle's own base" |
| `tests/test-issue-62-sequential-rounds.sh` AC-62-23 and AC-62-35 | **deleted — stale pin, subject covered unconditionally elsewhere** | AC-62-23 pinned `EXPECTED_OK=58`, stale against `tests/lib/harness-pins.sh` and duplicating the #27 suite's unconditional run of the same measurement. AC-62-35 asserted a `.autoflow/issue-62-runtime-launch.json` record; `.autoflow/**` is gitignored, so the arm was a local VALIDATE-time obligation of that cycle alone and can never be satisfied from a checkout |
| `tests/test-issue-62-sequential-rounds.sh` AC-62-36(iv) deletion control | **ungated — permanent property, gate was the defect** | the control's mutator `git rm`s the workflow file and its manifest row and **commits** inside the worktree, so the worktree's own `BASE_REF...HEAD` diff contains a `.claude/workflows/**` path regardless of the host branch. The guard it drives iterates over that diff, so the control was already branch-independent and the gate suppressed a live assertion for nothing |
| `tests/test-issue-62-sequential-rounds.sh` AC-62-36(iii) tamper control | **ungated — premise made hermetic, gate was supplying it** | unlike its sibling this control was **not** branch-independent as written: `tamper_workflow_manifest_sha` rewrote only `setup/manifest.json`, uncommitted, contributing nothing to a three-dot diff over `.claude/workflows`, so its FAIL appeared only when the host branch itself committed such a change — the gate's preamble was supplying the premise. Ungating it unchanged would have redded the suite on every branch that leaves `.claude/workflows/**` alone. The mutator is replaced by `stale_workflow_manifest_row`, which commits a content edit to the workflow file inside the worktree and leaves that file's manifest row untouched: the committed edit both supplies the diff the guard's loop needs and **is** the stale-row condition (`wf_sha != man_sha`) the assertion claims to detect. Same property asserted, premise now local |
| `tests/test-issue-62-sequential-rounds.sh` and `tests/test-issue-59-adoption-evidence-discipline.sh` `# ci-subject: tests/lib/harness-pins.sh` tokens (and the `tests/lib/base-ref.sh` tokens in `43`/`51`/`52`/`56`/`59`) | **retired — subject removed this cycle** | the `62` token was never backed by a sourcing at all: that suite's only occurrences of the path were the header token and two comment lines, so once AC-62-23's literal went the declaration rested on commentary alone — the case §12's `ci-subject` backing rule now decides. The remaining tokens lost their last non-comment reference with the arms deleted above. Tokens move in the narrowing direction only, which cannot break AC-b-2's declared-subject × hosting-workflow `paths:` coverage requirement; both registering workflows still declare a `tests/lib/**` entry, so a change to either library still fires them and only suite selection narrows |
| `tests/test-issue-103-suite-manifest.sh`'s "test-issue-59 sources tests/lib/harness-pins.sh" row | **retired — subject removed this cycle** | its subject is the sourcing deleted above. Left standing it would have reported **green while its subject was gone**, because its predicate was a bare whole-file `grep` that `59`'s `ci-subject` token and comment mentions satisfy on their own. #103's settled property — the literal has exactly one authoring home — is carried entirely by the two negative rows beside it, which are true and untouched. In the same edit the surviving positive row for `tests/test-issue-27-composition-oracle.sh` is tightened from that bare grep to a **non-comment `source`/`.` line** predicate, so the one remaining sourcing claim is semantic rather than textual — the weakness is fixed at the row that keeps its subject, not papered over at the row that loses it |
| `tests/test-issue-103-pin-and-docs.sh`'s two "branch-scoped-inert homes are untouched" rows | **flipped — presence pin's ground retired** | one shared preamble governed both rows on the ground that each foreign home pins its own cycle's measurement on its own dev branch. This cycle retires that ground. The `62` row asserted `EXPECTED_OK=58` is **present** — the only one of this cycle's three cross-file couplings in the positive direction, so a deletion, not an omission, reds it. The `56` row claimed its companion literal was untouched while its predicate was the file-existence tautology `[ -f "$SUITE_56" ]`, reporting green on a claim it never evaluated — the same semantically-false-PASS class as the row above, one row away in the same file. Both are flipped to the identical successor form, *the file authors no `EXPECTED_OK=` literal at all*, which strengthens #103's single-authorship invariant rather than dropping it, and the `56` row's tautological predicate is replaced by one that evaluates its own claim |
| `tests/test-push-context-base-ref.sh`'s two literal pins on `tests/test-issue-59-adoption-evidence-discipline.sh` (the under-derivation pin and the real-tree `NATIVE-COVERAGE` corroboration arm) | **repointed — pinned subject retired, property preserved** | that suite pins one literal suite name into its derived subject set so a silent under-derivation fails loud instead of merely shrinking the printed set, and separately asserts that same subject reports `NATIVE-COVERAGE PASS`. Both name one subject and move together: a suite that is no longer derived cannot report a coverage state at all, so repointing only the first leaves the second asserting a state its subject can never produce. `59` was chosen because it was a real non-comment resolver call site; this cycle removed its last one, so the subject left the derived set legitimately and the pin would have redded a standing suite under an unrelated name. The guard's value is the pin, not any particular subject, so it is repointed rather than deleted. The successor is chosen by the property the pin needs — registered by a `push: branches: [main]` workflow, not in `EXEMPT_HERMETIC_DRIVERS`, and carrying a non-comment resolver call against the repo under test — which `tests/test-issue-27-composition-oracle.sh` satisfies and this cycle does not touch; `tests/test-issue-798-topology-flip.sh` is the alternate if `27` ever loses the call |
| `tests/test-issue-62-sequential-rounds.sh:93-112` (`guard_result_at_ref_mutated`) and `tests/test-issue-103-pin-and-docs.sh`'s AC-pin-detects-harness-drift drive | **kept — intentional leaf exemption, negative control** | neither re-runs a registered sibling. Each drives a suite at ANOTHER ON-DISK STATE — a detached worktree at a historical ref, and a scratch worktree whose harness is deliberately perturbed — and the callee's own CI step, running the unperturbed tree, cannot stand in for it. The admission is a consequence of rows the lint itself evaluates, not a machine-readable exemption input: the #62 call site's argument is a function positional under a `tests/` prefix, which D5's antecedent (an assignment carrying a literal enumerated-suite path) does not have, and the pin-drift site's path is rooted at a scratch variable this file assigns from `mktemp`, which is row I3/I4's antecedent. This row records the GROUND for keeping them, not the mechanism that admits them |

## 13. Migration provenance — retired-guard dispositions (issue #109)

Issue #109 is auxiliary-asset hygiene for `tests/`: it closes the drift between what a
scenario document or a suite's section header *declares* and what the tree actually
carries. Two populations are dispositioned below — the zero-inbound scenario documents
under `tests/manual/`, and the assert-less acceptance-criterion section headers left
behind by the #76 migration. The closing rule §5, §6 and §7 share applies here too:
nothing in a retired column is a bare deletion.

### 13.1 `tests/manual/` scenario documents — the zero-inbound population

All six documents below are **indistinguishable under the inbound-reference
predicate**: a tree-wide `grep -rIl` for each basename (self, `.git` and `.autoflow`
excluded) returns nothing for every one of them. Retirement therefore rests on a second
predicate — **whether the prescribed procedure is still replayable at an arbitrary
head**. The retained side is recorded here as explicitly as the retired side, so the
next tree audit re-reads a basis instead of re-opening the question.

Disposal path is **deletion, recorded** — §6's `tests/manual/` row already fixes that
for a scenario document, on the ground that an out-of-repo archive duplicates git
history while making the material unreachable to a reviewer. `$AUTOFLOW_ARCHIVE_ROOT`
is not a candidate: `scripts/cleanup/cleanup-issue.sh` is its only writer and its
subject is `.autoflow/issue-{N}*`.

Each retired row records the five-kind closure result as an authored finding for that
file — no registry entry targets it, no surviving suite asserts on it, no
`docs/maintained-docs.md` row registers it, no prose document cites it, and no retained
scenario document cites it. That criterion is stated here in its own right and is **not**
delegated to `tests/test-run-doc-invariants.sh`'s `AC-c-3` clause 2, whose
`RETAINED_DOCS` array names none of these six and therefore evaluates nothing about
them.

| Document | Disposition | Basis |
|---|---|---|
| `tests/manual/issue-81-manual-scenarios.md` | **retired — procedure no longer replayable** | its M1/M2/M3 procedures act on "the chosen open PR" of that cycle; that PR is no longer open, so the stimulus cannot be re-created at any later head. Five-kind closure holds: no registry entry targets it, no surviving suite asserts on it, no `docs/maintained-docs.md` row registers it, no prose document cites it, no retained scenario document cites it |
| `tests/manual/issue-85-manual-scenarios.md` | **retired — one-shot observation window closed** | M1 instructs the operator to locate the push-triggered workflow runs produced by that cycle's own merge commit — a post-merge window that closed with the merge. Five-kind closure holds, as above |
| `tests/manual/issue-99-manual-scenarios.md` | **retired — one-shot observation window closed** | M1 likewise pins the `contract-suites.yml` run produced by that cycle's merge commit. Five-kind closure holds, as above |
| `tests/manual/issue-89-manual-scenarios.md` | **retained — replayable at any head** | its dry-run fixes its own inputs and pass condition inside the document, so the rubric dry-run replays at an arbitrary head; its oracle is an LLM evaluator's judgment, which no repository test observes |
| `tests/manual/issue-93-manual-scenarios.md` | **retained — replayable at any head** | its two criteria are walks of the lint-chain rule *in the current checkout*; cycle 2's section is the live record for the `not-run` reason-class split |
| `tests/manual/issue-100-manual-scenarios.md` | **retained — live delegated record, vehicle repaired** | M1 is explicitly `Status: delegated to user` and still unmet. This cycle repairs its reproduction vehicle rather than retiring it: Step 2's `tests/test-issue-979-probe.sh` recommendation is a false-negative pass condition (that suite's pre-fix `run_bounded` already reaped the watchdog), replaced by a condition-first step naming `tests/test-push-context-base-ref.sh`'s `run_bounded_in`. The corrected literals are pinned by the `109-AC-repro-site-*` / `109-AC-measurement-anchor-cited` registry entries |

### 13.2 Assert-less acceptance-criterion section headers

These blocks are residue of the #76 migration, which moved each suite's doc-STATE
assertions into registry entries and left the printing header behind. A block that
prints `=== AC5 … ===` and asserts nothing tells a reader the criterion is checked
here when it is checked elsewhere. Keeping the `echo` and adding a comment underneath
preserves exactly that false signal, so the `echo` line and its orphaned comment body
go, and each suite's own Scope / RED-expectation header list is narrowed to what the
body executes, with the migrated ids annotated by their carrier.

**Carrier notation is fixed for every row below.** The carrier column is the leg that
separates this cleanup from silent coverage loss, so it must be machine-resolvable and
prose is not. Every row states its carrier in exactly one of two forms: (1) a registry
`id` that appears in `jq -r '.invariants[].id' tests/fixtures/doc-invariants.json`, or
(2) a repository-relative path **plus** the assertion-description literal, verbatim,
that greps in that file.

| Suite | Header removed | Carrier |
|---|---|---|
| `tests/test-issue-798-topology-flip.sh` | AC5 DOC-CLAUDE-CLASS | `798-AC5-positive-singlerepo`, `798-AC5-negative-multirepo-gone` |
| `tests/test-issue-798-topology-flip.sh` | AC15 README-SYNC | `798-AC15a-no-recurse`, `798-AC15b-no-submodule-tree`, `798-AC15c-degenerate-prose` |
| `tests/test-issue-799-inert-cleanup.sh` | AC1 README-CONSUMED-PRESENT | `799-AC1-neg-wizard`, `799-AC1-pos-marketplace`, `799-AC1-pos-target` |
| `tests/test-issue-799-inert-cleanup.sh` | AC3 README-CHECKLIST-CURRENT | `799-AC3D-checklist-neg`, `799-AC3D-checklist-pos`, `799-AC3D-section-neg` |
| `tests/test-issue-799-inert-cleanup.sh` | AC6 INDEX-INERT-ROUTE-ABSENT | `799-AC5D-index-neg`, `799-AC5D-index-pos`, `799-AC5D-maint-header`, `799-AC5D-maint-qualifier` |
| `tests/test-issue-799-inert-cleanup.sh` | AC7 GITWORKFLOW-DEFERRAL-CLEARED | `799-AC5G-neg-s11a`, `799-AC5G-guard-active-na` |
| `tests/test-issue-799-inert-cleanup.sh` | AC9 DEGENERATE-PROSE-PRESERVED | `799-AC5H-degenerate` |
| `tests/test-issue-799-inert-cleanup.sh` | AC11 NO-SUBMODULE-REINTRO | **form 2** — `tests/test-issue-798-topology-flip.sh`, literals `AC2a: git ls-tree HEAD -- services is empty`, `AC2b: git ls-files -s -- services has no 160000 mode row`, `AC3a: git submodule status is empty`, `AC3b: HEAD .gitmodules path-entry count == 0` |
| `tests/adr-0016-conformance-check.sh` | AC4 DIAGNOSE non-contradiction | `adr0016-AC4-a-diagnose-heading` |
| `tests/adr-0016-conformance-check.sh` | AC5 case-collection result | `adr0016-AC5-a-casecollection-heading` |
| `tests/adr-0016-conformance-check.sh` | AC6 follow-up scope separated | `adr0016-AC6-a-followup-heading` |
| `tests/adr-0016-conformance-check.sh` | AC-961-5 Status + owner approval | `adr0016-AC961-5-a-owner-approval`, `adr0016-AC961-5-b-readme-accepted` |
| `tests/adr-0016-conformance-check.sh` | AC-961-7 numbering-gap note | `adr0016-AC961-7-a-range`, `adr0016-AC961-7-b-date`, `adr0016-AC961-7-b-repo`, `adr0016-AC961-7-c-registry` |

**The one header without a registry carrier.** `799` AC11 (NO-SUBMODULE-REINTRO) has no
`origin_issue: 799` registry entry, so its row takes form 2. The property is not
dropped: the four `798` literals it names are strictly stronger than "no
reintroduction", live, and CI-registered — the same disposition class §6 already used
when it retired the bats `T11-1b` guard against those same four assertions.

**Scope discipline.** Only the enumerated headers were touched. Guard sections that
carry assertions keep both their header and their body. No `assert_true`/`assert_false`
call, no results footer, and no `PASS`/`TESTS` counter arithmetic changed in any of the
three suites; `tests/fixtures/issue-109-assertion-baseline-{798,799,adr0016}.txt` pins
that as a set-inclusion invariant.

### 13.3 Script↔manual cross-references (no retirement)

`tests/plugin/verify-package.sh` and `tests/plugin/verify-install-skill-scripts.sh`
gained the missing script→doc half of the cross-reference with
`tests/plugin/manual-scenarios.md` / `tests/plugin/manual-scenarios-943.md`, in the
**comment form** `tests/plugin/verify-install-into-target.sh` already uses — not the
`# ci-subject:` token form. The token form is barred here by §12's backing rule (a
declared token must correspond to a non-comment body reference) together with
`tests/test-workflow-trigger-conformance.sh` `AC-b-2`, which would drag
`.github/workflows/plugin-package.yml`'s trigger semantics into this cycle's change
surface. Nothing is retired by this item.

---

## 14. Migration provenance — retired-guard dispositions (issue #119)

Issue #119 reduces the `contract-suites` full run by removing verification
redundancy and over-long real waits. Every removal below is a **subsumption**
claim — "another check already owns this invariant" — and §5/§6/§7's closing
rule applies unchanged: nothing in the retired column is a bare deletion.

**Owner strength classes**, used as vocabulary by every row:

| Class | Meaning |
|---|---|
| `unconditional-step` | the owner is a workflow step with no `if:` guard, so it runs on every triggered run of its workflow |
| `selection-gated-step` | the owner is a per-suite step behind `if: contains(… steps.select.outputs.suites …)`; admissible only where the deleting suite is itself selection-gated **and** the owner's selection trigger covers the deleted assertion's subject |
| `in-suite-arm` | the owner is a surviving arm in the same file |
| `re-homed` | the invariant is moved to a new, cheaper carrier written in this cycle |
| retired | the assertion was a one-shot pin on a past deletion; no future tree state re-introduces its subject without a separate intentional edit |

**`unconditional-step` is scoped WITHIN a triggered run, not per push.**
`.github/workflows/contract-suites.yml` is `paths:`-filtered on both
`pull_request` (`:19-`) and `push` (`:127-`), and
`.github/workflows/e2e-dummy-target.yml` likewise (`:29-31`). A step with no
`if:` is therefore unconditional only once its own workflow has been triggered.
Every cross-workflow row below names the owner workflow's `paths:` entry that
admits the deleted invariant's subject path; an owner claim resting only on the
absence of an `if:` guard is not admissible here.

### 14.1 Dispositions

| Asset | Disposition | Basis |
|---|---|---|
| `tests/test-issue-103-pin-and-docs.sh` — the UNPERTURBED composition-oracle re-invocation (`AC-pin-detects-harness-drift` baseline) | **retired — `selection-gated-step`** | owner: `.github/workflows/e2e-dummy-target.yml:588-591`, the `tests/test-issue-27-composition-oracle.sh` step, admitted by that workflow's own `paths:` entry `tests/test-issue-27-composition-oracle.sh` (`:104` pull_request, `:259` push). The deleting suite is itself selection-gated, and its `# ci-subject:` set (`tests/lib/harness-pins.sh`, `tests/run-doc-invariants.sh`, `tests/fixtures/doc-invariants.json`) is a subset of the owner suite's, so no pull-request delta selects the host without also selecting the owner. The **perturbed** run at the same arm is RETAINED: it is the operative half, and no other carrier perturbs the harness |
| `tests/test-issue-103-pin-and-docs.sh` — `AC-no-regression-on-removed-assertions (c)`'s composition-oracle re-run | **retired — `selection-gated-step`**; the `[ -f "$PIN_HOME" ]` half stays as an `in-suite-arm` | same owner and same `paths:` entry as the row above |
| `tests/test-issue-103-pin-and-docs.sh` — the real-tree `tests/run-doc-invariants.sh` run and its assertion (`AC-doc-contracts-registered`) | **retired — `unconditional-step`** | owner: `.github/workflows/e2e-dummy-target.yml:404` (`run: bash tests/run-doc-invariants.sh`, no `if:`), admitted by that workflow's `paths:` entry `tests/run-doc-invariants.sh` (`:45` pull_request, `:216` push) — the deleted assertion's subject path exactly |
| `tests/test-issue-103-pin-and-docs.sh` — the `run-doc-invariants.sh --self-test` run (`AC-doc-contracts-registered`) | **retired — `unconditional-step`** | owner: `.github/workflows/contract-suites.yml:562` (`run: bash tests/run-doc-invariants.sh --self-test`, no `if:`), admitted by that workflow's `paths:` entry `tests/run-doc-invariants.sh` (`:89` pull_request, `:197` push) |
| `tests/test-issue-103-pin-and-docs.sh` — the `AC-pin-dependents-disposed` text-pin group (the #62/#59/#69/#67/#56 removal pins and GATE:PLAN F1's row) | **retired** | each asserted that a past deletion had already landed. No future tree state re-introduces those literals without a separate, intentional edit, which the pin single-home invariant (`tests/test-issue-103-suite-manifest.sh` PIN group) and the retained harness-perturbation drift arm already govern |
| `tests/test-run-doc-invariants.sh` — the real-registry `--self-test` run and its exit-status / NO-TEETH assertions | **retired — `unconditional-step`** | owner: `.github/workflows/contract-suites.yml:562`, admitted by `paths:` entry `tests/run-doc-invariants.sh` (`:89` / `:197`). The runner credits only teeth-demonstrating entries and exits non-zero unless credited equals total, so the step's own exit status carries both halves |
| `tests/test-run-doc-invariants.sh` — the real-registry `--self-test` **denominator** assertion (reported total equals `.invariants \| length`) | **`re-homed` → `tests/run-doc-invariants.sh` itself** | the step's exit status did NOT own this: the self-test gates `ST_TOTAL > 0` and `ST_OK == ST_TOTAL`, never `ST_TOTAL == registry length`, and three paths `continue` before the counter (empty resolved id, `file` not in the tree, unrecognised predicate), so a mode that silently iterated a subset still exited 0. The guard now lives in the runner's own self-test exit predicate ("Denominator coverage gate"), where the real registry drives it through the unconditional step above. A hermetic fixture is NOT the carrier — a fixture is authored to take none of the three skip paths — it is only the guard's Red-state driver (`tests/fixtures/denominator-coverage-registry.json`, with `…-complete-registry.json` as the direction control) |
| `tests/test-run-doc-invariants.sh` — `AC-a-3`'s real-registry `--self-test` and default-mode runs | **retired — `unconditional-step`**; the output-shape halves are retargeted at a hermetic fixture registry (`in-suite-arm`) | owners: `.github/workflows/contract-suites.yml:562` (`--self-test`) and `.github/workflows/e2e-dummy-target.yml:404` (default mode), admitted by the `tests/run-doc-invariants.sh` `paths:` entries named above. What those arms actually assert is output SHAPE, which no exit status owns, so it stays — driven against `tests/fixtures/denominator-coverage-complete-registry.json` at negligible cost |
| `tests/test-issue-245-schema-validation.sh` — `A8b`'s exact `== 11` deny-site pin | **relaxed to a floor (`>= 11`), not retired — `in-suite-arm`** | the removal direction is what the pin exists for (a consolidation that silently drops a deny) and the floor keeps it; the addition direction is released so a later deny-adding commit needs no edit here. The relaxation is kept from being a deletion by the paired `A8d`/`A8e` perturbation drives added in the same file, which add and remove a deny site in a scratch worktree copy of the real hook and require green and red respectively. The floor is a RATCHET: raised deliberately, never lowered |
| `tests/test-issue-245-schema-validation.sh` — `B-POS3` (bare-number score form → `git push` passes) | **retired — `selection-gated-step`** | owner: `tests/test-issue-223-schema-hook-contract.sh:428-429` (`B5: git push passes w/ bare-number scores`), run by `.github/workflows/schema-hook-contract.yml:90-94`, admitted by that workflow's `paths:` entries `.claude/hooks/check-autoflow-gate.sh` and `tests/fixtures/gate-schema.json` (`:29-30` pull_request, and the mirrored push block) — both suites' subject is the same hook file, so any delta selecting one selects the other. This file's `B5.1`/`B5.2`/`B5.3` are negative cases and never covered the bare-number positive; `B-POS4` and `B-POS5` are retained |
| `tests/test-issue-103-orphan-coverage.sh` | **retired — whole suite** | per-assertion: the lint `--self-test` exit-0 arm and the real-tree arm are owned by `.github/workflows/contract-suites.yml:532` (`run: bash scripts/test/check-suite-ci-coverage.sh`, no `if:`), which self-tests before reporting, admitted by that workflow's `paths:` entry `scripts/test/check-suite-ci-coverage.sh` (`:72` pull_request, `:180` push) — `unconditional-step`. The de-linked-callee fixture drive's REPORTED half is owned by the lint's own DIRECT-REACHABILITY leg. The superseded-driver absence pin and the two header-prose pins are retired one-shots. The one non-subsumed half — that the lint EXITS non-zero when an orphan exists — is `re-homed` into the lint's own `--self-test` as the EXIT-STATUS leg (see 14.2) |
| `tests/test-issue-103-workflow-conformance.sh` | **retired — whole suite** | per-assertion: the `# ci-subject:` coverage sweep is owned by `scripts/test/check-suite-manifest.sh` `check_headers`, whose enumeration is a strict superset of the retired sweep's depth-1 `test-*.sh` glob, run at `.github/workflows/contract-suites.yml:541` with no `if:`, admitted by `paths:` entry `scripts/test/check-suite-manifest.sh` (`:121` / `:229`) — `unconditional-step`. The manifest regen-clean and maintained-docs-sync arms are owned by `:559` and `:556` of the same workflow, admitted by `paths:` entries `scripts/test/check-manifest-regen-clean.sh` (`:71` / `:179`) and `scripts/test/check-maintained-docs-sync.sh` (`:118` / `:226`) — `unconditional-step`. The three-sibling `paths:`-window sweep is owned by each sibling's own window guard and its own registered step — `selection-gated-step` per suite. The header-parse existence assertion is owned by every consumer that calls `suite_header_field` and fails loudly without it (`scripts/test/select-suites.sh`, `check-cycle-scope-guard.sh`, `suite-coverage.sh`), all reached from unconditional lint steps; its two text pins and the registration-row pin are retired one-shots |
| `.github/workflows/contract-suites.yml` — the two retired suites' steps and their four `paths:` entries | **removed with their suites** | leaving either behind is the dangling reference `scripts/test/check-suite-ci-coverage.sh` and `tests/test-workflow-trigger-conformance.sh` exist to report, so the removal is verified by those lints rather than by a new assertion. `tests/test-workflow-trigger-conformance.sh`'s `AC-no-stale-trigger-path` arm, added this cycle, closes the reverse direction: a literal `paths:` entry with no file behind it |
| `tests/test-bounded-execution-fallback.sh` — the six real-wait bounds (47/59/67/41/71/83 → 9/15/11/8/13/17) | **reduced, not retired — `in-suite-arm`** | the bounds are the suite's wall clock. Two floors re-derived from the file bound the reduction: a granularity floor of `>= 8` over the suite's own 5-second early-exit ceiling (`PROBE_ELAPSED -lt 5`), and, for the one drive that locates its subject by polling, a discovery floor of `bound >= 2 x the poll budget` (the poll is shortened from 40 to 24 iterations at 0.25s). Three of the six asserted only absence-shaped facts, which a subject that never hung also satisfies, so each reduced drive is given a fire signal reading the product's own exit contract (`scripts/preflight/check-review-backend.sh` exit 3; `scripts/handoff/confirm-ci-green.sh` exit 14) before its bound is shrunk. The pipe-release bound is explicitly outside the reduction set and keeps its `>= 6` constraint |

### 14.2 The two `re-homed` invariants and their new carriers

Both are product-side self-test hardenings, not new suites — each gives a
re-homed invariant a carrier inside an already-`unconditional-step`.

| Invariant | New carrier | Red-state driver |
|---|---|---|
| the doc-invariant self-test's reported denominator is the registry's own entry count | `tests/run-doc-invariants.sh` — "Denominator coverage gate" in the self-test exit predicate, comparing `ST_TOTAL` against `jq '.invariants \| length'` and failing loud with both numbers named | `tests/fixtures/denominator-coverage-registry.json` (third entry names a file not in the tree); `…-complete-registry.json` is the direction control |
| the suite-coverage lint EXITS non-zero when an orphan exists, not only reports the unreachable set | `scripts/test/check-suite-ci-coverage.sh` — the EXIT-STATUS leg of its own `--self-test`, which re-invokes the lint in DEFAULT mode against a fixture root holding a known orphan | a copy whose terminal orphan-reporting `exit 1` is defanged to `exit 0`, driven from `tests/test-workflow-trigger-conformance.sh` |

The EXIT-STATUS leg runs from the `--self-test` branch, **outside** `self_test()`:
default mode is gated on `if ! self_test`, so a re-invocation placed inside
`self_test()` would recurse unboundedly, and `self_test` removes its fixture
before returning.

## 15. Migration provenance — retired-guard dispositions (issue #123)

Issue #123 adds the ARCHITECT cap-round closing half-round. Its RED phase authored a
cycle-scoped suite, `tests/test-issue-123-closing-half-round.sh` (`retire-with: #123`),
carrying four assertions. GATE:QUALITY (avg 8.7) bound the §2 execution point to this
cycle's own final pre-DELIVER commit: the suite is retired here, following §6's rule
that nothing in a retired column is a bare deletion.

| Retired guard | Disposition | Basis |
|---|---|---|
| `AC-123-drift-closing-label` — `CLOSING_CALL_LABEL` identical between `.claude/workflows/architect-deliberation.js` and `test/workflows/run.mjs` | **promoted → registry entries `123-AC6-closing-label-prod` / `123-AC6-closing-label-harness`** | the DELTA (an equality between two files) is unfixable by an allow-list, so §3 rewrites it as two positive STATE predicates instead: each file's declaration line, `const CLOSING_CALL_LABEL = 'test-closing'`, is individually pinned `present`, `scope: "permanent"`. The pair still catches drift — a change to either file's line reds that entry alone — without the registry needing a cross-file equality predicate it structurally cannot express (§1: one entry evaluates one file's region) |
| `AC-123-drift-closing-missing-reason` — `REASON_CLOSING_AGENT_MISSING` identical between the two files | **promoted → registry entries `123-AC5-closing-reason-prod` / `123-AC5-closing-reason-harness`** | identical reasoning to the row above, over the declaration line `const REASON_CLOSING_AGENT_MISSING = 'closing agent missing'` |
| `AC-123-pin-sanity` — `tests/lib/harness-pins.sh` declares a positive-integer `HARNESS_OK_COUNT` | **dropped — subject retired against an existing carrier** | the actual pin-vs-measurement comparison this fence was a sanity check *for* already lives in the standing `tests/test-issue-27-composition-oracle.sh` (`AC-27-20c`), which runs unconditionally and re-executes on every harness/pin edit (`# ci-subject:` includes `test/workflows/run.mjs` and, via `tests/lib/**`, `tests/lib/harness-pins.sh`). This suite's own leg added no coverage the composition oracle did not already have; retiring it removes a redundant execution path rather than a property |
| `cycle-scope-respected` (`AC-123-SCOPE`) — this cycle's own branch diff stays within its declared `allow_list` | **dropped — cycle-local** | a branch-scoped change-surface fence over `dev/*-issue-123`'s own diff, per §1-2's DELTA/cycle-scoped classification; it is inert off that branch by construction and has no state to promote. Retired with the suite that carried it, per §2 |

**CI de-registration.** `.github/workflows/contract-suites.yml` drops the suite's `run:`
step (id `s-test-issue-123-closing-half-round`) and its two `paths:` entries
(`pull_request` and `push` blocks). `tests/manual/issue-123-manual-scenarios.md` is
**retained** — AC9 stays environment-dependent (the hosted Workflow runtime is not
launchable from this repository's test tree) and its scenario is still `Status:
delegated to user`; its cross-reference to the retired suite is corrected to name the
two promoted registry-entry id prefixes instead.

`tests/test-issue-103-cycle-scope-repoint.sh`'s allow-list-bearing suite count tripwire
returns to **3** with this retirement (it read 4 for the span between this cycle's RED
commit and this one).

---

## 16. Migration provenance — retired-guard dispositions (issue #121)

Issue #121 releases seven suites from `# out-of-tree-inputs: yes` by removing the
base-ref call sites their headers followed. The header is not the lever — the body
is (`scripts/test/suite-manifest.sh` `suite_reads_out_of_tree_state`), so each
declaration leaves only once its file's last base-ref arm does. Two shapes are
retired here, and they take different exits under §2/§3:

- **Lane A — branch-gated arms** (`tests/test-issue-67-deliberation-record.sh`,
  `tests/test-issue-69-verification-depth.sh`). Every arm sat behind that cycle's own
  `dev/*-issue-<N>` gate, and both cycles are merged, so each is inert by construction
  on every branch that exists now. §3 offers nothing to promote: a change-surface fence
  over one branch's own diff has no state form. The `allow_list` arrays and the
  `cycle-arm` header fields go with them (`check-suite-manifest.sh` makes `cycle-arm`
  without an array a violation), which is what removes both files from
  `scripts/test/check-cycle-scope-guard.sh`'s subject set and reduces §12's coupling
  passage to `tests/test-issue-71-digest-removal.sh` alone.
- **Lane B — un-gated DELTA fences**, dispositioned per arm below.

Nothing in the retired column is a bare deletion (§6 rule).

| Retired guard | Disposition | Basis |
|---|---|---|
| 67 `change-surface-bounded` / 69 `change-surface-bounded`, `AC:rubric-unchanged`, `AC:oracle-clause-untouched` (Lane A) | **dropped — cycle-local** | branch-gated on `dev/*-issue-67` / `dev/*-issue-69`, both merged, so inert on every branch that exists now; a fence over one branch's own diff has no state form. The disposition §15's `cycle-scope-respected` row already records. Symbol closure went with them: 67's `note_deferred()` (sole call site was the deleted off-branch arm), both files' `HEAD_BRANCH` assignment, 69's `on_issue_branch()` and its `CLAUDE_MD` constant. 69's `note_deferred()` is retained — the `AC:manifest-fresh` deferral arm still calls it |
| 798 `AC9: diff touches no .claude/hooks/** path, OR only check-autoflow-gate.sh…` · 799 `AC6-scope: diff does not touch .claude/hooks/**, OR only check-autoflow-gate.sh…` | **dropped — cycle-local, with recorded coverage loss** | Carried half: an edit to either file the AC5 parity block of `tests/plugin/verify-package.sh` compares (`hooks/check-autoflow-gate.sh`, `hooks/check-read-dedup.sh`) is caught there by byte equality, which is stricter than the deleted arms' admission test. Its execution home is `.github/workflows/plugin-package.yml`, which triggers on `pull_request` and `push: main` **under a `paths:` filter** that includes `.claude/hooks/**` — path-conditional, and reached on exactly the edits it covers; no unconditionality is claimed. **Recorded residue**: a cycle that adds a **third** file under `.claude/hooks/` fails the deleted arms and is outside AC5, which compares a fixed pair of basenames plus the agents directory. A cycle that edits a `.claude/hooks/**` file other than `check-autoflow-gate.sh` while updating its plugin mirror in the same diff is likewise admitted by the carrier and was rejected by the arms. The whole-tree STATE form of that residue would be "`.claude/hooks/` contains exactly this set" — a hand-maintained inventory, the shape §1-2 retires by construction — so it is not promoted |
| 798 `AC9: diff touches no .claude/workflows/** path, OR every touched .claude/workflows/** path has a setup/manifest.json sha256 row matching its current content…` · 799 `AC6-scope: diff touches no .claude/workflows/** path, OR every touched…` | **dropped — cycle-local, with recorded coverage loss** | Carried half (content drift): `scripts/test/check-manifest-regen-clean.sh`'s FIXED POINT leg fails on any *registered* source whose content changed while its recorded hash did not — a whole-tree STATE predicate over the registered set, and itself the §3 promotion of the retired `955 AC4-CLOSURE` DELTA. It runs unconditionally as its own step. **Recorded residue, first part (missing row)**: the arms also failed an **unregistered** workflow path — an absent `artifacts[]` row yields an empty hash and breaks their equality. FIXED POINT cannot see that case, because `setup/gen-manifest-hashes.sh` emits workflow rows from a fixed pair of `emit_row` calls, so a newly added `.claude/workflows/*.js` is in neither the committed nor the regenerated manifest and the fixed point holds. That regen lint's own header records the generalisation as deliberately refused for `.claude/workflows/**` (it would need an exclusion list, reintroducing the retired shape) and routes the general root-layer registration gap to *retired as not machine-checkable*, §5; this row inherits that decision rather than contradicting it. **Recorded residue, second part (the shape guard)**: `tests/test-issue-62-sequential-rounds.sh`'s `AC-62-36` was a differential owner of the same invariant, asserting the *shape* of the arm rather than its content. It retires with its subject in the row below, so after this cycle no executable asserts the manifest-pin shape — only FIXED POINT's content predicate remains |
| 62 `AC-62-36` (i)/(iii)/(iv) — the arm-shape structural check and its two worktree-driven negative controls | dropped — subject retired (§5's label, applied to a consumer's arms) | its subject is the `.claude/workflows/**` arm the row above deletes from both files. (i) drives `extract_arm_window()`, an awk opening on a `workflows_(admitted\|touched\|offwindow)_ac<N>` assignment and closing on the arm's own `assert_true`; both anchors sat inside the deleted region, so the window returns empty. (iii)/(iv) ran the real converted guard at `HEAD` in a detached worktree and required `FAIL:` on its `.claude/workflows` arm; with the arm gone it cannot. Repointing needs another file carrying the same arm shape and this cycle deletes both instances of it, so no subject remains; keeping the arms alive to preserve a guard over their shape inverts the issue. Symbol closure: `extract_arm_window()`, `check_arm_structural()` and the mutators `stale_workflow_manifest_row` / `delete_workflow_and_manifest_row` go with the arms. **`guard_result_at_ref_mutated()` is retained** against the orphan direction — `tests/test-cycle-arm-residue.sh` asserts its retention by name against §12.1's kept row, so it is a symbol another file requires rather than an orphan; §12.1's row is re-anchored to its post-change line range in this same commit. **This row supersedes, by name, §12.1's two dispositions `AC-62-36(iv)` (*ungated — permanent property, gate was the defect*) and `AC-62-36(iii)` (*ungated — premise made hermetic, gate was supplying it*)**: both state a permanent property over an executable that no longer exists, and a §16 row that merely sits beside them leaves the registry asserting a permanence it no longer has. §12's separate prose citation of "issue #107's AC-62-36(iii)" is **not** amended — it records what #107 decided, which stays true after the subject is retired |
| 952 `AC5: manifest.json is itself in the diff (regen ran, #949 [MUST])…` · 955 `AC4-DOGFOOD: diff-∩-sources non-empty ⇒ setup/manifest.json is itself in the diff` | **dropped — redundant** | the manifest FIXED POINT leg of `scripts/test/check-manifest-regen-clean.sh` is the same-commit-regen obligation in whole-tree state form and needs no diff. Both arms are registered-source-only by construction, so FIXED POINT's coverage is a superset. Driven as a fault rather than assumed: a registered source edited without regeneration reds FIXED POINT. Symbol closure: 952's `MANIFEST_JSON`, 955's `skip_no_base()` and `CYCLE_DIFF_FILES` |
| 798 `AC7b: no diff hunk against ADR-0015 (immutable historical record)` | **dropped — redundant** | manifest FIXED POINT (ADR-0015 is a registered source, confirmed in `setup/manifest.json`) plus the permanent registry entry `798-AC7a-adr0015-sentence` |
| 955 `AC-PRESERVE-deletion-audit: no contiguous run >15 deleted lines across the five edited docs` | **dropped — cycle-local** | a bounded-deletion-run heuristic over one cycle's own edit surface. Nothing at HEAD is the invariant and the predicate is unstatable without two trees, so §3's rewrite exit is closed. The content it stood in for is carried positively by `AC-PRESERVE-a/b/d` in the same file, which are STATE predicates and stay |
| 798 `AC6b: no diff hunk touches a '*Secondary (multi-repo)' marker line` · 799 `AC3-guard: no diff hunk over docs/ README.md touches a 'Secondary (multi-repo)' marker line` | promoted → registry entries `121-secondary-marker-*`, then deleted (§3's rewrite exit) | **Granularity: one entry per marker LINE**, not per file — the marker occurs on several lines within single files, and a file-scoped `present` entry still passes after one of them is deleted, which is exactly the loss the DELTA caught. Thirteen entries cover the two arms' scope (`docs/`, `CLAUDE.md`, `README.md`): four in `CLAUDE.md`, three in `docs/autoflow-guide.md`, two each in `docs/repo-boundary-rules.md` and `docs/teammate-contracts.md`, one each in `docs/git-workflow.md` and `docs/external-review-sequencing.md`. Each is `predicate: "present"`, `match: "fixed"`, `scope: "permanent"`, `origin_issue: 121`, file-scoped with **no `section`** — the shape that routes the runner's witness to `mutate_remove_lines` and is credited teeth. The marker lines in `agents/autoflow-implementer.md` (host and plugin copies) were in neither arm's scope and are correctly not promoted, as is `docs/autoflow-guide.md`'s `*Secondary (multi-repo), review-response mode*:` line, which the arms' grep excluded. **Literal rule — discriminating clause, not the full line**: the marker prefix plus the shortest clause distinguishing that line from the other marker lines in its own file, with volatile identifier tokens (org/repo pairs, issue numbers, link targets) excluded. Full-line keying is refused on evidence inside the deleted arm itself: 799's `AC3-guard` carried `grep -vF` filters whose only purpose was to admit an identifier-only rewrite of `docs/git-workflow.md`'s marker line, so a permanent full-line entry would red on exactly that legitimate edit and the remedy would be to edit the entry — the hand-maintained widening §1-2 retires. **Recorded residue**, two parts, both deliberate **narrowings** of the DELTA: a marker line added *after* the promotion is governed by the DELTA form and is not governed by the STATE form; and an edit confined to the unpinned remainder of a governed line is admitted by the STATE form where the DELTA form caught it |
| 799 `AC3-nores: no NEW doc line (changed surface) points at <sub-repo path> as a live tracked path` — the arm's own path token is elided here, since `tests/fixtures/e2e-bundle-purity-baseline.txt` forbids it in a bundled doc; the verbatim spelling is the one `tests/fixtures/host-purity-tokens.txt` lists | **dropped — cycle-local** | no admissible STATE form exists, re-derived three ways: an entry's `file` is a single path, so a tree-wide `docs/` scope is not expressible in one entry; the literal occurs many times at HEAD under `docs/` as live sub-repo prose, which the arm tolerated only because it was scoped to new `+` lines, so an `absent` + `fixed` entry on it reds at HEAD; and the qualified form needs `match: "regex"`, which the runner's self-test rejects by name as having no injectable witness. The arm's own comment already recorded it as changed-surface-only and deliberately non-recursive — §3's "dropped when it was only ever cycle-local" exit. **No registry entry is owed or added** |
| 27 `AC-27-9-diff: VERIFY step-4 block content byte-identical between $BASE_REF and HEAD…` | promoted → registry entries `121-verify-step4-l1`…`l8`, then deleted (§3's rewrite exit) | the guarded region is `docs/autoflow-guide.md`'s VERIFY step-4 block (the `extract_step4_block` region, opening at `4. Mock-boundary fidelity check (Test AI):`). Its sibling `AC-27-9-literal` greps only the block's opening literal, so it is not the equivalent predicate and stays. **One entry per LINE of the block**, not per sentence: the block's one prose sentence wraps across consecutive source lines, and a sentence-shaped literal would carry an embedded newline, which the runner's schema check refuses with a registry-wide `block` — under which the teeth obligation is unsatisfiable in that shape. Same entry shape and same discriminating-clause rule as the marker rows, with leading indentation and the box-drawing glyphs excluded; uniqueness in the file is the floor a clause must clear, not a licence to key long. One discriminator does separate this block from the marker lines and is recorded rather than spent on longer literals: the block sits inside a fenced code region, so its line breaks are literal content and no markdown formatter rewraps it. That bounds the fragility without removing the **narrowing**, so the clause rule applies here too. The existing `27-AC8-verify-step4-xref` entry is section-scoped to `Output artifacts` and pins the cross-reference occurrence of the header literal, not the block; it is left untouched. **Recorded residue**: the DELTA was one cycle's fence and the STATE form is permanent, so a later deliberate wording change to a governed line is remedied by a registry edit under §3's ordinary disposition procedure rather than silently. Symbol closure: 27's `extract_step4_block()` and `BASEREF_LIB` go with the arm; `count_heading()` stays, called by a surviving arm |

**Consumers of a deleted arm.** Three files execute against an arm this cycle deletes
and are edited with it rather than left red: `tests/test-issue-103-cycle-scope-repoint.sh`
and `tests/test-issue-103-suite-manifest.sh` (their real-tree loops over the
array-bearing standing triple reduce to the surviving subject, and the first file's
allow-list-bearing suite count tripwire re-anchors from 3 to **2** — this cycle's own
cycle-scoped suite plus `tests/test-issue-71-digest-removal.sh`), and
`tests/test-push-context-base-ref.sh`, whose two pins on
`tests/test-issue-27-composition-oracle.sh` are **repointed to
`tests/plugin/verify-package.sh`**. That pin has now decayed twice for the same reason,
which fixes the selection rule recorded in its own comment: **pin a subject whose
base-ref call cannot leave with a cycle** — `lane: standing`, no `cycle-arm`, and a
base-ref call dominated by no branch gate. The recorded alternate is
`tests/test-issue-788-host-purity-delta.sh`, which satisfies the same three checks and
is a member of the derived set; that file keeps its own declaration and is otherwise
unmodified, since a diff-scoped scanner is the essential case the field exists for.

**Header id inventories.** Each converted suite's leading comment block and its
`echo "=== <id> …"` banners are edited on **two independent axes** — the arm's id and
the banner's id, which are not the same id. In `tests/test-issue-799-inert-cleanup.sh`
they diverge: the emptied arms sit under banners named `AC8` and `AC10`, ids no deleted
arm carries. `tests/test-issue-109-doc-assertions.sh` follows on both axes; the arm ids
leave its live-id array for a new single-consumer `RETIRED_121_799_IDS` array rather
than `STALE_799_IDS`, which a second assertion re-uses as the witness set for §13.2's
issue-#116 narrowing claim and which would make that provenance false.

**Trigger-surface re-derivation.** `# ci-subject:` token lists are re-derived against
what each file still reads. `tests/lib/base-ref.sh` leaves suites 67, 69 and 27, whose
every executable read of it sat inside a deleted region.

**CI registration.** `tests/test-issue-121-declaration-release.sh` (`lane: cycle-scoped`,
`retire-with: #121`) is registered in `.github/workflows/contract-suites.yml` with its
own guarded, budgeted step and full `paths:` coverage for its subject set. It retires at
the merge its `retire-with` names, per §2.
