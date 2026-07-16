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
#   PLUGIN_CACHE_ROOT  marketplace-cache repo root (holds setup/manifest.json);
#                      SKILL.md passes ${CLAUDE_PLUGIN_ROOT}/../..
#
# Exit: 0 normally (a non-git / non-GitHub target is NOT an error — those
# derived fields are simply omitted); non-zero ONLY on hard error (cannot
# resolve PLUGIN_CACHE_ROOT / missing cache setup/manifest.json).
#
# DRIFT vs VERSION_SKEW are two decoupled axes (feature-design §3.2):
#   - DRIFT reuses the installed drift-check.sh and counts ONLY non-D2 (D1/D3)
#     FAIL lines (line format `FAIL: <id> -- <msg>`); D2 version-skew is filtered
#     out so a pure version bump never double-reports as content drift.
#   - VERSION_SKEW compares the installed manifest .version against the cache
#     thin-root source setup/manifest.json .version (the exact file init.sh
#     byte-copies in) — a distinct comparand from drift-check D2 (plugin.json).
# =============================================================================

set -u

TARGET_ROOT="${TARGET_ROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}"
PLUGIN_CACHE_ROOT="${PLUGIN_CACHE_ROOT:-}"

# ── Hard-error guard: the cache source repo must be resolvable ────────────────
CACHE_MANIFEST="$PLUGIN_CACHE_ROOT/setup/manifest.json"
if [ -z "$PLUGIN_CACHE_ROOT" ] || [ ! -f "$CACHE_MANIFEST" ]; then
  echo "ERROR: PLUGIN_CACHE_ROOT unresolvable or missing setup/manifest.json (PLUGIN_CACHE_ROOT='$PLUGIN_CACHE_ROOT')" >&2
  exit 1
fi

INSTALLED_MANIFEST="$TARGET_ROOT/.claude/autoflow/manifest.json"
# DRIFT oracle is sourced from the cache (trusted) domain, NOT the target: the
# target-owned drift-check.sh is untrusted pre-confirmation (a tampered copy must
# never be executed). $PLUGIN_CACHE_ROOT is already hard-validated at L36. The
# target copy is read/hashed by the oracle's D1, never executed by detect.sh.
DRIFT_ORACLE="$PLUGIN_CACHE_ROOT/setup/thin-root-layer/drift-check.sh"

# ── INSTALL_STATE ─────────────────────────────────────────────────────────────
if [ -f "$INSTALLED_MANIFEST" ]; then
  INSTALL_STATE=installed
else
  INSTALL_STATE=absent
fi

# ── DRIFT (D1/D3 only; D2 filtered out) ───────────────────────────────────────
DRIFT_STATE=na
DRIFT_FAILS=0
DRIFT_FIRST=
if [ "$INSTALL_STATE" = installed ]; then
  if [ ! -f "$DRIFT_ORACLE" ]; then
    # Deterministic degradation (no silent clean): the cache drift oracle is
    # unresolvable (corrupt/partial cache) -> DRIFT_STATE=error, never clean.
    DRIFT_STATE=error
  else
    _drift_out=$(CLAUDE_PROJECT_DIR="$TARGET_ROOT" sh "$DRIFT_ORACLE" 2>&1)
    _drift_rc=$?
    if printf '%s\n' "$_drift_out" | grep -q '^FAIL: drift-check '; then
      # drift-check itself could not run (jq absent / manifest unreadable).
      DRIFT_STATE=error
    else
      _nd2=$(printf '%s\n' "$_drift_out" | grep '^FAIL: ' | grep -v '^FAIL: D2 ')
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
        # A non-zero exit WITH a FAIL: line here can only be D2-only skew
        # (intentionally filtered) -> stays clean.
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
