#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# tests/issue-92/test-pr-template.bats — AC1 (F1: .github/pull_request_template.md).
#
# T1-1: ≥ 6 checklist items in "## Sub-repo merge dependency" section.
# T1-2: <!-- HOST-CLOSE-LINE --> marker present exactly once.
# T1-3: no raw close-keyword (Closes|Fixes|Resolves) #N outside backticks /
#       code fences / HTML comments — delegated to
#       scripts/test/check-close-keyword-quoting.sh.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
TEMPLATE="${REPO_ROOT}/.github/pull_request_template.md"
CHECKER="${REPO_ROOT}/scripts/test/check-close-keyword-quoting.sh"

@test "T1-0: F1 .github/pull_request_template.md exists" {
  [ -f "$TEMPLATE" ]
}

@test "T1-1: '## Sub-repo merge dependency' section has >= 6 checklist items" {
  [ -f "$TEMPLATE" ]
  # Extract the section body: lines between the section heading and the next
  # `## ` heading (or EOF).
  body="$(awk '
    /^## Sub-repo merge dependency[[:space:]]*$/ { in_section = 1; next }
    /^## / { if (in_section) { in_section = 0 } }
    in_section { print }
  ' "$TEMPLATE")"

  count="$(printf '%s\n' "$body" | grep -cE '^- \[[ x]\]' || true)"
  [ "$count" -ge 6 ]
}

@test "T1-2: <!-- HOST-CLOSE-LINE --> marker is present exactly once" {
  [ -f "$TEMPLATE" ]
  count="$(grep -cF '<!-- HOST-CLOSE-LINE -->' "$TEMPLATE" || true)"
  [ "$count" -eq 1 ]
}

@test "T1-3: no raw close-keyword outside permitted zones (checker script)" {
  [ -f "$TEMPLATE" ]
  [ -x "$CHECKER" ]
  run "$CHECKER" "$TEMPLATE"
  [ "$status" -eq 0 ]
}
