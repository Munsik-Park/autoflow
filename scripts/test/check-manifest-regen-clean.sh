#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-manifest-regen-clean.sh — standing lint: the committed manifest is a
# fixed point of its generator, and every bundled file is registered.
# =============================================================================
# Replaces the retired `955 AC4-CLOSURE` DELTA, which compared the manifest's
# source-row set at the base ref against HEAD and was silenced by a hardcoded
# per-cycle admission list — the widening hand-maintained inventory
# `docs/doc-invariant-registry.md` §1-2 retires by construction. What is
# promotable is the property that needs no inventory at all, and it is the two
# legs below. Each leg has its own label so a failure attributes to a leg.
#
#   FIXED POINT — regenerate setup/manifest.json in a scratch copy of the tree
#     with the REAL setup/gen-manifest-hashes.sh and require the result to be
#     byte-identical to the committed manifest. Fails on: a document entering
#     or leaving the CLAUDE.md + docs/INDEX.md markdown-link closure without
#     regeneration, an emit_row call added or removed without regeneration, and
#     any registered source whose content changed while its recorded hash did
#     not.
#
#   BUNDLE REGISTRATION — every file under setup/thin-root-layer/** appears as
#     an artifacts[].source. That directory's stated purpose is to hold the
#     stamped bundle, so membership in it IS the declaration and needs no
#     second inventory. This is the delivered-but-unregistered case in the one
#     lane where it is decidable; it is deliberately NOT generalised to
#     scripts/handoff/**, scripts/review/** or .claude/workflows/**, which may
#     legitimately hold host-only files and would therefore need an exclusion
#     list — reintroducing the retired shape.
#
# The general root-layer registration gap (a file delivered under a host-only
# directory with no emit_row call written for it) is NOT checked here and
# carries no acceptance criterion: the emit list IS the declaration of what
# ships at that tier, so any checker over the general case must re-declare the
# intended ship set. That is the hand-maintained widening inventory this cycle
# exists to retire, so the gap is retired as not machine-checkable rather than
# routed forward — see docs/doc-invariant-registry.md §5.
#
# Usage:
#   bash scripts/test/check-manifest-regen-clean.sh [--root <dir>]
#
# The lint NEVER writes to the tree it checks: regeneration happens in a scratch
# copy. With no --root it checks the tree it is invoked in when the working
# directory is itself a repository root (so the lint can be driven against a
# scratch worktree by cd-ing into it), otherwise the repository the script
# lives in.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift ;;
    *)      echo "check-manifest-regen-clean: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

is_repo_root() { [ -f "$1/setup/manifest.json" ] && [ -f "$1/setup/gen-manifest-hashes.sh" ]; }

if [ -z "$ROOT" ]; then
  if is_repo_root "$PWD"; then ROOT="$PWD"; else ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"; fi
fi
ROOT="$(cd "$ROOT" && pwd)"

is_repo_root "$ROOT" || {
  echo "check-manifest-regen-clean: $ROOT is not a repository root (setup/manifest.json + setup/gen-manifest-hashes.sh)" >&2
  exit 2
}

RC=0

# ---------------------------------------------------------------------------
# Leg 1 — FIXED POINT
# ---------------------------------------------------------------------------
SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH" 2>/dev/null || true; }
trap cleanup EXIT

# Copy the tree the generator reads. `.git` and the gitignored `.autoflow`
# scratch are excluded — neither is a generator input, and copying `.git` would
# dominate the lint's runtime.
( cd "$ROOT" && tar --exclude='./.git' --exclude='./.autoflow' -cf - . ) \
  | ( cd "$SCRATCH" && tar -xf - ) 2>/dev/null

if ! ( cd "$SCRATCH" && bash setup/gen-manifest-hashes.sh ) >"$SCRATCH/.regen.log" 2>&1; then
  echo "check-manifest-regen-clean: FIXED POINT leg — the generator itself failed in the scratch copy:"
  sed 's/^/    /' "$SCRATCH/.regen.log"
  RC=1
elif ! cmp -s "$ROOT/setup/manifest.json" "$SCRATCH/setup/manifest.json"; then
  echo "check-manifest-regen-clean: FIXED POINT leg FAILED — the committed setup/manifest.json is not a fixed point of setup/gen-manifest-hashes.sh."
  echo "  The markdown-link closure of CLAUDE.md + docs/INDEX.md, the root-layer emit list, or a registered source's content changed without regeneration."
  echo "  Differing rows (source · committed sha256 · regenerated sha256):"
  diff <(jq -r '.artifacts[] | "\(.source)\t\(.sha256 // "null")"' "$ROOT/setup/manifest.json") \
       <(jq -r '.artifacts[] | "\(.source)\t\(.sha256 // "null")"' "$SCRATCH/setup/manifest.json") \
    | sed 's/^/    /' | head -40
  echo "  Fix: run setup/gen-manifest-hashes.sh and stage the regenerated manifest in the same commit."
  RC=1
else
  echo "check-manifest-regen-clean: FIXED POINT leg OK — committed manifest matches the generator's output over the current tree"
fi

# ---------------------------------------------------------------------------
# Leg 2 — BUNDLE REGISTRATION
# ---------------------------------------------------------------------------
BUNDLE_DIR="$ROOT/setup/thin-root-layer"
UNREGISTERED=""
if [ -d "$BUNDLE_DIR" ]; then
  SOURCES="$(jq -r '.artifacts[].source' "$ROOT/setup/manifest.json" 2>/dev/null || true)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$ROOT"/}"
    printf '%s\n' "$SOURCES" | grep -qxF "$rel" || UNREGISTERED="$UNREGISTERED  $rel
"
  done < <(find "$BUNDLE_DIR" -type f | sort)
fi

if [ -n "$UNREGISTERED" ]; then
  echo "check-manifest-regen-clean: BUNDLE REGISTRATION leg FAILED — file(s) under setup/thin-root-layer/ are not registered as an artifacts[].source:"
  printf '%s' "$UNREGISTERED"
  echo "  Membership of that directory is the declaration that a file ships at the bundle tier, so an unregistered member is a delivered-but-unregistered source."
  echo "  Fix: add an emit_row call for it in setup/gen-manifest-hashes.sh and regenerate."
  RC=1
else
  echo "check-manifest-regen-clean: BUNDLE REGISTRATION leg OK — every setup/thin-root-layer/** file is a registered artifacts[].source"
fi

exit $RC
