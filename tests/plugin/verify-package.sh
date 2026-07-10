#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: plugin packaging acceptance suite — Issue #790 [#785-S4a]
# =============================================================================
# RED->GREEN harness for the plugin package delivered under plugin/autoflow/
# and the self-hosted marketplace at .claude-plugin/marketplace.json.
# Plain POSIX sh + jq/cmp/diff -r/grep/git only (DCR-5, verification design
# §4/§6.9) — no bats, no new runtime dependency (feature design §7).
#
# Acceptance criteria (.autoflow/issue-790-verification-design.md AC1-AC6,
# plus cycle-2 AC-R1/AC-R2/AC-R3):
#   AC1 plugin.json exists, parses, declares required fields, components resolve
#   AC2 marketplace.json registers the plugin (name/source/version cross-check)
#   AC3 hooks/hooks.json wires the two hooks under ${CLAUDE_PLUGIN_ROOT}; the
#       real byte-copied gate script still enforces (behavioral keystone 8a)
#   AC4 hook scripts resolve state via ${CLAUDE_PROJECT_DIR} only, never
#       ${CLAUDE_PLUGIN_ROOT} (static grep + behavioral two-distinct-roots 8b)
#   AC5 byte-copy parity + engine-core-unchanged (empty diff, AC-R3 narrowed
#       to drop .claude/skills; #796 narrowed to drop .claude/agents; #843
#       narrowed to drop .claude/hooks — parity carries agent/hook drift
#       protection) + no agents/skills/hooks inside any .claude-plugin/ +
#       packaged file-set coverage (workflows/CLAUDE.md/docs excluded)
#   AC6 settings-pin reference snippet lives only inside the README fence,
#       composes name@marketplace correctly, and no standalone pin file exists
#   AC-R1/AC-R2 (cycle 2, Codex Medium on PR #918) packaged skill body names
#       the ${CLAUDE_PLUGIN_ROOT}-first, .claude-fallback loop and no longer
#       carries the bare host-only assignment as its sole locator
#
# DCR-4 non-vacuity correction (grounded against the live spec, fetched
# 2026-07-06, https://code.claude.com/docs/en/plugins-reference > "Plugin
# manifest schema" > Required fields): "If you include a manifest, `name` is
# the ONLY required field." `version` and `description` are spec-OPTIONAL.
# AC1 below therefore asserts `name` as spec-required, `version` as
# R1-tool-delivery-contract-POLICY-required (explicit, non-"latest" — R1 is a
# project rule, not a Claude Code loader requirement), and `description` as a
# design-committed content check (feature design §4.1 ships one) — not as a
# spec mandate. This corrects the verification design's AC1 wording, which
# listed all three as "required plugin-spec fields."
#
# RED framing (verification design §4 / feature §6.9):
#   AC1/AC2/AC3-static/AC3-8a/AC4-8b/AC6 fail concretely pre-implementation
#   (no plugin.json/marketplace.json/hooks.json/README exists yet).
#   AC4-static-grep and AC5 empty-diff/structure-conformance MAY already be
#   green (the engine is layout-agnostic today) — these are REGRESSION GUARDS,
#   not red->green drivers; AC5 parity/coverage still fail pre-implementation
#   because the target files do not exist yet.
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

PLUGIN_DIR="$REPO_ROOT/plugin/autoflow"
PLUGIN_MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
GATE_SH="$PLUGIN_DIR/hooks/check-autoflow-gate.sh"
DEDUP_SH="$PLUGIN_DIR/hooks/check-read-dedup.sh"
README="$PLUGIN_DIR/README.md"

ORIG_GATE="$REPO_ROOT/.claude/hooks/check-autoflow-gate.sh"
ORIG_DEDUP="$REPO_ROOT/.claude/hooks/check-read-dedup.sh"
ORIG_AGENTS="$REPO_ROOT/.claude/agents"
ORIG_SKILL="$REPO_ROOT/.claude/skills/epic-dash"

