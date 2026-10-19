#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: the command bodies and the AutoFlow path notation (issue #454 PR-3)
# =============================================================================
# The rules reach a main session through the command bodies — /autoflow:cycle,
# /autoflow:cycle-u1 … cycle-u6 and /autoflow:criterion-review — generated from
# docs/core.md (ADR-0027 D2, ADR-0032), and an AutoFlow path is written
# `<autoflow-root>/…` wherever a role reads it (ADR-0027 D3). The bodies are the
# ones `gen-skill-bodies.sh --list` names. Plain bash + awk/sed/grep/cmp (no
# bats, no node/npm).
#
# Legs (category: packaging):
#
#   G   regen-clean
#     G1  the committed bodies equal scripts/skills/gen-skill-bodies.sh output
#     G2  a body edited by hand is caught (--check exits 1 on a scratch copy)
#     G3  the classification (scripts/skills/core-units.tsv) is complete: a
#         scratch core with a new section, or a new block in a split section,
#         and a scratch entry that matches nothing each fail the generation
#     G4  every skills/*/SKILL.md is a generated body
#
#   K   composition
#     K1  each unit body's core part equals the core's parts classified for
#         that unit (`gen-skill-bodies.sh --core Uk`); a body missing a line
#         is caught
#     K2  the /autoflow:cycle body's core part is the whole core
#
#   B   root declaration
#     B1  every body and every agent definition declare the root through
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
# docs/development-guideline.md), agents/*.md and every generated body.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GEN="$REPO_ROOT/scripts/skills/gen-skill-bodies.sh"
BODIES="$(bash "$GEN" --list)"

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
# this repository's own security checklist items. A body generated from the
# core takes the core's entries.
ALLOW_SPANS='docs/core.md|scripts/
docs/core.md|docs/
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

# scope_files <root> — the documents C1/C2 read, relative to <root>.
scope_files() {
  ( cd "$1" && {
      find docs -name '*.md' -not -path 'docs/records/*' | LC_ALL=C sort
      ls agents/*.md 2>/dev/null
      for _s in $BODIES; do [ -f "$_s" ] && echo "$_s"; done
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

# allowed <file> <span> <list> — a generated body also takes docs/core.md's
allowed() {
  printf '%s\n' "$3" | grep -qxF "$1|$2" && return 0
  printf '%s\n' "$BODIES" | grep -qxF "$1" && printf '%s\n' "$3" | grep -qxF "docs/core.md|$2"
}

# core_part <body> — a body's core part: its first `## ` line to the end, less
# the closing blank line and generation note.
core_part() { awk 'f || /^## / { f = 1; print }' "$1" | sed -e '$d' | sed -e '$d'; }

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

# scratch <dir> — a copy of the generator, its classification, the core and
# the committed bodies.
scratch() {
  mkdir -p "$1/scripts" "$1/docs"
  cp -R "$REPO_ROOT/scripts/skills" "$1/scripts/"
  cp "$REPO_ROOT/docs/core.md" "$1/docs/core.md"
  cp -R "$REPO_ROOT/skills" "$1/"
}

SCR="$WORK/regen"
scratch "$SCR"
printf 'hand edit\n' >> "$SCR/skills/cycle-u3/SKILL.md"
if bash "$SCR/scripts/skills/gen-skill-bodies.sh" --check >/dev/null 2>"$WORK/g2.err"; then
  failc "G2" "--check accepted a hand-edited body"
elif grep -q 'skills/cycle-u3/SKILL.md differs' "$WORK/g2.err"; then
  pass "G2: a hand-edited body is caught (--check exit 1, naming skills/cycle-u3/SKILL.md)"
else
  failc "G2" "unexpected diagnostic: $(head -c 300 "$WORK/g2.err")"
fi

# g3 <name> <expected diagnostic> — the scratch copy <name> fails the generation
# with that diagnostic.
g3=""
g3() {
  if bash "$WORK/$1/scripts/skills/gen-skill-bodies.sh" --check >/dev/null 2>"$WORK/$1.err"; then
    g3="$g3 $1:accepted"
  elif ! grep -qF "$2" "$WORK/$1.err"; then
    g3="$g3 $1:'$(head -c 200 "$WORK/$1.err")'"
  fi
}
scratch "$WORK/g3a"; printf '\n## New Section\n\nA rule.\n' >> "$WORK/g3a/docs/core.md"
g3 g3a 'heading "## New Section": no entry'
scratch "$WORK/g3b"
awk '{ print } /^AutoFlow does not classify/ { print ""; print "A new paragraph." }' "$REPO_ROOT/docs/core.md" > "$WORK/g3b/docs/core.md"
g3 g3b 'line "A new paragraph.": no entry in the split section "## Project Information"'
scratch "$WORK/g3c"; printf '## Cost Control\tA vanished bullet\tU6\n' >> "$WORK/g3c/scripts/skills/core-units.tsv"
g3 g3c 'A vanished bullet": matches nothing'
[ -z "$g3" ] && pass "G3: an unclassified section, an unclassified block in a split section and an entry matching nothing each fail the generation" \
  || failc "G3" "$g3"

stray=""
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
  printf '%s\n' "$BODIES" | grep -qxF "${f#"$REPO_ROOT"/}" || stray="$stray ${f#"$REPO_ROOT"/}"
done
[ -z "$stray" ] && pass "G4: every skills/*/SKILL.md is one of the $(printf '%s\n' "$BODIES" | wc -l | tr -d ' ') generated bodies" \
  || failc "G4" "not generated:$stray"

# ── K: composition ───────────────────────────────────────────────────────────
echo "== K: each body's core part follows the classification =="
k1=""
for k in U1 U2 U3 U4 U5 U6; do
  b="$REPO_ROOT/skills/cycle-$(printf '%s' "$k" | tr 'U' 'u')/SKILL.md"
  bash "$GEN" --core "$k" > "$WORK/k1.want" || { k1="$k1 $k:generator"; continue; }
  core_part "$b" > "$WORK/k1.got"
  cmp -s "$WORK/k1.want" "$WORK/k1.got" || k1="$k1 $k"
done
sed '/^\*\*Regressions\*\*/d' "$REPO_ROOT/skills/cycle-u4/SKILL.md" > "$WORK/k1.cut"
bash "$GEN" --core U4 | cmp -s - <(core_part "$WORK/k1.cut") && k1="$k1 specimen-accepted"
[ -z "$k1" ] && pass "K1: each unit body's core part equals its classified parts of the core; a body missing a line is caught" \
  || failc "K1" "differs:$k1"

awk 'f || /^## / { f = 1; print }' "$REPO_ROOT/docs/core.md" | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g' > "$WORK/k2.want"
if core_part "$REPO_ROOT/skills/cycle/SKILL.md" | cmp -s "$WORK/k2.want" -; then
  pass "K2: the /autoflow:cycle body carries the whole core"
else
  failc "K2" "the /autoflow:cycle body's core part differs from the core"
fi

# ── B: root declaration ──────────────────────────────────────────────────────
echo "== B: root declaration =="
DECL='AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}'
nodecl=""
for f in $(printf '%s\n' "$BODIES" | sed "s|^|$REPO_ROOT/|") "$REPO_ROOT"/agents/*.md; do
  [ -f "$f" ] && grep -qxF "$DECL" "$f" || nodecl="$nodecl ${f#"$REPO_ROOT"/}"
done
[ -z "$nodecl" ] && pass "B1: every body and every agent definition declare the root through \${CLAUDE_PLUGIN_ROOT}" \
  || failc "B1" "no root declaration line in:$nodecl"

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
