#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# /autoflow:install — reviewer-backend persistence seam (issue #979 AC-3)
# =============================================================================
# Persists the operator's EXPLICIT Step-3 backend selection into the target's
# .claude/autoflow.local.json via a single-key MERGE (.review.backend), applying
# the explicit post-confirm switch on top of init.sh's scaffold while preserving
# any sibling keys the target already holds. Refuses (never clobbers) any
# pre-existing file it cannot safely merge (jq-absent / unparseable).
# Invoked by SKILL.md Step 4 ONLY in the explicit-`claude` branch.
#
# Env contract (feature-design §4.1):
#   TARGET_ROOT   consuming project root (default ${CLAUDE_PROJECT_DIR:-$PWD})
#   BACKEND       required; the operator's explicit selection. MUST be one of
#                 {codex, claude}. Any other value -> exit 2 (no write).
#
# Exit:
#   0  merged/wrote the config; prints the resulting backend + path.
#   1  cannot safely persist without clobbering a pre-existing file (jq absent,
#      or the existing file is not valid JSON). Prints a hand-edit remedy; NO write.
#   2  invalid/empty BACKEND (not codex|claude) — no write performed.
# =============================================================================

set -u

TARGET_ROOT="${TARGET_ROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}"
BACKEND="${BACKEND:-}"

case "$BACKEND" in
  codex|claude) : ;;
  *)
    printf '[set-review-backend] BACKEND must be codex|claude (got "%s") -- no write.\n' "$BACKEND" >&2
    exit 2 ;;
esac

DEST="$TARGET_ROOT/.claude/autoflow.local.json"
mkdir -p "$(dirname "$DEST")"

if [ ! -f "$DEST" ]; then
  # No pre-existing file -> nothing to preserve; write the canonical document.
  printf '{ "review": { "backend": "%s" } }\n' "$BACKEND" > "$DEST"
elif command -v jq >/dev/null 2>&1; then
  # File exists + jq available -> merge ONLY .review.backend, preserving siblings.
  _tmp="$DEST.tmp.$$"
  if jq --arg b "$BACKEND" '.review.backend = $b' "$DEST" > "$_tmp" 2>/dev/null; then
    mv "$_tmp" "$DEST"
  else
    rm -f "$_tmp"
    printf '[set-review-backend] %s is not valid JSON; refusing to overwrite. Hand-edit .review.backend to "%s".\n' "$DEST" "$BACKEND" >&2
    exit 1
  fi
else
  # File exists but jq is unavailable -> cannot merge without a clobber; refuse.
  printf '[set-review-backend] jq unavailable; refusing to overwrite %s. Hand-edit .review.backend to "%s" (see docs/reviewer-backend.md).\n' "$DEST" "$BACKEND" >&2
  exit 1
fi

printf 'set reviewer backend to %s in %s\n' "$BACKEND" "$DEST"
# Backend-change trigger (issue #979 R2b): point the operator at the on-demand
# auth probe. No network call here — this script stays a pure persistence seam;
# the probe is the documented on-demand step the operator runs next.
printf 'next: verify auth for %s -- run scripts/preflight/check-review-backend.sh --probe\n' "$BACKEND"
exit 0
