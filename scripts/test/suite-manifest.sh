#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# suite-manifest.sh — sourced library: the single definition site of the suite
# subject set, the suite header grammar, and the runtime-budget ceiling.
# =============================================================================
# SOURCED, NOT EXECUTED. It has no independent exit status and is excluded from
# the subject set for that reason.
#
# SUBJECT SET — enumerate, then subtract. The set is EVERYTHING under tests/**
# that is an executable spec (`*.sh` plus `*.bats`), minus the named exclusions
# in `suite_is_excluded`. The direction matters: an admitting glob
# (`tests/test-*.sh`, `tests/adr-*.sh`, …) leaves every other filename shape
# silently outside every lint that consumes this set, which is the class the
# governing lints exist to remove.
#
# This file owns the exclusion set as well as the direction. A second copy in a
# consuming lint would be two definitions of one subject, and would let a file
# be header-required by one lint and orphan-required by another.
#
# HEADER GRAMMAR — column-1 comment lines, one field per line:
#
#   # ci-subject: <path-or-glob> [<path-or-glob> ...]
#   # lane: standing | cycle-scoped
#   # retire-with: #<issue-number>      (required iff lane: cycle-scoped)
#   # cycle-arm: #<issue-number>        (required iff a path allow-list array)
#   # budget-secs: <positive integer> | SUITE_BUDGET_CEILING_SECS
#
# `budget-secs` is a CI-CLOCK quantity: derived from the suite's own CI step
# duration, bounded by the ceiling, and spent by CI. Local wall-clock is
# inadmissible as its source. A suite with no CI-measured duration declares
# SUITE_BUDGET_CEILING_SECS verbatim — so a guessed budget is not a
# representable state.
#
# THE TWO CLOCKS ARE NOT THE SAME CLOCK. An earlier form of this design let one
# declared number be derived on the CI clock and spent on the local clock, which
# is unsatisfiable here: measured cross-clock, `test-push-context-base-ref.sh`
# runs 89 s in CI against 594 s locally (≈ 6.7×). That is a unit error, not a
# magnitude error, so no single number escapes it. Local enforcement therefore
# spends a LOCAL ALLOWANCE derived from the declared budget by one tree-wide
# ratio (SUITE_LOCAL_SLOWDOWN_FACTOR), never the CI number directly.
# =============================================================================

# The declared-budget ceiling, on the CI clock. Derived rather than chosen: the
# maximum measured CI step duration across the umbrella workflows at the run of
# record is 394 s, and ceil(394 × SUITE_BUDGET_HEADROOM_PERCENT / 100) = 591 s,
# rounded to the constant below. Re-check it by re-querying the Actions jobs API
# for each successful step's `completed_at − started_at`, not by inheriting this
# number.
#
# Changing it is NOT a one-line edit in effect: check-suite-manifest.sh asserts
# each governed step's `timeout-minutes` EQUALS ceil(budget-secs / 60) by strict
# equality, and every real suite declares the ceiling symbol — so a ceiling
# change moves every governed step's CI allowance together. That is what makes
# it a tree-wide bound rather than a knob.
SUITE_BUDGET_CEILING_SECS=600

# Headroom over a measurement, as a percentage, for the integer declaration form:
#
#     budget-secs = ceil(measured CI step duration × SUITE_BUDGET_HEADROOM_PERCENT / 100)
#
# Admissible shape: an integer >= 100. The lower bound is not stylistic — a
# sub-100 multiplier derives a budget TIGHTER than the measurement it is headroom
# over, which is a guessed-tight budget wearing the derivation's name, reached
# through the rule rather than around it.
#
# The value is not a fresh judgement: it is the margin the ceiling already
# embodies (600 over the 394 s maximum measured step is ≈ 1.52×), so the
# per-suite rule and the tree-wide ceiling are set by one factor rather than two
# independently chosen ones.
SUITE_BUDGET_HEADROOM_PERCENT=150

