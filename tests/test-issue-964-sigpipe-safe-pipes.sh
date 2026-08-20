#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/submodule-common-rules.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: SIGPIPE-safe assertion pipes guard — Issue #964
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-964-verification-design.md). Docs/ops meta-suite (no jest,
# no npm) — mirrors tests/test-issue-949-manifest-regen-doc.sh /
# tests/test-issue-955-subagent-background-ban.sh: assert_true/assert_false
# over grep/awk section extraction + eval-bound fixture equivalence.
#
# Central testability note (verification design §0): the race itself
# (producer/consumer SIGPIPE timing under `pipefail`) is NOT deterministically
# reproducible at the pipelines' real (small) data volume — 500/500 local
# iterations rc=0 (hypotheses.md). This suite therefore gates the
# DETERMINISTIC surfaces the design pivots onto instead of the race: the
# structural anti-pattern's absence (AC2-A/AC2-A2) and the documented
# safe-pattern convention (AC3-A).
#
# Scope (verification design §1/§3), as narrowed by issue #75:
#   AC2-A   — RED discriminator (primary): repo-wide zero-remaining guard —
#             no `tests/*.sh` line matches the canonical hazard shape
#             `grep -[ABC] ?[0-9]+ [^)]*\| grep -q` (verification design §1a).
#   AC2-A2  — RED discriminator (issue #973): repo-wide zero-remaining
#             extractor-function producer guard, self-inclusive.
#   AC3-A   — RED discriminator: docs/submodule-common-rules.md > Testing
#             Standards names `pipefail`, `SIGPIPE`, the capture-then-grep
#             guidance and the extractor-function producer case.
#   AC4-B   — informational: records which grep (wrapper vs real) this run
#             used, since the dev-shell wrapper cannot reproduce the race
#             (verification design AC4-B) — a wrapper-only green is
#             regression evidence, NOT fix-effect evidence.
#   AC5-A   — RED discriminator (issue #114): a third named, self-inclusive
#             structural guard — zero lines in the converted file set
#             (tests/test-issue-952-wizard-removal.sh, this suite) match a
#             printf-captured producer piped directly into a short-circuiting
#             `grep -q`/`grep -m` consumer (.autoflow/issue-114-verification-
#             design.md > AC-no-shortcircuit-pipe-in-converted-suite).
#   AC6-A/B — RED discriminator (issue #114, doc-assertion): Testing Standards
#             names the pipe-free here-string consumer form (`<<<`, presence)
#             and no longer prescribes the piped `"$ctx" | grep -q` form
#             (absence) — (.autoflow/issue-114-verification-design.md >
#             AC-canonical-idiom-is-pipe-free).
#
# Retired by issue #75 (cycle-scope-guard retirement, .autoflow/issue-75-
# feature-design.md §3.3): the inventory cross-check lanes that pinned a
# hazard file-set/line-count baseline and credited a vacuous PASS once the
# guard was clear; the two lanes scoped to
# tests/test-issue-949-manifest-regen-doc.sh, whose subject #951 deleted; and
# the sibling-suite whole-suite re-run guard, whose members are each already
# their own top-level CI step in .github/workflows/e2e-dummy-target.yml.
#
# Not in this file (verification design §1 AC1-D / §4 item 3): forced-race
# reproduction is an environment-dependent demonstration (real grep + an
# artificially inflated producer), not a CI gate — committing it risks a NEW
# flaky test, the opposite of this issue's intent.
#
# Self-guard (dogfood): this suite's own assertions use plain `grep -nE`/
# `awk`/`grep -rnE` (no `-A/-B/-C` context flag piped into `grep -q`) — it
# does not introduce a new instance of the defect class it tests for. The
# only occurrence of the literal hazard SHAPE in this file is inside
# mktemp-generated fixture content (never a committed tests/*.sh line) —
# matching verification design §1a's "Self-match footgun" guidance.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_COMMON="$PROJECT_ROOT/docs/submodule-common-rules.md"

# Canonical guard regex — single source, verification design §1a / feature
# design §8.1, cited verbatim. Matches the compound "context-mode producer
# piped directly into a short-circuit consumer" shape; the `[^)]*` (no
# closing paren before the pipe) is exactly what lets the guard CLEAR the
# mandated capture-then-printf fix (the `$(...)` closing `)` breaks it).
GUARD_REGEX='grep -[ABC] ?[0-9]+ [^)]*\| grep -q'

# Second named guard — issue #973, extractor-function producer class
# (feature §4.1 / verification §2 DCR-1, ledger E4, frozen regex). Matches a
# bare-identifier extractor function (e.g. `claude_issue_mgmt_section`) piped
# directly into a short-circuiting consumer (`grep -q`/`grep -m`). Kept as a
# SEPARATE named regex from GUARD_REGEX, never folded in: the two match
# different producer shapes, so a single merged pattern would report one
# undifferentiated hit set and AC2-A / AC2-A2 could no longer say WHICH class
# a hit belongs to (ledger E8).
EXTRACTOR_GUARD_REGEX='(^|[[:space:]"'"'"'])[a-zA-Z_][a-zA-Z0-9_]* \| grep -[qm]'

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-949-manifest-regen-doc.sh)
# ---------------------------------------------------------------------------

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