# Issue #943 — install skill (plugin-only, no .claude/skills/install host twin)
INSTALL_SKILL_DIR="$PLUGIN_DIR/skills/install"
INSTALL_SKILL_MD="$INSTALL_SKILL_DIR/SKILL.md"
INSTALL_SKILL_SCRIPTS="$INSTALL_SKILL_DIR/scripts"
README_ROOT="$REPO_ROOT/README.md"
SETUP_GUIDE="$REPO_ROOT/setup/SETUP-GUIDE.md"
SETUP_MANIFEST="$REPO_ROOT/setup/manifest.json"

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
  DESC=$(jq -r '.description // empty' "$PLUGIN_MANIFEST")
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

  if [ -n "$DESC" ]; then
    pass "AC1d: description present (design-committed content, not spec-required)"
  else
    failc "AC1d" "description missing/empty"
  fi
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

# ── Issue #943 AC1a/AC1b: install skill presence + component resolution ──
# NOTE (OC-3, verification design §4/§5): the install skill is intentionally
# PLUGIN-ONLY -- it has no `.claude/skills/install` host twin, so it is
# outside the AC5 byte-parity loop below (which stays hardcoded to
# `skills/epic-dash`). AC1a presence + AC1b component-resolution are
# therefore this skill's SOLE packaging guard and must be non-vacuous:
# assert both SKILL.md and every shipped scripts/*.sh resolve inside the
# PACKAGED plugin tree ($PLUGIN_DIR/skills/install/...), not just source.
# Do NOT generalize the AC5 parity loop to this skill -- it has no host
# twin to diff against.
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

echo "== AC1b (#943, OC-3 sole coverage): every shipped scripts/*.sh resolves in the PACKAGED tree =="
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

echo "== AC1c (#943, OC-3): this file records why AC5 parity stays epic-dash-scoped =="
# The comment 3 lines above this section IS the AC1c artifact (a future
# loop-generalization attempt to diff skills/install against a non-existent
# .claude/skills/install host twin is the regression this guards against).
SELF_SCRIPT="$REPO_ROOT/tests/plugin/verify-package.sh"
if grep -qF 'the install skill is intentionally' "$SELF_SCRIPT" 2>/dev/null; then
  pass "AC1c: verify-package.sh records why AC5 parity is epic-dash-scoped (guards a future loop-generalization onto a non-existent install host twin)"
else
  failc "AC1c" "verify-package.sh no longer carries the epic-dash-scoped parity rationale comment"
fi

# ── AC1f (#943 c2, Codex High PR #959): gating POSIX frontmatter oracle ─────
# Verification design AC-R2a-g / feature design §4. This is a defect-class
# validator, not a full YAML implementation -- honest ceiling: it catches (1)
# an embedded ": " (colon-space) token inside a plain (unquoted, non-block)
# scalar value or its indented continuation lines, and (2) a missing required
# "name" or "description" top-level key. It does NOT model YAML anchors/
# aliases, flow collections ([]/{}), multi-document streams, tag directives,
# or the internal contents of quoted/block scalars (those are colon-safe BY
# FORM). A key with an empty value (e.g. a block-sequence- or mapping-valued
# key) is not treated as a plain scalar, so its indented continuation lines
# are not flagged -- this is a defect-class validator, not a full YAML parser;
# the AC-R1a `claude plugin validate` gating-when-present block below remains
# the full-fidelity oracle where the CLI is available.
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

echo "== AC1f (#943 c2, AC-R2a/b/c): gating POSIX frontmatter oracle over every plugin skill =="
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

echo "== AC1f (#943 c2, AC-R2d/e/g): regression-witness + fixture specimens (in-test heredocs, DR-1/DR-2) =="
FM_TMP=$(mktemp -d)

# spec-embedded-colon: the LITERAL pre-fix install/SKILL.md frontmatter (the
# Triggers: embedded colon-space plain-scalar defect). This persists as a
# regression witness independently of the live file, so AC-R2d stays provable
# after AC-R1 fixes install/SKILL.md (§4.6, R1-C1).
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

# spec-missing-name: description present, no name key (AC-R2e, name arm).
cat > "$FM_TMP/spec-missing-name.md" <<'SPEC_EOF'
---
description: A skill with no name key.
---
SPEC_EOF

# spec-missing-desc: name present, no description key (AC-R2e, description arm).
cat > "$FM_TMP/spec-missing-desc.md" <<'SPEC_EOF'
---
name: no-description-skill
---
SPEC_EOF

