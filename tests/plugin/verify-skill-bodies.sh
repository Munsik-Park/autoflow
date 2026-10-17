#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: the command bodies and the AutoFlow path notation (issue #454 PR-3)
# =============================================================================
# The rules reach a main session through the bodies of /autoflow:cycle and
# /autoflow:criterion-review, generated from docs/core.md (ADR-0027 D2), and an
# AutoFlow path is written `<autoflow-root>/…` wherever a role reads it
# (ADR-0027 D3). Plain bash + awk/sed/grep/cmp (no bats, no node/npm).
#
# Legs (category: packaging):
#
#   G   regen-clean
#     G1  the committed bodies equal scripts/skills/gen-skill-bodies.sh output
#     G2  a body edited by hand is caught (--check exits 1 on a scratch copy)
#
#   B   body budget and order
#     B1  /autoflow:cycle: the first body line is the re-invocation rule, and
#         the leading part (after the frontmatter, up to the core's
#         `core:leading-end` marker) is at most 18,000 bytes — the 5,000-token
#         compaction re-attach cap
#     B2  /autoflow:criterion-review: the whole body is at most 18,000 bytes
#     B3  both bodies and every agent definition declare the root through
#         ${CLAUDE_PLUGIN_ROOT}
#
#   C   path closure
#     C1  every `<autoflow-root>/…` in the usage documents, the agent
#         definitions and the command bodies resolves under the repository
#         root (placeholders `<x>`, `{x}` and `…` match any name)
#     C2  no AutoFlow path is left as a bare code-span (or a bare command in a
#         fenced block): `docs/`, `scripts/`, `setup/`, `bin/`, `.codex/`,
#         `.claude/agents/`, `.claude/hooks/`; the allow-list below names the
#         spans that are a target's paths or not paths at all
#     C3  non-vacuity: a scratch document with a bare path and an unresolvable
#         `<autoflow-root>/…` path is flagged by both legs
#
# Scope: docs/**/*.md except docs/records/ (records are read, not rewritten —
# docs/development-guideline.md), agents/*.md, skills/cycle/SKILL.md and
# skills/criterion-review/SKILL.md.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GEN="$REPO_ROOT/scripts/skills/gen-skill-bodies.sh"
BUDGET=18000

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A target's path, or a span that is not a path, written bare on purpose:
# "<file>|<span>". A target's path names the repository under change — when
# the target is this repository, its working tree, not the plugin root: the
# host repository's own scope (the core's Cross-Project Boundary Rules, carried
# into the cycle body generated from it), the target's decision records and
# ADR directory, the rule documents a change to this repository edits, and
# this repository's own security checklist items.
ALLOW_SPANS='docs/core.md|scripts/
docs/core.md|docs/
skills/cycle/SKILL.md|scripts/
skills/cycle/SKILL.md|docs/
docs/units/build.md|scripts/
docs/git-workflow.md|docs/<issue>-<desc>
docs/development-guideline.md|docs/
docs/development-guideline.md|docs/records/
docs/development-guideline.md|.codex/
docs/development-guideline.md|scripts/test/check-host-purity-delta.sh
docs/evaluation-system.md|docs/records/adr/
docs/submodule-common-rules.md|docs/records/adr/
docs/submodule-common-rules.md|docs/records/design-rationale.md
docs/units/design.md|docs/records/adr/*
docs/units/design.md|docs/records/design-rationale.md
docs/security-checklist.md|scripts/gate/security-checklist.sh'
# Fenced-block tokens likewise: "<file>|<token>" — a branch name, and the
# paths of a target's pull-request body in the guide's examples.
ALLOW_FENCE='docs/git-workflow.md|docs/55-update-api-reference
docs/pr-body-guide.md|scripts/test/check-suite-manifest.sh
docs/pr-body-guide.md|docs/retry.md'

# body_after_frontmatter <file> — the lines after the closing frontmatter ---.
body_after_frontmatter() { awk 'n < 2 && /^---$/ { n++; next } n >= 2' "$1"; }

# scope_files <root> — the documents C1/C2 read, relative to <root>.
scope_files() {
  ( cd "$1" && {
      find docs -name '*.md' -not -path 'docs/records/*' | LC_ALL=C sort
      ls agents/*.md 2>/dev/null
      for _s in skills/cycle/SKILL.md skills/criterion-review/SKILL.md; do [ -f "$_s" ] && echo "$_s"; done
    } )
}

# bare_paths <root> <file> — "<file>|<line>|<span>" for every bare AutoFlow
# path in a code span or a fenced block (multi-line spans included).
bare_paths() {
  awk -v F="$2" '
    function bare(s) {
      sub(/^(bash|sh)[ \t]+/, "", s)
      return (s ~ /^(docs|scripts|setup|bin|\.codex)\// || s ~ /^\.claude\/(agents|hooks)(\/|$)/)
    }
    /^[ \t]*```/ { fence = !fence; inspan = 0; next }
    fence {
      line = $0
      while (match(line, /(^|[ \t"'\''(=`])((bash|sh)[ \t]+)?(docs|scripts|setup|bin)\/[^ \t"'\''`)]*/)) {
        tok = substr(line, RSTART, RLENGTH); sub(/^[ \t"'\''(=`]/, "", tok)
        sub(/^(bash|sh)[ \t]+/, "", tok)
        print F "|" NR "|" tok
        line = substr(line, RSTART + RLENGTH)
      }
      if (match($0, /(^|[ \t(])\.codex\/review\.md/) && $0 !~ /<autoflow-root>\/\.codex\/review\.md/) print F "|" NR "|.codex/review.md"
      next
    }
    {
      n = split($0, seg, "`")
      for (i = 1; i <= n; i++) {
        if (inspan) {
          span = (cont != "" ? cont " " : "") seg[i]
          if (i < n) { if (bare(span)) print F "|" NR "|" span; cont = ""; inspan = 0 }
          else cont = span
        } else if (i < n) { inspan = 1; cont = "" }
      }
    }' "$1/$2"
}

# allowed <file> <span> <list>
allowed() { printf '%s\n' "$3" | grep -qxF "$1|$2"; }

# unresolved_roots <root> <file> — every `<autoflow-root>/…` path in <file>
# that matches nothing under <root>.
unresolved_roots() {
  grep -oE '<autoflow-root>/[^] `'"'"'"),;|]*' "$1/$2" | sed -e 's|^<autoflow-root>/||' -e 's|[.:]*$||' | sort -u \
    | while IFS= read -r _p; do
        [ -n "$_p" ] || continue
        _g=$(printf '%s' "$_p" | sed -E -e 's/<[^>]*>/*/g' -e 's/\{[^}]*\}/*/g' -e 's/…/*/g' -e 's/\*+/*/g')
        _g=${_g%/}
        # shellcheck disable=SC2086
        if ! compgen -G "$1/$_g" >/dev/null; then printf '%s|%s\n' "$2" "$_p"; fi
      done
}

# ── G: regen-clean ───────────────────────────────────────────────────────────
echo "== G: the committed bodies equal the generator's output =="
if out=$(bash "$GEN" --check 2>&1); then
  pass "G1: $out"
else
  failc "G1" "$out"
fi

SCR="$WORK/regen"
mkdir -p "$SCR/scripts/skills" "$SCR/docs" "$SCR/skills"
cp "$GEN" "$SCR/scripts/skills/"
cp "$REPO_ROOT/docs/core.md" "$SCR/docs/core.md"
cp -R "$REPO_ROOT/skills/cycle" "$REPO_ROOT/skills/criterion-review" "$SCR/skills/"
printf 'hand edit\n' >> "$SCR/skills/cycle/SKILL.md"
if bash "$SCR/scripts/skills/gen-skill-bodies.sh" --check >/dev/null 2>"$WORK/g2.err"; then
  failc "G2" "--check accepted a hand-edited body"
elif grep -q 'skills/cycle/SKILL.md differs' "$WORK/g2.err"; then
  pass "G2: a hand-edited body is caught (--check exit 1, naming skills/cycle/SKILL.md)"
else
  failc "G2" "unexpected diagnostic: $(head -c 300 "$WORK/g2.err")"
fi

# ── B: body budget and order ─────────────────────────────────────────────────
echo "== B: body budget and order =="
CYCLE="$REPO_ROOT/skills/cycle/SKILL.md"
CRIT="$REPO_ROOT/skills/criterion-review/SKILL.md"
if [ -f "$CYCLE" ]; then
  first=$(body_after_frontmatter "$CYCLE" | grep -m1 -v '^[[:space:]]*$')
  # Read to end of input rather than exit at the marker: an early exit closes
  # the pipe on the upstream awk, whose SIGPIPE fails the pipeline under pipefail.
  lead=$(body_after_frontmatter "$CYCLE" | awk '/^<!-- core:leading-end/ { found = 1 } !found { print } END { if (!found) exit 3 }')
  lrc=$?
  lbytes=$(printf '%s\n' "$lead" | LC_ALL=C wc -c | tr -d ' ')
  case "$first" in
    *compacted*'/autoflow:cycle $ARGUMENTS'*'before any other action'*)
      pass "B1: the cycle body's first line is the re-invocation rule" ;;
    *) failc "B1" "first body line is not the re-invocation rule: ${first:0:200}" ;;
  esac
  if [ "$lrc" -ne 0 ]; then
    failc "B1" "the cycle body carries no core:leading-end marker"
  elif [ "$lbytes" -le "$BUDGET" ]; then
    pass "B1: the cycle body's leading part is $lbytes B (<= $BUDGET)"
  else
    failc "B1" "the cycle body's leading part is $lbytes B (> $BUDGET) — move a section past the core's core:leading-end marker"
  fi
