#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# gen-skill-bodies.sh — generate the carriers every AutoFlow role starts with
# (issue #454, ADR-0027 D2; issue #494, ADR-0035)
# =============================================================================
# Dev-time generator. The rules reach a role through the carrier it starts
# with — a main session through the body of the command that starts it, a
# subagent through its agent definition, a reviewer through its rule file —
# and each carrier is generated from the rules' homes: the core part of a
# command body from docs/core.md, and every carrier's documents by the
# classification scripts/skills/role-docs.tsv:
#
#   skills/cycle/SKILL.md            /autoflow:cycle <N> [new] — the whole cycle
#                                    in one session; the command header, then
#                                    the whole core in its own order
#   skills/cycle-u1/SKILL.md …       /autoflow:cycle-u1 <N> [new] …
#   skills/cycle-u7/SKILL.md         /autoflow:cycle-u7 [<N>] — one unit alone
#                                    (issue #464, ADR-0032; U7, its issue number
#                                    optional, ADR-0033); the command header,
#                                    then the parts of the core the unit uses,
#                                    in the core's order, by the classification
#                                    scripts/skills/core-units.tsv
#   skills/criterion-review/SKILL.md /autoflow:criterion-review <N> [new] —
#                                    U1's criterion review stage alone; the
#                                    command header, then the core sections the
#                                    stage is bound by
#   agents/<name>.md                 an agent definition: its own text, down to
#   docs/review/review-<name>.md     the generation marker, then what follows
#                                    it, generated; a reviewer's rule file
#                                    likewise
#
# A command body carries, after its core part, the documents role-docs.tsv
# names for it; an agent definition and a rule file carry, after the
# marker, the core parts and the documents it names for them. Each is
# preceded by a `<!-- From <autoflow-root>/<document> > <section> -->` line.
# A document's links point at `<autoflow-root>/…` (a link to a section of its
# own document, at that document); an entry whose document an earlier entry
# of the same carrier carries whole is left out; an entry that matches no
# carrier, a scope or prefix that matches no part of its document or more
# than one, and a link whose target does not exist fail the generation.
#
# The classification reads the core in blocks: a heading; a paragraph; a
# bullet, a table row or a `**`-led line, with the lines that continue it; a
# fenced block's fence and each of its unindented lines, with the indented lines
# under it. Every block takes the units of the entry that matches it — a prefix
# entry over the block's first line, else its deepest section entry — and a
# section entry `split` admits no block of its own. A part no entry classifies,
# a block two prefix entries match, and an entry that matches nothing fail the
# generation.
#
# The core's markdown links are reduced to their text in a body: a link is
# relative to docs/, while a body sits under skills/<name>/, and every AutoFlow
# path a link names is already written as `<autoflow-root>/…` in its text.
#
# The plugin installs without a build step, so the generated carriers are
# committed; tests/plugin/verify-skill-bodies.sh runs `--check` (regen-clean),
# the classification checks, the root declaration and the `<autoflow-root>/…`
# path closure.
#
#   gen-skill-bodies.sh            write every carrier
#   gen-skill-bodies.sh --check    exit 0 when the committed carriers equal the
#                                  generator's output, 1 (naming each one that
#                                  differs) otherwise
#   gen-skill-bodies.sh --list     print each generated command body's path
#   gen-skill-bodies.sh --list-all print every generated carrier's path
#   gen-skill-bodies.sh --core Uk  print the core part of unit Uk's body
# Pure bash + awk + sed; BSD and GNU tools alike.
# =============================================================================

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE="$ROOT/docs/core.md"
MAP="$ROOT/scripts/skills/core-units.tsv"
DOCS="$ROOT/scripts/skills/role-docs.tsv"
UNITS="U1 U2 U3 U4 U5 U6 U7"
BODIES="cycle cycle-u1 cycle-u2 cycle-u3 cycle-u4 cycle-u5 cycle-u6 cycle-u7 criterion-review"

