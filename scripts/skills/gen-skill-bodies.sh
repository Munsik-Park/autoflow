#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# gen-skill-bodies.sh — generate the AutoFlow command bodies from the core
# (issue #454, ADR-0027 D2)
# =============================================================================
# Dev-time generator. The rules reach a main session through the body of the
# command that starts it, and every command body is generated from one source,
# docs/core.md:
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
# The plugin installs without a build step, so the generated bodies are
# committed; tests/plugin/verify-skill-bodies.sh runs `--check` (regen-clean),
# the classification checks, the root declaration and the `<autoflow-root>/…`
# path closure.
#
#   gen-skill-bodies.sh            write every body
#   gen-skill-bodies.sh --check    exit 0 when the committed bodies equal the
#                                  generator's output, 1 (naming each body that
#                                  differs) otherwise
#   gen-skill-bodies.sh --list     print each generated body's path
#   gen-skill-bodies.sh --core Uk  print the core part of unit Uk's body
# Pure bash + awk + sed; BSD and GNU tools alike.
# =============================================================================

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE="$ROOT/docs/core.md"
MAP="$ROOT/scripts/skills/core-units.tsv"
UNITS="U1 U2 U3 U4 U5 U6 U7"
BODIES="cycle cycle-u1 cycle-u2 cycle-u3 cycle-u4 cycle-u5 cycle-u6 cycle-u7 criterion-review"

MODE=write
case "${1:-}" in
  "") ;;
  --check) MODE=check ;;
  --list) for _s in $BODIES; do echo "skills/$_s/SKILL.md"; done; exit 0 ;;
  --core) MODE=core
          case " $UNITS " in *" ${2:-none} "*) ;; *) echo "usage: gen-skill-bodies.sh --core U1…U7" >&2; exit 2 ;; esac ;;
  *) echo "usage: gen-skill-bodies.sh [--check | --list | --core Uk]" >&2; exit 2 ;;
esac
[ -f "$CORE" ] || { echo "gen-skill-bodies: $CORE not found" >&2; exit 2; }
[ -f "$MAP" ] || { echo "gen-skill-bodies: $MAP not found" >&2; exit 2; }

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
GEN_NOTE='<!-- Generated from docs/core.md by scripts/skills/gen-skill-bodies.sh — edit the core, then regenerate. -->'

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
argument-hint: "<issue-number> [new]"
---

EOF
  printf '%s\n\n' "$ROOT_DECL"
  cat <<'EOF'
**Scope** (`$ARGUMENTS`): `<N>` alone runs issue #N's cycle, PREFLIGHT to REVIEW; `new` requests a new attempt. A session that runs one unit alone is started by that unit's command, `/autoflow:cycle-u1` … `/autoflow:cycle-u7`, whose body carries the parts of the core the unit uses; given `unit=Uk` here, report that and stop.

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
  Run the criterion review stage of an AutoFlow cycle alone — an attempt's
  review of the issue's acceptance criteria against the target's code and
  policy, ending at its [criterion-ready] entry; /autoflow:cycle <N> then
  continues that attempt's cycle. Use only when the operator asks for the
  criterion review by itself (/autoflow:criterion-review <N> [new]).
argument-hint: "<issue-number> [new]"
---

EOF
  printf '%s\n\n' "$ROOT_DECL"
  cat <<'EOF'
**Scope** (`$ARGUMENTS`: `<N>`, `new` the request for a new attempt) — U1's criterion review stage of issue #N alone, entered as `/autoflow:cycle` enters it (`<autoflow-root>/docs/units/preparation.md` > *The criterion review stage*): from the facts `bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue <N>` reports, the attempt is created first on `new` or on the operator's `new` request, and `criterion-review` enters the attempt it names; otherwise the session reports and stops. Read `<autoflow-root>/docs/criterion-review.md` now and follow it; the stage ends at its `[criterion-ready]` entry and writes no state file. The rules below, from `<autoflow-root>/docs/core.md`, bind the session while it does.

