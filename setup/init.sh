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
# A re-stamp also RECONCILES the target against the manifest it previously
# installed (issue #236; docs/tool-delivery-contract.md > R4): an artifact the
# previous installed manifest lists and the new manifest does not is removed
# when — and only when — AutoFlow still owns it (kind `copy`, on-disk sha256
# equal to the previous manifest's). Every other case is kept and named with
# its reason. No previous manifest, or one that cannot be read, removes nothing.
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

# sha256_of <file> — portable sha256 (shasum on macOS, sha256sum on Linux).
sha256_of() {
  local h
  h="$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')"
  [ -n "$h" ] || h="$(sha256sum "$1" 2>/dev/null | awk '{print $1}')"
  printf '%s' "$h"
}

# dest_escapes_target <target> <dest> — true when any path component of
# <dest> under <target> is a symlink, or the parent directory's physical path
# is not inside the target's physical path (PR #237 review, High). The
# previous manifest is target-controlled input and so is the tree under it:
# `target/retired-dir -> ../outside` plus a previous-only `copy` row naming
# `retired-dir/retired.sh` with the outside file's hash would otherwise be
# followed by the hash check and the `rm`. Every component is checked, not
# only the leaf, and a symlink that resolves inside the target is refused
# too — the removal rule is "the file AutoFlow wrote at this dest", and a
# link is not that. A missing parent is not an escape (the file is absent).
dest_escapes_target() {
  local target="$1" dest="$2" acc="$target" rest="$dest" comp real_target real_parent
  while [ -n "$rest" ]; do
    comp="${rest%%/*}"
    if [ "$comp" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    [ -n "$comp" ] || continue
    acc="$acc/$comp"
    [ -L "$acc" ] && return 0
  done
  [ -d "$(dirname "$target/$dest")" ] || return 1
  real_target="$(cd -P -- "$target" 2>/dev/null && pwd -P)" || return 0
  real_parent="$(cd -P -- "$(dirname "$target/$dest")" 2>/dev/null && pwd -P)" || return 0
  case "$real_parent/" in
    "$real_target/"*) return 1 ;;
    *) return 0 ;;
  esac
}