MODE=write
case "${1:-}" in
  "") ;;
  --check) MODE=check ;;
  --list) for _s in $BODIES; do echo "skills/$_s/SKILL.md"; done; exit 0 ;;
  --list-all) MODE=list ;;
  --core) MODE=core
          case " $UNITS " in *" ${2:-none} "*) ;; *) echo "usage: gen-skill-bodies.sh --core U1…U7" >&2; exit 2 ;; esac ;;
  *) echo "usage: gen-skill-bodies.sh [--check | --list | --list-all | --core Uk]" >&2; exit 2 ;;
esac
[ -f "$CORE" ] || { echo "gen-skill-bodies: $CORE not found" >&2; exit 2; }
[ -f "$MAP" ] || { echo "gen-skill-bodies: $MAP not found" >&2; exit 2; }
[ -f "$DOCS" ] || { echo "gen-skill-bodies: $DOCS not found" >&2; exit 2; }

# strip_links — a markdown link becomes its text.
strip_links() { sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g'; }

# core_body — the core from its first `## ` heading to the end.
core_body() { awk 'f || /^## / { f = 1; print }' "$CORE"; }

# section <heading> — one `## ` section of the core, heading included, without
# its trailing blank lines; empty when the heading is absent.
section() {
  awk -v h="$1" '
    $0 == h { on = 1; print; next }
    on && /^## / { exit }
    on { print }' "$CORE" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# bullet <prefix> — the one-line bullet of the core that starts with <prefix>.
bullet() { awk -v p="$1" 'index($0, p) == 1 { print; exit }' "$CORE"; }

# need <what> <text> — fail when an extraction came back empty (a renamed
# heading or bullet in the core must break generation, not drop a rule).
need() { [ -n "$2" ] || { echo "gen-skill-bodies: docs/core.md has no $1" >&2; exit 1; }; }

ROOT_DECL='AutoFlow root (`<autoflow-root>`): ${CLAUDE_PLUGIN_ROOT}
An `<autoflow-root>/…` path is under that directory, and `<autoflow-root>` is never typed into a shell; a bare relative path (`.claude/autoflow.local.json`, the target'"'"'s own files) is the target'"'"'s, and `<attempt-dir>/…` is in the record directory `autoflow-records dir` prints. Where this line is absent — a helper, a shell — `autoflow-root` prints the root.'
GEN_NOTE='<!-- Generated from docs/core.md and the documents scripts/skills/role-docs.tsv names by scripts/skills/gen-skill-bodies.sh — edit those homes, then regenerate. -->'
MARK='<!-- Generated below from the homes of the documents it names by scripts/skills/gen-skill-bodies.sh (scripts/skills/role-docs.tsv) — edit those homes, then regenerate. -->'

# trim — drop trailing blank lines.
trim() { sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

# doc_part <document> <scope> <prefix> — the part of a document an entry
# names: the whole document, the section its heading path opens (to the next
# heading of its level or above; a line inside a fenced block is no heading),
# or the one block of it whose first line starts with <prefix>. Exit 3 when
# the scope opens no section or more than one, 4 when the prefix starts no
# block or more than one.
doc_part() {
  awk -v scope="$2" -v pfx="$3" '
    function lvl(x) { match(x, /^#+/); return RLENGTH }
    BEGIN {
      m = (scope == "") ? 0 : split(scope, st, " > ")
      for (j = 1; j <= m; j++) sl[j] = lvl(st[j])
      on = (m == 0)
    }
    {
      isf = ($0 ~ /^[ \t]*```/)
      if (!fence && !isf && $0 ~ /^#+ /) {
        d = lvl($0)
        if (on && m > 0 && d <= depth) on = 0
        cur[d] = $0; for (j = d + 1; j <= 6; j++) cur[j] = ""
        if (m > 0 && d == sl[m]) {
          ok = 1
          for (j = 1; j <= m; j++) if (index(cur[sl[j]], st[j]) != 1) ok = 0
          if (ok && ++found == 1) { on = 1; depth = d }
        }
      }
      wasfence = fence
      if (isf) fence = !fence
      if (!on) next
      if (pfx == "") { print; next }
      if (inb) {
        if ($0 ~ /^[ \t]*$/ || $0 ~ /^(- |\||#|[0-9]+\. |\*\*)/) inb = 0
        else { print; next }
      }
      if (!wasfence && index($0, pfx) == 1 && ++nb == 1) { print; inb = 1 }
    }
    END { if (m > 0 && found != 1) exit 3; if (pfx != "" && nb != 1) exit 4 }' "$ROOT/$1" > "$TMP/part" || return $?
  trim < "$TMP/part"
}

# links <document> — a markdown link of a document other than the core points
# at `<autoflow-root>/…`, its fragment dropped — a link to a section of the
# document itself, at the document (the core's links are reduced to
# their text, strip_links); exit 1, naming it, on a link whose target does not
# exist.
links() {
  awk -v doc="$1" -v root="$ROOT" '
    function norm(x,   n, a, i, o, k, r) {
      n = split(x, a, "/"); k = 0
      for (i = 1; i <= n; i++) {
        if (a[i] == "" || a[i] == ".") continue
        if (a[i] == "..") { if (k > 0) k--; continue }
        o[++k] = a[i]
      }
      r = ""; for (i = 1; i <= k; i++) r = r (i > 1 ? "/" : "") o[i]
      return r
    }
    BEGIN { dir = doc; sub(/\/[^\/]*$/, "", dir) }
    /^[ \t]*```/ { fence = !fence; print; next }
    fence { print; next }
    {
      out = ""; l = $0
      while (match(l, /\[[^]]*\]\([^)]*\)/)) {
        seg = substr(l, RSTART, RLENGTH)
        out = out substr(l, 1, RSTART - 1)
        l = substr(l, RSTART + RLENGTH)
        t = seg; sub(/^\[[^]]*\]\(/, "", t); sub(/\)$/, "", t)
        if (t ~ /^(https?:|mailto:|<)/) { out = out seg; continue }
        txt = seg; sub(/\]\([^)]*\)$/, "]", txt)
        sub(/#.*$/, "", t)
        p = (t == "") ? doc : norm(dir "/" t)
        if (system("test -e \"" root "/" p "\"") != 0) { print "gen-skill-bodies: " doc ": the link target " t " does not exist" | "cat 1>&2"; bad = 1 }
        out = out txt "(<autoflow-root>/" p ")"
      }
      print out l
    }
    END { exit bad }'
}

# label <document> <scope> <prefix> — an entry's name: the document's
# `<autoflow-root>/…` path, then its heading path and its block, by their text.
label() {
  local l="\`<autoflow-root>/$1\`" s c
  if [ -n "$2" ]; then
    s="$(printf '%s' "$2" | sed -E -e 's/(^| > )#+ /\1/g')"
    l="$l > $s"
  fi
  if [ -n "$3" ]; then
    c="$(printf '%s' "$3" | sed -E -e 's/\*\*//g' -e 's/^- //' -e 's/^\[(MUST|DENY)\] //' -e 's/[.:]$//')"
    l="$l > *$c*"
  fi
  printf '%s' "$l"
}

# entries — the classification's entries, one per line,
# "<carrier>\t<document>\t<scope>\t<prefix>"; fails on an entry whose document
# is absent.
entries() {
  awk -F '\t' -v root="$ROOT" '
    index($0, "\t") == 0 { next }
    {
      if (system("test -f \"" root "/" $2 "\"") != 0) { print "gen-skill-bodies: role-docs.tsv: \"" $0 "\": no document " $2 | "cat 1>&2"; bad = 1; next }
      print $1 "\t" $2 "\t" $3 "\t" $4
    }
    END { exit bad }' "$DOCS"
}

# carriers — every generated carrier: the command bodies in the order of
# BODIES, then every other file an entry's carrier names, in the order they
# first match. An entry whose carrier matches no file fails.
carriers() {
  local _s _e _c _bad=0 _seen="" _hit
  for _s in $BODIES; do echo "skills/$_s/SKILL.md"; done
  while IFS=$'\t' read -r _c _; do
    _hit=0
    for _s in $BODIES; do [[ "skills/$_s/SKILL.md" == $_c ]] && _hit=1; done
    for _e in $(cd "$ROOT" && compgen -G "$_c" | LC_ALL=C sort); do
      case "$_e" in skills/*) continue ;; esac
      _hit=1
      case " $_seen " in *" $_e "*) ;; *) _seen="$_seen $_e"; echo "$_e" ;; esac
    done
    [ "$_hit" -eq 1 ] || { echo "gen-skill-bodies: role-docs.tsv: the carrier $_c matches no file" >&2; _bad=1; }
  done < "$TMP/entries"
  return "$_bad"
}

# attached <carrier> — the classification's entries for a carrier, in order,
# less an entry whose document the carrier already carries whole.
attached() {
  awk -F '\t' -v c="$1" '
    function glob(p,   r) { r = p; gsub(/[.+?^$(){}|]/, "\\\\&", r); gsub(/\*/, ".*", r); return "^" r "$" }
    c ~ glob($1) {
      if (($2 "\t\t") in seen || ($2 "\t" $3 "\t" $4) in seen) next
      seen[$2 "\t" $3 "\t" $4] = 1
      print
    }' "$TMP/entries"
}

# doc_list <carrier> — the names of a carrier's entries, joined by "; ".
doc_list() {
  local _l="" _c _d _s _p
  while IFS=$'\t' read -r _c _d _s _p; do
    _l="${_l:+$_l; }$(label "$_d" "$_s" "$_p")"
  done < <(attached "$1")
  printf '%s' "${_l:-none}"
}

# attachments <carrier> — the text of a carrier's entries, each preceded by its
# `<!-- From … -->` line and followed by a blank line.
attachments() {
  local _c _d _s _p _t _rc _f
  while IFS=$'\t' read -r _c _d _s _p; do
    _rc=0; _t="$(doc_part "$_d" "$_s" "$_p")" || _rc=$?
    case "$_rc" in
      0) ;;
      3) echo "gen-skill-bodies: role-docs.tsv: $_d has no single section \"$_s\"" >&2; return 1 ;;
      4) echo "gen-skill-bodies: role-docs.tsv: $_d > $_s has no single block \"$_p\"" >&2; return 1 ;;
      *) return 1 ;;
    esac
    need "$_d $_s $_p" "$_t"
    _f="$(label "$_d" "$_s" "$_p" | tr -d '`*')"
    printf '<!-- From %s -->\n\n' "$_f"
    if [ "$_d" = docs/core.md ]; then
      printf '%s\n' "$_t" | strip_links
    else
      printf '%s\n' "$_t" | links "$_d" || return 1
    fi
    printf '\n'
  done < <(attached "$1")
}

