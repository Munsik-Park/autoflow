#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: plugin packaging acceptance suite
# =============================================================================
# Checks that the plugin package under plugin/autoflow/ and the self-hosted
# marketplace at .claude-plugin/marketplace.json are produced, complete, and
# wired to resolve from the packaged location. Plain POSIX sh +
# jq/cmp/diff -r/grep/git only.
#
# packaging:
#   AC1e   declared components (agents/, hooks/hooks.json, skills/) resolve
#   AC1a/AC1b/AC1d  the plugin-only install skill: SKILL.md, every shipped
#          scripts/*.sh, and its resolver lib byte-identical to scripts/lib/
#   AC1f   every packaged SKILL.md frontmatter parses (POSIX defect-class
#          oracle, with its fixture specimens AC-R2d/e/g)
#   AC3    hooks/hooks.json commands are ${CLAUDE_PLUGIN_ROOT}/hooks/-anchored
#   AC3 8a the packaged gate hook, invoked once, returns a decision (allow)
#   AC4    the gate hook resolves state via ${CLAUDE_PROJECT_DIR}, never
#          ${CLAUDE_PLUGIN_ROOT}
#   AC5    byte-copy parity host <-> package (hooks, agents, epic-dash skill);
#          no component directory inside any .claude-plugin/
#   AC-R1/AC-R2  the packaged epic-dash skill locates its scripts
#          ${CLAUDE_PLUGIN_ROOT}-first, never by the bare host-only path
#   AC-R1a claude plugin validate (gating when the CLI is present)
# manifest:
#   AC1    plugin.json parses; `name` (the only spec-required field) is
#          'autoflow'; `version` is explicit and non-'latest' (R1 pin)
#   AC2    marketplace.json registers the plugin (name/source/version)
#   AC6e   the shipped PLUGIN_NAME / MARKETPLACE_NAME defaults (drift-check,
#          scripts/lib/plugin-root.sh) agree with marketplace.json
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

PLUGIN_DIR="$REPO_ROOT/plugin/autoflow"
PLUGIN_MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
GATE_SH="$PLUGIN_DIR/hooks/check-autoflow-gate.sh"
DEDUP_SH="$PLUGIN_DIR/hooks/check-read-dedup.sh"

ORIG_GATE="$REPO_ROOT/.claude/hooks/check-autoflow-gate.sh"
ORIG_DEDUP="$REPO_ROOT/.claude/hooks/check-read-dedup.sh"
ORIG_AGENTS="$REPO_ROOT/.claude/agents"
ORIG_SKILL="$REPO_ROOT/.claude/skills/epic-dash"

# Install skill (plugin-only, no .claude/skills/install host twin)
INSTALL_SKILL_DIR="$PLUGIN_DIR/skills/install"
INSTALL_SKILL_MD="$INSTALL_SKILL_DIR/SKILL.md"
INSTALL_SKILL_SCRIPTS="$INSTALL_SKILL_DIR/scripts"

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

