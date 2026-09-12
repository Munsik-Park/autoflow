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
#   # budget-secs: <positive integer> | SUITE_BUDGET_CEILING_SECS
#
# THE GRAMMAR IS THIS LIST AND NOTHING ELSE. A field a script reads but no
# grammar declares is the second-definition-site failure this file exists to
# prevent, so the two directions are kept together: a field is added here and to
# check-suite-manifest.sh in one change, and retired from both in one change.
#
# FOUR FIELDS WERE RETIRED under ADR-0024 (issue #228), and each retirement's
# ground is recorded there > Area 3 rather than here:
#
#   `lane`, `retire-with`   under D2 every committed suite is standing and a
#                           one-shot check lives uncommitted under
#                           `.autoflow/issue-{N}-local/`, so a two-value field
#                           with one reachable value is not a declaration
#   `cycle-arm`             zero live instances of the case its own rationale
#                           named
#   `out-of-tree-inputs`    its only functional consumer was the verdict-
#                           inheritance exclusion, which D6 retires with the
#                           Green-tree register; with nothing inheriting, a
#                           base-ref-dependent suite simply runs. The predicate
#                           that decided it (`suite_reads_out_of_tree_state`
#                           below) survives for its other caller, which derives
#                           a subject set from it rather than a declaration
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
    # status to register.
    tests/lib/*.sh) return 0 ;;
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
# suite_step_id <repo-relative suite path> — the `id` a governed step carries,
# `s-<basename without extension>`. This is the ONLY link between a selection
# report path and an Actions outcome-map key, so it has one authoring home: the
# reconciler resolves a key back to a suite through it, and the manifest lint
# requires the declared value to equal it. A second copy would be value-equal
# on the day it is written and is what check-suite-manifest.sh's second-home
# rule rejects.
# ---------------------------------------------------------------------------
suite_step_id() {
  local base="${1##*/}"
  printf 's-%s\n' "${base%.*}"
}

