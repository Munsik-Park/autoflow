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

A guard that is *dropped — cycle-local* is proven non-occurring by the
state-only property (no registry entry reads a diff). A guard that is
*promoted* gets a positive registry entry. Nothing in the retired column is a
bare deletion.

The wider allow-list/base-ref family (798/799/843/844/846/952/953/955/964)
migrates incrementally under this same lifecycle rule; the registry is the
enabling mechanism they reuse.
