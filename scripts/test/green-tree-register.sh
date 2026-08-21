#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# green-tree-register.sh — the ONE writer of a Green-tree certificate, and the
# query surface the tree-identity predicate's shared arm is answered from.
# =============================================================================
# RED STATE (issue #130): this file currently carries its `--self-test` harness
# ONLY. Every production subcommand below is unimplemented and the dispatcher
# refuses it, which is what makes the legs fail. GREEN implements the
# subcommands in this same file; the self-test section is the Test AI's.
#
# Usage (the surface the legs drive — feature design > Writer):
#   green-tree-register.sh --append --root <dir> --ledger <path> --issue <N> \
#                          --cycle <C> --runner "<PHASE> step <S>" \
#                          --tree <hash> --head <hash> --result "<line>" \
#                          --suites "<path> [<path> ...]"
#   green-tree-register.sh --match  --root <dir> [--cover-enumerated]
#   green-tree-register.sh --store-path --root <dir>
#   green-tree-register.sh --prune  --root <dir> [--keep <n>]
#   green-tree-register.sh --self-test
#
# Exit: 0 normal, 1 refusal or no match, 2 usage, 65 when the store resolves
#       inside the repository tree (the archive path's own refusal code — it is
#       literally the same guard, called rather than mirrored).
#
# WHY THE WRITE SIDE NEEDS ITS OWN ORACLE. Every property asserted below is a
# WRITE property: the dirty-worktree and tree/head-drift refusals, the two
# stores naming the same suites with the same hashes, an interrupted append
# leaving no half-entry, and `--prune` retaining the right entries. The
# resolver's own `--self-test` fabricates its entries and emits its plan with
# no writer invocation on any path, so it cannot observe a certificate minted
# for a tree that never ran; the agreement layer reads artifacts rather than
# running either side. `--match` joins them because that query IS the shared
# arm of the tree-identity predicate — its answer becomes an `outcome:
# inherited` record directly, with no resolver in between.
#
# HERMETICITY. Every leg sets $AUTOFLOW_ARCHIVE_ROOT to a scratch directory of
# its own. The store root otherwise defaults into the operator's real home
# directory, where a leg would both read genuine prior-cycle certificates and
# mutate production inheritance state.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_WRAPPER="$SCRIPT_DIR/../cleanup/cleanup-issue.sh"
SELF="$SCRIPT_DIR/green-tree-register.sh"

# ---------------------------------------------------------------------------
# Self-test — hermetic fixture repositories and scratch stores whose answer is
# known by construction.
# ---------------------------------------------------------------------------
SELFTEST_RC=0
st_fail() { echo "green-tree-register: --self-test $1 FAILED — $2"; SELFTEST_RC=1; }
st_ok()   { echo "green-tree-register: --self-test $1 OK — $2"; }

# gtr_fixture_repo <dir> — a git repo with three suites and a shared library,
# on a `work` branch off `main`, with `.autoflow/` ignored exactly as a real
# checkout ignores it (an unignored fixture ledger makes every capture point
# dirty and no leg could reach the branch it tests).
gtr_fixture_repo() {
  local d="$1" n
  mkdir -p "$d/tests/lib" "$d/docs" "$d/.autoflow"
  for n in a b c; do
    cat > "$d/tests/test-fx-gtr-$n.sh" <<SH
#!/usr/bin/env bash
# ci-subject: docs/subject-$n.md
# lane: standing
# budget-secs: 5
true
SH
    printf '%s\n' 'x' > "$d/docs/subject-$n.md"
  done
  printf '%s\n' '# shared' > "$d/tests/lib/harness.sh"
  printf '%s\n' '.autoflow/' > "$d/.gitignore"
  git -C "$d" init -q -b main >/dev/null 2>&1
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m base >/dev/null 2>&1
  git -C "$d" checkout -q -b work >/dev/null 2>&1
}

# gtr_store_path <archive-root> <dir> — the shared register path, located
# through the SHIPPED key derivation taken with its CWD at the fixture root.
# Deliberately NOT located through `--store-path`: a leg that used the surface
# under test to find the file it then asserts about would agree with a broken
# resolution instead of catching it.
gtr_store_path() {
  local key; key="$(cd "$2" && bash "$CLEANUP_WRAPPER" --print-repo-key 2>/dev/null)"
  printf '%s/%s/green-trees/register.md' "$1" "$key"
}