# reconcile_removed <target> <prev-manifest> <new-manifest> — remove what the
# previous installed manifest lists and the new one does not (issue #236).
#
# Removal contract (R4): a candidate is a `dest` present in the previous
# installed manifest only. It is REMOVED only when AutoFlow still owns it —
# kind `copy` and the on-disk sha256 equals the previous manifest's recorded
# value. Everything else is KEPT and reported with its reason: a `copy` whose
# hash differs (target-modified), a `copy` with no recorded hash, a dest with a
# symlink on its path or a parent outside the target, an unsafe dest (absolute
# or `..`), and every `scaffold` / `shim-stamp` /
# `json-merge` row (target-owned or merged into a target file — never removed).
# A candidate already absent from disk is reported as ABSENT. Directories are
# never removed. The previous manifest is target-controlled input: its `dest`
# values are validated before any path under the target is touched.
#
# Output is one line per candidate, `REMOVED:` / `KEPT:` / `ABSENT:` followed by
# the dest and a parenthesised reason — the install skill reports these lines
# dest by dest, and the commit stays the operator's.
reconcile_removed() {
  local target="$1" prev="$2" new="$3"
  local pver nver rel n i dest kind psha dsha
  pver="$(jq -r '.version // "unknown"' "$prev")"
  nver="$(jq -r '.version // "unknown"' "$new")"
  rel="$(mktemp)"
  # One relation keyed by dest: rows the previous manifest lists and the new
  # manifest does not, with the previous row's kind and recorded sha256.
  if ! jq -n -r --slurpfile p "$prev" --slurpfile u "$new" '
      ($u[0].artifacts | map(.dest) | map({key: ., value: true}) | from_entries) as $keep
      | $p[0].artifacts[]
      | select($keep[.dest] == null)
      | [.dest, (.kind // "unknown"), (.sha256 // "null")] | @tsv' > "$rel" 2>/dev/null; then
    rm -f "$rel"
    warn "Previous installed manifest ($pver) could not be compared against $nver — nothing removed; compare the two by hand"
    return 0
  fi
  if [ ! -s "$rel" ]; then
    rm -f "$rel"
    success "No artifact left behind by the previous installed manifest ($pver -> $nver)"
    return 0
  fi
  info "Reconciling artifacts the previous installed manifest ($pver) lists and $nver does not:"
  local removed=0 kept=0 absent=0
  while IFS="$(printf '\t')" read -r dest kind psha; do
    [ -n "$dest" ] || continue
    case "$dest" in
      /*|*/../*|../*|*/..|..)
        echo "KEPT: $dest ($kind; unsafe dest in the previous manifest — not touched)"
        kept=$((kept + 1)); continue ;;
    esac
    if [ "$kind" != copy ]; then
      echo "KEPT: $dest ($kind; target-owned or merged into a target file — a re-stamp never removes a $kind artifact; dispose of it by hand)"
      kept=$((kept + 1)); continue
    fi
    if dest_escapes_target "$target" "$dest"; then
      echo "KEPT: $dest (copy; a symlink on the path or a parent outside the target — not the file AutoFlow wrote; dispose of it by hand)"
      kept=$((kept + 1)); continue
    fi
    if [ ! -e "$target/$dest" ]; then
      echo "ABSENT: $dest (copy; already absent — nothing to remove)"
      absent=$((absent + 1)); continue
    fi
    if [ ! -f "$target/$dest" ]; then
      echo "KEPT: $dest (copy; not a regular file on disk — dispose of it by hand)"
      kept=$((kept + 1)); continue
    fi
    if [ "$psha" = null ] || [ -z "$psha" ]; then
      echo "KEPT: $dest (copy; the previous manifest records no sha256, so ownership cannot be confirmed — dispose of it by hand)"
      kept=$((kept + 1)); continue
    fi
    dsha="$(sha256_of "$target/$dest")"
    if [ "$dsha" = "$psha" ]; then
      rm -f "$target/$dest"
      echo "REMOVED: $dest (copy; sha256 matched the previous manifest — no longer shipped by $nver)"
      removed=$((removed + 1))
    else
      echo "KEPT: $dest (copy; sha256 differs from the previous manifest — target-modified; dispose of it by hand)"
      kept=$((kept + 1))
    fi
  done < "$rel"
  rm -f "$rel"
  success "Reconciled against the previous installed manifest: $removed removed, $kept kept, $absent already absent"
}

# install_into_target <target> — apply every manifest artifact by kind, then
# reconcile what the previous installed manifest delivered and this one drops.
install_into_target() {
  local target="$1"
  [ -d "$target" ] || error "Target is not an existing directory: $target"
  command -v jq >/dev/null 2>&1 || error "jq is required for install-into-TARGET mode"
  local src="$INSTALL_PROJECT_ROOT"
  local manifest="$src/setup/manifest.json"
  [ -f "$manifest" ] || error "Manifest not found: $manifest"

  # Snapshot the manifest this target installed last, before the `copy` loop
  # below overwrites it (issue #236). Absent → first stamp, nothing to
  # reconcile. Present but unreadable → nothing removed, the operator is told.
  local prev_installed="$target/.claude/autoflow/manifest.json" prev_state=absent prev_snapshot=""
  if [ -e "$prev_installed" ]; then
    prev_snapshot="$(mktemp)"
    if cp "$prev_installed" "$prev_snapshot" 2>/dev/null \
       && jq -e '(.version | type) == "string" and (.artifacts | type) == "array"' "$prev_snapshot" >/dev/null 2>&1; then
      prev_state=readable
    else
      prev_state=unreadable
    fi
  fi

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

  case "$prev_state" in
    absent)
      info "No previous installed manifest at $prev_installed — nothing to reconcile (first stamp)"
      ;;
    unreadable)
      warn "Previous installed manifest at $prev_installed could not be read (invalid JSON, or no string version / artifacts array) — nothing removed; artifacts it delivered that $(jq -r '.version' "$manifest") no longer ships must be compared by hand"
      ;;
    readable)
      reconcile_removed "$target" "$prev_snapshot" "$manifest"
      ;;
  esac
  [ -n "$prev_snapshot" ] && rm -f "$prev_snapshot"

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
  echo "  5. Optionally pin the reviewer's model/effort per backend there"
  echo "       (.review.codex / .review.claude -> {model, effort}); absent keys"
  echo "       inherit the CLI's own defaults. Verify with"
  echo "       scripts/preflight/check-review-backend.sh --probe."
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
