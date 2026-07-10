#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: HANDOFF reviewer backend selection — claude branch (AC-1a) + API-key
#       guard (AC-5) — Issue #979
# =============================================================================
# Scope (.autoflow/issue-979-verification-design.md §1 AC-1/AC-5, feature
# design §5.2/§6): the wrapper (scripts/review/codex-review-pr.sh) gains a
# claude(-p) execution branch selected via .claude/autoflow.local.json
# (D1). This suite exercises that branch end-to-end under PATH stubs — no
# live `claude`/`codex`/`gh` call is ever made ([MUST], verification design
# §0). The codex branch (AC-6) is left untouched; see
# tests/test-codex-review-label-step.sh for that regression guard.
#
# Method (verification design §1 AC-1a "Method split"): a fake `claude` on
# PATH captures its own argv+cwd+env to a file; a fake `gh` answers the two
# wrapper-process calls the design confirms are the only ones before the
# subprocess (`gh pr view` for the start-check, `gh repo view` for
# EFFECTIVE_REPO — feature §5.1.1/§5.2). The wrapper runs inside an isolated
# tar-copy of the repo (mirrors tests/test-issue-953-cycle-digest.sh's F7
# isolation technique) with a real `.claude/autoflow.local.json` scaffold
# set to backend=claude, so this exercises the wrapper's OWN backend
# derivation, not a harness re-derivation (the vacuous-assertion trap the
# verification design calls out).
#
# RED expectation (pre-implementation, this commit): ALL assertions in this
# file FAIL. The current wrapper has no backend resolution at all — it always
# invokes `codex exec` unconditionally, so the claude stub is never invoked
# and the capture file this suite inspects is never written.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER_REL="scripts/review/codex-review-pr.sh"

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
echo "codex-review wrapper — claude backend branch (AC-1a) + API-key guard (AC-5)"
echo "=============================================="

# ---------------------------------------------------------------------------
# Isolated fixture: a tar-copy of the repo (git-initted so the wrapper's own
# `cd "$(git rev-parse --show-toplevel)"` resolves inside the copy, never the
# real project tree), a fake PATH with claude/gh/codex stubs, and a real
# .claude/autoflow.local.json scaffold with backend=claude.
# ---------------------------------------------------------------------------
TMP_REPO="$(mktemp -d)"
(cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO" && tar -xf -) 2>/dev/null
(cd "$TMP_REPO" && git init -q && git config user.email t@example.com && git config user.name t && git add -A && git commit -q -m fixture) >/dev/null 2>&1

mkdir -p "$TMP_REPO/.claude"
cat > "$TMP_REPO/.claude/autoflow.local.json" <<'EOF'
{ "review": { "backend": "claude" } }
EOF

FAKEBIN="$(mktemp -d)"
CAPTURE="$(mktemp)"
CODEX_CAPTURE="$(mktemp)"
: > "$CODEX_CAPTURE"

cat > "$FAKEBIN/gh" <<EOF
#!/usr/bin/env bash
# Stub gh — answers only the two wrapper-process calls the feature design
# confirms exist before the reviewer subprocess (pr_meta start-check,
# EFFECTIVE_REPO resolution). No network call, no real gh binary invoked.
case "\$*" in
  *"pr view"*"--json state,headRefName"*)
    printf 'OPEN\tmain\n'
    ;;
  *"repo view"*"nameWithOwner"*)
    printf 'acme/repo\n'
    ;;
  *)
    echo "unexpected gh stub call: \$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$FAKEBIN/gh"

cat > "$FAKEBIN/claude" <<EOF
#!/usr/bin/env bash
# Stub claude — captures argv, cwd, and the ANTHROPIC_API_KEY env-visibility
# fact to $CAPTURE, then returns success. No live model call is made.
{
  echo "ARGV:\$*"
  echo "ARGV_ARGS_BEGIN"
  printf '%s\n' "\$@"
  echo "ARGV_ARGS_END"
  echo "CWD:\$(pwd)"
  if [ -n "\${ANTHROPIC_API_KEY:-}" ]; then
    echo "ANTHROPIC_API_KEY_VISIBLE:yes"
  else
    echo "ANTHROPIC_API_KEY_VISIBLE:no"
  fi
  echo "ENV_DUMP_BEGIN"
  env
  echo "ENV_DUMP_END"
} > "$CAPTURE"
exit 0
EOF
chmod +x "$FAKEBIN/claude"