# head_of <file> — a carrier's own text: the file down to the marker, less
# trailing blank lines.
head_of() { awk -v m="$MARK" '$0 == m { exit } { print }' "$ROOT/$1" | trim; }

# gen_carrier <file> — an agent definition or a rule file: its own text, the
# marker, the line naming what follows, and the text of its entries.
gen_carrier() {
  local h a
  h="$(head_of "$1")"; need "text of its own in $1" "$h"
  a="$(attachments "$1")" || return 1
  printf '%s\n\n%s\n\n' "$h" "$MARK"
  printf '**Carried below** — the guidance this role follows, from its homes by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: %s.\n\n' "$(doc_list "$1")"
  printf '%s\n' "$a" | trim
}

# docs_line <body> — a command body's line naming the documents it carries.
docs_line() {
  printf '**The documents in this body** — after the core, the documents this session follows, by the classification `<autoflow-root>/scripts/skills/role-docs.tsv`: %s.\n\n' "$(doc_list "$1")"
}

# body_docs <body> — a command body's documents, after its core part.
body_docs() {
  local a
  a="$(attachments "$1")" || return 1
  [ -z "$a" ] || printf '\n%s\n' "$(printf '%s\n' "$a" | trim)"
}

# classify — the core from its first `## ` heading, one line per core line:
# "<depth>\t<units>\t<line>", depth the heading level less one (0 off a
# heading), units `all`, the unit names, `b` (a blank line) or `split` (a
# split section's heading, kept when any line of its section is). Fails, naming
# each defect, as the header says.
classify() {
  awk '
    function bad(msg) { print "gen-skill-bodies: core-units.tsv: " msg | "cat 1>&2"; err = 1 }
    function inscope(i, d,   j) {
      if (m[i] > d) return 0
      for (j = 1; j <= m[i]; j++) if (index(cur[j], st[i, j]) != 1) return 0
      return 1
    }
    # deepest section entry over the current path no deeper than d; 0 when none
    function section_of(d,   i, best) {
      best = 0
      for (i = 1; i <= n; i++) if (px[i] == "" && inscope(i, d) && (best == 0 || m[i] > m[best])) best = i
      return best
    }
    BEGIN { FS = "\t" }
    FNR == NR {
      if (index($0, "\t") == 0) next
      n++; sc[n] = $1; px[n] = $2; un[n] = $3
      m[n] = split($1, tmp, " > ")
      for (j = 1; j <= m[n]; j++) st[n, j] = tmp[j]
      if (un[n] != "all" && un[n] != "split" && un[n] !~ /^U[1-7]( U[1-7])*$/) bad("\"" $0 "\": units \"" un[n] "\"")
      if (px[n] != "" && un[n] == "split") bad("\"" $0 "\": a prefix entry is never split")
      next
    }
    !started && !/^## / { next }
    {
      started = 1
      isfence = ($0 ~ /^[ \t]*```/)
      if (!incode && match($0, /^#+ /)) {
        depth = RLENGTH - 2
        cur[depth] = $0
        for (j = depth + 1; j <= 6; j++) cur[j] = ""
        own = 0
        for (i = 1; i <= n; i++) if (px[i] == "" && m[i] == depth && inscope(i, depth)) { hits[i]++; if (own) bad("heading \"" $0 "\": two entries"); own = i }
        if (!own) own = section_of(depth - 1)
        if (!own) { bad("heading \"" $0 "\": no entry"); u = "split" }
        else if (un[own] == "split" && m[own] < depth) { bad("heading \"" $0 "\": no entry in the split section \"" sc[own] "\""); u = "split" }
        else u = un[own]
        print depth "\t" u "\t" $0
        prevblank = 0; prevhead = 1
        next
      }
      if ($0 ~ /^[ \t]*$/) { print 0 "\tb\t" $0; prevblank = 1; next }
      if (incode) start = isfence || $0 ~ /^[^ \t]/
      else start = prevblank || prevhead || isfence || $0 ~ /^(- |\||\*\*|<!--|> |[0-9]+\. )/
      if (start) bl = $0
      if (isfence) incode = !incode
      prevblank = 0; prevhead = 0
      hit = 0
      for (i = 1; i <= n; i++) if (px[i] != "" && inscope(i, depth) && index(bl, px[i]) == 1) { if (hit) bad("line \"" $0 "\": two prefix entries"); hit = i }
      if (hit) { hits[hit]++; u = un[hit] }
      else {
        sec = section_of(depth)
        if (!sec) { bad("line \"" $0 "\": no entry"); u = "split" }
        else if (un[sec] == "split") { bad("line \"" substr(bl, 1, 60) "\": no entry in the split section \"" sc[sec] "\""); u = "split" }
        else u = un[sec]
      }
      print 0 "\t" u "\t" $0
    }
    END {
      for (i = 1; i <= n; i++) {
        if (!hits[i]) bad("\"" sc[i] (px[i] == "" ? "" : "\t" px[i]) "\": matches nothing")
        else if (px[i] == "" && hits[i] > 1) bad("\"" sc[i] "\": matches " hits[i] " headings")
      }
      exit err
    }' "$MAP" "$CORE"
}

# unit_core <Uk> < classify — the core part of unit Uk's body: the lines whose
# units name Uk or `all`, a split heading when its section keeps a line, runs of
# blank lines left by a dropped part closed to one.
unit_core() {
  awk -v k="$1" '
    BEGIN { FS = "\t" }
    { d[NR] = $1; t[NR] = $2; x[NR] = substr($0, length($1) + length($2) + 3) }
    END {
      for (i = 1; i <= NR; i++)
        inc[i] = (t[i] == "b") ? -1 : (t[i] == "split") ? -2 : (t[i] == "all" || index(" " t[i] " ", " " k " ") > 0)
      for (i = NR; i >= 1; i--) if (inc[i] == -2) {
        inc[i] = 0
        for (j = i + 1; j <= NR && !(d[j] > 0 && d[j] <= d[i]); j++) if (inc[j] == 1) { inc[i] = 1; break }
      }
      out = 0; pend = 0
      for (i = 1; i <= NR; i++) {
        if (inc[i] == -1) { if (out) pend = 1; continue }
        if (inc[i] == 1) { if (pend) print ""; pend = 0; print x[i]; out = 1 }
      }
    }'
}

# left_out <Uk> — the classification entries unit Uk does not take, named by
# heading path and prefix and grouped under their parent path ("Parent: a, b");
# a split section none of whose entries Uk takes is named once.
left_out() {
  awk -v k="$1" '
    function takes(i) { return un[i] == "all" || index(" " un[i] " ", " " k " ") > 0 }
    function under(e, i) { return e != i && (sc[e] == sc[i] || index(sc[e], sc[i] " > ") == 1) }
    function path(str,   p, s, j, q) {
      q = split(str, s, " > ")
      for (j = 1; j <= q; j++) { sub(/^#+ /, "", s[j]); p = p (j > 1 ? " > " : "") s[j] }
      return p
    }
    function add(g, item) {
      if (!(g in items)) { order[++ng] = g; items[g] = item } else items[g] = items[g] ", " item
    }
    function list(i,   c, q) {
      if (px[i] == "") {
        q = path(sc[i])
        if (match(q, / > [^>]*$/)) add(substr(q, 1, RSTART - 1), substr(q, RSTART + 3))
        else add("", q)
        return
      }
      c = px[i]
      gsub(/\*\*|`/, "", c); sub(/^(- |\| |> )/, "", c); sub(/^\[MUST\] /, "", c)
      sub(/ \|$/, "", c); sub(/ \([^)]*$/, "", c); sub(/[.:]$/, "", c)
      if (c ~ /^[A-Za-z]/) add(path(sc[i]), c)
    }
    BEGIN { FS = "\t" }
    index($0, "\t") { n++; sc[n] = $1; px[n] = $2; un[n] = $3 }
    END {
      for (i = 1; i <= n; i++) {
        if (done[i]) continue
        if (un[i] == "split") {
          any = 0
          for (e = 1; e <= n; e++) if (under(e, i) && un[e] != "split" && takes(e)) any = 1
          if (any) continue
          for (e = 1; e <= n; e++) if (under(e, i)) done[e] = 1
        } else if (takes(i)) continue
        list(i)
      }
      for (j = 1; j <= ng; j++) printf "%s%s", (j > 1 ? "; " : ""), (order[j] == "" ? items[order[j]] : order[j] ": " items[order[j]])
      print ""
    }' "$MAP"
}