# The cross-clock ratio local enforcement spends:
#
#     local allowance = budget-secs × SUITE_LOCAL_SLOWDOWN_FACTOR
#
# This is a RATIO BETWEEN TWO CLOCKS, not a duration and not a per-suite
# estimate, which is what keeps it clear of the inadmissible-local-wall-clock
# rule. Its derivation set is narrow and stated: UNCONTENDED per-suite
# cross-clock measurements only. That set holds one member today —
# `test-push-context-base-ref.sh` at 89 s CI vs 594 s local, ≈ 6.7×, whose
# ceiling is 7 — and the value is set one integer above it. That extra integer is
# a decision, not an arithmetic step: it is the only margin a one-member
# derivation set can carry.
#
# The contended row on record (`test-issue-69`, 394 s CI vs 1298 s local, ≈ 3.3×)
# is context for the unit error, NOT a derivation input: it yields the LOWER
# ratio, so contention is not the property that orders this set, and a maximum
# across both would drag the factor down toward a condition the local gate must
# survive rather than be sized by.
#
# Admissible shape: an integer >= 1. One is the multiplier's identity, at which
# the local allowance is exactly the declared CI budget — the pre-change
# behaviour this constant exists to undo — so any value below it would derive a
# local allowance tighter than a number already measured on the FASTER clock,
# inverting the unit error rather than correcting it. The bound is also what
# keeps this from reading as a disable switch in the other direction: at every
# admissible value it is a multiplier over the declared budget, never an
# unconditional widening.
#
# It is deliberately NOT environment-settable. A `${SUITE_LOCAL_SLOWDOWN_FACTOR:-8}`
# form would still pass the single-authoring-home lint while making a resource
# control settable by any caller; a plain assignment is what makes the declared
# value the effective one.
#
# Residual: a maximum over a one-member set is a floor with no distribution
# behind it. The case that remains is a host slower than the measured ratio, and
# its outcome is a re-run, not a header edit.
SUITE_LOCAL_SLOWDOWN_FACTOR=8

# ---------------------------------------------------------------------------
# suite_is_excluded <repo-relative path>
# Each exclusion carries its reason here, in the library, rather than being
# inherited from a naming glob — so the intent survives a rename.
# ---------------------------------------------------------------------------
suite_is_excluded() {
  case "$1" in
    # Sourced libraries, not standalone specs: they have no independent exit
    # status to register. tests/lib/harness-pins.sh lands under this entry.
    tests/lib/*.sh) return 0 ;;
    # The registry runner, not a spec. It is CI-registered anyway, so this
    # changes no verdict today; it is stated so the set is a decision rather
    # than a coincidence.
    tests/run-doc-invariants.sh) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# suite_path_is_governed <repo-relative path>
# True when a path has the SHAPE of an enumerated spec, whether or not the file
# exists on disk. Workflow-side lints need this form: a `run:` step names a path
# that must be governed even when the lint is driven against a fixture root that
# carries only the workflow file.
# ---------------------------------------------------------------------------
suite_path_is_governed() {
  case "$1" in
    tests/*.sh|tests/*/*.sh|tests/*/*/*.sh|tests/*.bats|tests/*/*.bats) ;;
    *) return 1 ;;
  esac
  suite_is_excluded "$1" && return 1
  return 0
}

# ---------------------------------------------------------------------------
# suite_enumerate <root> — repo-relative paths of every executable spec under
# tests/**, sorted, minus the exclusions above.
# ---------------------------------------------------------------------------
suite_enumerate() {
  local root="$1" f rel
  [ -d "$root/tests" ] || return 0
  while IFS= read -r f; do
    rel="${f#"$root"/}"
    suite_is_excluded "$rel" || echo "$rel"
  done < <(find "$root/tests" -type f \( -name '*.sh' -o -name '*.bats' \) | sort)
}

