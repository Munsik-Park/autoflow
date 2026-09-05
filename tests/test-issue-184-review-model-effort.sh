#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/review/codex-review-pr.sh scripts/review/lib/review-config.sh scripts/preflight/check-review-backend.sh plugin/autoflow/skills/install/scripts/detect.sh docs/reviewer-backend.md setup/manifest.json
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: reviewer backend model / effort configuration — Issue #184
# =============================================================================
# Scope (issue #184 acceptance criteria): `.claude/autoflow.local.json`'s
# `.review.<backend>.{model,effort}` pins reach the reviewer CLI exactly
# (codex: --model / -c model_reasoning_effort=…; claude: --model / --effort),
# absence inherits (no flag), invalid values fail closed BEFORE any reviewer
# launches, the --probe applies the same resolver as the live wrapper, the
# claude isolation triple does not regress, and the start marker names the
# backend + effective pins without leaking credentials.
#
# Method: the wrapper and the probe run under PATH stubs for claude / codex /
# gh that capture their own argv one element per line — an empty argument or
# a split value is therefore distinguishable from a skipped flag. No live CLI
# is ever invoked. The wrapper runs inside an isolated tar-copy of the repo so
# `git rev-parse --show-toplevel` resolves inside the fixture.
# =============================================================================

# shellcheck disable=SC2034  # several captures are consumed inside assert_* eval strings
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER_REL="scripts/review/codex-review-pr.sh"
CHECK_REL="scripts/preflight/check-review-backend.sh"
LIB_REL="scripts/review/lib/review-config.sh"
DETECT_SH="$PROJECT_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"; FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  fi
}

echo "=============================================="
echo "reviewer model / effort configuration (issue #184)"
echo "=============================================="

# ---------------------------------------------------------------------------
# Isolated fixture repo + stub farm.
# ---------------------------------------------------------------------------
TMP_REPO="$(mktemp -d)"
(cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO" && tar -xf -) 2>/dev/null
(cd "$TMP_REPO" && git init -q && git config user.email t@example.com && git config user.name t && git add -A && git commit -q -m fixture) >/dev/null 2>&1
mkdir -p "$TMP_REPO/.claude"
CFG="$TMP_REPO/.claude/autoflow.local.json"

FAKEBIN="$(mktemp -d)"
CAP_CLAUDE="$(mktemp)"
CAP_CODEX="$(mktemp)"

cat > "$FAKEBIN/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  *"pr view"*"--json state,headRefName"*) printf 'OPEN\tmain\n' ;;
  *"repo view"*"nameWithOwner"*)          printf 'acme/repo\n' ;;
  *) echo "unexpected gh stub call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$FAKEBIN/gh"

# Each stub appends argv one element per line, its cwd, and the API-key
# visibility fact; both return success with a plausible reply.
for cli in claude codex; do
  cap="$CAP_CLAUDE"; [ "$cli" = codex ] && cap="$CAP_CODEX"
  cat > "$FAKEBIN/$cli" <<STUB
#!/usr/bin/env bash
{
  echo "ARGV_ARGS_BEGIN"
  printf '%s\n' "\$@"
  echo "ARGV_ARGS_END"
  echo "CWD:\$(pwd)"
  if [ -n "\${ANTHROPIC_API_KEY:-}" ]; then echo "ANTHROPIC_API_KEY_VISIBLE:yes"; else echo "ANTHROPIC_API_KEY_VISIBLE:no"; fi
} >> "$cap"
echo '{"result":"READY"}'
exit 0
STUB
  chmod +x "$FAKEBIN/$cli"
done

