#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# /autoflow:install — detection + git-state derivation (deterministic seam)
# Issue #943 — marketplace-cache-based root-layer stamp
# =============================================================================
# Read-only. Emits a machine-parseable `key=value` report to stdout that the
# install SKILL.md (and tests/plugin/verify-install-skill-scripts.sh) consume.
# Writes nothing to the target — the opt-in confirmation gate + all writes live
# in SKILL.md / scaffold-identity.sh / init.sh, strictly after confirmation.
#
# Env contract (feature-design §3.2):
#   TARGET_ROOT        consuming project root (default ${CLAUDE_PROJECT_DIR:-$PWD})
#   PLUGIN_CACHE_ROOT  the marketplace clone (holds setup/manifest.json);
#                      SKILL.md Step 0 passes what resolve-cache-root.sh
#                      printed. Unset or empty -> resolved here through the
#                      same script (issue #174); a caller-supplied value is
#                      validated as given, never replaced.
#
# Exit: 0 normally (a non-git / non-GitHub target is NOT an error — those
# derived fields are simply omitted); non-zero ONLY on hard error (cannot
# resolve PLUGIN_CACHE_ROOT / missing cache setup/manifest.json).
#
# DRIFT vs VERSION_SKEW are two decoupled axes (feature-design §3.2):
#   - DRIFT reuses the cache's drift-check.sh and counts ONLY the FAIL lines a
#     re-stamp of the thin root repairs — D1/D3 (installed content) and D4
#     (installed bundle behind the marketplace clone, issue #167); line format
#     `FAIL: <id> -- <msg>`. D2 (plugin.json version skew), D5 (plugin cache
#     vs clone plugin source) and D6 (spawn-policy scaffold vs the loaded agent
#     definitions, issue #185) are filtered out: none is a finding a stamp
#     changes — D2 so a pure version bump never double-reports as content
#     drift, D5 because its remedy is `/plugin update`, D6 because the
#     scaffold is target-owned and a re-stamp never overwrites it (its remedy
#     is a hand edit, reported on its own axis below).
#   - POLICY is the D6 axis, reported separately so SKILL.md can list the rows
#     to fix in both the Step-1 (pre-stamp) and Step-4 (post-stamp) reports:
#     POLICY_STATE = pass | fail | skip | na (target not installed, or the
#     oracle did not run) | error (the oracle emitted no D6 line at all);
#     POLICY_FAILS = the count of `FAIL: D6` lines; one POLICY_FINDING=<msg>
#     line per finding (a repeated key — consumers read every occurrence).
#   - VERSION_SKEW compares the installed manifest .version against the cache
#     thin-root source setup/manifest.json .version (the exact file init.sh
#     byte-copies in) — a distinct comparand from drift-check D2 (plugin.json).
# =============================================================================

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RESOLVER="$SCRIPT_DIR/resolve-cache-root.sh"

TARGET_ROOT="${TARGET_ROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}"
PLUGIN_CACHE_ROOT="${PLUGIN_CACHE_ROOT:-}"

# Unset or empty: resolve the clone the way SKILL.md Step 0 does — the
# harness's registries first, the ${CLAUDE_PLUGIN_ROOT}/../.. arithmetic last
# (issue #174: under /plugin install that arithmetic lands in cache/<mkt>/,
# which holds no setup/). An explicit value is never replaced: a wrong path
# the caller named is the caller's error to see, not one to paper over.
if [ -z "$PLUGIN_CACHE_ROOT" ] && [ -f "$RESOLVER" ]; then
  PLUGIN_CACHE_ROOT=$(sh "$RESOLVER" 2>/dev/null) || PLUGIN_CACHE_ROOT=""
fi

# ── Hard-error guard: the cache source repo must be resolvable ────────────────
CACHE_MANIFEST="$PLUGIN_CACHE_ROOT/setup/manifest.json"
if [ -z "$PLUGIN_CACHE_ROOT" ] || [ ! -f "$CACHE_MANIFEST" ]; then
  echo "ERROR: PLUGIN_CACHE_ROOT unresolvable or missing setup/manifest.json (PLUGIN_CACHE_ROOT='$PLUGIN_CACHE_ROOT')" >&2
  if [ -f "$RESOLVER" ]; then
    # The clone's location is read from this list, never guessed (issue #174).
    echo "  marketplace clone candidates, in order (each must hold setup/manifest.json):" >&2
    sh "$RESOLVER" --candidates 2>/dev/null | sed 's/^/    /' >&2
    echo "  remedy: /plugin marketplace add Munsik-Park/autoflow, or export AUTOFLOW_MARKETPLACE_ROOT=<clone root>" >&2
  fi
  exit 1