extract_section() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^## / { f=0 }
    f && /^---$/ { f=0 }
    f { print }
  ' "$file"
}

# =============================================================================
echo "=== AC2-A (RED discriminator, primary) — repo-wide zero-remaining guard ==="
# Single grep -rnE scan (no piped short-circuit consumer) — self-safe.

REPO_MATCHES="$(grep -rnE "$GUARD_REGEX" "$PROJECT_ROOT"/tests/*.sh 2>/dev/null || true)"
if [[ -n "$REPO_MATCHES" ]]; then
  REPO_MATCH_COUNT="$(printf '%s\n' "$REPO_MATCHES" | grep -c .)"
else
  REPO_MATCH_COUNT=0
fi
echo "  hazard lines found: $REPO_MATCH_COUNT"
[[ "$REPO_MATCH_COUNT" -gt 0 ]] && printf '%s\n' "$REPO_MATCHES" | sed 's/^/    /'

assert_true "AC2-A: zero tests/*.sh lines match the compound hazard shape (grep -[ABC] context producer piped directly into grep -q)" \
  "[ $REPO_MATCH_COUNT -eq 0 ]"


# =============================================================================
echo ""
echo "=== AC2-A2 (RED discriminator, issue #973) — repo-wide zero-remaining extractor-producer guard ==="
# Second named regex, self-inclusive scan (globs tests/*.sh INCLUDING this
# file itself — self-trip guard re-confirms 964's own new lines contribute 0,
# ledger E9). Single grep -rnE scan (no piped short-circuit consumer) — self-safe.

EXTRACTOR_MATCHES="$(grep -rnE "$EXTRACTOR_GUARD_REGEX" "$PROJECT_ROOT"/tests/*.sh 2>/dev/null || true)"
if [[ -n "$EXTRACTOR_MATCHES" ]]; then
  EXTRACTOR_MATCH_COUNT="$(printf '%s\n' "$EXTRACTOR_MATCHES" | grep -c .)"
else
  EXTRACTOR_MATCH_COUNT=0
fi
echo "  extractor-producer hazard lines found: $EXTRACTOR_MATCH_COUNT"
[[ "$EXTRACTOR_MATCH_COUNT" -gt 0 ]] && printf '%s\n' "$EXTRACTOR_MATCHES" | sed 's/^/    /'

assert_true "AC2-A2: zero tests/*.sh lines match the extractor-function producer hazard shape (bare-identifier fn piped into grep -q/-m), including this suite itself" \
  "[ $EXTRACTOR_MATCH_COUNT -eq 0 ]"




# =============================================================================
echo ""
echo "=== AC3-A (RED discriminator, doc-assertion) — Testing Standards safe-pattern convention ==="

TESTING_STANDARDS_BODY="$(extract_section '^## Testing Standards' "$SUBMODULE_COMMON")"
TESTING_STANDARDS_JOINED="$(printf '%s' "$TESTING_STANDARDS_BODY" | tr '\n' ' ')"
export TESTING_STANDARDS_JOINED

assert_true "AC3-A: Testing Standards section names 'pipefail'" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qF 'pipefail'"
assert_true "AC3-A: Testing Standards section names 'SIGPIPE'" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qF 'SIGPIPE'"
assert_true "AC3-A: Testing Standards section documents the capture-then-grep guidance (a capture assignment token or a \$(...) command-substitution form)" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qE 'capture|\\\$\\('"
assert_true "AC3 (issue #973): Testing Standards section names the extractor-function producer case" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qF 'extractor'"


