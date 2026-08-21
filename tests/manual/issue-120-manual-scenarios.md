# Issue #120 — Manual/Environment-Dependent Verification Scenarios

Per the verification design (`.autoflow/issue-120-verification-design.md` >
*Testability assessment*), two acceptance criteria have no automatable oracle
and are delegated to manual review. Neither sits at a triggered composition
contact point (F11 — every shared-state identifier in the *Composition
oracle* intersection carries a non-mock oracle; these two items are not
members of that intersection), so the manual fallback is available to both.

---

## M1 — The arm-representability filter verdict

**Situation.** For every assertion arm this cycle touches, the feature
design (`.autoflow/issue-120-feature-design.md` §1–§2) classifies it into one
of five dispositions — `migrated`, `retired against a carrier`,
`dropped — cycle-local`, `dropped — coverage loss, recorded`, or
`retained in place` — and, for the two full-file deletions
(`tests/adr-0016-conformance-check.sh`, `tests/test-issue-42-spawn-mode-contract.sh`),
whether the whole file is expressible enough to delete.

**What a machine can check (already covered, automated):** that a migrated
arm became a credited registry entry (`tests/run-doc-invariants.sh`,
`--self-test`); that a `retired against a carrier` row cites a real carrier;
that a `dropped` row claims no carrier
(`tests/test-cycle-arm-residue.sh` > *120 provenance-class*); that a suite is
deleted only once every one of its own arms holds a non-`retained in place`
disposition (the file-level leg of
`tests/test-issue-120-arm-reconciliation.sh`).

**What no machine can check.** Whether the *chosen* disposition for a given
arm is the *right* one is an editorial judgment over the arm's shape and the
document it protects, not a mechanical fact:

- Is the adr-0016 suite's `AC3-guard-a/b/c` absence guard genuinely
  inexpressible as `absent-enumeration` (its forbidden language is an
  unbounded-prose case-insensitive alternation), or could a differently-scoped
  registry entry have captured the same guard? (feature design §2, "The one
  trade in this row.")
- Is `76-RETAIN-REGION-INEXPRESSIBLE` the correct label for
  `tests/test-issue-846-doc-assertions.sh`'s step-6.5 arms, given the
  registry's `section_end` resolves file-wide rather than locally?
- Does the recorded coverage loss for each `dropped` row actually leave the
  guarded property unprotected, or does an independent positive entry
  already state the corrected reading directly (§1, "A rewritten positive is
  not a migration of an absence")?

**Reviewer action.** At GATE:PLAN and at code review, read each provenance
row in `docs/doc-invariant-registry.md`'s #120 section against the arm it
replaces (or the reason it does not migrate) and confirm the disposition
label matches the arm's actual shape under §1's expressibility rules. Pay
particular attention to the one flagged trade: dropping `AC3-guard-a/b/c` as
recorded coverage loss to buy the `adr-0016-conformance-check.sh` deletion
(feature design §2). **If that review rejects the trade**, the row flips to
`retain — partial` — the file survives, and §3 (keystone joint retirement)
and the adr-0016 half of §4 (inbound pins) do not execute this cycle; this
suite's `120 arm-removed` / `120 keystone-remnant-gone` / `120 firewall-pin-gone`
arms in `tests/test-cycle-arm-residue.sh` would then need re-scoping to match
the flipped disposition, since they currently assert the deletion outcome.

---

## M2 — This cycle's own suite retires at its merge

**Situation.**
`tests/test-issue-120-arm-reconciliation.sh` carries
`# lane: cycle-scoped` and `# retire-with: #120`. Per
`docs/doc-invariant-registry.md` §2 (the retirement condition), a
cycle-scoped suite is deleted at the merge of the issue it names — but
AutoFlow's own authority ends at HANDOFF (an open PR), and merging is
external (`CLAUDE.md` > Development Lifecycle). No automated check inside
this repository's CI can assert "this suite no longer exists" before that
merge happens, because before the merge it is *supposed* to still exist.

**Reviewer/operator action.** At the point issue #120's PR merges (outside
AutoFlow's own authority), whoever performs or reviews the merge confirms
`tests/test-issue-120-arm-reconciliation.sh` is deleted in the same change
(or a prompt follow-up), per the provenance section's reservation row for
its own retirement. This is a provenance row read at merge time, not a
CI-enforced gate — recorded here rather than asserted as green, since
AutoFlow holds no merge authority to execute it.
