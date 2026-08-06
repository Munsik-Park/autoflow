# Issue #59 — Manual/Environment-Dependent Verification Scenarios

These acceptance criteria are **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `59-AC*`), `test/workflows/run.mjs`, or
`tests/test-issue-59-adoption-evidence-discipline.sh` — they depend on a live opus
sub-agent's response to prompt text, which is non-deterministic and has no
deterministic oracle. Delegated per the verification design
(`.autoflow/issue-59-verification-design.md` §1 *Manual / environment-dependent*,
§4 *Coverage boundary*): the automated lanes prove the **channel** — the adoption-
discipline text is constructed, hoisted once, delivered to all four prompts,
symmetric, and unconditional. They cannot prove the **outcome** — whether a live
sub-agent actually declines to adopt an unverified externally-arriving claim as a
design ground. AC-59-13's subject is that live behavior, which is in neither the
change surface `T` nor the settled-decision set `S` the verification design's §4
composition-oracle determination covers; its one contact point (E1,
`architect-deliberation.js`) already carries non-mock oracles (E1(a)/(b)), so a
manual scenario with a stated reason is acceptable here per
`docs/autoflow-guide.md` > ARCHITECT > Testability-driven design — the same
boundary #56 recorded for AC-56-13 (`tests/manual/issue-56-manual-scenarios.md`).

---

## M1 — Adoption-path citation probe (Tier 3, environment-dependent)

**Source AC:** AC-59-13 — behavioral: in a real ARCHITECT run, neither sub-agent
promotes an un-re-derived gate-verdict / ledger assertion into design ground or an
acceptance criterion.

**Setup:** Run a real `architect-deliberation` Workflow on an issue whose
`.autoflow/issue-{N}-*.md` input set contains a **gate FAIL rationale** carrying at
least one assertoric, un-derived claim (the #445 shape this issue traces to).

**Procedure:** Record, per Draft artifact and per round-1 verdict, whether any
claim traceable to that FAIL rationale text appears in `feature-design.md` or
`verification-design.md` as a stated design ground, and whether it carries a
re-derived `path:line` citation into the **current** source (not the FAIL text
itself).

**Pass:** every such claim is either (a) re-derived with a citation into current
source, or (b) explicitly left open per the constant's escape clause (A12 —
"treat the point as open") rather than built upon.

**Fail:** a claim from the FAIL rationale is carried into either document as a
settled ground with no re-derivation and no citation.

---

## M2 — Falsified-premise probe (Tier 3, environment-dependent)

**Source AC:** AC-59-13 (adoption direction — accepting, not just countering, an
externally-arriving claim; the #59 core, H2).

**Setup:** Seed the `.autoflow` input set with a decision-ledger entry asserting a
claim that is **false against the current working-tree source** (a stale count, a
retracted decision, or a superseded anchor).

**Procedure:** Run a real `architect-deliberation` Workflow over that input set and
observe whether either sub-agent's Draft or round-1 output treats the seeded claim
as settled fact.

**Pass:** at least one side flags the claim as un-re-derivable, or contradicts it
with a current `path:line` / section citation.

**Fail:** the false claim is carried into `feature-design.md` or
`verification-design.md` as a settled ground with no contradiction and no
re-derivation flag.

---

## M3 — This cycle is its own witness (worked example, not an oracle)

**Source AC:** none — this is evidence about the **rule's value**, not about the
**implementation**; no automated AC depends on it.

Round 7 of this very issue's ARCHITECT deliberation is a live, recorded instance of
the M1 scenario: a GATE:PLAN attempt-1 FAIL rationale reached the deliberation
(`.autoflow/issue-59-gate-plan-attempt1.md`), was treated as a re-verification
checklist rather than a fact under this issue's own adoption rule, and
re-derivation confirmed all four of the gate's findings **and** surfaced four
further defects the gate did not name (documented as G5–G8 in
`.autoflow/issue-59-verification-design.md` §0.2). Record this round-7 episode as
the worked example of the rule operating as intended: every load-bearing claim
that reached the deliberation from outside the current source was re-verified
against the live tree before being built upon, rather than adopted on the strength
of its phrasing or its authority (a gate evaluation).

---

## M4 — Genuine host-level worktree failure (Tier 3, environment-dependent, cycle 2)

**Source AC:** AC-59-24 — a *genuine* host-level worktree failure (disk full,
stale worktree lock, `mktemp -d` failure) also produces the loud FAIL, not just
the bogus-ref form. The automated suite's AC-59-20a/20c only exercise the
unresolvable-ref route through `suite_result_at_ref` (the same `:149` branch,
but reached via a git-level rejection, not a host-level one); a fake `git`
standing in for the real host failure was rejected (composition-oracle clause,
`.autoflow/issue-59-verification-design.md` §4) — the mechanism is identical,
only the *cause* differs, so this scenario is the boundary that closes it
manually rather than with a substitute.

**Setup:** Point `TMPDIR` at a read-only directory before invoking the suite, so
`suite_result_at_ref`'s `mktemp -d` (and the subsequent
`git worktree add`) cannot write:

