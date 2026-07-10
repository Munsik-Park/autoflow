#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/test/check-close-keyword-quoting.sh
#
# AC1.c — close-keyword footgun checker (issue #92).
#
# Scans a markdown file for raw close-keyword tokens (Closes|Fixes|Resolves)
# followed by `#<digits>` that would, when the file is used as a PR body, be
# interpreted by GitHub as an active issue-close trigger.
#
# Permitted zones (matching memory rule `feedback_close_keyword_in_pr_body`
# and GitHub's actual close-keyword scanner behavior):
#   - inside a fenced code block (delimited by ``` lines)
#   - inside an HTML comment (<!-- ... -->), possibly spanning lines
#   - inside an inline backtick span (`...`) on the same line
#
# Failure: prints the offending line + line number to stderr and exits 1.
# Success: exits 0 silently (unless -v is passed).
#
# Note: GitHub's own close-keyword scanner ignores code spans — this checker
# is therefore stricter than GitHub's behavior, which is what we want for
# *templates* (we are checking that the template itself never inlines a
# *literal* close keyword; the rendered host PR body adds the literal at
# HANDOFF time per the feature design §2.4).

set -euo pipefail

VERBOSE=0
if [ "${1:-}" = "-v" ]; then
  VERBOSE=1
  shift
fi

if [ "$#" -ne 1 ]; then
  echo "usage: $0 [-v] <markdown-file>" >&2
  exit 64
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
  echo "file not found: $FILE" >&2
  exit 66
fi

# State machine over the file lines.
in_code_fence=0
in_html_comment=0
found=0
lineno=0

# Use awk-free pure bash to walk lines, so this script has no extra deps.
while IFS='' read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))

  # Multi-line HTML comment handling.
  work="$line"
  if [ "$in_html_comment" -eq 1 ]; then
    if printf '%s' "$work" | grep -q -- '-->'; then
      work="${work#*-->}"
      in_html_comment=0
    else
      continue
    fi
  fi

  # Code-fence toggle: a line that *starts* with ``` (after optional
  # whitespace) flips the state. The fence line itself is treated as
  # delimiter-only.
  if printf '%s' "$work" | grep -qE '^[[:space:]]*```'; then
    if [ "$in_code_fence" -eq 1 ]; then
      in_code_fence=0
    else
      in_code_fence=1
    fi
    continue
  fi

  if [ "$in_code_fence" -eq 1 ]; then
    continue
  fi

  # Strip single-line HTML comments (<!-- ... --> on one line).
  while printf '%s' "$work" | grep -qE '<!--.*-->'; do
    work="$(printf '%s' "$work" | sed -E 's/<!--[^-]*(-[^-]+)*-->/ /')"
  done

  # Detect a comment opener that does not close on the same line.
  if printf '%s' "$work" | grep -q -- '<!--'; then
    # Trim everything from the first '<!--' onward; enter multi-line mode.
    work="${work%%<!--*}"
    in_html_comment=1
  fi

  # Strip inline backtick spans. Iterate to handle multiple spans on a line.
  while printf '%s' "$work" | grep -qE '`[^`]*`'; do
    work="$(printf '%s' "$work" | sed -E 's/`[^`]*`/ /')"
  done

  # The remaining `work` is the "plain" part of the line where a close
  # keyword would be active. Search for the close-keyword pattern.
  if printf '%s' "$work" | grep -qiE '(closes|fixes|resolves)[[:space:]]+#[0-9]+'; then
    echo "close-keyword found outside permitted zone at $FILE:$lineno: $line" >&2
    found=1
  fi
done < "$FILE"

if [ "$found" -ne 0 ]; then
  exit 1
fi

if [ "$VERBOSE" -eq 1 ]; then
  echo "OK: no raw close-keyword in $FILE"
fi
exit 0
