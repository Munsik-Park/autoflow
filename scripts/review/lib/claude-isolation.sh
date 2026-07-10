#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Shared claude-backend isolation preamble (issue #979, cycle 9 §3.2)
# =============================================================================
# SINGLE SOURCE OF TRUTH for the claude reviewer/probe isolation triple, sourced
# (not executed) by BOTH:
#   - scripts/review/codex-review-pr.sh   (HANDOFF step-6 review call)
#   - scripts/preflight/check-review-backend.sh --probe  (on-demand auth check)
#
# Two hand-maintained copies of this CLAUDE* env scrub / OAuth carve-out loop is
# the exact drift class that shipped a Medium finding at cycle-8 / Codex round-7
# (retaining CLAUDE_CODE_OAUTH_TOKEN was fixed in one copy only). Keeping ONE
# copy here closes that drift class: a caller composes its own review- or
# probe-specific flags on top of the isolation this file establishes.
#
# `build_claude_isolation` sets, in the caller's scope:
#   NEUTRAL_CWD             — a fresh `mktemp -d` the caller cd's into before the
#                            `claude -p` call, so the target's project-scope
#                            .claude settings/gate hooks are not loaded.
#   CLAUDE_ISOLATION_UNSET  — the `env -u …` argument array: `-u ANTHROPIC_API_KEY`
#                            (OAuth-billing guard) plus `-u <each CLAUDE*-prefixed
#                            name currently in the environment>` EXCEPT
#                            CLAUDE_CODE_OAUTH_TOKEN (the documented headless
#                            auth credential — retained, see the carve-out below).
#
# The caller then runs, e.g.:
#   ( cd "$NEUTRAL_CWD" && env "${CLAUDE_ISOLATION_UNSET[@]}" claude -p … \
#       --setting-sources "" <caller-specific flags> )
# and calls `cleanup_claude_isolation` to remove the neutral cwd afterwards.
# =============================================================================

# Populate NEUTRAL_CWD + CLAUDE_ISOLATION_UNSET in the caller's scope.
build_claude_isolation() {
  NEUTRAL_CWD="$(mktemp -d)"
  # Neutral cwd (blocks project-scope .claude settings) + CLAUDE* env scrub
  # (blocks the parent Claude Code session's re-attach via inherited
  # CLAUDECODE / CLAUDE_CODE_*) — the two isolation layers a caller pairs with
  # `--setting-sources ""` (blocks USER-scope plugin hooks). Build the unset
  # list dynamically from every CLAUDE-prefixed name currently in the
  # environment (`${!CLAUDE@}`), so a future CLAUDE_* addition is covered
  # without editing this list; keep -u ANTHROPIC_API_KEY (OAuth-billing guard).
  # PATH, HOME, and the rest of the env survive — claude needs HOME for its
  # OAuth credentials and PATH to resolve gh.
  CLAUDE_ISOLATION_UNSET=(-u ANTHROPIC_API_KEY)
  local _claude_var
  for _claude_var in ${!CLAUDE@}; do
    # Retain CLAUDE_CODE_OAUTH_TOKEN: it is the documented headless-automation
    # auth credential for the claude backend (reviewer-backend.md), not ambient
    # session state. In a token-based automation env (no HOME-stored OAuth
    # login, ANTHROPIC_API_KEY unset by design) it is the ONLY auth channel the
    # nested claude -p has; scrubbing it makes the review/probe run
    # unauthenticated (issue #979 cycle-8, Codex round-7). All other
    # CLAUDE*-prefixed session/config vars are still scrubbed dynamically.
    [[ "$_claude_var" == CLAUDE_CODE_OAUTH_TOKEN ]] && continue
    CLAUDE_ISOLATION_UNSET+=(-u "$_claude_var")
  done
}

# Remove the neutral cwd established by build_claude_isolation (best-effort).
cleanup_claude_isolation() {
  [ -n "${NEUTRAL_CWD:-}" ] && rmdir "$NEUTRAL_CWD" 2>/dev/null || true
}