```
TMPDIR=/path/to/a/read-only/dir bash tests/test-issue-59-adoption-evidence-discipline.sh
```

**Procedure:** Run the suite as above on the `dev/*-issue-59*` branch with a
resolvable `BASE_REF`, and inspect the output of the 12 AC-59-21 / AC-59-11d /
AC-59-12c lanes.

**Pass:** each AC-59-21 precondition lane FAILs with its `base measurement of
<suite> at <ref>` label showing a `-1` triple, its paired delta lane FAILs
alongside, and the suite exits non-zero. No literal token is pinned beyond the
label's suite name and the `-1` fields.

**Fail:** any AC-59-21 precondition lane prints a `PASS` label despite the
host-level failure, its paired delta lane does not also FAIL, or the suite
exits zero.

---

## M5 — Genuine host-level worktree failure against the full-sweep driver (Tier 3, environment-dependent, cycle 3)

**Source AC:** AC-59-34 — a *genuine* host-level worktree failure (read-only
`TMPDIR`, disk full, stale worktree lock) driving `tests/issue-59-full-sweep-driver.sh`
as a real program also produces the per-suite `INCONCLUSIVE` line and a non-zero
exit — never `ALREADY RED`, never `PASS`. This mirrors M4 above for the sibling
suite, applied to the driver: AC-59-25/26 already drive the *same branch*
through the real binary (an unresolvable ref), only the *cause* differs here,
and a fake `git` standing in for the real host failure is rejected for a
`T ∩ S` contact point for the same composition-oracle reason M4 cites
(`.autoflow/issue-59-verification-design.md` cycle-3 §1, DCR-C3-6, inheriting
DCR-C2-5).

**Setup:** Point `TMPDIR` at a read-only directory before invoking the driver,
so its `mktemp -d "${TMPDIR:-/tmp}/autoflow-sweep-wt.XXXXXX"` cannot write:

```
TMPDIR=/path/to/a/read-only/dir bash tests/issue-59-full-sweep-driver.sh
```

**Procedure:** Run the driver as above on the `dev/*-issue-59*` branch with a
resolvable `BASE_REF` (or the default resolution), and inspect the per-suite
lines and the run-level exit code.

**Pass:** each suite whose base cannot be measured prints the per-suite
`INCONCLUSIVE:` line naming that suite, no line reads `ALREADY RED`, the
summary reports a non-zero inconclusive count, and the driver exits non-zero.
No literal is pinned beyond the suite name and the words `INCONCLUSIVE` /
`ALREADY RED`.

**Fail:** any `ALREADY RED … base exit` line, any inconclusive suite counted
into `Clean/already-red`, or an exit of `0`.
