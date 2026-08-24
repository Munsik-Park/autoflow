#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/autoflow/spawn-policy.json tests/manual/issue-150-manual-scenarios.md
# lane: cycle-scoped
# retire-with: #150
# cycle-arm: #150
# out-of-tree-inputs: yes
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #150 migration fidelity -- the config's model values equal the
# values each source document/file carried at the merge-base -- PLUS (cycle 2,
# finding F2) that the manual scenario file's ### Result sections carry a real
# recorded disposition rather than the shipped placeholder.
# =============================================================================
# Cycle-scoped by construction (.autoflow/issue-150-verification-design.md >
# section 2): the migration changed a policy value while claiming to preserve
# it. This is a ONE-TIME property. Keeping it standing would freeze the policy
# model values against the CLAUDE.md revert rule, which this issue does not
# license. Three baselines, one per row group (feature design §3):
#   - `phases` rows the CLAUDE.md table carries      -> that table @ merge-base
#   - the two DIAGNOSE rows the table never carried   -> docs/phases/analysis.md
#                                                         prose @ merge-base
#   - `workflow_sites` rows                           -> the `model:` literals
#                                                         in the two .js files
#                                                         @ merge-base
# =============================================================================

set -uo pipefail

# The fixed set of files this cycle's migration-fidelity assertion is licensed
# to compare — the three baselines feature design §3 names (the CLAUDE.md
# table, the docs/phases/analysis.md prose, and the two workflow scripts'
# `model:` literals), plus the config it compares them against. Declared as a
# path allow-list array per scripts/test/suite-manifest.sh's cycle-scoped
# grammar: retirement (`# retire-with: #150`) and this array's evaluation set
# are the only things dominance is checkable over for a one-time property.
allow_list=(
  "CLAUDE.md"
  "docs/phases/analysis.md"
  ".claude/workflows/architect-deliberation.js"
  ".claude/workflows/verify-cause-branch.js"
  ".claude/autoflow/spawn-policy.json"
)

# DCR-7 (feature design §2): the manual-result-recorded leg below reads the
# PRESENT tree -- it compares nothing against the merge-base baseline, so its
# file does not belong in `allow_list` above (that array's own preceding
# comment declares it as the baseline-comparison set, and widening it without
# widening the comment would leave the comment describing a set it no longer
# describes). Declared instead in its own array, in the same recognized
# `ALLOWLIST_[0-9A-Za-z_]+=\(` grammar scripts/test/suite-manifest.sh matches.
ALLOWLIST_MANUAL_RECORD=(
  "tests/manual/issue-150-manual-scenarios.md"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/lib/base-ref.sh
. "$SCRIPT_DIR/lib/base-ref.sh"

CONFIG="$PROJECT_ROOT/.claude/autoflow/spawn-policy.json"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

if [ ! -f "$CONFIG" ]; then
  failc "migration-fidelity: $CONFIG not found"
  echo; echo "PASS: $PASS  FAIL: $FAIL"; exit 1
fi

# Cycle-scoped, diff-dependent by construction: the assertions below compare
# the CONFIG against this cycle's OWN merge-base -- a property that is only
# well-formed while CLAUDE.md @ BASE_REF still carries the pre-migration
# value table. Gate on that CONTENT, not on the executing branch name: a
# branch-name signal is not portable across the execution contexts this
# suite is invoked from. The push-context oracle's scratch clone
# (tests/test-push-context-base-ref.sh:602-609, make_scratch_push_context)
# checks out HEAD DETACHED, so `git rev-parse --abbrev-ref HEAD` there reads
# the literal string "HEAD" regardless of the real branch -- and a
# GITHUB_HEAD_REF fallback does not fix this: GitHub Actions exports that
# variable for the whole PR *job*, so it survives unset into the oracle's
# scratch-clone subprocess too, falsely re-arming a `dev/*-issue-150`
# branch-name gate inside a clone whose BASE_REF has already degenerated to
# `merge-base HEAD origin/main` == HEAD (CI: matches -> assertions run
# against the degenerate base, whose CLAUDE.md is this same cycle's OWN
# post-migration text -- no table, every base_model empty, every comparison
# FAILs loud). Locally the same scratch clone has no GITHUB_HEAD_REF, so the
# branch-name gate reads "HEAD", never matches, and defers -- which is why a
# branch-name gate passes local re-runs while failing in CI on the identical
# scratch-clone tree. The actual precondition the assertions need is
# CONTENT: the pre-migration table (retired by 3ad399b: "CLAUDE.md > Spawn
# Model loses the value table for a pointer") is present in CLAUDE.md @
# BASE_REF iff BASE_REF genuinely predates the migration -- true on the real
# dev/*-issue-150 branch's merge-base, false in every degenerate or
# self-referential BASE_REF this suite can be handed, in any environment.
note_deferred() { echo "  DEFERRED: $1"; }

BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref "${1:-}")" || {
  failc "migration-fidelity: no base ref resolvable (resolve_base_ref failed)"
  echo; echo "PASS: $PASS  FAIL: $FAIL"; exit 1
}

