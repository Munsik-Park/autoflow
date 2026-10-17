#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# gen-skill-bodies.sh — generate the AutoFlow command bodies from the core
# (issue #454, ADR-0027 D2)
# =============================================================================
# Dev-time generator. The rules reach a main session through the body of the
# command that starts it, and both command bodies are generated from one source,
# docs/core.md:
#
#   skills/cycle/SKILL.md            /autoflow:cycle <N> [unit=U1…U6] — the
#                                    command header, then the whole core in its
#                                    own order (the leading part, up to the
#                                    `core:leading-end` marker, first)
#   skills/criterion-review/SKILL.md /autoflow:criterion-review <N> — the
#                                    command header, then the core sections the
#                                    criterion review is bound by
#
# The core's markdown links are reduced to their text in a body: a link is
# relative to docs/, while a body sits under skills/<name>/, and every AutoFlow
# path a link names is already written as `<autoflow-root>/…` in its text.
#
# The plugin installs without a build step, so the generated bodies are
# committed; tests/plugin/verify-skill-bodies.sh runs `--check` (regen-clean),
# the leading-part budget and the `<autoflow-root>/…` path closure.
#
#   gen-skill-bodies.sh            write both bodies
#   gen-skill-bodies.sh --check    exit 0 when the committed bodies equal the
#                                  generator's output, 1 (naming each body that
#                                  differs) otherwise
# Pure bash + awk + sed; BSD and GNU tools alike.
# =============================================================================

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE="$ROOT/docs/core.md"
MARKER='<!-- core:leading-end'

MODE=write
case "${1:-}" in
  "") ;;
  --check) MODE=check ;;
  *) echo "usage: gen-skill-bodies.sh [--check]" >&2; exit 2 ;;
esac
[ -f "$CORE" ] || { echo "gen-skill-bodies: $CORE not found" >&2; exit 2; }

# strip_links — a markdown link becomes its text.
strip_links() { sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g'; }

# core_body — the core from its first `## ` heading to the end.
core_body() { awk 'f || /^## / { f = 1; print }' "$CORE"; }

# section <heading> — one `## ` section of the leading part, heading included,
# without its trailing blank lines; empty when the heading is absent.
section() {
  awk -v h="$1" -v m="$MARKER" '
    $0 == h { on = 1; print; next }
    on && (/^## / || index($0, m) == 1) { exit }
    on { print }' "$CORE" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# bullet <prefix> — the one-line bullet of the core that starts with <prefix>.
bullet() { awk -v p="$1" 'index($0, p) == 1 { print; exit }' "$CORE"; }

# need <what> <text> — fail when an extraction came back empty (a renamed
# heading or bullet in the core must break generation, not drop a rule).
need() { [ -n "$2" ] || { echo "gen-skill-bodies: docs/core.md has no $1" >&2; exit 1; }; }

ROOT_DECL='AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.autoflow/…`, `.claude/autoflow.local.json`, the target'"'"'s own files) is the target'"'"'s. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.'
GEN_NOTE='<!-- Generated from docs/core.md by scripts/skills/gen-skill-bodies.sh — edit the core, then regenerate. -->'

gen_cycle() {
  cat <<'EOF'
---
name: cycle
description: >-
  Run an AutoFlow cycle on an issue — PREFLIGHT to HANDOFF, or one functional
  unit with unit=U1…U6. Use only when the operator starts or resumes an
  AutoFlow cycle (/autoflow:cycle <N> [unit=Uk]), and again after a compaction.
argument-hint: "<issue-number> [unit=U1…U6]"
---

**After a compaction** — if this conversation was compacted after this command was invoked, invoke `/autoflow:cycle $ARGUMENTS` again, with the same arguments, before any other action, then re-read the current unit's document.

EOF
  printf '%s\n\n' "$ROOT_DECL"
  cat <<'EOF'
**Scope** (`$ARGUMENTS`): `<N>` alone runs issue #N's cycle, PREFLIGHT to HANDOFF. `<N> unit=Uk` runs unit Uk only: confirm from `bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue <N>` that the cycle stands at Uk's entry (otherwise report the situation and stop), run Uk from its entry to its exit transition, and end the session with the report the invoking prompt asks for.

EOF
  core_body | strip_links
  printf '\n%s\n' "$GEN_NOTE"
}

gen_criterion_review() {
  local conv rule spawn ledger hdp wrapper cross conc
  conv="$(section '## Instruction Conventions')";                         need 'Instruction Conventions section' "$conv"
  rule="$(section '## Rule Scope — Authority Rules and AI Judgment')";    need 'Rule Scope section' "$rule"
  spawn="$(section '## Spawn Model — Phase-by-Phase')";                    need 'Spawn Model section' "$spawn"
  ledger="$(section '## Decision Ledger')";                               need 'Decision Ledger section' "$ledger"
  hdp="$(bullet '- **[MUST] Human-decision presentation**')";             need 'Human-decision presentation bullet' "$hdp"
  wrapper="$(bullet '- **[MUST] File every issue through the wrapper**')"; need 'issue-wrapper bullet' "$wrapper"
  cross="$(bullet '- **[MUST] Check cross-issue consistency')";           need 'cross-issue bullet' "$cross"
  conc="$(bullet '- **Concurrent spawns**')";                             need 'Concurrent spawns bullet' "$conc"
  cat <<'EOF'
---
name: criterion-review
description: >-
  Review an issue's acceptance criteria against the target's code and policy,
  outside any AutoFlow cycle, before its first new-issue cycle. Use only when
  the operator asks for the criterion review (/autoflow:criterion-review <N>).
argument-hint: "<issue-number>"
---

EOF
  printf '%s\n\n' "$ROOT_DECL"
  cat <<'EOF'
**Scope** — the criterion review of issue `$ARGUMENTS`, outside any cycle. Read `<autoflow-root>/docs/criterion-review.md` now and follow it; the rules below, from `<autoflow-root>/docs/core.md`, bind the session while it does.

EOF
  {
    printf '%s\n\n' "$conv" "$rule" "$spawn" "$ledger"
    printf '## Execution Principles\n\n%s\n%s\n%s\n\n' "$hdp" "$wrapper" "$cross"
    printf '## Cost Control\n\n%s\n' "$conc"
  } | strip_links
  printf '\n%s\n' "$GEN_NOTE"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/cycle" "$TMP/criterion-review"
gen_cycle > "$TMP/cycle/SKILL.md"
gen_criterion_review > "$TMP/criterion-review/SKILL.md"

rc=0
for _s in cycle criterion-review; do
  _dst="$ROOT/skills/$_s/SKILL.md"
  if [ "$MODE" = check ]; then
    if ! cmp -s "$TMP/$_s/SKILL.md" "$_dst"; then
      echo "gen-skill-bodies: skills/$_s/SKILL.md differs from the generator's output — run: bash scripts/skills/gen-skill-bodies.sh" >&2
      rc=1
    fi
  else
    mkdir -p "$(dirname "$_dst")"
    cp "$TMP/$_s/SKILL.md" "$_dst"
  fi
done
[ "$MODE" = check ] && [ "$rc" -eq 0 ] && echo "gen-skill-bodies: OK — skills/cycle and skills/criterion-review equal the generator's output"
exit "$rc"
