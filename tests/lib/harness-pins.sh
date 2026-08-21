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
# -> 122 (#127) -> 126 (#127 cycle 2).
# The #123, #127 and #127-cycle-2 bumps are all the RED-commit TARGET value, not the
# RED-commit MEASURED value: #123 added 12 cap-round-closing cases (8 discriminating),
# #127 adds 25 resume cases (23 discriminating, 2 deliberate regression locks documented
# inline in test/workflows/run.mjs -- see "AC127-15" and "AC127-18" -- that pass
# vacuously at RED because the AS-IS script touches no filesystem and names no
# state-file path at all). #127 cycle 2 adds 4 new discriminating cases (terminal
# post-verdict call rejection absorption: write-reject-absorbed, write-sync-throw-
# absorbed, ledger-reject-absorbed, stale-register-untouched) -- all 4 propagate at
# HEAD (bare `await agent(...)`, no absorption wrapper) and are the RED failures this
# commit records. Measured at RED: 122 ok (the full pre-existing set, unchanged) + 4
# FAIL. Target after GREEN: 126. The composition oracle
# (tests/test-issue-27-composition-oracle.sh) intentionally reds against this pin
# until GREEN, per .autoflow/issue-127-verification-design.md > Composition oracle.
# =============================================================================

# Expected `ok` line count from `node test/workflows/run.mjs`.
HARNESS_OK_COUNT=126
