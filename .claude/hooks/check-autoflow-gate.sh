#!/bin/bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# AutoFlow Gate Check
# The hook computes pass/fail directly from the raw `scores` object so that the
# trust chain stops at the script level — the AI's own `pass`/`avg`/`min` fields
# are ignored.
#
# Command matching and check ordering follow docs/gate-matching-standard.md:
#   - P1: gates match with the shared CMD_BOUNDARY prefix + word boundary,
#         never a bare `^` (which `cd x && git push` would bypass).
#   - P2: unconditional denies (gh pr merge / default-branch push /
#         blocked-by-review label removal) run in Section 1, BEFORE the
#         activity check, so an inactive/absent state file cannot nullify them.
#
# PASS criteria (defined in CLAUDE.md):
#   - average ≥ 7.5
#   - each item ≥ 7
#   - security ≤ 3 → automatic block
#
# Gate points:
#   - Bash(gh pr merge)             → DENIED unconditionally (AutoFlow never merges)
#   - Bash(git push <default br>)   → DENIED unconditionally (push dev branch + PR only)
#   - Bash(remove blocked-by-review label) → DENIED unconditionally; matches the
#                                     label name across gh pr edit / gh issue edit
#                                     --remove-label and gh api DELETE .../labels/…
#                                     (gate-label clearing is the reviewer's job)
#   - Agent (any spawn)             → explicit `model` parameter required
#                                     (state-independent — CLAUDE.md > Spawn Model)
#   - Agent (role-declared spawn)   → gate by DECLARED role, never by prompt
#                                     keywords (docs/gate-matching-standard.md P3):
#                                     planning → GATE:HYPOTHESIS pass (bug issue;
#                                     verdict containing "skip" → bypass, feat),
#                                     implementation / testing → GATE:PLAN pass,
#                                     analysis / evaluation / research → pass.
#   - Agent (undeclared spawn)      → DENIED while a cycle is active (declare the
#                                     role via subagent_type autoflow-<role> or a
#                                     team-spawn name prefix — see resolve_spawn_role)
#   - Bash(git push)                → AUDIT + GATE:QUALITY pass required
#   - Bash(gh pr create)            → AUDIT + GATE:QUALITY pass required

set -e

AUTOFLOW_DIR="${CLAUDE_PROJECT_DIR:-.}/.autoflow"
INPUT=$(cat)

# ── Hook target detection ──
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Shared command-boundary prefix (docs/gate-matching-standard.md > P1).
# Matches command start or the position after ; & | && || — so a gate is
# not bypassed by `cd x && git push` / `a && gh pr create`. Backtick / (
# are intentionally NOT boundary chars: command-substitution evasion is out
# of scope, and including them caused heredoc/body false-positives.
CMD_BOUNDARY='(^|[;&|]|&&|\|\|)[[:space:]]*'