# Codex stub — writes a sentinel to $CODEX_CAPTURE on invocation, so C3-AC-2
# (cycle 3) can assert directly that the codex reviewer never ran when the
# backend is unknown (D-3, required — the codex path is where the Medium
# finding's "silent downgrade" actually happens).
cat > "$FAKEBIN/codex" <<EOF
#!/usr/bin/env bash
echo "CODEX_INVOKED" > "$CODEX_CAPTURE"
exit 0
EOF
chmod +x "$FAKEBIN/codex"

# ---------------------------------------------------------------------------
# Run the wrapper (host-PR case: no --repo) under the stubbed PATH, inside
# the isolated fixture, with ANTHROPIC_API_KEY exported in the caller's env
# (AC-5's "even when exported" precondition).
# ---------------------------------------------------------------------------
WRAPPER_LOG="$(mktemp)"
( cd "$TMP_REPO" && PATH="$FAKEBIN:$PATH" ANTHROPIC_API_KEY=sk-test-fixture \
    CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=parent-test \
    CLAUDE_CODE_CHILD_SESSION=1 CLAUDE_SOMETHING_FUTURE=x \
    CLAUDE_CODE_OAUTH_TOKEN=oauth-sentinel-979 \
    bash "$TMP_REPO/$WRAPPER_REL" --pr 123 >"$WRAPPER_LOG" 2>&1 )
WRAPPER_EXIT=$?

assert_true "AC-1a: wrapper invokes the claude stub at all (capture file is non-empty — backend=claude actually dispatched)" \
  "[ -s '$CAPTURE' ]"