compare_file() {
  # $1 = description, $2 = plugin-side path, $3 = .claude/ original path
  if [ -f "$2" ] && [ -f "$3" ]; then
    if cmp -s "$2" "$3"; then
      pass "AC5 parity: $1 byte-identical"
    else
      failc "AC5 parity" "$1 differs: cmp $2 $3"
    fi
  else
    failc "AC5 parity" "$1 -- missing file(s): $2 or $3"
  fi
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

# ── AC1a/AC1b: install skill presence + component resolution ────────────
# The install skill is plugin-only -- it has no `.claude/skills/install` host
# twin, so it is outside the AC5 byte-parity loop below (which stays
# hardcoded to `skills/epic-dash`). AC1a presence + AC1b component-resolution
# are therefore this skill's sole packaging guard: both SKILL.md and every
# shipped scripts/*.sh must resolve inside the PACKAGED plugin tree.
echo "== AC1a (#943): install skill SKILL.md presence + frontmatter =="
if [ -f "$INSTALL_SKILL_MD" ]; then
  pass "AC1a: plugin/autoflow/skills/install/SKILL.md exists"
  INSTALL_NAME=$(awk '/^---$/{n++; next} n==1 && /^name:/{print; exit}' "$INSTALL_SKILL_MD" | sed -E 's/^name:[[:space:]]*//')
  if [ "$INSTALL_NAME" = "install" ]; then
    pass "AC1a: install SKILL.md frontmatter name == 'install'"
  else
    failc "AC1a" "install SKILL.md frontmatter name='$INSTALL_NAME' (expected 'install')"
  fi
else
  failc "AC1a" "install skill SKILL.md missing at $INSTALL_SKILL_MD"
fi

echo "== AC1b (#943): every shipped scripts/*.sh resolves in the PACKAGED tree =="
if [ -d "$INSTALL_SKILL_SCRIPTS" ]; then
  SCRIPT_COUNT=0
  for _s in "$INSTALL_SKILL_SCRIPTS"/*.sh; do
    [ -e "$_s" ] || continue
    SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    pass "AC1b: $(basename "$_s") resolves under packaged $INSTALL_SKILL_SCRIPTS"
  done
  if [ "$SCRIPT_COUNT" -eq 0 ]; then
    failc "AC1b" "install skill scripts/ directory has no *.sh files at $INSTALL_SKILL_SCRIPTS (non-vacuity: sole packaging guard for a plugin-only skill)"
  fi
  if [ -f "$INSTALL_SKILL_SCRIPTS/detect.sh" ]; then
    pass "AC1b: detect.sh resolves in the packaged tree"
  else
    failc "AC1b" "detect.sh missing at $INSTALL_SKILL_SCRIPTS/detect.sh"
  fi
  if [ -f "$INSTALL_SKILL_SCRIPTS/scaffold-identity.sh" ]; then
    pass "AC1b: scaffold-identity.sh resolves in the packaged tree"
  else
    failc "AC1b" "scaffold-identity.sh missing at $INSTALL_SKILL_SCRIPTS/scaffold-identity.sh"
  fi
else
  failc "AC1b" "install skill scripts/ directory missing at $INSTALL_SKILL_SCRIPTS"
fi

echo "== AC1d (#174): resolve-cache-root.sh + lib/plugin-root.sh resolve in the packaged tree; the lib is byte-identical to scripts/lib/plugin-root.sh =="
# The install skill resolves the marketplace clone through the same resolver
# drift-check D4/D5 and spawn-policy check use (scripts/lib/plugin-root.sh),
# but a plugin cache carries no scripts/lib/ and an uninstalled target none
# either -- so the skill ships its own copy under scripts/lib/ of the skill.
# Two copies of one resolver are one resolver only while they are
# byte-identical; this pin is what makes an edit to either side visible.
if [ -f "$INSTALL_SKILL_SCRIPTS/resolve-cache-root.sh" ]; then
  pass "AC1d: resolve-cache-root.sh resolves in the packaged tree"
else
  failc "AC1d" "resolve-cache-root.sh missing at $INSTALL_SKILL_SCRIPTS/resolve-cache-root.sh"
fi
if [ -f "$INSTALL_SKILL_SCRIPTS/lib/plugin-root.sh" ] && cmp -s "$INSTALL_SKILL_SCRIPTS/lib/plugin-root.sh" "$REPO_ROOT/scripts/lib/plugin-root.sh"; then
  pass "AC1d: skills/install/scripts/lib/plugin-root.sh is byte-identical to scripts/lib/plugin-root.sh"
else
  failc "AC1d" "skills/install/scripts/lib/plugin-root.sh missing or differs from scripts/lib/plugin-root.sh -- re-copy: cp scripts/lib/plugin-root.sh plugin/autoflow/skills/install/scripts/lib/plugin-root.sh"
fi

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

# spec-embedded-colon: the literal pre-fix install/SKILL.md frontmatter (the
# Triggers: embedded colon-space plain-scalar defect). It persists as a
# regression witness independently of the live file.
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

  if [ "$P0_SOURCE" = "./plugin/autoflow" ]; then
    pass "AC2c: plugins[0].source == './plugin/autoflow' (starts with ./)"
  else
    failc "AC2c" "plugins[0].source='$P0_SOURCE' (expected './plugin/autoflow')"
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
  failc "AC3 8a" "plugin/autoflow/hooks/check-autoflow-gate.sh missing or not executable — cannot drive the real script"
fi

# ── AC4: state-path separation (static grep) ────────────────────────────
echo "== AC4: state-path separation (static, regression guard) =="
if [ -f "$GATE_SH" ]; then
  if grep -qE '\$\{CLAUDE_PLUGIN_ROOT\}[^"'"'"']*\.autoflow' "$GATE_SH"; then
    failc "AC4 static" "found a \${CLAUDE_PLUGIN_ROOT}-anchored .autoflow reference in $GATE_SH"
  else
    pass "AC4 REGRESSION GUARD: no \${CLAUDE_PLUGIN_ROOT}-anchored .autoflow reference"
  fi
  if grep -qF '${CLAUDE_PROJECT_DIR' "$GATE_SH"; then
    pass "AC4 REGRESSION GUARD: \${CLAUDE_PROJECT_DIR} present for state resolution"
  else
    failc "AC4 static" "no \${CLAUDE_PROJECT_DIR} reference found for state resolution"
  fi
else
  failc "AC4 static" "plugin gate script missing at $GATE_SH"
fi

# ── AC5: byte-copy parity (D-1 guard) ────────────────────────────────────
echo "== AC5: parity (byte-copies) =="
compare_file "hooks/check-autoflow-gate.sh" "$GATE_SH" "$ORIG_GATE"
compare_file "hooks/check-read-dedup.sh" "$DEDUP_SH" "$ORIG_DEDUP"

if [ -d "$ORIG_AGENTS" ]; then
  for f in "$ORIG_AGENTS"/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    compare_file "agents/$base" "$PLUGIN_DIR/agents/$base" "$f"
  done
else
  failc "AC5 parity" "reference directory missing: $ORIG_AGENTS"
fi

if [ -d "$PLUGIN_DIR/skills/epic-dash" ] && [ -d "$ORIG_SKILL" ]; then
  DIFF_TMP=$(mktemp)
  if diff -rq "$PLUGIN_DIR/skills/epic-dash" "$ORIG_SKILL" >"$DIFF_TMP" 2>&1; then
    pass "AC5 parity: skills/epic-dash byte-identical (diff -r)"
  else
    failc "AC5 parity" "skills/epic-dash differs: $(cat "$DIFF_TMP")"
  fi
  rm -f "$DIFF_TMP"
else
  failc "AC5 parity" "skills/epic-dash — missing directory at $PLUGIN_DIR/skills/epic-dash or $ORIG_SKILL"
fi

# ── AC-R1/AC-R2: packaged skill resolves scripts portably ───────────────
# A packaged SKILL.md that hardcodes a host-only script path resolves only on
# the host, which whole-directory byte-parity cannot detect. Do NOT assert
# absence of the whole substring '.claude/skills/epic-dash' -- the body
# legitimately retains it inside the quoted fallback candidate
# "$PWD/.claude/skills/epic-dash/scripts".
echo "== AC-R1/AC-R2: packaged skill resolves scripts portably (host-only-ref detector) =="
PKG_SKILL_MD="$PLUGIN_DIR/skills/epic-dash/SKILL.md"
if [ -f "$PKG_SKILL_MD" ]; then
  BARE_ASSIGN_FOUND=0
  if grep -qF 'S=.claude/skills/epic-dash/scripts' "$PKG_SKILL_MD"; then
    BARE_ASSIGN_FOUND=1
  fi
  if grep -qF 'S=".claude/skills/epic-dash/scripts"' "$PKG_SKILL_MD"; then
    BARE_ASSIGN_FOUND=1
  fi
  if grep -qF "S='.claude/skills/epic-dash/scripts'" "$PKG_SKILL_MD"; then
    BARE_ASSIGN_FOUND=1
  fi
  if [ "$BARE_ASSIGN_FOUND" -eq 0 ]; then
    pass "AC-R1(a)/AC-R2: bare host-only assignment 'S=.claude/skills/epic-dash/scripts' is absent"
  else
    failc "AC-R1(a)/AC-R2" "bare host-only assignment 'S=.claude/skills/epic-dash/scripts' still present in $PKG_SKILL_MD"
  fi

  # Line-structure-agnostic: the 'for S in' loop's candidate list may be
  # written on one line or continued across several with trailing '\'.
  # Extract the loop header block (from 'for S in' through the line that
  # opens the loop body with a trailing 'do') and compare the two
  # candidates' character offsets within it, rather than requiring them on a
  # single physical line.
  LOOP_BLOCK=$(awk '
    /for S in/{flag=1}
    flag{print}
    flag && /do[[:space:]]*$/{exit}
  ' "$PKG_SKILL_MD")
  if [ -z "$LOOP_BLOCK" ]; then
    failc "AC-R1(b)/AC-R2" "no 'for S in' loop found in $PKG_SKILL_MD"
  else
    PLUGIN_POS=$(awk -v s="$LOOP_BLOCK" -v t='${CLAUDE_PLUGIN_ROOT}/skills/epic-dash/scripts' 'BEGIN{print index(s,t)}')
    FALLBACK_POS=$(awk -v s="$LOOP_BLOCK" -v t='.claude/skills/epic-dash/scripts' 'BEGIN{print index(s,t)}')
    if [ "$PLUGIN_POS" -gt 0 ] && [ "$FALLBACK_POS" -gt 0 ] && [ "$PLUGIN_POS" -lt "$FALLBACK_POS" ]; then
      pass "AC-R1(b)/AC-R2: \${CLAUDE_PLUGIN_ROOT}/skills/epic-dash/scripts is the FIRST 'for S in' loop candidate"
    else
      failc "AC-R1(b)/AC-R2" "\${CLAUDE_PLUGIN_ROOT}/skills/epic-dash/scripts is not the first 'for S in' loop candidate in $PKG_SKILL_MD (plugin-root pos=$PLUGIN_POS, fallback pos=$FALLBACK_POS)"
    fi
  fi
else
  failc "AC-R1/AC-R2" "packaged SKILL.md missing at $PKG_SKILL_MD"
fi

# ── AC5: structure conformance (spec Warning) ────────────────────────────
echo "== AC5: structure conformance =="
for d in "$REPO_ROOT/.claude-plugin" "$PLUGIN_DIR/.claude-plugin"; do
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

# ── AC6e: shipped name defaults vs marketplace.json ─────────────────────
# drift-check's fallback branch (the one every conforming target lands on)
# and the shipped resolver's parameter defaults carry the plugin and
# marketplace names as literals. A rename that desyncs them from
# marketplace.json degrades every stamped target's D2/D4/D5 resolution to
# SKIP at exit 0.
echo "== AC6e (#245): shipped PLUGIN_NAME / MARKETPLACE_NAME defaults agree with marketplace.json =="
DRIFT_CHECK_SRC="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
PLUGIN_ROOT_LIB_SRC="$REPO_ROOT/scripts/lib/plugin-root.sh"
if [ -n "$MP_NAME" ] && [ -n "$P0_NAME" ] \
   && [ -f "$DRIFT_CHECK_SRC" ] && [ -f "$PLUGIN_ROOT_LIB_SRC" ]; then
  DC_FALLBACK=$(grep -E '^[[:space:]]*\*\)[[:space:]]+PLUGIN_NAME=' "$DRIFT_CHECK_SRC" | head -1)
  DC_PLG=$(printf '%s\n' "$DC_FALLBACK" | sed -n 's/.*PLUGIN_NAME="\([^"]*\)".*/\1/p')
  DC_MKT=$(printf '%s\n' "$DC_FALLBACK" | sed -n 's/.*MARKETPLACE_NAME="\([^"]*\)".*/\1/p')
  LIB_PLG=$(grep -E '_apr_plg="\$\{3:-[^}]*\}"' "$PLUGIN_ROOT_LIB_SRC" \
            | sed -n 's/.*_apr_plg="\${3:-\([^}]*\)}".*/\1/p' | head -1)
  LIB_MKT=$(grep -E '_amr_mkt="\$\{1:-[^}]*\}"' "$PLUGIN_ROOT_LIB_SRC" \
            | sed -n 's/.*_amr_mkt="\${1:-\([^}]*\)}".*/\1/p' | head -1)
  if [ -n "$DC_PLG" ] && [ "$DC_PLG" = "$P0_NAME" ] && [ -n "$DC_MKT" ] && [ "$DC_MKT" = "$MP_NAME" ]; then
    pass "AC6e: drift-check's name fallback ('$DC_PLG' / '$DC_MKT') agrees with marketplace.json (.plugins[0].name / .name)"
  else
    failc "AC6e" "drift-check's name fallback plugin='$DC_PLG' marketplace='$DC_MKT' != marketplace.json '$P0_NAME' / '$MP_NAME' -- every conforming target's D2/D4/D5 resolution degrades to SKIP at exit 0"
  fi
  if [ -n "$LIB_PLG" ] && [ "$LIB_PLG" = "$P0_NAME" ] && [ -n "$LIB_MKT" ] && [ "$LIB_MKT" = "$MP_NAME" ]; then
    pass "AC6e: scripts/lib/plugin-root.sh's resolver defaults ('$LIB_PLG' / '$LIB_MKT') agree with marketplace.json (.plugins[0].name / .name)"
  else
    failc "AC6e" "resolver defaults plugin='$LIB_PLG' marketplace='$LIB_MKT' != marketplace.json '$P0_NAME' / '$MP_NAME' -- the shipped defaults have desynced from the declared names"
  fi
else
  failc "AC6e" "cannot cross-check the shipped name defaults (MP_NAME='$MP_NAME' P0_NAME='$P0_NAME', drift-check.sh / scripts/lib/plugin-root.sh present?)"
fi

# ── AC-R1a: claude plugin validate, GATING when the CLI is present ──────
# When `claude` is present a non-zero exit feeds failc. When it is absent
# (CI) this is skipc, and the AC1f POSIX subset oracle above is the standing
# CI witness.
echo "== AC-R1a: claude plugin validate (gating when CLI present) =="
if command -v claude >/dev/null 2>&1 && [ -d "$PLUGIN_DIR" ]; then
  VALIDATE_OUT=$(claude plugin validate "$PLUGIN_DIR" 2>&1)
  VALIDATE_RC=$?
  if [ "$VALIDATE_RC" -eq 0 ]; then
    pass "AC-R1a: claude plugin validate ./plugin/autoflow -> exit 0 (frontmatter parses; full-parser gate)"
  else
    failc "AC-R1a" "claude plugin validate ./plugin/autoflow -> exit $VALIDATE_RC: $VALIDATE_OUT"
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