EOF
  {
    printf '%s\n\n' "$conv" "$rule" "$spawn" "$ledger"
    printf '## Execution Principles\n\n%s\n%s\n%s\n\n' "$hdp" "$wrapper" "$cross"
    printf '## Cost Control\n\n%s\n' "$conc"
  } | strip_links
  printf '\n%s\n' "$GEN_NOTE"
}

# wrap76 — words onto lines of at most 76 bytes, each indented two spaces (fold
# breaks differently in BSD and GNU).
wrap76() {
  awk '{ for (i = 1; i <= NF; i++) { if (l != "" && length(l) + 1 + length($i) > 76) { print "  " l; l = "" } l = (l == "" ? $i : l " " $i) } } END { if (l != "") print "  " l }'
}

gen_unit() {
  local k="$1" lk name phases new hint out
  lk="$(printf '%s' "$k" | tr 'U' 'u')"
  name="$(unit_field "$k" 1)";   need "unit table row for $k" "$name"
  phases="$(unit_field "$k" 2)"; need "unit table phases for $k" "$phases"
  out="$(left_out "$k")"
  new=" <N>"; hint="<issue-number>"
  [ "$k" = U1 ] && { new=" <N> [new]"; hint="<issue-number> [new]"; }
  [ "$k" = U7 ] && { new=" [<N>]"; hint="[<issue-number>]"; }
  printf -- '---\nname: cycle-%s\ndescription: >-\n' "$lk"
  printf 'Run unit %s (%s — %s) of an AutoFlow cycle alone, in a session of its own, with the parts of the core %s uses. Use only when the operator starts a %s session (/autoflow:cycle-%s%s).\n' \
    "$k" "$name" "$phases" "$k" "$k" "$lk" "$new" | wrap76
  printf 'argument-hint: "%s"\n---\n\n' "$hint"
  printf '%s\n\n' "$ROOT_DECL"
  if [ "$k" = U7 ]; then
    printf '**Scope** (`$ARGUMENTS`: `<N>`, or nothing) — unit %s, %s (%s), of a cycle alone: read where the cycle stands from the current state — `bash <autoflow-root>/scripts/preflight/cycle-status.sh`, with `--issue <N>` when given — run %s from there to its exit transition, and end the session with the report the invoking prompt asks for.\n\n' \
      "$k" "$name" "$phases" "$k"
  else
    if [ "$k" = U1 ]; then
      printf '**Scope** (`$ARGUMENTS`: `<N>`, `new` the request for a new attempt)'
    else
      printf '**Scope** (`$ARGUMENTS`: `<N>`)'
    fi
    printf ' — unit %s, %s (%s), of issue #N'"'"'s cycle alone: confirm from `bash <autoflow-root>/scripts/preflight/cycle-status.sh --issue <N>` that the cycle stands at %s'"'"'s entry (otherwise report the situation and stop), run %s from its entry to its exit transition, and end the session with the report the invoking prompt asks for.\n\n' \
      "$k" "$name" "$phases" "$k" "$k"
  fi
  printf '**The core in this body** — the parts of `<autoflow-root>/docs/core.md` that %s uses, by the classification `<autoflow-root>/scripts/skills/core-units.tsv`. Left out, and read in `<autoflow-root>/docs/core.md` when the work needs one: %s.\n\n' \
    "$k" "${out:-none}"
  unit_core "$k" < "$TMP/core.tagged" | strip_links
  printf '\n%s\n' "$GEN_NOTE"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
classify > "$TMP/core.tagged" || exit 1
if [ "$MODE" = core ]; then
  unit_core "$2" < "$TMP/core.tagged" | strip_links
  exit 0
fi
for _s in $BODIES; do mkdir -p "$TMP/$_s"; done
gen_cycle > "$TMP/cycle/SKILL.md"
for _k in $UNITS; do gen_unit "$_k" > "$TMP/cycle-$(printf '%s' "$_k" | tr 'U' 'u')/SKILL.md"; done
gen_criterion_review > "$TMP/criterion-review/SKILL.md"

rc=0
for _s in $BODIES; do
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
[ "$MODE" = check ] && [ "$rc" -eq 0 ] && echo "gen-skill-bodies: OK — every body under skills/ ($(echo $BODIES | tr ' ' ',')) equals the generator's output"
exit "$rc"