# spec-blockseq-valid: name+description plus an empty-value key carrying a
# block sequence whose items embed ": " -- must NOT false-positive (R1-C4
# lock-in, AC-R2g).
cat > "$FM_TMP/spec-blockseq-valid.md" <<'SPEC_EOF'
---
name: blockseq-skill
description: A skill whose frontmatter carries a block-sequence-valued key.
allowed-tools:
  - read: file contents
  - write: file contents
---
SPEC_EOF

# Assertion inversion (R1-C3): each specimen's EXPECTED exit is non-zero, so
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
  pass "AC-R2g: spec-blockseq-valid -> exit 0 (empty-value block-seq key not mistaken for a plain scalar; R1-C4 lock-in)"
else
  failc "AC-R2g" "spec-blockseq-valid: expected exit 0, got $FM_RC"
fi

rm -rf "$FM_TMP"

echo "== AC-R2f (#943 c2): honest-ceiling comment present in the test source =="
if grep -qF 'defect-class validator, not a full YAML implementation' "$SELF_SCRIPT" 2>/dev/null; then
  pass "AC-R2f: verify-package.sh states the POSIX oracle's honest ceiling (enumerated defect classes only, not full YAML)"
else
  failc "AC-R2f" "verify-package.sh no longer carries the honest-ceiling comment for the frontmatter oracle"
fi

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
    pass "AC2c: plugins[0].source == './plugin/autoflow' (starts with ./, OQ-4 locked)"
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
  PRE_MATCHER=$(jq -r '.hooks.PreToolUse[0].matcher // empty' "$HOOKS_JSON")
  POST_MATCHER=$(jq -r '.hooks.PostToolUse[0].matcher // empty' "$HOOKS_JSON")
  PRE_CMD=$(jq -r '.hooks.PreToolUse[0].hooks[0].command // empty' "$HOOKS_JSON")
  POST_CMD=$(jq -r '.hooks.PostToolUse[0].hooks[0].command // empty' "$HOOKS_JSON")

  if [ "$PRE_MATCHER" = "Write|Edit|MultiEdit|Bash|Agent" ]; then
    pass "AC3b: PreToolUse matcher matches .claude/settings.json topology"
  else
    failc "AC3b" "PreToolUse matcher='$PRE_MATCHER' (expected 'Write|Edit|MultiEdit|Bash|Agent')"
  fi
  if [ "$POST_MATCHER" = "Read" ]; then
    pass "AC3b: PostToolUse matcher matches .claude/settings.json topology"
  else
    failc "AC3b" "PostToolUse matcher='$POST_MATCHER' (expected 'Read')"
  fi

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

# ── AC3 behavioral keystone 8a: real script still enforces ──────────────
echo "== AC3 behavioral (8a): enforcement survives relocation (real script, never a stub) =="
if [ -f "$GATE_SH" ] && [ -x "$GATE_SH" ]; then
  MERGE_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"gh pr merge 123"}}'
  OUT=$(printf '%s' "$MERGE_PAYLOAD" | CLAUDE_PLUGIN_ROOT=/plugin CLAUDE_PROJECT_DIR="$REPO_ROOT" bash "$GATE_SH" 2>&1)
  CODE=$?
  if [ "$CODE" -eq 2 ]; then
    pass "AC3 8a: 'gh pr merge' via the plugin-rooted real script -> exit 2 (blocked)"
  else
    failc "AC3 8a" "expected exit 2, got $CODE; output: $OUT"
  fi

  BENIGN_DIR=$(mktemp -d)
  BENIGN_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  OUT2=$(printf '%s' "$BENIGN_PAYLOAD" | CLAUDE_PLUGIN_ROOT=/plugin CLAUDE_PROJECT_DIR="$BENIGN_DIR" bash "$GATE_SH" 2>&1)
  CODE2=$?
  if [ "$CODE2" -eq 0 ]; then
    pass "AC3 8a: benign command with no active state file -> exit 0 (pass)"
  else
    failc "AC3 8a" "expected exit 0, got $CODE2; output: $OUT2"
  fi
  rm -rf "$BENIGN_DIR"
else
  failc "AC3 8a" "plugin/autoflow/hooks/check-autoflow-gate.sh missing or not executable — cannot drive the real script (target absent pre-GREEN; a stub would be vacuous)"
fi

# ── AC4: state-path separation (static grep — regression guard) ─────────
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