CLAUDE_MD_BASE="$(git -C "$PROJECT_ROOT" show "$BASE_REF:CLAUDE.md" 2>/dev/null)"

if ! grep -qF '| Phase | Model | Work type |' < <(printf '%s\n' "$CLAUDE_MD_BASE"); then
  note_deferred "migration-fidelity: CLAUDE.md @ $BASE_REF carries no pre-migration Spawn Model table (BASE_REF resolved to this cycle's own post-migration tree, or the table's already gone there) -- this cycle's own pre-migration baseline is this PR's contract, not a base that never had it."
  echo
  echo "=============================================="
  echo "PASS: $PASS  FAIL: $FAIL"
  echo "=============================================="
  exit 0
fi

# -----------------------------------------------------------------------------
# Group 1 -- `phases` rows the CLAUDE.md table carries, vs. that table at the
# merge-base. Source table: CLAUDE.md > Spawn Model — Phase-by-Phase.
# Mapping per feature design §3 (`phase key` -> `source table row`).
# -----------------------------------------------------------------------------
echo "== migration-fidelity: phases rows vs CLAUDE.md table @ $BASE_REF =="

declare -a TABLE_ROWS=(
  "diagnose-phase-a|DIAGNOSE Phase A"
  "diagnose-phase-b|DIAGNOSE Phase B"
  "diagnose-phase-3|DIAGNOSE Phase 3"
  "gate-hypothesis|GATE:HYPOTHESIS"
  "gate-plan|GATE:PLAN"
  "red|RED"
  "green|GREEN"
  "verify-arbitration|VERIFY"
  "refine-impl|REFINE"
  "refine-test-reconfirm|REFINE"
  "audit|AUDIT"
  "gate-quality|GATE:QUALITY"
  "handoff-review-triage|HANDOFF review-triage"
)

if [ -z "$CLAUDE_MD_BASE" ]; then
  failc "migration-fidelity: could not read CLAUDE.md @ $BASE_REF"
else
  for row in "${TABLE_ROWS[@]}"; do
    key="${row%%|*}"
    label="${row#*|}"
    # The table row: | <phase> | `<model>` | <work type> |
    base_model=$(echo "$CLAUDE_MD_BASE" | grep -F "| $label " | grep -oE '`(sonnet|opus|haiku)`' | head -n1 | tr -d '`')
    cfg_model=$(jq -r --arg k "$key" '.phases[$k].model // empty' "$CONFIG" 2>/dev/null)
    if [ -n "$base_model" ] && [ "$base_model" = "$cfg_model" ]; then
      pass "migration-fidelity: phases.$key.model ($cfg_model) == CLAUDE.md '$label' row @ base ($base_model)"
    else
      failc "migration-fidelity: phases.$key.model='$cfg_model' vs CLAUDE.md '$label' row @ base='$base_model'"
    fi
  done
fi

# -----------------------------------------------------------------------------
# Group 2 -- the two DIAGNOSE rows the table never carried, vs the model
# values stated in docs/phases/analysis.md prose @ merge-base.
# -----------------------------------------------------------------------------
echo "== migration-fidelity: DIAGNOSE-only rows vs docs/phases/analysis.md prose @ $BASE_REF =="

ANALYSIS_BASE="$(git -C "$PROJECT_ROOT" show "$BASE_REF:docs/phases/analysis.md" 2>/dev/null)"
if [ -z "$ANALYSIS_BASE" ]; then
  failc "migration-fidelity: could not read docs/phases/analysis.md @ $BASE_REF"
