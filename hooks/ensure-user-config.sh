#!/bin/bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# User-level config bootstrap  (SessionStart; issue #463)
#
# What this hook does:
#   Creates the operator's user-level AutoFlow file, $HOME/.autoflow/config.json
#   (scripts/lib/user-config.sh), when it is absent, with the default
#     { "review": { "reviewers": [] } }
#   — external review off until the operator sets `reviewers` there
#   (docs/reviewer-backend.md > Config location), and no `record_root`, so the
#   record root is the default $HOME/.autoflow (scripts/lib/records.sh) — and,
#   only when it created
#   the file, tells the operator where it is and what it holds
#   (`systemMessage`). An existing file is never changed, read or validated,
#   broken or not.
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
# It never blocks a session: any failure (no HOME, an unwritable directory)
# exits 0 with no output.

set -u

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/user-config.sh
. "$HOOK_DIR/../scripts/lib/user-config.sh" 2>/dev/null || exit 0

# The hook payload is not needed.
cat >/dev/null 2>&1 || true

cfg="$(autoflow_user_config_path)"
[ -n "$cfg" ] || exit 0
[ -e "$cfg" ] && exit 0

dir="${cfg%/*}"
mkdir -p "$dir" 2>/dev/null || exit 0
tmp="$(mktemp "$dir/.config.json.XXXXXX" 2>/dev/null)" || exit 0
if ! printf '%s\n' "$AUTOFLOW_USER_CONFIG_DEFAULT" > "$tmp" 2>/dev/null; then
  rm -f "$tmp"
  exit 0
fi
chmod 644 "$tmp" 2>/dev/null || true

if ln "$tmp" "$cfg" 2>/dev/null; then
  rm -f "$tmp"
  doc="$(cd "$HOOK_DIR/.." && pwd)/docs/reviewer-backend.md"
  msg="AutoFlow created ${cfg} with { \"review\": { \"reviewers\": [] } } — external review is off. Set \"reviewers\": [\"codex\"] there to run codex beside the built-in review in every project whose .claude/autoflow.local.json has no .review (${doc} > Config location)."
  msg="${msg//\\/\\\\}"
  msg="${msg//\"/\\\"}"
  printf '{"systemMessage":"%s"}\n' "$msg"
else
  rm -f "$tmp"
fi
exit 0
