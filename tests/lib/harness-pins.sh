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
# Measurement history: 37 -> 58 -> 80 (#67) -> 82 (#69) -> 85 (#97) -> 97 (#123).
# The #123 bump is the RED-commit target value (12 new cap-round-closing cases:
# AC1, AC2, AC3 x3, AC4, AC5, AC6, AC10, AC11, AC12, AC13), not the RED-commit
# measured value -- 8 of the 12 are discriminating and FAIL until the closing
# half-round lands, so the composition oracle (tests/test-issue-27-composition-
# oracle.sh) intentionally reds against this pin until GREEN, per
# .autoflow/issue-123-verification-design.md > Composition oracle.
# =============================================================================

# Expected `ok` line count from `node test/workflows/run.mjs`.
HARNESS_OK_COUNT=97