else
  loopcheck_line=$(echo "$ANALYSIS_BASE" | grep "^\*\*Review-response loop check\*\*")
  intake_line=$(echo "$ANALYSIS_BASE" | grep "^\*\*Intake readiness triage\*\*")

  loopcheck_base_model=$(echo "$loopcheck_line" | grep -oE '`(sonnet|opus|haiku)`' | head -n1 | tr -d '`')
  intake_base_model=$(echo "$intake_line" | grep -oE '`(sonnet|opus|haiku)`' | head -n1 | tr -d '`')

  cfg_loopcheck=$(jq -r '.phases["diagnose-loopcheck"].model // empty' "$CONFIG" 2>/dev/null)
  cfg_intake=$(jq -r '.phases["diagnose-intake-triage"].model // empty' "$CONFIG" 2>/dev/null)

  if [ -n "$loopcheck_base_model" ] && [ "$loopcheck_base_model" = "$cfg_loopcheck" ]; then
    pass "migration-fidelity: phases.diagnose-loopcheck.model ($cfg_loopcheck) == analysis.md prose @ base ($loopcheck_base_model)"
  else
    failc "migration-fidelity: phases.diagnose-loopcheck.model='$cfg_loopcheck' vs analysis.md prose @ base='$loopcheck_base_model'"
  fi

  if [ -n "$intake_base_model" ] && [ "$intake_base_model" = "$cfg_intake" ]; then
    pass "migration-fidelity: phases.diagnose-intake-triage.model ($cfg_intake) == analysis.md prose @ base ($intake_base_model)"
  else
    failc "migration-fidelity: phases.diagnose-intake-triage.model='$cfg_intake' vs analysis.md prose @ base='$intake_base_model'"
  fi

  # diagnose-loopcheck's agent_type must be the harness research type Explore.
  cfg_loopcheck_type=$(jq -r '.phases["diagnose-loopcheck"].agent_type // empty' "$CONFIG" 2>/dev/null)
  if [ "$cfg_loopcheck_type" = "Explore" ]; then
    pass "migration-fidelity: phases.diagnose-loopcheck.agent_type == Explore (stated outright in analysis.md)"
  else
    failc "migration-fidelity: phases.diagnose-loopcheck.agent_type='$cfg_loopcheck_type' (want Explore)"
  fi
fi

# -----------------------------------------------------------------------------
# Group 3 -- `workflow_sites` rows vs the `model:` literals in the two .js
# files @ merge-base (NOT the CLAUDE.md table's blanket facilitator value).
# -----------------------------------------------------------------------------
echo "== migration-fidelity: workflow_sites rows vs .js literals @ $BASE_REF =="

# site key -> (workflow name, label, line-anchor grep pattern for the model)
declare -a SITE_ROWS=(
  "architect-deliberation|dev-draft|label: 'dev-draft'"
  "architect-deliberation|test-draft|label: 'test-draft'"
  "architect-deliberation|register-load|label: 'register-load'"
  "architect-deliberation|test-round|label: \`test-r\${round}\`"
  "architect-deliberation|dev-round|label: \`dev-r\${round}\`"
  "architect-deliberation|ac-diff|label: 'ac-diff'"
  "architect-deliberation|ledger|label: 'ledger'"
  "architect-deliberation|register-write|label: 'register-write'"
  "verify-cause-branch|test-self-check|label: 'test-self-check'"
  "verify-cause-branch|impl-self-check|label: 'impl-self-check'"
  "verify-cause-branch|ledger|label: 'ledger'"
)

for row in "${SITE_ROWS[@]}"; do
  IFS='|' read -r wf site label_pat <<< "$row"
  jsfile=".claude/workflows/${wf}.js"
  base_content="$(git -C "$PROJECT_ROOT" show "$BASE_REF:$jsfile" 2>/dev/null)"
  # Grab the block containing the label and its model literal (search +/- 3
  # lines around the label match for a model: literal on the same statement).
  base_model=$(echo "$base_content" | grep -F "$label_pat" -A2 -B2 2>/dev/null | grep -oE "model: *'(sonnet|opus|haiku)'" | head -n1 | grep -oE '(sonnet|opus|haiku)')
  cfg_model=$(jq -r --arg wf "$wf" --arg s "$site" '.workflow_sites[$wf][$s].model // empty' "$CONFIG" 2>/dev/null)
  if [ -n "$base_model" ] && [ "$base_model" = "$cfg_model" ]; then
    pass "migration-fidelity: workflow_sites.$wf.$site.model ($cfg_model) == .js literal @ base ($base_model)"
  else
    failc "migration-fidelity: workflow_sites.$wf.$site.model='$cfg_model' vs .js literal @ base='$base_model'"
  fi
