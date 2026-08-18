#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-suite-manifest.sh — standing lint: every suite declares what it is and
# what it costs, and the workflow that runs it agrees.
# =============================================================================
# The header grammar's single definition site is scripts/test/suite-manifest.sh,
# which this lint sources rather than re-parsing. What this file owns is the
# CONFORMANCE rules over that grammar, in three groups:
#
#   HEADER      — presence and grammar of ci-subject / lane / retire-with /
#                 cycle-arm / budget-secs, and the couplings between them.
#   WORKFLOW    — every GOVERNED suite step carries an `id`, a sentinel-delimited
#                 `if:` guard, and `timeout-minutes` equal to
#                 ceil(budget-secs / 60).
#   PIN         — the shared harness ok-count literal is authored in exactly one
#                 file.
#
# THE COUPLINGS, and why they are one-directional. `lane: cycle-scoped` implies
# the file declares a path allow-list array — that is the direction which keeps a
# cycle-scoped declaration inside check-cycle-scope-guard.sh's subject set. The
# CONVERSE is deliberately NOT asserted: this tree's three array-bearing suites
# each guard an own-PR change-surface arm inside a body of otherwise permanent
# assertions, so they are `standing`, and an `array => cycle-scoped` rule would
# mark three live standing suites for immediate retirement. What keeps such a
# suite governed instead is that `cycle-arm` is declared exactly when an array
# is, and agrees with `retire-with` when both apply.
#
# This lint asserts NO branch-inertness property of its own. Dominance of the
# branch gate over the array's evaluation set keeps exactly one owner,
# scripts/test/check-cycle-scope-guard.sh; a second, weaker definition of the
# same concept here is what the split exists to prevent.
#
# THE GOVERNED SET is a strict subset of a job's steps. A step is governed when
# its `run:` invokes a path with the SHAPE of an enumerated spec
# (`suite_path_is_governed`). The standing lints (`bash scripts/test/check-*.sh`)
# and the registry runner (`bash tests/run-doc-invariants.sh`) run
# unconditionally and are UNGOVERNED — they carry no budget header to agree with,
# and demanding one of a script that has none is how this arm would red a correct
# workflow. The boundary is by shape, not by filename: `tests/plugin/verify-*.sh`
# and `tests/adr-0016-conformance-check.sh` are governed too.
#
# WHY THE SENTINEL FORM IS MECHANICAL, NOT STYLISTIC: one suite path is a prefix
# of another's, so a bare `contains(steps.select.outputs.suites, 'tests/x.sh')`
# mis-selects. The guard must test membership with delimiters:
# `contains(format(' {0} ', steps.select.outputs.suites), ' tests/x.sh ')`.
# And every guarded step needs an `id`, because a step without one does not
# appear in the Actions `steps` context — which is exactly the input
# scripts/test/check-step-reconciliation.sh reads to catch a guard that
# evaluates false at run time.
#
# Usage:
#   bash scripts/test/check-suite-manifest.sh [--self-test] [--root <dir>] [--list-subjects]
#
# The default run performs the self-test FIRST, then reports the real-tree
# result — the precedent scripts/test/check-cycle-scope-guard.sh sets.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"
# shellcheck source=scripts/test/invocation-scan.sh
. "$SCRIPT_DIR/invocation-scan.sh"

MODE="default"
ROOT=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test)     MODE="self-test" ;;
    --root)          require_value check-suite-manifest "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    --list-subjects) LIST=1 ;;
    *)               echo "check-suite-manifest: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

VIOLATIONS=0
violation() { printf '  %s\n' "$1"; VIOLATIONS=$((VIOLATIONS + 1)); }