# ---------------------------------------------------------------------------
# require_value <prog> <flag> <remaining argc> <next argument> — a flag that
# takes a value requires one. Absorbing a missing value into an empty string
# is how a lost argument resolves to a default and reports a result about a
# subject the caller never named. Shared by every CLI parser that sources this
# file, so the check is authored in one place rather than once per script.
# ---------------------------------------------------------------------------
require_value() {
  if [ "$3" -lt 2 ] || [ -z "$4" ]; then
    echo "$1: $2 requires a non-empty value" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# trim_ws <value> — <value> with leading and trailing whitespace stripped,
# printed on stdout. Shared by every parser that sources this file so the
# strip idiom has one definition site rather than one copy per caller.
# ---------------------------------------------------------------------------
trim_ws() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

# ---------------------------------------------------------------------------
# glob_matches <actions-dialect pattern> <path>
# The Actions `paths:` dialect, matched the way the conformance suite already
# implements it: `**` crosses `/`, a single `*` does not, and a token with no
# wildcard is an exact path or a directory prefix when it ends in `/`.
#
# THIS FILE IS THE MATCHER'S HOME because it is where the grammar the matcher
# interprets is declared: a `# ci-subject:` token IS an Actions `paths:` token,
# so the dialect belongs beside the header grammar rather than inside one of its
# consumers. Both callers already source this file, so the single definition
# site is reachable without a new source edge in either direction — and a single
# site is what makes "one implementation" executable rather than an agreement
# obligation between two copies over an unbounded input space.
# ---------------------------------------------------------------------------
glob_matches() {
  local pattern="$1" path="$2" rx
  case "$pattern" in
    */) case "$path" in "$pattern"*) return 0 ;; esac; return 1 ;;
  esac
  case "$pattern" in
    *'*'*) ;;
    *) [ "$pattern" = "$path" ] && return 0; return 1 ;;
  esac
  # Translate the dialect into an ERE: `**` -> `.*`, `*` -> `[^/]*`.
  rx="$(printf '%s' "$pattern" \
    | sed -e 's/[.[\()+^$|]/\\&/g' -e 's/\*\*/\x01/g' -e 's/\*/[^\/]*/g' -e 's/\x01/.*/g')"
  printf '%s' "$path" | grep -qE "^${rx}$"
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
# carries column-1 grammar lines in its BODY — a fixture header it emits, not a
# declaration it makes — and a whole-file grep reads one of those as the suite's
# own.
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
# suite_reads_out_of_tree_state <path> — true when the file's body carries a
# base-ref call site: a NON-COMMENT line invoking resolve_base_ref, or `git …
# merge-base` (flags between `git` and `merge-base` allowed, e.g.
# `git -C "$root" merge-base HEAD main`).
#
# THE SINGLE DEFINITION SITE of that criterion. It shipped inline inside an
# executed suite's derive_subjects(), which no lint can source, so a consuming
# lint could only re-type the expression — and a re-typed copy answers
# identically on the day it is written and drifts silently afterwards. Both
# consumers now call this: tests/test-push-context-base-ref.sh's subject
# derivation, and check-suite-manifest.sh's out-of-tree declaration arm. What
# does NOT move here is either consumer's DOMAIN — one asks a
# registration-scoped question, the other asks it over suite_enumerate; they
# differ in domain, not in predicate.
#
# The comment filter's output reaches grep through a PROCESS SUBSTITUTION, not a
# pipe. Under `set -o pipefail` the early-exiting `grep -q` delivers SIGPIPE to
# the first filter before it finishes writing, and the pipeline's status becomes
# 141 — silently dropping a true match. That defect was measured: a real
# resolve_base_ref call site deterministically vanished from the derived set.
# `< <(...)` keeps the filter a single simple command, so pipefail sees nothing.
#
# Naming the resolver only in a comment does not qualify — that is what the
# non-comment restriction buys, and it is why the filter is part of the
# predicate rather than the caller's business.
# ---------------------------------------------------------------------------
suite_reads_out_of_tree_state() {
  grep -qE '\bresolve_base_ref\b|\bgit\b[^#]*\bmerge-base\b' < <(grep -vE '^\s*#' "$1" 2>/dev/null)
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

# ---------------------------------------------------------------------------
# SUITE-PLANE OPT-IN — the single resolver (ADR-0024 D3, issue #228).
#
# AutoFlow's suite plane — this header grammar, the selector, the runner and the
# manifest lint — applies only where the target declared it, plus this
# repository, whose standing layer depends on it (ADR-0024 D5). The declaration
# lives in the target-owned scaffold `.claude/autoflow.local.json`, under the
# `tests` object's `suite_plane` key.
#
# THE KEY IS READ HERE AND NOWHERE ELSE. "Three copies of one predicate is the
# defect, not the fix … three predicates that must agree is a verification that
# can pass while the system is inconsistent" (ADR-0024 D3). Every consumer —
# the selection path, the runner and the manifest lint — sources this file and
# calls the function below; none of them re-types the key.
# tests/test-suite-plane-optin-single-site.sh holds that arity.
#
# THREE ANSWERS, NOT TWO. "Not opted in" carries its OWN exit status wherever it
# is consulted, distinct from success and from every failure code the consulting
# device already defines — the precedent is scripts/handoff/confirm-ci-green.sh,
# which keeps 11 ("nothing ran") distinct from 12 ("it failed") so that nothing
# ran cannot read as passed. And ABSENT is not UNREADABLE: a scaffold stamped
# before the declaration site shipped carries no `tests` object at all (the
# current `.claude/autoflow.local.json.example` ships the object with
# `suite_plane: false` — issue #229 — but a re-stamp never overwrites a target's
# copy), so absent is a normal non-opted-in state, while a declaration file that
# is present and cannot be parsed is a refusal — the fail-closed contract
# scripts/review/lib/review-config.sh already sets in this tree.
#
#   0                          opted in
#   SUITE_PLANE_NOT_OPTED_IN   no declaration file, no `tests` object, or the
#                              key is anything but true
#   SUITE_PLANE_UNREADABLE     a declaration file is present but its JSON cannot
#                              be read (malformed, unreadable, or no jq)
# ---------------------------------------------------------------------------
SUITE_PLANE_DECL_REL='.claude/autoflow.local.json'
SUITE_PLANE_NOT_OPTED_IN=3
SUITE_PLANE_UNREADABLE=4

suite_plane_opted_in() {
  local root="${1:-.}" decl verdict
  decl="$root/$SUITE_PLANE_DECL_REL"
  [ -f "$decl" ] || return "$SUITE_PLANE_NOT_OPTED_IN"
  command -v jq >/dev/null 2>&1 || return "$SUITE_PLANE_UNREADABLE"
  verdict="$(jq -r 'if (.tests.suite_plane? // false) == true then "in" else "out" end' "$decl" 2>/dev/null)" \
    || return "$SUITE_PLANE_UNREADABLE"
  case "$verdict" in
    in)  return 0 ;;
    out) return "$SUITE_PLANE_NOT_OPTED_IN" ;;
    *)   return "$SUITE_PLANE_UNREADABLE" ;;
  esac
}

# ---------------------------------------------------------------------------
# suite_plane_decl_path <root> — the declaration file a message should name, so
# every consumer reports the same path rather than composing its own.
# ---------------------------------------------------------------------------
suite_plane_decl_path() {
  printf '%s/%s\n' "${1:-.}" "$SUITE_PLANE_DECL_REL"
}

# ---------------------------------------------------------------------------
# suite_plane_declared <root> — does the target carry the DECLARATION SITE at
# all (issue #229, ADR-0024 S4)? 0 when the declaration file exists and holds a
# `tests` object, 1 otherwise. This answers a different question from
# `suite_plane_opted_in`: a scaffold stamped before the `tests` object shipped
# (0.2.2 and earlier) is not opted in AND has nowhere to say so, and a re-stamp
# never overwrites it — so drift-check D7 names that absence as a HINT beside
# its not-opted-in PASS, which is how an existing target learns the site exists
# (`.claude/autoflow.local.json.example` carries the sample). It is a presence
# predicate over the `tests` object, not a read of the opt-in key: the key is
# read by `suite_plane_opted_in` and nowhere else.
# ---------------------------------------------------------------------------
suite_plane_declared() {
  local root="${1:-.}" decl
  decl="$root/$SUITE_PLANE_DECL_REL"
  [ -f "$decl" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e 'has("tests") and (.tests | type == "object")' "$decl" >/dev/null 2>&1
}
