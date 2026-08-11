<!--
SPDX-FileCopyrightText: 2026 Munsik-Park
SPDX-License-Identifier: Elastic-2.0
-->
<!-- REUSE-IgnoreStart -->
<!-- This map records deleted assertions' first arguments VERBATIM (the
     equivalence record). Recorded descriptions may themselves contain the
     literal "SPDX-License-Identifier:" (the 985 AC3-SPDX legs), which the
     REUSE scanner would misparse as this file's own license expression —
     the same recording-artefact collision class as the token-sweep
     carve-outs (ledger E10). The file's real license is the header above. -->
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


**Every occurrence is accounted for, migrated or not.** The map's scope is the
twelve touched suites named in the feature design's *Files to change* — the two
migrated-and-deleted wholesale (`843`, `844`) and the ten partially touched. A
row whose assertion **moves** names its carriers. A row whose assertion **stays
where it is** names a `disposition:` from `docs/doc-invariant-registry.md` §6.1
with the reason it is not registry-expressible, which is the "or a disposition
with its reason" half of the row contract. There is no fourth carrier kind and
no unaccounted occurrence: an assertion that simply vanished from the record is
the bare deletion this artifact exists to prevent, and an assertion recorded as
"retained" without a reason is the same thing wearing a label.

`tests/issue-92/*.bats` is **outside** this map. Its assertions are `@test { … }`
bats blocks, a syntax the AC-a-1 extraction rule — defined over the
`assert_true`/`assert_false` command word — does not range over, so a row keyed
by that rule cannot name them. Their disposition is recorded in §6 instead: the
execution-shaped half was ported to `tests/test-issue-92-host-pr-execution.sh`,
the STATE half migrated to registry entries, and the count- and diff-shaped half
retired with a disposition row.

