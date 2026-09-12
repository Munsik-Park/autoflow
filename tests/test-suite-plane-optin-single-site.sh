#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/suite-manifest.sh scripts/test/select-suites.sh scripts/test/run-suites.sh scripts/test/check-suite-manifest.sh .claude/autoflow.local.json .claude/autoflow.local.json.example
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: the suite plane's opt-in declaration has ONE reader, and every consumer
#       resolves through it.
# =============================================================================
# STANDING suite (`automated / standing: cross-file`), subject-named, no issue
# number — docs/autoflow-guide.md > RED > Naming.
#
# WHAT IT PROTECTS, and what its absence costs. ADR-0024 D3 requires "a single
# shared opt-in resolver" and states the defect by name: "Three copies of one
# predicate is the defect, not the fix ... three predicates that must agree is a
# verification that can pass while the system is inconsistent." A second copy
# passes every behavioural check on the day it is written and diverges later,
# after merge — the `cross-file` category's own case ("two or more files that
# must state the same fact do so — shared identifiers named by a settled
# decision"). No behavioural leg can see it: a tree with three agreeing copies
# answers every selection correctly. This is the only device that can.
#
# WHY IT IS NOT COVERED ELSEWHERE. The real-root behavioural oracle lives in
# tests/test-headerless-suite-target.sh (the installed selector against real
# opted-in and non-opted-in roots); it drives the answer, not the arity. The
# manifest lint's second-home rules cover the budget constants and the step-id
# derivation, not this key.
#
# THE READ PREDICATE IS ANCHORED ON A KEY ACCESS, NOT ON THE WORD. A `jq` path
# (`.tests.suite_plane`), a bracket access, or a quoted key literal in a lookup
# position is a read; the key's NAME inside a prose message or an assertion
# description is not (tests/test-issue-979-bundle-delivery.sh legitimately
# carries one). Declaration files are out of the scan set for the same reason:
# they declare the key, they do not read it.
#
# A DECLARATION A SUITE WRITES IS A DECLARATION, NOT A READ. The same exclusion
# reaches the JSON object literals a behavioural suite writes into a fixture
# root's .claude/autoflow.local.json (tests/test-headerless-suite-target.sh must
# write the literal key to drive the real resolver against a real declaration).
# The discriminator is the position, not the file: `"suite_plane"` immediately
# followed by `:` is the JSON member-NAME position of a declaration being
# supplied; every other occurrence of the key retrieves a value and counts. So a
# genuine `.tests.suite_plane` access added to that same suite — the shape a
# second resolver would take — is still counted, and the arity property the row
# records (exactly one reader) is narrowed in shape, not in reach.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 2

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== suite-plane opt-in: single declaration site, every consumer resolving through it ==="

RESOLVER_HOME='scripts/test/suite-manifest.sh'
CONSUMERS=(scripts/test/select-suites.sh scripts/test/run-suites.sh scripts/test/check-suite-manifest.sh)
SELF='tests/test-suite-plane-optin-single-site.sh'

# A key ACCESS: a jq path, a bracket access, or a quoted key literal in a lookup
# position. A quoted literal immediately followed by ':' is the JSON member-name
# position of a declaration being WRITTEN, not a read, so the two quoted arms
# require a following non-':' character; readers() appends one to every line so
# a key at end-of-line still matches without an in-group '$' anchor (its ERE
# meaning is unspecified and this suite runs on BSD grep too).
READ_RE='\.suite_plane|\[suite_plane\]|"suite_plane"[^:]|'"'"'suite_plane'"'"'[^:]'

# The scan set: executable code, tree-wide. Declaration files (*.json) are not
# in it — a declaration is not a reader.
scan_set() {
  git ls-files -- \
    'scripts/*.sh' 'scripts/*/*.sh' 'scripts/*/*/*.sh' \
    'tests/*.sh' 'tests/*/*.sh' 'tests/*/*/*.sh' \
    'setup/*.sh' 'setup/*/*.sh' \
    'plugin/*/*.sh' 'plugin/*/*/*.sh' 'plugin/*/*/*/*.sh' 'plugin/*/*/*/*/*.sh' \
    '.claude/hooks/*.sh' '.claude/workflows/*.js' 2>/dev/null | sort -u
}

