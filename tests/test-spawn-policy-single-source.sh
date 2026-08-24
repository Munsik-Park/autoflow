#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/autoflow/spawn-policy.json scripts/spawn-policy/spawn-policy.sh .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .claude/agents/autoflow-analyzer.md .claude/agents/autoflow-evaluator.md .claude/agents/autoflow-implementer.md .claude/agents/autoflow-planner.md .claude/agents/autoflow-tester.md CLAUDE.md docs/teammate-contracts.md docs/phases/analysis.md
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
AGENT_TYPES=(autoflow-analyzer autoflow-evaluator autoflow-implementer autoflow-planner autoflow-tester)

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

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
  ( cd "$SCRATCH" && git init -q && git add -A && git commit -q -m scratch --allow-empty ) >/dev/null 2>&1

  SCRATCH_CONFIG="$SCRATCH/.claude/autoflow/spawn-policy.json"
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
  inherit_key=$(jq -r '.phases | to_entries[] | select(.value.effort == "inherit") | .key' "$CONFIG" 2>/dev/null | head -n1)
  if [ -n "$inherit_key" ]; then
    out=$(bash "$RESOLVER" effort "$inherit_key" 2>/dev/null); rc=$?
    if [ "$rc" = "0" ] && [ "$out" = "inherit" ]; then
      pass "AC4 inherit-marker: inheriting row '$inherit_key' -> exit 0, stdout 'inherit'"
    else
      failc "AC4 inherit-marker: inheriting row '$inherit_key' -> exit $rc, stdout '$out' (want 0, 'inherit')"
    fi
  else
    failc "AC4 inherit-marker: no inheriting phases[] row found in $CONFIG"
  fi

  # Concrete-value case: construct one in a scratch copy, since every shipped
  # row carries the inherit sentinel this cycle (feature design §6).
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

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