Line references in this document are to each suite **at the base ref**, which is
also where the checker extracts from: an assertion this cycle removes does not
exist at HEAD, so a working-tree read would silently shrink the corpus to the
retained-only subset and certify a totality it never checked.

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
| tests/test-issue-846-doc-assertions.sh | AC1-FALLBACK: label-removal bullet carries the 'gh issue edit <PR_NUMBER> --remove-label blocked-by-review' fallback | 1 | registry:846-AC1-FALLBACK |
| tests/test-issue-846-doc-assertions.sh | AC1-SUBREPO: label-removal bullet notes --repo for sub-repo PRs | 1 | registry:846-AC1-SUBREPO |
| tests/test-issue-846-doc-assertions.sh | AC1-VERIFY: label-removal bullet requires 'gh pr view <PR_NUMBER> --json labels' verification before reporting | 1 | registry:846-AC1-VERIFY |
| tests/test-issue-846-doc-assertions.sh | AC1-ACTOR: docs/autoflow-guide.md does not carry a --remove-label blocked-by-review command | 1 | registry:846-AC1-ACTOR |
| tests/test-issue-846-doc-assertions.sh | AC2-GUIDE: docs/autoflow-guide.md step 6.5 carries the verbatim window-phrase substring A | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-846-doc-assertions.sh | AC2-GUIDE: docs/autoflow-guide.md step 6.5 carries the verbatim window-phrase substring B | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-846-doc-assertions.sh | AC2-RATIONALE: docs/design-rationale.md Decision 9 carries the verbatim window-phrase substring A | 1 | registry:846-AC2-RATIONALE-A |
| tests/test-issue-846-doc-assertions.sh | AC2-RATIONALE: docs/design-rationale.md Decision 9 carries the verbatim window-phrase substring B | 1 | registry:846-AC2-RATIONALE-B |
| tests/test-issue-846-doc-assertions.sh | AC2-NOCONTRA (autoflow-guide.md): bare 'Count this issue's review-autofix-marked ledger entries' does not coexist with the window phrase | 1 | disposition:76-RETAIN-NEGATED-CONJUNCTION |
| tests/test-issue-846-doc-assertions.sh | AC2-NOCONTRA (design-rationale.md): bare '(counted via review-autofix-marked ledger entries)' does not coexist with the window phrase | 1 | disposition:76-RETAIN-NEGATED-CONJUNCTION |
| tests/test-issue-846-doc-assertions.sh | AC2-NOLABELCLEAR (autoflow-guide.md): no sentence names a label-clear as the cap-window reset trigger | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/test-issue-846-doc-assertions.sh | AC2-NOLABELCLEAR (design-rationale.md): no sentence names a label-clear as the cap-window reset trigger | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/test-issue-846-doc-assertions.sh | AC3-DURABLE: step 6.5 requires a durable record naming the host PR | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-846-doc-assertions.sh | AC3-DURABLE: step 6.5 durable-record clause covers the cap-fire trigger | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-846-doc-assertions.sh | AC3-DURABLE: step 6.5 durable-record clause covers the user re-entry trigger | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-846-doc-assertions.sh | AC3-GITHUBSIDE: the durable-record clause does not point at .autoflow/*/the ledger as the record location | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-846-doc-assertions.sh | CLAUDEMD-NOCONTRA: CLAUDE.md Regressions line does not name label-clear as a reset trigger | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/test-issue-846-doc-assertions.sh | AC-PRESERVE: .codex/review.md still requires reporting failure clearly if label removal fails | 1 | registry:846-AC-PRESERVE-failclause |
| tests/test-issue-846-doc-assertions.sh | AC-PRESERVE: docs/autoflow-guide.md/design-rationale.md still state the orchestrator never owns/clears the label | 1 | registry:846-AC-PRESERVE-neverowns |
| tests/test-issue-846-doc-assertions.sh | AC-CI-a: e2e-dummy-target.yml references test-issue-846-doc-assertions.sh | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-846-doc-assertions.sh | AC-CI-b: reference appears in a 'paths:' trigger block | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-846-doc-assertions.sh | AC-CI-c: reference appears in a 'run:' step | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-846-doc-assertions.sh | AC-CI-a: $CI_WORKFLOW exists | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-847-doc-assertions.sh | AC1-a: INTEGRATE body carries the '### Deploy/CI-path conditional verification' sub-heading | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC1-b: subsection names all four trigger classes (.gitmodules, .github/workflows, Jenkinsfile, deploy-, .env) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC1-c: subsection names all three bundle items (dry-run+--init --recursive; CI static/lint validation; routing/landing smoke) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC2-a: INTEGRATE body contains 'git diff --name-only' AND 'grep -E' (concrete command, not prose) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC2-COHERENCE-EXEC: INTEGRATE body contains the frozen TRIGGER_REGEX verbatim on one physical line | 1 | disposition:76-RETAIN-TRIGGER-REGEX |
| tests/test-issue-847-doc-assertions.sh | AC2-EXEC-POS: TRIGGER_REGEX matches '$f' | 1 | disposition:76-RETAIN-TRIGGER-REGEX |
| tests/test-issue-847-doc-assertions.sh | AC2-EXEC-NEG: TRIGGER_REGEX does NOT match '$f' | 1 | disposition:76-RETAIN-TRIGGER-REGEX |
| tests/test-issue-847-doc-assertions.sh | AC-COHERENCE-a: INTEGRATE body references 'Deploy/CI-path' (canonical name) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-COHERENCE-b: VALIDATE body references the canonical subsection name '### Deploy/CI-path conditional verification' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-NOOP-a: INTEGRATE subsection carries the defined-no-op clause ('no deploy/CI-path surface') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-NOOP-b: VALIDATE item 6 carries the same defined-no-op clause ('no deploy/CI-path surface') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-FAIL: subsection states the FAIL disposition (INTEGRATE FAIL -> RED) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-PRESERVE-a: existing INTEGRATE single-repo no-op sentence retained ('no-op (single-repo') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-PRESERVE-b: VALIDATE item 1 (automated tests all PASS) retained | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-PRESERVE-c: VALIDATE item 5 (manifest coherence) retained | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-CI-a: e2e-dummy-target.yml references test-issue-847-doc-assertions.sh (>= 3 occurrences: 2 paths blocks + 1 run step) | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-847-doc-assertions.sh | AC-CI-b: reference appears in a 'paths:' trigger block | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-CI-c: reference appears in a 'run:' step | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-847-doc-assertions.sh | AC-CI-a: $CI_WORKFLOW exists | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-848-doc-assertions.sh | AC1-DELIVER-MARKER: DELIVER section carries a '*Secondary (multi-repo):*' marker bullet (promoted from the fenced 1.-3. list) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC1-DELIVER-ACTOR: the DELIVER *Secondary* marker block names the pointer-bump actor as orchestrator | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC1-DELIVER-GITLINK: the DELIVER *Secondary* marker block names the services gitlink/pointer target | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC1-DELIVER-FORWARDREF: the DELIVER *Secondary* marker block forward-refs HANDOFF step 4b for the commit format | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC1-HANDOFF-STEP: HANDOFF step 4b carries 'git add services' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC1-HANDOFF-STEP: HANDOFF step 4b carries the canonical commit-message format 'chore(#N): bump services pointer to <short-sha>' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC1-OWNERSHIP-ROW: Commit Ownership table has a pointer-bump row with committer Orchestrator | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC1-XREF: submodule-common-rules.md reconciles 'only the submodule pointer' with the orchestrator actor | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC1-NO-HOSTONLY-BLEED: the DELIVER host-only (default) paragraph (before any *Secondary* marker) never gains 'git add services' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC1-XREF-NOCONTRA: submodule-common-rules.md still states 'Each developer commits only the submodule pointer' | 1 | registry:848-AC1-XREF-NOCONTRA |
| tests/test-issue-848-doc-assertions.sh | AC2-MUST: HANDOFF step 3 carries a [MUST] re-bump clause | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC2-MUST: HANDOFF step 3 requires the 'git ls-tree HEAD services' verification | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-848-doc-assertions.sh | AC2-SOLE-DEFENSE: HANDOFF step 3 states the sole-defense English phrase 'only remaining' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC2-SOLE-DEFENSE: HANDOFF step 3 anchors the sole-defense clause to #795/ADR-0015 | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC2-NO-PERPUSH: HANDOFF step 3 block does not mandate an unconditional per-push re-bump | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/test-issue-848-doc-assertions.sh | AC3-NO-LIVE-WORKFLOW: Merge Sequencing section does not describe handoff-sequence.yml as a live machine-verify without a retirement token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC3-EXIT79-CTX: Pointer-reconciliation section does not attribute Exit 79/subrepo-merged assertion 3 without a retirement token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC3-RETIRE-ALIGNED: git-workflow.md carries a #795/ADR-0015 retirement anchor | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC3-PRESERVE-MANUAL: Pointer-reconciliation section still requires the git ls-tree HEAD services manual check | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-848-doc-assertions.sh | AC3-PRESERVE-MANUAL: Merge Sequencing section still names the blocked-by-subrepo label | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC3-XDOC-NOCONTRA: external-review-sequencing.md still carries its #795/ADR-0015 D3 retirement record | 1 | registry:848-AC3-XDOC-NOCONTRA |
| tests/test-issue-848-doc-assertions.sh | AC4-DEFER: HANDOFF step 6.5 states the propagation-batching defer-until-clean rule | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC4-EXTREVSEQ: external-review-sequencing.md carries a one-line cross-ref to HANDOFF step 6.5 for the batching norm | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC4-EXCEPTION: HANDOFF step 6.5 carries the ASCII exception commit-format token 'interim services bump' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC4-EXCEPTION: HANDOFF step 6.5 requires the exception commit to record a reason | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC4-NO-NESTED-PRESUME: HANDOFF step 6.5 block does not depend on nested/multi-tier/grandparent tokens | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/test-issue-848-doc-assertions.sh | AC5-ADR-CITED: git-workflow.md cites ADR-0015 | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-848-doc-assertions.sh | AC5-NO-REVIVE: HANDOFF section of autoflow-guide.md does not reintroduce subrepo-merged as a live machine status check | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC-CI-a: e2e-dummy-target.yml references test-issue-848-doc-assertions.sh | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-848-doc-assertions.sh | AC-CI-b: reference appears in a 'paths:' trigger block | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC-CI-c: reference appears in a 'run:' step | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-848-doc-assertions.sh | AC-CI-a: $CI_WORKFLOW exists | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-canonical: '## Bash Execution Mode' section exists in docs/teammate-common-rules.md | 1 | registry:955-AC1-a-canonical-heading |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-canonical: canonical clause is [MUST] and names run_in_background | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-canonical: canonical clause names foreground | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-canonical: canonical clause names teammate or subagent scope | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-mirror: '### Bash execution mode' subsection exists in docs/submodule-common-rules.md | 1 | registry:955-AC1-a-mirror-heading |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-mirror: mirror clause names run_in_background + foreground | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-mirror: mirror clause cross-links the canonical home (teammate-common-rules.md > Bash Execution Mode) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-a-mirror-equality: canonical clause body and mirror clause body (cross-link stripped) are line-identical | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-b: $rel Hard-rules bullet names run_in_background + foreground | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-c: docs/teammate-contracts.md names run_in_background + foreground | 1 | registry:955-AC1-c-contracts-rib, registry:955-AC1-c-contracts-foreground |
| tests/test-issue-955-subagent-background-ban.sh | AC1-c: docs/teammate-contracts.md explicitly names workflow in-script sub-agents (in-script / workflows/*) | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-955-subagent-background-ban.sh | AC1-d: docs/teammate-common-rules.md — run_in_background co-located with foreground | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-d: docs/submodule-common-rules.md — run_in_background co-located with foreground | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-d: docs/teammate-contracts.md — run_in_background co-located with foreground | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-counterpart: Execution Principles states orchestrator/main-loop scope | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-counterpart: Execution Principles names background | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC1-counterpart: Execution Principles justifies via the future-turn lifecycle contract | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC2: Teammate idle handling carries a Done/completed token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC2: Teammate idle handling carries a shell-verification token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC2: Teammate idle handling carries a do-not-wait token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC3: REFINE section carries a foreground/direct-execution token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC3: VERIFY section carries a foreground/direct-execution token | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC4-DOGFOOD: diff-∩-sources non-empty ⇒ setup/manifest.json is itself in the diff | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-955-subagent-background-ban.sh | AC4-CLOSURE: manifest source-row set is identical at <base> and HEAD, or the only delta is the #951 docs/doc-invariant-registry.md manifest-closure row (§DR-8, ledger E14), is the #979 reviewer-backend-selection six-row delivery set (ledger E12), is the #979 cycle-9 seven-row delivery set (six-row set plus scripts/review/lib/claude-isolation.sh, ledger E13), is the #25 confirm-ci-green.sh single-row delivery set (ledger issue-25 E14), is the #51 docs/adr/0017-teammate-removal-feasibility.md single-row delivery set (GATE:QUALITY E36), is the #69 docs/adr/0018-verification-depth-justification.md single-row delivery set, or is the #71 two-row removal set (emit-cycle-digest.sh + scan-cross-issue-recurrence.sh, zero additions) | 1 | disposition:76-DROP-AC4-CLOSURE |
| tests/test-issue-955-subagent-background-ban.sh | AC5-a: canonical clause names BOTH direct-spawn (autoflow-*) AND in-script workflow agents | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC5-a: teammate-contracts.md run_in_background clause co-locates a direct-spawn actor token AND an in-script token (not a generic unrelated mention) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC5-b: canonical clause binds the actor's OWN verification command ('own'/'its own' co-located with 'verification') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC5-c: canonical clause is normatively [MUST] | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | CI-a: e2e-dummy-target.yml references test-issue-955-subagent-background-ban.sh | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-955-subagent-background-ban.sh | CI-b: reference appears in a 'paths:' trigger block | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | CI-c: reference appears in a 'run:' step | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | CI-a: $CI_WORKFLOW exists | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: $rel names run_in_background | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: $rel names foreground | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: $rel names the Bash Execution Mode pointer | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: architect-deliberation.js clause on >= 6 non-comment (prompt-literal) lines | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: verify-cause-branch.js clause on >= 3 non-comment (prompt-literal) lines | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: architect ledger CONVERGED branch (line carrying 'ARCHITECT mutual ACCEPT') carries the clause | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1: architect ledger non-converged branch (line carrying 'ARCHITECT non-convergence') carries the clause | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1 tripwire: architect-deliberation.js has exactly 5 agent( call sites | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-1 tripwire: verify-cause-branch.js has exactly 3 agent( call sites | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-2: suite variable ARCH_WF resolves to an existing file | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-955-subagent-background-ban.sh | AC-C2-2: suite variable VERIFY_WF resolves to an existing file | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-955-subagent-background-ban.sh | G-REG: node test/workflows/run.mjs exits 0 | 1 | disposition:76-RETAIN-EXEC |
| tests/test-issue-955-subagent-background-ban.sh | G-REG: $RUN_MJS exists | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-955-subagent-background-ban.sh | AC-PRESERVE-a: REFINE existing [MUST] 'Re-run all tests' item retained | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC-PRESERVE-b: VERIFY existing cause-branch table (RED | GREEN | SEQUENTIAL_FIX | EVALUATION_AI) retained | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC-PRESERVE-c: submodule-common-rules.md Reporting Format items 1-6 retained | 1 | registry:955-AC-PRESERVE-c-reporting |
| tests/test-issue-955-subagent-background-ban.sh | AC-PRESERVE-d: CLAUDE.md Teammate-idle 'continue work when (a)/(b)/(c)' list retained | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-955-subagent-background-ban.sh | AC-PRESERVE-deletion-audit: no contiguous run >15 deleted lines across the five edited docs | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-798-topology-flip.sh | AC1: .gitmodules absent from HEAD (git ls-tree empty) | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-798-topology-flip.sh | AC1 (fallback): no [submodule stanza in committed .gitmodules | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-798-topology-flip.sh | AC2a: git ls-tree HEAD -- services is empty | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-798-topology-flip.sh | AC2b: git ls-files -s -- services has no 160000 mode row | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-798-topology-flip.sh | AC3a: git submodule status is empty | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-798-topology-flip.sh | AC3b: HEAD .gitmodules path-entry count == 0 | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-798-topology-flip.sh | AC5-negative: old multi-repo self-classification sentence absent | 1 | registry:798-AC5-negative-multirepo-gone |
| tests/test-issue-798-topology-flip.sh | AC5-positive: '**zero submodules** → **single-repo**' present (non-vacuous arrow literal) | 1 | registry:798-AC5-positive-singlerepo |
| tests/test-issue-798-topology-flip.sh | AC6a: CLAUDE.md single-repo dual-mode definition present & unchanged | 1 | registry:798-AC6a-singlerepo-def |
| tests/test-issue-798-topology-flip.sh | AC6a: CLAUDE.md multi-repo dual-mode definition present & unchanged | 1 | registry:798-AC6a-multirepo-def |
| tests/test-issue-798-topology-flip.sh | AC6b: no diff hunk touches a '*Secondary (multi-repo):*' marker line | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-798-topology-flip.sh | AC7a: ADR-0015 'remains a valid multi-repo' sentence present | 1 | registry:798-AC7a-adr0015-sentence |
| tests/test-issue-798-topology-flip.sh | AC7b: no diff hunk against ADR-0015 (immutable historical record) | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-798-topology-flip.sh | AC9: diff touches no .claude/hooks/** path, OR only check-autoflow-gate.sh with its plugin mirror byte-identical (#843 parity-carried exception) | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-798-topology-flip.sh | AC9: diff touches no .claude/workflows/** path, OR every touched .claude/workflows/** path has a setup/manifest.json sha256 row matching its current content (#62 D10 — supersedes the #985/#27/#56/#59 substring window) | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-798-topology-flip.sh | AC12a: $ci_home references tests/test-issue-798-topology-flip.sh | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-798-topology-flip.sh | AC12b: $ci_home paths: trigger lists .gitmodules | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-798-topology-flip.sh | AC12a: some workflow references tests/test-issue-798-topology-flip.sh | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-798-topology-flip.sh | AC15a: README has no --recurse-submodules clone instruction | 1 | registry:798-AC15a-no-recurse |
| tests/test-issue-798-topology-flip.sh | AC15b: README structure tree has no '(git submodule)' entry | 1 | registry:798-AC15b-no-submodule-tree |
| tests/test-issue-798-topology-flip.sh | AC15c (guard): README generic 'single-repo is the degenerate case' prose preserved | 1 | registry:798-AC15c-degenerate-prose |
| tests/test-issue-799-inert-cleanup.sh | AC1-neg: README no longer narrates the interactive setup wizard as the primary path | 1 | registry:799-AC1-neg-wizard |
| tests/test-issue-799-inert-cleanup.sh | AC1-pos: README documents the consumed-tool --target flow | 1 | registry:799-AC1-pos-target, registry:799-AC1-pos-marketplace |
| tests/test-issue-799-inert-cleanup.sh | AC2-neg: README no longer annotates init.sh/SETUP-GUIDE.md as template-era | 1 | registry:799-AC2-neg-template-era |
| tests/test-issue-799-inert-cleanup.sh | AC2-tree: README structure tree lists docs/adr/, docs/phases/, .claude/agents/, .claude/workflows/, .github/workflows/, scripts/, tests/, plugin/, setup/manifest.json | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-799-inert-cleanup.sh | AC3D-checklist-neg: README Post-Setup no longer cites the legacy 'no remaining {{placeholders}}' output | 1 | registry:799-AC3D-checklist-neg |
| tests/test-issue-799-inert-cleanup.sh | AC3D-checklist-pos: README Post-Setup references drift-check.sh or AUTOFLOW-IMPORT | 1 | registry:799-AC3D-checklist-pos |
| tests/test-issue-799-inert-cleanup.sh | AC3D-section-neg: README Single-Repo-vs-Multi-Repo no longer says 'skip the sub-repo placeholders' | 1 | registry:799-AC3D-section-neg |
| tests/test-issue-799-inert-cleanup.sh | $label: present-tense self-claim co-occurs with a #798/detach reference | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/test-issue-799-inert-cleanup.sh | $label: present-tense self-claim literal absent (no qualifier needed) | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/test-issue-799-inert-cleanup.sh | AC3-guard: no diff hunk over docs/ README.md touches a 'Secondary (multi-repo):' marker line | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-799-inert-cleanup.sh | AC3-nores: no NEW doc line (changed surface) points at services/librechat as a live tracked path | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-799-inert-cleanup.sh | AC5D-index-neg: INDEX.md no longer routes to the inert services/librechat/docs/ path | 1 | registry:799-AC5D-index-neg |
| tests/test-issue-799-inert-cleanup.sh | AC5D-index-pos: INDEX.md carries no route to a non-existent services/librechat path | 1 | registry:799-AC5D-index-pos |
| tests/test-issue-799-inert-cleanup.sh | AC5D-maint-neg: maintained-docs.md carries the 'N/A under zero-submodule topology' qualifier | 1 | registry:799-AC5D-maint-qualifier |
| tests/test-issue-799-inert-cleanup.sh | AC5D-maint-neg (paired): '### Sub-repo (\`services/librechat\`)' header still present | 1 | registry:799-AC5D-maint-header |
| tests/test-issue-799-inert-cleanup.sh | AC4-guard: no broken repo-relative link in INDEX.md / maintained-docs.md | 1 | disposition:76-RETAIN-EXEC |
| tests/test-issue-799-inert-cleanup.sh | AC5G-neg: git-workflow.md no longer says 'deferred to S11a' | 1 | registry:799-AC5G-neg-s11a |
| tests/test-issue-799-inert-cleanup.sh | AC5G-guard: git-workflow.md still frames the reconcile step as 'active N/A' | 1 | registry:799-AC5G-guard-active-na |
| tests/test-issue-799-inert-cleanup.sh | AC5H-degenerate: README still contains 'single-repo is the degenerate case' | 1 | registry:798-AC15c-degenerate-prose |
| tests/test-issue-799-inert-cleanup.sh | AC5H-nosubmod: README does not reintroduce --recurse-submodules | 1 | registry:798-AC15a-no-recurse |
| tests/test-issue-799-inert-cleanup.sh | AC5H-nosubmod: README does not reintroduce '(git submodule)' | 1 | registry:798-AC15b-no-submodule-tree |
| tests/test-issue-799-inert-cleanup.sh | AC6-scope: diff does not touch .claude/hooks/**, OR only check-autoflow-gate.sh with its plugin mirror byte-identical (#843 parity-carried exception) | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-799-inert-cleanup.sh | AC6-scope: diff touches no .claude/workflows/** path, OR every touched .claude/workflows/** path has a setup/manifest.json sha256 row matching its current content (#62 D10 — supersedes the #985/#27/#56/#59 substring window) | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-799-inert-cleanup.sh | AC6-ci: e2e-dummy-target.yml references tests/test-issue-799-inert-cleanup.sh | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-799-inert-cleanup.sh | AC6-ci: e2e-dummy-target.yml paths: trigger lists README.md | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-799-inert-cleanup.sh | AC6-ci: e2e-dummy-target.yml paths: trigger lists the edited docs/*.md files | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-985-doc-assertions.sh | AC1-SWEEP: tests/fixtures/expected-connev-residual.txt exists | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-985-doc-assertions.sh | AC1-SWEEP: git grep -il connev match set equals expected-connev-residual.txt exactly | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC1-DOMAIN: 'connev\\.io' appears only in the host-purity denylist fixture set (L4) plus this suite's own doc comment | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC1-INTERNAL-DOCS-ABSENT: $removed is absent from git ls-files | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC1-INTERNAL-DOCS-ABSENT: docs/adr/0001-*.md is absent from git ls-files | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC1-BACKLOG-EMPTY-START: docs/improvement-backlog.md is tracked with no internal finding blocks | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC1-NO-DANGLING-REF: docs/adr/0001 is deleted and no tracked file still references its basename | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC2-KEY-CONSISTENT: no surviving 'autoflow@claude-autoflow' literal | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC3-SPDX-COVERAGE: REUSE.toml exists | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-985-doc-assertions.sh | AC3-SPDX-COVERAGE: LICENSES/Elastic-2.0.txt exists (Elastic-2.0 is SPDX-listed - no LicenseRef file) | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-985-doc-assertions.sh | AC3-SPDX-COVERAGE: LICENSES/LicenseRef-PolyForm-Internal-Use-1.0.0.txt is absent | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-985-doc-assertions.sh | AC3-SPDX-COVERAGE: every tracked .sh/.py/.bats/.yml/.js/.mjs file carries the SPDX-License-Identifier: Elastic-2.0 line | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC3-SPDX-COVERAGE: no surviving 'LicenseRef-PolyForm-Internal-Use-1.0.0' token anywhere tracked | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-985-doc-assertions.sh | AC3-WORKFLOW-COUNT: reuse.yml is present alongside the 5 existing workflows | 1 | disposition:76-RETAIN-CI-REGISTRATION |
| tests/test-issue-985-doc-assertions.sh | AC-LICENSE: LICENSE carries the Elastic License 2.0 distinctive marker (not MIT, not PolyForm) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-985-doc-assertions.sh | AC-LICENSE: LICENSE no longer opens with 'MIT License' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-985-doc-assertions.sh | AC-LICENSE: LICENSE no longer carries the PolyForm Internal Use marker | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/test-issue-985-doc-assertions.sh | AC-LICENSE: LICENSE carries the Copyright (c) 2026 Munsik-Park notice | 1 | registry:985-AC-LICENSE-copyright |
| tests/test-issue-985-doc-assertions.sh | AC-LICENSE: LICENSES/Elastic-2.0.txt exists with content | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-985-doc-assertions.sh | AC-LICENSE: LICENSES/LicenseRef-PolyForm-Internal-Use-1.0.0.txt is absent | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-985-doc-assertions.sh | AC4-INSTALL-PATH: README contains '/plugin marketplace add Munsik-Park/autoflow' | 1 | registry:985-AC4-INSTALL-PATH-marketplace |
| tests/test-issue-985-doc-assertions.sh | AC4-INSTALL-PATH: README no longer contains 'connev-llm' | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-985-doc-assertions.sh | AC4-LICENSE-SUMMARY: README carries an Elastic License 2.0 allow/deny summary section | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-985-doc-assertions.sh | AC4-LICENSE-SUMMARY: README states hosted/managed-service provision is prohibited | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/test-issue-985-doc-assertions.sh | AC4-LICENSE-SUMMARY: README carries the one-line commercial-exception notice (commercial license + contact path) | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC1-a: ADR file exists at docs/adr/0016-adr-conformance-gate-scoring.md | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/adr-0016-conformance-check.sh | AC1-b: '## Status' section states 'Accepted' (flipped post-#961 owner promotion; issue #961 AC10) | 1 | registry:adr0016-AC1-b-status-accepted |
| tests/adr-0016-conformance-check.sh | AC1-c: '## Decision' heading present (level-tolerant) | 1 | registry:adr0016-AC1-c-decision-heading |
| tests/adr-0016-conformance-check.sh | AC1-d: verbatim lowercase verdict token 'Decision: adopt' present inside the Decision block (case-sensitive) | 1 | registry:adr0016-AC1-d-verdict-token |
| tests/adr-0016-conformance-check.sh | AC1-e: '### Rationale' heading present (level-tolerant), distinct from the verdict token | 1 | registry:adr0016-AC1-e-rationale-heading |
| tests/adr-0016-conformance-check.sh | AC1-f: README 'Current Drafts' table gains a '0016-adr-conformance' row | 1 | registry:adr0016-AC1-f-readme-row |
| tests/adr-0016-conformance-check.sh | AC1-guard: README Status Values lists Proposed/Accepted/Deprecated/Superseded | 1 | registry:adr0016-AC1-guard-proposed, registry:adr0016-AC1-guard-accepted, registry:adr0016-AC1-guard-deprecated, registry:adr0016-AC1-guard-superseded |
| tests/adr-0016-conformance-check.sh | AC2-a: '### Placement' heading present (level-tolerant) | 1 | registry:adr0016-AC2-a-placement-heading |
| tests/adr-0016-conformance-check.sh | AC2-b: Placement block names ARCHITECT | 1 | registry:adr0016-AC2-b-placement-architect |
| tests/adr-0016-conformance-check.sh | AC2-c: Placement block names GATE:PLAN | 1 | registry:adr0016-AC2-c-placement-gateplan |
| tests/adr-0016-conformance-check.sh | AC2-d: Placement block names GATE:QUALITY | 1 | registry:adr0016-AC2-d-placement-gatequality |
| tests/adr-0016-conformance-check.sh | AC2-e: Placement block names the Feasibility cap target in-block | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC2-f: Placement block names the Scope cap target in-block | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC2-g: '### Item form' heading present (level-tolerant) | 1 | registry:adr0016-AC2-g-itemform-heading |
| tests/adr-0016-conformance-check.sh | AC2-h: Item form block states 'caps the named item at 6' | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC2-i: Item form block states 'not a new scored item' | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC2-j: '### N/A convention' heading present (level-tolerant) | 1 | registry:adr0016-AC2-j-naconvention-heading |
| tests/adr-0016-conformance-check.sh | AC2-k: N/A convention block states the Conforms outcome (no cap) | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC2-l: N/A convention block states the Diverges/undocumented outcome (cap 6) | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC2-m: N/A convention block states N/A is the default for a change touching no ADR-decision surface | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC3-a: '### Threshold & hook cascade' heading present (level-tolerant) | 1 | registry:adr0016-AC3-a-threshold-heading |
| tests/adr-0016-conformance-check.sh | AC3-b: Threshold block asserts no new scores key | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC3-c: Threshold block asserts no hook edit | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC3-d: Threshold block asserts no threshold recompute | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC3-guard-a: Threshold block does not claim a hook edit is required | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/adr-0016-conformance-check.sh | AC3-guard-b: Threshold block does not claim a threshold recompute is required | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/adr-0016-conformance-check.sh | AC3-guard-c: Threshold block does not describe N+1-item averaging as the chosen form's behavior | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/adr-0016-conformance-check.sh | AC3-hook-a: check_scores computes avg via add/length (item-count-agnostic) | 1 | registry:adr0016-AC3-hook-a-avg |
| tests/adr-0016-conformance-check.sh | AC3-hook-b: check_scores reads security by key name | 1 | registry:adr0016-AC3-hook-b-security-key |
| tests/adr-0016-conformance-check.sh | AC3-hook-c: cap fires via the pre-existing \$min < 7 branch | 1 | registry:adr0016-AC3-hook-c-min-branch |
| tests/adr-0016-conformance-check.sh | AC4-a: '### DIAGNOSE consistency' heading present (level-tolerant) | 1 | registry:adr0016-AC4-a-diagnose-heading |
| tests/adr-0016-conformance-check.sh | AC4-guard-a: analysis.md [DENY] on injecting ADR-candidate docs is live | 1 | registry:adr0016-AC4-guard-a-deny |
| tests/adr-0016-conformance-check.sh | AC4-guard-b: analysis.md whitelist row denies ADR candidates to all three roles | 1 | registry:adr0016-AC4-guard-b-whitelist |
| tests/adr-0016-conformance-check.sh | AC5-a: '### Case collection' heading present (level-tolerant) | 1 | registry:adr0016-AC5-a-casecollection-heading |
| tests/adr-0016-conformance-check.sh | AC6-a: '### Follow-up scope' heading present (level-tolerant) | 1 | registry:adr0016-AC6-a-followup-heading |
| tests/adr-0016-conformance-check.sh | AC-R1-a: a 0016 row exists inside the ADRs table block of maintained-docs.md | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-R1-b: the matched line is a real 4-column table row (leading + internal pipes) | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-R2-a: the 'AutoFlow rules, gates...' routing row references ADR-0016 | 1 | registry:adr0016-AC-R2-a-routing-row |
| tests/adr-0016-conformance-check.sh | AC-R2-b: that row does not use a markdown-link form to the ADR (backtick inline-code form required, not '](adr/0016...)') | 1 | disposition:76-RETAIN-ABSENT-REGEX |
| tests/adr-0016-conformance-check.sh | AC-R3-a: manifest sha256 for docs/maintained-docs.md matches current source hash | 1 | disposition:76-RETAIN-JSON-SHAPE |
| tests/adr-0016-conformance-check.sh | AC-R3-b: manifest sha256 for docs/INDEX.md matches current source hash | 1 | disposition:76-RETAIN-JSON-SHAPE |
| tests/adr-0016-conformance-check.sh | AC-961-1-a: new '### ADR-conformance check' subsection heading present in autoflow-guide.md | 1 | registry:adr0016-AC961-1-a-subsection |
| tests/adr-0016-conformance-check.sh | AC-961-1-b: ADR-conformance check subsection (GATE:PLAN) names both Feasibility and Scope | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-1-c: ADR-conformance check subsection carries T-CAP verbatim ('caps the named item at 6'), window-scoped | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-1-d: ADR-conformance check subsection carries T-TRIG-1 verbatim ('divergence from a governing ADR') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-1-e: ADR-conformance check subsection carries T-TRIG-2 verbatim ('architecture-impacting change with no governing ADR/owner decision') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-1-f: ADR-conformance check subsection carries T-NA verbatim ('N/A by default') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-1-g: GATE:QUALITY blind-spot list carries item-specific 'caps Fit at 6' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-1-h: ARCHITECT Agreement criteria carries T-NONSCORED verbatim ('a divergence is a COUNTER, not an ACCEPT') | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-2-a: evaluation-system.md GATE:PLAN row names the embedded ADR-conformance check | 1 | registry:adr0016-AC961-2-a-gateplan-row |
| tests/adr-0016-conformance-check.sh | AC-961-2-b: evaluation-system.md GATE:QUALITY row names the embedded ADR-conformance check | 1 | registry:adr0016-AC961-2-b-gatequality-row |
| tests/adr-0016-conformance-check.sh | AC-961-2-c: teammate-contracts.md Facilitator Responsibilities names ADR conformance as a first-exchange axis | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC-961-2-d: cross-doc cap-surface co-occurrence — evaluation-system.md GATE:PLAN row names Feasibility, Scope, and the cap value 6 | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/adr-0016-conformance-check.sh | AC-961-2-e: cross-doc cap-surface co-occurrence — evaluation-system.md GATE:QUALITY row names Fit and the cap value 6 | 1 | disposition:76-RETAIN-MULTI-FILE |
| tests/adr-0016-conformance-check.sh | AC-961-2-f: GATE:QUALITY blind-spot intro no longer hard-counts 'Three defect patterns' | 1 | disposition:76-RETAIN-REGION-INEXPRESSIBLE |
| tests/adr-0016-conformance-check.sh | AC-961-2-g: GATE:QUALITY blind-spot section carries a distinct-provenance marker for the proactive ADR-0016 check (not a Codex catch) | 1 | disposition:76-RETAIN-CASE-INSENSITIVE |
| tests/adr-0016-conformance-check.sh | AC-961-5-a: ADR '## Status' block carries the 'Owner approval: 2026-07-08' evidence line | 1 | registry:adr0016-AC961-5-a-owner-approval |
| tests/adr-0016-conformance-check.sh | AC-961-5-b: docs/adr/README.md 0016 row status flipped to Accepted | 1 | registry:adr0016-AC961-5-b-readme-accepted |
| tests/adr-0016-conformance-check.sh | AC-961-7-a: README numbering-gap note names the migrated range 0002, 0004-0014 | 1 | registry:adr0016-AC961-7-a-range |
| tests/adr-0016-conformance-check.sh | AC-961-7-b: README numbering-gap note attributes the migration to the 2026-06-27 split -> services/librechat-deploy | 1 | registry:adr0016-AC961-7-b-date, registry:adr0016-AC961-7-b-repo |
| tests/adr-0016-conformance-check.sh | AC-961-7-c: README numbering-gap note cross-references docs/maintained-docs.md as the authoritative registry | 1 | registry:adr0016-AC961-7-c-registry |
| tests/test-issue-16-manifest-locale-invariance.sh | AC1-a: setup/gen-manifest-hashes.sh contains a script-entry 'export LC_ALL=C' pin | 1 | registry:16-AC1-a-lcall-pin |
| tests/test-issue-16-manifest-locale-invariance.sh | AC2-gen-exit0: the generator exits 0 in the isolated temp copy | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-16-manifest-locale-invariance.sh | AC2-byte-identical: the regenerated setup/manifest.json is byte-identical to the committed one | 1 | disposition:76-RETAIN-EXEC |
| tests/test-issue-16-manifest-locale-invariance.sh | AC3-gen-exit0-c: the generator exits 0 under LC_ALL=C | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-16-manifest-locale-invariance.sh | AC3-gen-exit0-utf: the generator exits 0 under LC_ALL=$AC3_UTF8_CANDIDATE | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-16-manifest-locale-invariance.sh | AC3-byte-identical-cross-locale: regenerating under LC_ALL=C and LC_ALL=$AC3_UTF8_CANDIDATE produces byte-identical setup/manifest.json (pre-fix: FAILs — the two runs inherit their differing ambient LC_ALL and reorder; post-fix: the in-script export LC_ALL=C overrides both) | 1 | disposition:76-RETAIN-EXEC |
| tests/test-issue-16-manifest-locale-invariance.sh | AC4-adr0016-suite-exit0: tests/adr-0016-conformance-check.sh (AC-R3 sha256/count guards, order-insensitive by construction) exits 0 unmodified | 1 | disposition:76-RETAIN-COUNT |
| tests/test-issue-16-manifest-locale-invariance.sh | AC4-adr0016-suite-exists: tests/adr-0016-conformance-check.sh exists | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-16-manifest-locale-invariance.sh | AC-C2-1-a: no HEAD-restore command targeting the real tree's setup/manifest.json remains | 1 | disposition:76-RETAIN-SELF-SUBJECT |
| tests/test-issue-16-manifest-locale-invariance.sh | AC-C2-1-b: no descriptor/comment line spells the HEAD-restore command as a literal real-space token | 1 | disposition:76-RETAIN-SELF-SUBJECT |
| tests/test-issue-16-manifest-locale-invariance.sh | AC-C2-6-a: setup/gen-manifest-hashes.sh has no uncommitted modification | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-16-manifest-locale-invariance.sh | AC-C2-6-b: setup/manifest.json has no uncommitted modification | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-WF: .github/workflows/handoff-sequence.yml no longer exists | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-DISPATCH: docs/autoflow-guide.md has no 'subrepo-merged' token | 1 | registry:795-AC-DEL-DISPATCH-guide |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-DISPATCH: docs/external-review-sequencing.md has no 'subrepo-merged' token | 1 | registry:795-AC-DEL-DISPATCH-extrev |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-TOKEN: no live SUBREPO_READ_TOKEN reference under .github/ | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-TOKEN: no live SUBREPO_READ_TOKEN reference under scripts/ | 1 | disposition:76-RETAIN-GIT-PLUMBING |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-TOKEN: docs/external-review-sequencing.md drops SUBREPO_READ_TOKEN narration | 1 | registry:795-AC-DEL-TOKEN-extrev |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-TOKEN: docs/maintained-docs.md drops SUBREPO_READ_TOKEN narration | 1 | registry:795-AC-DEL-TOKEN-maintdocs |
| tests/test-issue-795-handoff-removal.sh | AC-DEL-TOKEN: tests/test-issue-495-token-scope.sh removed (subject deleted, feature T6) | 1 | disposition:76-RETAIN-FILE-EXISTENCE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: 'blocked-by-subrepo' preserved in docs/external-review-sequencing.md | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: 'blocked-by-subrepo' preserved in docs/git-workflow.md | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: 'blocked-by-subrepo' preserved in docs/autoflow-guide.md | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: create-host-pr.sh applies blocked-by-review label | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: create-host-pr.sh applies blocked-by-subrepo label by default | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: create-host-pr.sh --no-subrepo-dep guard unchanged | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: pointer==TARGET reconcile requirement present in docs/external-review-sequencing.md | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: pointer==TARGET reconcile requirement present in docs/submodule-common-rules.md | 1 | disposition:76-RETAIN-OUT-OF-MIGRATION-SCOPE |
| tests/test-issue-795-handoff-removal.sh | AC-KEEP-LABEL: git-workflow.md L120-157 (Merge Sequencing + Pointer reconciliation) has no diff hunk vs merge-base ($BASE_REF) | 1 | disposition:76-RETAIN-DELTA |
| tests/test-issue-795-handoff-removal.sh | AC-DANGLING-REF: no tests/ file (outside this suite) still references 'test-issue-495-token-scope' | 1 | disposition:76-RETAIN-GIT-PLUMBING |
<!-- REUSE-IgnoreEnd -->
