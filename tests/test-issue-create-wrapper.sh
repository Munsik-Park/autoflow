#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/issue/create-issue.sh docs/issue-proposal.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: wrapper behavior (scripts/issue/create-issue.sh) under a corpus-backed,
#       argv-dispatching `gh` PATH shim — STANDING (issue #96 origin;
#       docs/doc-invariant-registry.md §10)
# =============================================================================
# Covers, per .autoflow/issue-96-verification-design.md's acceptance-criteria
# table:
#   Wrapper-Requires-Draft, Wrapper-Rejects-Absent-Autoflow-Dir,
#   Wrapper-Rejects-Draft-Outside-Autoflow, Wrapper-Rejects-Malformed-Draft,
#   Wrapper-Reruns-Dupcheck, Wrapper-Query-Recalls-Colliding-Issue,
#   Wrapper-Refuses-Underivable-Draft, Wrapper-Distrusts-Self-Report,
#   Wrapper-Query-Independent-Of-Recorded-Terms, Wrapper-Query-Locale-Stable,
#   Wrapper-Derivation-Not-Tunable, Wrapper-Query-Sequence-Stable-And-Additive,
#   Wrapper-Query-Not-Truncated, Wrapper-Rename-Binds-Create,
#   Wrapper-Create-Payload-Matches-Draft, Wrapper-Dry-Run-Creates-Nothing.
#
# Environment: this file MUST run under the shimmed `gh` on PATH
# (tests/issue-create/mock-gh-search/gh), which is exactly what the hook-side
# sibling tests/test-issue-create-gate.sh must NOT have — the split reason
# stated in the verification design (New spec files).
#
# The shim is corpus-backed and argv-dispatching (not canned): it answers
# `gh issue list --search <term>` from a seeded corpus of REAL issue titles
# measured from this tracker (tests/issue-create/fixtures/corpus.jsonl,
# `gh issue list --state all --limit 100` at RED time), matched by substring
# containment — an index built from the corpus alone, never from the
# wrapper's own derivation rule (verification design > Testability
# assessment). Issue #96's own title is corpus row `number":96`, and its
# title contains the noun "검토" ("review") verbatim — the fixture this file
# uses for the Korean-collision rows below.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="$PROJECT_ROOT/scripts/issue/create-issue.sh"
SHIM_DIR="$SCRIPT_DIR/issue-create/mock-gh-search"
CORPUS="$SCRIPT_DIR/issue-create/fixtures/corpus.jsonl"

PASS=0
FAIL=0

