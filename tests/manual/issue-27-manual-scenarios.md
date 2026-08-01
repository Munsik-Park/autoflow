# Issue #27 — Manual/Environment-Dependent Verification Scenarios (Tier-2/Tier-3)

These acceptance criteria are **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `27-AC*`) or by `tests/test-issue-27-composition-oracle.sh` — they
are semantic judgments a grep cannot make, or they depend on a live AutoFlow cycle
that is not reproducible in CI. Delegated per the verification design
(`.autoflow/issue-27-verification-design.md` §4, §6): this cycle is a
documentation/methodology cycle with a two-string executable tail (Phase 3: Type 1,
docs-as-code lever) — the change surface is `docs/autoflow-guide.md`,
`docs/teammate-contracts.md`, `.claude/workflows/architect-deliberation.js`, and
`setup/manifest.json`.

**Coverage boundary, stated plainly.** Automated coverage for #27 is *documentary*:
it proves the composition-oracle rule is written, positioned, mechanically phrased,
environment-neutral, mirrored in the role contract, wired into the executing prompt,
and internally consistent with the checks it must not replace and the bullets it must
narrow. It does **not** and **cannot** prove that a future ARCHITECT run obeys it. The
behavioral claim — that the clause actually causes a non-mock oracle to be assigned at
a real contact point, and does not misfire on unrelated changes — rests entirely on
M1/M2/M3 below.

---

## M1 — Replay of llmroute #218 c3 against the amended rule (Tier 3, environment-dependent)

**Source AC:** AC-27-15 — behavioral: in a live cycle whose change surface overlaps a
ledger/ADR-referenced shared-state identifier, the produced Verification Design
Document actually assigns ≥ 1 non-mock oracle at that contact point.

**Why not automated:** requires a live ARCHITECT run against a foreign repository's
decision ledger; no CI-reproducible fixture exists — the artifact under change is
instruction text consumed by a model at runtime, not a mechanically checkable
predicate.

**Steps:**

1. Take as the input case the historical situation that motivated this issue: the
   llmroute #218 c3 change surface (tenant-scoping of `verifyEmail`) and the settled
   decision it collided with (#755 — non-invited user, unstamped).
2. Apply the amended rule's trigger by hand — enumerate the change-scope identifiers
   named by the design and the shared-state identifiers the settled decision (#755)
   references.
3. Confirm the intersection is non-empty (the `verifyEmail` query path over the
   unstamped-user document set is named by both).
4. Confirm the rule then compels ≥ 1 oracle exercising the real query path — i.e. the
   very spec that only appeared in c4, promoted to a c3 obligation.

**Pass condition:** the trigger fires by hand-application of the amended rule text,
and the compelled oracle is the c4 integration spec's role, now required a cycle
earlier.

**Explicitly out of scope for this scenario:** whether a model in a live cycle *in
fact* applies the rule this way. That is an observation about model behavior, not
about the spec, and this cycle does not claim it.

---

## M2 — Trigger decidability + environment neutrality (Tier 2)

**Source AC:** AC-27-16 — decidability: two independent readers, given the same
change surface + settled-decision set, reach the same trigger verdict. Also covers
the semantic (non-token) half of AC-27-6/7 (environment neutrality) and AC-27-23's
checkability (coverage by a single oracle spanning several elements).

**Why not automated:** agreement between two independent readings of natural-language
criteria is not a grep predicate; "does not *depend* on a stack" is a semantic
judgment beyond token placement.

**Steps:**

Present five fixed cases to two independent evaluations, each reading **only** the
amended `docs/autoflow-guide.md` > ARCHITECT > *Composition oracle* text (no other
context):

1. **(i) server** — a change to a datastore collection/field that a prior ADR's
   Decision scope contracts.
2. **(ii) embedded** — a change to a firmware configuration register that a prior
   decision (ledger entry) pinned.
3. **(iii) pure-function refactor** — a change with no shared-state identifier at all.
4. **(iv) untracked shared state** — a change touching shared state that **no**
   settled decision references.
5. **(v) coverage-by-one-oracle** — a change intersecting **two** shared-state
   identifiers, discharged by a single oracle whose trace names both (AC-27-23).

**Pass condition:**

- Identical verdicts across both readers on all 5/5 cases: (i), (ii), (v) fire;
  (iii), (iv) do not.
- Neither reader needed a stack-specific assumption (a named datastore product, a
  named hardware platform) to decide (i) or (ii) — confirms the semantic half of
  environment neutrality (AC-27-6/7) beyond the automated token-count check.
- Both readers independently accept (v)'s single oracle as sufficient because each
  intersecting element is traced by it — confirms AC-27-23's checkability.

---

## M3 — Over-fire fence (Tier 2)

**Source AC:** AC-27-17 — false-trigger fence: a change with no identifier overlap
does not acquire a mandatory non-mock oracle; the rule does not inflate every cycle
into an integration-test cycle.

**Why not automated:** a negative behavioral claim — "the rule does not over-fire" —
cannot be exercised by a static check against text that has no live change surface to
evaluate.

**Steps:**

1. Reuse M2's non-firing cases — (iii) pure-function refactor, (iv) untracked shared
   state.
2. For each, confirm the rule's required output (per the amended text) is the
   explicit negative declaration (AC-27-12 — the "no intersection" statement), and
   **not** an assigned oracle.
3. Confirm the effort the amended text implies for these two cases is a one-line
   determination, not a request to build an integration-test environment.

**Pass condition:** both non-firing cases terminate at a negative declaration with no
oracle-assignment obligation, and the text does not read as requiring more than a
one-line statement for either.

---

## Note on this cycle's own compliance

This cycle's own dogfooding determination (verification design §0.5) already applies
the composition-oracle rule to its own change surface — `T ∩ S` is three elements
(doc-invariant registry entry set, manifest `artifacts[]` sha256 set, the
`architect-deliberation.js` prompt strings), each discharged by a real-execution
oracle (AC-27-22, AC-27-21, AC-27-20 respectively, in
`tests/test-issue-27-composition-oracle.sh`). None of M1/M2/M3 above is itself a
composition contact point for this cycle, so the manual delegation here is not the
fallback the rule itself forbids for a triggered contact point (feature design
§2.3(3)).
