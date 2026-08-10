#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-suite-ci-coverage.sh — standing lint: every executable spec under
# tests/** has an execution path.
# =============================================================================
# Registering the named orphan suites empties the orphan set once; nothing
# stops the next cycle from landing a suite nothing runs. This lint makes the
# CLASS unrepresentable rather than the instances empty.
#
# SUBJECT SET — enumerate, then subtract. The set is EVERYTHING under tests/**
# that is an executable spec (`*.sh` plus `*.bats`), minus the named exclusions
# below. The direction matters: an admitting glob (`tests/test-*.sh`,
# `tests/adr-*.sh`, …) leaves every other filename shape silently outside the
# lint, which is the orphan class this exists to remove. `*.bats` stays IN, so
# that after this cycle's tests/issue-92 deletion a newly added `.bats` file is
# flagged rather than ignored — `bats` is unavailable in CI by design, so such
# a file has no execution path and must be disposed of, not merged.
#
# There is NO exemption list for unreachable suites: an allow-list here would be
# the hand-maintained inventory `docs/doc-invariant-registry.md` §1-2 retires.
# An unreachable suite is either wired or deleted with a disposition row.
#
# REACHABLE — a `run:` step in any workflow invokes it, or a reachable suite
# invokes it as a subprocess (transitive closure over `bash <path>`), which is
# the mechanism that makes tests/test-issue-40-hook-additive.sh reachable
# through tests/test-issue-71-digest-removal.sh.
#
# Usage:
#   bash scripts/test/check-suite-ci-coverage.sh [--self-test] [--root <dir>]
#
# The default run performs the self-test FIRST, then reports the real-tree
# result — the precedent scripts/test/check-cycle-scope-guard.sh sets. Against
# the live tree an exit 0 is unfalsifiable once the orphan set is empty, so the
# self-test's two legs are what keep it from being vacuous: the CLOSURE leg
# drives a fixture tree holding a known-unreachable suite, and the EXCLUSION leg
# asserts the subtraction positively — without it the lint is satisfiable by
# broadening the exclusions until the subject set is empty.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODE="default"
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --root)      ROOT="${2:-}"; shift ;;
    *)           echo "check-suite-ci-coverage: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# ---------------------------------------------------------------------------
