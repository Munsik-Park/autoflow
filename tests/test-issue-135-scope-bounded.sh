#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/review/scope-bounded.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: review-response scope judgment is a set relation (issue #135)
# =============================================================================
# scripts/review/scope-bounded.sh decides `scope-bounded` mechanically:
#   triage    Medium+ finding files ⊆ previous PR diff files, every Medium+ row names a file
#   check-fix the fix adds no file
# Asserted by execution over inline fixtures and a scratch git repo; no doc
# prose is pinned.
# =============================================================================

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SB="$PROJECT_ROOT/scripts/review/scope-bounded.sh"
PASS=0; FAIL=0
assert_eq() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi; }

T=$(mktemp -d)
printf 'scripts/a.sh\ndocs/x.md\ntests/t.sh\n' > "$T/diff.txt"

mk() { # <name> <table rows...>
  local f="$T/$1.md"; shift
  { echo "## Findings"; echo; echo "| Severity | File:line | Claim | Evidence | Confidence |"; echo "|---|---|---|---|---|"; printf '%s\n' "$@"; } > "$f"; echo "$f"
}

echo "=== triage ==="
F=$(mk inside '| Medium | `scripts/a.sh:12` | c | e | High |' '| Low | `other/z.sh:1` | low row ignored | e | High |')
out=$(bash "$SB" triage --findings "$F" --diff-files "$T/diff.txt"); rc=$?
assert_eq "subset → bounded (exit 0)" "0" "$rc"
assert_eq "subset → scope-bounded: true" "scope-bounded: true" "$(printf '%s\n' "$out" | sed -n 1p)"
assert_eq "Low rows do not enter the finding set" "scope-bounded-finding-files: scripts/a.sh" "$(printf '%s\n' "$out" | sed -n 2p)"

F=$(mk outside '| Medium | `scripts/a.sh:12` | c | e | High |' '| High | `scripts/new.sh:3` | c | e | High |')
out=$(bash "$SB" triage --findings "$F" --diff-files "$T/diff.txt"); rc=$?
assert_eq "file outside diff → not bounded (exit 1)" "1" "$rc"
assert_eq "outside file named in grounds" "1" "$(printf '%s\n' "$out" | grep -c 'outside the previous PR diff: scripts/new.sh')"

F=$(mk nofile '| Medium | — | no location | e | High |')
out=$(bash "$SB" triage --findings "$F" --diff-files "$T/diff.txt"); rc=$?
assert_eq "Medium+ row without a file → not bounded (fail closed)" "1" "$rc"
assert_eq "grounds say not evaluable" "1" "$(printf '%s\n' "$out" | grep -c 'not evaluable')"

F=$(mk lowonly '| Low | `scripts/a.sh:1` | c | e | High |')
out=$(bash "$SB" triage --findings "$F" --diff-files "$T/diff.txt"); rc=$?
assert_eq "no Medium+ row → not bounded" "1" "$rc"

# rows under a superseded/historical heading are ignored
{ echo "## Findings"; echo; echo "| Severity | File:line | Claim | Evidence | Confidence |"; echo "|---|---|---|---|---|"; echo '| Medium | `docs/x.md:2` | c | e | High |'; echo; echo "## Cycle-1 finding (historical, superseded by above)"; echo '| Medium | `elsewhere/old.sh:9` | old | e | High |'; } > "$T/hist.md"
out=$(bash "$SB" triage --findings "$T/hist.md" --diff-files "$T/diff.txt"); rc=$?
assert_eq "historical rows ignored → bounded" "0" "$rc"

assert_eq "usage: missing --findings → exit 2" "2" "$(bash "$SB" triage --diff-files "$T/diff.txt" >/dev/null 2>&1; echo $?)"
assert_eq "usage: unknown subcommand → exit 2" "2" "$(bash "$SB" nope >/dev/null 2>&1; echo $?)"

echo "=== check-fix ==="
R=$(mktemp -d); git -C "$R" init -q; git -C "$R" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
echo a > "$R/a.sh"; git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -q -m a
echo b >> "$R/a.sh"; git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -q -m edit
out=$(cd "$R" && bash "$SB" check-fix --base HEAD~1 --head HEAD); rc=$?
assert_eq "edit-only fix → bounded holds (exit 0)" "0" "$rc"
assert_eq "fix true line" "scope-bounded-fix: true" "$(printf '%s\n' "$out" | sed -n 1p)"
echo n > "$R/new.sh"; git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -q -m add
out=$(cd "$R" && bash "$SB" check-fix --base HEAD~2 --head HEAD); rc=$?
assert_eq "fix adds a file → leaves the bounded path (exit 1)" "1" "$rc"
assert_eq "added file named" "1" "$(printf '%s\n' "$out" | grep -c 'new mechanism): new.sh')"
assert_eq "usage: check-fix without --head → exit 2" "2" "$(cd "$R" && bash "$SB" check-fix --base HEAD >/dev/null 2>&1; echo $?)"

rm -rf "$T" "$R"
echo; echo "Tests: $PASS passed, $FAIL failed"; [[ $FAIL -eq 0 ]]
