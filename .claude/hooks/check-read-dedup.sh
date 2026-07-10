#!/bin/bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# Read-dedup / stale-context guard  (PostToolUse on Read)
#
# Why this exists (see issue #243):
#   Claude Code deduplicates re-reads of an UNCHANGED file (on-disk mtime
#   match) and returns a ~100-byte stub instead of the content, e.g.
#     "File unchanged since last read … refer to that earlier tool_result"
#     "Wasted call — file unchanged since your last Read."
#   The dedup ledger is NOT reset on compact/rewind
#   (anthropics/claude-code#46749), so after a long session compacts away the
#   earlier read, the stub's "refer to earlier" DANGLES — it points at content
#   no longer in context and the model confabulates it. In the #211 cycle this
#   produced a phantom "57-line stub" of a 197-line file and a false
#   "dependency absent" blocker escalated to the user.
#
# What this hook does:
#   On a Read whose result IS such a stub, inject a system-reminder telling the
#   model the stub is NOT data — re-read via shell (sed -n / grep / wc -l),
#   which bypasses the dedup ledger (the documented #46749 workaround) — and
#   never conclude "absent / empty / stub / smaller-than-expected" from it.
#
# This fires on every occurrence, so the guard does not depend on the model
# remembering a docs rule (memory does not load for other operators anyway).

set -e
INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL_NAME" = "Read" ] || exit 0

# Read result may be a string or a structured value; normalise to text.
RESP=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response // .tool_result // empty)
  | if type == "string" then . else tostring end' 2>/dev/null)

# Dedup / unchanged-file stub markers (wording varies across CC versions).
if printf '%s' "$RESP" | grep -qiE "unchanged since( your)? last [Rr]ead|Wasted call|refer to that earlier tool_result|content from the earlier Read tool_result"; then
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // "the file"' 2>/dev/null)
  REMINDER="Read-dedup stub detected for ${FILE}. This 1-line result is NOT the file content — it is a deduplication stub (anthropics/claude-code#46749) pointing at an earlier Read result that may have been compacted out of context. Do NOT conclude the file is absent, empty, a stub, or smaller than expected. If the earlier full read is not visible above, re-read via shell to bypass the dedup ledger: 'sed -n \"N,Mp\" ${FILE}', 'grep -n PATTERN ${FILE}', or 'wc -l ${FILE}'. Reproduce any blocker / absence finding with a fresh shell read before acting on it or escalating to the user."
  jq -cn --arg ctx "$REMINDER" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
fi
exit 0
