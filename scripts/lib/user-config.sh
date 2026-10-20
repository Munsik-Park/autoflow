#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# user-config.sh — the operator's user-level AutoFlow file (issue #463)
# =============================================================================
# POSIX sh, SOURCED (never executed). One file per machine user, outside every
# target's tree:
#
#   $HOME/.autoflow/config.json
#
# It holds the operator's own values — the reviewers (`{ "review": { … } }`;
# scripts/review/lib/review-config.sh) and the
# record root (`"record_root": "<absolute path>"`, default $HOME/.autoflow;
# scripts/lib/records.sh, issue #466). Each key is read, and validated, by its
# own reader: an error in one leaves the other as it is. The
# SessionStart hook (hooks/ensure-user-config.sh) creates it once, with the
# default below, when it is absent, and never changes an existing file. $HOME
# alone decides where it is, so a check that sets HOME runs apart from the
# operator's file.
#
#   autoflow_user_config_path
#       prints $HOME/.autoflow/config.json; prints nothing when HOME is unset
#       or empty (no user file)
#   AUTOFLOW_USER_CONFIG_DEFAULT
#       the content the hook writes: no reviewer named, so the default
#       reviewers run (docs/reviewer-backend.md > Config location)

AUTOFLOW_USER_CONFIG_DEFAULT='{
  "review": { "reviewers": [] }
}'

autoflow_user_config_path() {
  [ -n "${HOME:-}" ] || return 0
  printf '%s/.autoflow/config.json' "$HOME"
}