# Scan target: the command with body text removed so a quoted/heredoc body
# that merely mentions a prohibited token does not false-positive, while a
# real chained command outside quotes is preserved (gate-matching-standard
# > Known Limitation refinement):
#   1. drop everything from the first heredoc introducer (`<<`) onward;
#   2. delete single- and double-quoted substrings (inline --body "...").
SCAN=$(printf '%s' "${COMMAND%%<<*}" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# `git` may carry global options (-c key=value, -C <path>) between the binary
# and the subcommand: `git -c protocol.version=2 push origin main`. Match zero
# or more such option tokens so push detection is not bypassed (issue #13).
# Scope: -c/-C interposition that arises in NORMAL operation. Adversarial
# wrappers (subshell/backtick/command-substitution) stay out of P1's threat
# model and are NOT covered here (docs/gate-matching-standard.md > P1). Defined
# at global scope (before the Bash guard and the is_score_gated_surface
# definition) so all three consumers — the P2 default-branch deny, Gate 3, and
# is_score_gated_surface (called on the Agent path too) — reference a set value.
GIT_PUSH='git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+push\b'

# ── Section 1: Unconditional blocks (state-independent — P2) ──
# AutoFlow never merges and never pushes to the default branch through the
# agent's tools. Enforced regardless of any .autoflow state so that a
# terminal phase setting active:false (or a removed state file) cannot
# disable the prohibition. Merging is performed by external review.
if [ "$TOOL_NAME" = "Bash" ]; then
  # Shell-separator segment split shared by the co-occurrence denies below
  # (label-gate REST form, default-branch push). Computed once from SCAN.
  # NOTE (C3): fold backslash-newline line-continuations into ONE logical line
  # BEFORE the separator split. A `\`<newline> continuation is a single logical
  # shell command, but it leaves a literal newline in SCAN, so the per-segment
  # `while read` loops below (which read one physical line at a time) would split
  # that one command into several segments and let a same-segment co-occurrence
  # AND fail OPEN in a security gate (issue #13 AUDIT regression). The `\n` here
  # is a PATTERN-side newline match against the embedded newline that `N` pulls
  # into the pattern space; `\n`-in-pattern is honored by BSD (macOS operator)
  # and GNU (CI) sed alike, and is distinct from the undefined `\n`-in-REPLACEMENT
  # that NOTE (C2) below avoids. The `/\\$/N … s/\\\n/ /; ta` loop only joins a
  # newline PRECEDED by a backslash; a bare newline is a real command separator
  # and is deliberately left intact (over-block guard).
  #
  # BSD/GNU DIVERGENCE (issue #13 AUDIT cycle 2): `N` is NOT alike on the LAST
  # line of the buffer when it ends in a trailing `\` (a continuation with no
  # following line to append). BSD `N` at EOF has no next line, so it DISCARDS
  # the pattern space — _JOINED goes EMPTY and the whole segment-based deny fails
  # OPEN; GNU `N` at EOF prints (preserves) the pattern space. The earlier
  # "BSD/GNU both honor" wording did not hold at this EOF boundary. Fix: the
  # leading `$s/\\$//` strips a bare trailing backslash on the LAST line BEFORE
  # the fold loop, so a lone continuation-at-EOF collapses to a plain command on
  # both seds (verified on /usr/bin/sed and gsed).
  _JOINED=$(printf '%s' "$SCAN" | sed -e '$s/\\$//' -e ':a' -e '/\\$/N' -e 's/\\\n/ /' -e 'ta')
  # NOTE (C4): fail-closed invariant. If the fold ever empties a non-empty SCAN on
  # some residual sed/input combination (e.g. a multi-line command whose final
  # joined line still ends in `\` re-hits the BSD N-at-EOF discard inside the `ta`
  # loop), fall back to the raw SCAN so the segment scan runs against real content
  # and the deny fires — never against an empty buffer that would fail OPEN.
  [ -n "$SCAN" ] && [ -z "$_JOINED" ] && _JOINED=$SCAN
  # NOTE (C2): the replacement is a POSIX literal backslash-newline (an escaped
  # real newline), NOT the `\n` escape — `\n`-in-replacement is undefined by
  # POSIX and a sed that emits literal `n` would collapse segmentation and let a
  # co-occurrence deny fail OPEN in a security gate. The literal form is
  # standard-guaranteed on BSD (macOS operator) and GNU (CI) sed alike.
  _SEGMENTS=$(printf '%s' "$_JOINED" | sed -E 's/(&&|\|\||[;&|])/\
/g')

  if printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+merge\b"; then
    echo "BLOCKED: AutoFlow does not merge — 'gh pr merge' is denied (CLAUDE.md > HANDOFF)." >&2
    echo "Merging, issue close, and deployment are owned by an external review process." >&2
    exit 2
  fi

  # The orchestrator must never clear the `blocked-by-review` gate label — that
  # would let the producer self-open its own gate. AutoFlow owns neither label:
  # `blocked-by-review` is the independent Codex reviewer's step, run inside the
  # isolated `codex exec` session (a subprocess this hook does not intercept),
  # and `blocked-by-subrepo` is the operator's step at merge (the workflow no
  # longer auto-removes it — not viable for N sub-repos). Match the LABEL NAME in
  # a removal context so the deny (a) covers every natural surface that drops the
  # label — `gh pr edit` / `gh issue edit --remove-label blocked-by-review` (a
  # PR's labels are issue labels) and the `gh api … -X DELETE …/labels/
  # blocked-by-review` REST form — while (b) NOT firing on unrelated label edits
  # such as HANDOFF step 7's `gh issue edit … --remove-label status:in-progress`,
  # and (c) leaving other labels removable. Residual (accepted; shared by every
  # Section-1 deny): a quoted label value or a `sh -c "…"`/backtick wrapper is
  # stripped by SCAN and slips — the threat model is the naive self-clear, and
  # the bare form is what callers write.
  # (A) --remove-label <gate label> is a single-pattern gate — unaffected by
  # segment scoping (one pattern has no co-occurrence to mis-scope).
  # (B) the `gh api … -X DELETE …/labels/<gate label>` REST form is an AND of
  # two patterns; require them to co-occur in ONE segment so unrelated
  # sub-commands (…/labels/blocked-by-review GET ; curl -X DELETE …/other)
  # no longer false-positive over the whole buffer (issue #13; P1 refinement).
  _label_deny=0
  if printf '%s' "$SCAN" | grep -qE "[[:space:]]--remove-label[[:space:]=]+blocked-by-(review|subrepo)\b"; then
    _label_deny=1
  else
    while IFS= read -r _seg; do
      if printf '%s' "$_seg" | grep -qE "/labels/blocked-by-(review|subrepo)\b" \
         && printf '%s' "$_seg" | grep -qE "(-X[[:space:]]*|--method[[:space:]=]+)DELETE\b"; then
        _label_deny=1; break
      fi
    done <<< "$_SEGMENTS"
  fi
  if [ "$_label_deny" = 1 ]; then
    echo "BLOCKED: AutoFlow does not clear the 'blocked-by-review' / 'blocked-by-subrepo' gate labels." >&2
    echo "blocked-by-review is the Codex reviewer's step (.codex/review.md); blocked-by-subrepo is the operator's step at merge — AutoFlow owns neither." >&2
    exit 2
  fi

  DEFAULT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  # Segment-scoped default-branch-push deny (issue #3): the "git push" and the
  # "target is the default branch" patterns must co-occur in ONE command segment,
  # not merely somewhere in the multi-line scan buffer. Splitting on the shell
  # command separators turns each separator into a newline so the per-segment
  # loop treats one command at a time — a composite cleanup command whose only
  # push is a delete-refspec to a non-default branch no longer AND-matches an
  # unrelated `… origin <default>` sub-command.
  # Reuses the shared $_SEGMENTS split (computed once above) so the fragile
  # segmentation primitive has a single source — see the _SEGMENTS NOTE (C2) for
  # the sed literal-newline rationale. The interposition-tolerant $GIT_PUSH
  # fragment lets `git -c k=v push origin <default>` still match (issue #13).
  while IFS= read -r _bp_seg; do
    if printf '%s' "$_bp_seg" | grep -qE "^[[:space:]]*${GIT_PUSH}" \
       && printf '%s' "$_bp_seg" | grep -qE "(\borigin[[:space:]]+(HEAD:)?${DEFAULT_BRANCH}\b|:[[:space:]]*${DEFAULT_BRANCH}\b)"; then
      echo "BLOCKED: AutoFlow does not push to ${DEFAULT_BRANCH} — push the dev branch and open a PR (CLAUDE.md > HANDOFF)." >&2
      exit 2
    fi
  done <<< "$_SEGMENTS"
fi

# ── Section 1b: Agent spawn must declare an explicit model (state-independent) ──
# CLAUDE.md > Spawn Model [MUST]: every Agent spawn (subagent_type or team_name
# form) declares the `model` parameter explicitly. An omitted model silently
# inherits the HOST SESSION model, bypassing the per-phase model policy — and
# bills at whatever tier the host runs (2x the policy model when the host is on
# a premium tier). Enforced BEFORE the state check so ad-hoc spawns outside an
# Auto-Flow cycle are covered too. Research (Explore/Plan) and evaluation spawns
# are NOT exempt: the Spawn Model table assigns them a model as well — their
# bypasses below apply only to the score gates, not to this declaration rule.
# Presence-only check: the Agent tool's own enum validates the value.
if [ "$TOOL_NAME" = "Agent" ]; then
  AGENT_MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)
  if [ -z "$AGENT_MODEL" ]; then
    echo "BLOCKED: Agent spawn without an explicit 'model' parameter (CLAUDE.md > Spawn Model)." >&2
    echo "Declare the phase-policy model on every spawn (e.g. model: \"sonnet\" / \"opus\") — omitting it inherits the host session model and bypasses the per-phase policy." >&2
    exit 2
  fi
