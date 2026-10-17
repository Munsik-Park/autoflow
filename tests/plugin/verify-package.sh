#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: plugin packaging acceptance suite
# =============================================================================
# Checks that the plugin package — the repository root, which is the plugin
# root (ADR-0027 D1) — and the self-hosted marketplace at
# .claude-plugin/marketplace.json are complete and wired to resolve from the
# packaged location. Plain POSIX sh + jq/cmp/grep only.
#
# packaging:
#   AC1e   declared components (agents/, hooks/hooks.json, skills/, bin/)
#          resolve; bin/autoflow-root is executable
#   AC1a/AC1b  the command skills cycle and criterion-review: SKILL.md present
#          with its frontmatter name
#   AC1f   every packaged SKILL.md frontmatter parses (POSIX defect-class
#          oracle, with its fixture specimens AC-R2d/e/g)
#   AC3    hooks/hooks.json commands are ${CLAUDE_PLUGIN_ROOT}/hooks/-anchored
#   AC3 8a the packaged gate hook, invoked once, returns a decision (allow)
#   AC5    no duplicate copy of the components (.claude/agents, .claude/hooks,
#          plugin/) remains; no component directory inside .claude-plugin/
#   AC-R1a claude plugin validate on the repository root (gating when the CLI
#          is present; its warning that a root CLAUDE.md is not loaded is
#          expected — that file is this repository's own)
# manifest:
#   AC1    plugin.json parses; `name` (the only spec-required field) is
#          'autoflow'; `version` is explicit and non-'latest' (R1 pin)
#   AC2    marketplace.json registers the plugin (name/source/version)
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

PLUGIN_DIR="$REPO_ROOT"
PLUGIN_MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
GATE_SH="$PLUGIN_DIR/hooks/check-autoflow-gate.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

failc() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s -- %s\n' "$1" "$2"
}

skipc() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf 'SKIP: %s -- %s\n' "$1" "$2"
}

# ── AC1: plugin manifest ─────────────────────────────────────────────────
echo "== AC1: plugin manifest =="
NAME=""
VERSION=""
if [ -f "$PLUGIN_MANIFEST" ] && jq -e . "$PLUGIN_MANIFEST" >/dev/null 2>&1; then
  pass "AC1a: plugin.json exists and is valid JSON"
  NAME=$(jq -r '.name // empty' "$PLUGIN_MANIFEST")
  VERSION=$(jq -r '.version // empty' "$PLUGIN_MANIFEST")

  if [ "$NAME" = "autoflow" ]; then
    pass "AC1b: name == 'autoflow' (the only Claude-Code-spec-required plugin.json field)"
  else
    failc "AC1b" "name='$NAME' (expected 'autoflow')"
  fi

  case "$VERSION" in
    "")
      failc "AC1c" "version missing (R1 tool-delivery-contract requires an explicit, pinnable version — policy-required, not spec-required)"
      ;;
    [Ll][Aa][Tt][Ee][Ss][Tt])
      failc "AC1c" "version == 'latest' (R1 forbids the unpinned form)"
      ;;
    [0-9]*.[0-9]*.[0-9]*)
      pass "AC1c: version '$VERSION' is explicit and non-'latest' (R1 policy)"
      ;;
    *)
      failc "AC1c" "version '$VERSION' does not look like a concrete semver value"
      ;;
  esac
else
  failc "AC1a" "plugin.json missing or invalid JSON at $PLUGIN_MANIFEST"
fi

echo "== AC1e: declared components resolve to files in the package =="
if [ -d "$PLUGIN_DIR/agents" ]; then
  pass "AC1e: agents/ resolves"
else
  failc "AC1e" "agents/ does not exist at $PLUGIN_DIR/agents"
fi
if [ -f "$HOOKS_JSON" ]; then
  pass "AC1e: hooks/hooks.json resolves"
else
  failc "AC1e" "hooks/hooks.json does not exist at $HOOKS_JSON"
fi
if [ -d "$PLUGIN_DIR/skills" ]; then
  pass "AC1e: skills/ resolves"
else
  failc "AC1e" "skills/ does not exist at $PLUGIN_DIR/skills"
fi
if [ -f "$PLUGIN_DIR/bin/autoflow-root" ] && [ -x "$PLUGIN_DIR/bin/autoflow-root" ]; then
  pass "AC1e: bin/autoflow-root resolves and is executable"
else
  failc "AC1e" "bin/autoflow-root missing or not executable at $PLUGIN_DIR/bin/autoflow-root"
fi

