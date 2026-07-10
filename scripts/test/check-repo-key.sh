#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/test/check-repo-key.sh
#
# Regression test for issue #978 AC-2 / cycle-2 (#978 review-response, Codex
# Finding 1 on PR #980) — repo-key derivation. Drives the in-script pure
# `derive_repo_key <url>` function through the bounded introspection
# subcommand `cleanup-issue.sh --print-repo-key [<url>|--no-origin]` (no
# separate scripts/cleanup/repo-key.sh lib — one caller, verification design
# counter #1 / feature §7-rej-2).
#
#   C2-AC-1 / C2-AC-2 (table-driven, hermetic) — the FULL per-scheme
#     cross-product {scp-form, https-form, ssh-scheme-form} x {.git: absent,
#     present} x {trailing-/: absent, present} = 12 labelled cells, each
#     normalizing to Munsik-Park__autoflow. This REPLACES the prior
#     4-row table (the 4 prior inputs are a strict subset, retained as
#     labelled cells within the 12 — verification design C2-AC-2 / R3,
#     replace-with-labelled-grid); the two Codex-named ".git/"-suffixed
#     cases (https-form + scp-form) are the C2-AC-1 labelled cells. No
#     throwaway `git init` repo, no network for this part.
#   C2-AC-3 (stacked/repeated-suffix closure) — 4 witnesses
#     (".git//", ".git/.git", ".git/.git/", "//") stacking trailing "/" and
#     ".git" beyond a single suffix; each must still fold to
#     Munsik-Park__autoflow (never a malformed empty-org/empty-repo
#     key). This is an input-enumeration closure, NOT self-composition
#     idempotency — `f(f(x)) == f(x)` is invalid for this URL-to-key
#     function (ledger E22 / verification design R2) and is never asserted
#     here.
#   C2-AC-5 (--no-origin fallback) — the path-encoded slug of $ROOT, computed
#     at RUNTIME from `git rev-parse --show-toplevel` (never hardcoded —
#     avoids a macOS /var vs /private/var mismatch).
#   C2-AC-5 (no-arg live-remote consistency) — `--print-repo-key` with no
#     argument reads the CWD repo's live `origin` remote and must equal
#     driving that same URL through the explicit <url> form.
#   Request #1 hoist (CWD-independence, C2-AC-5 non-regression) —
#     `--print-repo-key` must emit the key and exit 0 even when invoked from
#     a git repo whose $ROOT has no `.autoflow/` directory at all (parsed
#     ABOVE the `[ ! -d "$AUTOFLOW_DIR" ]` existence gate, not merely before
#     the digits loop). This ONE sub-case uses a throwaway `git init` repo
#     because it is the only way to construct a repo root that genuinely
#     lacks `.autoflow/` — a different property than the hermetic
#     URL-normalization table above, which the verification design's "no
#     throwaway repo" note was scoped to.
#   C2-AC-8 (reachability guard, hermetic, fix-independent) — a throwaway
#     `git init` repo round-trips each C2-AC-3 suffix-noise URL through
#     `git remote add` -> `git remote get-url origin` byte-for-byte, proving
#     the stacked shapes are production-reachable (git does not normalize
#     them on storage), not synthetic-only. This block exercises git's own
#     storage, not `derive_repo_key` — it is GREEN on both the pre-fix
#     baseline and post-fix (ledger E27) and is excluded from the RED
#     failure set.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLEAN="$ROOT/scripts/cleanup/cleanup-issue.sh"