fi

INSTALLED_MANIFEST="$TARGET_ROOT/.claude/autoflow/manifest.json"
# DRIFT oracle is sourced from the cache (trusted) domain, NOT the target: the
# target-owned drift-check.sh is untrusted pre-confirmation (a tampered copy must
# never be executed). $PLUGIN_CACHE_ROOT is already hard-validated above. The
# target copy is read/hashed by the oracle's D1, never executed by detect.sh.
DRIFT_ORACLE="$PLUGIN_CACHE_ROOT/setup/thin-root-layer/drift-check.sh"

# ── INSTALL_STATE ─────────────────────────────────────────────────────────────
if [ -f "$INSTALLED_MANIFEST" ]; then
  INSTALL_STATE=installed
else
  INSTALL_STATE=absent
fi

# ── DRIFT (D1/D3/D4 — stamp-repairable; D2/D5/D6 not stamp-repairable, filtered out) ─
DRIFT_STATE=na
DRIFT_FAILS=0
DRIFT_FIRST=
POLICY_STATE=na
POLICY_FAILS=0
POLICY_FINDINGS=
if [ "$INSTALL_STATE" = installed ]; then
  if [ ! -f "$DRIFT_ORACLE" ]; then
    # Deterministic degradation (no silent clean): the cache drift oracle is
    # unresolvable (corrupt/partial cache) -> DRIFT_STATE=error, never clean.
    DRIFT_STATE=error
  else
    # The oracle's D4 compares the target against the marketplace clone — and
    # $PLUGIN_CACHE_ROOT IS that clone (the tree a confirmed stamp copies
    # from), so it is named explicitly rather than re-derived from the
    # harness registries. The oracle sources its resolver ONLY from its own
    # (cache) tree — never the target's copy, which is target-controlled and
    # must not run pre-confirmation (PR #172 review, High) — so a same-version
    # target stamped before this leg existed is still compared, and a
    # tampered target resolver is hashed by D1, not executed.
    _drift_out=$(CLAUDE_PROJECT_DIR="$TARGET_ROOT" AUTOFLOW_MARKETPLACE_ROOT="$PLUGIN_CACHE_ROOT" sh "$DRIFT_ORACLE" 2>&1)
    _drift_rc=$?
    if printf '%s\n' "$_drift_out" | grep -q '^FAIL: drift-check '; then
      # drift-check itself could not run (jq absent / manifest unreadable).
      DRIFT_STATE=error
    else
      _nd2=$(printf '%s\n' "$_drift_out" | grep '^FAIL: ' | grep -v -e '^FAIL: D2 ' -e '^FAIL: D5 ' -e '^FAIL: D6 ')
      # D6 (issue #185) on its own axis: the spawn-policy scaffold vs the
      # agent definitions the session loads. Not stamp-repairable (the
      # scaffold is never overwritten), so it never moves DRIFT_STATE; the
      # finding lines are carried verbatim for the skill to list.
      _d6_fails=$(printf '%s\n' "$_drift_out" | grep '^FAIL: D6 ' | sed -E 's/^FAIL: D6 -- //')
      if [ -n "$_d6_fails" ]; then
        POLICY_STATE=fail
        POLICY_FAILS=$(printf '%s\n' "$_d6_fails" | wc -l | tr -d ' ')
        POLICY_FINDINGS=$_d6_fails
      elif printf '%s\n' "$_drift_out" | grep -q '^PASS: D6'; then
        POLICY_STATE=pass
      elif printf '%s\n' "$_drift_out" | grep -q '^SKIP: D6'; then
        POLICY_STATE=skip
      else
        # The oracle ran but emitted no D6 verdict at all: an oracle that
        # predates the leg, or an abnormal termination before it — never
        # read as pass.
        POLICY_STATE=error
      fi
      if [ -n "$_nd2" ]; then
        DRIFT_STATE=drift
        DRIFT_FAILS=$(printf '%s\n' "$_nd2" | wc -l | tr -d ' ')
        DRIFT_FIRST=$(printf '%s\n' "$_nd2" | head -1 | sed -E 's/^FAIL: [^ ]+ -- //')
      else
        # _nd2 empty: no non-D2 FAIL line. drift-check exits non-zero ONLY
        # with a FAIL line (self-guard, or D1/D2/D3 FAIL). A non-zero exit
        # with NO FAIL: line at all is an unexplained abnormal termination
        # (shell syntax error, set -u abort, or a bare exit N) -> error,
        # never silent clean (mirrors the L57-58 file-absent guarantee).
        # A non-zero exit WITH a FAIL: line here can only be D2/D5-only
        # plugin-tier skew or a D6-only scaffold finding (both intentionally
        # filtered; D6 is reported on the POLICY axis) -> stays clean.
        if [ "$_drift_rc" -ne 0 ] \
           && ! printf '%s\n' "$_drift_out" | grep -q '^FAIL: '; then
          DRIFT_STATE=error
        else
          DRIFT_STATE=clean
          DRIFT_FAILS=0
        fi
      fi
    fi
  fi
