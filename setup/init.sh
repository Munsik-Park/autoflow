#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# AutoFlow Template — Consumed-tool Installer
# =============================================================================
# `setup/init.sh --target <path> [--force]` installs the AutoFlow bundle into an
# external target project root, driven by the machine-readable manifest
# (setup/manifest.json). Install-into-TARGET is the only supported mode; the
# legacy in-place placeholder-substitution wizard was removed (issue #952 — its
# .template sources were deleted, making it a permanent no-op).
#
# Usage:
#   setup/init.sh --target /path/to/your-project [--force]
#
# See setup/SETUP-GUIDE.md for details.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# =============================================================================
# Install-into-TARGET mode (issue #792 [#785-S5], WI-1)
# =============================================================================
# `setup/init.sh --target <path> [--force]` copies the AutoFlow thin-root /
# reference bundle into an external target project root, driven by the
# machine-readable manifest (setup/manifest.json), and ships the drift detector
# with it.

INSTALL_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_PROJECT_ROOT="$(cd "$INSTALL_SCRIPT_DIR/.." && pwd)"

# stamp_shim <target> <shim-src> — idempotent managed-block stamp (R2 marker).
# BEGIN present ⇒ replace the enclosed region; absent ⇒ append the block.
# Target prose outside the AUTOFLOW-IMPORT fence is never touched.
stamp_shim() {
  local target="$1" shim="$2"
  local claude="$target/CLAUDE.md"
  [ -f "$claude" ] || : > "$claude"
  if grep -qF 'AUTOFLOW-IMPORT:BEGIN' "$claude"; then
    awk -v shimfile="$shim" '
      BEGIN { while ((getline _l < shimfile) > 0) _shim = _shim _l "\n" }
      /AUTOFLOW-IMPORT:BEGIN/ { printf "%s", _shim; _inblk = 1; next }
      /AUTOFLOW-IMPORT:END/   { _inblk = 0; next }
      !_inblk { print }
    ' "$claude" > "$claude.tmp" && mv "$claude.tmp" "$claude"
  else
    printf '\n' >> "$claude"
    cat "$shim" >> "$claude"
  fi
}

# merge_settings <target> <pin-src> <dest-rel> — jq deep-merge (R1 pin delivery).
# Recursive object merge preserves the target's pre-existing keys; the pin's
# marketplace + enabledPlugins keys are added.
merge_settings() {
  local target="$1" pin="$2" dest="$3"
  local settings="$target/$dest"
  mkdir -p "$(dirname "$settings")"
  [ -f "$settings" ] || echo '{}' > "$settings"
  jq -s '.[0] * .[1]' "$settings" "$pin" > "$settings.tmp" && mv "$settings.tmp" "$settings"
}

# install_into_target <target> — apply every manifest artifact by kind.
install_into_target() {
  local target="$1"
  [ -d "$target" ] || error "Target is not an existing directory: $target"
  command -v jq >/dev/null 2>&1 || error "jq is required for install-into-TARGET mode"
  local src="$INSTALL_PROJECT_ROOT"
  local manifest="$src/setup/manifest.json"
  [ -f "$manifest" ] || error "Manifest not found: $manifest"

  local n i source dest kind
  n="$(jq -r '.artifacts | length' "$manifest")"
  i=0
  while [ "$i" -lt "$n" ]; do
    source="$(jq -r ".artifacts[$i].source" "$manifest")"
    dest="$(jq -r ".artifacts[$i].dest" "$manifest")"
    kind="$(jq -r ".artifacts[$i].kind" "$manifest")"
    case "$kind" in
      copy)
        mkdir -p "$(dirname "$target/$dest")"
        cp "$src/$source" "$target/$dest"
        ;;
      shim-stamp)
        stamp_shim "$target" "$src/$source"
        ;;
      json-merge)
        merge_settings "$target" "$src/$source" "$dest"
        ;;
      scaffold)
        # R3: target-authored file — scaffold only when absent, never overwrite
        # (even under --force).
        mkdir -p "$(dirname "$target/$dest")"
        [ -e "$target/$dest" ] || cp "$src/$source" "$target/$dest"
        ;;
      *)
        error "Unknown artifact kind '$kind' for $dest"
        ;;
    esac
    i=$((i + 1))
  done

  success "AutoFlow bundle installed into: $target"
  echo ""
  echo "Next steps:"
  echo "  1. Install the plugin in this target:"
  echo "       /plugin marketplace add Munsik-Park/autoflow"
  echo "       /plugin install autoflow@autoflow"
  echo "  2. Self-verify the install:"
  echo "       sh .claude/autoflow/drift-check.sh"
  echo "  3. Fill in target identity in CLAUDE.local.md (never overwritten)."
  echo "  4. Reviewer backend (HANDOFF step-6 review) defaults to codex in"
  echo "       .claude/autoflow.local.json; switch to claude there if preferred"
  echo "       (see docs/reviewer-backend.md). PREFLIGHT fail-closes if the"
  echo "       configured backend's CLI is absent."
}

# Dispatch: --target selects install mode; otherwise print usage and exit 1.
# --force is accepted for CLI stability; install is unconditionally idempotent.
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --force)  shift ;;
    *) error "Unknown argument: $1" ;;
  esac
done

if [ -n "$TARGET" ]; then
  install_into_target "$TARGET"
  exit $?
fi

# No --target: the interactive in-place model was removed (issue #952 — its
# .template sources were deleted, making it a permanent no-op).
error "Usage: setup/init.sh --target <path> [--force]
Install-into-TARGET is the only supported mode (see setup/SETUP-GUIDE.md)."