assert_true() {
  local desc="$1" condition="$2"
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

CLEANUP_TMP_DIRS=()
cleanup_all() {
  for d in "${CLEANUP_TMP_DIRS[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup_all EXIT

mktempd() {
  local d
  d=$(mktemp -d)
  CLEANUP_TMP_DIRS+=("$d")
  printf '%s' "$d"
}

# new_repo — a fresh git repo with a real .autoflow/ directory at its top level.
new_repo() {
  local r
  r=$(mktempd)
  git -C "$r" init -q
  mkdir -p "$r/.autoflow"
  printf '%s' "$r"
}

# write_draft <path> <title> <grounds anchor line> <searched line body>
#             <candidate lines or 'candidates: none'> <body text>
# Sections written in a NON-canonical order (Duplicate check first, Body
# before Grounds) — the grammar is order-independent (feature design §6).
write_draft() {
  local path="$1" title="$2" grounds="$3" searched="$4" candidates="$5" body="$6"
  cat > "$path" <<EOF
## Duplicate check
searched: $searched
$candidates

## Body
$body

## Title
$title

## Grounds
$grounds
EOF
}

# run_wrapper <cwd> <log-dir> <args...> — drives the real wrapper with the
# corpus shim on PATH. Sets WRAPPER_STATUS; recorded argv is $LOG_DIR/gh.log
# (blocks delimited by a literal "===CALL===" line). The repository itself is
# never a separate parameter: every caller's <cwd> already sits inside it (or
# is the repo root), which is what `git rev-parse --show-toplevel` resolves
# from — a distinct <repo> argument was carried but never read (SC2034).
export GH_SEARCH_CORPUS="$CORPUS"
run_wrapper() {
  local cwd="$1" logdir="$2"; shift 2
  export GH_INVOCATION_LOG="$logdir/gh.log"
  : > "$GH_INVOCATION_LOG"
  ( cd "$cwd" && PATH="$SHIM_DIR:$PATH" "$WRAPPER" "$@" ) >"$logdir/out.log" 2>"$logdir/err.log"
  WRAPPER_STATUS=$?
}

# creation_call_count <log-file> — number of "===CALL===" blocks whose first
# two argv lines are "issue" then "create".
creation_call_count() {
  awk '
    /^===CALL===$/ { if (a1=="create" && a0=="issue") n++; a0=""; a1=""; c=0; next }
    { c++; if (c==1) a0=$0; else if (c==2) a1=$0 }
    END { if (a1=="create" && a0=="issue") n++; print n+0 }
  ' "$1" 2>/dev/null
}

# normalize_gh_log <log-file> — prints the log with the value following each
# --body-file token masked to a fixed placeholder. The wrapper writes its
# payload to a FRESH tmp file every invocation (by design — the file need not
# survive the run, verification design > Testability assessment), so that one
# line differs run-to-run even when the QUERY sequence a "determinism" /
# "locale-stable" row is actually about is byte-identical. Comparing raw logs
# treats that expected, irrelevant instability as a false defect.
normalize_gh_log() {
  awk '
    prev == "--body-file" { print "<tmp-body-file>"; prev=$0; next }
    { print; prev=$0 }
  ' "$1"
}

# search_call_count_for_term <log-file> <term> — number of "issue list"
# blocks whose --search value equals <term>.
search_call_count_for_term() {
  awk -v want="$2" '
    /^===CALL===$/ { if (issue=="issue" && list=="list" && term==want) n++;
                      issue=""; list=""; term=""; prevtoken=""; c=0; next }
    { c++;
      if (c==1) issue=$0; else if (c==2) list=$0;
      if (prevtoken=="--search") term=$0;
      prevtoken=$0 }
    END { if (issue=="issue" && list=="list" && term==want) n++; print n+0 }
  ' "$1" 2>/dev/null
}

echo "=== issue #96 — Wrapper-Requires-Draft ==="
R1=$(new_repo)
run_wrapper "$R1" "$R1"
assert_true "no --draft argument exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "no --draft argument creates nothing" "[ \"\$(creation_call_count "$R1/gh.log")\" -eq 0 ]"

D1B="$R1/.autoflow/valid.md"
write_draft "$D1B" "some title words here" "path/to/file.sh:10" "zzqxxvterm" "candidates: none" "body text"
run_wrapper "$R1" "$R1" --draft "$D1B" --repo
assert_true "--repo with no following value exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "--repo with no following value creates nothing" "[ \"\$(creation_call_count "$R1/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper preconditions: not a git repository, missing/symlinked draft (VERIFY minimal-implementation follow-up) ==="
NOTGIT=$(mktempd)   # a plain directory, never `git init`
mkdir -p "$NOTGIT/.autoflow"
D_NOTGIT="$NOTGIT/.autoflow/draft.md"
write_draft "$D_NOTGIT" "some title words here" "path/to/file.sh:10" "zzqxxvterm" "candidates: none" "body text"
run_wrapper "$NOTGIT" "$NOTGIT" --draft "$D_NOTGIT"
assert_true "outside any git repository: exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "outside any git repository: creates nothing" "[ \"\$(creation_call_count "$NOTGIT/gh.log")\" -eq 0 ]"

R1C=$(new_repo)
run_wrapper "$R1C" "$R1C" --draft "$R1C/.autoflow/does-not-exist.md"
assert_true "a --draft path that does not exist exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "a --draft path that does not exist creates nothing" "[ \"\$(creation_call_count "$R1C/gh.log")\" -eq 0 ]"

D_LINK_TARGET="$R1C/target-outside.md"
write_draft "$D_LINK_TARGET" "some title words here" "path/to/file.sh:10" "zzqxxvterm" "candidates: none" "body text"
D_LINK="$R1C/.autoflow/symlink-draft.md"
ln -s "$D_LINK_TARGET" "$D_LINK"
run_wrapper "$R1C" "$R1C" --draft "$D_LINK"
assert_true "a symlinked draft is refused, not resolved: exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "a symlinked draft: creates nothing" "[ \"\$(creation_call_count "$R1C/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper-Rejects-Absent-Autoflow-Dir ==="
R2=$(mktempd); git -C "$R2" init -q   # deliberately NO mkdir .autoflow
OUTSIDE_DRAFT="$R2/somewhere-else.md"
write_draft "$OUTSIDE_DRAFT" "some title words here" "path/to/file.sh:10" "zzqxxvterm" "candidates: none" "body text"
run_wrapper "$R2" "$R2" --draft "$OUTSIDE_DRAFT"
assert_true "absent .autoflow: exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "absent .autoflow: creates nothing" "[ \"\$(creation_call_count "$R2/gh.log")\" -eq 0 ]"
assert_true "absent .autoflow: directory is NOT created as a side effect" "[ ! -d '$R2/.autoflow' ]"
ABSENT_MSG=$(cat "$R2/err.log" 2>/dev/null)
# The message text is compared via a deferred variable reference (resolved at
# eval time), not interpolated into the condition string — a "'" in the
# wrapper's own stderr text would otherwise break the quoting of the eval'd
# condition itself.
# The directory the message names is the PHYSICAL resolution of $R2 (the
# wrapper resolves its repo root with `cd -P`), which on macOS differs from
# the raw mktemp path (/var/folders/... is itself a symlink to
# /private/var/folders/...) — resolve the same way before comparing, or the
# assertion spuriously fails on a platform where $R2 is already physical.
R2_PHYS="$(cd -P "$R2" && pwd)"
assert_true "absent .autoflow: stderr NAMES the missing directory" \
  "printf '%s' \"\$ABSENT_MSG\" | grep -qF '$R2_PHYS/.autoflow'"
assert_true "absent .autoflow: stderr says the draft is to be written there" \
  "printf '%s' \"\$ABSENT_MSG\" | grep -qi 'write the draft'"

echo ""
echo "=== issue #96 — Wrapper-Rejects-Draft-Outside-Autoflow ==="
R3=$(new_repo)
mkdir -p "$R3/.autoflow/fixtures" "$R3/.autoflow/subdir"
OUTSIDE1="$R3/.autoflow/fixtures/draft.md"     # fixtures/ subdir — different archive slot
OUTSIDE2="$R3/.autoflow/subdir/draft.md"       # arbitrary subdir — swept by nothing
OUTSIDE3="$R3/../draft-outside-repo.md"        # outside the repository entirely
for f in "$OUTSIDE1" "$OUTSIDE2" "$OUTSIDE3"; do
  write_draft "$f" "some title words here" "path/to/file.sh:10" "zzqxxvterm" "candidates: none" "body text"
done
run_wrapper "$R3" "$R3" --draft "$OUTSIDE1"
assert_true "fixtures/ subdir draft: exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "fixtures/ subdir draft: creates nothing" "[ \"\$(creation_call_count "$R3/gh.log")\" -eq 0 ]"
OUTSIDE_FIXTURES_MSG=$(cat "$R3/err.log" 2>/dev/null)
R3_PHYS="$(cd -P "$R3" && pwd)"
assert_true "fixtures/ subdir draft: stderr NAMES the required directory" \
  "printf '%s' \"\$OUTSIDE_FIXTURES_MSG\" | grep -qF '$R3_PHYS/.autoflow'"

run_wrapper "$R3" "$R3" --draft "$OUTSIDE2"
assert_true "arbitrary subdir draft: exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "arbitrary subdir draft: creates nothing" "[ \"\$(creation_call_count "$R3/gh.log")\" -eq 0 ]"

run_wrapper "$R3" "$R3" --draft "$OUTSIDE3"
assert_true "outside-repo draft: exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "outside-repo draft: creates nothing" "[ \"\$(creation_call_count "$R3/gh.log")\" -eq 0 ]"

assert_true "the outside-autoflow message differs from the absent-.autoflow message (paired assertion)" \
  "[ \"\$ABSENT_MSG\" != \"\$OUTSIDE_FIXTURES_MSG\" ]"

echo ""
echo "=== issue #96 — Wrapper-Rejects-Malformed-Draft ==="
R4=$(new_repo)
D_NOTITLE="$R4/.autoflow/no-title.md"
cat > "$D_NOTITLE" <<'EOF'
## Duplicate check
searched: zzqxxvterm
candidates: none

## Body
body text

## Grounds
path/to/file.sh:10
EOF
run_wrapper "$R4" "$R4" --draft "$D_NOTITLE"
assert_true "missing ## Title: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "missing ## Title: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

D_NOGROUNDS="$R4/.autoflow/no-grounds.md"
cat > "$D_NOGROUNDS" <<'EOF'
## Title
some title words here

## Duplicate check
searched: zzqxxvterm
candidates: none

## Body
body text
EOF
run_wrapper "$R4" "$R4" --draft "$D_NOGROUNDS"
assert_true "missing ## Grounds section entirely: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "missing ## Grounds section entirely: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

D_NOANCHOR="$R4/.autoflow/no-anchor.md"
write_draft "$D_NOANCHOR" "some title words here" "no anchor in this sentence at all" "zzqxxvterm" "candidates: none" "body text"
run_wrapper "$R4" "$R4" --draft "$D_NOANCHOR"
assert_true "grounds with no anchor: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "grounds with no anchor: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

D_NOSEARCHED="$R4/.autoflow/no-searched.md"
cat > "$D_NOSEARCHED" <<'EOF'
## Title
some title words here

## Grounds
path/to/file.sh:10

## Duplicate check
candidates: none

## Body
body text
EOF
run_wrapper "$R4" "$R4" --draft "$D_NOSEARCHED"
assert_true "missing searched: line: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "missing searched: line: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

D_NOBODY="$R4/.autoflow/no-body.md"
cat > "$D_NOBODY" <<'EOF'
## Title
some title words here

## Grounds
path/to/file.sh:10

## Duplicate check
searched: zzqxxvterm
candidates: none
EOF
run_wrapper "$R4" "$R4" --draft "$D_NOBODY"
assert_true "missing ## Body: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "missing ## Body: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

D_EMPTYTITLE="$R4/.autoflow/empty-title.md"
cat > "$D_EMPTYTITLE" <<'EOF'
## Title

## Grounds
path/to/file.sh:10

## Duplicate check
searched: zzqxxvterm
candidates: none

## Body
body text
EOF
run_wrapper "$R4" "$R4" --draft "$D_EMPTYTITLE"
assert_true "## Title present but empty: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "## Title present but empty: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

D_EMPTYBODY="$R4/.autoflow/empty-body.md"
cat > "$D_EMPTYBODY" <<'EOF'
## Title
some title words here

## Grounds
path/to/file.sh:10

## Duplicate check
searched: zzqxxvterm
candidates: none

## Body
EOF
run_wrapper "$R4" "$R4" --draft "$D_EMPTYBODY"
assert_true "## Body present but empty: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "## Body present but empty: creates nothing" "[ \"\$(creation_call_count "$R4/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper-Reruns-Dupcheck (one query per term, unioned — not a joined string) ==="
R5=$(new_repo)
D5="$R5/.autoflow/two-term-draft.md"
write_draft "$D5" "zzqxxvalpha zzqxxvbeta" "path/to/file.sh:10" "zzqxxvalpha zzqxxvbeta" "candidates: none" "body text"
run_wrapper "$R5" "$R5" --draft "$D5"
assert_true "two-term title: a --search call for the first term exists" \
  "[ \"\$(search_call_count_for_term "$R5/gh.log" zzqxxvalpha)\" -ge 1 ]"
assert_true "two-term title: a --search call for the second term exists" \
  "[ \"\$(search_call_count_for_term "$R5/gh.log" zzqxxvbeta)\" -ge 1 ]"
# Scoped to "issue list" blocks only: the joined string legitimately appears
# elsewhere in the log as the create call's own --title argv (the draft's
# whole title, byte-for-byte — Wrapper-Create-Payload-Matches-Draft), which
# is a different call and not the joined-into-one---search-argument defect
# this assertion exists to catch.
assert_true "two-term title: no 'issue list' call joins both terms in one --search argument" \
  "! awk '
     /^===CALL===\$/ { if (a0==\"issue\" && a1==\"list\" && joined==1) { print \"joined\"; exit 1 }; a0=\"\"; a1=\"\"; joined=0; c=0; next }
     { c++; if (c==1) a0=\$0; else if (c==2) a1=\$0;
       if (\$0 == \"zzqxxvalpha zzqxxvbeta\") joined=1 }
     END { if (a0==\"issue\" && a1==\"list\" && joined==1) { print \"joined\"; exit 1 } }
   ' '$R5/gh.log' | grep -q joined"
# per-term calls precede any create call: the last search call's line number
# in the log is before the first create call's line number, or there is no
# create call at all (a clean check with no candidates still creates — this
# assertion only orders the two kinds of call relative to each other).
LAST_SEARCH_LINE=$(grep -n '^list$' "$R5/gh.log" 2>/dev/null | tail -1 | cut -d: -f1)
FIRST_CREATE_LINE=$(awk '/^===CALL===$/{getline a; getline b; if(a=="issue" && b=="create"){print NR; exit}}' "$R5/gh.log")
assert_true "per-term queries precede any creation call" \
  "[ -z \"$FIRST_CREATE_LINE\" ] || [ -z \"$LAST_SEARCH_LINE\" ] || [ \"$LAST_SEARCH_LINE\" -lt \"$FIRST_CREATE_LINE\" ]"

echo ""
echo "=== issue #96 — Wrapper-Query-Recalls-Colliding-Issue ==="
R6=$(new_repo)
# (i) Korean paraphrase sharing the substantive noun 검토 ("review") with
# corpus issue #96's own title; searched: line names only non-colliding terms.
D6A="$R6/.autoflow/korean-collision.md"
write_draft "$D6A" "AI가 스스로 검토했다고 주장하는 파일링 방지" "path/to/file.sh:10" "zzqxxvnothing plughcode" "candidates: none" "body text"
run_wrapper "$R6" "$R6" --draft "$D6A"
assert_true "Korean collision on a shared noun (검토): exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "Korean collision: the refusal names issue 96" "grep -qE '#96\b' '$R6/err.log' 2>/dev/null"
assert_true "Korean collision: creates nothing" "[ \"\$(creation_call_count "$R6/gh.log")\" -eq 0 ]"

# (ii) a bracket tag shared by many corpus rows, with content words that
# collide with none of them — not refused on the tag alone.
D6B="$R6/.autoflow/tag-only-shared.md"
write_draft "$D6B" "[fix] zzqxxvgamma zzqxxvdelta" "path/to/file.sh:10" "zzqxxvgamma zzqxxvdelta" "candidates: none" "body text"
GH_CREATE_URL="https://github.com/example/repo/issues/777" run_wrapper "$R6" "$R6" --draft "$D6B"
assert_true "tag-only collision: NOT refused merely for reusing a common tag (exit 0)" "[ \"$WRAPPER_STATUS\" -eq 0 ]"
assert_true "tag-only collision: a creation call was issued" "[ \"\$(creation_call_count "$R6/gh.log")\" -eq 1 ]"

echo ""
echo "=== issue #96 — Wrapper-Refuses-Underivable-Draft ==="
R7=$(new_repo)
D7="$R7/.autoflow/underivable.md"
# after the bracket tag is stripped: "a b c 力" — three ASCII tokens below the
# 4-codepoint floor and one single-codepoint non-ASCII token below the
# 2-codepoint floor: nothing survives derivation.
write_draft "$D7" "[fix] a b c 力" "path/to/file.sh:10" "zzqxxvnomatch" "candidates: none" "body text"
run_wrapper "$R7" "$R7" --draft "$D7"
assert_true "underivable title: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "underivable title: message names the title" "grep -qF 'a b c 力' '$R7/err.log' 2>/dev/null"
assert_true "underivable title: creates nothing" "[ \"\$(creation_call_count "$R7/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper-Distrusts-Self-Report ==="
R8=$(new_repo)
D8="$R8/.autoflow/self-report.md"
write_draft "$D8" "검토 절차를 스스로 마쳤다고 기록한 초안" "path/to/file.sh:10" "zzqxxvunrelated" "candidates: none  # reviewed, no duplicates found" "body text"
run_wrapper "$R8" "$R8" --draft "$D8"
assert_true "self-report ignored: the wrapper's own query still surfaces the collision (exit 65)" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "self-report ignored: the refusal names issue 96" "grep -qE '#96\b' '$R8/err.log' 2>/dev/null"
assert_true "self-report ignored: creates nothing" "[ \"\$(creation_call_count "$R8/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper-Query-Independent-Of-Recorded-Terms ==="
R9=$(new_repo)
D9="$R9/.autoflow/independent-run1.md"
write_draft "$D9" "검토 없이 zzqxxvepsilon 이슈가 파일링됨" "path/to/file.sh:10" "zzqxxvepsilon 없이" "candidates: none" "body text"
run_wrapper "$R9" "$R9" --draft "$D9"
assert_true "run 1 (recorded line omits 검토): the title-derived term is still queried" \
  "[ \"\$(search_call_count_for_term "$R9/gh.log" 검토)\" -ge 1 ]"
assert_true "run 1: the collision is recalled regardless (exit 65)" "[ \"$WRAPPER_STATUS\" -eq 65 ]"

D9B="$R9/.autoflow/independent-run2.md"
write_draft "$D9B" "검토 없이 zzqxxvepsilon 이슈가 파일링됨" "path/to/file.sh:10" "zzqxxvnothingatall" "candidates: none" "body text"
run_wrapper "$R9" "$R9" --draft "$D9B"
assert_true "run 2 (recorded line names a term in neither title nor corpus): the title-derived term is still queried" \
  "[ \"\$(search_call_count_for_term "$R9/gh.log" 검토)\" -ge 1 ]"
assert_true "run 2: the collision is recalled regardless (exit 65)" "[ \"$WRAPPER_STATUS\" -eq 65 ]"

echo ""
echo "=== issue #96 — Wrapper-Query-Locale-Stable ==="
R10=$(new_repo)
D10="$R10/.autoflow/locale-token.md"
# 한 is a single UTF-8 codepoint (3 bytes) — wc -m counts it 3 under LC_ALL=C
# and 1 under a UTF-8 locale (verification design premise), so a wc -m-based
# floor check derives a DIFFERENT query per locale; a locale-free byte count
# derives the SAME query (dropping the token either way, since 1 < the
# non-ASCII floor of 2).
write_draft "$D10" "[chore] 한 zzqxxvzeta" "path/to/file.sh:10" "zzqxxvzeta" "candidates: none" "body text"
# A successful run RENAMES its draft away (Wrapper-Rename-Binds-Create), so
# comparing two runs of "the same draft" needs a FRESH copy per run — reusing
# one path means the second run's --draft no longer exists after the first
# run's rename, which is a different fixture defect than locale, not a
# genuine same-input comparison.
D10_C="$R10/.autoflow/locale-token-c.md"
D10_UTF8="$R10/.autoflow/locale-token-utf8.md"
cp "$D10" "$D10_C"
cp "$D10" "$D10_UTF8"
LOGDIR_C=$(mktempd); LOGDIR_UTF8=$(mktempd)
LC_ALL=C run_wrapper "$R10" "$LOGDIR_C" --draft "$D10_C"
STATUS_C="$WRAPPER_STATUS"
LC_ALL=C.UTF-8 run_wrapper "$R10" "$LOGDIR_UTF8" --draft "$D10_UTF8"
STATUS_UTF8="$WRAPPER_STATUS"
assert_true "locale-stable: the same draft exits the same code under C and UTF-8 locales" \
  "[ \"$STATUS_C\" -eq \"$STATUS_UTF8\" ]"
assert_true "locale-stable: the recorded argv sequence is identical across locales (--body-file's own fresh-tmp-path masked)" \
  "diff -q <(normalize_gh_log '$LOGDIR_C/gh.log') <(normalize_gh_log '$LOGDIR_UTF8/gh.log') >/dev/null 2>&1"

echo ""
echo "=== issue #96 — Wrapper-Derivation-Not-Tunable ==="
R11=$(new_repo)
D11="$R11/.autoflow/tunable-attempt.md"
write_draft "$D11" "some title words here" "path/to/file.sh:10" "zzqxxvterm" "candidates: none" "body text"
run_wrapper "$R11" "$R11" --draft "$D11" --term-cap 20
assert_true "an unrecognised flag exits 64" "[ \"$WRAPPER_STATUS\" -eq 64 ]"
assert_true "an unrecognised flag creates nothing" "[ \"\$(creation_call_count "$R11/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper-Query-Sequence-Stable-And-Additive ==="
R12=$(new_repo)
D12="$R12/.autoflow/stable-run.md"
write_draft "$D12" "zzqxxvalpha zzqxxvbeta" "path/to/file.sh:10" "zzqxxvalpha" "candidates: none" "body text"
# Fresh copy per run — a successful run renames its draft away (same reason
# as the locale-stable fix above), so comparing "two runs of the identical
# draft" needs two distinct on-disk copies, not one path run twice.
D12A="$R12/.autoflow/stable-run-a.md"
D12B="$R12/.autoflow/stable-run-b.md"
cp "$D12" "$D12A"
cp "$D12" "$D12B"
LOG12A=$(mktempd); LOG12B=$(mktempd)
run_wrapper "$R12" "$LOG12A" --draft "$D12A"
run_wrapper "$R12" "$LOG12B" --draft "$D12B"
assert_true "determinism: two runs of the identical draft produce the identical argv sequence (--body-file's own fresh-tmp-path masked)" \
  "diff -q <(normalize_gh_log '$LOG12A/gh.log') <(normalize_gh_log '$LOG12B/gh.log') >/dev/null 2>&1"

D12W="$R12/.autoflow/wider-run.md"
write_draft "$D12W" "zzqxxvalpha zzqxxvbeta" "path/to/file.sh:10" "zzqxxvalpha zzqxxvbeta zzqxxvextra" "candidates: none" "body text"
LOG12W=$(mktempd)
run_wrapper "$R12" "$LOG12W" --draft "$D12W"
assert_true "additivity: the search term added only via a wider searched: line is now queried too" \
  "[ \"\$(search_call_count_for_term "$LOG12W/gh.log" zzqxxvextra)\" -ge 1 ]"
assert_true "additivity: every term queried by the narrower run is still queried by the wider run" \
  "[ \"\$(search_call_count_for_term "$LOG12W/gh.log" zzqxxvalpha)\" -ge 1 ] && [ \"\$(search_call_count_for_term "$LOG12W/gh.log" zzqxxvbeta)\" -ge 1 ]"

echo ""
echo "=== issue #96 — Wrapper-Query-Not-Truncated ==="
R13=$(new_repo)
D13="$R13/.autoflow/truncation.md"
write_draft "$D13" "[chore] zzqxxvtruncationterm" "path/to/file.sh:10" "zzqxxvtruncationterm" "candidates: none" "body text"
GH_FULL_PAGE_TERMS="zzqxxvtruncationterm" run_wrapper "$R13" "$R13" --draft "$D13"
assert_true "a full-page term refuses rather than creating: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "the refusal names the truncated term" "grep -qF 'zzqxxvtruncationterm' '$R13/err.log' 2>/dev/null"
assert_true "a full-page term: creates nothing" "[ \"\$(creation_call_count "$R13/gh.log")\" -eq 0 ]"

echo ""
echo "=== issue #96 — Wrapper-Rename-Binds-Create + Wrapper-Create-Payload-Matches-Draft + Wrapper-Dry-Run-Creates-Nothing ==="
R14=$(new_repo)
mkdir -p "$R14/sub"
D14="$R14/.autoflow/issue-proposal-demo.md"
BODY_TEXT="This is the proposed issue body.
It has more than one line."
# Title deliberately uses the zzqxxv* non-colliding idiom (as D5/D6B/D12 do):
# this row is about payload/rename binding, not retrieval, so the title must
# derive terms that retrieve nothing from the corpus — a real-word title
# (e.g. "The exact title line") derives "line", which the corpus's own
# issue #8 ("...one-liner...") is recalled on under --state all, turning this
# into an unwanted strict-disposition refusal instead of a create.
write_draft "$D14" "zzqxxvrenametitle zzqxxvpayloadtitle" "path/to/file.sh:10" "zzqxxvrename" "candidates: none" "$BODY_TEXT"
cp "$D14" "$R14/.autoflow/issue-proposal-demo.md.orig"

BODY_CAPTURE=$(mktempd)/captured-body.md
# (i) successful create, driven from a NON-root working directory.
GH_CREATE_URL="https://github.com/example/repo/issues/555" GH_CREATE_BODY_CAPTURE="$BODY_CAPTURE" \
  run_wrapper "$R14/sub" "$R14" --draft "$D14"
assert_true "successful create: exits 0" "[ \"$WRAPPER_STATUS\" -eq 0 ]"
assert_true "successful create: the draft no longer exists at its original path" "[ ! -f '$D14' ]"
assert_true "successful create: renamed to issue-555-proposal.md at the top level of .autoflow" \
  "[ -f '$R14/.autoflow/issue-555-proposal.md' ]"
assert_true "successful create: renamed content is byte-identical to the original draft" \
  "diff -q '$R14/.autoflow/issue-555-proposal.md' '$R14/.autoflow/issue-proposal-demo.md.orig' >/dev/null 2>&1"
assert_true "payload: --title carries the draft's ## Title line byte-for-byte" \
  "ctx=\$(grep -A1 -- '--title' '$R14/gh.log'); printf '%s\n' \"\$ctx\" | grep -qFx 'zzqxxvrenametitle zzqxxvpayloadtitle'"
assert_true "payload: the body-file bytes equal the draft's ## Body section verbatim" \
  "diff -q '$BODY_CAPTURE' <(printf '%s\n' \"$BODY_TEXT\") >/dev/null 2>&1"
assert_true "payload: the body-file carries no Grounds/Duplicate-check text" \
  "! grep -qF 'path/to/file.sh:10' '$BODY_CAPTURE' && ! grep -qF 'zzqxxvrename' '$BODY_CAPTURE'"

# (ii) --dry-run — every check passes, nothing is created, nothing renamed.
D14B="$R14/.autoflow/issue-proposal-dryrun.md"
write_draft "$D14B" "dry run title" "path/to/file.sh:11" "zzqxxvdryrun" "candidates: none" "dry run body"
run_wrapper "$R14" "$R14" --draft "$D14B" --dry-run
assert_true "dry-run: exits 0" "[ \"$WRAPPER_STATUS\" -eq 0 ]"
assert_true "dry-run: creates nothing" "[ \"\$(creation_call_count "$R14/gh.log")\" -eq 0 ]"
assert_true "dry-run: the draft is left in place" "[ -f '$D14B' ]"
assert_true "dry-run: no numbered proposal file exists anywhere under .autoflow" \
  "[ -z \"\$(find '$R14/.autoflow' -name 'issue-*-proposal.md' ! -name 'issue-555-proposal.md')\" ]"

# (iii) a 65 refusal leaves the draft untouched (malformed draft, reused shape).
D14C="$R14/.autoflow/issue-proposal-malformed.md"
write_draft "$D14C" "malformed title" "no anchor here" "zzqxxvmalformed" "candidates: none" "malformed body"
run_wrapper "$R14" "$R14" --draft "$D14C"
assert_true "refusal: the draft is left in place" "[ -f '$D14C' ]"
assert_true "refusal: no numbered proposal file was created for it" \
  "[ -z \"\$(find '$R14/.autoflow' -maxdepth 1 -name 'issue-*-proposal.md' -newer '$D14C' 2>/dev/null)\" ]"

# (iv) a non-zero gh create exit propagates and leaves the draft untouched.
D14D="$R14/.autoflow/issue-proposal-ghfail.md"
write_draft "$D14D" "gh failure title" "path/to/file.sh:12" "zzqxxvghfail" "candidates: none" "gh failure body"
GH_CREATE_EXIT=7 run_wrapper "$R14" "$R14" --draft "$D14D"
assert_true "gh failure: propagates a non-zero exit" "[ \"$WRAPPER_STATUS\" -ne 0 ]"
assert_true "gh failure: the draft is left in place" "[ -f '$D14D' ]"

# (v) a create URL with no parsable trailing number is a failed bind.
D14E="$R14/.autoflow/issue-proposal-nonumber.md"
write_draft "$D14E" "no number url title" "path/to/file.sh:13" "zzqxxvnonumber" "candidates: none" "no number url body"
GH_CREATE_URL="https://github.com/example/repo/issues/not-a-number" run_wrapper "$R14" "$R14" --draft "$D14E"
assert_true "unparsable URL: exits non-zero" "[ \"$WRAPPER_STATUS\" -ne 0 ]"
assert_true "unparsable URL: the draft is left in place (no guessed rename)" "[ -f '$D14E' ]"
assert_true "unparsable URL: no new numbered proposal file was created" \
  "[ -z \"\$(find '$R14/.autoflow' -maxdepth 1 -name 'issue-*-proposal.md' -newer '$D14E' 2>/dev/null)\" ]"

echo ""
echo "=== issue #96 — the duplicate query itself failing (VERIFY minimal-implementation follow-up) ==="
R15=$(new_repo)
D15="$R15/.autoflow/list-fail.md"
write_draft "$D15" "[chore] zzqxxvlistfailterm" "path/to/file.sh:10" "zzqxxvlistfailterm" "candidates: none" "body text"
GH_LIST_FAIL_TERMS="zzqxxvlistfailterm" run_wrapper "$R15" "$R15" --draft "$D15"
assert_true "a failed 'gh issue list' query refuses rather than treating it as zero candidates: exits 65" "[ \"$WRAPPER_STATUS\" -eq 65 ]"
assert_true "a failed query names the term it was querying" "grep -qF 'zzqxxvlistfailterm' '$R15/err.log' 2>/dev/null"
assert_true "a failed query: creates nothing" "[ \"\$(creation_call_count "$R15/gh.log")\" -eq 0 ]"
assert_true "a failed query: the draft is left in place" "[ -f '$D15' ]"

echo ""
echo "=== issue #96 — the post-create rename failing (VERIFY minimal-implementation follow-up) ==="
R16=$(new_repo)
D16="$R16/.autoflow/rename-fail.md"
write_draft "$D16" "zzqxxvrenamefailalpha zzqxxvrenamefailbeta" "path/to/file.sh:10" "zzqxxvrenamefailalpha" "candidates: none" "body text"
chmod 555 "$R16/.autoflow"   # the wrapper's own creation succeeds; only the rename's mv is denied
GH_CREATE_URL="https://github.com/example/repo/issues/888" run_wrapper "$R16" "$R16" --draft "$D16"
RENAME_FAIL_STATUS="$WRAPPER_STATUS"
chmod 755 "$R16/.autoflow"   # restore before this script's own cleanup trap removes the tree
assert_true "a create that succeeds but cannot rename its draft: exits non-zero (never silently reports success)" "[ \"$RENAME_FAIL_STATUS\" -ne 0 ]"
assert_true "a create that succeeds but cannot rename: a creation call WAS issued (this is a post-create failure, not a refusal)" "[ \"\$(creation_call_count "$R16/gh.log")\" -eq 1 ]"
assert_true "a create that succeeds but cannot rename: the original draft is still readable (rename did not silently drop content)" "[ -f '$D16' ]"

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