# unit_field <Uk> <column> — the unit table row of the core: 1 the unit's name,
# 2 its phases.
unit_field() {
  awk -v k="$1" -v c="$2" -F '|' '
    index($2, " " k " ") == 1 { f = (c == 1) ? $2 : $3; sub(/^ U[1-7] /, "", f); sub(/^ +/, "", f); sub(/ +$/, "", f); print f; exit }' "$CORE"
}

gen_cycle() {
  cat <<'EOF'
---
name: cycle
description: >-
  Run an AutoFlow cycle on an issue in one session — PREFLIGHT, with the
  attempt's criterion review stage, to REVIEW; `new` asks for a new attempt of
  the issue (one unit alone is /autoflow:cycle-u1 … cycle-u7). Use only when the
  operator starts or resumes an AutoFlow cycle (/autoflow:cycle <N> [new]).
argument-hint: "<issue-number> [new [--base <branch>] [--commit <commit>]]"
---

EOF
  printf '%s\n\n' "$ROOT_DECL"
  cat <<'EOF'
**Scope** (`$ARGUMENTS`): `<N>` alone runs issue #N's cycle, PREFLIGHT to REVIEW; `new` requests a new attempt, and `--base <branch>` / `--commit <commit>` with it name the base and the start commit `autoflow-records new` makes it at. A session that runs one unit alone is started by that unit's command, `/autoflow:cycle-u1` … `/autoflow:cycle-u7`, whose body carries the parts of the core the unit uses; given `unit=Uk` here, report that and stop.

EOF
  docs_line skills/cycle/SKILL.md
  core_body | strip_links
  body_docs skills/cycle/SKILL.md || return 1
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
  Run the criterion review stage of an AutoFlow cycle alone, also the entry of
  the abbreviated path — an attempt's review of the issue's acceptance criteria
  against the target's code and policy, ending at its review record;
  the attempt then goes on by /autoflow:cycle <N> or on the abbreviated path.
  Use only when the operator asks for the criterion review by itself
  (/autoflow:criterion-review <N> [new]).
argument-hint: "<issue-number> [new [--base <branch>] [--commit <commit>]]"
---

EOF
  printf '%s\n\n' "$ROOT_DECL"
  cat <<'EOF'
**Scope** (`$ARGUMENTS`: `<N>`, `new` the request for a new attempt, `--base <branch>` / `--commit <commit>` its base and start commit for `autoflow-records new`) — U1's criterion review stage of issue #N alone, entered as `/autoflow:cycle` enters it: from the attempt's records, the attempt is created first on `new` or on the operator's `new` request, and `criterion-review` enters the attempt it names; otherwise the session reports and stops. Follow `<autoflow-root>/docs/criterion-review.md`, carried below; the stage ends at its `[criterion-ready]` entry and writes no state file, and a `READY` attempt then goes on by `/autoflow:cycle <N>` or on the abbreviated path (`<autoflow-root>/docs/abbreviated-path.md`). The rules below, from `<autoflow-root>/docs/core.md`, bind the session while it does.

EOF
  docs_line skills/criterion-review/SKILL.md
  {
    printf '%s\n\n' "$conv" "$rule" "$spawn" "$ledger"
    printf '## Execution Principles\n\n%s\n%s\n%s\n\n' "$hdp" "$wrapper" "$cross"
    printf '## Cost Control\n\n%s\n' "$conc"
  } | strip_links
  body_docs skills/criterion-review/SKILL.md || return 1
  printf '\n%s\n' "$GEN_NOTE"
}

