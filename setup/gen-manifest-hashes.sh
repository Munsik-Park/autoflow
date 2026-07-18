#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# AutoFlow manifest generator / hash-recorder (issue #792 [#785-S5], WI-2 §4.5)
# =============================================================================
# Dev-time helper. Regenerates setup/manifest.json:
#   - version  := plugin/autoflow/.claude-plugin/plugin.json .version (R2 stamp)
#   - artifacts[] := the fixed thin-root/root-layer set PLUS the transitive
#     markdown-link closure of CLAUDE.md + docs/INDEX.md (the Phase Playbook
#     Loading Contract's on-demand Read set — DCR-7 / feature §3.1 O1), each a
#     `copy` row whose dest mirrors the repo-relative layout under
#     .claude/autoflow/.
#   - sha256 := current `shasum -a 256` of each source (null for the manifest
#     self-entry, which cannot hash itself pre-write).
#
# Run this whenever a bundled source artifact changes; verify-install-into-target
# AC2e asserts every copy-row sha256 equals the current source hash.
# =============================================================================

set -euo pipefail

# Pin byte-order collation so manifest row order is a function of the source tree
# alone, not the invoking shell's locale (issue #16 — Derived-artifacts rule).
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

PLUGIN_JSON="plugin/autoflow/.claude-plugin/plugin.json"
OUT="setup/manifest.json"

VERSION="$(jq -r '.version' "$PLUGIN_JSON")"

sha256_of() {
  local h
  h="$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')"
  [ -n "$h" ] || h="$(sha256sum "$1" 2>/dev/null | awk '{print $1}')"
  printf '%s' "$h"
}

# Normalize a path (collapse . and .. segments) — mirrors the test's awk resolver.
norm_path() {
  printf '%s\n' "$1" | awk '{
    n = split($0, a, "/"); j = 0
    for (i = 1; i <= n; i++) {
      if (a[i] == "..") { if (j > 0) j-- }
      else if (a[i] != "." && a[i] != "") { r[++j] = a[i] }
    }
    for (i = 1; i <= j; i++) printf "%s%s", (i>1?"/":""), r[i]
    printf "\n"
  }'
}

# Transitive markdown-link closure from CLAUDE.md + docs/INDEX.md.
# Only files that exist are emitted (broken links are skipped — they are not
# installable sources; the installed tree carries the resolvable closure).
compute_doc_closure() {
  local seen cur nxt f d lnk resolved
  seen="$(mktemp)"; cur="$(mktemp)"; nxt="$(mktemp)"
  printf 'CLAUDE.md\ndocs/INDEX.md\n' | sort -u > "$cur"
  cat "$cur" > "$seen"
  while [ -s "$cur" ]; do
    : > "$nxt"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      d="$(dirname "$f")"
      while IFS= read -r lnk; do
        [ -n "$lnk" ] || continue
        if [ "$d" = "." ]; then resolved="$(norm_path "$lnk")"
        else resolved="$(norm_path "$d/$lnk")"; fi
        if ! grep -qxF "$resolved" "$seen"; then
          echo "$resolved" >> "$seen"
          echo "$resolved" >> "$nxt"
        fi
      done <<EOF
$(grep -oE '\]\([^)#:]+\.md\)' "$f" | sed -e 's/^](//' -e 's/)$//')
EOF
    done < "$cur"
    cp "$nxt" "$cur"
  done
  # Emit existing files only, sorted.
  sort "$seen" | while IFS= read -r f; do
    [ -f "$f" ] && echo "$f"
  done
  rm -f "$seen" "$cur" "$nxt"
}

# Accumulate artifact rows as JSON objects on stdout of build_rows.
emit_row() {  # source dest tier kind hashmode
  local src="$1" dest="$2" tier="$3" kind="$4" hashmode="$5" sha
  if [ "$hashmode" = "null" ]; then
    jq -n --arg s "$src" --arg d "$dest" --arg t "$tier" --arg k "$kind" \
      '{source:$s, dest:$d, tier:$t, kind:$k, sha256:null}'
  else
    sha="$(sha256_of "$src")"
    jq -n --arg s "$src" --arg d "$dest" --arg t "$tier" --arg k "$kind" --arg h "$sha" \
      '{source:$s, dest:$d, tier:$t, kind:$k, sha256:$h}'
  fi
}

