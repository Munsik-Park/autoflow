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
# `budget-secs` is derived from the suite's own CI step duration, never from
# local wall-clock. A suite with no CI-measured duration yet declares
# SUITE_BUDGET_CEILING_SECS verbatim — so a guessed budget is not a
# representable state.
# =============================================================================

# The declared-budget ceiling. Raising it is a visible one-line edit here, which
# is what stops a suite buying unbounded runtime by inflating its own header.
SUITE_BUDGET_CEILING_SECS=600

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
# ---------------------------------------------------------------------------
suite_header_field() {
  local file="$1" field="$2" line
  [ -f "$file" ] || return 1
  line="$(suite_header_block "$file" | grep -m1 "^# ${field}:")" || return 1
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
# ---------------------------------------------------------------------------
suite_budget_minutes() {
  printf '%s\n' "$(( ( $1 + 59 ) / 60 ))"
}
