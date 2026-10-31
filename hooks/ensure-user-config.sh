#!/bin/bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# User-level config bootstrap and requirements notice  (SessionStart; issues
# #463, #553)
#
# What this hook does:
#   Creates the operator's user-level AutoFlow file, $HOME/.autoflow/config.json
#   (scripts/lib/user-config.sh), when it is absent, with the default
#     { "review": { "reviewers": [] } }
#   — no reviewer named, so the default reviewers run until the operator lists
#   them there (docs/reviewer-backend.md > Config location), and no
#   `record_root`, so the
#   record root is the default $HOME/.autoflow (scripts/lib/records.sh) — and,
#   only when it created
#   the file, tells the operator where it is and what it holds
#   (`systemMessage`). An existing file is never changed, read or validated,
#   broken or not.
#
#   Tells the operator, at every session start, of what it finds missing of
#   docs/requirements.md: `jq` or `gh` not on PATH, or a `claude` on PATH older
#   than the minimum, which is not always the running Claude Code
#   (scripts/lib/prerequisites.sh; ADR-0041). The hook's stdout is one JSON
#   object, so the two messages share one `systemMessage`.
#
# Where it runs: every session start (any source) in every project the plugin
#   is enabled in, and it writes outside the target's tree, under $HOME.
#
# Concurrent sessions: the content is written to a temporary file beside the
#   destination and published with `ln` (a hard link, which fails when the
#   destination exists). So the file is created once, a file another session
#   created first is never overwritten, the message comes only from the session
#   whose link succeeded, and no reader ever sees a partly written file.
#
# It never blocks a session: any failure (no HOME, an unwritable directory, an
# unreadable version, a library that does not load) exits 0 and leaves out what
# failed. Each part runs in its own subshell, so one that fails leaves the other.

set -u

# No `dirname`: the hook has to work under a PATH that holds nothing.
case "${BASH_SOURCE[0]}" in
  */*) HOOK_DIR="${BASH_SOURCE[0]%/*}" ;;
  *) HOOK_DIR=. ;;
esac
HOOK_DIR="$(cd "$HOOK_DIR" && pwd)"
PLUGIN_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

# Prints the message for the operator when it created the file.
create_user_config() {
  # shellcheck source=../scripts/lib/user-config.sh
  . "$HOOK_DIR/../scripts/lib/user-config.sh" 2>/dev/null || return 0

  local cfg dir tmp doc
  cfg="$(autoflow_user_config_path)"
  [ -n "$cfg" ] || return 0
  [ -e "$cfg" ] && return 0

  dir="${cfg%/*}"
  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$(mktemp "$dir/.config.json.XXXXXX" 2>/dev/null)" || return 0
  if ! printf '%s\n' "$AUTOFLOW_USER_CONFIG_DEFAULT" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 0
  fi
  chmod 644 "$tmp" 2>/dev/null || true

  if ln "$tmp" "$cfg" 2>/dev/null; then
    rm -f "$tmp"
    doc="$PLUGIN_ROOT/docs/reviewer-backend.md"
    printf '%s\n' "AutoFlow created ${cfg} with { \"review\": { \"reviewers\": [] } } — no reviewer is named there, so the default reviewers, claude and codex, review every pull request. List the reviewers to run there to choose them (${doc} > Config location)."
  else
    rm -f "$tmp"
  fi
}

# Prints the message for the operator when a requirement is not met.
check_prerequisites() {
  # shellcheck source=../scripts/lib/prerequisites.sh
  . "$HOOK_DIR/../scripts/lib/prerequisites.sh" 2>/dev/null || return 0
  autoflow_prerequisite_notice "$PLUGIN_ROOT/docs/requirements.md"
}

# The hook payload is not needed.
cat >/dev/null 2>&1 || true

config_msg="$(create_user_config 2>/dev/null)"
prerequisite_msg="$(check_prerequisites 2>/dev/null)"

msg="${config_msg}${config_msg:+${prerequisite_msg:+$'\n'}}${prerequisite_msg}"
[ -n "$msg" ] || exit 0

msg="${msg//\\/\\\\}"
msg="${msg//\"/\\\"}"
msg="${msg//$'\n'/\\n}"
msg="${msg//$'\r'/\\r}"
msg="${msg//$'\t'/\\t}"
printf '{"systemMessage":"%s"}\n' "$msg"
exit 0