PASS=0; FAIL=0; TESTS=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TESTS=$((TESTS + 1))
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit0() {
  local desc="$1" actual_exit="$2"
  TESTS=$((TESTS + 1))
  if [ "$actual_exit" = "0" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit 0, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

assert_nonempty() {
  local desc="$1" actual="$2"
  TESTS=$((TESTS + 1))
  if [ -n "$actual" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (got empty output)"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
echo "=== C2-AC-1/C2-AC-2: repo-key derivation — 12-cell crossed URL grid ==="
# ---------------------------------------------------------------------------
# REPLACES the prior 4-row table (verification design C2-AC-2 / R3): the full
# per-scheme cross-product {scp-form, https-form, ssh-scheme-form} x
# {.git: absent, present} x {trailing-/: absent, present} = 12 labelled
# cells. The 4 prior inputs are a strict subset, retained here as labelled
# cells (scp-form .git/no-slash, https-form .git/no-slash,
# ssh-scheme-form .git/no-slash, https-form no-.git/trailing-slash) so
# C2-AC-5 non-regression is preserved. The two ".git + trailing-/" cells for
# scp-form and https-form are the C2-AC-1 Codex Finding 1 named cases; the
# ssh-scheme-form ".git + trailing-/" cell is the systematic 3rd analog the
# crossing adds. Expanded literal heredoc (NOT a for-loop generator) so
# every crossed cell stays greppable (C2-AC-4 header self-check).
EXPECTED_KEY="Munsik-Park__autoflow"

run_print_repo_key() {   # run_print_repo_key <args...> -> sets RPK_OUT / RPK_RC
  RPK_OUT="$("$CLEAN" --print-repo-key "$@" 2>/dev/null)"
  RPK_RC=$?
}

while IFS='|' read -r label url; do
  [ -n "$label" ] || continue
  run_print_repo_key "$url"
  assert_exit0 "print-repo-key exits 0 for $label" "$RPK_RC"
  assert_eq    "print-repo-key($label) == $EXPECTED_KEY" "$EXPECTED_KEY" "$RPK_OUT"
done <<'TABLE'
scp-form (no .git, no trailing-/)|git@github.com:Munsik-Park/autoflow
scp-form (no .git, trailing-/)|git@github.com:Munsik-Park/autoflow/
scp-form (.git, no trailing-/)|git@github.com:Munsik-Park/autoflow.git
scp-form (.git, trailing-/ — Codex Finding 1)|git@github.com:Munsik-Park/autoflow.git/
https-form (no .git, no trailing-/)|https://github.com/Munsik-Park/autoflow
https-form (no .git, trailing-/)|https://github.com/Munsik-Park/autoflow/
https-form (.git, no trailing-/)|https://github.com/Munsik-Park/autoflow.git
https-form (.git, trailing-/ — Codex Finding 1)|https://github.com/Munsik-Park/autoflow.git/
ssh-scheme-form (no .git, no trailing-/)|ssh://git@github.com/Munsik-Park/autoflow
ssh-scheme-form (no .git, trailing-/)|ssh://git@github.com/Munsik-Park/autoflow/
ssh-scheme-form (.git, no trailing-/)|ssh://git@github.com/Munsik-Park/autoflow.git
ssh-scheme-form (.git, trailing-/)|ssh://git@github.com/Munsik-Park/autoflow.git/
TABLE

# ---------------------------------------------------------------------------
echo ""
echo "=== C2-AC-3: stacked/repeated-suffix closure (fixpoint-only, distinguishes B from A) ==="
# ---------------------------------------------------------------------------
# Input-enumeration closure (NOT self-composition idempotency — f(f(x)) ==
# f(x) is invalid for this URL-to-key function, ledger E22 / verification
# design R2, and is never asserted). Each witness stacks trailing "/" and
# ".git" beyond a single suffix and must still fold to EXPECTED_KEY. Under
# the current single-pass, fixed-order strip these are malformed
# (empty-org/empty-repo) keys, not merely ".git"-retaining ones — see the
# per-row FAIL messages this suite prints on baseline `a4ccfcf`.
while IFS='|' read -r label url; do
  [ -n "$label" ] || continue
  run_print_repo_key "$url"
  assert_exit0 "print-repo-key exits 0 for $label" "$RPK_RC"
  assert_eq    "print-repo-key($label) == $EXPECTED_KEY" "$EXPECTED_KEY" "$RPK_OUT"
done <<'TABLE'
stacked-suffix (.git//)|https://github.com/Munsik-Park/autoflow.git//
stacked-suffix (.git/.git)|https://github.com/Munsik-Park/autoflow.git/.git
stacked-suffix (.git/.git/)|https://github.com/Munsik-Park/autoflow.git/.git/
stacked-suffix (// double trailing slash)|https://github.com/Munsik-Park/autoflow//
TABLE

# ---------------------------------------------------------------------------
echo ""
echo "=== C2-AC-8: reachability guard (hermetic, fix-independent) ==="
# ---------------------------------------------------------------------------
# Grounds R1 (adopt fixpoint loop-B over reorder-A): the suffix-noise URLs
# above must be PRODUCTION-REACHABLE, i.e. git stores and returns them
# unmodified on a live origin, not synthetic-only. This block exercises
# git's own remote-URL storage via a throwaway `git init` repo — it does
# NOT call derive_repo_key — so it is GREEN on both the pre-fix baseline and
# post-fix (ledger E27) and must not be counted toward the RED failure set.
# SKIP (not FAIL) if a throwaway git repo cannot be constructed, mirroring
# the Request #1 CWD-hoist SKIP posture below.
# NOTE: cleaned up deterministically at the end of this block (not via an
# EXIT trap) because the Request #1 hoist section below registers its own
# `trap teardown_noaf EXIT` for its own throwaway repo — a second `trap …
# EXIT` call would silently replace this one, since only one EXIT trap can
# be active at a time; an immediate rm -rf avoids that clobber entirely.
RKREACH_REPO="$(mktemp -d)"

(cd "$RKREACH_REPO" && git init -q) >/dev/null 2>&1

if [ -d "$RKREACH_REPO/.git" ]; then
  while IFS='|' read -r label url; do
    [ -n "$label" ] || continue
    (cd "$RKREACH_REPO" && git remote add origin "$url") >/dev/null 2>&1
    RT_OUT="$(cd "$RKREACH_REPO" && git remote get-url origin 2>/dev/null)"
    assert_eq "reachability round-trip ($label): get-url origin == input byte-for-byte" \
      "$url" "$RT_OUT"
    (cd "$RKREACH_REPO" && git remote remove origin) >/dev/null 2>&1
  done <<'TABLE'
reachability (.git/)|https://github.com/Munsik-Park/autoflow.git/
reachability (.git//)|https://github.com/Munsik-Park/autoflow.git//
reachability (.git/.git)|https://github.com/Munsik-Park/autoflow.git/.git
reachability (.git/.git/)|https://github.com/Munsik-Park/autoflow.git/.git/
reachability (// double trailing slash)|https://github.com/Munsik-Park/autoflow//
TABLE
else
  echo "  SKIP: C2-AC-8 reachability guard (throwaway git init repo could not be created)"
fi
rm -rf "$RKREACH_REPO"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-2: --no-origin fallback (runtime-computed, never hardcoded) ==="
# ---------------------------------------------------------------------------
EXPECTED_FALLBACK="$(printf '%s' "$ROOT" | LC_ALL=C sed 's/[^A-Za-z0-9._-]/-/g')"
run_print_repo_key --no-origin
assert_exit0 "print-repo-key --no-origin exits 0" "$RPK_RC"
assert_eq    "print-repo-key --no-origin == runtime path-fallback slug of \$ROOT" \
  "$EXPECTED_FALLBACK" "$RPK_OUT"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-2: no-arg live-remote consistency oracle ==="
# ---------------------------------------------------------------------------
LIVE_URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
if [ -n "$LIVE_URL" ]; then
  run_print_repo_key
  NOARG_OUT="$RPK_OUT"; NOARG_RC=$RPK_RC
  run_print_repo_key "$LIVE_URL"
  URL_OUT="$RPK_OUT"; URL_RC=$RPK_RC

  assert_exit0  "no-arg print-repo-key exits 0" "$NOARG_RC"
  assert_exit0  "explicit-URL print-repo-key exits 0" "$URL_RC"
  assert_nonempty "no-arg print-repo-key produces non-empty output" "$NOARG_OUT"
  # Guard against a vacuous "" == "" pass: only compare when at least one
  # side is non-empty (both empty means the property is untested, not met).
  if [ -n "$NOARG_OUT" ] || [ -n "$URL_OUT" ]; then
    assert_eq "no-arg print-repo-key == print-repo-key \"\$(git remote get-url origin)\"" \
      "$URL_OUT" "$NOARG_OUT"
  else
    TESTS=$((TESTS + 1))
    echo "  FAIL: no-arg print-repo-key == print-repo-key \"\$(git remote get-url origin)\" (both sides empty — property untested)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  SKIP: no-arg live-remote consistency (no 'origin' remote configured)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== AUDIT r1: embedded-newline origin URL — single-line sanitized key ==="
# ---------------------------------------------------------------------------
# AUDIT round-1 finding (.autoflow/issue-978-audit.md / ledger E15): git
# stores and returns a raw newline inside a remote URL (verified via
# `git config`), and derive_repo_key's per-line `sed` never sees the
# newline as data — it survives into the emitted key, splitting it across
# two lines (a control character in a value consumed as a single path
# component). Contract: the emitted key is exactly ONE line composed only
# of slug-alphabet bytes [A-Za-z0-9._-]. NOTE the no-control-chars oracle
# is byte-level (tr -d of the allowed alphabet), NOT grep '[[:cntrl:]]' —
# grep is line-based too and cannot see a newline as content.
NL_URL="$(printf 'https://github.com/Munsik-Park/auto\nflow.git')"
NL_OUT="$("$CLEAN" --print-repo-key "$NL_URL" 2>/dev/null)"
NL_RC=$?

assert_exit0 "AUDIT-nl: print-repo-key exits 0 for an embedded-newline URL" "$NL_RC"

TESTS=$((TESTS + 1))
NL_LINES="$(printf '%s\n' "$NL_OUT" | wc -l | tr -d ' ')"
if [ "$NL_LINES" = "1" ]; then
  echo "  PASS: AUDIT-nl: emitted key is exactly ONE line"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AUDIT-nl: emitted key is exactly ONE line (got $NL_LINES lines)"
  FAIL=$((FAIL + 1))
fi

TESTS=$((TESTS + 1))
NL_RESIDUE="$(printf '%s' "$NL_OUT" | LC_ALL=C tr -d 'A-Za-z0-9._-' | wc -c | tr -d ' ')"
if [ "$NL_RESIDUE" = "0" ]; then
  echo "  PASS: AUDIT-nl: emitted key contains only slug-alphabet bytes (no control characters)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AUDIT-nl: emitted key contains only slug-alphabet bytes (found $NL_RESIDUE disallowed byte(s))"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Request #1 hoist: CWD-independence (--print-repo-key exit-0 contract) ==="
# ---------------------------------------------------------------------------
# The ONLY way to construct a repo root genuinely lacking .autoflow/ is a
# throwaway repo (see file header) — this is a parse-ordering property, not
# the URL-normalization hermeticity the design's "no throwaway git init repo"
# note applies to.
NOAF_REPO="$(mktemp -d)"
teardown_noaf() { rm -rf "$NOAF_REPO"; }
trap teardown_noaf EXIT

(cd "$NOAF_REPO" && git init -q) >/dev/null 2>&1

if [ -d "$NOAF_REPO/.git" ]; then
  NOAF_ROOT="$(git -C "$NOAF_REPO" rev-parse --show-toplevel)"
  EXPECTED_NOAF_FALLBACK="$(printf '%s' "$NOAF_ROOT" | LC_ALL=C sed 's/[^A-Za-z0-9._-]/-/g')"

  NOAF_OUT="$(cd "$NOAF_REPO" && "$CLEAN" --print-repo-key --no-origin 2>/dev/null)"
  NOAF_RC=$?

  TESTS=$((TESTS + 1))
  if [ "$NOAF_RC" = "0" ]; then
    echo "  PASS: --print-repo-key exits 0 from a repo root with no .autoflow/ dir"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: --print-repo-key exits 0 from a repo root with no .autoflow/ dir (got exit $NOAF_RC)"
    FAIL=$((FAIL + 1))
  fi
  assert_eq "--print-repo-key --no-origin (no .autoflow/) == runtime path-fallback slug of that repo root" \
    "$EXPECTED_NOAF_FALLBACK" "$NOAF_OUT"
  # Must NOT have printed the "nothing to clean/archive" no-op line instead of the key.
  TESTS=$((TESTS + 1))
  case "$NOAF_OUT" in
    *"nothing to"*)
      echo "  FAIL: output is the no-.autoflow-dir no-op message, not the repo-key (existence gate not hoisted)"
      FAIL=$((FAIL + 1))
      ;;
    *)
      echo "  PASS: output is not the no-.autoflow-dir no-op message"
      PASS=$((PASS + 1))
      ;;
  esac
else
  echo "  SKIP: CWD-independence check (throwaway git init repo could not be created)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-CI-REGISTER (guard) — suite wired into e2e-dummy-target.yml ==="
# ---------------------------------------------------------------------------
CI_WORKFLOW="$ROOT/.github/workflows/e2e-dummy-target.yml"
if [ -f "$CI_WORKFLOW" ]; then
  TESTS=$((TESTS + 1))
  if grep -q 'check-repo-key' "$CI_WORKFLOW"; then
    echo "  PASS: AC-CI-a: e2e-dummy-target.yml references check-repo-key.sh"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: AC-CI-a: e2e-dummy-target.yml references check-repo-key.sh"
    FAIL=$((FAIL + 1))
  fi

  CTX_B="$(grep -B80 'check-repo-key' "$CI_WORKFLOW" | head -80)"
  TESTS=$((TESTS + 1))
  if printf '%s\n' "$CTX_B" | grep -q '^ *paths:'; then
    echo "  PASS: AC-CI-b: reference appears in a 'paths:' trigger block"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: AC-CI-b: reference appears in a 'paths:' trigger block"
    FAIL=$((FAIL + 1))
  fi

  CTX_C="$(grep -A2 'check-repo-key' "$CI_WORKFLOW")"
  TESTS=$((TESTS + 1))
  if printf '%s\n' "$CTX_C" | grep -q 'run: bash scripts/test/check-repo-key.sh'; then
    echo "  PASS: AC-CI-c: reference appears in a 'run:' step"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: AC-CI-c: reference appears in a 'run:' step"
    FAIL=$((FAIL + 1))
  fi
else
  TESTS=$((TESTS + 3))
  FAIL=$((FAIL + 3))
  echo "  FAIL: AC-CI-a/b/c: $CI_WORKFLOW missing"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[ "$FAIL" -gt 0 ] && exit 1
exit 0
