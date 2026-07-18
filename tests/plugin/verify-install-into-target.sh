#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: install-into-TARGET acceptance suite — Issue #792 [#785-S5]
# =============================================================================
# RED->GREEN harness for: install-into-TARGET mode (WI-1), artifact manifest
# (WI-2), drift detector (WI-3), and SETUP-GUIDE docs (WI-4).
# Plain POSIX sh + jq/cmp/diff/grep/awk/git only (DCR-5) — no bats, no new
# runtime dependency (matches tests/plugin/verify-package.sh harness form).
#
# Acceptance criteria (canonical IDs from
#   .autoflow/issue-792-verification-design.md §1):
#
#   W1 install mode:
#     AC1-drive   non-interactive install gate (</dev/null, exit 0)
#     AC1a        shim stamped in target CLAUDE.md (BEGIN/END + import inside)
#     AC1b        idempotency (one block, byte-identical on 2nd run)
#     AC1c        marker replace/append (prose preserved, fenced region updated)
#     AC1d        workflow files byte-identical to source (cmp)
#     AC1e        settings.json deep-merge (pin keys land, pre-existing key kept)
#     AC2-ENV     (issue #963) re-stamp on a dedicated seeded target: unrelated
#                 key + env.FOO survive; env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
#                 seeded "0" -> "1" (pin-wins, D1 MANDATORY discriminating oracle)
#     AC1f        .claude/autoflow/METHODOLOGY.md exists post-install
#     AC1g        @-import graph statically resolvable, max 3 hops from METHODOLOGY.md
#     AC1j        CLAUDE.local.md scaffolded (absent->create), never overwritten
#     AC1k        markdown-link closure of installed CLAUDE.md + INDEX.md complete
#
#   W2 manifest:
#     AC2a        manifest.json parses, has version + non-empty artifacts[]
#     AC2b        installer reads manifest (static grep + install-set parity)
#     AC2c        manifest copied into target (.claude/autoflow/manifest.json)
#     AC2d        manifest component set matches docs/thin-root-layer.md §2 contract
#     AC2e        sha256 freshness: per-copy entry hash == current shasum of source
#
#   W3 drift detector:
#     AC3a        detector is manifest entry + exists in target post-install
#     AC3b        clean install -> detector exits 0
#     AC3c        drift classes caught (copy content, shim region, json-merge pin)
#     AC3d        D2 version skew -> non-zero; unresolvable plugin root -> SKIP
#     AC3e        independence: no network calls (grep) + source-repo-removed run
#
#   W4 docs:
#     AC4a        SETUP-GUIDE.md documents install model, manifest, drift command
#     AC4b        guide copy-list/checklist names thin-root artifacts
#
#   Regression:
#     AC-Ra       verify-package.sh whole-suite exits 0
#     AC-Rb       verify-thin-root-layer.sh whole-suite exits 0
#
#   NOT automated (E/M types — see tests/plugin/manual-scenarios-792.md):
#     AC1h        live @import resolution in a real Claude Code session
#     AC1i        live Workflow() invocation in target runtime
#     AC3f        live end-to-end drift-check in a real Claude Code session
#     AC4c        maintained-docs.md single-row registration (deferred to VALIDATE)
#     AC4d        operator hand-follows the guide on a scratch target (M)
#
# RED framing (verification design §4):
#   AC1-drive/AC1a-AC1k/AC2a-AC2e/AC3a-AC3e/AC4a/AC4b FAIL (no installer
#   --target mode, no manifest, no drift detector pre-GREEN).
#   AC-Ra/AC-Rb PASS (baseline regression suites unaffected by this branch).
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
SHIM_SRC="$REPO_ROOT/setup/thin-root-layer/claude-md-shim.md"
PIN_SRC="$REPO_ROOT/setup/thin-root-layer/settings-pin.json"
WORKFLOW_AD="$REPO_ROOT/.claude/workflows/architect-deliberation.js"
WORKFLOW_VCB="$REPO_ROOT/.claude/workflows/verify-cause-branch.js"
DRIFT_SH_SRC="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
EXAMPLE_LOCAL="$REPO_ROOT/CLAUDE.local.md.example"
VERIFY_PACKAGE="$REPO_ROOT/tests/plugin/verify-package.sh"
VERIFY_THIN_ROOT="$REPO_ROOT/tests/plugin/verify-thin-root-layer.sh"
PLUGIN_JSON="$REPO_ROOT/plugin/autoflow/.claude-plugin/plugin.json"
SETUP_GUIDE="$REPO_ROOT/setup/SETUP-GUIDE.md"
THIN_ROOT_DOC="$REPO_ROOT/docs/thin-root-layer.md"
IMPORT_LINE='@./.claude/autoflow/METHODOLOGY.md'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass()  { PASS_COUNT=$((PASS_COUNT + 1));  printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1));  printf 'FAIL: %s -- %s\n' "$1" "$2"; }
skipc() { SKIP_COUNT=$((SKIP_COUNT + 1));  printf 'SKIP: %s -- %s\n' "$1" "$2"; }

# ── Temp targets ──────────────────────────────────────────────────────────────
TARGET=$(mktemp -d)          # primary: AC1-drive → AC1g, AC1k, AC2c, AC3a, AC3b
COMPLEX_TARGET=$(mktemp -d)  # AC1c replace arm
SETTINGS_TARGET=$(mktemp -d) # AC1e settings merge
LOCAL_TARGET_A=$(mktemp -d)  # AC1j arm (a): absent -> scaffold
LOCAL_TARGET_B=$(mktemp -d)  # AC1j arm (b): existing -> never overwrite
DRIFT_TARGET=$(mktemp -d)    # AC3c mutation arms
SKEW_TARGET=$(mktemp -d)     # AC3d version skew arm
RESTAMP_TARGET=$(mktemp -d)  # issue #963 AC2: dedicated scratch, re-stamp pin-wins arm

cleanup() {
  rm -rf "$TARGET" "$COMPLEX_TARGET" "$SETTINGS_TARGET" \
         "$LOCAL_TARGET_A" "$LOCAL_TARGET_B" \
         "$DRIFT_TARGET" "$SKEW_TARGET" "$RESTAMP_TARGET"
}
trap cleanup EXIT INT TERM

# ── Helpers ───────────────────────────────────────────────────────────────────

# Run init.sh --target <dir> [extra flags] non-interactively; capture stdout+stderr.
run_install() {
  _tgt="$1"; shift
  bash "$INIT_SH" --target "$_tgt" "$@" </dev/null 2>&1
}