# ---------------------------------------------------------------------------
# HEADER group
# ---------------------------------------------------------------------------
check_headers() {
  local root="$1" f lane retire arm budget resolved has_array oot
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$root/$f" ] || continue

    suite_header_field "$root/$f" ci-subject >/dev/null \
      || violation "$f: no '# ci-subject:' header — the trigger surface is what selection consumes"

    if ! lane="$(suite_header_field "$root/$f" lane)"; then
      violation "$f: no '# lane:' header — every spec declares its lane at creation"
      lane=""
    elif [ "$lane" != standing ] && [ "$lane" != cycle-scoped ]; then
      violation "$f: '# lane: $lane' is not one of standing | cycle-scoped"
    fi

    retire="$(suite_header_field "$root/$f" retire-with || true)"
    arm="$(suite_header_field "$root/$f" cycle-arm || true)"
    has_array=0
    suite_declares_allow_list "$root/$f" && has_array=1

    if [ "$lane" = cycle-scoped ]; then
      [ -n "$retire" ] || violation "$f: 'lane: cycle-scoped' requires a '# retire-with: #<issue>' — the retirement condition needs a machine-readable subject"
      [ "$has_array" -eq 1 ] || violation "$f: 'lane: cycle-scoped' requires a path allow-list array — behavioural inertness is not statically checkable, and the array's evaluation set is the only thing dominance is checkable over"
    elif [ -n "$retire" ]; then
      violation "$f: '# retire-with:' is forbidden on a standing suite — a standing suite asserts permanent state and is never retired by an issue's merge"
    fi

    if [ "$has_array" -eq 1 ] && [ -z "$arm" ]; then
      violation "$f: declares a path allow-list array but no '# cycle-arm: #<issue>' — the arm names the cycle whose landed diff it asserts"
    fi
    if [ "$has_array" -eq 0 ] && [ -n "$arm" ]; then
      violation "$f: declares '# cycle-arm: $arm' but no path allow-list array — there is no arm for it to name"
    fi
    if [ -n "$arm" ] && [ -n "$retire" ] && [ "$arm" != "$retire" ]; then
      violation "$f: cycle-arm ($arm) and retire-with ($retire) disagree — on a cycle-scoped suite the arm and the retirement name the same cycle"
    fi
    for v in "$arm" "$retire"; do
      if [ -n "$v" ] && ! printf '%s' "$v" | grep -qE '^#[0-9]+$'; then
        violation "$f: '$v' is not a '#<issue-number>' value"
      fi
    done

    # OUT-OF-TREE declaration. A suite whose body carries a base-ref call site
    # can answer differently while the tracked tree is unchanged, so per-suite
    # verdict inheritance must be told about it explicitly
    # (docs/adr/0019-scope-fit-verification-policy.md, decision 2). The
    # obligation is PRESENCE of the field, `yes` or `no` — absence is the only
    # violation. Set equality was rejected: a suite declaring an explicit `no`
    # would violate it, and it would force this lint to decide hermeticity,
    # which a grep cannot. Presence fails closed on the case that matters — a
    # new out-of-tree reader landing silently — and an explicit `no` is the
    # escape, declared where the suite's other properties are declared rather
    # than in a second list to keep in sync.
    #
    # The criterion is `suite_reads_out_of_tree_state` from the sourced
    # library, its single definition site. Re-typing the expression here would
    # be the second copy this lint's own second-home rule rejects.
    oot="$(suite_header_field "$root/$f" out-of-tree-inputs || true)"
    if suite_reads_out_of_tree_state "$root/$f" && [ -z "$oot" ]; then
      violation "$f: reads out-of-tree state (a base-ref call site) but declares no '# out-of-tree-inputs:' — verdict inheritance keyed on declared reach cannot see a dependency that is not declared"
    fi
    if [ -n "$oot" ] && [ "$oot" != yes ] && [ "$oot" != no ]; then
      violation "$f: '# out-of-tree-inputs: $oot' is not one of yes | no"
    fi

    if ! budget="$(suite_header_field "$root/$f" budget-secs)"; then
      violation "$f: no '# budget-secs:' header — an undeclared cost is an unbounded one"
      continue
    fi
    if [ "$budget" = SUITE_BUDGET_CEILING_SECS ]; then
      continue   # the unmeasured case, declared verbatim rather than guessed
    fi
    if ! printf '%s' "$budget" | grep -qE '^[0-9]+$' || [ "$budget" -le 0 ]; then
      violation "$f: '# budget-secs: $budget' is neither a positive integer nor the literal SUITE_BUDGET_CEILING_SECS"
    elif [ "$budget" -gt "$SUITE_BUDGET_CEILING_SECS" ]; then
      violation "$f: '# budget-secs: $budget' exceeds SUITE_BUDGET_CEILING_SECS ($SUITE_BUDGET_CEILING_SECS) — raise the ceiling in scripts/test/suite-manifest.sh deliberately, do not inflate one suite's declaration"
    fi
  done < <(suite_enumerate "$root")
}