# =============================================================================
echo ""
echo "=== AC5-A (RED discriminator, issue #114) — no short-circuit pipe in the converted file set ==="
# Verification design .autoflow/issue-114-verification-design.md >
# AC-no-shortcircuit-pipe-in-converted-suite. Capturing the producer first
# (`ctx=$(<producer>)`) removes a *streaming* producer, but `printf` of the
# captured string is itself a producer: piped directly into a
# short-circuiting `grep -q`/`grep -m` consumer, its remaining write() can
# still be stranded when the consumer exits early under `pipefail` (issue
# #114). Kept as a separate named regex from GUARD_REGEX/EXTRACTOR_GUARD_REGEX
# for the same attribution reason recorded above — a merged pattern could no
# longer say which class a hit belongs to.
#
# Path set: this cycle's converted files only (verification design
# DCR-guard-scope-must-be-bounded) — tests/test-issue-952-wizard-removal.sh
# and this suite's own file. Self-inclusive: the scan reads this file too, so
# the regex-definition line below is its own self-clearance check — if it
# matched its own pattern this assertion would fail on landing.

SHORTCIRCUIT_PIPE_REGEX='printf [^|]*\| *grep -[qm]'
CONVERTED_952="$PROJECT_ROOT/tests/test-issue-952-wizard-removal.sh"
SELF_FILE="$SCRIPT_DIR/test-issue-964-sigpipe-safe-pipes.sh"

SHORTCIRCUIT_MATCHES="$(grep -rnE "$SHORTCIRCUIT_PIPE_REGEX" "$CONVERTED_952" "$SELF_FILE" 2>/dev/null || true)"
if [[ -n "$SHORTCIRCUIT_MATCHES" ]]; then
  SHORTCIRCUIT_MATCH_COUNT="$(printf '%s\n' "$SHORTCIRCUIT_MATCHES" | grep -c .)"
else
  SHORTCIRCUIT_MATCH_COUNT=0
fi
echo "  short-circuit-pipe hazard lines found: $SHORTCIRCUIT_MATCH_COUNT"
[[ "$SHORTCIRCUIT_MATCH_COUNT" -gt 0 ]] && printf '%s\n' "$SHORTCIRCUIT_MATCHES" | sed 's/^/    /'

assert_true "AC5-A (issue #114): zero lines in the converted file set (test-issue-952-wizard-removal.sh, this suite) match a printf-captured producer piped directly into grep -q/-m" \
  "[ $SHORTCIRCUIT_MATCH_COUNT -eq 0 ]"


# =============================================================================
echo ""
echo "=== AC6 (RED discriminator, doc-assertion, issue #114) — canonical idiom is pipe-free ==="
# Verification design AC-canonical-idiom-is-pipe-free. Two legs, not one: a
# presence assertion is RED at HEAD because its token is absent, an absence
# assertion because its token is present — one shape cannot carry both. Both
# legs ride the existing extract_section '^## Testing Standards' extraction
# ($TESTING_STANDARDS_JOINED, above) and are written in the here-string
# consumer form this cycle converts the neighbouring AC3-A legs into, so
# neither re-seeds the shape AC5-A scans for.

assert_true "AC6-A (issue #114, presence half): Testing Standards section names the pipe-free here-string consumer form ('<<<')" \
  "grep -qF '<<<' <<<\"\$TESTING_STANDARDS_JOINED\""
assert_true "AC6-B (issue #114, absence half): Testing Standards section no longer prescribes the captured-string-piped-into-grep-q form (literal '\"\$ctx\" | grep -q')" \
  "! grep -qF '\"\$ctx\" | grep -q' <<<\"\$TESTING_STANDARDS_JOINED\""


# =============================================================================
echo ""
echo "=== AC4-B (informational, NOT a RED discriminator) — grep provenance for this run ==="
# The dev-shell default grep is a Claude Code wrapper function and does not
# exhibit the SIGPIPE race; a green run here is regression evidence only, not
# fix-effect evidence (verification design AC4-B). Recorded, not asserted.

if declare -F grep >/dev/null 2>&1 || type grep 2>/dev/null | grep -qi 'function'; then
  echo "  grep provenance: wrapper (dev-shell function) — regression evidence only, not fix-effect evidence"
else
  echo "  grep provenance: real ($(command -v grep))"
fi

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