if [ -s "$CAPTURE" ]; then
  CAP_ARGV="$(grep '^ARGV:' "$CAPTURE" | sed 's/^ARGV://')"
  CAP_CWD="$(grep '^CWD:' "$CAPTURE" | sed 's/^CWD://')"
  CAP_KEY_VISIBLE="$(grep '^ANTHROPIC_API_KEY_VISIBLE:' "$CAPTURE" | sed 's/^ANTHROPIC_API_KEY_VISIBLE://')"
  TOPLEVEL="$(cd "$TMP_REPO" && git rev-parse --show-toplevel)"

  assert_true "AC-1a (neutral cwd, §3 isolation-preservation): claude subprocess cwd is NOT the repo toplevel" \
    "[ \"\$CAP_CWD\" != \"\$TOPLEVEL\" ]"
  assert_true "AC-1a (--repo on every gh call, host-PR case): captured invocation carries --repo acme/repo" \
    "printf '%s' \"\$CAP_ARGV\" | grep -qF -- '--repo acme/repo'"
  assert_true "AC-1a (--system-prompt-file, D4): captured invocation injects .codex/review.md as the system prompt file" \
    "printf '%s' \"\$CAP_ARGV\" | grep -qE -- '--system-prompt-file[= ].*\\.codex/review\\.md'"
  assert_true "AC-1a (sealing): captured invocation allows only Bash(gh *)" \
    "printf '%s' \"\$CAP_ARGV\" | grep -qF -- '--allowedTools' && printf '%s' \"\$CAP_ARGV\" | grep -qF 'Bash(gh *)'"
  assert_true "AC-1a (sealing): captured invocation disallows Edit/Write/MultiEdit" \
    "printf '%s' \"\$CAP_ARGV\" | grep -qF -- '--disallowedTools' && printf '%s' \"\$CAP_ARGV\" | grep -qE 'Edit.*Write.*MultiEdit|Edit,Write,MultiEdit'"
  assert_true "AC-1a (prompt/sentinel parity): captured invocation's prompt still directs the comment + blocked-by-review label step" \
    "printf '%s' \"\$CAP_ARGV\" | grep -qi 'blocked-by-review'"
  # VERIFY step-3 coverage addition (minimal-implementation check): the
  # headless-output contract flag was in the GREEN diff but unasserted.
  assert_true "AC-1a (headless output contract): captured invocation carries --output-format json" \
    "printf '%s' \"\$CAP_ARGV\" | grep -qE -- '--output-format[= ]json'"

  # AC-10 (INTEGRATE M-1 re-run, orchestrator probe): the gate hook also
  # ships as a USER-scope plugin (~/.claude/settings.json enabledPlugins
  # autoflow@autoflow) whose hooks load in EVERY claude session
  # regardless of cwd or env — the AC-9 env scrub alone is insufficient.
  # Probe evidence: a neutral-cwd `claude -p` control run denied
  # `gh pr merge --help` via ${CLAUDE_PLUGIN_ROOT}/hooks/check-autoflow-gate.sh;
  # the same probe with --setting-sources "" loaded no hooks and was
  # permitted, with gh/OAuth intact. The captured argv is inspected as a
  # per-argument list (ARGV_ARGS_BEGIN/END) rather than the space-joined
  # ARGV: line, because an empty-string argument is otherwise indistinguishable
  # from a skipped flag once space-joined.
  CAP_ARGS_LIST="$(sed -n '/^ARGV_ARGS_BEGIN$/,/^ARGV_ARGS_END$/p' "$CAPTURE")"
  assert_true "AC-10 (user-scope plugin hook leak, ledger M-1): captured invocation carries --setting-sources \"\" (empty value — loads no settings sources, so user-scope plugin hooks are not enabled in the reviewer session)" \
    "printf '%s\\n' \"\$CAP_ARGS_LIST\" | grep -A1 -F -x -- '--setting-sources' | tail -1 | grep -E '^\$' >/dev/null"

  assert_true "AC-5 (API-key guard, core): claude subprocess does NOT observe ANTHROPIC_API_KEY even though the caller exported it" \
    "[ \"\$CAP_KEY_VISIBLE\" = 'no' ]"
  assert_true "AC-5 (warning): a set ANTHROPIC_API_KEY triggers a stderr warning before being unset" \
    "grep -qi 'ANTHROPIC_API_KEY' '$WRAPPER_LOG' && grep -qi 'warn\\|unset' '$WRAPPER_LOG'"

  # E17 (INTEGRATE FAIL, M-1 live gate): a nested `claude -p` inherits
  # CLAUDECODE/CLAUDE_CODE_* env from the parent Claude Code session and
  # attaches to the parent project's gate hook despite neutral cwd. The fix
  # scrubs ALL `CLAUDE`-prefixed env vars (dynamic prefix, not a hardcoded
  # list) reaching the claude reviewer subprocess. Parent-side sentinels
  # (incl. a synthetic CLAUDE_SOMETHING_FUTURE, proving the scrub is
  # prefix-based, not an enumerated list) are exported at the wrapper
  # invocation above.
  CAP_ENV_DUMP="$(sed -n '/^ENV_DUMP_BEGIN$/,/^ENV_DUMP_END$/p' "$CAPTURE")"
  assert_false "C8-AC-2 (env scrub, nested-session hook leak, ledger E17): no CLAUDE-prefixed var OTHER THAN CLAUDE_CODE_OAUTH_TOKEN reaches the claude subprocess env" \
    "[ -n \"\$(printf '%s\\n' \"\$CAP_ENV_DUMP\" | grep -E '^CLAUDE[A-Z_]*=' | grep -vE '^CLAUDE_CODE_OAUTH_TOKEN=')\" ]"
  assert_true "AC-9 (env scrub survives): PATH is preserved for the claude subprocess (needed to resolve gh, etc.)" \
    "printf '%s\\n' \"\$CAP_ENV_DUMP\" | grep -q '^PATH='"
  assert_true "AC-9 (env scrub survives): HOME is preserved for the claude subprocess (needed for OAuth credential lookup)" \
    "printf '%s\\n' \"\$CAP_ENV_DUMP\" | grep -q '^HOME='"
  assert_true "C8-AC-1 (OAuth-token retention, issue #979 cycle 8): CLAUDE_CODE_OAUTH_TOKEN survives the scrub and reaches the claude subprocess env with its value unchanged" \
    "[ -n \"\$(printf '%s\\n' \"\$CAP_ENV_DUMP\" | grep -xF 'CLAUDE_CODE_OAUTH_TOKEN=oauth-sentinel-979')\" ]"