# ── AC1a/AC1b: the command skills ────────────────────────────────────────
# /autoflow:cycle and /autoflow:criterion-review carry the rules a main
# session runs by (ADR-0027 D2); their bodies are generated and checked by
# tests/plugin/verify-skill-bodies.sh.
echo "== AC1a/AC1b: command skills cycle and criterion-review =="
for _cmd in cycle criterion-review; do
  _md="$PLUGIN_DIR/skills/$_cmd/SKILL.md"
  if [ -f "$_md" ]; then
    _nm=$(awk '/^---$/{n++; next} n==1 && /^name:/{print; exit}' "$_md" | sed -E 's/^name:[[:space:]]*//')
    if [ "$_nm" = "$_cmd" ]; then
      pass "AC1a: skills/$_cmd/SKILL.md exists with frontmatter name '$_cmd'"
    else
      failc "AC1a" "skills/$_cmd/SKILL.md frontmatter name='$_nm' (expected '$_cmd')"
    fi
  else
    failc "AC1b" "skills/$_cmd/SKILL.md missing at $_md"
  fi
done

# ── AC1f: gating POSIX frontmatter oracle ─────────────────────────────────
# A skill whose frontmatter does not parse does not load from the package.
# This is a defect-class validator, not a full YAML implementation -- honest
# ceiling: it catches (1) an embedded ": " (colon-space) token inside a plain
# (unquoted, non-block) scalar value or its indented continuation lines, and
# (2) a missing required "name" or "description" top-level key. It does NOT
# model YAML anchors/aliases, flow collections ([]/{}), multi-document
# streams, tag directives, or the internal contents of quoted/block scalars
# (those are colon-safe BY FORM). A key with an empty value (e.g. a
# block-sequence- or mapping-valued key) is not treated as a plain scalar, so
# its indented continuation lines are not flagged; the AC-R1a
# `claude plugin validate` gating-when-present block below remains the
# full-fidelity oracle where the CLI is available.
FM_ORACLE='
BEGIN { d=0; inplain=0; haskey_name=0; haskey_desc=0; err="" }
/^---[[:space:]]*$/ { d++; if (d==2) exit; next }
d==1 {
  if ($0 ~ /^[A-Za-z_][A-Za-z0-9_-]*:([[:space:]]|$)/) {
    key=$0; sub(/:.*/,"",key)
    if (key=="name") haskey_name=1
    if (key=="description") haskey_desc=1
    val=$0; sub(/^[A-Za-z_][A-Za-z0-9_-]*:[[:space:]]*/,"",val)
    c=substr(val,1,1)
    if (val=="") { inplain=0 }
    else if (c=="|" || c==">" || c=="\"" || c=="'"'"'") { inplain=0 }
    else {
      inplain=1
      if (val ~ /:[[:space:]]/ && err=="") err="plain-scalar embedded colon-space at line " NR " (key " key ")"
    }
  } else if ($0 ~ /^[[:space:]]/) {
    if (inplain==1 && $0 ~ /:[[:space:]]/ && err=="") err="plain-scalar continuation embedded colon-space at line " NR
  }
}
END {
  if (haskey_name==0) { print "missing required key: name"; exit 3 }
  if (haskey_desc==0) { print "missing required key: description"; exit 3 }
  if (err!="")        { print err; exit 2 }
}
'

echo "== AC1f: gating POSIX frontmatter oracle over every plugin skill =="
for _sk in "$PLUGIN_DIR"/skills/*/SKILL.md; do
  [ -e "$_sk" ] || continue
  _skname=$(basename "$(dirname "$_sk")")
  FM_OUT=$(awk "$FM_ORACLE" "$_sk" 2>&1)
  FM_RC=$?
  if [ "$FM_RC" -eq 0 ]; then
    pass "AC1f: $_skname/SKILL.md frontmatter parses (POSIX defect-class oracle)"
  else
    failc "AC1f" "$_skname/SKILL.md: $FM_OUT (oracle exit $FM_RC)"
  fi
done

echo "== AC1f: oracle fixture specimens (in-test heredocs; non-vacuity of the oracle) =="
FM_TMP=$(mktemp -d)

# spec-embedded-colon: the literal pre-fix frontmatter of the install skill
# (retired with the stamp, ADR-0027 D5), with its Triggers: embedded
# colon-space plain-scalar defect. It persists as a regression witness of the
# oracle, independently of any live file.
cat > "$FM_TMP/spec-embedded-colon.md" <<'SPEC_EOF'
---
name: install
description: Detect and report AutoFlow root-layer absence or drift in the current
  project, then — only after explicit user confirmation — stamp the thin-root bundle
  from the marketplace cache via init.sh and run drift-check. Detection and reporting
  are automatic and read-only; every write is opt-in. Triggers: "autoflow install",
  "stamp autoflow", "install autoflow into this repo", "/autoflow:install".
---
SPEC_EOF

# spec-missing-name: description present, no name key.
cat > "$FM_TMP/spec-missing-name.md" <<'SPEC_EOF'
---
description: A skill with no name key.
---
SPEC_EOF

# spec-missing-desc: name present, no description key.
cat > "$FM_TMP/spec-missing-desc.md" <<'SPEC_EOF'
---
name: no-description-skill
---
SPEC_EOF

# spec-blockseq-valid: name+description plus an empty-value key carrying a
# block sequence whose items embed ": " -- must NOT false-positive.
cat > "$FM_TMP/spec-blockseq-valid.md" <<'SPEC_EOF'
---
name: blockseq-skill
description: A skill whose frontmatter carries a block-sequence-valued key.
allowed-tools:
  - read: file contents
  - write: file contents
---
SPEC_EOF

# Assertion inversion: each defect specimen's EXPECTED exit is non-zero, so
# the inverted condition (rc == expected) feeds pass/failc -- the specimen's
# raw non-zero exit is never piped straight into failc.
awk "$FM_ORACLE" "$FM_TMP/spec-embedded-colon.md" >/dev/null 2>&1
FM_RC=$?
if [ "$FM_RC" -eq 2 ]; then
  pass "AC-R2d: spec-embedded-colon regression witness -> exit 2 (embedded colon-space defect; survives the SKILL.md fix)"
else
  failc "AC-R2d" "spec-embedded-colon: expected exit 2, got $FM_RC"
fi

awk "$FM_ORACLE" "$FM_TMP/spec-missing-name.md" >/dev/null 2>&1
FM_RC=$?
if [ "$FM_RC" -eq 3 ]; then
  pass "AC-R2e: spec-missing-name -> exit 3 (missing required 'name' key)"
else
  failc "AC-R2e" "spec-missing-name: expected exit 3, got $FM_RC"
fi

awk "$FM_ORACLE" "$FM_TMP/spec-missing-desc.md" >/dev/null 2>&1
FM_RC=$?
if [ "$FM_RC" -eq 3 ]; then
  pass "AC-R2e: spec-missing-desc -> exit 3 (missing required 'description' key)"
else
  failc "AC-R2e" "spec-missing-desc: expected exit 3, got $FM_RC"
fi

awk "$FM_ORACLE" "$FM_TMP/spec-blockseq-valid.md" >/dev/null 2>&1
FM_RC=$?
if [ "$FM_RC" -eq 0 ]; then
  pass "AC-R2g: spec-blockseq-valid -> exit 0 (empty-value block-seq key not mistaken for a plain scalar)"
else
  failc "AC-R2g" "spec-blockseq-valid: expected exit 0, got $FM_RC"
fi

rm -rf "$FM_TMP"

# ── AC2: marketplace registration ────────────────────────────────────────
echo "== AC2: marketplace source =="
MP_NAME=""
if [ -f "$MARKETPLACE" ] && jq -e . "$MARKETPLACE" >/dev/null 2>&1; then
  pass "AC2a: marketplace.json exists and is valid JSON"
  MP_NAME=$(jq -r '.name // empty' "$MARKETPLACE")
  P0_NAME=$(jq -r '.plugins[0].name // empty' "$MARKETPLACE")
  P0_SOURCE=$(jq -r '.plugins[0].source // empty' "$MARKETPLACE")
  P0_VERSION=$(jq -r '.plugins[0].version // empty' "$MARKETPLACE")

  if [ "$P0_NAME" = "autoflow" ]; then
    pass "AC2b: plugins[0].name == 'autoflow'"
  else
    failc "AC2b" "plugins[0].name='$P0_NAME' (expected 'autoflow')"
  fi

  if [ "$P0_SOURCE" = "./" ]; then
    pass "AC2c: plugins[0].source == './' (the repository root is the plugin root, ADR-0027 D1)"
  else
    failc "AC2c" "plugins[0].source='$P0_SOURCE' (expected './')"
  fi

  if [ -n "$VERSION" ] && [ -n "$P0_VERSION" ] && [ "$VERSION" = "$P0_VERSION" ]; then
    pass "AC2d: marketplace version matches plugin.json version ('$VERSION') — no skew"
  else
    failc "AC2d" "version cross-check failed: plugin.json='$VERSION' marketplace='$P0_VERSION'"
  fi
else
  failc "AC2a" "marketplace.json missing or invalid JSON at $MARKETPLACE"
fi

# ── AC3: hooks.json wiring (static) ──────────────────────────────────────
echo "== AC3: hooks/hooks.json wiring =="
if [ -f "$HOOKS_JSON" ] && jq -e . "$HOOKS_JSON" >/dev/null 2>&1; then
  pass "AC3a: hooks/hooks.json exists and is valid JSON"
  PRE_CMD=$(jq -r '.hooks.PreToolUse[0].hooks[0].command // empty' "$HOOKS_JSON")
  POST_CMD=$(jq -r '.hooks.PostToolUse[0].hooks[0].command // empty' "$HOOKS_JSON")

  case "$PRE_CMD" in
    '${CLAUDE_PLUGIN_ROOT}/hooks/'*)
      pass "AC3c: PreToolUse command is \${CLAUDE_PLUGIN_ROOT}-anchored"
      ;;
    *)
      failc "AC3c" "PreToolUse command='$PRE_CMD' is not \${CLAUDE_PLUGIN_ROOT}/hooks/-anchored"
      ;;
  esac
  case "$PRE_CMD" in
    *'${CLAUDE_PROJECT_DIR}'*)
      failc "AC3c" "PreToolUse command conflates \${CLAUDE_PROJECT_DIR}: $PRE_CMD"
      ;;
    *)
      pass "AC3c: PreToolUse command contains no \${CLAUDE_PROJECT_DIR} token"
      ;;
  esac
  case "$POST_CMD" in
    '${CLAUDE_PLUGIN_ROOT}/hooks/'*)
      pass "AC3c: PostToolUse command is \${CLAUDE_PLUGIN_ROOT}-anchored"
      ;;
    *)
      failc "AC3c" "PostToolUse command='$POST_CMD' is not \${CLAUDE_PLUGIN_ROOT}/hooks/-anchored"
      ;;
  esac
else
  failc "AC3a" "hooks/hooks.json missing or invalid JSON at $HOOKS_JSON"
fi

# ── AC3 8a: the packaged gate hook returns a decision (one smoke) ────────
# The allow case is the smoke: exit 0 cannot come from a script bash fails to
# parse, whose exit status (2) coincides with the deny status.
echo "== AC3 behavioral (8a): the packaged gate hook, invoked once, returns a decision (real script, never a stub) =="
if [ -f "$GATE_SH" ] && [ -x "$GATE_SH" ]; then
  BENIGN_DIR=$(mktemp -d)
  BENIGN_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  OUT=$(printf '%s' "$BENIGN_PAYLOAD" | CLAUDE_PLUGIN_ROOT=/plugin CLAUDE_PROJECT_DIR="$BENIGN_DIR" bash "$GATE_SH" 2>&1)
  CODE=$?
  if [ "$CODE" -eq 0 ]; then
    pass "AC3 8a: benign command with no active state file -> exit 0 (allow)"
  else
    failc "AC3 8a" "expected exit 0, got $CODE; output: $OUT"
  fi
  rm -rf "$BENIGN_DIR"
else
  failc "AC3 8a" "hooks/check-autoflow-gate.sh missing or not executable — cannot drive the real script"
fi

# ── AC5: one copy of each component ──────────────────────────────────────
# The components live once, at the plugin root (ADR-0027 D1). A second copy
# under .claude/ would load as project agents beside the plugin's own, and the
# former plugin/ package directory would be a second plugin source.
echo "== AC5: no duplicate component copies =="
for _dup in .claude/agents .claude/hooks plugin; do
  if [ -e "$REPO_ROOT/$_dup" ]; then
    failc "AC5 single copy" "$_dup exists — the components live only at the plugin root (agents/, hooks/, skills/)"
  else
    pass "AC5 single copy: no $_dup"
  fi
done

# ── AC5: structure conformance (spec Warning) ────────────────────────────
echo "== AC5: structure conformance =="
for d in "$REPO_ROOT/.claude-plugin"; do
  if [ -d "$d" ]; then
    if [ -d "$d/agents" ] || [ -d "$d/skills" ] || [ -d "$d/hooks" ]; then
      failc "AC5 structure" "$d contains agents/skills/hooks — spec Warning violation"
    else
      pass "AC5 structure: $d has no agents/skills/hooks subdirectory"
    fi
  else
    failc "AC5 structure" "$d does not exist"
  fi
done

# ── AC-R1a: claude plugin validate, GATING when the CLI is present ──────
# When `claude` is present a non-zero exit feeds failc. When it is absent
# (CI) this is skipc, and the AC1f POSIX subset oracle above is the standing
# CI witness.
echo "== AC-R1a: claude plugin validate (gating when CLI present) =="
if command -v claude >/dev/null 2>&1 && [ -d "$PLUGIN_DIR" ]; then
  VALIDATE_OUT=$(claude plugin validate "$PLUGIN_DIR" 2>&1)
  VALIDATE_RC=$?
  if [ "$VALIDATE_RC" -eq 0 ]; then
    pass "AC-R1a: claude plugin validate <repository root> -> exit 0 (frontmatter parses; full-parser gate)"
  else
    failc "AC-R1a" "claude plugin validate <repository root> -> exit $VALIDATE_RC: $VALIDATE_OUT"
  fi
else
  skipc "AC-R1a" "claude CLI not present in this environment -- the AC1f POSIX subset oracle is the standing CI witness"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