gtr_store_init() { # <archive-root> <dir> -> creates and echoes an empty store
  local p; p="$(gtr_store_path "$1" "$2")"
  mkdir -p "$(dirname "$p")"
  : > "$p"
  printf '%s' "$p"
}

# gtr_shared_entry <store> <issue> <cycle> <tree> <head> <suites> [result]
gtr_shared_entry() {
  {
    printf '### green-tree-shared | issue: #%s | cycle: %s | runner: VERIFY step 1\n' "$2" "$3"
    printf -- '- tree: %s\n' "$4"
    printf -- '- head: %s\n' "$5"
    printf -- '- worktree: clean\n'
    printf -- '- suites: %s\n' "$6"
    printf -- '- result: %s\n' "${7:-run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed}"
    printf -- '- authority: Green-tree register (shared store)\n'
    printf '\n'
  } >> "$1"
}

# gtr_run <archive-root> — fills GTR_OUT / GTR_ERR / GTR_RC from the remaining
# arguments, with the store root redirected.
gtr_run() {
  local ar="$1"; shift
  local err; err="$(mktemp)"
  GTR_OUT="$(AUTOFLOW_ARCHIVE_ROOT="$ar" bash "$SELF" "$@" 2>"$err")"
  GTR_RC=$?
  GTR_ERR="$(cat "$err")"
  rm -f "$err"
}

# gtr_field <file> <heading-grep> <field> — a field value of the entry under
# the first heading matching <heading-grep>.
gtr_field() {
  awk -v pat="$2" -v key="- $3: " '
    index($0, pat) == 1 { inb = 1; next }
    inb && index($0, key) == 1 { print substr($0, length(key) + 1); exit }
    inb && /^#/ { exit }
  ' "$1"
}

# gtr_entry_count <file> <marker>
gtr_entry_count() { grep -cF "$2" "$1" 2>/dev/null || true; }

# gtr_wellformed <file> <marker> — every entry under <marker> carries all six
# fields. This is the observable form of "no half-entry survives".
gtr_wellformed() {
  local f="$1" marker="$2" n_head n_tree n_hd n_wt n_su n_re n_au
  n_head="$(grep -cF "$marker" "$f" 2>/dev/null || true)"
  n_tree="$(grep -c '^- tree: ' "$f" 2>/dev/null || true)"
  n_hd="$(grep -c '^- head: ' "$f" 2>/dev/null || true)"
  n_wt="$(grep -c '^- worktree: ' "$f" 2>/dev/null || true)"
  n_su="$(grep -c '^- suites: ' "$f" 2>/dev/null || true)"
  n_re="$(grep -c '^- result: ' "$f" 2>/dev/null || true)"
  n_au="$(grep -c '^- authority: ' "$f" 2>/dev/null || true)"
  [ "$n_tree" = "$n_head" ] && [ "$n_hd" = "$n_head" ] && [ "$n_wt" = "$n_head" ] \
    && [ "$n_su" = "$n_head" ] && [ "$n_re" = "$n_head" ] && [ "$n_au" = "$n_head" ]
}

RESULT_LINE='run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed'
ALL_SUITES='tests/test-fx-gtr-a.sh tests/test-fx-gtr-b.sh tests/test-fx-gtr-c.sh'