else
  echo "  SKIP: AC-1a (neutral cwd / --repo / --system-prompt-file / sealing / prompt-sentinel / output-format) + AC-10 (--setting-sources) + AC-5 (core / warning) + AC-9 (env scrub / PATH / HOME survive) + C8-AC-1 (OAuth-token retention) — claude never invoked pre-impl"
  TESTS=$((TESTS + 14))
fi

assert_true "AC-1a (completion marker, D3): wrapper emits the claude-only completion marker after the subprocess returns" \
  "grep -qE '\\[review\\] claude completed for PR #123' '$WRAPPER_LOG'"

assert_true "AC-8 (label-authority neutrality, D4): .codex/review.md's label-removal authority sentence reads backend-neutral, not codex-exec-specific" \
  "grep -qi 'configured isolated reviewer subprocess' '$PROJECT_ROOT/.codex/review.md'"
assert_false "AC-8 (label-authority neutrality, D4): the old codex-exec-specific authority phrasing is gone" \
  "grep -qi 'isolated .codex exec. subprocess' '$PROJECT_ROOT/.codex/review.md'"

# ---------------------------------------------------------------------------
# VERIFY step-3 coverage additions (minimal-implementation check): two GREEN
# hunks were uncovered — the MODEL env passthrough (${MODEL:+--model}) and the
# claude-branch EFFECTIVE_REPO resolution-failure exit 3. Both are exercised
# here with the same stub fixture (no live CLI).
# ---------------------------------------------------------------------------

# Arm 2 — MODEL passthrough: re-run the wrapper with MODEL exported; the
# captured argv must carry `--model <value>`.
WRAPPER_LOG2="$(mktemp)"
( cd "$TMP_REPO" && PATH="$FAKEBIN:$PATH" MODEL=review-model-fixture \
    bash "$TMP_REPO/$WRAPPER_REL" --pr 123 >"$WRAPPER_LOG2" 2>&1 )
assert_true "AC-1a (MODEL passthrough): an exported MODEL reaches the claude invocation as --model" \
  "grep '^ARGV:' '$CAPTURE' | grep -qF -- '--model review-model-fixture'"

# Arm 3 — EFFECTIVE_REPO resolution failure: a gh stub whose `repo view`
# fails (and no --repo given) must make the claude branch fail fast with
# exit 3 and a resolution-failure message, BEFORE any reviewer subprocess.
FAKEBIN_GHFAIL="$(mktemp -d)"
cat > "$FAKEBIN_GHFAIL/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKEBIN_GHFAIL/gh"
cp "$FAKEBIN/claude" "$FAKEBIN_GHFAIL/claude"
cp "$FAKEBIN/codex" "$FAKEBIN_GHFAIL/codex"
WRAPPER_LOG3="$(mktemp)"
: > "$CAPTURE"
( cd "$TMP_REPO" && PATH="$FAKEBIN_GHFAIL:$PATH" \
    bash "$TMP_REPO/$WRAPPER_REL" --pr 123 >"$WRAPPER_LOG3" 2>&1 )
GHFAIL_EXIT=$?
assert_true "AC-1a (repo-resolution fail-fast): claude backend exits 3 when gh repo view fails and no --repo is given" \
  "[ '$GHFAIL_EXIT' -eq 3 ]"
assert_true "AC-1a (repo-resolution fail-fast): failure message names the claude-backend repository resolution" \
  "grep -qi 'could not resolve the repository' '$WRAPPER_LOG3'"
assert_true "AC-1a (repo-resolution fail-fast): the reviewer subprocess is never invoked on resolution failure" \
  "[ ! -s '$CAPTURE' ]"