fi

# ── Spawn role resolution (declaration, not inference) ──
# A spawn's gate class comes from a STRUCTURAL declaration, never from prompt
# keywords. Keyword inference failed in both directions in live cycles: benign
# spawns whose prompts mentioned "수정"/"design"/"create" were over-blocked and
# then re-spawned with sanitized wording (training the orchestrator to phrase
# around the regex), while a keyword-free implementation prompt slipped past
# GATE:PLAN entirely. Declaration channels (docs/gate-matching-standard.md P3):
#   - direct spawn: subagent_type = autoflow-<role> (defined in .claude/agents/)
#   - team spawn:   teammate `name` carries a role prefix (impl-*, test-*, …)
#   - research:     built-in read-only types Explore / Plan / claude-code-guide
# Prints: research|analysis|planning|implementation|testing|evaluation, or ""
# (undeclared). The role→gate mapping below is owned by this hook — a spawn
# declares WHO it is; it never declares which gate applies to it.
resolve_spawn_role() {
  local _subtype _name _role=""
  _subtype=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
  _name=$(echo "$INPUT" | jq -r '.tool_input.name // empty' 2>/dev/null)
  # Channel priority: a team spawn (teammate `name` present) is declared by the
  # NAME PREFIX ALONE — subagent_type is not consulted. Otherwise a mixed
  # payload (subagent_type:"Explore" + name:"impl-…") would resolve to research
  # and pass an implementation teammate through without GATE:PLAN (PR #506
  # review, Medium). A team spawn whose name carries no role prefix stays
  # undeclared → denied during an active cycle, even if subagent_type names a
  # research or autoflow-* type: a contradictory declaration is blocked, not
  # arbitrated.
  if [ -n "$_name" ]; then
    case "$_name" in
      analysis|analysis-*)      _role="analysis" ;;
      plan|plan-*)              _role="planning" ;;
      impl|impl-*|dev|dev-*)    _role="implementation" ;;
      test|test-*)              _role="testing" ;;
      eval|eval-*)              _role="evaluation" ;;
    esac
  else
    case "$_subtype" in
      Explore|Plan|claude-code-guide)              _role="research" ;;
      autoflow-analyzer|*:autoflow-analyzer)       _role="analysis" ;;
      autoflow-planner|*:autoflow-planner)         _role="planning" ;;
      autoflow-implementer|*:autoflow-implementer) _role="implementation" ;;
      autoflow-tester|*:autoflow-tester)           _role="testing" ;;
      autoflow-evaluator|*:autoflow-evaluator)     _role="evaluation" ;;
    esac
  fi
  printf '%s' "$_role"
}