# is_excluded <repo-relative path>
# Each exclusion carries its reason here, in the lint, rather than being
# inherited from a naming glob — so the intent survives a rename.
# ---------------------------------------------------------------------------
is_excluded() {
  case "$1" in
    # Sourced libraries, not standalone specs: they have no independent exit
    # status to register.
    tests/lib/*.sh) return 0 ;;
    # The registry runner, not a spec. It is CI-registered anyway, so this
    # changes no verdict today; it is stated so the set is a decision rather
    # than a coincidence.
    tests/run-doc-invariants.sh) return 0 ;;
    # A VERIFY-time driver, deliberately not CI-registered: its own header
    # records that its filename deliberately does not match the suite glob and
    # gives the two measured reasons.
    tests/issue-59-full-sweep-driver.sh) return 0 ;;
  esac
  return 1
}

# subject_set <root> — every executable spec under tests/**, minus exclusions.
subject_set() {
  local root="$1" f rel
  [ -d "$root/tests" ] || return 0
  while IFS= read -r f; do
    rel="${f#"$root"/}"
    is_excluded "$rel" || echo "$rel"
  done < <(find "$root/tests" -type f \( -name '*.sh' -o -name '*.bats' \) | sort)
}

# invoked_paths <file> — repo-relative spec paths this file invokes as a
# subprocess. Only lines carrying the `bash` command word are read, so a
# workflow's `paths:` trigger entry naming a suite is never mistaken for an
# execution path — a trigger fires the workflow, it does not run the file.
invoked_paths() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -h 'bash' "$file" 2>/dev/null \
    | grep -ohE '(tests|scripts)/[A-Za-z0-9_./-]+\.(sh|bats)' \
    | sort -u
}

# reachable_set <root> — the transitive closure described above.
reachable_set() {
  local root="$1" frontier next seen wf f
  seen="$(mktemp)"; frontier="$(mktemp)"; next="$(mktemp)"
  : > "$frontier"
  for wf in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml; do
    [ -f "$wf" ] || continue
    invoked_paths "$wf" >> "$frontier"
  done
  sort -u "$frontier" -o "$frontier"
  cat "$frontier" > "$seen"
  while [ -s "$frontier" ]; do
    : > "$next"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      invoked_paths "$root/$f" >> "$next"
    done < "$frontier"
    sort -u "$next" -o "$next"
    comm -23 "$next" <(sort -u "$seen") > "$frontier"
    cat "$frontier" >> "$seen"
    sort -u "$seen" -o "$seen"
  done
  sort -u "$seen"
  rm -f "$seen" "$frontier" "$next"
}

# unreachable_set <root> — subject set minus reachable set.
unreachable_set() {
  local root="$1"
  comm -23 <(subject_set "$root") <(reachable_set "$root")
}

# ---------------------------------------------------------------------------
# Self-test — a hermetic fixture tree whose answer is known by construction.
# ---------------------------------------------------------------------------
build_fixture_tree() {
  local dir="$1"
  mkdir -p "$dir/.github/workflows" "$dir/tests/lib" "$dir/tests/plugin"

  cat > "$dir/.github/workflows/fixture.yml" <<'YML'
name: fixture
on:
  pull_request:
    paths:
      - 'tests/fixture-orphan.sh'
jobs:
  fixture:
    runs-on: ubuntu-latest
    steps:
      - run: bash tests/fixture-entry.sh
YML

  # Reachable directly (a run: step names it) and, transitively, the suite it
  # drives as a subprocess.
  echo 'bash "$PROJECT_ROOT/tests/fixture-transitive.sh"' > "$dir/tests/fixture-entry.sh"
  echo 'echo transitive'                                  > "$dir/tests/fixture-transitive.sh"

  # Unreachable, and named ONLY by the workflow's paths: trigger — a trigger
  # fires the workflow, it does not execute the file.
  echo 'echo orphan'                                      > "$dir/tests/fixture-orphan.sh"
  # Unreachable and outside every exclusion, in a subdirectory: the subject set
  # must reach it, which an admitting glob over tests/test-*.sh would not.
  echo 'echo plugin orphan'                               > "$dir/tests/plugin/verify-fixture-orphan.sh"
  # Unreachable .bats: bats is unavailable in CI, so it has no execution path.
  echo '@test "x" { true; }'                              > "$dir/tests/fixture-orphan.bats"

  # Each of the three named exclusions, all unreachable: the subtraction must
  # drop them, and only them.
  echo 'true'                                             > "$dir/tests/lib/fixture-helper.sh"
  echo 'true'                                             > "$dir/tests/run-doc-invariants.sh"
  echo 'true'                                             > "$dir/tests/issue-59-full-sweep-driver.sh"
}

self_test() {
  local dir out rc=0 expected
  dir="$(mktemp -d)"
  build_fixture_tree "$dir"
  out="$(unreachable_set "$dir")"

  # --- CLOSURE leg -------------------------------------------------------
  # The lint finds an unreachable suite it looks at, and does NOT report a
  # suite made reachable only through a transitive `bash <path>` edge.
  expected="$(printf 'tests/fixture-orphan.bats\ntests/fixture-orphan.sh\ntests/plugin/verify-fixture-orphan.sh\n')"
  if [ "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$expected" | sort)" ]; then
    echo "check-suite-ci-coverage: --self-test CLOSURE leg OK — the known-unreachable fixture suites are reported and the transitively-invoked one is not"
  else
    echo "check-suite-ci-coverage: --self-test CLOSURE leg FAILED"
    echo "  expected unreachable: $(printf '%s' "$expected" | tr '\n' ' ')"
    echo "  reported unreachable: $(printf '%s' "$out" | tr '\n' ' ')"
    rc=1
  fi

  # --- EXCLUSION leg -----------------------------------------------------
  # Each named exclusion is asserted positively, and a path outside the three
  # is asserted NOT excluded. Without this leg the criterion is satisfiable by
  # broadening the exclusions until the subject set is empty.
  local p
  for p in tests/lib/fixture-helper.sh tests/run-doc-invariants.sh tests/issue-59-full-sweep-driver.sh; do
    if printf '%s\n' "$out" | grep -qxF "$p"; then
      echo "check-suite-ci-coverage: --self-test EXCLUSION leg FAILED — $p should be excluded from the subject set but was reported"
      rc=1
    fi
    if ! is_excluded "$p"; then
      echo "check-suite-ci-coverage: --self-test EXCLUSION leg FAILED — $p is not recognised as a named exclusion"
      rc=1
    fi
  done
  if is_excluded tests/plugin/verify-fixture-orphan.sh; then
    echo "check-suite-ci-coverage: --self-test EXCLUSION leg FAILED — a path outside the three named exclusions is being excluded (over-broad subtraction)"
    rc=1
  fi
  [ "$rc" -eq 0 ] && echo "check-suite-ci-coverage: --self-test EXCLUSION leg OK — the three named exclusions are subtracted and nothing outside them is"

  rm -rf "$dir"
  return $rc
}

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

if ! self_test; then
  echo "check-suite-ci-coverage: detector self-test failed — real-tree result not reported"
  exit 1
fi

UNREACHABLE="$(unreachable_set "$ROOT")"
SUBJECT_COUNT="$(subject_set "$ROOT" | wc -l | tr -d ' ')"

if [ -z "$UNREACHABLE" ]; then
  echo "check-suite-ci-coverage: OK — all $SUBJECT_COUNT executable spec(s) under tests/** have an execution path"
  exit 0
fi

echo "check-suite-ci-coverage: suite(s) with zero execution paths:"
printf '%s\n' "$UNREACHABLE" | sed 's/^/  /'
echo "Each is either wired into a workflow's run: steps (or invoked by a suite that is), or deleted with a §5 disposition row in docs/doc-invariant-registry.md. There is no exemption list."
exit 1
