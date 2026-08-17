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
# that is an executable spec (`*.sh` plus `*.bats`), minus the named exclusions.
# The direction matters: an admitting glob (`tests/test-*.sh`, `tests/adr-*.sh`,
# …) leaves every other filename shape silently outside the lint, which is the
# orphan class this exists to remove. `*.bats` stays IN, so a newly added
# `.bats` file is flagged rather than ignored — `bats` is unavailable in CI by
# design, so such a file has no execution path and must be disposed of, not
# merged.
#
# Both the direction and the exclusion set now live in
# scripts/test/suite-manifest.sh, which this lint sources. A second copy here
# would be two definitions of one subject, and would let a file be
# header-required by check-suite-manifest.sh and orphan-required by this lint.
#
# There is NO exemption list for unreachable suites: an allow-list here would be
# the hand-maintained inventory `docs/doc-invariant-registry.md` §1-2 retires.
# An unreachable suite is either wired or deleted with a disposition row.
#
# REACHABLE — a `run:` step in any workflow invokes it. DIRECT ONLY: the former
# transitive-closure clause (a reachable suite invoking it as a subprocess) is
# removed by issue #103. It protected nothing: every enumerated spec but the
# now-deleted full-sweep driver already carried its own `run:` step, and the one
# suite the old header advertised as the closure's sole beneficiary had in fact
# held a direct step of its own since contract-suites.yml registered it. That
# name is deliberately not repeated here — a stale rationale naming a live file
# is how a later cycle re-derives a protection that does not exist. The leaf rule
# (scripts/test/check-suite-leaf.sh) additionally makes a sibling invocation a
# violation, so a closure edge is not a reachability route a conforming tree can
# offer.
#
# WHAT COUNTS AS AN INVOCATION is not decided here. scripts/test/invocation-scan.sh
# owns that relation and this lint consumes it, as does
# tests/test-workflow-trigger-conformance.sh and the manifest lint's step reader.
# The line-based rule this file used to carry read a `bash` token wherever it
# appeared — inside a quoted grep pattern naming a `run:` line included — and
# missed a block-scalar `run:` body entirely, so the two lints disagreed on the
# same file while each stayed consistent with itself.
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

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"
# shellcheck source=scripts/test/invocation-scan.sh
. "$DEFAULT_ROOT/scripts/test/invocation-scan.sh"

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

# The subject set and its exclusions are the library's, not this lint's.
is_excluded()  { suite_is_excluded "$1"; }
subject_set()  { suite_enumerate "$1"; }

# reachable_set <root> — every spec a workflow `run:` step invokes directly.
# The invocation relation itself is scripts/test/invocation-scan.sh's, not this
# lint's: a private copy here and a second one in the conformance suite were two
# definitions of one subject, and they disagreed by construction on a
# block-scalar `run:` and on a quoted grep pattern naming a `run:` line.
reachable_set() {
  local root="$1" wf out
  out="$(mktemp)"
  for wf in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml; do
    [ -f "$wf" ] || continue
    invscan_workflow_invocations "$wf" >> "$out"
  done
  sort -u "$out"
  rm -f "$out"
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

  # Reachable: a run: step names it.
  echo 'echo entry'                                       > "$dir/tests/fixture-entry.sh"
  # Reachable ONLY through a sibling invocation. Since issue #103 narrowed
  # reachability to a direct run: step, this is an ORPHAN — the leg that pins
  # the narrowing, since under the former closure clause it was reported clean.
  echo 'echo sibling-only'                                > "$dir/tests/fixture-sibling-only.sh"

  # Unreachable, and named ONLY by the workflow's paths: trigger — a trigger
  # fires the workflow, it does not execute the file.
  echo 'echo orphan'                                      > "$dir/tests/fixture-orphan.sh"
  # Unreachable and outside every exclusion, in a subdirectory: the subject set
  # must reach it, which an admitting glob over tests/test-*.sh would not.
  echo 'echo plugin orphan'                               > "$dir/tests/plugin/verify-fixture-orphan.sh"
  # Unreachable .bats: bats is unavailable in CI, so it has no execution path.
  echo '@test "x" { true; }'                              > "$dir/tests/fixture-orphan.bats"

  # Each named exclusion, all unreachable: the subtraction must drop them, and
  # only them.
  echo 'true'                                             > "$dir/tests/lib/fixture-helper.sh"
  echo 'true'                                             > "$dir/tests/run-doc-invariants.sh"
}

self_test() {
  local dir out rc=0 expected
  dir="$(mktemp -d)"
  build_fixture_tree "$dir"
  out="$(unreachable_set "$dir")"

  # --- DIRECT-REACHABILITY leg -------------------------------------------
  # Every known-unreachable fixture suite is reported, INCLUDING the one a
  # sibling invokes: since issue #103 reachability is a direct run: step, and a
  # sibling edge is itself a leaf-rule violation rather than a route.
  expected="$(printf 'tests/fixture-orphan.bats\ntests/fixture-orphan.sh\ntests/fixture-sibling-only.sh\ntests/plugin/verify-fixture-orphan.sh\n')"
  if [ "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$expected" | sort)" ]; then
    echo "check-suite-ci-coverage: --self-test DIRECT-REACHABILITY leg OK — every known-unreachable fixture suite is reported, the sibling-only one included: a transitive-closure edge is no longer a reachability route"
  else
    echo "check-suite-ci-coverage: --self-test DIRECT-REACHABILITY leg FAILED — a transitive-closure edge must not count as a reachability route"
    echo "  expected unreachable: $(printf '%s' "$expected" | tr '\n' ' ')"
    echo "  reported unreachable: $(printf '%s' "$out" | tr '\n' ' ')"
    rc=1
  fi

  # --- EXCLUSION leg -----------------------------------------------------
  # Each named exclusion is asserted positively, and a path outside the three
  # is asserted NOT excluded. Without this leg the criterion is satisfiable by
  # broadening the exclusions until the subject set is empty.
  local p
  for p in tests/lib/fixture-helper.sh tests/run-doc-invariants.sh; do
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
    echo "check-suite-ci-coverage: --self-test EXCLUSION leg FAILED — a path outside the named exclusions is being excluded (over-broad subtraction)"
    rc=1
  fi
  [ "$rc" -eq 0 ] && echo "check-suite-ci-coverage: --self-test EXCLUSION leg OK — the named exclusions are subtracted and nothing outside them is"

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
echo "Each is either wired into a workflow's run: steps, or deleted with a §5 disposition row in docs/doc-invariant-registry.md. There is no exemption list."
echo "A sibling invocation is not an execution path: scripts/test/check-suite-leaf.sh denies it."
exit 1