# Shared by the corrupt-state and multi-active fail-closed branches below: both
# need the identical "does this call hit the score-gated surface?" test (git
# push / gh pr create, or a non-research/non-evaluation Agent spawn) — a single
# definition keeps the two branches from silently drifting apart on a future
# edit to that surface (issue #843 REFINE).
is_score_gated_surface() {
  if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}(${GIT_PUSH}|gh[[:space:]]+pr[[:space:]]+create)\b"; then
    return 0
  elif [ "$TOOL_NAME" = "Agent" ]; then
    # Research is read-only and evaluation must stay spawnable (it produces the
    # scores a repaired state needs); every other role — and an undeclared
    # spawn — fails closed.
    local _role
    _role=$(resolve_spawn_role)
    [ "$_role" != "research" ] && [ "$_role" != "evaluation" ]
  else
    return 1
  fi
}

# ── Section 2: Activity check — locate the active issue state file ──
# No state file means AutoFlow has not started — let the call through
# (pre-PREFLIGHT). The Section 1 denies above already ran unconditionally.
#
# Discovery is JSON-semantic (jq), not a textual grep: a state file is "active"
# iff `.active == true` as JSON, regardless of serialization whitespace. A prior
# `grep -rl '"active": true'` matched only the exact one-space form, so a valid
# but compact (`{"active":true}`) or reformatted (`"active" : true`) state file
# was silently not found — leaving STATE_FILE empty and bypassing every score
# gate (issue #241). jq decides by value; the loop keeps the first active file
# (one issue runs at a time).
#
# Parse-validity and `.active` are decided in a SINGLE jq read per file, not two:
# a `jq -e '.active == true'` returns non-zero for both a parse error AND
# `.active == false`, and reading the file twice (validate, then re-read for
# active) leaves a TOCTOU window where a mid-write between the two reads validates
# on the first and parse-errors on the second — slipping past both branches into a
# silent fail-open (PR #242 review). One `jq -er 'if .active == true ...'` snapshot
# distinguishes the three outcomes atomically: jq exits non-zero on a parse error
# (→ corrupt, recorded in MALFORMED_STATE and made to FAIL CLOSED for the
# score-gated commands below, never silently skipped); otherwise it prints
# "active" / "inactive". The assignment sits in the `if` condition so a jq failure
# does not trip `set -e`.
STATE_FILE=""
STATE_JSON=""
MALFORMED_STATE=""
ACTIVE_COUNT=0
ACTIVE_FILES=""
if [ -d "$AUTOFLOW_DIR" ]; then
  for _sf in "$AUTOFLOW_DIR"/*.json; do
    [ -e "$_sf" ] || continue   # glob had no match → literal path → skip
    # Read the file ONCE into memory and decide parse-validity + active on that
    # single snapshot. Every downstream consumer (ACTIVE, VERDICT, check_scores)
    # reads STATE_JSON, never the file again — so a partial write occurring after
    # discovery cannot turn a later re-read into a jq parse error that exits 5,
    # which PreToolUse treats as a NON-blocking error (only exit 2 blocks). The
    # cat+jq pair sits in the `if` condition so neither failure trips `set -e`.
    # `jq -s` slurps the file: a valid state is EXACTLY ONE top-level JSON object.
    # jq is a stream parser, so two concatenated objects would otherwise parse to
    # "active\nactive" and slip past both the active and the malformed branches
    # (PR #242 review). Zero/multiple top-level values, a non-object top-level, or
    # a parse error all take the malformed path → fail closed.
    # AUTOFLOW-SCHEMA-VALIDATION (issue #245): the filter is CLOSED-WORLD — it accepts ONLY
    # the declared shape (top-level keys in the allowlist or fix_regression_cycle_N; each
    # field's type; verdict in {"",pending,evaluated,skipped (feat issue)}; scores
    # number|{score:number} in [0,10]; phases only at root + fix_regression* cycles) and
    # routes EVERY other shape to error() -> the MALFORMED path -> exit 2. "Reject all not
    # explicitly allowed" (vs the prior open-world "reject known-bad shapes") structurally
    # closes the corrupt-but-valid-JSON fail-open class (issue #245 cycle 2; verdict-value #5,
    # unknown-key/field-type #6). Single source of the vocabulary: tests/fixtures/gate-schema.json
    # (verdict_enum, top_level_keys, cycle_key_grammar, score_range), drift-checked by
    # test-issue-245-schema-validation.sh CLASS A (A9). check_scores below is UNTOUCHED — a
    # validator-passing doc has phases only at grammar-legal cycles, so its walk is uncontaminated.
    if _content=$(cat "$_sf" 2>/dev/null) \
       && _verdict=$(printf '%s' "$_content" | jq -s -er 'def in_range: type == "number" and . >= 0 and . <= 10; def is_score: in_range or (type == "object" and (.score | in_range)); def scores_ok: (type == "object") and ((to_entries | map(.value | is_score)) | all); def verdict_ok: (type == "string") and (. == "" or . == "pending" or . == "evaluated" or . == "skipped (feat issue)"); def phase_ok($p): (.phases[$p] == null) or ((.phases[$p] | type == "object") and ((.phases[$p].verdict == null) or (.phases[$p].verdict | verdict_ok)) and ((.phases[$p].scores == null) or (.phases[$p].scores | scores_ok))); def topkeys_ok: (keys_unsorted - ["active","issue","title","date","cycle","mode","phase","phases","fix_regression"]) | map(select(test("^fix_regression_cycle_[0-9]+$") | not)) | length == 0; def topvalues_ok: ((has("issue")|not) or (.issue|type=="string")) and ((has("title")|not) or (.title|type=="string")) and ((has("date")|not) or (.date|type=="string")) and ((has("cycle")|not) or (.cycle|type=="number")) and ((has("mode")|not) or (.mode|type=="string")) and ((has("phase")|not) or (.phase|type=="string")) and ((has("phases")|not) or (.phases|type=="object")); if (length != 1) or (.[0] | type != "object") then error("state file must be exactly one JSON object") else .[0] | if (has("active") | not) or (.active | type != "boolean") then error("active must be a boolean") elif .active != true then "inactive" elif (topkeys_ok | not) then error("unknown top-level key") elif (topvalues_ok | not) then error("top-level field has wrong type") else ( [.. | objects | select(has("phases"))] as $cycles | ([., (to_entries[] | select(.key == "fix_regression" or (.key | test("^fix_regression_cycle_[0-9]+$"))) | .value)] | map(select(type == "object" and has("phases")))) as $allowed | if (($cycles | length) != ($allowed | length)) then error("phases in a disallowed location") elif ($cycles | map(.phases | type == "object") | all | not) then error("phases must be an object") elif ($cycles | map(. as $c | ["gate_hypothesis_cause","gate_plan","audit","gate_quality"] | map(. as $p | $c | phase_ok($p)) | all) | all | not) then error("gated phase has invalid shape") else "active" end ) end end' 2>/dev/null); then
      if [ "$_verdict" = "active" ]; then
        # Count EVERY active file (no break) so a second simultaneously-active
        # state file cannot be silently ignored: the first-active-wins glob
        # order would otherwise decide every score gate by whichever file sorts
        # first, regardless of which issue the command targets (issue #843).
        # The first active file is still remembered as STATE_FILE so the
        # single-active path is byte-identical to before; the ≥2 fail-closed
        # branch below consults ACTIVE_COUNT.
        ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
        ACTIVE_FILES="${ACTIVE_FILES:+$ACTIVE_FILES }$_sf"
        if [ -z "$STATE_FILE" ]; then
          STATE_FILE="$_sf"
          STATE_JSON="$_content"
        fi
      fi
    else
      MALFORMED_STATE="$_sf"    # parse error / unreadable → corrupt; cannot trust its active flag
    fi
  done
fi

# Fail closed on corrupt state: no readable active file, but a malformed state
# file exists whose active flag we cannot determine. The state file gates BOTH
# git push / gh pr create AND score-gated Agent spawns (docs/evaluation-system.md),
# so refuse all of those on corrupt state — while leaving read-only commands and
# the writes needed to repair the file unblocked (no recovery deadlock). Research
# (Explore / Plan / claude-code-guide) and evaluation agents never gate, so they
# stay allowed even on corrupt state. The unconditional Section 1 denies already ran.
if [ -z "$STATE_FILE" ] && [ -n "$MALFORMED_STATE" ]; then
  if is_score_gated_surface; then
    echo "BLOCKED: malformed AutoFlow state file: $MALFORMED_STATE" >&2
    echo "A .autoflow/*.json state file is malformed (invalid JSON or schema) — refusing score-gated work on corrupt state. Fix or remove it." >&2
    exit 2
  fi
fi

# Fail closed on multiple active state files: one issue runs at a time
# (CLAUDE.md > PR Wait Rule). When two or more state files are simultaneously
# active, the first-active-wins discovery above would decide every score gate by
# whichever file sorts first in the glob — regardless of which issue the pushed
# branch / spawn actually targets (issue #843). Shares `is_score_gated_surface`
# with the corrupt-state branch above: only the score-gated surface (git push /
# gh pr create / gated Agent spawns, undeclared spawns included) fails closed;
# read-only commands, repair writes, and research/evaluation spawns stay
# unblocked so the operator can deactivate the stale file without a deadlock.
# Runs while STATE_FILE is set to the first active file, ahead of every score
# gate.
if [ "$ACTIVE_COUNT" -ge 2 ]; then
  if is_score_gated_surface; then
    echo "BLOCKED: multiple active AutoFlow state files — one issue runs at a time (CLAUDE.md > PR Wait Rule)." >&2
    echo "Active: $ACTIVE_FILES" >&2
    echo "Deactivate all but the in-flight cycle's state file before score-gated work." >&2
    exit 2
  fi
fi

if [ -z "$STATE_FILE" ]; then
  exit 0
fi

ACTIVE=$(printf '%s' "$STATE_JSON" | jq -r '.active // false' 2>/dev/null)
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# ── Compute PASS verdict from raw scores ──
# Output: JSON { "pass": bool, "avg": float, "min": int, "security": int|null, "reason": string }
#
# State files can nest cycles (`fix_regression`, `fix_regression_cycle_2`, …)
# alongside the top-level `phases.*`. A previous cycle's gate scores are
# preserved at the top level, so a naive top-level lookup silently passes the
# stale verdict instead of the current cycle's. Select the scores of the LAST
# cycle location that HAS a `phases[$phase]` key at all — JSON authoring order
# corresponds to cycle order (base → fix_regression → fix_regression_cycle_N),
# so `last` is the most recent cycle that recorded this phase. An empty
# `scores` at that most-recent recording location is treated as "evaluation not
# run" (fail closed via the length==0 branch below) — NEVER a fallback to an
# earlier cycle's PASS. The removed `map(select(non-empty))` empty-skipping is
# exactly what let the stale-PASS fallback through, so it is not re-added: a
# future author must not filter empty score objects out before `last`.
# Companion invariant (deadlock-safety, not code-enforced): a nested
# `fix_regression*` object must record ONLY the phases actually re-run in that
# regression — never a full empty-template reset of all five phase keys. This
# keeps the GATE:QUALITY→RED regression (which re-runs AUDIT/GATE:QUALITY but
# not GATE:PLAN) deadlock-free: the regression carries no `phases.gate_plan`
# key, so `select(.phases | has("gate_plan"))` skips it and the walk resolves
# the base cycle's gate_plan PASS. Current top-level-reset authoring never
# produces the all-`{}` shape.
check_scores() {
  local phase_key=$1
  printf '%s' "$STATE_JSON" | jq --arg phase "$phase_key" '
    [.. | objects | select(has("phases")) | select(.phases | has($phase)) | .phases[$phase].scores]
    | (last // {}) |
    if length == 0 then
      { pass: false, avg: 0, min: 0, security: null, reason: "evaluation not run" }
    else
      (to_entries | map(.value | if type == "object" then .score else . end | tonumber)) as $vals |
      ($vals | add / length * 10 | round / 10) as $avg |
      ($vals | min) as $min |
      (.["security"] // .["보안"] // null | if type == "object" then .score else . end) as $sec |
      if $sec != null and $sec <= 3 then
        { pass: false, avg: $avg, min: $min, security: $sec,
          reason: ("security score " + ($sec | tostring) + " — automatic rework") }
      elif $min < 7 then
        { pass: false, avg: $avg, min: $min, security: $sec,
          reason: ("lowest score " + ($min | tostring) + " — each item must be ≥ 7") }
      elif $avg < 7.5 then
        { pass: false, avg: $avg, min: $min, security: $sec,
          reason: ("average " + ($avg | tostring) + " — must be ≥ 7.5") }
      else
        { pass: true, avg: $avg, min: $min, security: $sec, reason: "PASS" }
      end
    end
  '
}

# Block if the gate's check_scores result is not pass.
block_with_scores() {
  local gate_name=$1
  local phase_key=$2
  local result pass
  # A security gate must never let an error in score evaluation become a
  # non-blocking exit. If check_scores fails — e.g. a raw score is non-numeric so
  # jq's `tonumber` errors and exits 5, which PreToolUse does NOT treat as
  # blocking (only exit 2 blocks) — fail closed with an explicit exit 2 (PR #242
  # review). The assignment sits in the `if` condition so the failure does not
  # trip `set -e` before it is handled. All four score gates route through here,
  # so this single guard closes the whole "jq error → exit 5 → fail-open" class.
  if ! result=$(check_scores "$phase_key" 2>/dev/null); then
    echo "BLOCKED: ${gate_name}" >&2
    echo "Reason: state scores are not evaluable (corrupt or non-numeric) — failing closed." >&2
    echo "State file: $STATE_FILE" >&2
    exit 2
  fi
  pass=$(echo "$result" | jq -r '.pass')

  if [ "$pass" != "true" ]; then
    local reason avg min_val
    reason=$(echo "$result" | jq -r '.reason')
    avg=$(echo "$result" | jq -r '.avg')
    min_val=$(echo "$result" | jq -r '.min')
    echo "BLOCKED: ${gate_name}" >&2
    echo "Reason: ${reason}" >&2
    echo "Current scores — average: ${avg}, lowest: ${min_val}" >&2
    echo "PASS criteria — average ≥ 7.5, each ≥ 7, security > 3" >&2
    echo "State file: $STATE_FILE" >&2
    exit 2
  fi
}

# ── Gate: Agent spawn (declared role → gate; the hook owns the mapping) ──
if [ "$TOOL_NAME" = "Agent" ]; then
  ROLE=$(resolve_spawn_role)
  case "$ROLE" in
    research|analysis|evaluation)
      # research: read-only, never gates. evaluation: must stay spawnable —
      # blocking it would deadlock the very gate it produces scores for.
      # analysis: DIAGNOSE precedes every gate, so it has no prerequisite.
      exit 0
      ;;
    planning)
      # Gate 1: planning spawn → GATE:HYPOTHESIS pass required (bug issues only).
      # If gate_hypothesis_cause.verdict does not contain "skip", treat as bug issue.
      # Fail closed if the verdict cannot be read — a JSON-valid but schema-corrupt
      # state (e.g. `.phases` is not an object) makes this jq error and would
      # otherwise exit 5, a NON-blocking PreToolUse code (PR #242 review). The
      # assignment sits in the `if` condition so set -e does not fire first.
      if ! VERDICT=$(printf '%s' "$STATE_JSON" | jq -r '.phases.gate_hypothesis_cause.verdict // empty' 2>/dev/null); then
        echo "BLOCKED: AutoFlow state schema is corrupt (.phases is not an object) — failing closed for the Agent spawn." >&2
        echo "State file: $STATE_FILE" >&2
        exit 2
      fi
      if [ -n "$VERDICT" ] && ! echo "$VERDICT" | grep -qi "skip"; then
        block_with_scores "planning agent spawn requires GATE:HYPOTHESIS pass" "gate_hypothesis_cause"
      fi
      ;;
    implementation|testing)
      # Gate 2: implementation / test-writing spawn → GATE:PLAN pass required.
      block_with_scores "${ROLE} agent spawn requires GATE:PLAN pass" "gate_plan"
      ;;
    *)
      # Undeclared spawn while a cycle is active: deny LOUDLY. Inference from
      # prompt text is deliberately not attempted — a silent misclassification
      # (either direction) is worse than this explicit, self-describing stop.
      echo "BLOCKED: Agent spawn without a declared AutoFlow role while a cycle is active." >&2
      echo "Declare the role structurally — direct spawn: subagent_type autoflow-{analyzer|planner|implementer|tester|evaluator}; team spawn: name prefix {analysis|plan|impl|dev|test|eval}-. Research types (Explore/Plan/claude-code-guide) pass as-is." >&2
      echo "State file: $STATE_FILE" >&2
      exit 2
      ;;
  esac
fi

# ── Gate 3: git push → AUDIT + GATE:QUALITY pass required ──
if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}${GIT_PUSH}"; then
  block_with_scores "git push requires AUDIT pass" "audit"
  block_with_scores "git push requires GATE:QUALITY pass" "gate_quality"
fi

# ── Gate 4: gh pr create → AUDIT + GATE:QUALITY pass required ──
if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$SCAN" | grep -qE "${CMD_BOUNDARY}gh[[:space:]]+pr[[:space:]]+create\b"; then
  block_with_scores "gh pr create requires AUDIT pass" "audit"
  block_with_scores "gh pr create requires GATE:QUALITY pass" "gate_quality"
fi

# Pass.
exit 0
