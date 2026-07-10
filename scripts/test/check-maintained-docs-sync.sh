#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/test/check-maintained-docs-sync.sh
#
# RED harness for issue #685 — AC3/C-5/B-6: docs/maintained-docs.md sync.
#
# Assertions:
#   (R) Retired registry rows are removed or marked historical:
#       - "Tenant Data Convergence Migration" row (the migrate tooling row)
#       - "Per-Client Onboarding Template" row (now landing-only)
#       - "Per-Client Instance — jeungpyeong" row (per-client scope retired)
#       The per-client RS0 portion of MongoDB Replica-Set Transition row is
#       managed as part of the Tenant Data Convergence row check.
#   (P) Dangling-path guard: every explicit file path still listed in
#       maintained-docs.md actually exists on disk (test -e).
#       This is the non-vacuous oracle: the L102 row enumerates ~10 paths
#       that B-6 deletes; after deletion those paths must also leave the table.
#
# [MUST] Does NOT assert ADR-0007 presence (design §9 item 3 — selective
#        registration convention; ADR-0007 is tracked in docs/adr/README.md only).
#
# Convention: set -euo pipefail, PASS/FAIL counter, exit non-zero on any failure.

set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
MAINTAINED="$ROOT/docs/maintained-docs.md"

FAIL_COUNT=0
PASS_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1" >&2; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$MAINTAINED" ]; then
  fail "prerequisite: docs/maintained-docs.md missing"
  printf '\nResults: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT" >&2
  exit 1
fi

# -------------------------------------------------------------------------
# (R) Retired rows must be absent (or at most carry a historical marker)
#
# "Tenant Data Convergence Migration" — currently at L102.
# "Per-Client Onboarding Template"   — currently at L118.
# "Per-Client Instance — jeungpyeong" — currently at L119.
#
# A row is "absent" if it does not appear as a live table row.
# A row is "historical" only if it has been relabelled or moved to a
# clearly marked historical/retired section (accepted GREEN-phase form).
# We fail on any live `| <Name> |` row for the retired entries.
# -------------------------------------------------------------------------

check_retired_row() {
  local LABEL="$1"   # harness label
  local PATTERN="$2" # grep -E pattern to match the table row header cell
  local LIVE_HIT
  LIVE_HIT="$(grep -E "^\|\s*${PATTERN}" "$MAINTAINED" | grep -vE 'historical|retired|~~' || true)"
  if [ -n "$LIVE_HIT" ]; then
    fail "AC3/C-5 [$LABEL] retired row still present as a live entry in maintained-docs.md"
  else
    pass "AC3/C-5 [$LABEL] retired row absent or marked historical in maintained-docs.md"
  fi
}

check_retired_row "Tenant Data Convergence Migration" "Tenant Data Convergence Migration"
check_retired_row "Per-Client Onboarding Template" "Per-Client Onboarding Template"
check_retired_row "Per-Client Instance — jeungpyeong" "Per-Client Instance"

# -------------------------------------------------------------------------
# (P) Dangling-path guard: extract every backtick-quoted relative file path
#     from the maintained-docs table and verify it exists on disk.
#
# Path extraction: matches `path/to/file.ext` forms (not directory/ globs,
# not `*` wildcards — those are glob patterns, not assertable paths).
# Submodule-resident paths (services/... including nested services/librechat/...) are included.
# -------------------------------------------------------------------------

DANGLING_COUNT=0

# Extract backtick-delimited tokens and keep only those that are concrete,
# assertable file paths in the host repo (or submodule).
# Rules for inclusion:
#   1. No wildcard (*) — glob patterns are not assertable
#   2. No spaces — path tokens don't contain spaces
#   3. No leading / — absolute paths (API routes, server paths) are not repo-relative
#   4. No placeholder (<, >) — template variables
#   5. No colons except docker-compose service syntax (but those also have <, > so skip)
#   6. No ./ prefix (relative Docker bind-mounts to server paths)
#   7. No ~/ prefix (home-dir paths)
#   8. Must have a known file extension: .md .sh .js .ts .yml .yaml .json .mjs .cjs
#      OR be a known top-level file without extension (Jenkinsfile, CLAUDE.md handled by .md)
#   9. No GitHub Action ref form (owner/repo without a file extension)
# This conservative set prevents false positives on descriptive prose paths.

while IFS= read -r CANDIDATE; do
  # Rule 1: no wildcards
  printf '%s' "$CANDIDATE" | grep -qF '*' && continue
  # Rule 2: no spaces
  printf '%s' "$CANDIDATE" | grep -qE '[[:space:]]' && continue
  # Rule 3: no leading slash (API routes, absolute server paths)
  printf '%s' "$CANDIDATE" | grep -qE '^/' && continue
  # Rule 4: no placeholders
  printf '%s' "$CANDIDATE" | grep -qE '[<>]' && continue
  # Rule 5: no colons (Docker bind syntax, GitHub Actions, image tags)
  printf '%s' "$CANDIDATE" | grep -qF ':' && continue
  # Rule 5b: no brace expansion (e.g. clients/{_template,jeungpyeong}/...)
  printf '%s' "$CANDIDATE" | grep -qE '[{}]' && continue
  # Rule 5c: skip submodule-relative paths (api/test/..., packages/...) without
  #          the services/ prefix (or services/librechat/ for nested paths) — these are prose short-forms, not
  #          host-repo paths. The submodule-resident file check is the GREEN oracle.
  printf '%s' "$CANDIDATE" | grep -qE '^api/|^packages/' && continue
  # Rule 6: no ./ prefix
  printf '%s' "$CANDIDATE" | grep -qE '^\.' && continue
  # Rule 7: no ~/ prefix
  printf '%s' "$CANDIDATE" | grep -qE '^~' && continue
  # Rule 8: must contain a directory separator (not just a bare filename)
  #          This ensures we only assert full relative paths, not quoted
  #          bare filenames mentioned in prose.
  printf '%s' "$CANDIDATE" | grep -qF '/' || continue
  # Rule 9: must have a known file extension
  printf '%s' "$CANDIDATE" | grep -qE '\.(md|sh|js|ts|yml|yaml|json|mjs|cjs|txt)$' || continue

  FULL="$ROOT/$CANDIDATE"
  if [ -e "$FULL" ]; then
    : # exists
  else
    fail "AC3/C-5 dangling-path guard: '$CANDIDATE' listed in maintained-docs.md but not found on disk"
    DANGLING_COUNT=$((DANGLING_COUNT + 1))
  fi
done < <(grep -oE '`[^`]+`' "$MAINTAINED" | tr -d '`')

if [ "$DANGLING_COUNT" -eq 0 ]; then
  pass "AC3/C-5 dangling-path guard: all explicit file paths in maintained-docs.md exist on disk"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\nResults: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT" >&2
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