# ---------------------------------------------------------------------------
# Arm 4 (cycle 3, C3-AC-1/C3-AC-2) — unknown backend value: the wrapper must
# fail closed (exit 2 + stderr naming the value + the expected set) and must
# NOT dispatch either reviewer subprocess. Reuses the tar-copy fixture,
# rewriting its .claude/autoflow.local.json to backend=gemini.
#
# RED expectation (cycle 3, this commit): HEAD has no unknown-backend guard
# in codex-review-pr.sh, so 'gemini' falls through to the codex path — the
# codex stub runs and writes CODEX_CAPTURE, UNKNOWN_EXIT is 0 (the codex
# stub's own exit), and none of the assertions below hold.
# ---------------------------------------------------------------------------
cat > "$TMP_REPO/.claude/autoflow.local.json" <<'EOF'
{ "review": { "backend": "gemini" } }
EOF

: > "$CAPTURE"
: > "$CODEX_CAPTURE"
WRAPPER_LOG4="$(mktemp)"
( cd "$TMP_REPO" && PATH="$FAKEBIN:$PATH" \
    bash "$TMP_REPO/$WRAPPER_REL" --pr 123 >"$WRAPPER_LOG4" 2>&1 )
UNKNOWN_EXIT=$?

assert_true "C3-AC-1 (unknown backend fail-closed exit): wrapper exits 2 on an unrecognized .review.backend value ('gemini'), parity with check-review-backend.sh" \
  "[ '$UNKNOWN_EXIT' -eq 2 ]"
assert_true "C3-AC-1 (unknown backend message): stderr names 'unknown review backend', the offending value ('gemini'), and the expected codex/claude set" \
  "grep -qi 'unknown review backend' '$WRAPPER_LOG4' && grep -qF 'gemini' '$WRAPPER_LOG4' && grep -qiE \"codex.*claude|'codex' or 'claude'\" '$WRAPPER_LOG4'"
assert_true "C3-AC-2 (no reviewer subprocess, primary witness, D-3): the codex reviewer never ran — CODEX_CAPTURE sentinel stays empty" \
  "[ ! -s '$CODEX_CAPTURE' ]"
assert_true "C3-AC-2 (no reviewer subprocess, corroborating): no '[codex-review] starting' marker reached the log" \
  "! grep -q '\\[codex-review\\] starting' '$WRAPPER_LOG4'"
assert_true "C3-AC-2 (no reviewer subprocess, corroborating; inert for this arm per feature design's verification note — kept as secondary): the claude capture also stayed empty" \
  "[ ! -s '$CAPTURE' ]"

rm -f "$WRAPPER_LOG4" 2>/dev/null

echo ""
echo "=== C3-AC-4 (doc contract) — docs/reviewer-backend.md states the wrapper's fail-closed-on-unknown behavior ==="

REVIEWER_BACKEND_MD="$PROJECT_ROOT/docs/reviewer-backend.md"
assert_true "C3-AC-4: docs/reviewer-backend.md names the unknown/invalid/unrecognized backend contract" \
  "[ -f '$REVIEWER_BACKEND_MD' ] && grep -qiE 'unknown|invalid|unrecognized' '$REVIEWER_BACKEND_MD'"
assert_true "C3-AC-4: the fail-closed sentence covers the wrapper (codex-review-pr.sh), not only the PREFLIGHT check" \
  "[ -f '$REVIEWER_BACKEND_MD' ] && grep -B2 -A2 -iE 'unknown|invalid|unrecognized' '$REVIEWER_BACKEND_MD' | grep -F 'codex-review-pr.sh' >/dev/null"

echo ""
echo "=== C8-AC-5 (doc contract, issue #979 cycle 8) — docs/reviewer-backend.md states the CLAUDE* scrub EXCEPTS CLAUDE_CODE_OAUTH_TOKEN ==="
assert_true "C8-AC-5 (doc carve-out): docs/reviewer-backend.md states the CLAUDE* scrub EXCEPTS CLAUDE_CODE_OAUTH_TOKEN" \
  "grep -B1 -A1 -i 'scrub' \"$REVIEWER_BACKEND_MD\" | grep -F 'CLAUDE_CODE_OAUTH_TOKEN' >/dev/null"

