#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# tests/issue-92/test-cross-file-consistency.bats — AC10 token consistency.
#
# Issue #795 (ADR-0015 D3): the `subrepo-merged` repository_dispatch
# status-check machinery was physically removed (advisory-only signal, never an
# enforceable required check). This suite is INVERTED from "`subrepo-merged`
# appears in every expected file" to "`subrepo-merged` is gone from the surgery
# surface", and the surviving cross-file token whose consistency now matters is
# `blocked-by-subrepo` — the operator merge-order label gate that #795 preserves.
#
# SCOPE NOTE: docs/git-workflow.md is EXCLUDED from the absence assertions — its
# `subrepo-merged` occurrences sit inside the #794-frozen L120-157 reconcile
# block that #795 does not edit (deferred to S11b/#799).

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."

@test "T10-1a: handoff-sequence.yml workflow no longer exists" {
  [ ! -f "$REPO_ROOT/.github/workflows/handoff-sequence.yml" ]
}

@test "T10-1b: subrepo-merged is absent from docs/autoflow-guide.md" {
  [ -f "$REPO_ROOT/docs/autoflow-guide.md" ]
  ! grep -qF 'subrepo-merged' "$REPO_ROOT/docs/autoflow-guide.md"
}

@test "T10-1c: subrepo-merged is absent from docs/external-review-sequencing.md" {
  [ -f "$REPO_ROOT/docs/external-review-sequencing.md" ]
  ! grep -qF 'subrepo-merged' "$REPO_ROOT/docs/external-review-sequencing.md"
}

@test "T10-1d: subrepo-merged is absent from the host PR helper + template + registry" {
  for f in \
    "$REPO_ROOT/scripts/handoff/create-host-pr.sh" \
    "$REPO_ROOT/.github/pull_request_template.md" \
    "$REPO_ROOT/docs/maintained-docs.md"; do
    [ -f "$f" ]
    ! grep -qF 'subrepo-merged' "$f"
  done
}

@test "T10-2: blocked-by-subrepo merge-order gate is consistently present" {
  # The surviving cross-file token: the operator label gate must remain
  # described in the reviewer guide, applied by the host PR helper, and tracked
  # in the PR template checklist. Non-vacuous: each path currently carries it.
  REQUIRED_PATHS=(
    "$REPO_ROOT/docs/external-review-sequencing.md"
    "$REPO_ROOT/scripts/handoff/create-host-pr.sh"
    "$REPO_ROOT/.github/pull_request_template.md"
  )
  for p in "${REQUIRED_PATHS[@]}"; do
    [ -f "$p" ]
    grep -qF 'blocked-by-subrepo' "$p"
  done
}