# BFS walk of @-import lines from METHODOLOGY.md (depth counted from METHODOLOGY.md).
# $1 = .claude/autoflow dir in installed target
# $2 = max hop depth from METHODOLOGY.md (3 because shim is already hop 1)
# Prints FAIL lines for any missing target or depth violation.
# Returns 0 if clean, 1 if any failure.
walk_at_imports() {
  _adir="$1"
  _maxhops="$2"
  _fail=0
  _cur=$(mktemp)
  _nxt=$(mktemp)
  _vis=$(mktemp)
  echo "METHODOLOGY.md" > "$_cur"
  echo "METHODOLOGY.md" > "$_vis"
  _depth=0
  while [ -s "$_cur" ]; do
    if [ "$_depth" -gt "$_maxhops" ]; then
      printf 'FAIL: AC1g -- @-import depth exceeds %d hops from METHODOLOGY.md\n' "$_maxhops"
      _fail=1
      break
    fi
    > "$_nxt"
    while IFS= read -r _f; do
      _abs="$_adir/$_f"
      if ! [ -f "$_abs" ]; then
        printf 'FAIL: AC1g -- @-import target missing: %s\n' "$_f"
        _fail=1
        continue
      fi
      while IFS= read -r _line; do
        case "$_line" in
          @*)
            _raw="${_line#@}"
            _tgt="${_raw#./}"
            if ! grep -qxF "$_tgt" "$_vis" 2>/dev/null; then
              echo "$_tgt" >> "$_vis"
              echo "$_tgt" >> "$_nxt"
            fi
            ;;
        esac
      done < "$_abs"
    done < "$_cur"
    cp "$_nxt" "$_cur"
    _depth=$((_depth + 1))
  done
  rm -f "$_cur" "$_nxt" "$_vis"
  return $_fail
}

# Resolve a markdown link target relative to its source file within autoflow dir.
# $1 = source file path relative to autoflow dir (e.g., "CLAUDE.md")
# $2 = link target (e.g., "docs/autoflow-guide.md" or "../README.md")
# Prints resolved path relative to autoflow dir.
resolve_md_link() {
  _src="$1"; _lnk="$2"
  _dir=$(dirname "$_src")
  if [ "$_dir" = "." ]; then
    _combined="$_lnk"
  else
    _combined="$_dir/$_lnk"
  fi
  # Normalize: collapse . and .. components
  printf '%s\n' "$_combined" | awk '{
    n = split($0, a, "/")
    j = 0
    for (i = 1; i <= n; i++) {
      if (a[i] == "..") { if (j > 0) j-- }
      else if (a[i] != "." && a[i] != "") { r[++j] = a[i] }
    }
    for (i = 1; i <= j; i++) printf "%s%s", (i>1?"/":""), r[i]
    printf "\n"
  }'
}

# BFS walk of markdown link closure from a starting set of files.
# $1 = .claude/autoflow dir
# $2 = space-separated list of starting files (relative to autoflow dir)
# Prints FAIL lines for missing link targets.
# Links whose resolved target does not exist in the SOURCE repo tree are
# skipped as pre-existing source doc defects (AC1k asserts the installed tree
# is self-contained relative to what the source ships — it cannot require
# targets already broken at source, e.g. docs/improvement-backlog.md quoting
# CLAUDE.md root-relative link text). Skips are counted and reported.
# Returns 0 if all source-valid targets exist, 1 otherwise.
walk_md_links() {
  _adir="$1"
  _starters="$2"
  _fail=0
  _skipcnt=0
  _cur=$(mktemp)
  _vis=$(mktemp)
  for _s in $_starters; do
    echo "$_s" >> "$_cur"
    echo "$_s" >> "$_vis"
  done
  while [ -s "$_cur" ]; do
    _nxt=$(mktemp)
    while IFS= read -r _f; do
      _abs="$_adir/$_f"
      if ! [ -f "$_abs" ]; then
        printf 'FAIL: AC1k -- installed file missing: %s\n' "$_f"
        _fail=1
        continue
      fi
      # Extract ](path.md) style links; skip external URLs and anchors
      while IFS= read -r _lnk; do
        # Guard: heredoc feeds one empty line when grep matches nothing —
        # an empty link must not be resolved (it would yield the linking
        # file's own directory and false-fail every zero-link leaf doc).
        [ -n "$_lnk" ] || continue
        # Resolve relative to current file's location
        _resolved=$(resolve_md_link "$_f" "$_lnk")
        [ -n "$_resolved" ] || continue
        # Skip links whose target does not exist in the SOURCE repo either:
        # a pre-existing source doc defect, not an install-completeness gap.
        # (The installed autoflow-dir layout mirrors repo-root-relative
        # layout, so the source counterpart is $REPO_ROOT/$_resolved.)
        if ! [ -f "$REPO_ROOT/$_resolved" ]; then
          _skipcnt=$((_skipcnt + 1))
          continue
        fi
        if ! grep -qxF "$_resolved" "$_vis" 2>/dev/null; then
          echo "$_resolved" >> "$_vis"
          echo "$_resolved" >> "$_nxt"
        fi
      done <<LINKS
$(grep -oE '\]\([^)#:]+\.md\)' "$_abs" 2>/dev/null | sed 's/^\](//' | sed 's/)$//')
LINKS
    done < "$_cur"
    rm -f "$_cur"
    _cur="$_nxt"
  done
  rm -f "$_cur" "$_vis"
  if [ "$_skipcnt" -gt 0 ]; then
    printf 'NOTE: AC1k -- %d link(s) skipped as pre-existing source-broken targets\n' "$_skipcnt"
  fi
  return $_fail
}

# ══════════════════════════════════════════════════════════════════════════════
# W1 — install-into-TARGET mode
# ══════════════════════════════════════════════════════════════════════════════

# ── AC1-drive: non-interactive install gate ───────────────────────────────────
echo "== AC1-drive: non-interactive install into temp target =="
DRIVE_PASS=0
if [ -f "$INIT_SH" ]; then
  DRIVE_OUT=$(run_install "$TARGET" 2>&1)
  DRIVE_CODE=$?
  if [ "$DRIVE_CODE" -eq 0 ]; then
    pass "AC1-drive: init.sh --target exits 0 non-interactively (</dev/null)"
    DRIVE_PASS=1
  else
    failc "AC1-drive" \
      "init.sh --target exited $DRIVE_CODE — no --target mode pre-GREEN; first output line: $(printf '%s\n' "$DRIVE_OUT" | head -1)"
  fi
else
  failc "AC1-drive" "init.sh missing at $INIT_SH"
fi