fi

# ── VERSION_SKEW (installed thin-root version vs cache source version) ─────────
VERSION_INSTALLED=
VERSION_CACHE=$(jq -r '.version // empty' "$CACHE_MANIFEST" 2>/dev/null)
if [ -f "$INSTALLED_MANIFEST" ]; then
  VERSION_INSTALLED=$(jq -r '.version // empty' "$INSTALLED_MANIFEST" 2>/dev/null)
fi
if [ -n "$VERSION_INSTALLED" ] && [ -n "$VERSION_CACHE" ] && [ "$VERSION_INSTALLED" != "$VERSION_CACHE" ]; then
  VERSION_SKEW=yes
else
  VERSION_SKEW=no
fi

# ── Git-state derivation (display-only; graceful omission, never an error) ─────
ORG=
REPO=
DEFAULT_BRANCH=
TOPOLOGY=single
FORK_PROPOSAL=
FORK_EXISTS=
LOCAL_MD_EXISTS=no

[ -f "$TARGET_ROOT/CLAUDE.local.md" ] && LOCAL_MD_EXISTS=yes

_have_git=0
command -v git >/dev/null 2>&1 && _have_git=1

if [ "$_have_git" = 1 ] && git -C "$TARGET_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  _url=$(git -C "$TARGET_ROOT" remote get-url origin 2>/dev/null)
  case "$_url" in
    *github.com[:/]*)
      _p="${_url#*github.com}"   # ":org/repo.git" or "/org/repo.git"
      _p="${_p#[:/]}"            # strip the leading : or /
      _p="${_p%.git}"           # strip trailing .git
      ORG="${_p%%/*}"
      REPO="${_p##*/}"
      ;;
    git@github.com[-_]*:*/*)     # GitHub SSH host-alias (~/.ssh/config), e.g. github.com-work/github.com_personal — the [-_] separator excludes github.com-prefixed foreign hosts (github.com.evil…); the exact git@github.com: form is caught by the preceding *github.com[:/]* arm
      _p="${_url#*:}"           # "org/repo.git" — path after the first colon
      _p="${_p%.git}"
      ORG="${_p%%/*}"
      REPO="${_p##*/}"
      ;;
  esac
  _head=$(git -C "$TARGET_ROOT" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$_head" ] && DEFAULT_BRANCH="${_head#refs/remotes/origin/}"
fi

# Topology: a .gitmodules entry (or a non-empty `git submodule status`) => multi.
if [ -f "$TARGET_ROOT/.gitmodules" ]; then
  TOPOLOGY=multi
elif [ "$_have_git" = 1 ] && [ -n "$(git -C "$TARGET_ROOT" submodule status 2>/dev/null)" ]; then
  TOPOLOGY=multi
fi

# Fork-URL proposal + existence probe — multi-repo only (gate dormant on single).
if [ "$TOPOLOGY" = multi ]; then
  if [ -n "$ORG" ] && [ -n "$REPO" ]; then
    FORK_PROPOSAL="$ORG/$REPO"
  fi
  if ! command -v gh >/dev/null 2>&1 || [ -z "$FORK_PROPOSAL" ]; then
    FORK_EXISTS=unknown
  elif gh repo view "$FORK_PROPOSAL" >/dev/null 2>&1; then
    FORK_EXISTS=yes
  else
    FORK_EXISTS=no
  fi
fi

# ── Reviewer backend (issue #979): configured backend + CLI presence ──────────
# Read-only. Reports the configured backend (target scaffold, default codex) and
# each backend CLI's presence, so SKILL.md can DISCLOSE a codex-absent target
# (its HANDOFF step-6 review would fail-closed at PREFLIGHT) and prompt for an
# explicit backend switch at the single confirmation gate. No write here — the
# scaffold always ships its codex default; only an explicit operator switch (in
# SKILL.md, post-confirmation) ever rewrites it to claude.
REVIEW_BACKEND=codex
_bcfg="$TARGET_ROOT/.claude/autoflow.local.json"
if [ -f "$_bcfg" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    # File present but jq absent: the configured backend cannot be read. Report
    # `invalid` (never the codex default) so the disclosure gate surfaces an
    # unreadable config rather than masking it as a clean zero-config target —
    # read-side symmetry with check-review-backend.sh's fail-closed jq-absent
    # arm (issue #979 cycle 5b). detect.sh only REPORTS; it never exits.
    REVIEW_BACKEND=invalid
  elif _rb=$(jq -r '.review.backend // "codex"' "$_bcfg" 2>/dev/null) && [ -n "$_rb" ]; then
    # File present + jq available: verbatim configured value, or the `//` codex
    # default for an absent/null key.
    REVIEW_BACKEND=$_rb
  else
    # File present + jq available but parse fails or value is empty: report a
    # PARSE FAILURE as `invalid`, never masked as the codex default (AC-2/AC-3).
    REVIEW_BACKEND=invalid
  fi
fi
REVIEW_CODEX_PRESENT=no
REVIEW_CLAUDE_PRESENT=no
command -v codex  >/dev/null 2>&1 && REVIEW_CODEX_PRESENT=yes
command -v claude >/dev/null 2>&1 && REVIEW_CLAUDE_PRESENT=yes

# ── Report (printf: bash builtin, so this still emits under a stripped PATH) ───
printf 'INSTALL_STATE=%s\n'     "$INSTALL_STATE"
printf 'DRIFT_STATE=%s\n'       "$DRIFT_STATE"
printf 'DRIFT_FAILS=%s\n'       "$DRIFT_FAILS"
printf 'DRIFT_FIRST=%s\n'       "$DRIFT_FIRST"
printf 'POLICY_STATE=%s\n'      "$POLICY_STATE"
printf 'POLICY_FAILS=%s\n'      "$POLICY_FAILS"
if [ -n "$POLICY_FINDINGS" ]; then
  printf '%s\n' "$POLICY_FINDINGS" | while IFS= read -r _pf; do
    [ -n "$_pf" ] || continue
    printf 'POLICY_FINDING=%s\n' "$_pf"
  done
fi
printf 'VERSION_INSTALLED=%s\n' "$VERSION_INSTALLED"
printf 'VERSION_CACHE=%s\n'     "$VERSION_CACHE"
printf 'VERSION_SKEW=%s\n'      "$VERSION_SKEW"
printf 'ORG=%s\n'               "$ORG"
printf 'REPO=%s\n'              "$REPO"
printf 'DEFAULT_BRANCH=%s\n'    "$DEFAULT_BRANCH"
printf 'TOPOLOGY=%s\n'          "$TOPOLOGY"
printf 'FORK_PROPOSAL=%s\n'     "$FORK_PROPOSAL"
printf 'FORK_EXISTS=%s\n'       "$FORK_EXISTS"
printf 'LOCAL_MD_EXISTS=%s\n'   "$LOCAL_MD_EXISTS"
printf 'REVIEW_BACKEND=%s\n'        "$REVIEW_BACKEND"
printf 'REVIEW_CODEX_PRESENT=%s\n'  "$REVIEW_CODEX_PRESENT"
printf 'REVIEW_CLAUDE_PRESENT=%s\n' "$REVIEW_CLAUDE_PRESENT"

exit 0
