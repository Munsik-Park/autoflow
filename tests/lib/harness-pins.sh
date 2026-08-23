#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# harness-pins.sh — the single committed home of the shared workflow-harness
# ok-count pin. Sourced, never executed.
# =============================================================================
# The pin exists so that a harness test which silently stops running turns a
# green run red. It is therefore a COMMITTED LITERAL, deliberately not a value
# regenerated from the harness at evaluation time: a regenerated value always
# agrees with itself and detects nothing.
#
# Before this file the same integer was authored in two live homes
# (tests/test-issue-27-composition-oracle.sh and
# tests/test-issue-59-adoption-evidence-discipline.sh) plus a cross-pin
# agreement check that compared them by grep. A harness change needed a
# synchronised multi-file bump, and the agreement machinery existed only to
# police that synchronisation. With one home there is nothing to agree: a real
# harness change is one deliberate edit on the line below.
#
# HOW TO BUMP: run `node test/workflows/run.mjs`, count its `ok` lines, and set
# the constant to the measured value in the same commit as the harness change
# that moved it — the precedent tests/test-issue-27-composition-oracle.sh's
# header records for every prior bump.
#
# Measurement history: 37 -> 58 -> 80 (#67) -> 82 (#69) -> 85 (#97) -> 97 (#123)
# -> 122 (#127) -> 126 (#127 cycle 2) -> 135 (#127 cycle 3) -> 150 (#138) -> 156
# (#138, VERIFY-step-3 legs) -> 157 (#138, RED3 -- O5(c) empty-ac_rows fail-closed
# leg; TARGET value, RED3 itself MEASURES 156 ok + 1 FAIL) -> 164 (#138 cycle 2,
# RED c2 -- codex F1 item-level ac-diff validation; TARGET value, RED c2 itself
# MEASURES 156 ok + 8 FAIL: 7 new legs (row-nonboolean-method-executable,
# row-nonboolean-carried, row-out-of-enum-disposition, row-missing-ac,
# nonobject-row-fails-closed, substitution-item-fails-closed,
# absent-with-carried-true-fails-closed) plus the pre-existing leg
# ac-diff-schema-shape, which now carries one added assertion pinning that the
# guard reads AC_ROW.properties.disposition.enum and fails closed for lack of
# the guard itself. `node test/workflows/run.mjs` measures 156 ok + 8 FAIL
# against the as-is script; 164 is the GREEN target once the row/substitution
# guard ships.
# The #123, #127 and #127-cycle-2/3 bumps are all the RED-commit TARGET value, not the
# RED-commit MEASURED value: #123 added 12 cap-round-closing cases (8 discriminating),
# #127 adds 25 resume cases (23 discriminating, 2 deliberate regression locks documented
# inline in test/workflows/run.mjs -- see "AC127-15" and "AC127-18" -- that pass
# vacuously at RED because the AS-IS script touches no filesystem and names no
# state-file path at all). #127 cycle 2 adds 4 new discriminating cases (terminal
# post-verdict call rejection absorption: write-reject-absorbed, write-sync-throw-
# absorbed, ledger-reject-absorbed, stale-register-untouched) -- all 4 propagate at
# HEAD (bare `await agent(...)`, no absorption wrapper) and were the RED failures that
# commit recorded (122 ok + 4 FAIL -> 126). #127 cycle 3 adds 9 new cases for the
# resume-scoped open-entry precondition on CONVERGED, of which 7 are DISCRIMINATING at
# RED (they FAIL against the AS-IS script, which converges unconditionally on mutual
# grounded ACCEPT and cannot yet produce ESCALATE/the sentinel/the persisted-open-entry
# state) -- open-entry-blocks-converge, peer-disposition-does-not-unblock,
# sentinel-on-the-denied-run, terminal-turn-decides-the-reason, infrastructure-outranks-
# the-sentinel, closing-half-round-honors-precondition, open-entry-survives-into-
# persisted-register -- and 2 are ADMISSION rows that already PASS at RED because their
# shape already converges under the AS-IS script -- disposed-entry-permits-converge,
# resume-amendment-closable-by-closing-turn -- per the verification design, these two
# discriminate only a WRONG fix once GREEN ships one (a guard ordered before the
# round's own dispositions, or a closing turn excluded from disposal), not the absence
# of any guard, so a vacuous PASS at RED is the correct and expected reading for them,
# not a coverage gap. Cycle 3 also amends 7 existing resume cases' responder fixtures
# (adding a disposition, no assertion changed) so they keep passing once the
# precondition ships -- resume-lifts-first-exchange, resume-persists-both-verdicts,
# return-contract-fields, closing-prompt-coherent-cap, rehydration-fallback,
# write-reject-absorbed, ledger-reject-absorbed. The 7 amended cases pass at HEAD both
# before and after their fixture amendment (the AS-IS script never reads register
# status), so they contribute no FAIL at RED. RED (d84881b) MEASURES 128 ok (126
# pre-existing cases, including the 7 amended ones, plus the 2 new admission-pass
# cases) + 7 FAIL (the 7 new discriminating cases) -- see
# .autoflow/issue-127-c3-red-report.md. Target after GREEN (all 135 pass): 135. The
# composition oracle (tests/test-issue-27-composition-oracle.sh) intentionally reds
# against this pin until GREEN, per
# .autoflow/issue-127-verification-design.md > Composition oracle.
# #138 adds 15 AC-authority reconciliation cases (Reconcile phase / AC_CHANGE
# verdict / fail-closed sentinels / register minting / ledger branch), all 15
# DISCRIMINATING at RED -- the AS-IS script has no Reconcile phase and calls no
# 'ac-diff' sub-agent, so RED (d474cd7) MEASURES 135 ok + 15 FAIL. 150 is therefore
# the GREEN TARGET value, in the #123/#127 discipline. NOTE (GREEN, #138): GREEN
# (b1fcf63) measured 122 ok + 28 FAIL -- 28 pre-existing converging cases whose
# responders did not answer the new 'ac-diff' label fell into the DELIBERATELY
# fail-closed AC_CHANGE path, the same fixture-amendment class #127 cycle 3
# recorded above for its 7 amended resume cases. RESOLVED (RED2b, 525c3f3): the
# 28 responders (via the shared capResponder/resumeResponder factories plus 14
# inline responders) now answer 'ac-diff' with
# { ac_source_present: true, ac_rows: [], ledger_ac_decisions: [], substituted: [] }
# -- the shape the #138 ac-diff-plumbing leg proves yields CONVERGED with no
# findings. No #138 fail-closed leg was touched. `node test/workflows/run.mjs`
# now measures all 150 ok, matching the pin below.
# NOTE (VERIFY step 3, #138): the orchestrator's minimal-implementation check
# (.autoflow/issue-138-verify-report.md, tree d5600bd) found 8 implementation
# hunks in architect-deliberation.js uncovered by any #138 leg. Hunks 1
# (meta.phases metadata) and 8 (acChangeGrounds's structurally-unreachable
# no-open-entries fallback) are accepted exceptions. Hunks 2-7 (AC_ROW/
# AC_SUBSTITUTION/AC_DIFF schema shape, the per-finding ac-authority:<ac id>
# minted name, the AC_CHANGE result.summary text, resuming from a persisted
# AC_CHANGE register, acDiffWellFormed's non-null-malformed-payload guard,
# mintAcEntry's upsert branch) each get a new leg here, all PASSING
# immediately against the existing GREEN implementation (the "add a test"
# branch of the check, not a defect). `node test/workflows/run.mjs` now
# measures all 156 ok, matching the pin below.
# =============================================================================

# Expected `ok` line count from `node test/workflows/run.mjs`.
HARNESS_OK_COUNT=164
