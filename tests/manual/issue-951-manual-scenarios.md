# Issue #951 — manual verification scenarios

Source: `.autoflow/issue-951-verification-design.md` §2/§3 (verification-type
summary, testability assessment). These items are explicitly **not**
shell-assertable — they require human/design judgement or a live CI
environment that cannot be reproduced hermetically. `tests/test-issue-951-registry.sh`
covers everything else.

## 1. AC1 — migration-map completeness (manual, design-adequacy judgement)

**Claim**: every *permanent* invariant of the five migrated suites
(794/796/797/800/949) has a corresponding registry entry — no permanent
assertion was silently dropped during hand-transcription.

**Why not automated**: the RED suite's coverage-floor check only asserts
"at least one entry per `origin_issue`," which catches a wholesale-missed
suite but not a partial miss within a suite (verification design §1: "a
human/Dev-AI confirms the map is *complete* — this is a judgement the runner
can't self-certify").

**Procedure**: at VALIDATE, diff each old suite's assertion list (captured in
`tests/fixtures/doc-invariants-baseline.txt`) against the registry entries
carrying that `origin_issue`; confirm every *permanent* (non-retired) source
assertion maps to exactly one registry entry, and every *retired* assertion
appears in the feature design §6 disposition table (dropped-cycle-local /
promoted / deferred).

## 2. AC2 — lifetime-rule adequacy (manual, design-adequacy judgement)

**Claim**: the retirement condition and promotion procedure in
`docs/doc-invariant-registry.md` are *sufficient* to prevent the class of
false positives this issue fixes, not merely present.

**Why not automated**: RED asserts the rule's *presence* (grep for
retirement/promotion keywords); its *adequacy* is a GATE:PLAN/human judgement
(verification design §3: "presence is grep-guardable, sufficiency is a
GATE:PLAN/human judgement").

**Procedure**: reviewer reads `docs/doc-invariant-registry.md` and confirms
both lanes are unambiguous and the retirement condition is actionable
("PR merges" is a concrete, checkable trigger, not vague language).

## 3. AC4 — live-CI base-ref resolution (environment-dependent, HANDOFF)

**Claim**: under a real `actions/checkout@v6` `pull_request` checkout,
`resolve_base_ref` (or a future adopting call-site) resolves the base ref
correctly — H3's originally-unverified sub-claim.

**Why not automated**: this cycle creates no live call-site for
`tests/lib/base-ref.sh` (ledger E10 — every base-dependent check this cycle
is either state-migrated or retired), and the actual GitHub Actions
`pull_request` checkout environment cannot be reproduced hermetically in a
local temp-repo test (verification design §DR-5, §3: "cannot be proven
locally... verified by the HANDOFF CI run itself").

**Procedure**: `tests/test-issue-951-registry.sh` proves the resolver's
override/`GITHUB_BASE_REF`/`origin/main`/local-`main`/unresolved-loud-FAIL
paths hermetically. This item has **no in-cycle CI-log subject** (E10) — it
activates only when a future cycle-scoped doc-invariant RED suite adopts
`resolve_base_ref` as a live base-dependent check. No HANDOFF action is
required this cycle; recorded here so the re-scope (verification design
§DR-5 "no subject this cycle") is not silently dropped from the record.

## 4. AC5 — "data-append, no CI edit" workflow (manual, doc review)

**Claim**: adding a new permanent invariant going forward is a pure
`tests/fixtures/doc-invariants.json` data append with zero
`.github/workflows/e2e-dummy-target.yml` edit.

**Why not automated**: `tests/test-issue-951-registry.sh` proves the runner
is data-driven (no per-invariant branch, no hardcoded heading text) as a
structural proxy, but the *end-to-end workflow claim* — "a reviewer appends
an entry and CI picks it up with no YAML diff" — is a process claim best
confirmed by a reviewer reading `docs/doc-invariant-registry.md` rule 4 (§5
"No accretion").

**Procedure**: reviewer confirms `docs/doc-invariant-registry.md` states the
data-append rule explicitly and that no companion CI-edit step is implied.