done

# The closing-call site (a distinct label in architect-deliberation.js).
base_content_ad="$(git -C "$PROJECT_ROOT" show "$BASE_REF:.claude/workflows/architect-deliberation.js" 2>/dev/null)"
closing_base_model=$(echo "$base_content_ad" | grep -n "CLOSING_CALL_LABEL" -A2 -B2 2>/dev/null | grep -oE "model: *'(sonnet|opus|haiku)'" | head -n1 | grep -oE '(sonnet|opus|haiku)')
cfg_closing=$(jq -r '.workflow_sites["architect-deliberation"]["test-closing"].model // empty' "$CONFIG" 2>/dev/null)
if [ -n "$closing_base_model" ] && [ "$closing_base_model" = "$cfg_closing" ]; then
  pass "migration-fidelity: workflow_sites.architect-deliberation.test-closing.model ($cfg_closing) == .js literal @ base ($closing_base_model)"
else
  failc "migration-fidelity: workflow_sites.architect-deliberation.test-closing.model='$cfg_closing' vs .js literal @ base='$closing_base_model'"
fi

# -----------------------------------------------------------------------------
# manual-result-recorded (finding F2, verification design > §1
# `manual-result-recorded`). Each `### Result` section in the real manual
# scenarios file must carry a REAL recorded disposition -- never the shipped
# placeholder -- checked as a POSITIVE record shape, not a placeholder
# blacklist (a blacklist would pass silently on a mere rewording of the
# placeholder prose, the same evidence-honesty gap the finding reports).
#
# Record shape (declared HERE, per the verification design's instruction that
# the vocabulary has a single home read by the implementation):
#   Date: YYYY-MM-DD
#   Disposition: PASS | FAIL | BLOCKED | DECLINED
#   Authorized-by: <non-empty>     (required only when Disposition is BLOCKED
#                                    or DECLINED -- DCR-3's authorized decline)
# -----------------------------------------------------------------------------
echo "== manual-result-recorded =="

MANUAL_SCENARIOS="$PROJECT_ROOT/tests/manual/issue-150-manual-scenarios.md"

check_result_section() {
  local section_name="$1" body="$2"
  local date_line disp_line disp_token auth_line
  date_line=$(echo "$body" | grep -E '^Date:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$')
  disp_line=$(echo "$body" | grep -E '^Disposition:[[:space:]]*(PASS|FAIL|BLOCKED|DECLINED)[[:space:]]*$')
  disp_token=$(echo "$disp_line" | sed -E 's/^Disposition:[[:space:]]*//' | tr -d '[:space:]')

  if [ -z "$date_line" ]; then
    failc "manual-result-recorded: $section_name has no 'Date: YYYY-MM-DD' line"
    return
  fi
  if [ -z "$disp_token" ]; then
    failc "manual-result-recorded: $section_name has no 'Disposition: PASS|FAIL|BLOCKED|DECLINED' line"
    return
  fi
  if [ "$disp_token" = "BLOCKED" ] || [ "$disp_token" = "DECLINED" ]; then
    auth_line=$(echo "$body" | grep -E '^Authorized-by:[[:space:]]*[^[:space:]]')
    if [ -z "$auth_line" ]; then
      failc "manual-result-recorded: $section_name disposition=$disp_token requires a non-empty 'Authorized-by:' line"
      return
    fi
  fi
  pass "manual-result-recorded: $section_name carries a conforming recorded result (Date + Disposition=$disp_token)"
}

if [ -f "$MANUAL_SCENARIOS" ]; then
  m1_body=$(awk '/^## M1 /{f=1; next} /^## M2 /{f=0} f' "$MANUAL_SCENARIOS" | awk '/^### Result/{f=1; next} /^---/{if (f) exit} f')
  m2_body=$(awk '/^## M2 /{f=1; next} f' "$MANUAL_SCENARIOS" | awk '/^### Result/{f=1; next} /^---/{if (f) exit} f')
  check_result_section "M1" "$m1_body"
  check_result_section "M2" "$m2_body"
else
  failc "manual-result-recorded: $MANUAL_SCENARIOS not found"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