# ── AC4 behavioral keystone 8b: two DISTINCT roots ───────────────────────
echo "== AC4 behavioral (8b): two-distinct-roots state separation (non-vacuous: roots must differ) =="
if [ -f "$GATE_SH" ] && [ -x "$GATE_SH" ]; then
  PROJECT_SCRATCH=$(mktemp -d)
  PLUGIN_SCRATCH=$(mktemp -d)
  mkdir -p "$PROJECT_SCRATCH/.autoflow" "$PLUGIN_SCRATCH/.autoflow"

  # Active state under the PROJECT root: evaluation not run -> git push must BLOCK.
  cat > "$PROJECT_SCRATCH/.autoflow/issue-1.json" <<'EOF'
{"active":true,"issue":"#1","phases":{"audit":{"scores":{}},"gate_quality":{"scores":{}}}}
EOF
  # Decoy under the PLUGIN root: fully-scored, would PASS if read instead.
  cat > "$PLUGIN_SCRATCH/.autoflow/issue-1.json" <<'EOF'
{"active":true,"issue":"#1","phases":{"audit":{"scores":{"a":10}},"gate_quality":{"scores":{"a":10}}}}
EOF

  PUSH_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"git push origin dev/scratch"}}'
  OUT3=$(printf '%s' "$PUSH_PAYLOAD" | CLAUDE_PLUGIN_ROOT="$PLUGIN_SCRATCH" CLAUDE_PROJECT_DIR="$PROJECT_SCRATCH" bash "$GATE_SH" 2>&1)
  CODE3=$?
  if [ "$CODE3" -eq 2 ]; then
    pass "AC4 8b: gate acted on \${CLAUDE_PROJECT_DIR}'s state (blocked) and ignored the \${CLAUDE_PLUGIN_ROOT} decoy that would have passed"
  else
    failc "AC4 8b" "expected exit 2 (state read from CLAUDE_PROJECT_DIR); got $CODE3 — a passing decoy from CLAUDE_PLUGIN_ROOT would indicate root conflation; output: $OUT3"
  fi
  rm -rf "$PROJECT_SCRATCH" "$PLUGIN_SCRATCH"
else
  failc "AC4 8b" "plugin gate script missing — cannot run the two-distinct-roots behavioral check"
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

# ── AC-R1/AC-R2: packaged skill resolves scripts portably (cycle 2) ─────
# Codex Medium (PR #918): the packaged plugin/autoflow/skills/epic-dash/SKILL.md
# hardcoded a host-only script path, which whole-directory byte-parity cannot
# detect. This is the red->green driver this cycle (DCR-C2-3) — it must FAIL
# on the pre-fix byte-copied body and PASS after the C2.3 portable-loop fix.
# Do NOT assert absence of the whole substring '.claude/skills/epic-dash' —
# the fixed body legitimately retains it inside the quoted fallback candidate
# "$PWD/.claude/skills/epic-dash/scripts" (verification design AC-R1(a)/§0).
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
  # written on one line or continued across several with trailing '\' (as
  # the C2.3 implementation does). Extract the loop header block (from
  # 'for S in' through the line that opens the loop body with a trailing
  # 'do') and compare the two candidates' character offsets within it,
  # rather than requiring them on a single physical line.
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

# ── AC5: engine-core-unchanged (empty diff — regression guard) ──────────
# AC-R3 narrowing: .claude/skills is dropped from scope because the host copy
# now legitimately changes (identical portable edit applied to both copies,
# verification design AC-R3/DCR-C2-2). Issue #796 narrowing (same shape):
# .claude/agents is dropped because agent role prose now legitimately changes
# (target-centric re-narration, #796 WI-4) — drift protection for agents is
# carried by the AC5 byte-copy parity check above, which is stricter (byte
# equality, CI-triggered on .claude/agents/**), so an engine agent edit cannot
# land silently: the plugin copy must change in the same diff. Issue #843
# narrowing (same shape): .claude/hooks is dropped from scope because the
# gate hook now legitimately changes (first intentional engine-hook edit
# since the #790 packaging) — drift protection for hooks is carried by the
# AC5 byte-copy parity check above, which is stricter (byte equality,
# plugin-package.yml CI-triggers on both .claude/hooks/** and plugin/**), so
# an engine hook edit cannot land silently: the plugin copy must change in
# the same diff. settings.json stays in scope — the gate-machinery drift
# guard is not gutted.
echo "== AC5: engine-core-unchanged (regression guard, AC-R3 + #796 + #843 narrowed) =="
BASE_REF=$(git -C "$REPO_ROOT" merge-base HEAD origin/main 2>/dev/null)
if [ -z "$BASE_REF" ]; then
  BASE_REF=$(git -C "$REPO_ROOT" rev-parse origin/main 2>/dev/null)