# readers — files carrying a key ACCESS on a non-comment line.
readers() {
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    [ "$f" = "$SELF" ] && continue
    grep -vE '^[[:space:]]*#' "$f" 2>/dev/null | sed 's/$/ /' \
      | grep -qE -- "$READ_RE" && echo "$f"
  done < <(scan_set)
}

N_SCAN=$(scan_set | grep -c .)
if [ "$N_SCAN" -ge 50 ]; then
  pass "SCAN-SET: $N_SCAN tracked executables enumerated — the arity arms below have a subject"
else
  failc "SCAN-SET: only $N_SCAN files enumerated; every arm below would be vacuous"
fi

mapfile -t READERS < <(readers)

if [ "${#READERS[@]}" -eq 1 ]; then
  pass "SINGLE-SITE: exactly one file in the tree reads the suite-plane opt-in key"
else
  failc "SINGLE-SITE: ${#READERS[@]} file(s) read the opt-in key (expected exactly 1): ${READERS[*]:-none}"
fi

if [ "${#READERS[@]}" -ge 1 ] && [ "${READERS[0]}" = "$RESOLVER_HOME" ]; then
  pass "RESOLVER-HOME: the one reader is $RESOLVER_HOME — the suite plane's single vocabulary definition site and an already-registered bundle artifact"
else
  failc "RESOLVER-HOME: the reader is '${READERS[0]:-none}', not $RESOLVER_HOME"
fi

for c in "${CONSUMERS[@]}"; do
  if grep -qE "^[[:space:]]*(\.|source)[[:space:]].*suite-manifest\.sh" "$c"; then
    pass "CONSUMER-SOURCES: $c sources $RESOLVER_HOME"
  else
    failc "CONSUMER-SOURCES: $c does not source $RESOLVER_HOME, so it cannot resolve through it"
  fi
  if grep -vE '^[[:space:]]*#' "$c" | grep -qE -- "$READ_RE"; then
    failc "CONSUMER-NO-COPY: $c carries its own read of the opt-in key — a second predicate that must agree with the resolver"
  else
    pass "CONSUMER-NO-COPY: $c carries no private read of the opt-in key"
  fi
done

# The declaration side. Since issue #229 the shipped scaffold CARRIES the
# declaration site (`tests` > `command`, `tests` > `suite_plane`) and does not
# opt in — a stamped target must not inherit an opt-in it never made — while
# `absent` stays a normal non-opted-in state for a scaffold stamped before the
# site shipped (ADR-0024 D3). Both facts are read through the resolver over a
# scratch root holding the sample, never by a private read of the key; this
# repository declares its own opt-in (ADR-0024 D5).
if command -v jq >/dev/null 2>&1; then
  _scaf="$(mktemp -d)"; mkdir -p "$_scaf/.claude"
  cp .claude/autoflow.local.json.example "$_scaf/.claude/autoflow.local.json"
  if ( . "$RESOLVER_HOME"; suite_plane_declared "$_scaf" ) \
     && ( . "$RESOLVER_HOME"; suite_plane_opted_in "$_scaf"; [ $? -eq "$( . "$RESOLVER_HOME"; echo "$SUITE_PLANE_NOT_OPTED_IN" )" ] ); then
    pass "SCAFFOLD-NEUTRAL: the shipped scaffold carries the tests declaration site and the resolver answers 'not opted in' over it — a stamped target inherits the site, not an opt-in (#229)"
  else
    failc "SCAFFOLD-NEUTRAL: .claude/autoflow.local.json.example either lacks the tests declaration site or opts a stamped target in"
  fi
  rm -rf "$_scaf"
  if jq -e '.tests.suite_plane == true' .claude/autoflow.local.json >/dev/null 2>&1; then
    pass "THIS-REPO-OPTS-IN: .claude/autoflow.local.json declares tests.suite_plane: true (ADR-0024 D5 — this repository's standing layer depends on the plane)"
  else
    failc "THIS-REPO-OPTS-IN: .claude/autoflow.local.json does not declare tests.suite_plane: true, so this repository's own suites fall outside the plane they depend on"
  fi
else
  failc "jq is unavailable — the declaration arms cannot be evaluated, and a skipped check is never a pass"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