# ── AC1a: shim block stamped in target CLAUDE.md ─────────────────────────────
echo "== AC1a: shim block stamped in target CLAUDE.md =="
TARGET_CLAUDE="$TARGET/CLAUDE.md"
if [ -f "$TARGET_CLAUDE" ]; then
  BEGIN_L=$(grep -n 'AUTOFLOW-IMPORT:BEGIN' "$TARGET_CLAUDE" 2>/dev/null | head -1 | cut -d: -f1)
  END_L=$(grep -n 'AUTOFLOW-IMPORT:END'   "$TARGET_CLAUDE" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$BEGIN_L" ] && [ -n "$END_L" ] && [ "$BEGIN_L" -lt "$END_L" ]; then
    pass "AC1a: AUTOFLOW-IMPORT:BEGIN/END markers present and BEGIN < END"
    BETWEEN=$(awk -v b="$BEGIN_L" -v e="$END_L" 'NR>b && NR<e' "$TARGET_CLAUDE")
    if printf '%s\n' "$BETWEEN" | grep -qF "$IMPORT_LINE"; then
      pass "AC1a: import line '$IMPORT_LINE' strictly between markers"
    else
      failc "AC1a" "import line not found strictly between markers (between='$BETWEEN')"
    fi
  else
    failc "AC1a" "markers missing or BEGIN >= END (begin=$BEGIN_L end=$END_L)"
  fi
else
  failc "AC1a" "target CLAUDE.md not created ($TARGET_CLAUDE absent post-install)"
fi

# ── AC1b: idempotency ─────────────────────────────────────────────────────────
echo "== AC1b: idempotency (second run: one block, byte-identical CLAUDE.md) =="
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$TARGET_CLAUDE" ]; then
  cp "$TARGET_CLAUDE" "$TARGET_CLAUDE.snap"
  run_install "$TARGET" >/dev/null 2>&1
  _cnt=$(grep -c 'AUTOFLOW-IMPORT:BEGIN' "$TARGET_CLAUDE" 2>/dev/null || printf '0')
  if [ "$_cnt" -eq 1 ]; then
    pass "AC1b: exactly one AUTOFLOW-IMPORT:BEGIN after second run"
  else
    failc "AC1b" "BEGIN count=$_cnt after second run (expected 1 — not idempotent)"
  fi
  if cmp -s "$TARGET_CLAUDE.snap" "$TARGET_CLAUDE"; then
    pass "AC1b: CLAUDE.md byte-identical after second run"
  else
    failc "AC1b" "CLAUDE.md differs after second run (installer not idempotent)"
  fi
  rm -f "$TARGET_CLAUDE.snap"
else
  failc "AC1b" "prerequisite AC1-drive failed or CLAUDE.md absent — cannot test idempotency"
fi

# ── AC1c: marker replace/append ───────────────────────────────────────────────
echo "== AC1c: marker replace (operator prose preserved, stale block replaced) =="
# Arm 1: pre-seeded target with operator prose + stale managed block
STALE_SHIM="<!-- AUTOFLOW-IMPORT:BEGIN (managed by claude-autoflow — do not edit inside) -->
@./OLD_STALE_IMPORT.md
<!-- AUTOFLOW-IMPORT:END -->"
printf '# My Project\n\nOperator custom content here.\n\n%s\n' "$STALE_SHIM" \
  > "$COMPLEX_TARGET/CLAUDE.md"
if [ -f "$INIT_SH" ]; then
  run_install "$COMPLEX_TARGET" >/dev/null 2>&1
  _code=$?
  if [ "$_code" -eq 0 ]; then
    if grep -qF 'Operator custom content here.' "$COMPLEX_TARGET/CLAUDE.md"; then
      pass "AC1c replace: operator prose preserved after managed-block replace"
    else
      failc "AC1c replace" "operator prose lost after replace install"
    fi
    if grep -qF 'OLD_STALE_IMPORT' "$COMPLEX_TARGET/CLAUDE.md"; then
      failc "AC1c replace" "stale import still present after replace"
    else
      pass "AC1c replace: stale import line removed (replaced by canonical shim)"
    fi
    if grep -qF "$IMPORT_LINE" "$COMPLEX_TARGET/CLAUDE.md"; then
      pass "AC1c replace: canonical import line present after replace"
    else
      failc "AC1c replace" "canonical import '$IMPORT_LINE' missing after replace"
    fi
  else
    failc "AC1c replace" "install into seeded target exited $_code"
  fi
else
  failc "AC1c replace" "init.sh missing"
fi

echo "== AC1c: append (block appended to prose-only CLAUDE.md, prose preserved) =="
# Arm 2: prose-only CLAUDE.md (no existing block) -> block appended
APPEND_T=$(mktemp -d)
printf '# My Project\n\nSome operator prose.\n' > "$APPEND_T/CLAUDE.md"
if [ -f "$INIT_SH" ]; then
  run_install "$APPEND_T" >/dev/null 2>&1
  _code=$?
  if [ "$_code" -eq 0 ]; then
    if grep -qF 'AUTOFLOW-IMPORT:BEGIN' "$APPEND_T/CLAUDE.md" \
       && grep -qF 'Some operator prose.' "$APPEND_T/CLAUDE.md"; then
      pass "AC1c append: shim block appended, original prose preserved"
    else
      failc "AC1c append" "block not appended or prose lost (CLAUDE.md=$(cat "$APPEND_T/CLAUDE.md" 2>/dev/null | head -5))"
    fi
  else
    failc "AC1c append" "install into append target exited $_code"
  fi
  rm -rf "$APPEND_T"
else
  rm -rf "$APPEND_T"
  failc "AC1c append" "init.sh missing"
fi

# ── AC1d: workflow files byte-identical ───────────────────────────────────────
echo "== AC1d: workflow files byte-identical to source =="
for _wf in "architect-deliberation.js" "verify-cause-branch.js"; do
  _installed="$TARGET/.claude/workflows/$_wf"
  _source="$REPO_ROOT/.claude/workflows/$_wf"
  if [ -f "$_installed" ] && [ -f "$_source" ]; then
    if cmp -s "$_installed" "$_source"; then
      pass "AC1d: $_wf byte-identical (cmp -s)"
    else
      failc "AC1d" "$_wf differs from source (not a verbatim copy)"
    fi
  else
    failc "AC1d" "$_wf missing in target or source (target=$_installed source=$_source)"
  fi
done

# ── AC1e: settings.json deep-merge ────────────────────────────────────────────
echo "== AC1e: settings.json merge (pin keys land, pre-existing key preserved) =="
mkdir -p "$SETTINGS_TARGET/.claude"
printf '{"sentinel_key": "sentinel_value", "other": 42}\n' \
  > "$SETTINGS_TARGET/.claude/settings.json"
if [ -f "$INIT_SH" ]; then
  run_install "$SETTINGS_TARGET" >/dev/null 2>&1
  _code=$?
  _s="$SETTINGS_TARGET/.claude/settings.json"
  if [ "$_code" -eq 0 ] && [ -f "$_s" ] && jq -e . "$_s" >/dev/null 2>&1; then
    _ekm=$(jq -r '.extraKnownMarketplaces["autoflow"] // empty' "$_s" 2>/dev/null)
    _ep=$(jq -r '.enabledPlugins["autoflow@autoflow"] // empty' "$_s" 2>/dev/null)
    _sent=$(jq -r '.sentinel_key // empty' "$_s" 2>/dev/null)
    if [ -n "$_ekm" ] && [ "$_ekm" != "null" ]; then
      pass "AC1e: extraKnownMarketplaces[autoflow] present after merge"
    else
      failc "AC1e" "extraKnownMarketplaces[autoflow] missing after merge"
    fi
    if [ "$_ep" = "true" ]; then
      pass "AC1e: enabledPlugins[autoflow@autoflow] == true"
    else
      failc "AC1e" "enabledPlugins[autoflow@autoflow] != true (got '$_ep')"
    fi
    if [ "$_sent" = "sentinel_value" ]; then
      pass "AC1e: pre-existing sentinel_key preserved after merge"
    else
      failc "AC1e" "pre-existing sentinel_key lost or changed (got '$_sent')"
    fi
  else
    failc "AC1e" "install into settings target exited $_code or settings.json invalid JSON"
  fi
else
  failc "AC1e" "init.sh missing"
fi

# ── AC2-ENV (issue #963): re-stamp preserves unrelated keys; env pin-wins ─────
# Verification design §1 AC2 / feature design §5 AC2 (C1, MANDATORY
# discriminating oracle): a dedicated scratch target (NOT the shared $TARGET
# or $SETTINGS_TARGET used above) is seeded with an unrelated key, an
# unrelated env.FOO, and env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "0"
# BEFORE the stamp. After re-stamping: (a) the unrelated key survives, (b)
# env.FOO survives (env deep-merges key-by-key, not a whole-env replace),
# and (c) env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS becomes "1" (pin overwrote
# the seeded "0" -- the ONLY assertion that discriminates pin-wins from
# insert-only; sibling/env.FOO preservation holds under both).
echo "== AC2-ENV (issue #963): re-stamp on a seeded target -- unrelated keys survive, env.FOO survives, env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS \"0\"->\"1\" (pin-wins) =="
mkdir -p "$RESTAMP_TARGET/.claude"
printf '{"theme": "dark", "env": {"FOO": "bar", "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"}}\n' \
  > "$RESTAMP_TARGET/.claude/settings.json"
if [ -f "$INIT_SH" ]; then
  run_install "$RESTAMP_TARGET" >/dev/null 2>&1
  _code=$?
  _rs="$RESTAMP_TARGET/.claude/settings.json"
  if [ "$_code" -eq 0 ] && [ -f "$_rs" ] && jq -e . "$_rs" >/dev/null 2>&1; then
    _theme=$(jq -r '.theme // empty' "$_rs" 2>/dev/null)
    _foo=$(jq -r '.env.FOO // empty' "$_rs" 2>/dev/null)
    _agt=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' "$_rs" 2>/dev/null)
    if [ "$_theme" = "dark" ]; then
      pass "AC2-ENV: unrelated pre-existing key theme=\"dark\" preserved after re-stamp"
    else
      failc "AC2-ENV" "unrelated pre-existing key theme lost or changed after re-stamp (got '$_theme')"
    fi
    if [ "$_foo" = "bar" ]; then
      pass "AC2-ENV: unrelated pre-existing env.FOO=\"bar\" preserved after re-stamp (env deep-merges key-by-key, not whole-env replace)"
    else
      failc "AC2-ENV" "unrelated pre-existing env.FOO lost or changed after re-stamp (got '$_foo')"
    fi
    if [ "$_agt" = "1" ]; then
      pass "AC2-ENV MANDATORY discriminating oracle: env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS seeded \"0\" -> \"1\" after re-stamp (pin-wins, D1)"
    else
      failc "AC2-ENV MANDATORY discriminating oracle" "env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS expected \"1\" (pin-wins overwrite of seeded \"0\") after re-stamp; got '$_agt' -- settings-pin.json does not ship the Agent Teams enablement env (issue #963)"
    fi
  else
    failc "AC2-ENV" "install into restamp target exited $_code or settings.json invalid JSON"
  fi
else
  failc "AC2-ENV" "init.sh missing"
fi

# ── AC1f: METHODOLOGY.md exists post-install ──────────────────────────────────
echo "== AC1f: .claude/autoflow/METHODOLOGY.md exists post-install =="
if [ -f "$TARGET/.claude/autoflow/METHODOLOGY.md" ]; then
  pass "AC1f: .claude/autoflow/METHODOLOGY.md exists in installed target"
else
  failc "AC1f" ".claude/autoflow/METHODOLOGY.md absent (installer did not create it)"
fi

# ── AC1g: @-import graph statically resolvable, max depth ≤ 4 from shim ──────
echo "== AC1g: @-import graph resolvable (max 3 hops from METHODOLOGY.md = 4 from shim) =="
ADIR="$TARGET/.claude/autoflow"
if [ -f "$ADIR/METHODOLOGY.md" ]; then
  GRAPH_OUT=$(walk_at_imports "$ADIR" 3 2>&1)
  GRAPH_CODE=$?
  printf '%s\n' "$GRAPH_OUT" | grep '^FAIL:' || true
  if [ "$GRAPH_CODE" -eq 0 ]; then
    pass "AC1g: all @-import targets exist and depth ≤ 4 from shim"
  else
    failc "AC1g" "import graph has missing targets or exceeds depth (see FAIL lines above)"
  fi
else
  failc "AC1g" "METHODOLOGY.md absent ($ADIR/METHODOLOGY.md) — cannot walk graph"
fi

# ── AC1j: CLAUDE.local.md scaffolded when absent, never overwritten ───────────
echo "== AC1j arm (a): absent CLAUDE.local.md -> scaffolded from example =="
if [ -f "$EXAMPLE_LOCAL" ] && [ -f "$INIT_SH" ]; then
  run_install "$LOCAL_TARGET_A" >/dev/null 2>&1
  _code=$?
  if [ "$_code" -eq 0 ] && [ -f "$LOCAL_TARGET_A/CLAUDE.local.md" ]; then
    if cmp -s "$LOCAL_TARGET_A/CLAUDE.local.md" "$EXAMPLE_LOCAL"; then
      pass "AC1j (a): CLAUDE.local.md scaffolded from example (byte-identical)"
    else
      failc "AC1j (a)" "CLAUDE.local.md created but differs from example"
    fi
  elif [ "$_code" -ne 0 ]; then
    failc "AC1j (a)" "install exited $_code on empty target"
  else
    failc "AC1j (a)" "CLAUDE.local.md not created in target (scaffold step missing)"
  fi
else
  failc "AC1j (a)" "CLAUDE.local.md.example missing or init.sh missing"
fi

echo "== AC1j arm (b): existing CLAUDE.local.md never overwritten (with and without --force) =="
SENTINEL_LOCAL="# SENTINEL — do not overwrite\nOperator wrote this.\n"
if [ -f "$INIT_SH" ]; then
  printf '%b' "$SENTINEL_LOCAL" > "$LOCAL_TARGET_B/CLAUDE.local.md"
  # Without --force
  run_install "$LOCAL_TARGET_B" >/dev/null 2>&1
  _code1=$?
  if [ "$_code1" -eq 0 ]; then
    if grep -qF 'SENTINEL — do not overwrite' "$LOCAL_TARGET_B/CLAUDE.local.md"; then
      pass "AC1j (b): sentinel preserved without --force"
    else
      failc "AC1j (b)" "CLAUDE.local.md overwritten without --force (R3 violated)"
    fi
  else
    failc "AC1j (b)" "install (no --force) exited $_code1"
  fi
  # With --force
  printf '%b' "$SENTINEL_LOCAL" > "$LOCAL_TARGET_B/CLAUDE.local.md"
  run_install "$LOCAL_TARGET_B" --force >/dev/null 2>&1
  _code2=$?
  if [ "$_code2" -eq 0 ]; then
    if grep -qF 'SENTINEL — do not overwrite' "$LOCAL_TARGET_B/CLAUDE.local.md"; then
      pass "AC1j (b): sentinel preserved even with --force (R3: never overwrite)"
    else
      failc "AC1j (b)" "CLAUDE.local.md overwritten with --force (R3 violated — --force must not touch this file)"
    fi
  else
    failc "AC1j (b)" "install (with --force) exited $_code2"
  fi
else
  failc "AC1j (b)" "init.sh missing"
fi

# ── AC1k: markdown-link closure of installed CLAUDE.md + INDEX.md complete ────
echo "== AC1k: transitive markdown-link closure complete in installed target =="
_aCLAUDE="$TARGET/.claude/autoflow/CLAUDE.md"
_aINDEX="$TARGET/.claude/autoflow/docs/INDEX.md"
if [ -f "$_aCLAUDE" ] || [ -f "$_aINDEX" ]; then
  _starters=""
  [ -f "$_aCLAUDE" ] && _starters="CLAUDE.md"
  [ -f "$_aINDEX" ]  && _starters="$_starters docs/INDEX.md"
  _starters=$(printf '%s\n' "$_starters" | sed 's/^ *//')  # trim leading space
  LINK_OUT=$(walk_md_links "$TARGET/.claude/autoflow" "$_starters" 2>&1)
  LINK_CODE=$?
  printf '%s\n' "$LINK_OUT" | grep -E '^(FAIL|NOTE):' || true
  if [ "$LINK_CODE" -eq 0 ]; then
    pass "AC1k: all markdown-link closure targets exist in installed tree"
  else
    failc "AC1k" "one or more link-closure targets missing in installed tree (see FAIL lines above)"
  fi
else
  failc "AC1k" "neither CLAUDE.md nor docs/INDEX.md installed — cannot walk link closure"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W2 — artifact manifest
# ══════════════════════════════════════════════════════════════════════════════

# ── AC2a: manifest.json structure ─────────────────────────────────────────────
echo "== AC2a: manifest.json parses, has version + non-empty artifacts[] =="
if [ -f "$MANIFEST" ] && jq -e . "$MANIFEST" >/dev/null 2>&1; then
  pass "AC2a: setup/manifest.json exists and is valid JSON"
  _ver=$(jq -r '.version // empty' "$MANIFEST")
  _cnt=$(jq -r '.artifacts | length' "$MANIFEST" 2>/dev/null || echo 0)
  if [ -n "$_ver" ] && [ "$_ver" != "null" ]; then
    pass "AC2a: .version present ('$_ver')"
  else
    failc "AC2a" ".version missing or null"
  fi
  if [ "$_cnt" -gt 0 ]; then
    pass "AC2a: artifacts[] non-empty ($_cnt entries)"
  else
    failc "AC2a" "artifacts[] empty or missing"
  fi
  # Assert each artifact has required fields: source, dest, tier, kind
  _bad=$(jq -r '.artifacts[] | select((.source==null) or (.dest==null) or (.tier==null) or (.kind==null)) | .dest // "<unnamed>"' "$MANIFEST" 2>/dev/null)
  if [ -z "$_bad" ]; then
    pass "AC2a: all artifact entries have source/dest/tier/kind fields"
  else
    failc "AC2a" "artifact entries missing required fields: $_bad"
  fi
  # Assert kind values are within the allowed set
  _bad_kind=$(jq -r '.artifacts[] | select(.kind | IN("copy","shim-stamp","json-merge","scaffold") | not) | .dest // "<unnamed>"' "$MANIFEST" 2>/dev/null)
  if [ -z "$_bad_kind" ]; then
    pass "AC2a: all artifact .kind values in {copy, shim-stamp, json-merge, scaffold}"
  else
    failc "AC2a" "invalid .kind values on entries: $_bad_kind"
  fi
else
  failc "AC2a" "setup/manifest.json missing or invalid JSON at $MANIFEST"
fi

# ── AC2b: installer reads manifest (not hardcoded) ────────────────────────────
echo "== AC2b: installer reads manifest (static grep + install-set parity) =="
if [ -f "$INIT_SH" ]; then
  if grep -qF 'manifest' "$INIT_SH" || grep -qF 'manifest.json' "$INIT_SH"; then
    pass "AC2b static: init.sh references 'manifest' (reads manifest path)"
  else
    failc "AC2b static" "no 'manifest' reference found in init.sh — installer may be hardcoded"
  fi
else
  failc "AC2b static" "init.sh missing at $INIT_SH"
fi
# Behavioral: every file created in TARGET is listed in manifest dest set
if [ "$DRIVE_PASS" -eq 1 ] && [ -f "$MANIFEST" ]; then
  _extra=""
  while IFS= read -r _installed_rel; do
    _in_manifest=$(jq -r --arg d "$_installed_rel" '.artifacts[] | select(.dest == $d) | .dest' "$MANIFEST" 2>/dev/null | head -1)
    if [ -z "$_in_manifest" ]; then
      _extra="$_extra $_installed_rel"
    fi
  done <<FILES
$(find "$TARGET" -type f | sed "s|^$TARGET/||" | sort)
FILES
  if [ -z "$_extra" ]; then
    pass "AC2b behavioral: install set is a subset of manifest dest entries (manifest-driven)"
  else
    failc "AC2b behavioral" "files in target not in manifest: $_extra"
  fi
elif [ "$DRIVE_PASS" -eq 0 ]; then
  failc "AC2b behavioral" "skipped — AC1-drive failed (no install ran)"
else
  failc "AC2b behavioral" "manifest.json absent — cannot compare install set"
fi

# ── AC2c: manifest copied to target ───────────────────────────────────────────
echo "== AC2c: manifest copied into target at .claude/autoflow/manifest.json =="
if [ -f "$TARGET/.claude/autoflow/manifest.json" ]; then
  pass "AC2c: .claude/autoflow/manifest.json present in target post-install"
else
  failc "AC2c" ".claude/autoflow/manifest.json absent in target (manifest not self-copied)"
fi

# ── AC2d: manifest component set matches thin-root-layer.md §2 contract ───────
echo "== AC2d: manifest ↔ thin-root contract parity (shim/workflows/settings/methodology) =="
if [ -f "$MANIFEST" ] && [ -f "$THIN_ROOT_DOC" ]; then
  # Check required kinds are represented in manifest
  _has_shim=$(jq -r '.artifacts[] | select(.kind == "shim-stamp") | .kind' "$MANIFEST" 2>/dev/null | head -1)
  _has_copy=$(jq -r '.artifacts[] | select(.kind == "copy" and (.dest | test("\\.claude/workflows/"))) | .dest' "$MANIFEST" 2>/dev/null | head -1)
  _has_merge=$(jq -r '.artifacts[] | select(.kind == "json-merge") | .kind' "$MANIFEST" 2>/dev/null | head -1)
  _has_method=$(jq -r '.artifacts[] | select(.dest == ".claude/autoflow/METHODOLOGY.md") | .dest' "$MANIFEST" 2>/dev/null | head -1)
  _ok=1
  if [ -n "$_has_shim" ]; then
    pass "AC2d: manifest has shim-stamp entry (thin-root §2 shim component)"
  else
    failc "AC2d" "no shim-stamp entry in manifest (thin-root §2 requires shim)"
    _ok=0
  fi
  if [ -n "$_has_copy" ]; then
    pass "AC2d: manifest has workflow copy entry (thin-root §2 workflows component)"
  else
    failc "AC2d" "no workflow copy entry in manifest (thin-root §2 requires workflows)"
    _ok=0
  fi
  if [ -n "$_has_merge" ]; then
    pass "AC2d: manifest has json-merge entry (thin-root §2 settings-pin component)"
  else
    failc "AC2d" "no json-merge entry in manifest (thin-root §2 requires settings pin)"
    _ok=0
  fi
  if [ -n "$_has_method" ]; then
    pass "AC2d: manifest has METHODOLOGY.md entry (thin-root §2 methodology component)"
  else
    failc "AC2d" "no METHODOLOGY.md entry in manifest (thin-root §2 requires methodology)"
    _ok=0
  fi
  # No entry with kind outside the four allowed (already checked in AC2a)
else
  failc "AC2d" "manifest.json ($MANIFEST) or thin-root-layer.md ($THIN_ROOT_DOC) missing"
fi

# ── AC2e: sha256 freshness ─────────────────────────────────────────────────────
echo "== AC2e: sha256 freshness (per-copy entry hash == current shasum of source) =="
if [ -f "$MANIFEST" ]; then
  _stale=""
  _tab=$(printf '\t')
  while IFS="$_tab" read -r _src _hash; do
    if [ "$_hash" = "null" ] || [ -z "$_hash" ]; then
      continue  # null allowed for manifest self-entry
    fi
    _abs_src="$REPO_ROOT/$_src"
    if ! [ -f "$_abs_src" ]; then
      _stale="$_stale [missing-source:$_src]"
      continue
    fi
    # Compute sha256: try shasum -a 256 (macOS/Linux), fallback to sha256sum
    _actual=$(shasum -a 256 "$_abs_src" 2>/dev/null | awk '{print $1}')
    if [ -z "$_actual" ]; then
      _actual=$(sha256sum "$_abs_src" 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$_actual" ]; then
      _stale="$_stale [cannot-hash:$_src]"
      continue
    fi
    if [ "$_actual" != "$_hash" ]; then
      _stale="$_stale [$_src: manifest=$_hash actual=$_actual]"
    fi
  done <<HASHES
$(jq -r '.artifacts[] | select(.kind == "copy") | [.source, (.sha256 // "null")] | @tsv' "$MANIFEST" 2>/dev/null)
HASHES
  if [ -z "$_stale" ]; then
    pass "AC2e: all copy-kind artifact sha256 hashes match current source files"
  else
    failc "AC2e" "stale or unverifiable sha256 entries:$_stale"
  fi
else
  failc "AC2e" "setup/manifest.json absent — cannot check sha256 freshness"
fi

# ── AC-1 (issue #10): exact registration of the 4 methodology-step scripts ────
echo "== AC-1 (issue #10): 4 methodology-step scripts registered as root-layer/copy, count==47 =="
if [ -f "$MANIFEST" ]; then
  _ac1_bad=""
  for _ac1_src in \
    "scripts/preflight/scan-cross-issue-recurrence.sh" \
    "scripts/handoff/emit-cycle-digest.sh" \
    "scripts/handoff/create-host-pr.sh" \
    "scripts/cleanup/cleanup-issue.sh"
  do
    _ac1_match=$(jq -r --arg s "$_ac1_src" \
      '.artifacts[] | select(.source == $s)' "$MANIFEST" 2>/dev/null)
    if [ -z "$_ac1_match" ]; then
      _ac1_bad="$_ac1_bad [missing:$_ac1_src]"
      continue
    fi
    _ac1_count=$(printf '%s' "$_ac1_match" | jq -s 'length')
    if [ "$_ac1_count" != "1" ]; then
      _ac1_bad="$_ac1_bad [$_ac1_src: expected 1 entry, found $_ac1_count]"
      continue
    fi
    _ac1_dest=$(printf '%s' "$_ac1_match" | jq -r '.dest')
    _ac1_tier=$(printf '%s' "$_ac1_match" | jq -r '.tier')
    _ac1_kind=$(printf '%s' "$_ac1_match" | jq -r '.kind')
    if [ "$_ac1_dest" != "$_ac1_src" ]; then
      _ac1_bad="$_ac1_bad [$_ac1_src: dest='$_ac1_dest' != source]"
    fi
    if [ "$_ac1_tier" != "root-layer" ]; then
      _ac1_bad="$_ac1_bad [$_ac1_src: tier='$_ac1_tier' != root-layer]"
    fi
    if [ "$_ac1_kind" != "copy" ]; then
      _ac1_bad="$_ac1_bad [$_ac1_src: kind='$_ac1_kind' != copy]"
    fi
  done
  _ac1_total=$(jq -r '.artifacts | length' "$MANIFEST" 2>/dev/null)
  if [ "$_ac1_total" != "47" ]; then
    _ac1_bad="$_ac1_bad [artifacts|length=$_ac1_total != 47]"
  fi
  if [ -z "$_ac1_bad" ]; then
    pass "AC-1 (issue #10): all 4 scripts registered (source==dest, root-layer/copy) and artifacts|length==47"
  else
    failc "AC-1 (issue #10)" "registration gap or field mismatch:$_ac1_bad"
  fi
else
  failc "AC-1 (issue #10)" "setup/manifest.json absent — cannot check registration"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W3 — drift detector
# ══════════════════════════════════════════════════════════════════════════════

# ── AC3a: drift detector is manifest entry + exists in target ─────────────────
echo "== AC3a: drift detector in manifest + present in target post-install =="
if [ -f "$MANIFEST" ]; then
  _det_dest=$(jq -r '.artifacts[] | select(.dest | contains("drift-check")) | .dest' "$MANIFEST" 2>/dev/null | head -1)
  if [ -n "$_det_dest" ]; then
    pass "AC3a: drift-check script is a manifest artifact entry (dest: $_det_dest)"
  else
    failc "AC3a" "no drift-check artifact found in manifest"
  fi
else
  failc "AC3a" "manifest absent — cannot verify drift-check manifest entry"
fi
_det_target="$TARGET/.claude/autoflow/drift-check.sh"
if [ -f "$_det_target" ]; then
  pass "AC3a: drift-check.sh exists in installed target at .claude/autoflow/drift-check.sh"
else
  failc "AC3a" "drift-check.sh absent in target ($TARGET/.claude/autoflow/drift-check.sh)"
fi

# ── AC3b: clean install -> detector exits 0 ──────────────────────────────────
echo "== AC3b: clean install -> drift detector exits 0 =="
if [ -f "$_det_target" ]; then
  # Run detector from within the target
  DET_OUT=$(CLAUDE_PROJECT_DIR="$TARGET" sh "$_det_target" 2>&1)
  DET_CODE=$?
  if [ "$DET_CODE" -eq 0 ]; then
    pass "AC3b: drift detector exits 0 on clean install"
  else
    failc "AC3b" "drift detector exited $DET_CODE on clean install (expected 0); last line: $(printf '%s\n' "$DET_OUT" | tail -1)"
  fi
else
  failc "AC3b" "drift-check.sh not installed — cannot run clean-install check"
fi

# ── AC3c: drift detection (D1 arms) ──────────────────────────────────────────
echo "== AC3c: drift detection (copy content, shim region, json-merge pin) =="
# First install a fresh target for mutation tests
if [ -f "$INIT_SH" ]; then
  run_install "$DRIFT_TARGET" >/dev/null 2>&1
  _dt_code=$?
else
  _dt_code=1
fi

_drift_det="$DRIFT_TARGET/.claude/autoflow/drift-check.sh"

if [ "$_dt_code" -eq 0 ] && [ -f "$_drift_det" ]; then
  # Arm (i): mutate a copy artifact (workflow file)
  echo "== AC3c arm (i): copy artifact content altered -> detector catches it =="
  _wf_path="$DRIFT_TARGET/.claude/workflows/architect-deliberation.js"
  if [ -f "$_wf_path" ]; then
    printf '\n// DRIFT_MUTATION\n' >> "$_wf_path"
    DRIFT_OUT=$(CLAUDE_PROJECT_DIR="$DRIFT_TARGET" sh "$_drift_det" 2>&1)
    DRIFT_CODE=$?
    if [ "$DRIFT_CODE" -ne 0 ]; then
      if printf '%s\n' "$DRIFT_OUT" | grep -qF '.claude/workflows/architect-deliberation.js' \
         || printf '%s\n' "$DRIFT_OUT" | grep -qiE 'drift|fail|mismatch'; then
        pass "AC3c (i): D1 copy drift caught (non-zero + drifted dest named)"
      else
        pass "AC3c (i): D1 copy drift caught (detector non-zero; dest naming: check output)"
      fi
    else
      failc "AC3c (i)" "detector exited 0 after copy artifact mutation (drift not caught)"
    fi
    # Restore mutation target (not needed past this point; tests are complete)
  else
    failc "AC3c (i)" "workflow file missing in DRIFT_TARGET — cannot mutate for D1 copy test"
  fi

  # Arm (ii): alter shim region in target CLAUDE.md
  echo "== AC3c arm (ii): shim region edited -> detector catches it =="
  _dclaude="$DRIFT_TARGET/CLAUDE.md"
  if [ -f "$_dclaude" ]; then
    # Insert a line inside the managed block
    awk '/AUTOFLOW-IMPORT:END/{print "<!-- DRIFT MUTATION -->"}; {print}' \
      "$_dclaude" > "$_dclaude.tmp" && mv "$_dclaude.tmp" "$_dclaude"
    DRIFT_OUT2=$(CLAUDE_PROJECT_DIR="$DRIFT_TARGET" sh "$_drift_det" 2>&1)
    DRIFT_CODE2=$?
    if [ "$DRIFT_CODE2" -ne 0 ]; then
      pass "AC3c (ii): D1 shim-region drift caught (non-zero)"
    else
      failc "AC3c (ii)" "detector exited 0 after shim-region mutation (drift not caught)"
    fi
  else
    failc "AC3c (ii)" "target CLAUDE.md missing in DRIFT_TARGET — cannot test shim-region drift"
  fi

  # Arm (iii): remove pin key from installed settings.json
  echo "== AC3c arm (iii): json-merge pin key removed -> detector catches it =="
  _dsettings="$DRIFT_TARGET/.claude/settings.json"
  if [ -f "$_dsettings" ] && jq -e . "$_dsettings" >/dev/null 2>&1; then
    jq 'del(.enabledPlugins["autoflow@autoflow"])' \
      "$_dsettings" > "$_dsettings.tmp" && mv "$_dsettings.tmp" "$_dsettings"
    DRIFT_OUT3=$(CLAUDE_PROJECT_DIR="$DRIFT_TARGET" sh "$_drift_det" 2>&1)
    DRIFT_CODE3=$?
    if [ "$DRIFT_CODE3" -ne 0 ]; then
      pass "AC3c (iii): D1 json-merge pin drift caught (non-zero)"
    else
      failc "AC3c (iii)" "detector exited 0 after pin key removal (drift not caught)"
    fi
  else
    failc "AC3c (iii)" "settings.json missing or invalid in DRIFT_TARGET — cannot test pin drift"
  fi
else
  failc "AC3c (i)"   "install into DRIFT_TARGET failed (exit $_dt_code) or detector absent"
  failc "AC3c (ii)"  "install into DRIFT_TARGET failed — cannot test shim-region drift"
  failc "AC3c (iii)" "install into DRIFT_TARGET failed — cannot test pin-key drift"
fi

# ── AC3d: D2 version skew + SKIP ─────────────────────────────────────────────
echo "== AC3d arm (a): version skew (plugin.json version differs from manifest) -> non-zero =="
# Install a fresh target for D2 testing
if [ -f "$INIT_SH" ]; then
  run_install "$SKEW_TARGET" >/dev/null 2>&1
  _sk_code=$?
else
  _sk_code=1
fi
_skew_det="$SKEW_TARGET/.claude/autoflow/drift-check.sh"
if [ "$_sk_code" -eq 0 ] && [ -f "$_skew_det" ]; then
  # Arm (a): create a fixture plugin.json with a mismatched version
  _fake_plugin_root=$(mktemp -d)
  mkdir -p "$_fake_plugin_root/.claude-plugin"
  printf '{"name":"autoflow","version":"9.9.9"}\n' \
    > "$_fake_plugin_root/.claude-plugin/plugin.json"
  SKEW_OUT=$(CLAUDE_PROJECT_DIR="$SKEW_TARGET" CLAUDE_PLUGIN_ROOT="$_fake_plugin_root" \
             sh "$_skew_det" 2>&1)
  SKEW_CODE=$?
  rm -rf "$_fake_plugin_root"
  if [ "$SKEW_CODE" -ne 0 ]; then
    pass "AC3d (a): D2 version skew detected (non-zero when plugin version != manifest version)"
  else
    failc "AC3d (a)" "detector exited 0 despite version skew (expected non-zero)"
  fi

  # Arm (b): CLAUDE_PLUGIN_ROOT unresolvable -> SKIP, not FAIL
  echo "== AC3d arm (b): unresolvable CLAUDE_PLUGIN_ROOT -> SKIP line, not failure =="
  SKIP_OUT=$(CLAUDE_PROJECT_DIR="$SKEW_TARGET" \
             sh "$_skew_det" 2>&1)
  SKIP_CODE=$?
  if printf '%s\n' "$SKIP_OUT" | grep -qiE 'SKIP'; then
    pass "AC3d (b): SKIP line present when CLAUDE_PLUGIN_ROOT unset"
    if [ "$SKIP_CODE" -eq 0 ]; then
      pass "AC3d (b): detector exits 0 on SKIP (D2 skip does not fail the run)"
    else
      failc "AC3d (b)" "detector exited $SKIP_CODE on SKIP (expected 0 — SKIP must not fail)"
    fi
  else
    failc "AC3d (b)" "no SKIP line found when CLAUDE_PLUGIN_ROOT unresolvable (output: $(printf '%s\n' "$SKIP_OUT" | tail -3))"
  fi
else
  failc "AC3d (a)" "install into SKEW_TARGET failed (exit $_sk_code) or detector absent"
  failc "AC3d (b)" "install into SKEW_TARGET failed — cannot test D2 SKIP"
fi

# ── AC3e: detector independence (no network calls + source-repo-removed run) ──
echo "== AC3e: drift detector independence (no network calls, no source-repo dependency) =="
_drift_sh="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
if [ -f "$_drift_sh" ]; then
  # Static: assert no network tool invocations
  _net_hits=$(grep -E '(curl|wget|gh |git .*(fetch|pull|push|remote|clone))' "$_drift_sh" 2>/dev/null)
  if [ -z "$_net_hits" ]; then
    pass "AC3e static: no curl/wget/gh/git-remote calls in drift-check.sh"
  else
    failc "AC3e static" "network/remote calls found in drift-check.sh: $_net_hits"
  fi
else
  failc "AC3e static" "drift-check.sh source absent at $REPO_ROOT/setup/thin-root-layer/drift-check.sh"
fi
# Behavioral: the installed detector must run with the source repo checkout
# genuinely unavailable. Method (design DCR-6, source-repo-removed run):
#   (i)  relocate the whole installed target OUT of its install-time path
#        (mv to a fresh mktemp dir) — severs any relative/recorded relationship
#        to the AutoFlow checkout;
#   (ii) static: no installed file may embed the source repo's absolute path
#        (a baked path would be a hidden source-repo dependency);
#   (iii) run the relocated detector from a cwd outside the repo with only
#        CLAUDE_PROJECT_DIR pointing at the relocated target — exit 0.
# SKEW_TARGET is a clean install (only env vars varied in AC3d); reuse it.
_indep_det="$SKEW_TARGET/.claude/autoflow/drift-check.sh"
if [ -f "$_indep_det" ]; then
  _reloc_parent=$(mktemp -d)
  _reloc="$_reloc_parent/relocated-target"
  mv "$SKEW_TARGET" "$_reloc"
  mkdir -p "$SKEW_TARGET"   # keep the trap's rm -rf path valid

  # (ii) no installed file embeds the source repo absolute path
  _baked=$(grep -rlF "$REPO_ROOT" "$_reloc" 2>/dev/null)
  if [ -z "$_baked" ]; then
    pass "AC3e behavioral: no installed file embeds the source repo absolute path"
  else
    failc "AC3e behavioral" "installed file(s) embed the source repo path (hidden dependency): $_baked"
  fi

  # (iii) run the relocated detector from outside the repo
  INDEP_OUT=$(cd "$_reloc_parent" && \
              CLAUDE_PROJECT_DIR="$_reloc" \
              sh "$_reloc/.claude/autoflow/drift-check.sh" 2>&1)
  INDEP_CODE=$?
  if [ "$INDEP_CODE" -eq 0 ]; then
    pass "AC3e behavioral: relocated detector exits 0 with source repo unavailable (TARGET_ROOT-anchored inputs only)"
  else
    failc "AC3e behavioral" "relocated detector exited $INDEP_CODE (source-repo dependency suspected); last line: $(printf '%s\n' "$INDEP_OUT" | tail -1)"
  fi
  rm -rf "$_reloc_parent"
else
  failc "AC3e behavioral" "detector not installed in SKEW_TARGET — cannot run independence behavioral check"
fi

# ══════════════════════════════════════════════════════════════════════════════
# W4 — SETUP-GUIDE / docs
# ══════════════════════════════════════════════════════════════════════════════

# ── AC4a: SETUP-GUIDE.md documents install model, manifest, drift command ─────
echo "== AC4a: SETUP-GUIDE.md documents install model, manifest, drift-check =="
if [ -f "$SETUP_GUIDE" ]; then
  # Token 1: install-into-TARGET model (--target flag)
  if grep -qE '\-\-target|install.into.target|install-into-TARGET' "$SETUP_GUIDE"; then
    pass "AC4a: SETUP-GUIDE.md documents the --target install model"
  else
    failc "AC4a" "SETUP-GUIDE.md lacks --target / install-into-TARGET documentation"
  fi
  # Token 2: manifest reference
  if grep -qiE 'manifest\.json|artifact manifest|manifest layout' "$SETUP_GUIDE"; then
    pass "AC4a: SETUP-GUIDE.md references the artifact manifest"
  else
    failc "AC4a" "SETUP-GUIDE.md lacks manifest documentation"
  fi
  # Token 3: drift detector run command
  if grep -qE 'drift.check\.sh|drift-check' "$SETUP_GUIDE"; then
    pass "AC4a: SETUP-GUIDE.md references the drift-check run command"
  else
    failc "AC4a" "SETUP-GUIDE.md lacks drift-check.sh run documentation"
  fi
else
  failc "AC4a" "setup/SETUP-GUIDE.md missing at $SETUP_GUIDE"
fi

# ── AC4b: guide copy-list/checklist names thin-root artifacts ─────────────────
echo "== AC4b: SETUP-GUIDE.md copy-list/checklist names thin-root artifacts =="
if [ -f "$SETUP_GUIDE" ]; then
  _missing=""
  # Shim artifact
  grep -qiE 'CLAUDE\.md|shim|AUTOFLOW-IMPORT' "$SETUP_GUIDE" \
    || _missing="$_missing shim/CLAUDE.md"
  # Workflow files
  grep -qiE 'architect-deliberation|verify-cause-branch|workflows' "$SETUP_GUIDE" \
    || _missing="$_missing workflows"
  # Settings pin
  grep -qiE 'settings.*pin|settings\.json|extraKnownMarketplaces|enabledPlugins' "$SETUP_GUIDE" \
    || _missing="$_missing settings-pin"
  # Methodology tree
  grep -qiE 'METHODOLOGY\.md|methodology|autoflow/' "$SETUP_GUIDE" \
    || _missing="$_missing methodology-tree"
  if [ -z "$_missing" ]; then
    pass "AC4b: SETUP-GUIDE.md references all thin-root artifact classes (shim, workflows, settings-pin, methodology)"
  else
    failc "AC4b" "SETUP-GUIDE.md missing references to thin-root components:$_missing"
  fi
else
  failc "AC4b" "setup/SETUP-GUIDE.md missing at $SETUP_GUIDE"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Regression — AC-Ra/AC-Rb
# ══════════════════════════════════════════════════════════════════════════════

echo "== AC-Ra: verify-package.sh whole-suite regression =="
if [ -f "$VERIFY_PACKAGE" ]; then
  VP_OUT=$(sh "$VERIFY_PACKAGE" 2>&1)
  VP_CODE=$?
  VP_RESULT=$(printf '%s\n' "$VP_OUT" | grep '^RESULT:' | head -1)
  if [ "$VP_CODE" -eq 0 ]; then
    pass "AC-Ra: verify-package.sh exits 0 (#790 regression intact) — $VP_RESULT"
  else
    failc "AC-Ra" "verify-package.sh exited $VP_CODE (#790 regression broken) — $VP_RESULT"
  fi
else
  failc "AC-Ra" "tests/plugin/verify-package.sh missing at $VERIFY_PACKAGE"
fi

echo "== AC-Rb: verify-thin-root-layer.sh whole-suite regression =="
if [ -f "$VERIFY_THIN_ROOT" ]; then
  VT_OUT=$(sh "$VERIFY_THIN_ROOT" 2>&1)
  VT_CODE=$?
  VT_RESULT=$(printf '%s\n' "$VT_OUT" | grep '^RESULT:' | head -1)
  if [ "$VT_CODE" -eq 0 ]; then
    pass "AC-Rb: verify-thin-root-layer.sh exits 0 (#791 regression intact) — $VT_RESULT"
  else
    failc "AC-Rb" "verify-thin-root-layer.sh exited $VT_CODE (#791 regression broken) — $VT_RESULT"
  fi
else
  failc "AC-Rb" "tests/plugin/verify-thin-root-layer.sh missing at $VERIFY_THIN_ROOT"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