# ---------------------------------------------------------------------------
# WORKFLOW group
#
# The step record — `<startline>|<runpaths>|<id>|<if>|<timeout>` — is read by
# scripts/test/invocation-scan.sh's `invscan_workflow_steps`, not by a private
# parser here. The private one matched a `run:` scalar on the step's own line
# only, so a `run: |` block whose body invoked a governed suite produced no
# record and was required to carry neither `id:`, `if:` nor `timeout-minutes:` —
# a bypass route the coverage lint's own rule counted as a registration.
#
# A step's `runpaths` is a SET, because a block-scalar body can invoke several
# paths. A step invoking more than one GOVERNED suite is rejected below: a
# per-suite `if:` guard and a per-suite `timeout-minutes:` cannot be expressed
# for it. The count is over the governed paths alone — the live `select` and
# `reconcile` steps are block scalars invoking several ungoverned `scripts/…`
# paths, and a rejection written over the raw invocation count would red them
# the moment this reader makes them visible.
# ---------------------------------------------------------------------------
check_workflows() {
  local root="$1" wf rel start runpaths sid ifval tmo budget want
  local runpath p governed governed_count
  for wf in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml; do
    [ -f "$wf" ] || continue
    rel="${wf#"$root"/}"
    while IFS='|' read -r start runpaths sid ifval tmo; do
      [ -n "$runpaths" ] || continue

      governed=""
      governed_count=0
      for p in $runpaths; do
        if suite_path_is_governed "$p"; then
          governed="${governed:+$governed }$p"
          governed_count=$((governed_count + 1))
        fi
      done

      if [ "$governed_count" -gt 1 ]; then
        violation "$rel:$start: one step invokes $governed_count governed suites ($governed) — a per-suite 'if:' guard and a per-suite 'timeout-minutes:' cannot be expressed for a step that runs more than one"
        continue
      fi

      runpath="${governed:-${runpaths%% *}}"

      if ! suite_path_is_governed "$runpath"; then
        # Ungoverned: a standing lint or the registry runner. It runs
        # unconditionally, carries no budget header, and is invisible to the
        # reconciliation comparison — nothing is required of it here. A
        # mis-shaped guard is still rejected, since a guard on an ungoverned
        # step would silently skip work nothing reconciles.
        if [ -n "$ifval" ] && printf '%s' "$ifval" | grep -q 'contains(' \
           && ! printf '%s' "$ifval" | grep -qF "contains(format(' {0} '"; then
          violation "$rel:$start: step running $runpath guards on a bare contains() — one suite path is a prefix of another's, so substring matching mis-selects"
        fi
        continue
      fi

      if [ -z "$sid" ]; then
        violation "$rel:$start: governed step running $runpath declares no 'id:' — a step without one is absent from the Actions steps context, so check-step-reconciliation.sh cannot see whether it ran"
      else
        want="$(suite_step_id "$runpath")"
        [ "$sid" = "$want" ] || violation "$rel:$start: governed step running $runpath declares 'id: $sid' but the convention requires 'id: $want' — the outcome key is the only link back to the suite path, so a deviating id makes the step read as absent"
      fi

      if [ -z "$ifval" ]; then
        violation "$rel:$start: governed step running $runpath declares no 'if:' guard — selection is what decides whether it runs"
      elif ! printf '%s' "$ifval" | grep -qF "contains(format(' {0} '" \
           || ! printf '%s' "$ifval" | grep -qF "' $runpath '"; then
        violation "$rel:$start: governed step running $runpath does not test sentinel-delimited membership — use contains(format(' {0} ', steps.select.outputs.suites), ' $runpath ')"
      fi

      if [ -z "$tmo" ]; then
        violation "$rel:$start: governed step running $runpath declares no 'timeout-minutes:' — the declared budget has no CI-side enforcement without it"
        continue
      fi
      # The value agreement needs the suite's own header, so it is checked only
      # where the file is present in this root.
      if [ -f "$root/$runpath" ]; then
        budget="$(suite_budget_secs "$root/$runpath" 2>/dev/null || true)"
        case "$budget" in ''|*[!0-9]*) continue ;; esac
        want="$(suite_budget_minutes "$budget")"
        [ "$tmo" = "$want" ] || violation "$rel:$start: step running $runpath declares 'timeout-minutes: $tmo' but its header's budget-secs ($budget) is ceil()-equal to $want minutes"
      fi
    done < <(invscan_workflow_steps "$wf")
  done
}

