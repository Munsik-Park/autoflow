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
resolvable `BASE_REF`, and inspect the output of the 7 AC-59-21 / AC-59-11d
lanes (issue #75 retired the yml-window delta family with its lane).

**Pass:** each AC-59-21 precondition lane FAILs with its `base measurement of
<suite> at <ref>` label showing a `-1` triple, its paired delta lane FAILs
alongside, and the suite exits non-zero. No literal token is pinned beyond the
label's suite name and the `-1` fields.

**Fail:** any AC-59-21 precondition lane prints a `PASS` label despite the
host-level failure, its paired delta lane does not also FAIL, or the suite
exits zero.

---

## M5 — Genuine host-level failure under a read-only TMPDIR (Tier 3, environment-dependent, cycle 3)

**Retirement note (issue #103):** `tests/issue-59-full-sweep-driver.sh` is
deleted (feature design §2.3 — superseded by `scripts/test/run-suites.sh
--all`, which unlike the driver has a real CI execution path). The driver's
own worktree-creation mechanism (`mktemp -d
"${TMPDIR:-/tmp}/autoflow-sweep-wt.XXXXXX"`, the subject of the original
`AC-59-34` INCONCLUSIVE classification below) does not exist in the new
runner — `scripts/test/run-suites.sh` creates no worktree at all
(`.autoflow/issue-103-budget-green-blocker.md` §4, "sandbox containment
structurally, since the runner creates no worktree at all"), so a read-only
`TMPDIR` cannot fail *it* the way it failed the driver. The scenario is
re-pointed below to what the new runner *does* do under the same host
condition — every suite that itself calls `mktemp` under the process
environment's `TMPDIR` fails individually — rather than left claiming an
`INCONCLUSIVE` classification no live mechanism produces.

**Source AC:** AC-59-34 (historical) — a *genuine* host-level worktree
failure (read-only `TMPDIR`, disk full, stale worktree lock) driving the
now-deleted driver as a real program produced a per-suite `INCONCLUSIVE`
line and a non-zero exit, never `ALREADY RED`, never `PASS`. Superseded by
the retirement note above; recorded for provenance, not as a live pass
condition.

**Setup:** Point `TMPDIR` at a read-only directory before invoking the
runner, so any suite that itself calls `mktemp` under that environment
cannot write:

```
TMPDIR=/path/to/a/read-only/dir bash scripts/test/run-suites.sh --all
```

**Procedure:** Run the runner as above on the `dev/*-issue-59*` branch (or
any branch), and inspect the per-suite `PASS`/`FAIL`/`TIMEOUT` lines and the
run-level exit code.

**Pass:** every suite that calls `mktemp` internally reports `FAIL <suite>
<elapsed>s (exit <status>)` — a non-zero exit attributable to its own
`mktemp` failure, not a silent `PASS`; the run-level summary line reports a
non-zero failed count and `run-suites` exits non-zero. There is no
`INCONCLUSIVE` classification in the new runner — a host-level failure and a
genuine assertion failure both surface as `FAIL`, distinguishable only by
reading the suite's own output, which is why this scenario stays manual
rather than becoming a gate.

<!-- The paragraph below is retained verbatim for provenance; it describes
     the deleted driver's behaviour and is not the pass condition above. -->

**Historical pass condition (driver, retired):** each suite whose base
cannot be measured prints the per-suite
`INCONCLUSIVE:` line naming that suite, no line reads `ALREADY RED`, the
summary reports a non-zero inconclusive count, and the driver exits non-zero.
No literal is pinned beyond the suite name and the words `INCONCLUSIVE` /
`ALREADY RED`. (Historical — the driver that produced this vocabulary is
deleted; the live pass condition is the one stated above, under **Pass**.)

**Fail (live, new runner):** any suite affected by the read-only `TMPDIR`
reports `PASS` instead of `FAIL`, or `run-suites` exits `0` despite a
non-zero failed count.