else
  failc "B1" "skills/cycle/SKILL.md missing"
fi
if [ -f "$CRIT" ]; then
  cbytes=$(body_after_frontmatter "$CRIT" | LC_ALL=C wc -c | tr -d ' ')
  if [ "$cbytes" -le "$BUDGET" ]; then
    pass "B2: the criterion-review body is $cbytes B (<= $BUDGET), wholly within the re-attach cap"
  else
    failc "B2" "the criterion-review body is $cbytes B (> $BUDGET)"
  fi
else
  failc "B2" "skills/criterion-review/SKILL.md missing"
fi
DECL='AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}'
nodecl=""
for f in "$CYCLE" "$CRIT" "$REPO_ROOT"/agents/*.md; do
  [ -f "$f" ] && grep -qxF "$DECL" "$f" || nodecl="$nodecl ${f#"$REPO_ROOT"/}"
done
[ -z "$nodecl" ] && pass "B3: both bodies and every agent definition declare the root through \${CLAUDE_PLUGIN_ROOT}" \
  || failc "B3" "no root declaration line in:$nodecl"

# ── C: path closure ──────────────────────────────────────────────────────────
echo "== C: <autoflow-root>/… paths resolve; no bare AutoFlow path =="
unres=""; nfiles=0; nroots=0
while IFS= read -r f; do
  nfiles=$((nfiles + 1))
  nroots=$((nroots + $(grep -oE '<autoflow-root>/' "$REPO_ROOT/$f" | wc -l)))
  u=$(unresolved_roots "$REPO_ROOT" "$f")
  [ -n "$u" ] && unres="$unres$u"$'\n'
done < <(scope_files "$REPO_ROOT")
if [ "$nroots" -eq 0 ]; then
  failc "C1" "no <autoflow-root>/ path found in $nfiles files (vacuous)"
elif [ -z "$unres" ]; then
  pass "C1: all $nroots <autoflow-root>/ paths in $nfiles files resolve under the repository root"
else
  failc "C1" "unresolved: $(printf '%s' "$unres" | tr '\n' ' ')"
fi

bare=""
while IFS= read -r f; do
  while IFS='|' read -r bf bl bs; do
    [ -n "$bf" ] || continue
    allowed "$bf" "$bs" "$ALLOW_SPANS" && continue
    allowed "$bf" "$bs" "$ALLOW_FENCE" && continue
    bare="$bare $bf:$bl:\`$bs\`"
  done < <(bare_paths "$REPO_ROOT" "$f")
done < <(scope_files "$REPO_ROOT")
[ -z "$bare" ] && pass "C2: no AutoFlow path is left as a bare code-span or fenced command" \
  || failc "C2" "bare AutoFlow path(s) — write <autoflow-root>/…:$bare"

SPEC="$WORK/spec"
mkdir -p "$SPEC/docs"
printf '%s\n' 'Run `bash scripts/ledger/ledger-entry-id.sh next`, then read' \
  '`docs/core.md` > Rule Scope and `<autoflow-root>/docs/no-such-document.md`.' > "$SPEC/docs/specimen.md"
sb=$(bare_paths "$SPEC" docs/specimen.md | cut -d'|' -f3 | tr '\n' ' ')
su=$(unresolved_roots "$SPEC" docs/specimen.md)
if [ "$sb" = "bash scripts/ledger/ledger-entry-id.sh next docs/core.md " ] && [ "$su" = "docs/specimen.md|docs/no-such-document.md" ]; then
  pass "C3: the specimen's two bare paths and its unresolvable <autoflow-root>/ path are flagged"
else
  failc "C3" "bare='$sb' unresolved='$su'"
fi

TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo ""
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $TOTAL checks)"
[ "$FAIL_COUNT" -eq 0 ]
