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
#   bash scripts/test/check-suite-ci-coverage.sh [--root <dir>]
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"
# shellcheck source=scripts/test/invocation-scan.sh
. "$DEFAULT_ROOT/scripts/test/invocation-scan.sh"

ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
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

UNREACHABLE="$(unreachable_set "$ROOT")"
SUBJECT_COUNT="$(subject_set "$ROOT" | wc -l | tr -d ' ')"

if [ -z "$UNREACHABLE" ]; then
  echo "check-suite-ci-coverage: OK — all $SUBJECT_COUNT executable spec(s) under tests/** have an execution path"
  exit 0
fi

echo "check-suite-ci-coverage: suite(s) with zero execution paths:"
printf '%s\n' "$UNREACHABLE" | sed 's/^/  /'
echo "Each is either wired into a workflow's run: steps, or deleted. There is no exemption list."
echo "A sibling invocation is not an execution path: scripts/test/check-suite-leaf.sh denies it."
exit 1