self_test() {
  local d ar store ledger tree head n i

  # =======================================================================
  # --append — a minted certificate describes the tree that actually ran
  # =======================================================================

  # --- APPEND-CLEAN leg (the control every refusal leg below is read
  # against): a clean capture point whose recorded tree and head match the
  # observed ones is appended to BOTH stores, and the two entries name the
  # same suites with the same hashes. Two hand-written entries in two files
  # is two chances to drift, and the drift is invisible until a wrong
  # inheritance fires — one writer is the whole point, so the two stores
  # agreeing is the property, not a coincidence to be spot-checked.
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
    --runner "VERIFY step 1" --tree "$tree" --head "$head" \
    --result "$RESULT_LINE" --suites "$ALL_SUITES"
  if [ "$GTR_RC" -eq 0 ] \
     && [ "$(gtr_entry_count "$ledger" '### green-tree | cycle: 1')" -eq 1 ] \
     && [ "$(gtr_entry_count "$store" '### green-tree-shared | issue: #130')" -eq 1 ]; then
    st_ok "APPEND-CLEAN leg" "a verified capture point mints one entry in each store"
  else
    st_fail "APPEND-CLEAN leg" "expected exit 0 with one entry in each store, got rc=$GTR_RC ledger=$(gtr_entry_count "$ledger" '### green-tree | cycle: 1') shared=$(gtr_entry_count "$store" '### green-tree-shared | issue: #130') err=$GTR_ERR"
  fi
  local led_suites sh_suites
  led_suites="$(gtr_field "$ledger" '### green-tree | cycle: 1' suites)"
  sh_suites="$(gtr_field "$store" '### green-tree-shared | issue: #130' suites)"
  if [ -n "$led_suites" ] && [ "$led_suites" = "$sh_suites" ]; then
    st_ok "APPEND-CLEAN leg (both stores agree)" "the per-issue ledger and the shared store name the same suites with the same input hashes"
  else
    st_fail "APPEND-CLEAN leg (both stores agree)" "expected identical non-empty suites fields, got ledger='$led_suites' shared='$sh_suites'"
  fi
  if printf '%s\n' "$sh_suites" | tr ' ' '\n' | grep -c '@' | grep -qx 3 \
     && [ "$(gtr_field "$store" '### green-tree-shared | issue: #130' tree)" = "$tree" ] \
     && [ "$(gtr_field "$store" '### green-tree-shared | issue: #130' head)" = "$head" ]; then
    st_ok "APPEND-CLEAN leg (hashed tokens at the verified tree)" "each named suite is written as <path>@<input-hash>, keyed to the tree and head the writer re-observed"
  else
    st_fail "APPEND-CLEAN leg (hashed tokens at the verified tree)" "expected three @<hash> tokens keyed to $tree/$head, got suites='$sh_suites' tree='$(gtr_field "$store" '### green-tree-shared | issue: #130' tree)' head='$(gtr_field "$store" '### green-tree-shared | issue: #130' head)'"
  fi
  rm -rf "$d" "$ar"

  # --- APPEND-DIRTY leg: the guide's prose suppression rule becomes a
  # mechanical refusal. A dirty worktree at WRITE time means the tree the
  # certificate would name is not the tree anything was observed over, and a
  # certificate that describes a tree that never ran is the widening harm the
  # whole mechanism exists to prevent — so it refuses, writing to NEITHER
  # store. (Read against APPEND-CLEAN above: the same call succeeds there.)
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
    --runner "VERIFY step 1" --tree "$tree" --head "$head" \
    --result "$RESULT_LINE" --suites "$ALL_SUITES"
  local clean_rc="$GTR_RC" clean_wrote=0
  { [ -s "$ledger" ] && [ -s "$store" ]; } && clean_wrote=1
  : > "$ledger"; : > "$store"
  printf 'uncommitted\n' >> "$d/docs/subject-a.md"
  gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
    --runner "VERIFY step 1" --tree "$tree" --head "$head" \
    --result "$RESULT_LINE" --suites "$ALL_SUITES"
  if [ "$clean_rc" -eq 0 ] && [ "$clean_wrote" -eq 1 ] \
     && [ "$GTR_RC" -ne 0 ] && [ ! -s "$ledger" ] && [ ! -s "$store" ]; then
    st_ok "APPEND-DIRTY leg" "the identical call writes both stores over a clean capture point and refuses, writing neither, once the worktree is dirty at write time"
  else
    st_fail "APPEND-DIRTY leg" "expected the clean control to write both stores (rc=$clean_rc wrote=$clean_wrote) and the dirty case to refuse with both empty, got rc=$GTR_RC ledger-bytes=$(wc -c < "$ledger") shared-bytes=$(wc -c < "$store")"
  fi
  rm -rf "$d" "$ar"

  # --- APPEND-DRIFT legs: the window between the run and the write. The
  # caller records the capture point BEFORE the suites start; if the tree or
  # the head moved before the write, the recorded values describe a run that
  # did not happen at the tree now on disk. The writer re-takes the capture
  # point and refuses on either drift.
  local drift
  for drift in tree head; do
    d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
    store="$(gtr_store_init "$ar" "$d")"; ledger="$d/.autoflow/l.md"; : > "$ledger"
    tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
    gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
      --runner "VERIFY step 1" --tree "$tree" --head "$head" \
      --result "$RESULT_LINE" --suites "$ALL_SUITES"
    local ctl_rc="$GTR_RC" ctl_wrote=0
    { [ -s "$ledger" ] && [ -s "$store" ]; } && ctl_wrote=1
    : > "$ledger"; : > "$store"
    if [ "$drift" = tree ]; then
      tree="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    else
      head="cafebabecafebabecafebabecafebabecafebabe"
    fi
    gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
      --runner "VERIFY step 1" --tree "$tree" --head "$head" \
      --result "$RESULT_LINE" --suites "$ALL_SUITES"
    if [ "$ctl_rc" -eq 0 ] && [ "$ctl_wrote" -eq 1 ] \
       && [ "$GTR_RC" -ne 0 ] && [ ! -s "$ledger" ] && [ ! -s "$store" ]; then
      st_ok "APPEND-DRIFT leg ($drift)" "the identical call writes both stores with the observed $drift and refuses, writing neither, once the recorded $drift differs from it"
    else
      st_fail "APPEND-DRIFT leg ($drift)" "expected the matching-$drift control to write both stores (rc=$ctl_rc wrote=$ctl_wrote) and the drifted case to refuse with both empty, got rc=$GTR_RC ledger-bytes=$(wc -c < "$ledger") shared-bytes=$(wc -c < "$store")"
    fi
    rm -rf "$d" "$ar"
  done

  # --- APPEND-ATOMIC leg: an append that cannot complete leaves no
  # half-entry for another cycle to interpret. The failure is injected
  # deterministically rather than by timing — the ledger's directory is made
  # unwritable, so the write to one store fails while the other is in flight.
  # Both observables are asserted: neither store gained an entry, and every
  # entry that IS present carries all six fields (the shape a truncated write
  # would break). A successful append leaves no temporary file beside the
  # register either, since a stray temp is the other way a partial write
  # becomes visible.
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  mkdir -p "$d/.autoflow/locked"; ledger="$d/.autoflow/locked/l.md"; : > "$ledger"
  gtr_shared_entry "$store" 900 1 "1111111111111111111111111111111111111111" \
    "2222222222222222222222222222222222222222" "tests/test-fx-gtr-a.sh"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  # Control half, over a WRITABLE ledger directory in the same fixture: the
  # store does grow when the append can complete, so the case half below is
  # about the failed write and not about a writer that never writes.
  gtr_run "$ar" --append --root "$d" --ledger "$d/.autoflow/l.md" --issue 131 --cycle 1 \
    --runner "VERIFY step 1" --tree "$tree" --head "$head" \
    --result "$RESULT_LINE" --suites "$ALL_SUITES"
  local atomic_ctl_rc="$GTR_RC" atomic_ctl_grew=0
  grep -qF '#131' "$store" && atomic_ctl_grew=1
  local store_before; store_before="$(cat "$store")"
  chmod a-w "$d/.autoflow/locked"
  gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
    --runner "VERIFY step 1" --tree "$tree" --head "$head" \
    --result "$RESULT_LINE" --suites "$ALL_SUITES"
  chmod u+w "$d/.autoflow/locked"
  if [ "$atomic_ctl_rc" -eq 0 ] && [ "$atomic_ctl_grew" -eq 1 ] \
     && [ "$GTR_RC" -ne 0 ] && [ "$(cat "$store")" = "$store_before" ] \
     && gtr_wellformed "$store" '### green-tree-shared | '; then
    st_ok "APPEND-ATOMIC leg (no partial cross-store write)" "the same append grows the shared store when it completes and leaves it byte-identical, every entry whole, when the other store's write cannot"
  else
    st_fail "APPEND-ATOMIC leg (no partial cross-store write)" "expected the writable control to grow the store (rc=$atomic_ctl_rc grew=$atomic_ctl_grew) and the blocked case to leave it unchanged, got rc=$GTR_RC"
  fi
  rm -rf "$d" "$ar"

  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_run "$ar" --append --root "$d" --ledger "$ledger" --issue 130 --cycle 1 \
    --runner "VERIFY step 1" --tree "$tree" --head "$head" \
    --result "$RESULT_LINE" --suites "$ALL_SUITES"
  if [ "$GTR_RC" -eq 0 ] \
     && [ "$(find "$(dirname "$store")" -type f ! -name 'register.md' | wc -l | tr -d ' ')" -eq 0 ] \
     && gtr_wellformed "$store" '### green-tree-shared | '; then
    st_ok "APPEND-ATOMIC leg (no temporary residue)" "a completed append leaves the store directory holding the register alone, every entry whole"
  else
    st_fail "APPEND-ATOMIC leg (no temporary residue)" "expected exit 0, no stray file beside register.md and a well-formed store, got rc=$GTR_RC residue='$(find "$(dirname "$store")" -type f ! -name 'register.md' | tr '\n' ' ')'"
  fi
  rm -rf "$d" "$ar"

  # =======================================================================
  # --match — the tree-identity predicate's SHARED ARM
  # =======================================================================
  # This query's answer becomes an `outcome: inherited` record directly, with
  # no resolver in between, so its qualification rule is load-bearing on its
  # own. Each negative half below is paired with the positive control it
  # differs from by exactly one field — an implementation that never matches
  # anything satisfies every negative half alone.

  # --- MATCH-QUALIFY leg (result must be a pass)
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_shared_entry "$store" 401 1 "$tree" "$head" "$ALL_SUITES"
  gtr_run "$ar" --match --root "$d"
  local pass_rc="$GTR_RC" pass_out="$GTR_OUT"
  : > "$store"
  gtr_shared_entry "$store" 402 1 "$tree" "$head" "$ALL_SUITES" \
    "run-suites: 2 passed, 1 failed, 0 timed out, of 3 executed"
  gtr_run "$ar" --match --root "$d"
  if [ "$pass_rc" -eq 0 ] && printf '%s\n' "$pass_out" | grep -qF '#401' \
     && [ "$GTR_RC" -ne 0 ] && [ -z "$GTR_OUT" ]; then
    st_ok "MATCH-QUALIFY leg (result)" "an entry at the captured tree whose result is a pass matches and is printed; the same entry with a failing result matches nothing and exits non-zero"
  else
    st_fail "MATCH-QUALIFY leg (result)" "expected the pass entry printed at exit 0 and the non-pass entry silent at a non-zero exit, got pass rc=$pass_rc out='$pass_out'; non-pass rc=$GTR_RC out='$GTR_OUT'"
  fi
  rm -rf "$d" "$ar"

  # --- MATCH-QUALIFY leg (head must resolve)
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_shared_entry "$store" 403 1 "$tree" "$head" "$ALL_SUITES"
  gtr_run "$ar" --match --root "$d"
  pass_rc="$GTR_RC"; pass_out="$GTR_OUT"
  : > "$store"
  gtr_shared_entry "$store" 404 1 "$tree" "cafebabecafebabecafebabecafebabecafebabe" "$ALL_SUITES"
  gtr_run "$ar" --match --root "$d"
  if [ "$pass_rc" -eq 0 ] && printf '%s\n' "$pass_out" | grep -qF '#403' \
     && [ "$GTR_RC" -ne 0 ] && [ -z "$GTR_OUT" ]; then
    st_ok "MATCH-QUALIFY leg (head)" "an entry whose head resolves matches; the same entry with a head naming no commit matches nothing and exits non-zero"
  else
    st_fail "MATCH-QUALIFY leg (head)" "expected the resolvable-head entry printed at exit 0 and the unresolvable one silent at a non-zero exit, got resolvable rc=$pass_rc out='$pass_out'; unresolvable rc=$GTR_RC out='$GTR_OUT'"
  fi
  rm -rf "$d" "$ar"

  # --- COVER-UNION leg (the load-bearing one): the coverage test applies to
  # the UNION of the qualifying entries. Certificates are minted per
  # phase-step run naming only the suites that ran, so two issues on one tree
  # ordinarily leave two partial entries — joint coverage is the normal
  # cross-issue case, not a corner. It is also the rule the resolver's own
  # shared arm applies: under a single-covering-entry rule the resolver would
  # union an empty run set (nothing executes) while this predicate reported a
  # mismatch, producing `outcome: inherited` with a non-`none` cause, which
  # the guide forbids as a biconditional.
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_shared_entry "$store" 501 1 "$tree" "$head" "tests/test-fx-gtr-a.sh"
  gtr_shared_entry "$store" 502 1 "$tree" "$head" "tests/test-fx-gtr-b.sh tests/test-fx-gtr-c.sh"
  gtr_run "$ar" --match --root "$d" --cover-enumerated
  if [ "$GTR_RC" -eq 0 ] \
     && [ "$(printf '%s\n' "$GTR_OUT" | grep -c .)" -eq 2 ] \
     && printf '%s\n' "$GTR_OUT" | grep -qF '#501' \
     && printf '%s\n' "$GTR_OUT" | grep -qF '#502'; then
    st_ok "COVER-UNION leg" "two qualifying entries naming disjoint subsets that jointly cover the enumerated set are both printed, one heading per line, at exit 0"
  else
    st_fail "COVER-UNION leg" "expected both contributing headings printed at exit 0, got rc=$GTR_RC out='$(printf '%s' "$GTR_OUT" | tr '\n' ' ')'"
  fi
  rm -rf "$d" "$ar"

  # --- COVER-SUBSET leg: the mirror. A qualifying entry naming only a
  # subset, with no other qualifying entry supplying the remainder, does not
  # cover — nothing is printed and the exit is non-zero. This is a real
  # failure only while COVER-UNION's scoping holds, which is why the two are
  # written as a pair.
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  gtr_shared_entry "$store" 503 1 "$tree" "$head" "tests/test-fx-gtr-a.sh"
  gtr_run "$ar" --match --root "$d" --cover-enumerated
  local subset_rc="$GTR_RC" subset_out="$GTR_OUT"
  gtr_run "$ar" --match --root "$d"
  if [ "$subset_rc" -ne 0 ] && [ -z "$subset_out" ] \
     && [ "$GTR_RC" -eq 0 ] && printf '%s\n' "$GTR_OUT" | grep -qF '#503'; then
    st_ok "COVER-SUBSET leg" "a lone qualifying entry covering only a subset prints nothing under --cover-enumerated and exits non-zero, while the same entry still qualifies without it"
  else
    st_fail "COVER-SUBSET leg" "expected --cover-enumerated silent at a non-zero exit and plain --match printing #503 at exit 0, got cover rc=$subset_rc out='$subset_out'; match rc=$GTR_RC out='$GTR_OUT'"
  fi
  rm -rf "$d" "$ar"

  # =======================================================================
  # --prune — bounded growth
  # =======================================================================
  # Every resolver call parses the whole file, so unbounded growth is a cost
  # every later issue pays. `--prune` retains the most RECENT entries: the
  # store is append-only, so file order is chronological and "most recent" is
  # the tail.

  # --- PRUNE leg (explicit --keep): the retained set is the tail, by
  # identity, not merely the right count.
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  for i in 1 2 3 4 5; do
    gtr_shared_entry "$store" "60$i" 1 "$tree" "$head" "tests/test-fx-gtr-a.sh"
  done
  gtr_run "$ar" --prune --root "$d" --keep 2
  if [ "$GTR_RC" -eq 0 ] \
     && [ "$(gtr_entry_count "$store" '### green-tree-shared | ')" -eq 2 ] \
     && grep -qF '#604' "$store" && grep -qF '#605' "$store" \
     && ! grep -qF '#601' "$store"; then
    st_ok "PRUNE leg (--keep)" "--keep 2 over five entries retains exactly the two most recent and drops the rest"
  else
    st_fail "PRUNE leg (--keep)" "expected the two most recent entries retained, got rc=$GTR_RC count=$(gtr_entry_count "$store" '### green-tree-shared | ')"
  fi
  rm -rf "$d" "$ar"

  # --- PRUNE leg (default retention): the default is a BEHAVIOUR, driven
  # here rather than read out of the header, so a header that says 200 while
  # the code keeps something else is a failing leg (DISPATCH directive D8).
  d="$(mktemp -d)"; gtr_fixture_repo "$d"; ar="$(mktemp -d)"
  store="$(gtr_store_init "$ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  i=1
  while [ "$i" -le 205 ]; do
    gtr_shared_entry "$store" "7$i" 1 "$tree" "$head" "tests/test-fx-gtr-a.sh"
    i=$((i + 1))
  done
  gtr_run "$ar" --prune --root "$d"
  n="$(gtr_entry_count "$store" '### green-tree-shared | ')"
  if [ "$GTR_RC" -eq 0 ] && [ "$n" -eq 200 ] \
     && grep -qF '#7205' "$store" && ! grep -qF '#71 ' "$store"; then
    st_ok "PRUNE leg (default retention)" "--prune with no --keep retains 200 entries, the most recent, and drops the overflow"
  else
    st_fail "PRUNE leg (default retention)" "expected 200 entries retained by default, got rc=$GTR_RC count=$n"
  fi
  rm -rf "$d" "$ar"

  return $SELFTEST_RC
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

# RED STATE: no production subcommand is implemented in this file yet.
echo "green-tree-register: not implemented (RED, issue #130): $*" >&2
exit 2