fi
if [ -n "$BASE_REF" ]; then
  DIFF_OUT=$(git -C "$REPO_ROOT" diff "$BASE_REF"...HEAD -- .claude/settings.json)
  if [ -z "$DIFF_OUT" ]; then
    pass "AC5 REGRESSION GUARD: engine-core diff vs $BASE_REF is empty (additive model, D-1, .claude/skills dropped per AC-R3, .claude/agents per #796, .claude/hooks per #843)"
  else
    failc "AC5 engine-core-unchanged" "non-empty diff vs $BASE_REF — engine files were modified"
  fi
else
  failc "AC5 engine-core-unchanged" "cannot resolve origin/main to compute the base diff"
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

# ── AC5: manifest coverage (workflows/CLAUDE.md/docs excluded) ──────────
echo "== AC5: manifest coverage =="
if [ -d "$PLUGIN_DIR" ]; then
  if [ -d "$PLUGIN_DIR/workflows" ]; then
    failc "AC5 coverage" "plugin/autoflow/workflows exists — workflows are thin-root-layer, not plugin (D1)"
  else
    pass "AC5 coverage: no workflows/ directory inside the plugin"
  fi
  if [ -f "$PLUGIN_DIR/CLAUDE.md" ] || [ -d "$PLUGIN_DIR/docs" ]; then
    failc "AC5 coverage" "plugin ships CLAUDE.md or docs/ — out of the plugin tier (D1)"
  else
    pass "AC5 coverage: no CLAUDE.md / docs/ inside the plugin"
  fi
else
  failc "AC5 coverage" "plugin/autoflow directory missing"
fi

# ── AC6: settings-pin reference snippet (README fence only) ─────────────
echo "== AC6: settings-pin reference snippet =="
if [ -f "$README" ]; then
  SNIPPET=$(awk '/```json/{flag=1; next} /```/{if(flag){flag=0}} flag' "$README")
  if [ -n "$SNIPPET" ] && printf '%s' "$SNIPPET" | jq -e . >/dev/null 2>&1; then
    pass "AC6a: README fenced \`\`\`json block extracts and parses as valid JSON"
    ENABLED_KEY=$(printf '%s' "$SNIPPET" | jq -r '.enabledPlugins | keys[0] // empty')
    EKM_KEY=$(printf '%s' "$SNIPPET" | jq -r '.extraKnownMarketplaces | keys[0] // empty')
    EXPECTED_ENABLED="${NAME:-autoflow}@${MP_NAME:-autoflow}"
    if [ "$ENABLED_KEY" = "$EXPECTED_ENABLED" ]; then
      pass "AC6b: enabledPlugins key == '$EXPECTED_ENABLED' (name@marketplace composition)"
    else
      failc "AC6b" "enabledPlugins key='$ENABLED_KEY' != expected '$EXPECTED_ENABLED'"
    fi
    if [ "$EKM_KEY" = "${MP_NAME:-autoflow}" ]; then
      pass "AC6c: extraKnownMarketplaces key == '${MP_NAME:-autoflow}'"
    else
      failc "AC6c" "extraKnownMarketplaces key='$EKM_KEY' != '${MP_NAME:-autoflow}'"
    fi
  else
    failc "AC6a" "no valid fenced \`\`\`json block found/parsed in $README"
  fi
else
  failc "AC6a" "README.md missing at $README"
fi

echo "== AC6: boundary — no standalone committed settings-pin artifact =="
PIN_HITS=""
for jf in $(git -C "$REPO_ROOT" ls-files -- '*.json' ':!services/*' ':!setup/thin-root-layer/settings-pin.json' 2>/dev/null); do
  if jq -e 'has("enabledPlugins")' "$REPO_ROOT/$jf" >/dev/null 2>&1; then
    PIN_HITS="$PIN_HITS $jf"
  fi