rm -rf "$TMP_REPO" "$FAKEBIN" "$FAKEBIN_GHFAIL" "$CAPTURE" "$CODEX_CAPTURE" "$WRAPPER_LOG" "$WRAPPER_LOG2" "$WRAPPER_LOG3" 2>/dev/null

# =============================================================================
# Cycle 5 (review-response, Codex Medium, issue-comment 4931950297) — C5-AC-1/
# 2/4/6: a malformed or empty-value .claude/autoflow.local.json must fail
# closed (exit 2, no reviewer subprocess), never silently resolve to codex;
# absent/{}/null must keep resolving to codex (regression pin).
#
# RED expectation (this commit): HEAD's `jq … 2>/dev/null || echo codex`
# idiom swallows jq's exit status, so a malformed or empty-value config is
# masked to the literal 'codex' BEFORE the existing case guard — the wrapper
# proceeds to dispatch the codex reviewer stub (CODEX_CAPTURE gets written)
# and exits 0, not 2. The malformed/empty arms below FAIL at HEAD.
# =============================================================================
echo ""
echo "=== C5-AC-1/2/4/6 (cycle 5) — malformed/empty config fail-closed at codex-review-pr.sh ==="

TMP_REPO5="$(mktemp -d)"
(cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO5" && tar -xf -) 2>/dev/null
(cd "$TMP_REPO5" && git init -q && git config user.email t@example.com && git config user.name t && git add -A && git commit -q -m fixture) >/dev/null 2>&1
mkdir -p "$TMP_REPO5/.claude"

FAKEBIN5="$(mktemp -d)"
CLAUDE_CAP5="$(mktemp)"
CODEX_CAP5="$(mktemp)"
cat > "$FAKEBIN5/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"pr view"*"--json state,headRefName"*) printf 'OPEN\tmain\n' ;;
  *"repo view"*"nameWithOwner"*) printf 'acme/repo\n' ;;
  *) echo "unexpected gh stub call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$FAKEBIN5/gh"
cat > "$FAKEBIN5/claude" <<EOF
#!/usr/bin/env bash
echo "CLAUDE_INVOKED" > "$CLAUDE_CAP5"
exit 0
EOF
chmod +x "$FAKEBIN5/claude"
cat > "$FAKEBIN5/codex" <<EOF
#!/usr/bin/env bash
echo "CODEX_INVOKED" > "$CODEX_CAP5"
exit 0
EOF
chmod +x "$FAKEBIN5/codex"

run_wrapper5() {
  # $1 = config file body (empty string => no file written)
  rm -f "$TMP_REPO5/.claude/autoflow.local.json"
  if [ -n "$1" ]; then
    printf '%s' "$1" > "$TMP_REPO5/.claude/autoflow.local.json"
  fi
  : > "$CLAUDE_CAP5"
  : > "$CODEX_CAP5"
  WRAPPER_LOG5="$(mktemp)"
  ( cd "$TMP_REPO5" && PATH="$FAKEBIN5:$PATH" \
      bash "$TMP_REPO5/$WRAPPER_REL" --pr 123 >"$WRAPPER_LOG5" 2>&1 )
  WRAPPER5_EXIT=$?
}

# --- C5-AC-1(A) + C5-AC-2: malformed JSON -> exit 2, no reviewer dispatched ---
run_wrapper5 '{ "review": { "backend": "claude"'
assert_true "C5-AC-1(A): malformed .claude/autoflow.local.json makes codex-review-pr.sh exit 2 (not silently resolve to codex)" \
  "[ '$WRAPPER5_EXIT' -eq 2 ]"
assert_true "C5-AC-1(A) message: stderr names the malformed config file" \
  "grep -qi 'autoflow.local.json' '$WRAPPER_LOG5' && grep -qiE 'malformed|not valid|invalid|parse' '$WRAPPER_LOG5'"
assert_true "C5-AC-2: no reviewer subprocess is invoked on the malformed-config fail-closed path (neither claude nor codex capture written)" \
  "[ ! -s '$CLAUDE_CAP5' ] && [ ! -s '$CODEX_CAP5' ]"