# ---------------------------------------------------------------------------
# PIN group — the shared harness ok-count is authored in exactly one file.
# Only the assignment is a home; a consumer that READS the sourced constant is
# not, which is the whole point of single-sourcing.
# ---------------------------------------------------------------------------
check_pin() {
  local root="$1" home='tests/lib/harness-pins.sh' f rel
  [ -f "$root/$home" ] || return 0
  while IFS= read -r f; do
    rel="${f#"$root"/}"
    [ "$rel" = "$home" ] && continue
    violation "$rel: authors the harness ok-count literal (HARNESS_OK_COUNT=<n>), which belongs only in $home — a second home re-introduces the synchronised multi-file bump single-sourcing removed"
  done < <(grep -rlE '^[[:space:]]*HARNESS_OK_COUNT=[0-9]+' "$root/tests" "$root/scripts" 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# CONSTANTS group — the two budget constants are single-homed and in-bounds.
#
# The values are read out of the ROOT's own library file rather than from the
# constants this lint sourced: the subject is the tree being checked, and a
# fixture root supplies its own edited copy. Reading the in-process value would
# make every bounds arm assert against this repository's constant no matter
# which tree was passed.
#
# Skipped entirely when the root carries no library, so a fixture root planted
# only with suites or workflows keeps its own verdict.
# ---------------------------------------------------------------------------
check_constants() {
  local root="$1" home='scripts/test/suite-manifest.sh' spec name rest min why value f rel
  [ -f "$root/$home" ] || return 0

  # name:minimum:meaning-of-the-floor
  for spec in \
    "SUITE_BUDGET_HEADROOM_PERCENT:100:a sub-100 multiplier derives a budget tighter than the measurement it is headroom over — a guessed-tight budget wearing the derivation's name" \
    "SUITE_LOCAL_SLOWDOWN_FACTOR:1:one is the multiplier's identity, at which the local allowance is exactly the declared CI budget; below it the allowance is tighter than a number already measured on the faster clock"
  do
    name="${spec%%:*}"; rest="${spec#*:}"; min="${rest%%:*}"; why="${rest#*:}"

    value="$(grep -m1 -E "^${name}=" "$root/$home" 2>/dev/null | sed -E "s/^${name}=//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//")"
    if [ -z "$value" ]; then
      violation "$home: no '$name=' assignment — the constant's single authoring home is this file"
    elif ! printf '%s' "$value" | grep -qE '^[0-9]+$'; then
      violation "$home: '$name=$value' is not an integer"
    elif [ "$value" -lt "$min" ]; then
      violation "$home: '$name=$value' is below its floor of $min — $why"
    fi

    # Single authoring home. Only a column-1 assignment counts: a suite that
    # greps for the constant, or writes it into a fixture, is not a home.
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rel="${f#"$root"/}"
      [ "$rel" = "$home" ] && continue
      violation "$rel: assigns $name=, which belongs only in $home — a second home makes the constant settable from somewhere the derivation note does not reach"
    done < <(grep -rlE "^${name}=" "$root/scripts" "$root/tests" 2>/dev/null || true)
  done
}

# ---------------------------------------------------------------------------
# STEP-ID group — the enumerated governed set maps one-to-one onto step ids.
# Two suites sharing a basename collapse onto a single outcome key, and the
# reconciliation's report-to-outcome-map link then judges one of them by the
# other's result. The domain is the enumerated set rather than a raw tests/**
# scan: an excluded path never reaches an outcome key, so its basename is free.
# ---------------------------------------------------------------------------
check_step_ids() {
  local root="$1" f id prev
  local -A owner=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id="$(suite_step_id "$f")"
    prev="${owner[$id]:-}"
    if [ -n "$prev" ]; then
      violation "$f: shares the step id '$id' with $prev — two governed suites on one outcome key leave the reconciliation unable to say which of them ran"
    else
      owner["$id"]="$f"
    fi
  done < <(suite_enumerate "$root")
}

# ---------------------------------------------------------------------------
# STEP-ID DERIVATION group — the id derivation is authored in exactly one file.
#
# Stated as a second-home rule rather than as value agreement, for the reason
# check_pin above is: a verbatim second copy agrees on every value it produces,
# which is precisely the state single-sourcing exists to prevent. Both limbs of
# the expression are line-anchored, which is what separates the one derivation
# from the many literal `s-…` id strings the tree's fixtures legitimately carry
# — none of those follows `s-` with a format placeholder or a parameter
# expansion — and what keeps the rule from matching this file's own source.
# ---------------------------------------------------------------------------
check_step_id_home() {
  local root="$1" home='scripts/test/suite-manifest.sh' f rel
  [ -f "$root/$home" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$root"/}"
    [ "$rel" = "$home" ] && continue
    violation "$rel: authors the step-id derivation, which belongs only in $home — a private copy is value-equal on the day it is written and is what drifts the outcome-key link apart"
  done < <(grep -rlE '^[[:space:]]*suite_step_id[[:space:]]*\(\)|^[[:space:]]*(printf|echo)[^#]*s-(%s|\$\{)' "$root/scripts" "$root/tests" 2>/dev/null || true)
}

check_tree() {
  VIOLATIONS=0
  check_headers "$1"
  check_workflows "$1"
  check_pin "$1"
  check_constants "$1"
  check_step_ids "$1"
  check_step_id_home "$1"
  [ "$VIOLATIONS" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Self-test — one fixture per named rule, both arms. On a conforming tree exit 0
# is unfalsifiable, so these are what keep the lint from passing vacuously.
# ---------------------------------------------------------------------------
self_test() {
  local dir rc=0 fails=0
  dir="$(mktemp -d)"

  expect() { # <label> <conform|violation>
    local label="$1" want="$2"
    if check_tree "$dir" >/dev/null 2>&1; then
      if [ "$want" = conform ]; then echo "  SELF-TEST PASS: $label"
      else echo "  SELF-TEST FAIL: $label — expected a violation, got a clean tree"; fails=$((fails + 1)); fi
    else
      if [ "$want" = violation ]; then echo "  SELF-TEST PASS: $label"
      else echo "  SELF-TEST FAIL: $label — expected a clean tree, got:"; check_tree "$dir" | sed 's/^/    /'; fails=$((fails + 1)); fi
    fi
  }

  spec() { # <relpath> <header lines...> ; body on stdin
    local rel="$1"; shift
    mkdir -p "$dir/$(dirname "$rel")"
    { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; cat; } > "$dir/$rel"
  }

  reset() { rm -rf "$dir"; mkdir -p "$dir/tests" "$dir/.github/workflows"; }

  # --- HEADER: lane presence and lane/retire-with coupling ----------------
  reset
  spec tests/test-fx-nolane.sh '# ci-subject: docs/a.md' '# budget-secs: 30' <<< 'true'
  expect "HEADER: a spec with no lane -> violation" violation

  reset
  spec tests/test-fx-cs-noretire.sh '# ci-subject: docs/a.md' '# lane: cycle-scoped' '# budget-secs: 30' <<< 'true'
  expect "HEADER: lane: cycle-scoped without retire-with -> violation" violation

  reset
  spec tests/test-fx-standing-retire.sh '# ci-subject: docs/a.md' '# lane: standing' '# retire-with: #1' '# budget-secs: 30' <<< 'true'
  expect "HEADER: lane: standing carrying retire-with -> violation" violation

  reset
  spec tests/test-fx-ok-standing.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  spec tests/plugin/verify-fx-outside-shape.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  expect "HEADER: valid standing specs, including one outside the test-*.sh shape -> conform" conform

  # --- COUPLINGS ----------------------------------------------------------
  reset
  spec tests/test-fx-cs-noarray.sh '# ci-subject: docs/a.md' '# lane: cycle-scoped' '# retire-with: #1' '# cycle-arm: #1' '# budget-secs: 30' <<< 'true'
  expect "COUPLING (a): cycle-scoped with no allow-list array -> violation" violation

  reset
  spec tests/test-fx-array-standing.sh '# ci-subject: docs/a.md' '# lane: standing' '# cycle-arm: #1' '# budget-secs: 30' <<< 'allow_list=(
  "docs/a.md"
)'
  expect "COUPLING: allow-list array + standing + cycle-arm -> conform (the converse of (a) is not asserted)" conform

  reset
  spec tests/test-fx-array-noarm.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'allow_list=(
  "docs/a.md"
)'
  expect "COUPLING (b): allow-list array with no cycle-arm -> violation" violation

  reset
  spec tests/test-fx-arm-noarray.sh '# ci-subject: docs/a.md' '# lane: standing' '# cycle-arm: #1' '# budget-secs: 30' <<< 'true'
  expect "COUPLING (b): cycle-arm with no allow-list array -> violation" violation

  reset
  spec tests/test-fx-arm-mismatch.sh '# ci-subject: docs/a.md' '# lane: cycle-scoped' '# retire-with: #1' '# cycle-arm: #2' '# budget-secs: 30' <<< 'allow_list=(
  "docs/a.md"
)'
  expect "COUPLING (c): cycle-arm disagreeing with retire-with -> violation" violation

  reset
  spec tests/test-fx-arm-agree.sh '# ci-subject: docs/a.md' '# lane: cycle-scoped' '# retire-with: #1' '# cycle-arm: #1' '# budget-secs: 30' <<< 'allow_list=(
  "docs/a.md"
)'
  expect "COUPLING (c): cycle-scoped + array + agreeing arm/retirement -> conform" conform

  # --- OUT-OF-TREE declaration -------------------------------------------
  # The arm is presence-only, so both arms are needed: a matching body with no
  # field is the violation, and the SAME body declaring `no` conforms. A leg
  # asserting only the first would pass equally under a lint that demanded
  # `yes`, which is the rule this arm deliberately does not implement.
  reset
  spec tests/test-fx-oot-undeclared.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'git merge-base HEAD main'
  expect "OUT-OF-TREE: a base-ref call site with no out-of-tree-inputs field -> violation" violation

  reset
  spec tests/test-fx-oot-no.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' '# out-of-tree-inputs: no' <<< 'git merge-base HEAD main'
  expect "OUT-OF-TREE: the same body declaring an explicit no -> conform (presence is the obligation, not hermeticity)" conform

  reset
  spec tests/test-fx-oot-yes.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' '# out-of-tree-inputs: yes' <<< 'resolve_base_ref ""'
  expect "OUT-OF-TREE: a resolve_base_ref call site declaring yes -> conform" conform

  reset
  spec tests/test-fx-oot-badvalue.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' '# out-of-tree-inputs: maybe' <<< 'git merge-base HEAD main'
  expect "OUT-OF-TREE: a value outside yes | no -> violation" violation

  reset
  spec tests/test-fx-oot-commentonly.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< '# names resolve_base_ref only in a comment
true'
  expect "OUT-OF-TREE: naming the resolver only in a comment does not create the obligation -> conform" conform

  # --- BUDGET bounds ------------------------------------------------------
  reset
  spec tests/test-fx-budget-nonint.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: notanumber' <<< 'true'
  expect "BUDGET: a non-integer budget-secs -> violation" violation

  reset
  spec tests/test-fx-budget-zero.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 0' <<< 'true'
  expect "BUDGET: a non-positive budget-secs -> violation" violation

  reset
  spec tests/test-fx-budget-over.sh '# ci-subject: docs/a.md' '# lane: standing' "# budget-secs: $((SUITE_BUDGET_CEILING_SECS + 1))" <<< 'true'
  expect "BUDGET: a budget-secs above the ceiling -> violation" violation

  reset
  spec tests/test-fx-budget-ceiling.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: SUITE_BUDGET_CEILING_SECS' <<< 'true'
  expect "BUDGET: the unmeasured case declaring the ceiling symbol verbatim -> conform" conform

  # --- WORKFLOW guard shape ----------------------------------------------
  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - name: bare
        if: contains(steps.select.outputs.suites, 'tests/test-fx-guard.sh')
        timeout-minutes: 1
        run: bash tests/test-fx-guard.sh
YML
  expect "WORKFLOW: a bare-contains guard -> violation" violation

  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - name: no-id
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fx-guard.sh ')
        timeout-minutes: 1
        run: bash tests/test-fx-guard.sh
YML
  expect "WORKFLOW: a sentinel guard with no step id -> violation" violation

  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - id: s-test-fx-guard
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fx-guard.sh ')
        timeout-minutes: 1
        run: bash tests/test-fx-guard.sh
YML
  expect "WORKFLOW: the sentinel form with an id -> conform" conform

  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - run: bash scripts/test/check-suite-ci-coverage.sh
      - run: bash tests/run-doc-invariants.sh
YML
  expect "WORKFLOW governed-set boundary: ungoverned lint / registry-runner steps carrying no id, if or timeout-minutes -> conform" conform

  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - run: bash tests/plugin/verify-fx-outside-shape.sh
YML
  expect "WORKFLOW governed-set boundary: a governed step outside the test-*.sh shape is still required to carry the guard shape -> violation" violation

  # --- WORKFLOW block-scalar run: ----------------------------------------
  # A governed suite invoked from a `run: |` body is a governed step record,
  # exactly as the single-line form is. Both arms are required: the negative
  # alone is satisfied by a reader that reds every block scalar.
  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - name: block-no-guard
        run: |
          bash tests/test-fx-guard.sh
YML
  expect "WORKFLOW block scalar: a governed suite invoked from a 'run: |' body with no id/if/timeout-minutes -> violation" violation

  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - id: s-test-fx-guard
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fx-guard.sh ')
        timeout-minutes: 1
        run: |
          bash tests/test-fx-guard.sh
YML
  expect "WORKFLOW block scalar: the same suite invoked from a 'run: |' body carrying the full guard shape -> conform" conform

  # --- WORKFLOW multi-suite step -----------------------------------------
  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - id: s-multi
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fx-a.sh ')
        timeout-minutes: 1
        run: |
          bash tests/test-fx-a.sh
          bash tests/test-fx-b.sh
YML
  expect "WORKFLOW multi-suite: one step invoking TWO governed suites -> violation" violation

  reset
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - id: s-test-fx-a
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fx-a.sh ')
        timeout-minutes: 1
        run: |
          bash scripts/test/check-suite-ci-coverage.sh
          bash tests/test-fx-a.sh
YML
  expect "WORKFLOW multi-suite: one governed suite alongside an ungoverned scripts/… path (the live select/reconcile shape) -> conform" conform

  # --- WORKFLOW timeout agreement ----------------------------------------
  reset
  spec tests/test-fx-timeout.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 90' <<< 'true'
  cat > "$dir/.github/workflows/fx.yml" <<'YML'
jobs:
  j:
    steps:
      - id: s-test-fx-timeout
        if: contains(format(' {0} ', steps.select.outputs.suites), ' tests/test-fx-timeout.sh ')
        timeout-minutes: 1
        run: bash tests/test-fx-timeout.sh
YML
  expect "TIMEOUT: a 90s budget (ceil 2min) against a step declaring 1 -> violation" violation

  sed -i.bak 's/timeout-minutes: 1/timeout-minutes: 2/' "$dir/.github/workflows/fx.yml"; rm -f "$dir/.github/workflows/fx.yml.bak"
  expect "TIMEOUT: an agreeing pair (90s -> ceil 2min) -> conform" conform

  sed -i.bak '/timeout-minutes: 2/d' "$dir/.github/workflows/fx.yml"; rm -f "$dir/.github/workflows/fx.yml.bak"
  expect "TIMEOUT: a governed step declaring no timeout-minutes -> violation" violation

  # --- PIN single authorship ---------------------------------------------
  reset
  mkdir -p "$dir/tests/lib"
  printf 'HARNESS_OK_COUNT=85\n' > "$dir/tests/lib/harness-pins.sh"
  spec tests/test-fx-pin-consumer.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'source tests/lib/harness-pins.sh
[ "$OK" -eq "$HARNESS_OK_COUNT" ]'
  expect "PIN: one authoring home with a sourcing consumer -> conform" conform

  spec tests/test-fx-pin-second-home.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'HARNESS_OK_COUNT=85'
  expect "PIN: a second authoring home -> violation" violation

  # --- STEP-ID collision --------------------------------------------------
  reset
  spec tests/test-fx-collide.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  spec tests/sub/test-fx-collide.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  expect "STEP-ID: two governed suites sharing a basename -> violation" violation

  reset
  spec tests/test-fx-nocollide-a.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  spec tests/sub/test-fx-nocollide-b.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  expect "STEP-ID: two governed suites with distinct basenames -> conform" conform

  # --- STEP-ID single authorship ------------------------------------------
  # The rule's own grading lives here rather than in a suite-side grep: a grep
  # over the tree stays green even if the rule were never reached from
  # check_tree, which is a lint nothing runs.
  # The fixture library is COPIED rather than written inline: a verbatim copy of
  # the derivation in this file would itself be a second home, and the rule
  # would correctly flag its own source.
  reset
  mkdir -p "$dir/scripts/test"
  cp "$SCRIPT_DIR/suite-manifest.sh" "$dir/scripts/test/suite-manifest.sh"
  expect "STEP-ID HOME: the derivation authored only in the library -> conform" conform

  # The planted copy carries the derivation and nothing else the other rules
  # own, so the violation it raises is this rule's and not the CONSTANTS rule's.
  grep -v '^SUITE_' "$SCRIPT_DIR/suite-manifest.sh" > "$dir/scripts/test/check-fx-second-home.sh"
  expect "STEP-ID HOME: a verbatim second copy of the derivation -> violation" violation

  # --- SUBJECT-SET leg ----------------------------------------------------
  reset
  spec tests/test-fx-subject-a.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  spec tests/plugin/verify-fx-subject-b.sh '# ci-subject: docs/a.md' '# lane: standing' '# budget-secs: 30' <<< 'true'
  local enumerated
  enumerated="$(suite_enumerate "$dir")"
  if printf '%s\n' "$enumerated" | grep -qxF 'tests/plugin/verify-fx-subject-b.sh' \
     && printf '%s\n' "$enumerated" | grep -qxF 'tests/test-fx-subject-a.sh'; then
    echo "  SELF-TEST PASS: subject-set leg — the enumeration reaches a filename outside test-*.sh"
  else
    echo "  SELF-TEST FAIL: subject-set leg — enumeration missed a planted spec"
    fails=$((fails + 1))
  fi

  rm -rf "$dir"
  if [ "$fails" -ne 0 ]; then
    echo "check-suite-manifest: --self-test FAILED ($fails of 38 fixture classes misclassified)"
    rc=1
  else
    echo "check-suite-manifest: --self-test OK (38/38 fixture classes classified correctly)"
  fi
  return $rc
}

if [ "$LIST" -eq 1 ]; then
  suite_enumerate "$ROOT"
  exit 0
fi

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

if ! self_test >/dev/null 2>&1; then
  self_test
  echo "check-suite-manifest: detector self-test failed — real-tree result not reported"
  exit 1
fi

if check_tree "$ROOT"; then
  echo "check-suite-manifest: OK — $(suite_enumerate "$ROOT" | grep -c .) suite(s) declared, every governed step guarded and budgeted, pin single-homed"
  exit 0
fi
echo "check-suite-manifest: $VIOLATIONS violation(s)"
echo "  A suite declares its lane, its trigger surface and its cost at creation, and the"
echo "  workflow step that runs it agrees. See docs/autoflow-guide.md > RED > Header contract."
exit 1