# ---------------------------------------------------------------------------
# suite_header_block <path> — the file's LEADING comment block: every line from
# the top up to the first line that is neither blank nor a comment. Bounding the
# search here is not tidiness. A suite that writes fixture files by heredoc
# carries column-1 `# lane:` / `# retire-with:` lines in its BODY — the RED
# suites of this very cycle do — and a whole-file grep reads one of those as the
# suite's own declaration.
# ---------------------------------------------------------------------------
suite_header_block() {
  awk '/^[[:space:]]*$/ { next } /^#/ { print; next } { exit }' "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# suite_header_field <path> <field> — prints the field's value (leading and
# trailing whitespace stripped) and returns 0, or returns 1 when absent.
# Only column-1 `# <field>:` comment lines are read, so a field name appearing
# inside a body string is never mistaken for a declaration.
#
# CAPTURE-THEN-MATCH, not `suite_header_block | grep -m1`. Under `set -o pipefail`
# the early-exiting consumer delivers SIGPIPE to the awk producer the moment it
# has its one match, and the pipeline's status becomes 141 — so a header that IS
# present reports as absent. Whether the producer has written its remaining lines
# before the consumer exits is a scheduling race, which is why the failure was
# nondeterministic and awk-implementation-dependent (gawk on the CI runner, not
# mawk or macOS awk). The prefix match below is exact: no field name in the
# grammar contains a glob or regex metacharacter.
# ---------------------------------------------------------------------------
suite_header_field() {
  local file="$1" field="$2" block line found=''
  [ -f "$file" ] || return 1
  block="$(suite_header_block "$file")" || return 1
  while IFS= read -r line; do
    case "$line" in
      "# ${field}:"*) found="$line"; break ;;
    esac
  done <<<"$block"
  line="$found"
  [ -n "$line" ] || return 1
  line="${line#\# ${field}:}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s\n' "$line"
}

# ---------------------------------------------------------------------------
# suite_declares_allow_list <path> — true when the file declares a path
# allow-list array IN ITS OWN SCOPE. This is the subject test
# check-cycle-scope-guard.sh binds to, and the antecedent of the header's
# cycle-arm coupling.
#
# Heredoc bodies are skipped. A suite that writes fixture files inline carries
# `allow_list=(` inside a heredoc — the RED suites of the cycle that introduced
# this library do — and that is fixture TEXT the suite emits, not an array the
# suite declares. Counting it makes a lint demand a `cycle-arm` header naming a
# cycle the file has no arm for, and inflates the guard's own subject count.
# ---------------------------------------------------------------------------
suite_declares_allow_list() {
  awk '
    /^[[:space:]]*$/ { next }
    in_here {
      s = $0; sub(/^[[:space:]]+/, "", s)
      if (s == tag) in_here = 0
      next
    }
    {
      if (match($0, /<<-?[[:space:]]*[\x27"]?[A-Za-z_][A-Za-z0-9_]*[\x27"]?/)) {
        tag = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[[:space:]]*/, "", tag)
        gsub(/[\x27"]/, "", tag)
        if (tag != "") { in_here = 1; next }
      }
      if ($0 ~ /^[[:space:]]*(allow_list|ALLOWLIST_[0-9A-Za-z_]+)=\(/) { found = 1; exit }
    }
    END { exit(found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# suite_budget_secs <path> — the declared budget resolved to an integer. The
# ceiling symbol resolves to SUITE_BUDGET_CEILING_SECS; anything else is echoed
# verbatim for the caller to validate.
# ---------------------------------------------------------------------------
suite_budget_secs() {
  local v
  v="$(suite_header_field "$1" budget-secs)" || return 1
  if [ "$v" = "SUITE_BUDGET_CEILING_SECS" ]; then
    printf '%s\n' "$SUITE_BUDGET_CEILING_SECS"
  else
    printf '%s\n' "$v"
  fi
}

# ---------------------------------------------------------------------------
# suite_budget_minutes <secs> — ceil(secs / 60), the Actions step-level ceiling
# the workflow must declare for a suite carrying this budget.
#
# CI-clock only: the local slowdown factor deliberately does NOT reach this
# derivation. Letting it through would let a local-execution constant buy CI
# runtime, which is the one thing the two-clock separation must not do.
# ---------------------------------------------------------------------------
suite_budget_minutes() {
  printf '%s\n' "$(( ( $1 + 59 ) / 60 ))"
}

# ---------------------------------------------------------------------------
# suite_local_allowance_secs <budget-secs> — the effective local ceiling,
# budget-secs × SUITE_LOCAL_SLOWDOWN_FACTOR. This is what a local run spends;
# the declared budget is what CI spends. They are quantities on different
# clocks, and the whole point of this function is that the caller cannot
# accidentally use one for the other.
# ---------------------------------------------------------------------------
suite_local_allowance_secs() {
  printf '%s\n' "$(( $1 * SUITE_LOCAL_SLOWDOWN_FACTOR ))"
}
