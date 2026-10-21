#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Test: the generated carriers and the AutoFlow path notation (issue #454 PR-3)
# =============================================================================
# The rules reach a role through the carrier it starts with — a main session
# through the command bodies /autoflow:cycle, /autoflow:cycle-u1 … cycle-u7 and
# /autoflow:criterion-review, a subagent through its agent definition, a
# reviewer through its rule file — generated from docs/core.md and the
# documents scripts/skills/role-docs.tsv names (ADR-0027 D2, ADR-0032,
# ADR-0035), and an AutoFlow path is written `<autoflow-root>/…` wherever a
# role reads it (ADR-0027 D3). The bodies are the ones `gen-skill-bodies.sh
# --list` names, the carriers the ones `--list-all` names. Plain bash +
# awk/sed/grep/cmp (no bats, no node/npm).
#
# Legs (category: packaging):
#
#   G   regen-clean
#     G1  the committed carriers equal scripts/skills/gen-skill-bodies.sh output
#     G2  a body edited by hand is caught (--check exits 1 on a scratch copy),
#         and so is an agent definition's generated part
#     G3  the classification (scripts/skills/core-units.tsv) is complete: a
#         scratch core with a new section, or a new block in a split section,
#         and a scratch entry that matches nothing each fail the generation;
#         so do a role-docs.tsv entry whose section does not exist and one
#         whose carrier matches no file
#     G4  every skills/*/SKILL.md is a generated body, and every agents/*.md
#         a generated carrier
#
#   K   composition
#     K1  read from the classification and the core apart from the
#         generator's block parser: each entry's first line (a section entry's
#         heading and first body line), where it is unique in the core, is in
#         exactly the unit bodies the entry names; a body missing a line is
#         caught
#     K2  the /autoflow:cycle body's core part is the whole core
#     K3  read from role-docs.tsv and the documents apart from the generator:
#         each entry's first line (the document's, its section heading or its
#         block) follows the entry's `<!-- From … -->` line in every carrier
#         the entry names; a carrier missing an entry is caught
#     K4  every document the core's Unit Document Loading Contract and Unit
#         references tables name for a unit is carried by that unit's body and
#         by the /autoflow:cycle body
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
# docs/development-guideline.md), agents/*.md and every generated body; of a
# generated carrier, C reads the part before its first `<!-- From … -->` line
# (what follows is its documents' text, read at their homes).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GEN="$REPO_ROOT/scripts/skills/gen-skill-bodies.sh"
BODIES="$(bash "$GEN" --list)"
CARRIERS="$(bash "$GEN" --list-all)"

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
docs/development-guideline.md|docs/review/
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

# own_part <root> <file> — the text C reads: a generated carrier's part before
# its first `<!-- From <autoflow-root>/… -->` line, any other file whole.
own_part() { awk '/^<!-- From <autoflow-root>\// { exit } { print }' "$1/$2"; }

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
    }' <(own_part "$1" "$2")
}

# allowed <file> <span> <list> — a generated body also takes docs/core.md's
allowed() {
  printf '%s\n' "$3" | grep -qxF "$1|$2" && return 0
  printf '%s\n' "$BODIES" | grep -qxF "$1" && printf '%s\n' "$3" | grep -qxF "docs/core.md|$2"
}

# core_part <body> — a body's core part: its first `## ` line to its first
# `<!-- From … -->` line or its generation note, less the blank line before it.
core_part() { awk '/^<!-- From |^<!-- Generated from / { exit } f || /^## / { f = 1; print }' "$1" | sed -e '$d'; }