build_rows() {
  # Reference tier: methodology entrypoint + framework prose closure.
  emit_row "setup/thin-root-layer/methodology/METHODOLOGY.md" \
           ".claude/autoflow/METHODOLOGY.md" "reference" "copy" "file"
  compute_doc_closure | while IFS= read -r f; do
    if [ "$f" = "CLAUDE.md" ]; then
      emit_row "CLAUDE.md" ".claude/autoflow/CLAUDE.md" "reference" "copy" "file"
    else
      emit_row "$f" ".claude/autoflow/$f" "reference" "copy" "file"
    fi
  done

  # Root-layer tier: deliberation workflows.
  emit_row ".claude/workflows/architect-deliberation.js" \
           ".claude/workflows/architect-deliberation.js" "root-layer" "copy" "file"
  emit_row ".claude/workflows/verify-cause-branch.js" \
           ".claude/workflows/verify-cause-branch.js" "root-layer" "copy" "file"

  # Root-layer tier: drift detector + canonical drift-reference copies.
  emit_row "setup/thin-root-layer/drift-check.sh" \
           ".claude/autoflow/drift-check.sh" "root-layer" "copy" "file"
  emit_row "setup/thin-root-layer/claude-md-shim.md" \
           ".claude/autoflow/claude-md-shim.md" "root-layer" "copy" "file"
  emit_row "setup/thin-root-layer/settings-pin.json" \
           ".claude/autoflow/settings-pin.json" "root-layer" "copy" "file"

  # Root-layer tier: stamp / merge / scaffold operations.
  emit_row "setup/thin-root-layer/claude-md-shim.md" \
           "CLAUDE.md" "root-layer" "shim-stamp" "file"
  emit_row "setup/thin-root-layer/settings-pin.json" \
           ".claude/settings.json" "root-layer" "json-merge" "file"
  emit_row "CLAUDE.local.md.example" \
           "CLAUDE.local.md" "root-layer" "scaffold" "file"

  # Root-layer tier: reviewer-backend delivery (issue #979) — the HANDOFF
  # step-6 wrapper, the PREFLIGHT fail-closed availability check, and the shared
  # review-instruction body ship as source-path-preserved copies; AGENTS.md and
  # the backend-selection scaffold ship as target-owned scaffolds (never
  # overwritten). docs/reviewer-backend.md enters via the doc-closure BFS above.
  emit_row "scripts/review/codex-review-pr.sh" \
           "scripts/review/codex-review-pr.sh" "root-layer" "copy" "file"
  # Shared claude-isolation helper (issue #979 cycle 9 §3.2): sourced by BOTH
  # codex-review-pr.sh and check-review-backend.sh --probe, so it MUST ship to
  # targets alongside them (a missing sibling breaks the source line).
  emit_row "scripts/review/lib/claude-isolation.sh" \
           "scripts/review/lib/claude-isolation.sh" "root-layer" "copy" "file"
  emit_row "scripts/preflight/check-review-backend.sh" \
           "scripts/preflight/check-review-backend.sh" "root-layer" "copy" "file"
  emit_row ".codex/review.md" \
           ".codex/review.md" "root-layer" "copy" "file"
  emit_row "AGENTS.md" \
           "AGENTS.md" "root-layer" "scaffold" "file"
  emit_row ".claude/autoflow.local.json" \
           ".claude/autoflow.local.json" "root-layer" "scaffold" "file"

  # Root-layer tier: methodology-step scripts (issue #10). Four scripts the
  # stamped docs (autoflow-guide.md PREFLIGHT 1.5 / HANDOFF 4·6.7,
  # git-workflow.md Post-Merge Cleanup) instruct a consumer to run but which
  # 0.1.0 never registered, so install_into_target never delivered them.
  # Source-path-preserved copies (identity dest), same shape as the reviewer-
  # backend script rows above; none source a sibling lib (no extra rows).
  emit_row "scripts/preflight/scan-cross-issue-recurrence.sh" \
           "scripts/preflight/scan-cross-issue-recurrence.sh" "root-layer" "copy" "file"
  emit_row "scripts/handoff/emit-cycle-digest.sh" \
           "scripts/handoff/emit-cycle-digest.sh" "root-layer" "copy" "file"
  emit_row "scripts/handoff/create-host-pr.sh" \
           "scripts/handoff/create-host-pr.sh" "root-layer" "copy" "file"
  emit_row "scripts/handoff/confirm-ci-green.sh" \
           "scripts/handoff/confirm-ci-green.sh" "root-layer" "copy" "file"
  emit_row "scripts/cleanup/cleanup-issue.sh" \
           "scripts/cleanup/cleanup-issue.sh" "root-layer" "copy" "file"

  # Manifest self-entry (copied last; cannot hash itself pre-write).
  emit_row "setup/manifest.json" \
           ".claude/autoflow/manifest.json" "root-layer" "copy" "null"
}

ROWS="$(build_rows | jq -s '.')"

jq -n --arg v "$VERSION" --argjson a "$ROWS" \
  '{version:$v, artifacts:$a}' > "$OUT"

echo "Wrote $OUT (version $VERSION, $(printf '%s' "$ROWS" | jq 'length') artifacts)"
