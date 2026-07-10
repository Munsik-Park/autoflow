#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# tests/issue-92/test-create-host-pr.bats — AC2 (F3: scripts/handoff/create-host-pr.sh).
#
# T2-1: script is executable.
# T2-2: missing required args → exit 64.
# T2-3: missing body-file → exit 66.
# T2-4: default invocation includes `--draft` AND `--label blocked-by-subrepo`.
# T2-5: `--no-subrepo-dep` invocation includes `--draft` but omits `--label blocked-by-subrepo`.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
SCRIPT="${REPO_ROOT}/scripts/handoff/create-host-pr.sh"
MOCK_GH_DIR="${BATS_TEST_DIRNAME}/mock-gh"

setup() {
  TMPDIR_T="$(mktemp -d)"
  export GH_INVOCATION_LOG="$TMPDIR_T/gh.log"
  : > "$GH_INVOCATION_LOG"
  # Prepend the mock gh dir so the script picks up our shim instead of real gh.
  export PATH="$MOCK_GH_DIR:$PATH"
  # Body file fixture used by the success-path tests.
  BODY_FILE="$TMPDIR_T/body.md"
  printf '## Summary\n\ntest body\n' > "$BODY_FILE"
}

teardown() {
  rm -rf "$TMPDIR_T"
}

@test "T2-1: F3 scripts/handoff/create-host-pr.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "T2-2a: no args → exit 64" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT"
  [ "$status" -eq 64 ]
}

@test "T2-2b: missing --title and --body-file → exit 64" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92
  [ "$status" -eq 64 ]
}

@test "T2-2c: missing --body-file → exit 64" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test"
  [ "$status" -eq 64 ]
}

@test "T2-3: body-file path does not exist → exit 66" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test" --body-file "$TMPDIR_T/does-not-exist.md"
  [ "$status" -eq 66 ]
}

@test "T2-4a: default invocation passes --draft to gh" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test" --body-file "$BODY_FILE"
  [ "$status" -eq 0 ]
  grep -qFx -- "--draft" "$GH_INVOCATION_LOG"
}

@test "T2-4b: default invocation passes --label blocked-by-subrepo to gh" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test" --body-file "$BODY_FILE"
  [ "$status" -eq 0 ]
  # Look for either --label=blocked-by-subrepo (one-arg form) or
  # --label followed by blocked-by-subrepo (two-arg form).
  grep -qFx -- "--label" "$GH_INVOCATION_LOG" || grep -qFx -- "--label=blocked-by-subrepo" "$GH_INVOCATION_LOG"
  grep -qFx -- "blocked-by-subrepo" "$GH_INVOCATION_LOG" || grep -qFx -- "--label=blocked-by-subrepo" "$GH_INVOCATION_LOG"
}

@test "T2-4c: default invocation invokes gh pr create" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test" --body-file "$BODY_FILE"
  [ "$status" -eq 0 ]
  grep -qFx -- "pr" "$GH_INVOCATION_LOG"
  grep -qFx -- "create" "$GH_INVOCATION_LOG"
}

@test "T2-5a: --no-subrepo-dep invocation still passes --draft" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test" --body-file "$BODY_FILE" --no-subrepo-dep
  [ "$status" -eq 0 ]
  grep -qFx -- "--draft" "$GH_INVOCATION_LOG"
}

@test "T2-5b: --no-subrepo-dep invocation does NOT pass --label blocked-by-subrepo" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --issue 92 --title "test" --body-file "$BODY_FILE" --no-subrepo-dep
  [ "$status" -eq 0 ]
  ! grep -qFx -- "blocked-by-subrepo" "$GH_INVOCATION_LOG"
  ! grep -qFx -- "--label=blocked-by-subrepo" "$GH_INVOCATION_LOG"
}