rm -f "$WRAPPER_LOG5" 2>/dev/null

# --- C5-AC-6: empty-string value -> exit 2, no reviewer dispatched ---
run_wrapper5 '{ "review": { "backend": "" } }'
assert_true "C5-AC-6(A): empty .review.backend (\"\") makes codex-review-pr.sh exit 2 (not silently resolve to codex)" \
  "[ '$WRAPPER5_EXIT' -eq 2 ]"
assert_true "C5-AC-6(A) message: stderr names the empty configured value" \
  "grep -qi 'autoflow.local.json' '$WRAPPER_LOG5' && grep -qiE 'empty' '$WRAPPER_LOG5'"
assert_true "C5-AC-6(A): no reviewer subprocess is invoked on the empty-value fail-closed path" \
  "[ ! -s '$CLAUDE_CAP5' ] && [ ! -s '$CODEX_CAP5' ]"
rm -f "$WRAPPER_LOG5" 2>/dev/null

# --- C5-AC-4: absent file / {} / null still dispatch codex (regression pin — passes at HEAD) ---
for fixture_name_body in "absent:" "empty-object:{}" "null-key:{ \"review\": { \"backend\": null } }"; do
  fname="${fixture_name_body%%:*}"
  fbody="${fixture_name_body#*:}"
  if [ "$fname" = "absent" ]; then
    run_wrapper5 ""
  else
    run_wrapper5 "$fbody"
  fi
  assert_true "C5-AC-4 ($fname): codex-review-pr.sh still dispatches the codex reviewer (exit 0, codex capture written, claude capture empty)" \
    "[ '$WRAPPER5_EXIT' -eq 0 ] && [ -s '$CODEX_CAP5' ] && [ ! -s '$CLAUDE_CAP5' ]"
  rm -f "$WRAPPER_LOG5" 2>/dev/null
done

rm -rf "$TMP_REPO5" "$FAKEBIN5" "$CLAUDE_CAP5" "$CODEX_CAP5" 2>/dev/null

# --- C5-AC-5 (class-general structural guard): the collapse idiom is gone
# from every read-path reader. Static grep, no execution.
echo ""
echo "=== C5-AC-5 (cycle 5) — collapse idiom '|| echo codex' absent from every reader ==="
assert_false "C5-AC-5: no read-path reader retains the exit-status-swallowing '|| echo codex' idiom" \
  "grep -nE '\\|\\|[[:space:]]*echo[[:space:]]+codex' '$PROJECT_ROOT/scripts/review/codex-review-pr.sh' '$PROJECT_ROOT/scripts/preflight/check-review-backend.sh' '$PROJECT_ROOT/plugin/autoflow/skills/install/scripts/detect.sh' >/dev/null 2>&1"

echo ""
echo "=== C6-AC-4 (cycle 6) — detect.sh's compound guard [ -f \$_bcfg ] && command -v jq is gone (nested-guard structure) ==="
DETECT_SH_C6="$PROJECT_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"
assert_false "C6-AC-4: detect.sh no longer carries the single-line compound guard '[ -f \"\$_bcfg\" ] && command -v jq' (split into nested file-presence / jq-presence checks)" \
  "[ -f '$DETECT_SH_C6' ] && grep -qE '\\[ -f .*_bcfg.* \\][[:space:]]*&&[[:space:]]*command -v jq' '$DETECT_SH_C6'"

echo ""
echo "=== C5-AC-1 (doc contract) — docs/reviewer-backend.md states the parse-failure/empty-value fail-closed contract ==="
assert_true "C5-AC-1 (doc): docs/reviewer-backend.md names the present-but-unparseable/empty fail-closed contract" \
  "[ -f '$REVIEWER_BACKEND_MD' ] && grep -qiE 'unparseable|not valid JSON' '$REVIEWER_BACKEND_MD' && grep -qiE 'empty' '$REVIEWER_BACKEND_MD'"

# ---------------------------------------------------------------------------
# Results.
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
