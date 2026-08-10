<!--
SPDX-FileCopyrightText: 2026 Munsik-Park
SPDX-License-Identifier: Elastic-2.0
-->
# Issue #76 — migration map

The equivalence record for the two suites this cycle migrates and deletes
wholesale, `tests/test-issue-843-doc-assertions.sh` and
`tests/test-issue-844-doc-assertions.sh`. It is what makes "no bare deletion"
checkable rather than asserted: `tests/test-issue-76-migration-map-total.sh`
drives it in two legs — every extracted assertion occurrence has exactly one
row here (totality), and every carrier a row names resolves (discharge).

It lives under `tests/fixtures/` rather than `.autoflow/` because `.autoflow/`
is gitignored scratch, and an artifact a CI-registered suite reads has to be a
committed path (GATE:PLAN carried finding, cycle ledger E6).

**Row shape.** `| <suite path> | <verbatim first-argument key> | <occurrence
count> | <carrier groups> |`

**The row key is the assertion's first argument, verbatim** — the full
description string of the `assert_true` / `assert_false` invocation, byte for
byte, including its leading `AC*` token and any parenthetical. Short forms such
as `AC2-g` are prose references here and in review discussion; they are never a
row key. A description carrying an interpolated variable is keyed on the
un-expanded source text, so a loop-bodied invocation is one static member
however many times it runs.

**A row key admits multiplicity.** A description is not unique by construction,
so a row carries an occurrence count and one carrier GROUP per occurrence,
groups separated by `;`. Both arms of an `if`/`else` pair are occurrences in
full standing — discharging such a row against the `if` arm alone would drop
the `else` arm's signal while the row read as discharged, which is the bare
deletion this artifact exists to prevent wearing a satisfied row as cover.

**The unit of discharge is the conjunct**, not the assertion. A registry entry
holds one `file`, one `section`, one `predicate` and one `literal`, while a
source assertion whose predicate is a `&&`/`||` chain guards several conditions
at once. Each group is therefore a comma-separated list with one carrier per
conjunct, and the row is discharged only when every member resolves. Three
carrier kinds are admissible and no fourth:

- `registry:<id>` — an entry id in `tests/fixtures/doc-invariants.json`;
- `disposition:<label>` — a disposition row in `docs/doc-invariant-registry.md`
  §6 naming that conjunct's guard;
- `load-time anchor gate` — reserved for a non-emptiness conjunct over an
  anchored region (`[ -n "$VAR" ]`), which Step 0b's exactly-one-match
  resolution subsumes: a `"line"`/`"block"` entry whose anchor resolves to zero
  lines blocks the whole run, so the emptiness the source conjunct guarded
  against cannot occur unnoticed. It is a real carrier and is named, never
  dropped as uninteresting.

A conjunction spanning two anchored regions decomposes into one entry per
region and is never recorded against either alone. `844`'s `AC2-g` is the live
instance: it asserts that neither the `**Resume procedure**` block nor the
`**Review-response mode setup**` region contains the other's lead line, so the
row carries two `absent` entries — one anchored at each region, each with the
other's lead as its literal — plus the `load-time anchor gate` carrier for its
two non-emptiness conjuncts.