# unresolved_roots <root> <file> — every `<autoflow-root>/…` path in <file>
# that matches nothing under <root>.
unresolved_roots() {
  own_part "$1" "$2" | grep -oE '<autoflow-root>/[^] `'"'"'"),;|]*' | sed -e 's|^<autoflow-root>/||' -e 's|[.:]*$||' | sort -u \
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

# scratch <dir> — a copy of the generator, its classifications, the documents
# and the committed carriers.
scratch() {
  mkdir -p "$1/scripts"
  cp -R "$REPO_ROOT/scripts/skills" "$1/scripts/"
  cp -R "$REPO_ROOT/docs" "$REPO_ROOT/skills" "$REPO_ROOT/agents" "$1/"
}

SCR="$WORK/regen"
scratch "$SCR"
printf 'hand edit\n' >> "$SCR/skills/cycle-u3/SKILL.md"
printf 'hand edit\n' >> "$SCR/agents/autoflow-evaluator.md"
if bash "$SCR/scripts/skills/gen-skill-bodies.sh" --check >/dev/null 2>"$WORK/g2.err"; then
  failc "G2" "--check accepted a hand-edited body"
elif grep -q 'skills/cycle-u3/SKILL.md differs' "$WORK/g2.err" && grep -q 'agents/autoflow-evaluator.md differs' "$WORK/g2.err"; then
  pass "G2: a hand-edited body and a hand-edited agent definition are caught (--check exit 1, naming each)"
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
scratch "$WORK/g3d"; printf 'agents/autoflow-evaluator.md\tdocs/units/build.md\t## A Vanished Section\n' >> "$WORK/g3d/scripts/skills/role-docs.tsv"
g3 g3d 'docs/units/build.md has no single section "## A Vanished Section"'
scratch "$WORK/g3e"; printf 'agents/autoflow-vanished.md\tdocs/core.md\t## Rule Scope\n' >> "$WORK/g3e/scripts/skills/role-docs.tsv"
g3 g3e 'the carrier agents/autoflow-vanished.md matches no file'
[ -z "$g3" ] && pass "G3: an unclassified section, an unclassified block in a split section, an entry matching nothing, a role-docs.tsv section that does not exist and a carrier matching no file each fail the generation" \
  || failc "G3" "$g3"

stray=""
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
  printf '%s\n' "$BODIES" | grep -qxF "${f#"$REPO_ROOT"/}" || stray="$stray ${f#"$REPO_ROOT"/}"
done
for f in "$REPO_ROOT"/agents/*.md; do
  printf '%s\n' "$CARRIERS" | grep -qxF "${f#"$REPO_ROOT"/}" || stray="$stray ${f#"$REPO_ROOT"/}"
done
[ -z "$stray" ] && pass "G4: every skills/*/SKILL.md is one of the $(printf '%s\n' "$BODIES" | wc -l | tr -d ' ') generated bodies, and every agents/*.md a generated carrier" \
  || failc "G4" "not generated:$stray"

# ── K: composition ───────────────────────────────────────────────────────────
echo "== K: each body's core part follows the classification =="
# k1 <skills-dir> — read without the generator's parser: for each entry of the
# classification, the lines it names — a prefix entry's line, the one line in
# its scope that starts with the prefix; a section entry's heading and the first
# line of its body — where such a line occurs once in the core, are in the
# bodies of the units the entry names and in no other unit body. Prints each
# "Uk:<line>" that disagrees; the last line is the number of entries read.
k1() {
  local row scope rest pfx units line read n=0 k b want got
  local -a lines
  sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g' "$REPO_ROOT/docs/core.md" | awk 'f || /^## / { f = 1; print }' > "$WORK/k1.core"
  for k in U1 U2 U3 U4 U5 U6 U7; do core_part "$1/cycle-$(printf '%s' "$k" | tr 'U' 'u')/SKILL.md" > "$WORK/k1.$k"; done
  while IFS= read -r row; do
    scope="${row%%	*}"; rest="${row#*	}"; pfx="${rest%%	*}"; units="${rest#*	}"
    [ "$units" != split ] || continue
    # the lines of the scope's section: each step a heading's leading text
    awk -v s="$scope" '
      BEGIN { m = split(s, st, " > ") }
      /^#+ / { d = index($0, " ") - 2; cur[d] = $0; for (j = d + 1; j <= 6; j++) cur[j] = "" }
      { for (j = 1; j <= m; j++) if (index(cur[j], st[j]) != 1) next; print }' "$WORK/k1.core" > "$WORK/k1.scope"
    if [ -n "$pfx" ]; then
      [ "$(awk -v p="$pfx" 'index($0, p) == 1' "$WORK/k1.scope" | wc -l)" -eq 1 ] || continue
      lines=("$(awk -v p="$pfx" 'index($0, p) == 1' "$WORK/k1.scope")")
    else
      lines=("$(sed -n 1p "$WORK/k1.scope")" "$(awk 'NR > 1 && NF && !/^#/ { print; exit }' "$WORK/k1.scope")")
    fi
    read=0
    for line in "${lines[@]}"; do
      [ -n "$line" ] && [ "$(grep -cxF -- "$line" "$WORK/k1.core")" -eq 1 ] || continue
      read=1
      for k in U1 U2 U3 U4 U5 U6 U7; do
        b="$1/cycle-$(printf '%s' "$k" | tr 'U' 'u')/SKILL.md"
        case " $units " in *" all "*|*" $k "*) want=1 ;; *) want=0 ;; esac
        grep -qxF -- "$line" "$WORK/k1.$k" && got=1 || got=0
        [ "$want" = "$got" ] || echo "$k:$(printf '%s' "$line" | cut -c1-50)"
      done
    done
    n=$((n + read))
  done < <(grep "$(printf '\t')" "$REPO_ROOT/scripts/skills/core-units.tsv")
  echo "$n"
}
k1 "$REPO_ROOT/skills" > "$WORK/k1.out"
k1n=$(tail -1 "$WORK/k1.out"); k1bad=$(sed '$d' "$WORK/k1.out" | tr '\n' ' ')
cp -R "$REPO_ROOT/skills" "$WORK/k1skills"
sed '/^\*\*Regressions\*\*/d' "$REPO_ROOT/skills/cycle-u4/SKILL.md" > "$WORK/k1skills/cycle-u4/SKILL.md"
k1spec=$(k1 "$WORK/k1skills" | sed '$d' | tr '\n' ' ')
if [ "$k1n" -lt 40 ]; then
  failc "K1" "only $k1n classification entries read (vacuous)"
elif [ -n "$k1bad" ]; then
  failc "K1" "a unit body disagrees with the classification: $k1bad"
elif [ "$k1spec" != "U4:$(grep -m1 '^\*\*Regressions\*\*' "$REPO_ROOT/skills/cycle-u4/SKILL.md" | cut -c1-50) " ]; then
  failc "K1" "a U4 body without its Regressions line was read as '$k1spec'"
else
  pass "K1: $k1n classification entries read apart from the generator; each one's lines are in exactly its units' bodies; a body missing a line is caught"
fi

awk 'f || /^## / { f = 1; print }' "$REPO_ROOT/docs/core.md" | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g' > "$WORK/k2.want"
if core_part "$REPO_ROOT/skills/cycle/SKILL.md" | cmp -s "$WORK/k2.want" -; then
  pass "K2: the /autoflow:cycle body carries the whole core"
else
  failc "K2" "the /autoflow:cycle body's core part differs from the core"
fi

# k3 <carriers-root> — read without the generator: for each role-docs.tsv entry
# and each carrier it names, the entry's `<!-- From <autoflow-root>/<document>
# [> <section>]` line is in the carrier and the line after it (past one blank
# line) is the entry's first line — the document's first line, its section's
# heading or its block's first line, links reduced to their text on both sides;
# an entry is also met where the carrier carries its document whole. Prints
# each "<carrier>:<document> <section>" that disagrees; the last line is the
# number of entries read.
k3() {
  local n=0 c d sc px f want hd got steps
  while IFS=$'\t' read -r c d sc px; do
    steps=""
    [ -n "$sc" ] && steps=" > $(printf '%s' "$sc" | sed -E 's/(^| > )#+ /\1/g')"
    if [ -n "$px" ]; then want="$px"
    elif [ -n "$sc" ]; then want="${sc##* > }"
    else want="$(head -1 "$REPO_ROOT/$d")"; fi
    want="$(printf '%s' "$want" | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g')"
    hd="<!-- From <autoflow-root>/$d$steps"
    while IFS= read -r f; do
      # shellcheck disable=SC2053
      [[ "$f" == $c ]] || continue
      n=$((n + 1))
      grep -qxF -- "<!-- From <autoflow-root>/$d -->" "$1/$f" && continue
      got="$(awk -v h="$hd" 'index($0, h) == 1 && (substr($0, length(h) + 1, 1) == " ") { getline; getline; print; exit }' "$1/$f" \
        | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g')"
      [ -n "$got" ] && [ "${got#"$want"}" != "$got" ] || echo "$f:$d$steps"
    done <<< "$CARRIERS"
  done < <(grep "$(printf '\t')" "$REPO_ROOT/scripts/skills/role-docs.tsv")
  echo "$n"
}
k3 "$REPO_ROOT" > "$WORK/k3.out"
k3n=$(tail -1 "$WORK/k3.out"); k3bad=$(sed '$d' "$WORK/k3.out" | tr '\n' ' ')
mkdir -p "$WORK/k3c"; ( cd "$REPO_ROOT" && tar cf - $CARRIERS ) | ( cd "$WORK/k3c" && tar xf - )
awk '/^<!-- From <autoflow-root>\/docs\/decision-ledger.md -->/ { getline; getline; next } { print }' \
  "$REPO_ROOT/agents/autoflow-advisor.md" > "$WORK/k3c/agents/autoflow-advisor.md"
k3spec=$(k3 "$WORK/k3c" | sed '$d' | tr '\n' ' ')
if [ "$k3n" -lt 60 ]; then
  failc "K3" "only $k3n role-docs.tsv entries read (vacuous)"
elif [ -n "$k3bad" ]; then
  failc "K3" "a carrier disagrees with role-docs.tsv: $k3bad"
elif [ "$k3spec" != "agents/autoflow-advisor.md:docs/decision-ledger.md " ]; then
  failc "K3" "an advisor definition without its decision-ledger text was read as '$k3spec'"
else
  pass "K3: $k3n role-docs.tsv entries read apart from the generator; each one's first line follows its From line in every carrier it names (the whole text is G1's); a carrier missing one is caught"
fi

# K4 — the documents the core's tables name for a unit, in that unit's body and
# the whole-cycle body.
k4=""; k4n=0
while IFS= read -r row; do
  k=$(printf '%s' "$row" | sed -E 's/^\| (U[1-7]) .*/\1/')
  for d in $(printf '%s' "$row" | grep -oE '<autoflow-root>/docs/[^`)]*\.md' | sed 's|^<autoflow-root>/||' | sort -u); do
    k4n=$((k4n + 1))
    for b in "skills/cycle-$(printf '%s' "$k" | tr 'U' 'u')/SKILL.md" skills/cycle/SKILL.md; do
      grep -q "^<!-- From <autoflow-root>/$d[ ]" "$REPO_ROOT/$b" || k4="$k4 $b:$d"
    done
  done
done < <(awk '/^### Unit Document Loading Contract|^### Unit references/ { on = 1; next } /^##/ { on = 0 } on && /^\| U[1-7] /' "$REPO_ROOT/docs/core.md")
if [ "$k4n" -lt 10 ]; then
  failc "K4" "only $k4n documents read from the core's tables (vacuous)"
elif [ -n "$k4" ]; then
  failc "K4" "a document the core names for a unit is not in its body:$k4"
else
  pass "K4: the $k4n documents the core's tables name for the units are in each unit's body and the /autoflow:cycle body"
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
  nroots=$((nroots + $(own_part "$REPO_ROOT" "$f" | grep -oE '<autoflow-root>/' | wc -l)))
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
