# Issue #800 — Manual/Environment-Dependent Verification Scenarios (Tier-2/Tier-3)

These acceptance criteria are **not** covered by
`tests/test-issue-800-doc-assertions.sh` — they are semantic judgments a grep
cannot make, or they depend on live GitHub state that is non-reproducible in
CI. Delegated per the verification design
(`.autoflow/issue-800-verification-design.md` §1/§2) and the feature design's
Outcome-X deliverable boundary (`.autoflow/issue-800-feature-design.md` §9):
**AC3 (live re-attribution) and AC4(ii) (live PR body edits) do not run this
cycle** — no live GitHub mutation is fired. Only their post-check oracles are
recorded here for when the operator later fires the handed-off migration.

---

## AC1 — tracker-readiness precondition (Tier 3)

**Why not automated:** depends on live GitHub repo settings (`gh api`),
non-deterministic across CI re-runs (network + auth), and D4 already settled
this as a one-time confirmation, not a recurring gate.

**Steps:**

```bash
gh api repos/{{REPO_SERVICE_HOST}} --jq .has_issues
```

**Pass condition:** output is `true`. If `false`, the tracker destination
requires a repo-setting change first — stop and report to the user before
proceeding with AC2/AC3.

**Evidence recording:** record the 1-line result (command + output) in the
decision ledger (`.autoflow/issue-800-ledger.md`) and in the PR body.

---

## AC2-CLASSIFY — semantic §1.3 coupling judgment (Tier 2)

**Why not automated:** whether an issue's subject is "the LibreChat service
product" vs "AutoFlow-the-tool" is a judgment call over free-text titles and
labels (feature design §1.3 / D-C), not a fixed-string match.

**Steps:**

1. Open `.autoflow/issue-800-classification.md` (the classification
   manifest, built from a frozen `gh issue list --state open` snapshot).
2. For each row, confirm the `class` (`framework` | `service`) matches D-C's
   criterion: `service-reattribute` iff the subject lands in
   `LibreChat`/`llmroute`/`librechat-deploy` (billing, credit, deploy, seed,
   multitenant, console, multichat, UX, or a `librechat` label / service
   epic); `framework-keep` iff the subject is AutoFlow-the-tool (gates,
   schema, hooks, HANDOFF, templates, phase playbooks, evaluation,
   distribution/plugin).
3. Spot-check the representative cases the verification design names:
   #946/#944 (LibreChat bugs), #567 (3-tier console), #611 (multitenant) →
   expect `service`; gate/schema/HANDOFF/template issues → expect
   `framework`.
4. Confirm epic-hub coherence (D-B): an epic hub and its `epic-<N>`
   sub-issues are never split across `framework`/`service` — classify by the
   epic's subject as a unit.
5. Confirm ambiguous rows are flagged conservatively (`action=flag`, kept
   host-resident) rather than silently moved.

**Pass condition:** every row's class is defensible against D-C/D-B; no
service-coupled issue is left `framework-keep` and no framework issue is
misrouted to `service`; no epic hub is split from its sub-issues.

---

## AC2-MANIFEST — classification-manifest completeness (Tier 3)

**Why not automated / not CI:** the manifest
(`.autoflow/issue-800-classification.md`) is `.autoflow/` scratch
(gitignored, per R6/§9-Q2) and therefore invisible to a CI repo-tree
checkout. The completeness check is deterministic **against the embedded
snapshot only** (never a live re-query, to avoid moving-target flakiness),
but because the artifact isn't committed, the assertion cannot run as a
Tier-1 CI gate.

**Steps:**

```bash
# Row-count of the manifest's classification table
grep -c '^| #' .autoflow/issue-800-classification.md

# Row-count of the embedded frozen `gh issue list` snapshot in the same file
# (compare against the snapshot block header's count, or re-count the
# embedded JSON/table rows — NOT a live gh re-query)
```

**Pass condition:** manifest row-count == embedded-snapshot row-count (every
open issue in the frozen snapshot appears exactly once in the classification
table).

**Evidence recording:** record the row-count comparison (both numbers) as
1-line PR-body evidence at execution time.