| Source suite | Assertion key (verbatim first argument) | Occurrences | Carriers (one group per occurrence; one carrier per conjunct) |
|---|---|---|---|
| tests/test-issue-843-doc-assertions.sh | A3-REMOVE: analysis.md no longer claims the hook computes pass/fail from the structure-gate scores | 1 | registry:843-A3-REMOVE-hook-computes |
| tests/test-issue-843-doc-assertions.sh | A3-STATE: analysis.md states the hook does not gate gate_hypothesis_structure | 1 | registry:843-A3-STATE-does-not-gate, registry:843-A3-STATE-key |
| tests/test-issue-843-doc-assertions.sh | A3-STATE-orchestrator: analysis.md attributes structure pass/fail judgment to the orchestrator | 1 | registry:843-A3-STATE-orchestrator |
| tests/test-issue-843-doc-assertions.sh | A3-EVALSYS: evaluation-system.md flags gate_hypothesis_structure as recorded-but-not-gated | 1 | registry:843-A3-EVALSYS-not-gated, registry:843-A3-EVALSYS-key |
| tests/test-issue-843-doc-assertions.sh | A3-CONSISTENCY-a: gate_hypothesis_structure absent from gate-schema.json:gated_phase_keys (already correct) | 1 | disposition:A3-CONSISTENCY-a |
| tests/test-issue-843-doc-assertions.sh | A3-CONSISTENCY-b: security-checklist.md:33 documents gate_hypothesis_structure as a non-gated phase (already correct) | 1 | registry:843-A3-CONSISTENCY-b-key, registry:843-A3-CONSISTENCY-b-nongated |
| tests/test-issue-843-doc-assertions.sh | A3-CONSISTENCY-c: no doc surface reintroduces gate_hypothesis_structure as hook-gated | 1 | disposition:A3-CONSISTENCY-c |
| tests/test-issue-843-doc-assertions.sh | A3-PROCEDURE-a: analysis.md documents the 'gh issue close' auto-close step explicitly | 1 | registry:843-A3-PROCEDURE-a-close |
| tests/test-issue-843-doc-assertions.sh | A3-PROCEDURE-b: analysis.md documents a pre-close confirmation that scores meet the FAIL condition | 1 | registry:843-A3-PROCEDURE-b-preclose |
| tests/test-issue-843-doc-assertions.sh | AC-CI-a: e2e-dummy-target.yml references test-issue-843-doc-assertions.sh | 1 | disposition:AC-CI-a |
| tests/test-issue-843-doc-assertions.sh | AC-CI-b: reference appears in a 'paths:' trigger block | 1 | disposition:AC-CI-b |
| tests/test-issue-843-doc-assertions.sh | AC-CI-c: reference appears in a 'run:' step | 1 | disposition:AC-CI-c |
| tests/test-issue-843-doc-assertions.sh | AC-CI-a: $CI_WORKFLOW exists | 1 | disposition:AC-CI-a |
| tests/test-issue-844-doc-assertions.sh | AC1-a: PREFLIGHT Step-1 cell states a case keyed on active:false + awaiting-user + no PR | 1 | registry:844-AC1-a-awaiting-user, registry:844-AC1-a-no-pr |
| tests/test-issue-844-doc-assertions.sh | AC1-b: the new case's disposition is preserve / do NOT archive (issue #978 delete->archive rewrite) | 1 | registry:844-AC1-b-preserve |
| tests/test-issue-844-doc-assertions.sh | AC1-c: the merged/closed archive path still requires an observed PR (safety net unchanged; issue #978 delete->archive rewrite) | 1 | registry:844-AC1-c-merged-or-closed, registry:844-AC1-c-archive-files |
| tests/test-issue-844-doc-assertions.sh | AC1-d: CLAUDE.md PR Wait Rule mode-selection sentence mirrors the PR-less awaiting-user reading | 1 | registry:844-AC1-d-awaiting-user, registry:844-AC1-d-no-pr |
| tests/test-issue-844-doc-assertions.sh | AC1-e (discriminator): the same sentence keeps the open-PR review-response reading textually distinct from the new no-PR case | 1 | registry:844-AC1-e-open-pr-distinct |
| tests/test-issue-844-doc-assertions.sh | AC2-a: PREFLIGHT Step-1 cell states a requested-issue active:true → resume branch, distinct from another-issue's report-and-hold | 1 | registry:844-AC2-a-resume-branch, registry:844-AC2-a-report-and-hold |
| tests/test-issue-844-doc-assertions.sh | AC2-b: a 'Resume procedure' heading exists under docs/autoflow-guide.md PREFLIGHT | 1 | registry:844-AC2-b-heading |
| tests/test-issue-844-doc-assertions.sh | AC2-c: the Resume procedure documents reading the last confirmed point from phases/phase | 1 | registry:844-AC2-c-last-point, registry:844-AC2-c-phases |
| tests/test-issue-844-doc-assertions.sh | AC2-d: the Resume procedure documents verifying resume prerequisites (dev branch + .autoflow artifacts) | 1 | registry:844-AC2-d-prereqs, registry:844-AC2-d-artifacts |
| tests/test-issue-844-doc-assertions.sh | AC2-e: the Resume procedure documents conservative re-entry after the last passed gate (re-run a gate lacking recorded scores) | 1 | registry:844-AC2-e-reenter, registry:844-AC2-e-scores |
| tests/test-issue-844-doc-assertions.sh | AC2-f (invariant 3): the Resume procedure states it does NOT increment cycle and does NOT reset phases | 1 | registry:844-AC2-f-no-increment, registry:844-AC2-f-no-reset |
| tests/test-issue-844-doc-assertions.sh | AC2-g (invariant 3): the Resume procedure block is textually separate from the Review-response mode setup block | 1 | load-time anchor gate, registry:844-AC2-g-resume-block-separate, registry:844-AC2-g-review-setup-separate |
| tests/test-issue-844-doc-assertions.sh | AC2-h: CLAUDE.md's active:true mode-selection reading cross-references the playbook Resume procedure section (not a dangling mention) | 1 | registry:844-AC2-h-crossref |
| tests/test-issue-844-doc-assertions.sh | AC-B3-a: PREFLIGHT Step 5 documents the issue-scoped dev-branch convention dev/YYYY-MM-DD-issue-N | 1 | registry:844-AC-B3-a-convention |
| tests/test-issue-844-doc-assertions.sh | AC-B3-b: the bare dev/YYYY-MM-DD create command (no -issue suffix) no longer stands alone as the create command | 1 | registry:844-AC-B3-b-bare-create |
| tests/test-issue-844-doc-assertions.sh | AC-B3-c: the review-response setup no longer claims the branch is recorded in .autoflow/issue-{target}.json | 1 | registry:844-AC-B3-c-no-recorded-json |
| tests/test-issue-844-doc-assertions.sh | AC-B3-d: the review-response setup derives the branch from the Step-5 naming convention instead | 1 | registry:844-AC-B3-d-derives |
| tests/test-issue-844-doc-assertions.sh | AC-B3-e: the Resume procedure resolves the branch via git branch --list against the dev/*-issue-<N> convention | 1 | registry:844-AC-B3-e-git-branch-list |
| tests/test-issue-844-doc-assertions.sh | AC3-a: teammate-common-rules.md no longer contains the unqualified 'previous PR is still unmerged' prohibition | 1 | registry:844-AC3-a-unqualified-gone |
| tests/test-issue-844-doc-assertions.sh | AC3-b: the narrowed rule scopes the new-branch prohibition to the SAME issue's open PR | 1 | registry:844-AC3-b-same-issue |
| tests/test-issue-844-doc-assertions.sh | AC3-c: the narrowed rule references PR Wait Rule / the active flag for cross-issue succession | 1 | registry:844-AC3-c-pr-wait-rule, registry:844-AC3-c-active-flag |
| tests/test-issue-844-doc-assertions.sh | AC4-a: docs/autoflow-guide.md no longer contains 'Two FAILs' at GATE:HYPOTHESIS or AUDIT | 1 | registry:844-AC4-a-two-fails-gone |
| tests/test-issue-844-doc-assertions.sh | AC4-b: docs/autoflow-guide.md states 'Third FAIL → human' at GATE:HYPOTHESIS | 1 | registry:844-AC4-b-hypothesis-third |
| tests/test-issue-844-doc-assertions.sh | AC4-c: docs/autoflow-guide.md states 'Third FAIL → human' at AUDIT | 1 | registry:844-AC4-c-audit-third |
| tests/test-issue-844-doc-assertions.sh | AC4-d: CLAUDE.md no longer states the bare '3 regressions without pass' | 1 | registry:844-AC4-d-bare-three-gone |
| tests/test-issue-844-doc-assertions.sh | AC4-e: CLAUDE.md's Human escalation line states the per-gate (N+1)th-FAIL rule, not a cross-gate total | 1 | registry:844-AC4-e-per-gate, registry:844-AC4-e-n-plus-1 |
| tests/test-issue-844-doc-assertions.sh | AC4-f: the cap→escalation arithmetic is defined once on the Regressions line | 1 | registry:844-AC4-f-regressions-line |
| tests/test-issue-844-doc-assertions.sh | AC4-g (invariant 4, diagram-unchanged): the diagram mirror still reads retry ≤2× for GATE:HYPOTHESIS | 1 | registry:844-AC4-g-diagram-hypothesis |
| tests/test-issue-844-doc-assertions.sh | AC4-g2 (invariant 4, diagram-unchanged): the diagram mirror still reads retry ≤2× for AUDIT | 1 | registry:844-AC4-g2-diagram-audit |
| tests/test-issue-844-doc-assertions.sh | AC4-h (single-definition): the (N+1)th-FAIL cap→escalation arithmetic is stated exactly once in CLAUDE.md | 1 | disposition:AC4-h |
| tests/test-issue-844-doc-assertions.sh | AC-CI-a: e2e-dummy-target.yml references test-issue-844-doc-assertions.sh | 1 | disposition:AC-CI-a |
| tests/test-issue-844-doc-assertions.sh | AC-CI-b: reference appears in a 'paths:' trigger block | 1 | disposition:AC-CI-b |
| tests/test-issue-844-doc-assertions.sh | AC-CI-c: reference appears in a 'run:' step | 1 | disposition:AC-CI-c |
| tests/test-issue-844-doc-assertions.sh | AC-CI-a: $CI_WORKFLOW exists | 1 | disposition:AC-CI-a |