done
if [ -z "$PIN_HITS" ]; then
  pass "AC6d: no unsanctioned standalone pin — the only committed pin is the sanctioned installable fragment setup/thin-root-layer/settings-pin.json, parity-checked against the README fence (#791 §3.3)"
else
  failc "AC6d" "found unsanctioned standalone pin artifact(s):$PIN_HITS"
fi

# ── Issue #943 AC4a: static opt-in-boundary guard (no unconditional stamp) ──
# S-type per verification design AC4a: the `init.sh --target` stamp call must
# be textually DOWNSTREAM of an await-confirmation instruction; no stamp
# invocation may exist unconditionally ahead of / outside a confirmation step.
echo "== AC4a (#943): install SKILL.md await-confirmation-before-stamp guard =="
if [ -f "$INSTALL_SKILL_MD" ]; then
  CONFIRM_LINE=$(grep -niE 'confirm' "$INSTALL_SKILL_MD" | head -1 | cut -d: -f1)
  STAMP_LINE=$(grep -niE 'init\.sh[^"'"'"']*--target' "$INSTALL_SKILL_MD" | head -1 | cut -d: -f1)
  if [ -n "$CONFIRM_LINE" ] && [ -n "$STAMP_LINE" ] && [ "$STAMP_LINE" -gt "$CONFIRM_LINE" ]; then
    pass "AC4a: 'init.sh --target' stamp call (line $STAMP_LINE) is textually downstream of the confirmation step (line $CONFIRM_LINE)"
  else
    failc "AC4a" "no confirmation instruction found before the stamp call in $INSTALL_SKILL_MD (confirm-line=$CONFIRM_LINE stamp-line=$STAMP_LINE) -- an unconditional stamp is the AC4/opt-in-boundary violation"
  fi
else
  failc "AC4a" "install SKILL.md missing -- cannot assert the opt-in-boundary guard"
fi

