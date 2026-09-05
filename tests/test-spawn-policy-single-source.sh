#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/autoflow/spawn-policy.json scripts/spawn-policy/spawn-policy.sh scripts/lib/plugin-root.sh .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .claude/agents/autoflow-analyzer.md .claude/agents/autoflow-evaluator.md .claude/agents/autoflow-implementer.md .claude/agents/autoflow-loopcheck.md .claude/agents/autoflow-planner.md .claude/agents/autoflow-tester.md CLAUDE.md docs/teammate-contracts.md docs/phases/analysis.md setup/manifest.json setup/init.sh setup/thin-root-layer/drift-check.sh setup/SETUP-GUIDE.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: single-source spawn policy (issue #150)
# =============================================================================
# Holds the policy surface as a whole (.autoflow/issue-150-verification-design.md
# > section 2, `tests/test-spawn-policy-single-source.sh`): a literal
# reintroduced into a workflow script (directly or via a named constant), an
# agent() call with no site() spread, a new site() call with no policy row (or
# a policy row with no call site), a row missing `effort` or carrying an
# unshippable one, an inherit result indistinguishable from an error, a config
# effort value that never reaches the agent definition (or a frontmatter line
# with no config row behind it), an agent definition neither named by a phase
# row nor declared unmapped (or both), an agent_type naming neither a shipped
# definition nor a harness research type, a DIAGNOSE direct spawn documented in
# the phase playbook with no policy row behind it, a `check` that reports a
# partition over a definitions listing it never resolved, an `effort:` line
# grown on a definition the policy does not govern, and policy values
# re-copied back into the prose documents.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="$PROJECT_ROOT/.claude/autoflow/spawn-policy.json"
RESOLVER="$PROJECT_ROOT/scripts/spawn-policy/spawn-policy.sh"
WORKFLOWS=("$PROJECT_ROOT/.claude/workflows/architect-deliberation.js" "$PROJECT_ROOT/.claude/workflows/verify-cause-branch.js")
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
AGENT_TYPES=(autoflow-analyzer autoflow-evaluator autoflow-implementer autoflow-loopcheck autoflow-planner autoflow-tester)

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Hermetic plugin discovery (issues #167 / #169): `spawn-policy.sh check` and
# drift-check.sh now resolve the installed plugin and the marketplace clone
# through scripts/lib/plugin-root.sh from ${CLAUDE_CONFIG_DIR:-~/.claude}. Point
# that at an empty scratch dir so a developer machine's real plugin cache never
# satisfies a "no definitions anywhere" or "SKIP" expectation below; legs that
# need a plugin build one and pass it explicitly.
HERMETIC_CONFIG_DIR="$(mktemp -d)"
export CLAUDE_CONFIG_DIR="$HERMETIC_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT
trap 'rm -rf "$HERMETIC_CONFIG_DIR"' EXIT INT TERM

# -----------------------------------------------------------------------------
# AC1 — no-literal-model
# -----------------------------------------------------------------------------
echo "== AC1: no-literal-model =="

# Form 1: the issue's own single-quoted grep.
_hits1=$(grep -nE "model: *'(opus|sonnet|haiku)'" "${WORKFLOWS[@]}" 2>/dev/null || true)
if [ -z "$_hits1" ]; then
  pass "AC1 form1: no single-quoted model: literal in workflow scripts"
else
  failc "AC1 form1: single-quoted model: literal present -- $_hits1"
fi

# Form 2: double-quoted and shorthand-property spellings of the same key.
_hits2=$(grep -nE 'model:[[:space:]]*"(opus|sonnet|haiku)"' "${WORKFLOWS[@]}" 2>/dev/null || true)
if [ -z "$_hits2" ]; then
  pass "AC1 form2: no double-quoted model: literal in workflow scripts"
else
  failc "AC1 form2: double-quoted model: literal present -- $_hits2"
fi

# Form 3: deliberately narrow — a quoted assignment to a model-name constant.
_hits3=$(grep -nE "(const|let|var)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*=[[:space:]]*['\"](opus|sonnet|haiku)['\"]" "${WORKFLOWS[@]}" 2>/dev/null || true)
if [ -z "$_hits3" ]; then
  pass "AC1 form3: no quoted assignment to a model-name constant"
else
  failc "AC1 form3: quoted model-name constant assignment present -- $_hits3"
fi

# -----------------------------------------------------------------------------
# AC2 — site-key-join (bidirectional set equality between call sites and rows)
# -----------------------------------------------------------------------------
echo "== AC2: site-key-join =="

if [ -f "$CONFIG" ]; then
  for wf_file in "${WORKFLOWS[@]}"; do
    wf_name="$(basename "$wf_file" .js)"
    # Every site('<literal>') call-site key.
    call_keys=$(grep -oE "site\('[^']*'\)" "$wf_file" 2>/dev/null | sed -E "s/site\('([^']*)'\)/\1/" | sort -u)
    # Every key under workflow_sites.<wf_name> in the config.
    row_keys=$(jq -r --arg wf "$wf_name" '.workflow_sites[$wf] // {} | keys[]' "$CONFIG" 2>/dev/null | sort -u)
    missing_row=$(comm -23 <(echo "$call_keys") <(echo "$row_keys") | grep -v '^$' || true)
    missing_call=$(comm -13 <(echo "$call_keys") <(echo "$row_keys") | grep -v '^$' || true)
    if [ -z "$missing_row" ] && [ -z "$missing_call" ]; then
      pass "AC2 site-key-join: $wf_name call sites <-> config rows agree"
    else
      failc "AC2 site-key-join: $wf_name mismatch -- call sites with no row: [$missing_row] rows with no call site: [$missing_call]"
    fi
  done
else
  failc "AC2 site-key-join: $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# AC2 — site-spread-totality (every agent() call site carries site(...), the
# lone policy-load loader exempted)
# -----------------------------------------------------------------------------
echo "== AC2: site-spread-totality =="

for wf_file in "${WORKFLOWS[@]}"; do
  wf_name="$(basename "$wf_file" .js)"
  # Count agent( invocations and site( spreads referenced with ...site(.
  agent_calls=$(grep -oc "agent(" "$wf_file" 2>/dev/null || echo 0)
  spread_calls=$(grep -oE "\.\.\.site\('[^']*'\)" "$wf_file" 2>/dev/null | wc -l | tr -d ' ')
  exempt=$(grep -c "policy-load" "$wf_file" 2>/dev/null || echo 0)
  if [ "$agent_calls" -gt 0 ] && [ "$spread_calls" -gt 0 ] && [ "$((spread_calls + 1))" -ge "$agent_calls" ] && [ "$exempt" -ge 1 ]; then
    pass "AC2 site-spread-totality: $wf_name -- $spread_calls spread call(s) + 1 exempt policy-load ~= $agent_calls agent() call(s)"
  else
    failc "AC2 site-spread-totality: $wf_name -- agent() calls=$agent_calls site() spreads=$spread_calls policy-load exemption present=$exempt"
  fi
done

# -----------------------------------------------------------------------------
# AC2 — resolver-propagation (edit one row in a scratch copy, observe the
# resolved value follow, and nothing else in the scratch tree changes)
# -----------------------------------------------------------------------------
echo "== AC2: resolver-propagation =="

if [ -x "$RESOLVER" ] && [ -f "$CONFIG" ]; then
  SCRATCH="$(mktemp -d)"
  trap 'rm -rf "$SCRATCH"' EXIT
  git -C "$PROJECT_ROOT" ls-files > "$SCRATCH/.filelist" 2>/dev/null
  ( cd "$PROJECT_ROOT" && tar -cf - $(cat "$SCRATCH/.filelist") ) | tar -xf - -C "$SCRATCH"
  ( cd "$SCRATCH" && git init -q \
      && git -c user.email=scratch@test -c user.name=scratch add -A \
      && git -c user.email=scratch@test -c user.name=scratch commit -q -m scratch --allow-empty )

  SCRATCH_CONFIG="$SCRATCH/.claude/autoflow/spawn-policy.json"
  if ! git -C "$SCRATCH" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    failc "AC2 resolver-propagation: scratch repo setup failed -- no HEAD after git init+commit in $SCRATCH"
  else
    first_key=$(jq -r '.phases | keys[0] // empty' "$SCRATCH_CONFIG" 2>/dev/null)
    if [ -n "$first_key" ]; then
      jq --arg k "$first_key" '.phases[$k].model = "haiku"' "$SCRATCH_CONFIG" > "$SCRATCH_CONFIG.tmp" && mv "$SCRATCH_CONFIG.tmp" "$SCRATCH_CONFIG"
      resolved=$(AUTOFLOW_SPAWN_POLICY="$SCRATCH_CONFIG" bash "$SCRATCH/scripts/spawn-policy/spawn-policy.sh" model "$first_key" 2>/dev/null)
      # The scratch tree's own .autoflow/.gitkeep can register as changed here
      # depending on the host tar/git toolchain's permission-bit handling on
      # extraction (bsdtar vs GNU tar) even though its content never changes --
      # it is scratch bookkeeping unrelated to what this leg verifies (config ->
      # resolver propagation), so it is filtered out before the equality check.
      # Any change OUTSIDE .autoflow/ still fails the assertion.
      changed_files=$(cd "$SCRATCH" && git status --porcelain | awk '{print $2}')
      changed_files_relevant=$(printf '%s\n' "$changed_files" | grep -v '^\.autoflow/' | grep -v '^$')
      if [ "$resolved" = "haiku" ] && [ "$changed_files_relevant" = ".claude/autoflow/spawn-policy.json" ]; then
        pass "AC2 resolver-propagation: editing $first_key.model propagates, only the config changed"
      else
        failc "AC2 resolver-propagation: resolved='$resolved' (want haiku) changed_files='$changed_files' relevant='$changed_files_relevant' (want only the config)"
      fi
    else
      failc "AC2 resolver-propagation: could not read a phases[] key from the scratch config"
    fi
  fi
else
  failc "AC2 resolver-propagation: $RESOLVER not executable or $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# AC3 — effort-field-total
# -----------------------------------------------------------------------------
echo "== AC3: effort-field-total =="

if [ -f "$CONFIG" ]; then
  missing_phase_effort=$(jq -r '.phases | to_entries[] | select((.value.effort // null) == null) | .key' "$CONFIG" 2>/dev/null)
  missing_site_effort=$(jq -r '.workflow_sites | to_entries[] | .key as $wf | .value | to_entries[] | select((.value.effort // null) == null) | ($wf + "." + .key)' "$CONFIG" 2>/dev/null)
  if [ -z "$missing_phase_effort" ] && [ -z "$missing_site_effort" ]; then
    pass "AC3 effort-field-total: every phases[] and workflow_sites[][] row carries effort"
  else
    failc "AC3 effort-field-total: phases missing effort=[$missing_phase_effort] workflow_sites missing effort=[$missing_site_effort]"
  fi
else
  failc "AC3 effort-field-total: $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# AC3 — diagnose-domain-enumeration (standing; the domain's completeness, not
# its values). Explicit prose-name -> key mapping, per feature design §3.
# -----------------------------------------------------------------------------
echo "== AC3: diagnose-domain-enumeration =="

ANALYSIS_MD="$PROJECT_ROOT/docs/phases/analysis.md"
if [ -f "$CONFIG" ] && [ -f "$ANALYSIS_MD" ]; then
  # The five DIAGNOSE direct spawns docs/phases/analysis.md > Spawn channel
  # enumerates, each mapped to its policy key.
  expected_keys="diagnose-intake-triage diagnose-loopcheck diagnose-phase-a diagnose-phase-b diagnose-phase-3"
  spawn_channel_line=$(grep -n "^Spawn channel:" "$ANALYSIS_MD" 2>/dev/null)
  all_named=1
  for name in "intake readiness triage" "Phase A" "Phase B" "Phase 3" "review-response loop check"; do
    echo "$spawn_channel_line" | grep -qi "$name" || all_named=0
  done
  actual_keys=$(jq -r '.phases | keys[]' "$CONFIG" 2>/dev/null | grep '^diagnose-' | sort | tr '\n' ' ' | sed 's/ $//')
  expected_sorted=$(echo "$expected_keys" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')
  if [ "$all_named" = "1" ] && [ -n "$spawn_channel_line" ] && [ "$actual_keys" = "$expected_sorted" ]; then
    pass "AC3 diagnose-domain-enumeration: diagnose-* phases keys == Spawn channel enumeration"
  else
    failc "AC3 diagnose-domain-enumeration: spawn_channel_line_found=$([ -n "$spawn_channel_line" ] && echo yes || echo no) all_named=$all_named actual_keys=[$actual_keys] expected=[$expected_sorted]"
  fi
else
  failc "AC3 diagnose-domain-enumeration: $CONFIG or $ANALYSIS_MD not found"
fi

# -----------------------------------------------------------------------------
# AC4 — inherit-marker: (exit code, stdout) pair distinguishes inherit /
# concrete / unknown-key.
# -----------------------------------------------------------------------------
echo "== AC4: inherit-marker =="

if [ -x "$RESOLVER" ] && [ -f "$CONFIG" ]; then
  # Inherit case: use a shipped inheriting row when the sample carries one;
  # otherwise construct one in a scratch copy -- since issue #180 every shipped
  # row carries an explicit effort, and the sample is a target-owned scaffold
  # whose values this suite must not assume.
  inherit_key=$(jq -r '.phases | to_entries[] | select(.value.effort == "inherit") | .key' "$CONFIG" 2>/dev/null | head -n1)
  inherit_cfg="$CONFIG"; inherit_resolver="$RESOLVER"
  if [ -z "$inherit_key" ]; then
    SCRATCH_INH="$(mktemp -d)"
    cp -R "$PROJECT_ROOT/scripts/spawn-policy" "$SCRATCH_INH/" 2>/dev/null
    mkdir -p "$SCRATCH_INH/.claude/autoflow"
    jq '.phases["__test_inherit__"] = {"agent_type":"autoflow-tester","model":"sonnet","effort":"inherit","work_type":"test"}' "$CONFIG" > "$SCRATCH_INH/.claude/autoflow/spawn-policy.json"
    inherit_key="__test_inherit__"; inherit_cfg="$SCRATCH_INH/.claude/autoflow/spawn-policy.json"; inherit_resolver="$SCRATCH_INH/spawn-policy/spawn-policy.sh"
  fi
  out=$(AUTOFLOW_SPAWN_POLICY="$inherit_cfg" bash "$inherit_resolver" effort "$inherit_key" 2>/dev/null); rc=$?
  if [ "$rc" = "0" ] && [ "$out" = "inherit" ]; then
    pass "AC4 inherit-marker: inheriting row '$inherit_key' -> exit 0, stdout 'inherit'"
  else
    failc "AC4 inherit-marker: inheriting row '$inherit_key' -> exit $rc, stdout '$out' (want 0, 'inherit')"
  fi

  # Concrete-value case: construct one in a scratch copy (the shipped rows'
  # values are the sample's, not this suite's, to assume).
  SCRATCH2="$(mktemp -d)"
  cp -R "$PROJECT_ROOT/scripts/spawn-policy" "$SCRATCH2/" 2>/dev/null
  mkdir -p "$SCRATCH2/.claude/autoflow"
  jq '.phases["__test_concrete__"] = {"agent_type":"autoflow-tester","model":"sonnet","effort":"high","work_type":"test"}' "$CONFIG" > "$SCRATCH2/.claude/autoflow/spawn-policy.json"
  out2=$(AUTOFLOW_SPAWN_POLICY="$SCRATCH2/.claude/autoflow/spawn-policy.json" bash "$SCRATCH2/spawn-policy/spawn-policy.sh" effort "__test_concrete__" 2>/dev/null); rc2=$?
  if [ "$rc2" = "0" ] && [ "$out2" = "high" ]; then
    pass "AC4 inherit-marker: declaring row -> exit 0, stdout the concrete value"
  else
    failc "AC4 inherit-marker: declaring row -> exit $rc2, stdout '$out2' (want 0, 'high')"
  fi
  rm -rf "$SCRATCH2"

  out3=$(bash "$RESOLVER" effort "__totally_unknown_key_xyz__" 2>/dev/null); rc3=$?
  if [ "$rc3" = "1" ] && [ -z "$out3" ]; then
    pass "AC4 inherit-marker: unknown key -> exit 1, empty stdout"
  else
    failc "AC4 inherit-marker: unknown key -> exit $rc3, stdout '$out3' (want 1, empty)"
  fi
else
  failc "AC4 inherit-marker: $RESOLVER not executable or $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# AC4 — effort-value-admission: the config's own admitted set, uniform across
# row kinds, with the named negative case `med`.
# -----------------------------------------------------------------------------
echo "== AC4: effort-value-admission =="

if [ -x "$RESOLVER" ] && [ -f "$CONFIG" ]; then
  # Named negative case: `med` is rejected on a phases row.
  SCRATCH3="$(mktemp -d)"
  cp -R "$PROJECT_ROOT/scripts/spawn-policy" "$SCRATCH3/" 2>/dev/null
  mkdir -p "$SCRATCH3/.claude/autoflow" "$SCRATCH3/.claude/agents"
  cp "$AGENTS_DIR"/*.md "$SCRATCH3/.claude/agents/" 2>/dev/null
  # Positive control: the unmodified config, in this same repaired SCRATCH3
  # tree (agent definitions present), must pass check on its own -- so each
  # negative below discriminates on the effort predicate alone, not on the
  # base-resolution guard (spawn-policy.sh:200-203) firing unconditionally.
  cp "$CONFIG" "$SCRATCH3/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH3/.claude/autoflow/spawn-policy.json" bash "$SCRATCH3/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_control=$?
  if [ "$rc_control" = "0" ]; then
    pass "AC4 effort-value-admission: unmodified config in the repaired SCRATCH3 tree passes check (positive control)"
  else
    failc "AC4 effort-value-admission: unmodified config in the repaired SCRATCH3 tree FAILS check (exit $rc_control) -- negatives below would be vacuous"
  fi

  first_phase_key=$(jq -r '.phases | keys[0]' "$CONFIG")
  jq --arg k "$first_phase_key" '.phases[$k].effort = "med"' "$CONFIG" > "$SCRATCH3/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH3/.claude/autoflow/spawn-policy.json" bash "$SCRATCH3/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_med=$?
  if [ "$rc_med" != "0" ]; then
    pass "AC4 effort-value-admission: 'med' rejected on a phases[] row (exit $rc_med)"
  else
    failc "AC4 effort-value-admission: 'med' was NOT rejected on a phases[] row (exit 0)"
  fi

  # Missing effort key entirely is rejected too.
  jq --arg k "$first_phase_key" 'del(.phases[$k].effort)' "$CONFIG" > "$SCRATCH3/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH3/.claude/autoflow/spawn-policy.json" bash "$SCRATCH3/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_missing=$?
  if [ "$rc_missing" != "0" ]; then
    pass "AC4 effort-value-admission: an absent effort key is rejected (exit $rc_missing)"
  else
    failc "AC4 effort-value-admission: an absent effort key was NOT rejected (exit 0)"
  fi

  # Same predicate on a workflow_sites row -- no agent_type conditional.
  first_wf=$(jq -r '.workflow_sites | keys[0]' "$CONFIG")
  first_site=$(jq -r --arg wf "$first_wf" '.workflow_sites[$wf] | keys[0]' "$CONFIG")
  jq --arg wf "$first_wf" --arg s "$first_site" '.workflow_sites[$wf][$s].effort = "med"' "$CONFIG" > "$SCRATCH3/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH3/.claude/autoflow/spawn-policy.json" bash "$SCRATCH3/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_med_site=$?
  if [ "$rc_med_site" != "0" ]; then
    pass "AC4 effort-value-admission: 'med' rejected on a workflow_sites[][] row too (no agent_type conditional)"
  else
    failc "AC4 effort-value-admission: 'med' was NOT rejected on a workflow_sites[][] row"
  fi

  # The real config, unmodified, must pass check.
  bash "$RESOLVER" check >/dev/null 2>&1
  rc_real=$?
  if [ "$rc_real" = "0" ]; then
    pass "AC4 effort-value-admission: the real config passes check"
  else
    failc "AC4 effort-value-admission: the real config fails check (exit $rc_real)"
  fi
  rm -rf "$SCRATCH3"
else
  failc "AC4 effort-value-admission: $RESOLVER not executable or $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# O7 — required-key-declaration-join (issue #150 cycle 2, verification design
# > §1 `required-key-declaration-join`, feature design §1 "Keeping the list
# honest"). Widens the AC2 site-key-join two-way comparison above to a
# three-way equality: the marker-delimited required-key declaration each
# workflow script is expected to carry (/* site-keys:begin */ ... /* site-
# keys:end */, bare quoted keys) must equal BOTH the site('<literal>') call-
# site keys extracted OUTSIDE the marker range AND the config's own rows for
# that workflow. No markers exist in the tree yet, so this leg is Red until
# the totality-check implementation adds them.
# -----------------------------------------------------------------------------
echo "== O7: required-key-declaration-join =="

if [ -f "$CONFIG" ]; then
  for wf_file in "${WORKFLOWS[@]}"; do
    wf_name="$(basename "$wf_file" .js)"
    marker_keys=$(sed -n '/site-keys:begin/,/site-keys:end/p' "$wf_file" 2>/dev/null | grep -oE "'[^']*'" | tr -d "'" | sort -u)
    call_keys_excl=$(sed '/site-keys:begin/,/site-keys:end/d' "$wf_file" 2>/dev/null | grep -oE "site\('[^']*'\)" | sed -E "s/site\('([^']*)'\)/\1/" | sort -u)
    row_keys=$(jq -r --arg wf "$wf_name" '.workflow_sites[$wf] // {} | keys[]' "$CONFIG" 2>/dev/null | sort -u)
    if [ -n "$marker_keys" ] && [ "$marker_keys" = "$call_keys_excl" ] && [ "$marker_keys" = "$row_keys" ]; then
      pass "O7 required-key-declaration-join: $wf_name -- declared list, call-site keys (outside markers) and config rows all agree"
    else
      failc "O7 required-key-declaration-join: $wf_name -- declared=[$marker_keys] call-sites(outside markers)=[$call_keys_excl] config-rows=[$row_keys]"
    fi
  done
else
  failc "O7 required-key-declaration-join: $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# O7 — effort-vocabulary-from-config (verification design > §1
# `effort-vocabulary-from-config`, feature design §3 policy-vocabulary-self-
# read, DCR-9). The positive control (arm a) is already exercised by AC4
# effort-value-admission above (the unmodified config passes check). These
# four arms are the ones a hardcoded shell vocabulary cannot satisfy:
#   (b) a value ADDED to admitted_values and used on a row is ADMITTED
#   (c) a value REMOVED from admitted_values while a row still carries it is REJECTED
#   (d) an arbitrary, previously-unenumerated model string is ADMITTED (unvalidated)
#   (e) the <integer> meta-token's ABSENCE rejects a JSON-integer effort value
# -----------------------------------------------------------------------------
echo "== O7: effort-vocabulary-from-config =="

if [ -x "$RESOLVER" ] && [ -f "$CONFIG" ]; then
  SCRATCH6="$(mktemp -d)"
  cp -R "$PROJECT_ROOT/scripts/spawn-policy" "$SCRATCH6/" 2>/dev/null
  mkdir -p "$SCRATCH6/.claude/autoflow" "$SCRATCH6/.claude/agents"
  cp "$AGENTS_DIR"/*.md "$SCRATCH6/.claude/agents/" 2>/dev/null
  SCRATCH6_CFG="$SCRATCH6/.claude/autoflow/spawn-policy.json"
  first_wf6=$(jq -r '.workflow_sites | keys[0]' "$CONFIG")
  first_site6=$(jq -r --arg wf "$first_wf6" '.workflow_sites[$wf] | keys[0]' "$CONFIG")
  first_phase6=$(jq -r '.phases | keys[0]' "$CONFIG")

  # (b) added value is admitted
  jq --arg wf "$first_wf6" --arg s "$first_site6" \
    '.effort_contract.admitted_values += ["custom_added_effort"] | .workflow_sites[$wf][$s].effort = "custom_added_effort"' \
    "$CONFIG" > "$SCRATCH6_CFG"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH6_CFG" bash "$SCRATCH6/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "O7 effort-vocabulary-from-config (b): a value ADDED to admitted_values and used on a row is admitted"
  else
    failc "O7 effort-vocabulary-from-config (b): a value added to the config's own admitted_values was still rejected -- the vocabulary is not being read from the config"
  fi

  # (c) removed value is rejected even though a hardcoded set would still admit it.
  # A workflow_sites[][] row is used (not a phases[] row) so the discriminating
  # rejection comes from the effort-vocabulary predicate alone -- a phases[] row
  # sharing agent_type with another phase would instead be rejected by the
  # unrelated divergent-effort-per-agent-type check, which is satisfied by the
  # unmodified admitted_values already and would pass vacuously.
  jq '.effort_contract.admitted_values -= ["xhigh"] | .workflow_sites["verify-cause-branch"]["ledger"].effort = "xhigh"' \
    "$CONFIG" > "$SCRATCH6_CFG"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH6_CFG" bash "$SCRATCH6/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    pass "O7 effort-vocabulary-from-config (c): a value REMOVED from admitted_values is rejected even though a hardcoded set would still admit it"
  else
    failc "O7 effort-vocabulary-from-config (c): 'xhigh' was admitted after being removed from the config's own admitted_values -- the check is reading a hardcoded set, not the config"
  fi

  # (d) arbitrary model string is unvalidated
  jq --arg k "$first_phase6" '.phases[$k].model = "custom-model-xyz"' "$CONFIG" > "$SCRATCH6_CFG"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH6_CFG" bash "$SCRATCH6/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "O7 effort-vocabulary-from-config (d): an arbitrary, previously-unenumerated model string is admitted (models are unvalidated)"
  else
    failc "O7 effort-vocabulary-from-config (d): an arbitrary model string was rejected -- model admission must be dropped to presence/shape only"
  fi

  # (e) <integer> meta-token's absence rejects a JSON-integer effort
  jq --arg wf "$first_wf6" --arg s "$first_site6" \
    '.effort_contract.admitted_values -= ["<integer>"] | .workflow_sites[$wf][$s].effort = 3' \
    "$CONFIG" > "$SCRATCH6_CFG"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH6_CFG" bash "$SCRATCH6/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    pass "O7 effort-vocabulary-from-config (e): a JSON-integer effort is rejected once the <integer> meta-token is removed from admitted_values"
  else
    failc "O7 effort-vocabulary-from-config (e): a JSON-integer effort was admitted despite <integer> being absent from admitted_values -- the meta-token is not being interpreted"
  fi

  rm -rf "$SCRATCH6"
else
  failc "O7 effort-vocabulary-from-config: $RESOLVER not executable or $CONFIG not found"
fi

# -----------------------------------------------------------------------------
# O7 — stamp-semantic-matches-declaration (verification design > §1, DCR-8).
# Declaration arm: the manifest's kind for spawn-policy.json. Behavioral arm:
# a real setup/init.sh run into scratch targets, and setup/thin-root-layer/
# drift-check.sh over an operator-edited target.
# -----------------------------------------------------------------------------
echo "== O7: stamp-semantic-matches-declaration =="

MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"
manifest_kind=$(jq -r '.artifacts[] | select(.dest == ".claude/autoflow/spawn-policy.json") | .kind' "$MANIFEST_JSON" 2>/dev/null)
if [ "$manifest_kind" = "scaffold" ]; then
  pass "O7 stamp-semantic-matches-declaration: setup/manifest.json declares spawn-policy.json kind=scaffold"
else
  failc "O7 stamp-semantic-matches-declaration: setup/manifest.json declares kind='$manifest_kind', expected 'scaffold'"
fi

if [ -x "$PROJECT_ROOT/setup/init.sh" ]; then
  T1="$(mktemp -d)"
  bash "$PROJECT_ROOT/setup/init.sh" --target "$T1" >/dev/null 2>&1
  if [ -f "$T1/.claude/autoflow/spawn-policy.json" ]; then
    pass "O7 stamp-semantic-matches-declaration: init.sh creates spawn-policy.json in a target lacking it"
  else
    failc "O7 stamp-semantic-matches-declaration: init.sh did NOT create spawn-policy.json in an empty target"
  fi

  T2="$(mktemp -d)"
  bash "$PROJECT_ROOT/setup/init.sh" --target "$T2" >/dev/null 2>&1
  SENTINEL='{"__test_sentinel__":"operator-configured-value-must-survive-restamp"}'
  printf '%s' "$SENTINEL" > "$T2/.claude/autoflow/spawn-policy.json"
  bash "$PROJECT_ROOT/setup/init.sh" --target "$T2" --force >/dev/null 2>&1
  after=$(cat "$T2/.claude/autoflow/spawn-policy.json" 2>/dev/null)
  if [ "$after" = "$SENTINEL" ]; then
    pass "O7 stamp-semantic-matches-declaration: a re-stamp, even under --force, does not overwrite an operator-configured spawn-policy.json"
  else
    failc "O7 stamp-semantic-matches-declaration: a re-stamp overwrote the operator's configured spawn-policy.json (expected preserved sentinel, got: $after)"
  fi

  if [ -f "$T2/.claude/autoflow/drift-check.sh" ]; then
    drift_out=$(CLAUDE_PROJECT_DIR="$T2" sh "$T2/.claude/autoflow/drift-check.sh" 2>&1)
    if echo "$drift_out" | grep -qE "scaffold:.*spawn-policy\.json present"; then
      pass "O7 stamp-semantic-matches-declaration: drift-check.sh reports spawn-policy.json as target-owned (scaffold), not content drift"
    else
      failc "O7 stamp-semantic-matches-declaration: drift-check.sh did NOT report spawn-policy.json as a target-owned scaffold artifact"
    fi
  else
    failc "O7 stamp-semantic-matches-declaration: drift-check.sh was not installed into the scratch target"
  fi
  rm -rf "$T1" "$T2"
else
  failc "O7 stamp-semantic-matches-declaration: $PROJECT_ROOT/setup/init.sh not executable"
fi

# -----------------------------------------------------------------------------
# O7 — sample-contract-documented (verification design > §1). The config
# states, in its own body, that its values are a stamp-time sample rather
# than an enforced universal vocabulary; the introducing documents (CLAUDE.md
# Spawn Model, setup/SETUP-GUIDE.md) say the same. Vocabulary declared here:
# the config carries a top-level string field `sample_contract` naming both
# "sample" and "stamp"; CLAUDE.md's Spawn Model section and setup/SETUP-
# GUIDE.md each name "scaffold" beside "spawn-policy.json". A presence
# predicate over a named field / section, never a prose-similarity match.
# -----------------------------------------------------------------------------
echo "== O7: sample-contract-documented =="

cfg_sample_contract=$(jq -r '.sample_contract // empty' "$CONFIG" 2>/dev/null)
if echo "$cfg_sample_contract" | grep -qi "sample" && echo "$cfg_sample_contract" | grep -qi "stamp"; then
  pass "O7 sample-contract-documented: $CONFIG carries a top-level sample_contract field naming both 'sample' and 'stamp'"
else
  failc "O7 sample-contract-documented: $CONFIG has no top-level sample_contract field naming both 'sample' and 'stamp' (got: '$cfg_sample_contract')"
fi

CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  spawn_section=$(awk '/^## Spawn Model/{flag=1} /^## [A-Z]/{if (flag && !/^## Spawn Model/) exit} flag' "$CLAUDE_MD")
  if echo "$spawn_section" | grep -qi "scaffold"; then
    pass "O7 sample-contract-documented: CLAUDE.md > Spawn Model section names 'scaffold' beside the config pointer"
  else
    failc "O7 sample-contract-documented: CLAUDE.md > Spawn Model section does not name 'scaffold'"
  fi
else
  failc "O7 sample-contract-documented: $CLAUDE_MD not found"
fi

SETUP_GUIDE="$PROJECT_ROOT/setup/SETUP-GUIDE.md"
if [ -f "$SETUP_GUIDE" ] && grep -qi "scaffold" "$SETUP_GUIDE" && grep -q "spawn-policy" "$SETUP_GUIDE"; then
  pass "O7 sample-contract-documented: setup/SETUP-GUIDE.md names the scaffold disposition beside spawn-policy.json"
else
  failc "O7 sample-contract-documented: setup/SETUP-GUIDE.md does not name the scaffold disposition beside spawn-policy.json"
fi

# -----------------------------------------------------------------------------
# AC5 — no-duplicated-policy
# -----------------------------------------------------------------------------
echo "== AC5: no-duplicated-policy =="

CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  start_line=$(grep -n "^## Spawn Model — Phase-by-Phase" "$CLAUDE_MD" | head -n1 | cut -d: -f1)
  end_line=$(awk -v s="$start_line" 'NR>s && /^## /{print NR-1; exit}' "$CLAUDE_MD")
  if [ -n "$start_line" ] && [ -n "$end_line" ]; then
    section=$(sed -n "${start_line},${end_line}p" "$CLAUDE_MD")
    # Phase names: any phases[] row's source-table phase name, plus ARCHITECT.
    phase_names="PREFLIGHT DIAGNOSE GATE:HYPOTHESIS ARCHITECT GATE:PLAN DISPATCH RED GREEN VERIFY REFINE VALIDATE AUDIT GATE:QUALITY DELIVER INTEGRATE HANDOFF"
    offenders=""
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      has_model=$(echo "$line" | grep -qE '`(opus|sonnet|haiku)`' && echo 1 || echo 0)
      [ "$has_model" = "1" ] || continue
      for pn in $phase_names; do
        if echo "$line" | grep -qF "$pn"; then
          offenders="$offenders|$line"
        fi
      done
    done <<< "$section"
    if grep -qF ".claude/autoflow/spawn-policy.json" <<< "$section" && [ -z "$offenders" ]; then
      pass "AC5 no-duplicated-policy: CLAUDE.md Spawn Model section has no phase+model co-occurrence line, and points at the config"
    else
      failc "AC5 no-duplicated-policy: CLAUDE.md Spawn Model section offenders=[$offenders] config-pointer-present=$(grep -qF '.claude/autoflow/spawn-policy.json' <<< "$section" && echo yes || echo no)"
    fi
  else
    failc "AC5 no-duplicated-policy: could not bound the CLAUDE.md Spawn Model section"
  fi
else
  failc "AC5 no-duplicated-policy: $CLAUDE_MD not found"
fi

# Secondary documents: whole-file range, no backtick span with a model word.
for doc in "docs/teammate-contracts.md" "docs/phases/analysis.md"; do
  docpath="$PROJECT_ROOT/$doc"
  if [ -f "$docpath" ]; then
    hits=$(grep -noE '`[^`]*`' "$docpath" | grep -iE 'sonnet|opus|haiku' || true)
    if [ -z "$hits" ]; then
      pass "AC5 no-duplicated-policy: $doc carries no backtick-delimited span naming a model tier"
    else
      failc "AC5 no-duplicated-policy: $doc still carries a model-tier backtick span -- $hits"
    fi
  else
    failc "AC5 no-duplicated-policy: $docpath not found"
  fi
done

# -----------------------------------------------------------------------------
# Design-added — policy-load bootstrap call admitted by the gate hook
# -----------------------------------------------------------------------------
echo "== design-added: policy-load bootstrap admission =="

HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
if [ -f "$HOOK" ]; then
  # A payload shaped like an in-script agent() call: no subagent_type, no model
  # -- what the matcher would see if it ever started intercepting these calls.
  payload='{"tool_name":"Agent","tool_input":{"prompt":"policy-load"}}'
  out=$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$PROJECT_ROOT" bash "$HOOK" 2>&1); rc=$?
  # Recorded, not asserted as a fix target: today's Section 1b denies any
  # Agent payload with no model (design §5.3 -- the loader is never SEEN by
  # the matcher during a real deliberation run, so this records the verdict
  # the matcher would emit if it ever did).
  echo "  RECORD: policy-load-shaped payload -> exit $rc"
  if [ "$rc" = "2" ]; then
    pass "design-added: policy-load-shaped payload denied by Section 1b today (exit 2), as feature design §5.3 records"
  else
    failc "design-added: policy-load-shaped payload -> exit $rc (expected 2, matching feature design §5.3's own derivation)"
  fi
else
  failc "design-added: policy-load bootstrap admission -- $HOOK not found"
fi

# -----------------------------------------------------------------------------
# Design-added — frontmatter-projection
# -----------------------------------------------------------------------------
echo "== design-added: frontmatter-projection =="

if [ -x "$RESOLVER" ]; then
  for t in "${AGENT_TYPES[@]}"; do
    def="$AGENTS_DIR/$t.md"
    out=$(bash "$RESOLVER" agent-effort "$t" 2>/dev/null); rc=$?
    has_line=$(grep -qE '^effort:' "$def" 2>/dev/null && echo 1 || echo 0)
    if [ "$rc" != "0" ]; then
      failc "design-added: frontmatter-projection -- agent-effort $t exited $rc"
      continue
    fi
    case "$out" in
      inherit|unmapped)
        if [ "$has_line" = "0" ]; then
          pass "design-added: frontmatter-projection -- $t ($out) carries no effort: line"
        else
          failc "design-added: frontmatter-projection -- $t ($out) carries an effort: line but should not"
        fi
        ;;
      *)
        actual_line=$(grep -E '^effort:' "$def" 2>/dev/null | head -n1)
        if [ "$actual_line" = "effort: $out" ]; then
          pass "design-added: frontmatter-projection -- $t carries 'effort: $out'"
        else
          failc "design-added: frontmatter-projection -- $t agent-effort='$out' but frontmatter line='$actual_line'"
        fi
        ;;
    esac
  done
else
  failc "design-added: frontmatter-projection -- $RESOLVER not executable"
fi

# -----------------------------------------------------------------------------
# Design-added — agent-type-membership / agent-type-partition
# -----------------------------------------------------------------------------
echo "== design-added: agent-type-membership / agent-type-partition =="

if [ -f "$CONFIG" ] && [ -d "$AGENTS_DIR" ]; then
  research_types="Explore Plan claude-code-guide"
  def_basenames=$(ls "$AGENTS_DIR" 2>/dev/null | sed 's/\.md$//' | sort)
  phase_types=$(jq -r '.phases[].agent_type' "$CONFIG" 2>/dev/null | sort -u)
  bad_types=""
  for pt in $phase_types; do
    is_def=$(echo "$def_basenames" | grep -qxF "$pt" && echo 1 || echo 0)
    is_research=0
    for rt in $research_types; do [ "$pt" = "$rt" ] && is_research=1; done
    if [ "$is_def" = "0" ] && [ "$is_research" = "0" ]; then
      bad_types="$bad_types $pt"
    fi
  done
  if [ -z "$bad_types" ]; then
    pass "design-added: agent-type-membership -- every phases[].agent_type is a shipped definition or a research type"
  else
    failc "design-added: agent-type-membership -- unrecognised agent_type(s):$bad_types"
  fi

  autoflow_phase_types=$(echo "$phase_types" | grep '^autoflow-' | sort -u)
  unmapped_keys=$(jq -r '.policy_unmapped_agent_types // {} | keys[]' "$CONFIG" 2>/dev/null | sort -u)
  union=$(printf '%s\n%s\n' "$autoflow_phase_types" "$unmapped_keys" | grep -v '^$' | sort -u)
  disjoint_violation=$(comm -12 <(echo "$autoflow_phase_types") <(echo "$unmapped_keys") | grep -v '^$' || true)
  set_diff=$(diff <(echo "$def_basenames") <(echo "$union") || true)
  if [ -z "$set_diff" ] && [ -z "$disjoint_violation" ]; then
    pass "design-added: agent-type-partition -- definitions == (autoflow-* phase types) ∪ (unmapped keys), disjoint"
  else
    failc "design-added: agent-type-partition -- diff=[$set_diff] disjoint_violation=[$disjoint_violation]"
  fi

  # spawn-policy.sh check enforces the same partition, independently.
  if [ -x "$RESOLVER" ]; then
    bash "$RESOLVER" check >/dev/null 2>&1
    if [ $? = 0 ]; then
      pass "design-added: agent-type-partition -- spawn-policy.sh check agrees (exit 0)"
    else
      failc "design-added: agent-type-partition -- spawn-policy.sh check exits non-zero on the real tree"
    fi
  fi
else
  failc "design-added: agent-type-membership / agent-type-partition -- $CONFIG or $AGENTS_DIR not found"
fi

# -----------------------------------------------------------------------------
# Design-added — check-base-resolution (the partition rule's own filesystem
# resolution must not default to an empty, vacuously-true set)
# -----------------------------------------------------------------------------
echo "== design-added: check-base-resolution =="

if [ -f "$CONFIG" ] && [ -x "$RESOLVER" ]; then
  SCRATCH4="$(mktemp -d)"
  mkdir -p "$SCRATCH4/no-agents/.claude/autoflow" "$SCRATCH4/with-agents/.claude/autoflow" "$SCRATCH4/with-agents/.claude/agents"
  cp "$CONFIG" "$SCRATCH4/no-agents/.claude/autoflow/spawn-policy.json"
  cp "$CONFIG" "$SCRATCH4/with-agents/.claude/autoflow/spawn-policy.json"
  cp "$AGENTS_DIR"/*.md "$SCRATCH4/with-agents/.claude/agents/" 2>/dev/null

  AUTOFLOW_SPAWN_POLICY="$SCRATCH4/no-agents/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>"$SCRATCH4/no-agents.err"
  rc_no=$?
  if [ "$rc_no" = "1" ] && [ -s "$SCRATCH4/no-agents.err" ]; then
    pass "design-added: check-base-resolution -- base with no .claude/agents/ -> exit 1 with a stderr message"
  else
    failc "design-added: check-base-resolution -- base with no .claude/agents/ -> exit $rc_no (want 1 with a message)"
  fi

  AUTOFLOW_SPAWN_POLICY="$SCRATCH4/with-agents/.claude/autoflow/spawn-policy.json" bash "$RESOLVER" check >/dev/null 2>&1
  rc_with=$?
  if [ "$rc_with" = "0" ]; then
    pass "design-added: check-base-resolution -- base carrying a full definitions copy -> exit 0"
  else
    failc "design-added: check-base-resolution -- base carrying a full definitions copy -> exit $rc_with (want 0)"
  fi
  rm -rf "$SCRATCH4"
else
  failc "design-added: check-base-resolution -- $CONFIG or $RESOLVER not found"
fi

# -----------------------------------------------------------------------------
# Issue #169 — thin-root layout: the target tree ships NO .claude/agents (the
# manifest delivers spawn-policy.json + spawn-policy.sh only), the definitions
# live in the installed plugin's agents/. `check` must pass there without a
# symlink, resolving the plugin through the same helper drift-check D2 uses
# (issue #167), and must still fail closed — naming what it consulted — when
# no definitions exist anywhere.
# -----------------------------------------------------------------------------
echo "== issue #169: check agent-definition lookup on a thin-root target =="

PLUGIN_SRC="$PROJECT_ROOT/plugin/autoflow"
if [ -f "$CONFIG" ] && [ -x "$RESOLVER" ] && [ -d "$PLUGIN_SRC/agents" ]; then
  SCRATCH7="$(mktemp -d)"
  # The thin-root target: config + the shipped readout, no .claude/agents.
  mkdir -p "$SCRATCH7/target/.claude/autoflow" "$SCRATCH7/target/scripts/spawn-policy" "$SCRATCH7/target/scripts/lib"
  cp "$CONFIG" "$SCRATCH7/target/.claude/autoflow/spawn-policy.json"
  cp "$RESOLVER" "$SCRATCH7/target/scripts/spawn-policy/spawn-policy.sh"
  cp "$PROJECT_ROOT/scripts/lib/plugin-root.sh" "$SCRATCH7/target/scripts/lib/plugin-root.sh"
  TCFG="$SCRATCH7/target/.claude/autoflow/spawn-policy.json"
  TCHECK="$SCRATCH7/target/scripts/spawn-policy/spawn-policy.sh"

  # (i) Hook context: CLAUDE_PLUGIN_ROOT names the plugin.
  AUTOFLOW_SPAWN_POLICY="$TCFG" CLAUDE_PLUGIN_ROOT="$PLUGIN_SRC" bash "$TCHECK" check >/dev/null 2>"$SCRATCH7/i.err"; rc=$?
  if [ "$rc" = "0" ]; then
    pass "issue #169: thin-root target (no .claude/agents) + CLAUDE_PLUGIN_ROOT -> check exit 0 (definitions read from the plugin, no symlink)"
  else
    failc "issue #169: thin-root target + CLAUDE_PLUGIN_ROOT -> exit $rc: $(head -1 "$SCRATCH7/i.err")"
  fi

  # (ii) Plain shell: the plugin is found through the harness registry under
  # CLAUDE_CONFIG_DIR (installed_plugins.json), CLAUDE_PLUGIN_ROOT unset.
  CFG7="$SCRATCH7/config"; mkdir -p "$CFG7/plugins/cache/autoflow/autoflow"
  cp -R "$PLUGIN_SRC" "$CFG7/plugins/cache/autoflow/autoflow/0.1.9"
  jq -n --arg p "$CFG7/plugins/cache/autoflow/autoflow/0.1.9" '{version:2, plugins:{"autoflow@autoflow":[{scope:"user", installPath:$p, version:"0.1.9"}]}}' > "$CFG7/plugins/installed_plugins.json"
  AUTOFLOW_SPAWN_POLICY="$TCFG" CLAUDE_CONFIG_DIR="$CFG7" bash "$TCHECK" check >/dev/null 2>"$SCRATCH7/ii.err"; rc=$?
  if [ "$rc" = "0" ]; then
    pass "issue #169: thin-root target, CLAUDE_PLUGIN_ROOT unset, plugin registered under CLAUDE_CONFIG_DIR -> check exit 0 (the operator's plain-shell obligation is executable)"
  else
    failc "issue #169: registry lookup -> exit $rc: $(head -1 "$SCRATCH7/ii.err")"
  fi

  # (iii) Plain shell, no registry: the versioned cache directory alone.
  rm -f "$CFG7/plugins/installed_plugins.json"
  AUTOFLOW_SPAWN_POLICY="$TCFG" CLAUDE_CONFIG_DIR="$CFG7" bash "$TCHECK" check >/dev/null 2>"$SCRATCH7/iii.err"; rc=$?
  if [ "$rc" = "0" ]; then
    pass "issue #169: thin-root target, plugin present only under plugins/cache/<mkt>/<plugin>/<ver>/ -> check exit 0"
  else
    failc "issue #169: cache-dir lookup -> exit $rc: $(head -1 "$SCRATCH7/iii.err")"
  fi

  # (iv) A target with its OWN .claude/agents (custom agents, no autoflow-*)
  # still reads the AutoFlow definitions from the plugin.
  mkdir -p "$SCRATCH7/target/.claude/agents"
  printf -- '---\nname: my-custom\n---\n' > "$SCRATCH7/target/.claude/agents/my-custom.md"
  AUTOFLOW_SPAWN_POLICY="$TCFG" CLAUDE_CONFIG_DIR="$CFG7" bash "$TCHECK" check >/dev/null 2>"$SCRATCH7/iv.err"; rc=$?
  if [ "$rc" = "0" ]; then
    pass "issue #169: a target .claude/agents holding only non-autoflow agents falls through to the plugin -> check exit 0"
  else
    failc "issue #169: foreign-agents fallthrough -> exit $rc: $(head -1 "$SCRATCH7/iv.err")"
  fi
  rm -rf "$SCRATCH7/target/.claude/agents"

  # (v) Nothing anywhere: fail closed, the message lists what was consulted
  # and the CLAUDE_PLUGIN_ROOT override.
  AUTOFLOW_SPAWN_POLICY="$TCFG" bash "$TCHECK" check >/dev/null 2>"$SCRATCH7/v.err"; rc=$?
  if [ "$rc" = "1" ] && grep -q 'no agent definitions (autoflow-\*\.md) found' "$SCRATCH7/v.err" \
     && grep -q 'installed_plugins.json' "$SCRATCH7/v.err" \
     && grep -q 'plugins/cache/autoflow/autoflow' "$SCRATCH7/v.err" \
     && grep -q 'CLAUDE_PLUGIN_ROOT=<plugin dir>' "$SCRATCH7/v.err"; then
    pass "issue #169: no definitions anywhere -> exit 1; stderr lists the tree dir, the registry, the cache path and the CLAUDE_PLUGIN_ROOT override"
  else
    failc "issue #169: no-definitions arm -> exit $rc; stderr: $(tr '\n' ' ' < "$SCRATCH7/v.err" | cut -c1-300)"
  fi

  # (vi) The plugin's definition set is what the partition rule is checked
  # against: a plugin shipping a definition the policy neither names nor
  # declares unmapped is reported, so the fallback is not a vacuous pass.
  cp -R "$PLUGIN_SRC" "$SCRATCH7/plugin-extra"
  printf -- '---\nname: autoflow-extra\n---\n' > "$SCRATCH7/plugin-extra/agents/autoflow-extra.md"
  AUTOFLOW_SPAWN_POLICY="$TCFG" CLAUDE_PLUGIN_ROOT="$SCRATCH7/plugin-extra" bash "$TCHECK" check >/dev/null 2>"$SCRATCH7/vi.err"; rc=$?
  if [ "$rc" = "1" ] && grep -q "agent definition 'autoflow-extra' is neither named by a phases row nor declared unmapped" "$SCRATCH7/vi.err"; then
    pass "issue #169: the partition rule runs over the plugin's definitions (an unnamed plugin definition is reported), so the fallback is not vacuous"
  else
    failc "issue #169: partition over plugin definitions -> exit $rc; stderr: $(head -1 "$SCRATCH7/vi.err")"
  fi

  rm -rf "$SCRATCH7"
else
  failc "issue #169: $CONFIG, $RESOLVER or $PLUGIN_SRC/agents not found"
fi

# The operator-facing obligation text states where `check` finds the definitions.
SETUP_GUIDE_169="$PROJECT_ROOT/setup/SETUP-GUIDE.md"
if grep -q 'spawn-policy.sh check' "$SETUP_GUIDE_169" && grep -q 'CLAUDE_PLUGIN_ROOT=<plugin dir>' "$SETUP_GUIDE_169"; then
  pass "issue #169: setup/SETUP-GUIDE.md keeps the bump-time check obligation and names the plugin fallback + CLAUDE_PLUGIN_ROOT override"
else
  failc "issue #169: setup/SETUP-GUIDE.md lacks the check fallback description"
fi

# -----------------------------------------------------------------------------
# Design-added — plugin-prefix normalization discriminates on the resolver's
# own output (spawn-policy.sh:78-83), not merely on an admitted-model check
# that a deleted `*:autoflow-*` arm would still pass.
# -----------------------------------------------------------------------------
echo "== design-added: plugin-prefix normalization (models-for) =="

if [ -x "$RESOLVER" ]; then
  bare_models=$(bash "$RESOLVER" models-for "autoflow-tester" 2>/dev/null)
  prefixed_models=$(bash "$RESOLVER" models-for "autoflow:autoflow-tester" 2>/dev/null)
  if [ -n "$bare_models" ] && [ "$prefixed_models" = "$bare_models" ]; then
    pass "design-added: plugin-prefix normalization -- 'autoflow:autoflow-tester' resolves to the same non-empty model set as 'autoflow-tester'"
  else
    failc "design-added: plugin-prefix normalization -- bare=[$bare_models] prefixed=[$prefixed_models] (want equal, non-empty; a deleted '*:autoflow-*' arm collapses prefixed to empty)"
  fi
else
  failc "design-added: plugin-prefix normalization -- $RESOLVER not executable"
fi

# -----------------------------------------------------------------------------
# Design-added — _check_effort type branches (spawn-policy.sh:162-181) and the
# agent-effort divergent-declaration error path (spawn-policy.sh:118).
# -----------------------------------------------------------------------------
echo "== design-added: effort type branches + divergent-effort error path =="

if [ -x "$RESOLVER" ] && [ -f "$CONFIG" ] && [ -d "$AGENTS_DIR" ]; then
  SCRATCH5="$(mktemp -d)"
  cp -R "$PROJECT_ROOT/scripts/spawn-policy" "$SCRATCH5/" 2>/dev/null
  mkdir -p "$SCRATCH5/.claude/autoflow" "$SCRATCH5/.claude/agents"
  cp "$AGENTS_DIR"/*.md "$SCRATCH5/.claude/agents/" 2>/dev/null
  first_phase_key=$(jq -r '.phases | keys[0]' "$CONFIG")

  # (a) A non-integer JSON number (3.5) is rejected -- the "*.*" branch at
  # spawn-policy.sh:169-171.
  jq --arg k "$first_phase_key" '.phases[$k].effort = 3.5' "$CONFIG" > "$SCRATCH5/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH5/.claude/autoflow/spawn-policy.json" bash "$SCRATCH5/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_float=$?
  if [ "$rc_float" != "0" ]; then
    pass "design-added: effort type branches -- a non-integer JSON number (3.5) is rejected (exit $rc_float)"
  else
    failc "design-added: effort type branches -- a non-integer JSON number (3.5) was NOT rejected (exit 0)"
  fi

  # (b) A non-string, non-number value (JSON boolean) is rejected -- the
  # jtype != "string" branch at spawn-policy.sh:174-176.
  jq --arg k "$first_phase_key" '.phases[$k].effort = true' "$CONFIG" > "$SCRATCH5/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH5/.claude/autoflow/spawn-policy.json" bash "$SCRATCH5/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_bool=$?
  if [ "$rc_bool" != "0" ]; then
    pass "design-added: effort type branches -- a JSON boolean effort (true) is rejected (exit $rc_bool)"
  else
    failc "design-added: effort type branches -- a JSON boolean effort (true) was NOT rejected (exit 0)"
  fi

  # Same for a JSON array.
  jq --arg k "$first_phase_key" '.phases[$k].effort = []' "$CONFIG" > "$SCRATCH5/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH5/.claude/autoflow/spawn-policy.json" bash "$SCRATCH5/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_arr=$?
  if [ "$rc_arr" != "0" ]; then
    pass "design-added: effort type branches -- a JSON array effort ([]) is rejected (exit $rc_arr)"
  else
    failc "design-added: effort type branches -- a JSON array effort ([]) was NOT rejected (exit 0)"
  fi

  # (c) agent-effort's divergent-effort error path (spawn-policy.sh:117-120):
  # two phases rows sharing one agent_type, forced to different concrete
  # effort values.
  second_phase_key=$(jq -r '.phases | keys[1]' "$CONFIG")
  shared_type="__test_shared_type__"
  jq --arg k1 "$first_phase_key" --arg k2 "$second_phase_key" --arg t "$shared_type" \
    '.phases[$k1].agent_type = $t | .phases[$k1].effort = "high" | .phases[$k2].agent_type = $t | .phases[$k2].effort = "low"' \
    "$CONFIG" > "$SCRATCH5/.claude/autoflow/spawn-policy.json"
  out_div=$(AUTOFLOW_SPAWN_POLICY="$SCRATCH5/.claude/autoflow/spawn-policy.json" bash "$SCRATCH5/spawn-policy/spawn-policy.sh" agent-effort "$shared_type" 2>"$SCRATCH5/div.err")
  rc_div=$?
  err_div=$(cat "$SCRATCH5/div.err")
  if [ "$rc_div" = "1" ] && [ -z "$out_div" ] && echo "$err_div" | grep -qi "divergent effort"; then
    pass "design-added: agent-effort divergent-effort error path -- exit 1, empty stdout, stderr names the divergence"
  else
    failc "design-added: agent-effort divergent-effort error path -- exit $rc_div, stdout '$out_div', stderr '$err_div' (want exit 1, empty stdout, divergence message)"
  fi

  rm -rf "$SCRATCH5"
else
  failc "design-added: effort type branches + divergent-effort error path -- $RESOLVER, $CONFIG, or $AGENTS_DIR not found"
fi

# -----------------------------------------------------------------------------
# effort-zero-admitted (issue #150 cycle 3, F4 -- verification design > §1
# "the checker still admits the boundary value the resolver now honors, on
# both row kinds"). `check` must admit the contract-valid concrete effort 0 on
# a phases[] row AND on a workflow_sites[][] row; this is the premise the F4
# resolver fix rests on. Pre-green: `_check_effort` (spawn-policy.sh:203-225)
# already treats a JSON-number 0 as an admitted integer -- the truthiness
# defect is confined to the JS site() helpers (architect-deliberation.js:595,
# verify-cause-branch.js:161), which this shell checker never calls. The
# phases[] arm mutates diagnose-loopcheck specifically, per GATE:PLAN: it is
# the sole agent_type="autoflow-loopcheck" row (issue #180 moved it off Explore; checked: `jq -r '.phases[]|select(.agent_type=="autoflow-loopcheck")|.key'`
# returns exactly this one key), so mutating it alone cannot trip the
# divergent-effort agreement check (spawn-policy.sh:291-296), which an
# arbitrary shared-agent_type row would.
# -----------------------------------------------------------------------------
echo "== design-added: effort-zero-admitted (issue #150 cycle 3, F4) =="

if [ -x "$RESOLVER" ] && [ -f "$CONFIG" ] && [ -d "$AGENTS_DIR" ]; then
  SCRATCH6="$(mktemp -d)"
  cp -R "$PROJECT_ROOT/scripts/spawn-policy" "$SCRATCH6/" 2>/dev/null
  mkdir -p "$SCRATCH6/.claude/autoflow" "$SCRATCH6/.claude/agents"
  cp "$AGENTS_DIR"/*.md "$SCRATCH6/.claude/agents/" 2>/dev/null

  # phases[] arm: diagnose-loopcheck (agent_type autoflow-loopcheck, agent_type-unique).
  jq '.phases["diagnose-loopcheck"].effort = 0' "$CONFIG" > "$SCRATCH6/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH6/.claude/autoflow/spawn-policy.json" bash "$SCRATCH6/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_phase0=$?
  if [ "$rc_phase0" = "0" ]; then
    pass "design-added: effort-zero-admitted -- effort=0 on the phases[] row diagnose-loopcheck (agent_type-unique) passes check"
  else
    failc "design-added: effort-zero-admitted -- effort=0 on the phases[] row diagnose-loopcheck FAILED check (exit $rc_phase0)"
  fi

  # workflow_sites[][] arm: unconstrained, any row.
  first_wf=$(jq -r '.workflow_sites | keys[0]' "$CONFIG")
  first_site=$(jq -r --arg wf "$first_wf" '.workflow_sites[$wf] | keys[0]' "$CONFIG")
  jq --arg wf "$first_wf" --arg s "$first_site" '.workflow_sites[$wf][$s].effort = 0' "$CONFIG" > "$SCRATCH6/.claude/autoflow/spawn-policy.json"
  AUTOFLOW_SPAWN_POLICY="$SCRATCH6/.claude/autoflow/spawn-policy.json" bash "$SCRATCH6/spawn-policy/spawn-policy.sh" check >/dev/null 2>&1
  rc_site0=$?
  if [ "$rc_site0" = "0" ]; then
    pass "design-added: effort-zero-admitted -- effort=0 on a workflow_sites[][] row ($first_wf.$first_site) passes check"
  else
    failc "design-added: effort-zero-admitted -- effort=0 on a workflow_sites[][] row FAILED check (exit $rc_site0)"
  fi

  rm -rf "$SCRATCH6"
else
  failc "design-added: effort-zero-admitted -- $RESOLVER, $CONFIG, or $AGENTS_DIR not found"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