# has_arg <capture> <token>            — an argv element equal to <token>
# has_pair <capture> <flag> <value>    — <flag> immediately followed by <value>
has_arg()  { sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' "$1" | grep -qxF -- "$2"; }
has_pair() { sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' "$1" | awk -v f="$2" -v v="$3" 'prev == f && $0 == v { found = 1 } { prev = $0 } END { exit found ? 0 : 1 }'; }

# run_wrapper <extra env...> — runs the wrapper against $CFG (as it stands),
# resetting both captures; sets W_EXIT and W_LOG.
run_wrapper() {
  : > "$CAP_CLAUDE"; : > "$CAP_CODEX"
  W_LOG="$(mktemp)"
  ( cd "$TMP_REPO" && env PATH="$FAKEBIN:$PATH" ANTHROPIC_API_KEY=sk-test-fixture-184 \
      CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=parent-test "$@" \
      bash "$TMP_REPO/$WRAPPER_REL" --pr 123 >"$W_LOG" 2>&1 )
  W_EXIT=$?
}

# run_check <args...> — runs the fixture copy of check-review-backend.sh from
# the fixture root (so it reads $CFG); sets C_EXIT and C_LOG.
run_check() {
  : > "$CAP_CLAUDE"; : > "$CAP_CODEX"
  C_LOG="$(mktemp)"
  ( cd "$TMP_REPO" && env PATH="$FAKEBIN:$PATH" ANTHROPIC_API_KEY=sk-test-fixture-184 \
      bash "$TMP_REPO/$CHECK_REL" "$@" >"$C_LOG" 2>&1 )
  C_EXIT=$?
}

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-2: codex backend — configured model/effort propagate exactly ==="
cat > "$CFG" <<'J'
{ "review": { "backend": "codex",
              "codex":  { "model": "gpt-5.6-sol", "effort": "high" },
              "claude": { "model": "opus",        "effort": "max" } } }
J
run_wrapper
assert_true "AC-2: wrapper exits 0 and dispatches the codex stub" "[ '$W_EXIT' -eq 0 ] && [ -s '$CAP_CODEX' ]"
assert_true "AC-2: codex argv carries --model gpt-5.6-sol as two adjacent elements" "has_pair '$CAP_CODEX' --model gpt-5.6-sol"
assert_true "AC-2: codex argv carries -c model_reasoning_effort=high as two adjacent elements" "has_pair '$CAP_CODEX' -c model_reasoning_effort=high"
assert_false "AC-2: the claude section's pins do NOT leak into the codex invocation" "has_arg '$CAP_CODEX' opus || has_arg '$CAP_CODEX' --effort"
assert_true "AC-2 (codex flags intact): -s workspace-write and approval_policy=never still present" "has_pair '$CAP_CODEX' -s workspace-write && has_arg '$CAP_CODEX' approval_policy=never"
assert_false "AC-2: the claude stub was not invoked" "[ -s '$CAP_CLAUDE' ]"
assert_true "AC-11: start marker names the backend and the effective configured model/effort" \
  "grep -qE '^\[codex-review\] starting codex for PR #123 \(model=gpt-5.6-sol effort=high\) at ' '$W_LOG'"
assert_false "AC-11: start marker / wrapper output never prints the exported API key value" "grep -qF 'sk-test-fixture-184' '$W_LOG'"
assert_false "AC-11: wrapper output never dumps unrelated environment values (no CLAUDE_CODE_SESSION_ID line)" "grep -qF 'CLAUDE_CODE_SESSION_ID' '$W_LOG'"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-3 / AC-7: claude backend — configured model/effort + isolation intact ==="
cat > "$CFG" <<'J'
{ "review": { "backend": "claude",
              "codex":  { "model": "gpt-5.6-sol", "effort": "high" },
              "claude": { "model": "opus",        "effort": "max" } } }
J
run_wrapper CLAUDE_SOMETHING_FUTURE=x CLAUDE_CODE_OAUTH_TOKEN=oauth-sentinel-184
assert_true "AC-3: wrapper exits 0 and dispatches the claude stub" "[ '$W_EXIT' -eq 0 ] && [ -s '$CAP_CLAUDE' ]"
assert_true "AC-3: claude argv carries --model opus as two adjacent elements" "has_pair '$CAP_CLAUDE' --model opus"
assert_true "AC-3: claude argv carries --effort max as two adjacent elements" "has_pair '$CAP_CLAUDE' --effort max"
assert_false "AC-3: the codex section's pins do NOT leak into the claude invocation" "has_arg '$CAP_CLAUDE' gpt-5.6-sol || has_arg '$CAP_CLAUDE' -c"
assert_false "AC-3: the codex stub was not invoked" "[ -s '$CAP_CODEX' ]"
TOPLEVEL="$(cd "$TMP_REPO" && git rev-parse --show-toplevel)"
CAP_CWD="$(grep '^CWD:' "$CAP_CLAUDE" | sed 's/^CWD://')"
assert_true "AC-7 (neutral cwd): claude subprocess cwd is not the repo toplevel" "[ \"\$CAP_CWD\" != \"\$TOPLEVEL\" ]"
assert_true "AC-7 (--setting-sources \"\"): the flag is followed by an EMPTY element" \
  "sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CLAUDE' | grep -A1 -xF -- '--setting-sources' | sed -n '2p' | grep -qE '^$'"
assert_true "AC-7 (tool sealing): --allowedTools Bash(gh *) and --disallowedTools Edit,Write,MultiEdit" \
  "has_pair '$CAP_CLAUDE' --allowedTools 'Bash(gh *)' && has_pair '$CAP_CLAUDE' --disallowedTools 'Edit,Write,MultiEdit'"
assert_true "AC-7 (system prompt): --system-prompt-file points at .codex/review.md" \
  "sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CLAUDE' | grep -A1 -xF -- '--system-prompt-file' | sed -n '2p' | grep -q '\.codex/review\.md$'"
assert_true "AC-7 (OAuth billing): ANTHROPIC_API_KEY is not visible to the claude subprocess" "grep -qx 'ANTHROPIC_API_KEY_VISIBLE:no' '$CAP_CLAUDE'"
assert_true "AC-7 (--repo on every gh call): the prompt carries --repo acme/repo" \
  "sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CLAUDE' | grep -qF -- '--repo acme/repo'"
assert_true "AC-11 (claude): start marker names backend + effective pins" \
  "grep -qE '^\[codex-review\] starting claude for PR #123 \(model=opus effort=max\) at ' '$W_LOG'"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-4 / AC-8: absent model/effort inherit (no flag); absent config stays codex ==="
cat > "$CFG" <<'J'
{ "review": { "backend": "codex" } }
J
run_wrapper
assert_true "AC-4 (codex, no pins): wrapper exits 0 and dispatches codex" "[ '$W_EXIT' -eq 0 ] && [ -s '$CAP_CODEX' ]"
assert_false "AC-4 (codex, no pins): no --model element is passed" "has_arg '$CAP_CODEX' --model"
assert_false "AC-4 (codex, no pins): no model_reasoning_effort override is passed" "sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CODEX' | grep -q 'model_reasoning_effort'"
assert_true "AC-11 (inherit): start marker reports model=inherit effort=inherit" \
  "grep -qE '^\[codex-review\] starting codex for PR #123 \(model=inherit effort=inherit\) at ' '$W_LOG'"

cat > "$CFG" <<'J'
{ "review": { "backend": "codex", "codex": { "model": null, "effort": null } } }
J
run_wrapper
assert_true "AC-4 (explicit null): null model/effort read as absent — codex dispatched with no pins" \
  "[ '$W_EXIT' -eq 0 ] && [ -s '$CAP_CODEX' ] && ! has_arg '$CAP_CODEX' --model && ! sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CODEX' | grep -q model_reasoning_effort"

cat > "$CFG" <<'J'
{ "review": { "backend": "codex", "codex": { "model": "gpt-5.6-sol" } } }
J
run_wrapper
assert_true "AC-4 (model only): --model passed, effort inherited (no model_reasoning_effort)" \
  "has_pair '$CAP_CODEX' --model gpt-5.6-sol && ! sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CODEX' | grep -q model_reasoning_effort"
assert_true "AC-11 (partial): start marker reports model=gpt-5.6-sol effort=inherit" "grep -qF '(model=gpt-5.6-sol effort=inherit)' '$W_LOG'"

cat > "$CFG" <<'J'
{ "review": { "backend": "claude" } }
J
run_wrapper
assert_true "AC-4 (claude, no pins): claude dispatched with neither --model nor --effort" \
  "[ '$W_EXIT' -eq 0 ] && [ -s '$CAP_CLAUDE' ] && ! has_arg '$CAP_CLAUDE' --model && ! has_arg '$CAP_CLAUDE' --effort"
run_wrapper MODEL=review-model-fixture
assert_true "AC-4 (claude legacy MODEL env): with no configured model, MODEL env still reaches claude as --model" \
  "has_pair '$CAP_CLAUDE' --model review-model-fixture"
cat > "$CFG" <<'J'
{ "review": { "backend": "claude", "claude": { "model": "opus" } } }
J
run_wrapper MODEL=review-model-fixture
assert_true "AC-4 (precedence): a configured model wins over the legacy MODEL env" \
  "has_pair '$CAP_CLAUDE' --model opus && ! has_arg '$CAP_CLAUDE' review-model-fixture"
cat > "$CFG" <<'J'
{ "review": { "backend": "codex" } }
J
run_wrapper MODEL=review-model-fixture
assert_false "AC-4 (MODEL env is claude-only): MODEL env never reaches the codex invocation" "has_arg '$CAP_CODEX' --model"

rm -f "$CFG"
run_wrapper
assert_true "AC-8 (absent file): backend defaults to codex, no pins, exit 0" \
  "[ '$W_EXIT' -eq 0 ] && [ -s '$CAP_CODEX' ] && ! has_arg '$CAP_CODEX' --model && grep -qF '(model=inherit effort=inherit)' '$W_LOG'"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-5: invalid configuration fails closed before any reviewer launches ==="
fail_closed_arm() {
  local desc="$1" json="$2" needle="$3"
  printf '%s\n' "$json" > "$CFG"
  run_wrapper
  assert_true "AC-5 ($desc): wrapper exits 2" "[ '$W_EXIT' -eq 2 ]"
  assert_true "AC-5 ($desc): neither reviewer stub was invoked" "[ ! -s '$CAP_CODEX' ] && [ ! -s '$CAP_CLAUDE' ]"
  assert_true "AC-5 ($desc): stderr names the cause ('$needle')" "grep -qiE -- '$needle' '$W_LOG'"
  assert_false "AC-5 ($desc): no start marker is printed on the rejected path" "grep -q 'starting' '$W_LOG'"
}
fail_closed_arm "codex unsupported effort"  '{ "review": { "backend": "codex",  "codex":  { "effort": "bogus" } } }'   'unsupported codex effort.*bogus'
fail_closed_arm "claude unsupported effort" '{ "review": { "backend": "claude", "claude": { "effort": "minimal" } } }' 'unsupported claude effort.*minimal'
fail_closed_arm "codex effort case-sensitive" '{ "review": { "backend": "codex", "codex": { "effort": "High" } } }'  'unsupported codex effort'
fail_closed_arm "empty model"               '{ "review": { "backend": "codex",  "codex":  { "model": "" } } }'        'empty .review.codex.model'
fail_closed_arm "empty effort"              '{ "review": { "backend": "claude", "claude": { "effort": "" } } }'       'empty .review.claude.effort'
fail_closed_arm "non-string effort"         '{ "review": { "backend": "codex",  "codex":  { "effort": 3 } } }'        'expected a string'
fail_closed_arm "non-string model"          '{ "review": { "backend": "codex",  "codex":  { "model": ["a"] } } }'     'expected a string'
fail_closed_arm "malformed JSON"            '{ "review": { "backend": "codex", "codex": { "model": '                  'not valid JSON'
fail_closed_arm "empty backend"             '{ "review": { "backend": "" } }'                                          'empty .review.backend'
fail_closed_arm "unknown backend"           '{ "review": { "backend": "gemini" } }'                                    'unknown review backend'

# The OTHER backend's section is not validated (only the configured one is).
printf '%s\n' '{ "review": { "backend": "codex", "codex": { "effort": "high" }, "claude": { "effort": "bogus" } } }' > "$CFG"
run_wrapper
assert_true "AC-5 (scope): an invalid pin in the NON-configured backend's section does not block the configured backend" \
  "[ '$W_EXIT' -eq 0 ] && has_pair '$CAP_CODEX' -c model_reasoning_effort=high"

# jq absent while the config is present: a PATH farm resolving every
# executable except jq (the 979 cycle-5b technique).
NOJQ_DIR="$(mktemp -d)"
_oldifs="$IFS"; IFS=':'
for _d in $FAKEBIN $PATH; do
  [ -n "$_d" ] && [ -d "$_d" ] || continue
  for _f in "$_d"/*; do
    [ -f "$_f" ] && [ -x "$_f" ] || continue
    _name="$(basename "$_f")"
    [ "$_name" = "jq" ] && continue
    [ -e "$NOJQ_DIR/$_name" ] && continue
    ln -s "$_f" "$NOJQ_DIR/$_name" 2>/dev/null
  done
done
IFS="$_oldifs"
if PATH="$NOJQ_DIR" command -v jq >/dev/null 2>&1; then
  assert_true "AC-5 setup sanity: jq-absent PATH farm hides jq" "false"
else
  printf '%s\n' '{ "review": { "backend": "codex", "codex": { "effort": "high" } } }' > "$CFG"
  : > "$CAP_CODEX"; : > "$CAP_CLAUDE"; NOJQ_LOG="$(mktemp)"
  ( cd "$TMP_REPO" && env PATH="$NOJQ_DIR" bash "$TMP_REPO/$WRAPPER_REL" --pr 123 >"$NOJQ_LOG" 2>&1 ); NOJQ_EXIT=$?
  assert_true "AC-5 (jq absent, config present): wrapper exits 2 naming jq, no reviewer launched" \
    "[ '$NOJQ_EXIT' -eq 2 ] && grep -qi 'jq' '$NOJQ_LOG' && [ ! -s '$CAP_CODEX' ] && [ ! -s '$CAP_CLAUDE' ]"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-6: check-review-backend.sh --probe applies the same resolver ==="
cat > "$CFG" <<'J'
{ "review": { "backend": "codex",
              "codex":  { "model": "gpt-5.6-sol", "effort": "xhigh" },
              "claude": { "model": "opus",        "effort": "low" } } }
J
run_check --probe
assert_true "AC-6 (codex probe): exits 0 and invokes the codex stub" "[ '$C_EXIT' -eq 0 ] && [ -s '$CAP_CODEX' ]"
assert_true "AC-6 (codex probe): argv carries --model gpt-5.6-sol and -c model_reasoning_effort=xhigh" \
  "has_pair '$CAP_CODEX' --model gpt-5.6-sol && has_pair '$CAP_CODEX' -c model_reasoning_effort=xhigh"
assert_true "AC-6 (codex probe): marker names backend + effective pins" "grep -qF -- '--probe: codex (model=gpt-5.6-sol effort=xhigh)' '$C_LOG'"
assert_false "AC-6 (codex probe): the API key value is never printed" "grep -qF 'sk-test-fixture-184' '$C_LOG'"

run_check --backend claude --probe
assert_true "AC-6 (claude probe via --backend override): exits 0 and invokes the claude stub" "[ '$C_EXIT' -eq 0 ] && [ -s '$CAP_CLAUDE' ]"
assert_true "AC-6 (claude probe): argv carries --model opus and --effort low from the claude section" \
  "has_pair '$CAP_CLAUDE' --model opus && has_pair '$CAP_CLAUDE' --effort low"
assert_true "AC-6 (claude probe, isolation): --setting-sources \"\" still passed" \
  "sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CLAUDE' | grep -A1 -xF -- '--setting-sources' | sed -n '2p' | grep -qE '^$'"
assert_true "AC-6 (claude probe, isolation): ANTHROPIC_API_KEY not visible" "grep -qx 'ANTHROPIC_API_KEY_VISIBLE:no' '$CAP_CLAUDE'"

cat > "$CFG" <<'J'
{ "review": { "backend": "codex" } }
J
run_check --probe
assert_true "AC-6 (probe, no pins): codex invoked with no --model / model_reasoning_effort (inherit)" \
  "[ '$C_EXIT' -eq 0 ] && [ -s '$CAP_CODEX' ] && ! has_arg '$CAP_CODEX' --model && ! sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' '$CAP_CODEX' | grep -q model_reasoning_effort"
assert_true "AC-6 (probe, no pins): marker reports inherit" "grep -qF -- '--probe: codex (model=inherit effort=inherit)' '$C_LOG'"

printf '%s\n' '{ "review": { "backend": "codex", "codex": { "effort": "bogus" } } }' > "$CFG"
run_check --probe
assert_true "AC-6 (probe, invalid effort): exits 2 with the same diagnostic, no CLI invoked" \
  "[ '$C_EXIT' -eq 2 ] && grep -qi 'unsupported codex effort' '$C_LOG' && [ ! -s '$CAP_CODEX' ]"
run_check
assert_true "AC-6 (presence path, invalid effort): PREFLIGHT presence check also fails closed (exit 2)" \
  "[ '$C_EXIT' -eq 2 ] && grep -qi 'unsupported codex effort' '$C_LOG'"
printf '%s\n' '{ "review": { "backend": "codex", "codex": { "model": "" } } }' > "$CFG"
run_check
assert_true "AC-6 (presence path, empty model): exit 2 naming the empty key" "[ '$C_EXIT' -eq 2 ] && grep -qi 'empty .review.codex.model' '$C_LOG'"
rm -f "$CFG"
run_check
assert_true "AC-8 (presence path, absent config): still exit 0 on the codex default" "[ '$C_EXIT' -eq 0 ]"

# ---------------------------------------------------------------------------
echo ""
echo "=== Single source of truth + delivery + install-time reporting ==="
assert_true "SSOT: the wrapper sources scripts/review/lib/review-config.sh" \
  "grep -qE '^\. .*lib/review-config\.sh' '$PROJECT_ROOT/$WRAPPER_REL'"
assert_true "SSOT: check-review-backend.sh sources scripts/review/lib/review-config.sh" \
  "grep -qE '^\. .*review/lib/review-config\.sh' '$PROJECT_ROOT/$CHECK_REL'"
assert_false "SSOT: neither consumer reads .review.backend from the file on its own any more" \
  "grep -q 'review.backend // ' '$PROJECT_ROOT/$WRAPPER_REL' '$PROJECT_ROOT/$CHECK_REL'"
assert_false "SSOT: the wrapper no longer carries its own MODEL env passthrough" \
  "grep -qF 'MODEL:+--model' '$PROJECT_ROOT/$WRAPPER_REL'"
assert_true "delivery: setup/manifest.json ships the resolver as a root-layer copy artifact" \
  "jq -e '.artifacts[] | select(.source == \"scripts/review/lib/review-config.sh\" and .kind == \"copy\" and .tier == \"root-layer\")' '$PROJECT_ROOT/setup/manifest.json' >/dev/null"
assert_true "delivery: the scaffold .claude/autoflow.local.json still pins no model/effort (absence = inherit)" \
  "! grep -qE '\"(model|effort)\"' '$PROJECT_ROOT/.claude/autoflow.local.json'"
assert_true "lib: bash -n parses under the system /bin/bash (macOS 3.2) as well" \
  "/bin/bash -n '$PROJECT_ROOT/$LIB_REL' && /bin/bash -n '$PROJECT_ROOT/$WRAPPER_REL'"

DT="$(mktemp -d)"; git -C "$DT" init -q; mkdir -p "$DT/.claude"
printf '%s\n' '{ "review": { "backend": "claude", "claude": { "model": "opus", "effort": "high" } } }' > "$DT/.claude/autoflow.local.json"
DET="$(TARGET_ROOT="$DT" sh "$DETECT_SH" 2>/dev/null)"
assert_true "detect.sh: reports the configured backend's pins as REVIEW_MODEL / REVIEW_EFFORT" \
  "printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_MODEL=opus' && printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_EFFORT=high'"
printf '%s\n' '{ "review": { "backend": "codex", "claude": { "model": "opus" } } }' > "$DT/.claude/autoflow.local.json"
DET="$(TARGET_ROOT="$DT" sh "$DETECT_SH" 2>/dev/null)"
assert_true "detect.sh: absent pins for the configured backend report inherit (other section ignored)" \
  "printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_MODEL=inherit' && printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_EFFORT=inherit'"
printf '%s\n' '{ "review": { "backend": "codex", "codex": { "model": "", "effort": 1 } } }' > "$DT/.claude/autoflow.local.json"
DET="$(TARGET_ROOT="$DT" sh "$DETECT_SH" 2>/dev/null)"
assert_true "detect.sh: empty / non-string pins report invalid" \
  "printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_MODEL=invalid' && printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_EFFORT=invalid'"
rm -f "$DT/.claude/autoflow.local.json"
DET="$(TARGET_ROOT="$DT" sh "$DETECT_SH" 2>/dev/null)"
assert_true "detect.sh: absent config reports codex + inherit/inherit (backward compatible)" \
  "printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_BACKEND=codex' && printf '%s\n' \"\$DET\" | grep -qx 'REVIEW_MODEL=inherit'"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-10: documentation ==="
DOC="$PROJECT_ROOT/docs/reviewer-backend.md"
assert_true "docs: reviewer-backend.md has a 'Model and effort' section" "grep -q '^## Model and effort' '$DOC'"
assert_true "docs: the section states the codex flag mapping (--model, model_reasoning_effort)" \
  "grep -q 'codex exec --model' '$DOC' && grep -q 'model_reasoning_effort=' '$DOC'"
assert_true "docs: the section states the claude flag mapping (--model, --effort)" "grep -q 'claude -p --effort' '$DOC'"
assert_true "docs: the section lists both effort vocabularies" \
  "grep -qF 'xhigh' '$DOC' && grep -qE '\`minimal\`' '$DOC' && grep -qE '\`max\`' '$DOC'"
assert_true "docs: the section states precedence and that absence inherits" \
  "grep -qi 'Precedence' '$DOC' && grep -qi 'Inherit means no flag' '$DOC'"
assert_true "docs: the section distinguishes the orchestrating session from the isolated reviewer" \
  "grep -qi 'Orchestrator vs. reviewer' '$DOC'"
assert_true "docs: SETUP-GUIDE mentions per-backend model/effort pinning" \
  "grep -qi 'model and effort per backend' '$PROJECT_ROOT/setup/SETUP-GUIDE.md'"
assert_true "docs: install SKILL.md discloses REVIEW_MODEL / REVIEW_EFFORT" \
  "grep -q 'REVIEW_MODEL' '$PROJECT_ROOT/plugin/autoflow/skills/install/SKILL.md' && grep -q 'REVIEW_EFFORT' '$PROJECT_ROOT/plugin/autoflow/skills/install/SKILL.md'"
assert_true "docs: init.sh next-steps mention the optional model/effort pins" \
  "grep -q 'model/effort' '$PROJECT_ROOT/setup/init.sh'"

# ---------------------------------------------------------------------------
rm -rf "$TMP_REPO" "$FAKEBIN" "$NOJQ_DIR" "$DT" 2>/dev/null
rm -f "$CAP_CLAUDE" "$CAP_CODEX" 2>/dev/null

echo ""
echo "=============================================="
echo "Results: ${PASS}/${TESTS} passed, ${FAIL} failed"
echo "=============================================="
[ "$FAIL" -eq 0 ]