# ── Issue #943 AC5a/b/c/d: README/SETUP-GUIDE 3-command onboarding flow ──
echo "== AC5a (#943): 3-command onboarding flow present, in order =="
for _doc_pair in "README:$README_ROOT" "SETUP-GUIDE:$SETUP_GUIDE"; do
  _doc_label=${_doc_pair%%:*}
  _doc_path=${_doc_pair#*:}
  if [ -f "$_doc_path" ]; then
    POS_MP=$(grep -niF 'marketplace add' "$_doc_path" | head -1 | cut -d: -f1)
    POS_PI=$(grep -niF 'plugin install' "$_doc_path" | head -1 | cut -d: -f1)
    POS_AI=$(grep -niF '/autoflow:install' "$_doc_path" | head -1 | cut -d: -f1)
    if [ -n "$POS_MP" ] && [ -n "$POS_PI" ] && [ -n "$POS_AI" ] \
       && [ "$POS_MP" -le "$POS_PI" ] && [ "$POS_PI" -le "$POS_AI" ]; then
      pass "AC5a: $_doc_label documents 'marketplace add' -> 'plugin install' -> '/autoflow:install' in order"
    else
      failc "AC5a" "$_doc_label does not document the 3-command flow in order (marketplace-add-pos=$POS_MP plugin-install-pos=$POS_PI autoflow-install-pos=$POS_AI) at $_doc_path"
    fi
  else
    failc "AC5a" "$_doc_label missing at $_doc_path"
  fi
done

echo "== AC5b (#943): the standalone clone-and-run step is no longer the documented PRIMARY onboarding path =="
for _doc_pair in "README:$README_ROOT" "SETUP-GUIDE:$SETUP_GUIDE"; do
  _doc_label=${_doc_pair%%:*}
  _doc_path=${_doc_pair#*:}
  if [ -f "$_doc_path" ]; then
    if grep -qiE 'clone the (tool|autoflow) repo' "$_doc_path"; then
      failc "AC5b" "$_doc_label still documents an onboarding 'clone the tool repo' instruction at $_doc_path"
    else
      pass "AC5b: $_doc_label carries no 'clone the tool repo' onboarding instruction"
    fi
  else
    failc "AC5b" "$_doc_label missing at $_doc_path"
  fi
done

echo "== AC5c (#943): #799 consumed-tool passage anchor survives, additive to the 3-command flow =="
if [ -f "$README_ROOT" ]; then
  if grep -qiE 'consumed.tool|versioned tool' "$README_ROOT"; then
    pass "AC5c: README consumed-tool (#799) passage anchor still present"
  else
    failc "AC5c" "README no longer carries the #799 consumed-tool passage anchor (extended, not contradicted, per AC5c)"
  fi
else
  failc "AC5c" "README.md missing at $README_ROOT"
fi
if [ -f "$SETUP_GUIDE" ]; then
  if grep -qiE 'consumed tool' "$SETUP_GUIDE"; then
    pass "AC5c: SETUP-GUIDE 'Install as a consumed tool' passage anchor still present"
  else
    failc "AC5c" "SETUP-GUIDE no longer carries the 'Install as a consumed tool' passage anchor"
  fi
else
  failc "AC5c" "setup/SETUP-GUIDE.md missing at $SETUP_GUIDE"
fi

echo "== AC5d (#943): negative manifest-non-regen guard (edited docs/skill are NOT manifest artifacts) =="
if [ -f "$SETUP_MANIFEST" ]; then
  MANIFEST_HIT=""
  MANIFEST_SOURCES=$(jq -r '.artifacts[].source' "$SETUP_MANIFEST" 2>/dev/null)
  for _edited in "README.md" "setup/SETUP-GUIDE.md"; do
    if printf '%s\n' "$MANIFEST_SOURCES" | grep -qFx "$_edited"; then
      MANIFEST_HIT="$MANIFEST_HIT $_edited"
    fi
  done
  if printf '%s\n' "$MANIFEST_SOURCES" | grep -qF 'plugin/autoflow/skills/install'; then
    MANIFEST_HIT="$MANIFEST_HIT plugin/autoflow/skills/install"
  fi
  if [ -z "$MANIFEST_HIT" ]; then
    pass "AC5d: none of README.md/setup/SETUP-GUIDE.md/plugin/autoflow/skills/install appears in setup/manifest.json .artifacts[].source (the #949 same-commit regen rule does not fire this cycle)"
  else
    failc "AC5d" "manifest .artifacts[].source unexpectedly registers a #943-edited path:$MANIFEST_HIT -- same-commit manifest regen is required (#949 rule)"
  fi

  if git -C "$REPO_ROOT" diff --exit-code -- setup/manifest.json >/dev/null 2>&1; then
    pass "AC5d: setup/manifest.json has no stray uncommitted diff (no unexpected regen)"
  else
    failc "AC5d" "setup/manifest.json has an uncommitted diff -- unexpected regen for a cycle whose edited files are not manifest sources"
  fi
else
  failc "AC5d" "setup/manifest.json missing at $SETUP_MANIFEST"
fi

# ── AC-R1a (#943 c2, DR-3): claude plugin validate, GATING when CLI present ──
# Promoted from informational-only (H3, the root guard-gap the Codex High
# finding exposed: a broken skill passed on any machine that HAS the claude
# CLI because this block never fed pass/failc). When `claude` is present a
# non-zero exit now feeds failc -- a real gate, red at HEAD on a CLI-equipped
# machine (the current install/SKILL.md frontmatter defect), green after
# AC-R1's fix. When `claude` is absent (CI) this stays skipc -- CI behaviour
# is unchanged; the AC1f POSIX subset oracle above is the standing CI witness.
echo "== AC-R1a (#943 c2): claude plugin validate (gating when CLI present, DR-3) =="
if command -v claude >/dev/null 2>&1 && [ -d "$PLUGIN_DIR" ]; then
  VALIDATE_OUT=$(claude plugin validate "$PLUGIN_DIR" 2>&1)
  VALIDATE_RC=$?
  if [ "$VALIDATE_RC" -eq 0 ]; then
    pass "AC-R1a: claude plugin validate ./plugin/autoflow -> exit 0 (frontmatter parses; full-parser gate, DR-3)"
  else
    failc "AC-R1a" "claude plugin validate ./plugin/autoflow -> exit $VALIDATE_RC: $VALIDATE_OUT"
  fi
else
  skipc "AC-R1a" "claude CLI not present in this environment -- the AC1f POSIX subset oracle is the standing CI witness (DR-3)"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