---

## AC3 — live re-attribution post-check (Tier 3, Outcome-Y-only, NOT this cycle)

**Why not automated / not this cycle:** AC3 is a one-time, partly
irreversible live mutation (`gh issue create` + comment + close across two
repos). Under Outcome X (locked baseline this cycle) it does not execute —
#800 hands off a reviewed go/no-go migration manifest to the operator. This
scenario is recorded for **if and when** the operator later grants go
(Outcome Y) and fires the migration using
`.autoflow/issue-800-migration-map.md`.

**Steps (post-check, run only after the operator fires the live migration):**

For each row in the migration map (`原本#N → llmroute#M`):

1. **(a)** `gh issue view {{REPO_SERVICE_HOST}}#M` — confirm it exists and its
   labels/milestone match the row's mapped values.
2. **(b)** `gh issue view Munsik-Park/autoflow#N --json state` —
   confirm `state == CLOSED`.
3. **(c)** `gh issue view Munsik-Park/autoflow#N --json comments` —
   confirm a pointer comment referencing `llmroute#M` is present (history
   preserved, never a bare/silent close).

**Order invariant (R3, [MUST]):** confirm (a) is satisfiable **before** any
row is allowed to show (b) closed — a pointer-less orphan close (state
CLOSED with no matching pointer comment) is a hard failure, not a Tier-2
nuance.

**Pass condition:** every migration-map row satisfies (a) ∧ (b) ∧ (c), with
(a) having been confirmed before (b).

---

## AC4(ii) — live PR cross-reference transition (Tier 2/3, conditional)

**Why not automated:** requires enumerating live open PRs referencing the
re-attributed issues and reading their body text — environment-dependent,
not grep-able against a fixed repo tree.

**Steps:**

1. `gh pr list --repo Munsik-Park/autoflow --state open` at execution
   time.
2. If the set is empty (as observed this session — 0 open PRs): AC4(ii) is
   **vacuously satisfied** — record "no open PR references a re-attributed
   issue" as the evidence line. No further action.
3. If any PR references a re-attributed issue: confirm its body uses `Part
   of {{REPO_SERVICE_HOST}}#M` and does **not** retain an active `Closes
   #<original-N>` plaintext token (the #82 fenced-form precedent — an
   unfenced `Closes` in a PR body is a live close trigger, not just prose).

**Pass condition:** either the referencing-PR set is empty (vacuous pass,
recorded), or every referencing PR's body has been transitioned to the
Target model with no active `Closes` token.

---

## AC5 — routing-rule semantic coherence (Tier 2)

**Why not automated:** `tests/test-issue-800-doc-assertions.sh` (AC5-ROUTE /
AC5-NOTE-FLIP) only proves the routing tokens and the flipped transition-note
phrase exist — it cannot judge whether the newly-written prose is
*consistent* with the surrounding document, only that the tokens are
present.

**Steps:**

1. Read the new routing-rule bullet in `CLAUDE.md` > Issue Management
   alongside the existing `ai:<agent>` / `Forks do not host issues` bullets —
   confirm no contradiction (e.g. the new bullet doesn't imply forks now
   host issues).
2. Read the updated Backlog section and transition note in
   `docs/repo-boundary-rules.md` alongside the surviving `*Secondary
   (multi-repo):*` framing — confirm the rewritten principle doesn't
   contradict the host-only default flow it sits next to.
3. Confirm the flipped transition note reads coherently as a past-tense
   "executed" statement, not a dangling half-edit that mixes old and new
   tense.

**Pass condition:** the routing rule is not merely token-present but reads as
one coherent, non-contradictory principle in both documents.

---

## Tier-3 evidence-recording checklist (for the PR body)

At execution time, the PR body should record, as 1-line evidence each:

- AC1 result (`has_issues` boolean).
- AC2-MANIFEST row-count comparison (manifest rows vs embedded snapshot
  rows).
- AC4(ii) referencing-PR-set cardinality (0 this session, or the transitioned
  set).
- (Outcome-Y-only, if fired) AC3 migration-map row outcomes.