# wrap76 — words onto lines of at most 76 bytes, each indented two spaces (fold
# breaks differently in BSD and GNU).
wrap76() {
  awk '{ for (i = 1; i <= NF; i++) { if (l != "" && length(l) + 1 + length($i) > 76) { print "  " l; l = "" } l = (l == "" ? $i : l " " $i) } } END { if (l != "") print "  " l }'
}

gen_unit() {
  local k="$1" lk name phases new hint out alone
  lk="$(printf '%s' "$k" | tr 'U' 'u')"
  name="$(unit_field "$k" 1)";   need "unit table row for $k" "$name"
  phases="$(unit_field "$k" 2)"; need "unit table phases for $k" "$phases"
  out="$(left_out "$k")"
  new=" <N>"; hint="<issue-number>"
  [ "$k" = U1 ] && { new=" <N> [new]"; hint="<issue-number> [new [--base <branch>] [--commit <commit>]]"; }
  alone="of an AutoFlow cycle alone"
  [ "$k" = U7 ] && { new=" [<N>]"; hint="[<issue-number>]"; alone="of an AutoFlow cycle alone, or the review of an attempt with no state file on the abbreviated path"; }
  printf -- '---\nname: cycle-%s\ndescription: >-\n' "$lk"
  printf 'Run unit %s (%s — %s) %s, in a session of its own, with the parts of the core %s uses. Use only when the operator starts a %s session (/autoflow:cycle-%s%s).\n' \
    "$k" "$name" "$phases" "$alone" "$k" "$k" "$lk" "$new" | wrap76
  printf 'argument-hint: "%s"\n---\n\n' "$hint"
  printf '%s\n\n' "$ROOT_DECL"
  if [ "$k" = U7 ]; then
    printf '**Scope** (`$ARGUMENTS`: `<N>`, or nothing) — unit %s, %s (%s), of a cycle alone: read where the cycle stands from the attempt'"'"'s records, run %s from there to its exit transition, and end the session with the report the invoking prompt asks for.\n\n' \
      "$k" "$name" "$phases" "$k"
  else
    if [ "$k" = U1 ]; then
      printf '**Scope** (`$ARGUMENTS`: `<N>`, `new` the request for a new attempt, `--base <branch>` / `--commit <commit>` its base and start commit for `autoflow-records new`)'
    else
      printf '**Scope** (`$ARGUMENTS`: `<N>`)'
    fi
    printf ' — unit %s, %s (%s), of issue #N'"'"'s cycle alone: confirm from the attempt'"'"'s records that the cycle stands at %s'"'"'s entry (otherwise report the situation and stop), run %s from its entry to its exit transition, and end the session with the report the invoking prompt asks for.\n\n' \
      "$k" "$name" "$phases" "$k" "$k"
  fi
  printf '**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that %s uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: %s.\n\n' \
    "$k" "${out:-none}"
  docs_line "skills/cycle-$lk/SKILL.md"
  unit_core "$k" < "$TMP/core.tagged" | strip_links
  body_docs "skills/cycle-$lk/SKILL.md" || return 1
  printf '\n%s\n' "$GEN_NOTE"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
classify > "$TMP/core.tagged" || exit 1
if [ "$MODE" = core ]; then
  unit_core "$2" < "$TMP/core.tagged" | strip_links
  exit 0
fi
entries > "$TMP/entries" || exit 1
carriers > "$TMP/carriers" || exit 1
[ "$MODE" = list ] && { cat "$TMP/carriers"; exit 0; }
mkdir -p "$TMP/out"
while IFS= read -r _f; do
  mkdir -p "$TMP/out/$(dirname "$_f")"
  case "$_f" in
    skills/cycle/SKILL.md)            gen_cycle ;;
    skills/criterion-review/SKILL.md) gen_criterion_review ;;
    skills/cycle-u*/SKILL.md)         _k="${_f#skills/cycle-}"; gen_unit "$(printf '%s' "${_k%%/*}" | tr 'u' 'U')" ;;
    *)                                gen_carrier "$_f" ;;
  esac > "$TMP/out/$_f" || exit 1
done < "$TMP/carriers"

rc=0
while IFS= read -r _f; do
  _dst="$ROOT/$_f"
  if [ "$MODE" = check ]; then
    if ! cmp -s "$TMP/out/$_f" "$_dst"; then
      echo "gen-skill-bodies: $_f differs from the generator's output — run: bash scripts/skills/gen-skill-bodies.sh" >&2
      rc=1
    fi
  else
    cp "$TMP/out/$_f" "$_dst"
  fi
done < "$TMP/carriers"
[ "$MODE" = check ] && [ "$rc" -eq 0 ] && echo "gen-skill-bodies: OK — every carrier ($(wc -l < "$TMP/carriers" | tr -d ' '): the command bodies under skills/, the agent definitions and the reviewers' rule files) equals the generator's output"
exit "$rc"
