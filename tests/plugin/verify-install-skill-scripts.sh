#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: /autoflow:install skill-shipped scripts (detect.sh, scaffold-identity.sh)
# Issue #943 — marketplace-cache-based root-layer stamp
# =============================================================================
# Drives the deterministic seams the install skill (SKILL.md) orchestrates:
# `plugin/autoflow/skills/install/scripts/detect.sh` (detection + git-state
# auto-derivation + version-skew) and `scripts/scaffold-identity.sh` (identity
# scaffold, never-overwrite). Plain POSIX sh + jq/git/awk/grep only, matching
# tests/plugin/verify-e2e-dummy-target.sh's harness form.
#
# This suite does NOT duplicate AC2a/AC3a/AD4(i) — the deterministic
# init.sh/drift-check.sh stamp+idempotency+scaffold-if-absent guarantees stay
# owned by tests/plugin/verify-e2e-dummy-target.sh (W-E1/W-E3). This suite's
# own new assertions are detect.sh's and scaffold-identity.sh's *new* value:
# absence/hard-error detection, drift/version-skew reporting (and their
# NON-conflation), git-state derivation (incl. graceful omission), topology
# judgment, the fork-URL gate (mocked `gh`), and the identity-scaffold draft.
#
# Acceptance criteria (.autoflow/issue-943-verification-design.md §1/§2, §5
# RED plan item 2):
#   AC2b   detect.sh absence arm: INSTALL_STATE=absent, DRIFT_STATE=na,
#          DRIFT_FAILS=0, exit 0 (normal, not an error)
#   AC2b-hard  hard-error arm: unresolvable PLUGIN_CACHE_ROOT -> non-zero exit
#   AC3b   drift arm: mutate one stamped artifact -> DRIFT_STATE=drift,
#          DRIFT_FAILS>=1, DRIFT_FIRST names the mutated artifact
#   AC3b-degrade  degradation arm (cycle 5 DCR-C5-2 FLIP): the installed
#          target's OWN drift-check.sh copy is removed -> DRIFT_STATE=drift
#          (cache oracle's D1 reports "missing installed artifact"), NOT
#          'error' -- superseding the pre-cycle-5 '=error' expectation
#          (.autoflow/issue-943-verification-design.md §3 DCR-C5-2)
#   AC3b-degrade-cache  EMPTY_CACHE-adjacent reconciliation (cycle 5): the
#          CACHE's own drift-check.sh is absent (manifest present, oracle
#          unresolvable) -> DRIFT_STATE=error, never silent 'clean'
#   AC-M1a  execution-failure (syntax-error) arm: the CACHE copy of
#          drift-check.sh aborts with a shell syntax error (non-zero exit, no
#          FAIL: line) -> DRIFT_STATE=error (cycle 3, review-response on PR
#          #959; cycle 5 DCR-C5-1 moves the stub fixture from the target copy
#          to a scratch cache copy, expected value unchanged)
#   AC-M1b  execution-failure (bare exit N) arm: the CACHE copy of
#          drift-check.sh exits non-zero with no FAIL: line (no syntax error)
#          -> DRIFT_STATE=error (cycle 3; cycle 5 DCR-C5-1 scratch-cache
#          fixture move)
#   AC-M1-D2  D2-only-disposition lock: the CACHE copy of drift-check.sh
#          exits non-zero emitting ONLY a 'FAIL: D2 ...' line -> DRIFT_STATE=
#          clean, DRIFT_FAILS=0, DRIFT_FIRST empty (discriminates the correct
#          fix from a naive rc!=0=>error promotion; cycle 3; cycle 5 DCR-C5-1
#          scratch-cache fixture move)
#   AC-T2  cache-oracle trust-source-switch sentinel (cycle 5, review-response
#          on Codex Medium, PR #959): the TARGET's own drift-check.sh copy is
#          tampered with a side-effect stub (proof-file write) -> (a) the
#          proof file must NOT appear (target copy never executed), (b) the
#          target tree must be byte-unchanged across the detection call
#          (full-tree hash snapshot equality), (c) the tampering itself must
#          still be reported as D1 drift by the cache oracle
#   AC-T3  static SKILL.md arm (cycle 5): the Step-1 region documents the
#          read-only mechanism -- a line naming both 'cache' and 'drift-check'
#          (the pinned token pair of verification-design §2 AC-T3)
#   AC3 (issue #963)  static SKILL.md arm: the Step-1 block (## Step 1 ..
#          ## Step 2) carries the stable marker
#          <!-- AGENT-TEAMS-ENV-DISCLOSURE --> naming
#          CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS / "Agent Teams" plus an
#          experimental/token-cost caveat, BEFORE the Step 3 confirmation
#          (.autoflow/issue-963-verification-design.md §1 AC3)
#   AC3b'  version-skew arm: installed manifest .version older than cache
#          setup/manifest.json .version -> VERSION_SKEW=yes (both populated);
#          equal-version fixture -> VERSION_SKEW=no
#   AC3b'-lockstep  cache setup/manifest.json .version == cache plugin.json
#          .version (the R2-stamp lockstep VERSION_SKEW's like-for-like
#          comparand rests on)
#   AC3b"  non-conflation arm: content-clean + version-skew-only fixture ->
#          VERSION_SKEW=yes AND DRIFT_STATE=clean/DRIFT_FAILS=0/DRIFT_FIRST
#          empty (a pure version bump does not double-report as drift)
#   AD1    org/repo/default-branch auto-derivation from a GitHub origin;
#          graceful omission (empty, exit 0, no prompt) on a non-GitHub or
#          absent remote
#   AD1-slash  slash-qualified DEFAULT_BRANCH derivation (single- and
#          multi-slash, non-nesting) -- the full branch name must survive,
#          not just its final path segment (cycle 4, review-response on
#          Codex Low, PR #959)
#   AD1-slash-scaffold  the detect-derived slash-qualified DEFAULT_BRANCH
#          propagates verbatim into the scaffolded CLAUDE.local.md (cycle 4)
#   AD2    topology auto-judge: zero-submodule -> single; .gitmodules entry
#          -> multi
#   AD3    fork-URL proposal + FORK_EXISTS under a mocked `gh` (yes/no), plus
#          the gh-absent graceful-degradation arm (FORK_EXISTS=unknown,
#          still exit 0) (OC-2); single-repo fixture -> FORK_PROPOSAL empty
#   AD4    scaffold-identity.sh: (i) CLAUDE.local.md present -> byte-unchanged
#          + "skipped" branch printed; (ii) absent -> derived-draft written
#          with derived values and "(set manually)" placeholders for empty
#          fields
#   C4-AC-1  (issue #979 cycle 4, review-response) set-review-backend.sh:
#          explicit BACKEND=claude on a codex-default-seeded config ->
#          .review.backend == "claude", exit 0 (the reviewer's exact
#          codex-absent + explicit-claude path)
#   C4-AC-2  validation boundary: empty/bogus BACKEND -> exit 2, config file
#          byte-unchanged (no write on an invalid selection)
#   C4-AC-3  jq-present merge fidelity: switching backend on a config that
#          already carries sibling operator keys preserves those keys
#          (single-key merge, not a whole-file clobber)
#   C4-AC-4  static SKILL.md arm: the Step 4 block (## Step 4 .. EOF, the
#          terminal Step) carries the stable marker
#          <!-- REVIEWER-BACKEND-PERSIST -->, names the persistence
#          invocation, gates it on the explicit selection, and orders it
#          AFTER the init.sh stamp line
#   C4-AC-6  jq-absent arm: with jq off PATH, a run against a pre-existing
#          config REFUSES (exit 1, file byte-unchanged) rather than
#          clobbering; a run against an absent config still writes the
#          canonical literal (nothing to preserve)
#
# RED framing: plugin/autoflow/skills/install/scripts/{detect,scaffold-identity}.sh
# do not exist yet -- every arm below fails on the "script missing" guard.
# set-review-backend.sh (C4-AC-1/2/3/6) likewise does not exist yet -- those
# arms fail on the same "script missing" (exit 127) guard, and the SKILL.md
# Step-4 marker (C4-AC-4) does not exist yet either.
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

DETECT_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"
SCAFFOLD_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/scaffold-identity.sh"
SET_BACKEND_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/set-review-backend.sh"
INIT_SH="$REPO_ROOT/setup/init.sh"
CACHE_MANIFEST="$REPO_ROOT/setup/manifest.json"
CACHE_PLUGIN_JSON="$REPO_ROOT/plugin/autoflow/.claude-plugin/plugin.json"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }
skipc() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP: %s -- %s\n' "$1" "$2"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

# get_kv <detect-output> <key> — last matching key=value line's value.
get_kv() {
  printf '%s\n' "$1" | grep "^$2=" | tail -1 | cut -d= -f2-
}

# run_detect <target-root> <plugin-cache-root> — invokes detect.sh with the
# env contract from feature-design §3.2 (TARGET_ROOT, PLUGIN_CACHE_ROOT).
# Sets DETECT_OUT / DETECT_CODE globals.
run_detect() {
  if [ ! -f "$DETECT_SH" ]; then
    DETECT_OUT=""
    DETECT_CODE=127
    return
  fi
  DETECT_OUT=$(TARGET_ROOT="$1" PLUGIN_CACHE_ROOT="$2" bash "$DETECT_SH" 2>&1)
  DETECT_CODE=$?
}

# mk_git_repo <dir> — bare minimal git repo with one commit, no remote.
mk_git_repo() {
  _d="$1"
  mkdir -p "$_d"
  ( cd "$_d" && git init -q \
      && git -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init )
}

# add_github_origin <dir> <org> <repo> — fake a GitHub origin + origin/HEAD
# without a network fetch (local ref plumbing only).
add_github_origin() {
  _d="$1"; _org="$2"; _repo="$3"
  ( cd "$_d" \
      && git remote add origin "https://github.com/$_org/$_repo.git" \
      && git update-ref refs/remotes/origin/main "$(git -C "$_d" rev-parse HEAD)" \
      && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main )
}

# add_github_origin_branch <dir> <org> <repo> <branch> — like add_github_origin
# but parameterizes the default-branch target so a slash-qualified
# refs/remotes/origin/HEAD can be constructed (cycle 4, AC-L1/AC-L2).
add_github_origin_branch() {
  _d="$1"; _org="$2"; _repo="$3"; _branch="$4"
  ( cd "$_d" \
      && (git remote add origin "https://github.com/$_org/$_repo.git" 2>/dev/null || true) \
      && git update-ref "refs/remotes/origin/$_branch" "$(git -C "$_d" rev-parse HEAD)" \
      && git symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$_branch" )
}

# add_non_github_origin <dir> — a remote that is not GitHub (graceful omission arm).
add_non_github_origin() {
  ( cd "$1" && git remote add origin "https://gitlab.example.com/foo/bar.git" )
}

# add_submodule <parent-dir> — registers a real local submodule so
# `git submodule status` is non-empty (AD2 multi-topology fixture).
add_submodule() {
  _parent="$1"
  _sub_src=$(mktemp -d)
  mk_git_repo "$_sub_src"
  ( cd "$_parent" && git -c protocol.file.allow=always submodule add -q "$_sub_src" sub >/dev/null 2>&1 )
}

# do_install <target-dir> — non-interactive stamp via the real init.sh
# (reuses the already-covered W-E1 mechanism; not re-verified here).
do_install() {
  bash "$INIT_SH" --target "$1" </dev/null >/dev/null 2>&1
}

# run_scaffold <target-root> <org> <repo> <default-branch> <topology> —
# invokes scaffold-identity.sh with the env contract (AD4 + AD1-slash-scaffold,
# cycle 4). Sets SCAFFOLD_OUT / SCAFFOLD_CODE globals.
run_scaffold() {
  # $1 TARGET_ROOT, $2 ORG, $3 REPO, $4 DEFAULT_BRANCH, $5 TOPOLOGY
  if [ ! -f "$SCAFFOLD_SH" ]; then
    SCAFFOLD_OUT=""; SCAFFOLD_CODE=127; return
  fi
  SCAFFOLD_OUT=$(TARGET_ROOT="$1" ORG="$2" REPO="$3" DEFAULT_BRANCH="$4" TOPOLOGY="$5" bash "$SCAFFOLD_SH" 2>&1)
  SCAFFOLD_CODE=$?
}

# run_set_backend <target-root> <backend> [path] — invokes set-review-backend.sh
# with the env contract from feature-design §4.1 (TARGET_ROOT, BACKEND). An
# optional 3rd arg overrides PATH for the subprocess (issue #979 cycle 4,
# C4-AC-6 jq-absent arm). Sets BACKEND_OUT / BACKEND_CODE globals.
run_set_backend() {
  # $1 TARGET_ROOT, $2 BACKEND, $3 optional PATH override
  if [ ! -f "$SET_BACKEND_SH" ]; then
    BACKEND_OUT=""; BACKEND_CODE=127; return
  fi
  if [ -n "${3:-}" ]; then
    BACKEND_OUT=$(PATH="$3" TARGET_ROOT="$1" BACKEND="$2" bash "$SET_BACKEND_SH" 2>&1)
  else
    BACKEND_OUT=$(TARGET_ROOT="$1" BACKEND="$2" bash "$SET_BACKEND_SH" 2>&1)
  fi
  BACKEND_CODE=$?
}

# path_without_jq — returns a single-directory PATH (NOJQ_DIR) populated with
# a symlink for every executable reachable on the current $PATH EXCEPT `jq`
# (issue #979 cycle 4, C4-AC-6). Unlike filtering out whole directories (jq
# commonly co-resides with unrelated essentials such as dirname/basename in
# /usr/bin on macOS), this symlink-farm approach keeps every other command
# resolvable while making `command -v jq` fail -- so the seam script's own
# `mkdir`/`dirname`/`mv` calls keep working under the "jq absent" fixture.
# Built once (idempotent, guarded by NOJQ_DIR/.built) and reused by both
# C4-AC-6 arms.
path_without_jq() {
  if [ ! -f "$NOJQ_DIR/.built" ]; then
    _oldifs="$IFS"
    IFS=':'
    for _d in $PATH; do
      [ -n "$_d" ] && [ -d "$_d" ] || continue
      for _f in "$_d"/*; do
        [ -f "$_f" ] && [ -x "$_f" ] || continue
        _name=$(basename "$_f")
        [ "$_name" = "jq" ] && continue
        [ -e "$NOJQ_DIR/$_name" ] && continue
        ln -s "$_f" "$NOJQ_DIR/$_name" 2>/dev/null
      done
    done
    IFS="$_oldifs"
    : > "$NOJQ_DIR/.built"
  fi
  printf '%s' "$NOJQ_DIR"
}

# mk_scratch_cache <dir> — builds a minimal writable plugin-cache scaffold:
# copies the real setup/manifest.json (satisfies detect.sh's line-35..38 hard
# guard so the DRIFT block is reached) and creates the setup/thin-root-layer/
# directory the caller drops a drift-check.sh stub into (or leaves empty, for
# the cache-oracle-absent arm). NEVER touches the real repo's own
# setup/thin-root-layer/drift-check.sh (cycle 5, DCR-C5-1/DCR-C5-2).
mk_scratch_cache() {
  _d="$1"
  mkdir -p "$_d/setup/thin-root-layer"
  cp "$CACHE_MANIFEST" "$_d/setup/manifest.json"
}

# ── Temp fixtures ─────────────────────────────────────────────────────────────
ABSENT_TARGET=$(mktemp -d)          # AC2b: no manifest yet
CLEAN_TARGET=$(mktemp -d)           # AC3b baseline / degradation / non-conflation
DRIFT_TARGET=$(mktemp -d)           # AC3b: mutated artifact
SKEW_TARGET=$(mktemp -d)            # AC3b': version-skew-only fixture
GITHUB_TARGET=$(mktemp -d)          # AD1: GitHub origin
NONGITHUB_TARGET=$(mktemp -d)       # AD1: non-GitHub/absent origin (omission arm)
SINGLE_TOPO_TARGET=$(mktemp -d)     # AD2/AD3: zero-submodule
MULTI_TOPO_TARGET=$(mktemp -d)      # AD2/AD3: submodule present
EMPTY_CACHE=$(mktemp -d)            # AC2b-hard: unresolvable PLUGIN_CACHE_ROOT
MOCK_GH_DIR=$(mktemp -d)
IDENTITY_PRESENT_TARGET=$(mktemp -d)  # AD4(i): CLAUDE.local.md pre-exists
IDENTITY_ABSENT_TARGET=$(mktemp -d)   # AD4(ii): CLAUDE.local.md absent
SSH_TARGET=$(mktemp -d)               # AD1 (F3): SSH-form GitHub origin
IDENTITY_UNKNOWN_TARGET=$(mktemp -d)  # AD4 (F3): unknown-TOPOLOGY label
CRASH_TARGET=$(mktemp -d)             # AC-M1a/AC-M1b/AC-M1-D2 (cycle 3): shared,
                                       # stub overwritten in place per arm
SLASHBRANCH_TARGET=$(mktemp -d)       # AD1-slash/AD1-slash-multi/AD1-slash-scaffold
                                       # (cycle 4): dedicated, own origin/HEAD
ORACLE_TAMPER_TARGET=$(mktemp -d)     # AC-T2 (cycle 5): dedicated, target
                                       # drift-check.sh tampered with a
                                       # side-effect stub
DEGRADE_TARGET=$(mktemp -d)           # AC3b-degrade (cycle 5, DCR-C5-2):
                                       # dedicated, so CLEAN_TARGET is never
                                       # contaminated by rm'ing its own
                                       # drift-check.sh
CRASH_CACHE=$(mktemp -d)              # AC-M1a/AC-M1b/AC-M1-D2 (cycle 5,
                                       # DCR-C5-1): scratch cache, stub
                                       # overwritten in place per arm
MISSING_ORACLE_CACHE=$(mktemp -d)     # AC3b-degrade-cache (cycle 5,
                                       # DCR-C5-2): scratch cache with a
                                       # manifest but no thin-root-layer/
                                       # drift-check.sh
BACKEND_TARGET=$(mktemp -d)           # C4-AC-1/2/3/6 (issue #979 cycle 4):
                                       # reused across backend-persistence
                                       # arms, reseeded per arm
NOJQ_DIR=$(mktemp -d)                 # C4-AC-6 (issue #979 cycle 4): jq-less
                                       # symlink-farm PATH, built lazily by
                                       # path_without_jq()
BACKEND5_TARGET=$(mktemp -d)          # C5-AC-3/4/6 (issue #979 cycle 5):
                                       # detect.sh malformed/empty/absent/null
                                       # REVIEW_BACKEND arms, reseeded per arm

cleanup() {
  rm -rf "$ABSENT_TARGET" "$CLEAN_TARGET" "$DRIFT_TARGET" "$SKEW_TARGET" \
         "$GITHUB_TARGET" "$NONGITHUB_TARGET" "$SINGLE_TOPO_TARGET" \
         "$MULTI_TOPO_TARGET" "$EMPTY_CACHE" "$MOCK_GH_DIR" \
         "$IDENTITY_PRESENT_TARGET" "$IDENTITY_ABSENT_TARGET" \
         "$SSH_TARGET" "$IDENTITY_UNKNOWN_TARGET" "$CRASH_TARGET" \
         "$SLASHBRANCH_TARGET" "$ORACLE_TAMPER_TARGET" "$DEGRADE_TARGET" \
         "$CRASH_CACHE" "$MISSING_ORACLE_CACHE" "$BACKEND_TARGET" "$NOJQ_DIR" \
         "$BACKEND5_TARGET"
}
trap cleanup EXIT INT TERM

# ══════════════════════════════════════════════════════════════════════════════
# AC2b — absence + hard-error arms
# ══════════════════════════════════════════════════════════════════════════════

echo "== AC2b: absent target -> INSTALL_STATE=absent, DRIFT_STATE=na, exit 0 (normal, not an error) =="
mk_git_repo "$ABSENT_TARGET"
run_detect "$ABSENT_TARGET" "$REPO_ROOT"
if [ "$DETECT_CODE" -eq 0 ] \
   && [ "$(get_kv "$DETECT_OUT" INSTALL_STATE)" = "absent" ] \
   && [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "na" ]; then
  pass "AC2b: absent target -> INSTALL_STATE=absent DRIFT_STATE=na, exit 0"
else
  failc "AC2b" "expected INSTALL_STATE=absent DRIFT_STATE=na exit=0; got exit=$DETECT_CODE INSTALL_STATE=$(get_kv "$DETECT_OUT" INSTALL_STATE) DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) (script missing pre-GREEN: $([ -f "$DETECT_SH" ] && echo no || echo yes))"
fi

echo "== AC2b-hard: unresolvable PLUGIN_CACHE_ROOT (no setup/manifest.json in cache) -> non-zero exit =="
if [ ! -f "$DETECT_SH" ]; then
  failc "AC2b-hard" "detect.sh missing at $DETECT_SH -- cannot exercise the hard-error arm (a bare exit-127-from-absence is not a verified hard-error path)"
else
  run_detect "$ABSENT_TARGET" "$EMPTY_CACHE"
  if [ "$DETECT_CODE" -ne 0 ]; then
    pass "AC2b-hard: unresolvable PLUGIN_CACHE_ROOT -> non-zero exit ($DETECT_CODE)"
  else
    failc "AC2b-hard" "expected non-zero exit with an empty/invalid PLUGIN_CACHE_ROOT; got exit 0"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# AC3b — drift detection + degradation arm
# ══════════════════════════════════════════════════════════════════════════════

echo "== AC3b (baseline): freshly-stamped target -> DRIFT_STATE=clean DRIFT_FAILS=0 =="
mk_git_repo "$CLEAN_TARGET"
do_install "$CLEAN_TARGET"
CLEAN_INSTALLED=$([ -f "$CLEAN_TARGET/.claude/autoflow/manifest.json" ] && echo yes || echo no)
run_detect "$CLEAN_TARGET" "$REPO_ROOT"
if [ "$CLEAN_INSTALLED" = "yes" ] && [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "clean" ] && [ "$(get_kv "$DETECT_OUT" DRIFT_FAILS)" = "0" ]; then
  pass "AC3b baseline: clean stamped target -> DRIFT_STATE=clean DRIFT_FAILS=0"
else
  failc "AC3b" "baseline clean-install arm failed: installed=$CLEAN_INSTALLED DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) DRIFT_FAILS=$(get_kv "$DETECT_OUT" DRIFT_FAILS)"
fi

echo "== AC3b: mutated stamped artifact -> DRIFT_STATE=drift, DRIFT_FIRST names it =="
cp -R "$CLEAN_TARGET" "$DRIFT_TARGET.copy" 2>/dev/null
rm -rf "$DRIFT_TARGET"
mk_git_repo "$DRIFT_TARGET"
do_install "$DRIFT_TARGET"
MUTATE_FILE="$DRIFT_TARGET/.claude/autoflow/METHODOLOGY.md"
if [ -f "$MUTATE_FILE" ]; then
  printf '\nDRIFT_MUTATION_ISSUE_943\n' >> "$MUTATE_FILE"
fi
run_detect "$DRIFT_TARGET" "$REPO_ROOT"
DRIFT_FIRST_VAL=$(get_kv "$DETECT_OUT" DRIFT_FIRST)
if [ -f "$MUTATE_FILE" ] && [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "drift" ] \
   && [ "$(get_kv "$DETECT_OUT" DRIFT_FAILS)" != "0" ] \
   && printf '%s' "$DRIFT_FIRST_VAL" | grep -qF "METHODOLOGY.md"; then
  pass "AC3b: mutated artifact -> DRIFT_STATE=drift, DRIFT_FIRST names METHODOLOGY.md"
else
  failc "AC3b" "expected DRIFT_STATE=drift with DRIFT_FIRST naming the mutated artifact; got DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) DRIFT_FAILS=$(get_kv "$DETECT_OUT" DRIFT_FAILS) DRIFT_FIRST=$DRIFT_FIRST_VAL"
fi

echo "== AC3b-degrade: installed target's OWN drift-check.sh copy removed -> DRIFT_STATE=drift (cycle 5, DCR-C5-2 FLIP: the cache oracle's D1 now reports the missing target artifact as content drift, superseding the pre-cycle-5 '=error' expectation; dedicated DEGRADE_TARGET so CLEAN_TARGET is never contaminated) =="
mk_git_repo "$DEGRADE_TARGET"
do_install "$DEGRADE_TARGET"
rm -f "$DEGRADE_TARGET/.claude/autoflow/drift-check.sh"
run_detect "$DEGRADE_TARGET" "$REPO_ROOT"
DEGRADE_DRIFT_FIRST=$(get_kv "$DETECT_OUT" DRIFT_FIRST)
if [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "drift" ] \
   && printf '%s' "$DEGRADE_DRIFT_FIRST" | grep -qF '.claude/autoflow/drift-check.sh'; then
  pass "AC3b-degrade: target's own drift-check.sh removed -> DRIFT_STATE=drift, DRIFT_FIRST names .claude/autoflow/drift-check.sh (cache oracle's D1 catches the missing artifact)"
else
  failc "AC3b-degrade" "expected DRIFT_STATE=drift with DRIFT_FIRST containing '.claude/autoflow/drift-check.sh' (DCR-C5-2 flip from the pre-cycle-5 'error' expectation); got DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) DRIFT_FIRST=$DEGRADE_DRIFT_FIRST -- at HEAD detect.sh still guards the TARGET's own missing copy directly and falls to DRIFT_STATE=error instead of routing through the cache oracle's D1"
fi

echo "== AC3b-degrade-cache: CACHE-copy drift-check.sh absent (manifest present, oracle unresolvable) -> DRIFT_STATE=error (cycle 5, DCR-C5-2 EMPTY_CACHE-adjacent reconciliation) =="
mk_scratch_cache "$MISSING_ORACLE_CACHE"
run_detect "$CLEAN_TARGET" "$MISSING_ORACLE_CACHE"
if [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "error" ]; then
  pass "AC3b-degrade-cache: cache manifest present but cache drift-check.sh absent -> DRIFT_STATE=error (never silent clean)"
else
  failc "AC3b-degrade-cache" "expected DRIFT_STATE=error when the CACHE's own drift-check.sh is absent (manifest present, oracle unresolvable); got DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) -- at HEAD detect.sh still guards the TARGET's own (present) drift-check.sh copy and never checks cache-copy presence, so this is the cache-oracle-switch RED driver"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AC-T2 — cache-oracle trust-source switch: tampered TARGET copy must not be
# executed, must leave the target byte-unchanged, and must still be reported
# as D1 drift by the cache oracle (cycle 5, review-response on Codex Medium,
# PR #959: SKILL.md Step 1 promises read-only detection, but detect.sh:61
# executes the TARGET-owned drift-check.sh -- a manifest kind:"copy" artifact
# that can be tampered -- performing arbitrary pre-confirmation side effects).
# .autoflow/issue-943-verification-design.md §2 AC-T2 is authoritative on the
# full-tree hash-snapshot-equality oracle (a bare "no new PWNED_PROOF file"
# check is not sufficient -- it would miss an in-place modification of an
# existing file) and the containment (not equality) assert on DRIFT_FIRST.
# ══════════════════════════════════════════════════════════════════════════════

echo "== AC-T2: tampered TARGET drift-check.sh -- not executed, target byte-unchanged, still reported as D1 drift =="
mk_git_repo "$ORACLE_TAMPER_TARGET"
do_install "$ORACLE_TAMPER_TARGET"
TAMPER_DRIFT_CHECK="$ORACLE_TAMPER_TARGET/.claude/autoflow/drift-check.sh"
if [ ! -f "$TAMPER_DRIFT_CHECK" ]; then
  failc "AC-T2" "prerequisite install missing drift-check.sh at $TAMPER_DRIFT_CHECK -- cannot tamper it with a side-effect stub"
else
  printf '%s\n' '#!/bin/sh' 'touch "$CLAUDE_PROJECT_DIR/PWNED_PROOF"' 'exit 0' > "$TAMPER_DRIFT_CHECK"
  PRE_SNAP=$(mktemp)
  ( cd "$ORACLE_TAMPER_TARGET" && find . -type f | sort | xargs shasum ) > "$PRE_SNAP" 2>/dev/null
  run_detect "$ORACLE_TAMPER_TARGET" "$REPO_ROOT"
  POST_SNAP=$(mktemp)
  ( cd "$ORACLE_TAMPER_TARGET" && find . -type f | sort | xargs shasum ) > "$POST_SNAP" 2>/dev/null
  AC_T2_DRIFT_FIRST=$(get_kv "$DETECT_OUT" DRIFT_FIRST)
  if [ ! -e "$ORACLE_TAMPER_TARGET/PWNED_PROOF" ] \
     && diff -q "$PRE_SNAP" "$POST_SNAP" >/dev/null 2>&1 \
     && [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "drift" ] \
     && printf '%s' "$AC_T2_DRIFT_FIRST" | grep -qF '.claude/autoflow/drift-check.sh'; then
    pass "AC-T2: tampered target drift-check.sh not executed (PWNED_PROOF absent), target byte-unchanged (full-tree hash snapshot equality), reported as D1 drift naming .claude/autoflow/drift-check.sh"
  else
    failc "AC-T2" "expected PWNED_PROOF absent + byte-unchanged target (snapshot equality) + DRIFT_STATE=drift naming .claude/autoflow/drift-check.sh; got PWNED_PROOF=$([ -e "$ORACLE_TAMPER_TARGET/PWNED_PROOF" ] && echo present || echo absent) snapshot=$(diff -q "$PRE_SNAP" "$POST_SNAP" >/dev/null 2>&1 && echo unchanged || echo CHANGED) DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) DRIFT_FIRST=$AC_T2_DRIFT_FIRST -- at HEAD detect.sh still executes the target-owned copy directly, so the tampered stub's pre-confirmation side effect fires instead of being caught (unexecuted) and reported as drift by the cache oracle"
  fi
  rm -f "$PRE_SNAP" "$POST_SNAP"
fi

echo "== AC-T3 (static): SKILL.md Step-1 region names the cache-copy drift-check execution (read-only mechanism line) =="
INSTALL_SKILL_MD="$REPO_ROOT/plugin/autoflow/skills/install/SKILL.md"
if [ ! -f "$INSTALL_SKILL_MD" ]; then
  failc "AC-T3" "install SKILL.md missing at $INSTALL_SKILL_MD"
elif awk '/^## Step 1/,/^## Step [2-9]/' "$INSTALL_SKILL_MD" | grep -i 'cache' | grep -qi 'drift-check'; then
  pass "AC-T3: SKILL.md Step-1 region carries a line naming both 'cache' and 'drift-check' (trust-source mechanism documented; verification-design §2 AC-T3 pinned token pair)"
else
  failc "AC-T3" "expected the SKILL.md Step-1 region (## Step 1 .. next ## Step) to contain a line matching both 'cache' and 'drift-check' (case-insensitive) -- the read-only trust-source mechanism (cache-copy oracle execution) must be documented where the detection step is narrated"
fi

echo "== AC3 (issue #963, static): SKILL.md Step-1 block discloses the Agent Teams env merge via a stable marker, BEFORE Step 3 =="
# Verification design §1 AC3 / feature design §2 D2 / §5 AC3 (DCR-3 option ii):
# the disclosure is anchored on a stable marker
# (<!-- AGENT-TEAMS-ENV-DISCLOSURE -->), not free prose -- a benign rephrase
# that keeps the marker + variable + caveat passes; dropping the disclosure
# removes the marker and fails. The awk range /^## Step 1/,/^## Step 2/
# extracts ONLY the Step 1 block, which structurally enforces "before the
# Step 3 confirmation" (a whole-file grep would wrongly pass a disclosure
# landed in Step 3 or an unrelated section).
if [ ! -f "$INSTALL_SKILL_MD" ]; then
  failc "AC3 (issue #963)" "install SKILL.md missing at $INSTALL_SKILL_MD"
else
  STEP1_BLOCK=$(awk '/^## Step 1/{flag=1} /^## Step 2/{flag=0} flag' "$INSTALL_SKILL_MD")
  if [ -z "$STEP1_BLOCK" ]; then
    failc "AC3 (issue #963)" "could not extract a non-empty Step 1 block (## Step 1 .. ## Step 2) from $INSTALL_SKILL_MD"
  elif ! printf '%s\n' "$STEP1_BLOCK" | grep -qF '<!-- AGENT-TEAMS-ENV-DISCLOSURE -->'; then
    failc "AC3 (issue #963)" "stable marker <!-- AGENT-TEAMS-ENV-DISCLOSURE --> not found within the SKILL.md Step 1 block -- the Agent Teams env merge disclosure is missing or misplaced"
  elif ! printf '%s\n' "$STEP1_BLOCK" | grep -qiE 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS|Agent Teams'; then
    failc "AC3 (issue #963)" "marker present but Step 1 block does not name CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS / 'Agent Teams'"
  elif ! printf '%s\n' "$STEP1_BLOCK" | grep -qiE 'experimental|token[- ]?cost'; then
    failc "AC3 (issue #963)" "marker + variable present but Step 1 block lacks an experimental/token-cost caveat"
  else
    pass "AC3 (issue #963): SKILL.md Step 1 block carries the <!-- AGENT-TEAMS-ENV-DISCLOSURE --> marker naming the Agent Teams env with an experimental/token-cost caveat, structurally before Step 2/Step 3"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# AC-M1a / AC-M1b / AC-M1-D2 — execution-failure degradation + D2-only lock
# (cycle 3, review-response on PR #959 Codex Medium: detect.sh:61 discards the
# drift-check.sh subshell exit code, so an installed drift-check.sh that
# terminates abnormally with NO 'FAIL:' line falls through to a silent
# DRIFT_STATE=clean. .autoflow/issue-943-verification-design.md §2/§2.1 (this
# doc is authoritative on arm names + the single shared CRASH_TARGET fixture
# topology; feature-design §4.2 aliases these AC3b-execfail-syntax /
# AC3b-execfail-exit / AC3b-d2only to the identical fixture).
#
# Cycle 5 (DCR-C5-1, .autoflow/issue-943-verification-design.md §3): the
# oracle-trust-source switch means detect.sh must no longer execute the
# TARGET's own drift-check.sh copy, so these arms move their crash/D2-only
# stub into a SCRATCH cache (CRASH_CACHE, never the real repo's
# setup/thin-root-layer/drift-check.sh) exercised via
# PLUGIN_CACHE_ROOT="$CRASH_CACHE". Expected DRIFT_STATE values are UNCHANGED
# from cycle 3 -- only the fixture carrying the stub moves from the target
# copy to the cache copy.
# ══════════════════════════════════════════════════════════════════════════════

mk_git_repo "$CRASH_TARGET"
do_install "$CRASH_TARGET"
mk_scratch_cache "$CRASH_CACHE"
CRASH_CACHE_DRIFT_CHECK="$CRASH_CACHE/setup/thin-root-layer/drift-check.sh"

echo "== AC-M1a: CACHE-copy drift-check.sh has a shell syntax error (exit !=0, no FAIL: line) -> DRIFT_STATE=error (cycle 5: scratch-cache fixture, DCR-C5-1) =="
printf '%s\n' 'if [ 1 -eq 1' > "$CRASH_CACHE_DRIFT_CHECK"
run_detect "$CRASH_TARGET" "$CRASH_CACHE"
if [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "error" ]; then
  pass "AC-M1a: syntax-error CACHE-copy drift-check.sh -> DRIFT_STATE=error"
else
  failc "AC-M1a" "expected DRIFT_STATE=error on a syntax-error CACHE-copy drift-check.sh (abnormal termination, no FAIL: line); got DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) -- at HEAD detect.sh still executes CRASH_TARGET's own (untouched, clean) drift-check.sh copy instead of this cache stub, so this is the cache-oracle-switch RED driver"
fi

echo "== AC-M1b: CACHE-copy drift-check.sh does a bare non-FAIL exit N (exit !=0, no FAIL: line) -> DRIFT_STATE=error (cycle 5: scratch-cache fixture) =="
printf '%s\n' '#!/bin/sh' 'echo "unexpected crash, no FAIL lines"' 'exit 7' > "$CRASH_CACHE_DRIFT_CHECK"
run_detect "$CRASH_TARGET" "$CRASH_CACHE"
if [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "error" ]; then
  pass "AC-M1b: bare 'exit 7' (no FAIL: line) CACHE-copy drift-check.sh -> DRIFT_STATE=error"
else
  failc "AC-M1b" "expected DRIFT_STATE=error on a bare non-FAIL 'exit 7' CACHE-copy drift-check.sh; got DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) -- at HEAD detect.sh still executes CRASH_TARGET's own (untouched, clean) drift-check.sh copy instead of this cache stub, so this is the cache-oracle-switch RED driver"
fi

echo "== AC-M1-D2: CACHE-copy drift-check.sh exits non-zero emitting ONLY a 'FAIL: D2 ...' line -> DRIFT_STATE=clean, DRIFT_FAILS=0, DRIFT_FIRST empty (cycle 5: scratch-cache fixture) =="
printf '%s\n' '#!/bin/sh' 'echo "FAIL: D2 -- version skew: manifest=1 plugin=2"' 'exit 1' > "$CRASH_CACHE_DRIFT_CHECK"
run_detect "$CRASH_TARGET" "$CRASH_CACHE"
D2LOCK_DRIFT_FIRST=$(get_kv "$DETECT_OUT" DRIFT_FIRST)
if [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "clean" ] \
   && [ "$(get_kv "$DETECT_OUT" DRIFT_FAILS)" = "0" ] \
   && [ -z "$D2LOCK_DRIFT_FIRST" ]; then
  pass "AC-M1-D2: D2-only non-zero exit (cache copy) -> DRIFT_STATE=clean DRIFT_FAILS=0 DRIFT_FIRST empty (discriminates the correct fix from a naive rc!=0=>error promotion; witness -- passes both pre- and post-cache-switch since CRASH_TARGET's own clean copy also yields clean)"
else
  failc "AC-M1-D2" "expected DRIFT_STATE=clean DRIFT_FAILS=0 DRIFT_FIRST empty on a D2-only non-zero exit (cache copy); got DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) DRIFT_FAILS=$(get_kv "$DETECT_OUT" DRIFT_FAILS) DRIFT_FIRST=$D2LOCK_DRIFT_FIRST -- a D2-only failure must stay 'clean' (D2 is intentionally filtered), not be promoted to error/drift"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AC3b' / AC3b" — version skew + drift/skew non-conflation
# ══════════════════════════════════════════════════════════════════════════════

echo "== AC3b'-lockstep: cache setup/manifest.json .version == cache plugin.json .version =="
if [ -f "$CACHE_MANIFEST" ] && [ -f "$CACHE_PLUGIN_JSON" ]; then
  MVER=$(jq -r '.version // empty' "$CACHE_MANIFEST")
  PVER=$(jq -r '.version // empty' "$CACHE_PLUGIN_JSON")
  if [ -n "$MVER" ] && [ "$MVER" = "$PVER" ]; then
    pass "AC3b'-lockstep: cache setup/manifest.json.version ($MVER) == plugin.json.version ($PVER) -- R2-stamp lockstep holds"
  else
    failc "AC3b'-lockstep" "cache version lockstep broken: setup/manifest.json.version='$MVER' plugin.json.version='$PVER' -- VERSION_SKEW's like-for-like comparand assumption would silently diverge"
  fi
else
  failc "AC3b'-lockstep" "cache setup/manifest.json or plugin.json missing"
fi

echo "== AC3b': installed manifest.version older than cache -> VERSION_SKEW=yes (both fields populated) =="
if [ -f "$CLEAN_TARGET/.claude/autoflow/manifest.json" ]; then
  jq '.version = "0.0.1"' "$CLEAN_TARGET/.claude/autoflow/manifest.json" > "$CLEAN_TARGET/.claude/autoflow/manifest.json.tmp" \
    && mv "$CLEAN_TARGET/.claude/autoflow/manifest.json.tmp" "$CLEAN_TARGET/.claude/autoflow/manifest.json"
  run_detect "$CLEAN_TARGET" "$REPO_ROOT"
  if [ "$(get_kv "$DETECT_OUT" VERSION_SKEW)" = "yes" ] \
     && [ "$(get_kv "$DETECT_OUT" VERSION_INSTALLED)" = "0.0.1" ] \
     && [ -n "$(get_kv "$DETECT_OUT" VERSION_CACHE)" ]; then
    pass "AC3b': installed=0.0.1 vs cache -> VERSION_SKEW=yes, both version fields populated"
  else
    failc "AC3b'" "expected VERSION_SKEW=yes with populated fields; got VERSION_SKEW=$(get_kv "$DETECT_OUT" VERSION_SKEW) VERSION_INSTALLED=$(get_kv "$DETECT_OUT" VERSION_INSTALLED) VERSION_CACHE=$(get_kv "$DETECT_OUT" VERSION_CACHE)"
  fi
else
  failc "AC3b'" "prerequisite clean install missing manifest.json -- cannot force a version-skew fixture"
fi

echo "== AC3b' (equal): fresh install version matches cache -> VERSION_SKEW=no =="
mk_git_repo "$SKEW_TARGET"
do_install "$SKEW_TARGET"
run_detect "$SKEW_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" VERSION_SKEW)" = "no" ]; then
  pass "AC3b' (equal): freshly-stamped target's version matches cache -> VERSION_SKEW=no"
else
  failc "AC3b' (equal)" "expected VERSION_SKEW=no on a fresh matching-version install; got $(get_kv "$DETECT_OUT" VERSION_SKEW)"
fi

echo "== AC3b\" (non-conflation, C2): content-clean + version-skew-only -> VERSION_SKEW=yes AND DRIFT_STATE=clean/DRIFT_FAILS=0 =="
if [ -f "$SKEW_TARGET/.claude/autoflow/manifest.json" ]; then
  jq '.version = "0.0.1"' "$SKEW_TARGET/.claude/autoflow/manifest.json" > "$SKEW_TARGET/.claude/autoflow/manifest.json.tmp" \
    && mv "$SKEW_TARGET/.claude/autoflow/manifest.json.tmp" "$SKEW_TARGET/.claude/autoflow/manifest.json"
  run_detect "$SKEW_TARGET" "$REPO_ROOT"
  DRIFT_FIRST_SKEW=$(get_kv "$DETECT_OUT" DRIFT_FIRST)
  if [ "$(get_kv "$DETECT_OUT" VERSION_SKEW)" = "yes" ] \
     && [ "$(get_kv "$DETECT_OUT" DRIFT_STATE)" = "clean" ] \
     && [ "$(get_kv "$DETECT_OUT" DRIFT_FAILS)" = "0" ] \
     && [ -z "$DRIFT_FIRST_SKEW" ]; then
    pass "AC3b\": a pure version bump reports VERSION_SKEW=yes WITHOUT double-reporting as DRIFT_STATE=drift (C2 filter witness)"
  else
    failc "AC3b\"" "conflation detected: VERSION_SKEW=$(get_kv "$DETECT_OUT" VERSION_SKEW) DRIFT_STATE=$(get_kv "$DETECT_OUT" DRIFT_STATE) DRIFT_FAILS=$(get_kv "$DETECT_OUT" DRIFT_FAILS) DRIFT_FIRST=$DRIFT_FIRST_SKEW -- a version-only bump must not surface as content drift"
  fi
else
  failc "AC3b\"" "prerequisite install missing manifest.json in SKEW_TARGET"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AD1 — git-state auto-derivation (org/repo/default-branch), graceful omission
# ══════════════════════════════════════════════════════════════════════════════

echo "== AD1: GitHub origin -> ORG/REPO/DEFAULT_BRANCH populated =="
mk_git_repo "$GITHUB_TARGET"
add_github_origin "$GITHUB_TARGET" "dummy-org" "throwaway-dummy"
run_detect "$GITHUB_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" ORG)" = "dummy-org" ] \
   && [ "$(get_kv "$DETECT_OUT" REPO)" = "throwaway-dummy" ] \
   && [ -n "$(get_kv "$DETECT_OUT" DEFAULT_BRANCH)" ]; then
  pass "AD1: GitHub origin derives ORG=dummy-org REPO=throwaway-dummy DEFAULT_BRANCH populated"
else
  failc "AD1" "expected derived ORG/REPO/DEFAULT_BRANCH; got ORG=$(get_kv "$DETECT_OUT" ORG) REPO=$(get_kv "$DETECT_OUT" REPO) DEFAULT_BRANCH=$(get_kv "$DETECT_OUT" DEFAULT_BRANCH)"
fi

echo "== AD1 (omission): non-GitHub/absent remote -> ORG/REPO/DEFAULT_BRANCH empty, exit 0, no prompt =="
mk_git_repo "$NONGITHUB_TARGET"
add_non_github_origin "$NONGITHUB_TARGET"
run_detect "$NONGITHUB_TARGET" "$REPO_ROOT"
if [ "$DETECT_CODE" -eq 0 ] \
   && [ -z "$(get_kv "$DETECT_OUT" ORG)" ] \
   && [ -z "$(get_kv "$DETECT_OUT" REPO)" ]; then
  pass "AD1 (omission): non-GitHub remote -> ORG/REPO omitted (empty), exit 0 (not an error)"
else
  failc "AD1 (omission)" "expected empty ORG/REPO with exit 0 on a non-GitHub remote; got exit=$DETECT_CODE ORG=$(get_kv "$DETECT_OUT" ORG) REPO=$(get_kv "$DETECT_OUT" REPO)"
fi

echo "== AD1 (F3, SSH form): git@github.com:org/repo.git origin -> same ORG/REPO derivation as https =="
mk_git_repo "$SSH_TARGET"
( cd "$SSH_TARGET" \
    && git remote add origin "git@github.com:dummy-org/ssh-dummy.git" \
    && git update-ref refs/remotes/origin/main "$(git -C "$SSH_TARGET" rev-parse HEAD)" \
    && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main )
run_detect "$SSH_TARGET" "$REPO_ROOT"
if [ "$DETECT_CODE" -eq 0 ] \
   && [ "$(get_kv "$DETECT_OUT" ORG)" = "dummy-org" ] \
   && [ "$(get_kv "$DETECT_OUT" REPO)" = "ssh-dummy" ]; then
  pass "AD1 (F3, SSH form): SSH origin derives ORG=dummy-org REPO=ssh-dummy (parity with https arm)"
else
  failc "AD1 (F3, SSH form)" "expected ORG=dummy-org REPO=ssh-dummy from an SSH-form origin; got exit=$DETECT_CODE ORG=$(get_kv "$DETECT_OUT" ORG) REPO=$(get_kv "$DETECT_OUT" REPO)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AD1-slash / AD1-slash-scaffold / AD1-slash-multi — slash-qualified
# DEFAULT_BRANCH derivation + scaffold propagation (cycle 4, review-response
# on Codex Low, PR #959: detect.sh:130 `${_head##*/}` greedily strips to the
# final path segment; the fix must preserve the full branch name).
# .autoflow/issue-943-verification-design.md §2 (cycle 4) is authoritative on
# arm placement/ordering: the scaffold-propagation arm MUST run while
# origin/HEAD still targets the single-slash branch, before the multi-slash
# re-point -- DERIVED reads the LAST run_detect output.
# ══════════════════════════════════════════════════════════════════════════════

echo "== AD1-slash: single-slash origin/HEAD (release/2026) -> DEFAULT_BRANCH=release/2026 (full name, not truncated) =="
mk_git_repo "$SLASHBRANCH_TARGET"
add_github_origin_branch "$SLASHBRANCH_TARGET" "dummy-org" "throwaway-dummy" "release/2026"
run_detect "$SLASHBRANCH_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" DEFAULT_BRANCH)" = "release/2026" ]; then
  pass "AD1-slash: single-slash origin/HEAD -> DEFAULT_BRANCH=release/2026 (full name)"
else
  failc "AD1-slash" "expected DEFAULT_BRANCH=release/2026 (full slash-qualified branch name); got DEFAULT_BRANCH=$(get_kv "$DETECT_OUT" DEFAULT_BRANCH) -- a truncated '2026' here is the slash-drop the Codex Low flagged"
fi

echo "== AD1-slash-scaffold: detect-derived slash-qualified DEFAULT_BRANCH propagates into scaffolded CLAUDE.local.md =="
SLASH_DERIVED=$(get_kv "$DETECT_OUT" DEFAULT_BRANCH)
SLASH_ORG_D=$(get_kv "$DETECT_OUT" ORG)
SLASH_REPO_D=$(get_kv "$DETECT_OUT" REPO)
run_scaffold "$SLASHBRANCH_TARGET" "$SLASH_ORG_D" "$SLASH_REPO_D" "$SLASH_DERIVED" "single"
if [ "$SCAFFOLD_CODE" -eq 0 ] \
   && grep -qF 'Default branch: release/2026' "$SLASHBRANCH_TARGET/CLAUDE.local.md" 2>/dev/null; then
  pass "AD1-slash-scaffold: scaffolded CLAUDE.local.md carries 'Default branch: release/2026' (full name, not '2026')"
else
  failc "AD1-slash-scaffold" "expected the scaffolded CLAUDE.local.md to contain 'Default branch: release/2026'; derived-value fed=$SLASH_DERIVED exit=$SCAFFOLD_CODE draft-line='$(grep -F 'Default branch:' "$SLASHBRANCH_TARGET/CLAUDE.local.md" 2>/dev/null)' -- a truncated '2026' here is the slash-drop propagating into both pipeline sinks"
fi

echo "== AD1-slash-multi: non-nesting multi-slash origin/HEAD (feature/x/y) -> DEFAULT_BRANCH=feature/x/y (full remainder, not last-two-segments) =="
add_github_origin_branch "$SLASHBRANCH_TARGET" "dummy-org" "throwaway-dummy" "feature/x/y"
run_detect "$SLASHBRANCH_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" DEFAULT_BRANCH)" = "feature/x/y" ]; then
  pass "AD1-slash-multi: multi-slash origin/HEAD -> DEFAULT_BRANCH=feature/x/y (full remainder)"
else
  failc "AD1-slash-multi" "expected DEFAULT_BRANCH=feature/x/y (full multi-slash branch name); got DEFAULT_BRANCH=$(get_kv "$DETECT_OUT" DEFAULT_BRANCH) -- a truncated 'y' (or a last-two-segment 'x/y') here fails the full-remainder contract"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AD2 — topology auto-judge
# ══════════════════════════════════════════════════════════════════════════════

echo "== AD2: zero-submodule fixture -> TOPOLOGY=single =="
mk_git_repo "$SINGLE_TOPO_TARGET"
run_detect "$SINGLE_TOPO_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" TOPOLOGY)" = "single" ]; then
  pass "AD2: zero-submodule fixture -> TOPOLOGY=single"
else
  failc "AD2" "expected TOPOLOGY=single; got $(get_kv "$DETECT_OUT" TOPOLOGY)"
fi

echo "== AD2: .gitmodules entry present -> TOPOLOGY=multi =="
mk_git_repo "$MULTI_TOPO_TARGET"
add_submodule "$MULTI_TOPO_TARGET"
run_detect "$MULTI_TOPO_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" TOPOLOGY)" = "multi" ]; then
  pass "AD2: submodule-present fixture -> TOPOLOGY=multi"
else
  failc "AD2" "expected TOPOLOGY=multi (submodule registered); got $(get_kv "$DETECT_OUT" TOPOLOGY)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AD3 — fork-URL confirmation gate (multi-repo only; mocked gh + gh-absent arm)
# ══════════════════════════════════════════════════════════════════════════════

MOCK_GH="$MOCK_GH_DIR/gh"

echo "== AD3: multi-repo fixture + gh mock (fork exists) -> FORK_PROPOSAL derived, FORK_EXISTS=yes =="
add_github_origin "$MULTI_TOPO_TARGET" "dummy-org" "throwaway-dummy"
cat > "$MOCK_GH" <<'MOCKGH_YES'
#!/bin/sh
case "$*" in
  *"repo view"*) exit 0 ;;
  *) exit 0 ;;
esac
MOCKGH_YES
chmod +x "$MOCK_GH"
run_detect_with_gh() {
  if [ ! -f "$DETECT_SH" ]; then
    DETECT_OUT=""; DETECT_CODE=127; return
  fi
  DETECT_OUT=$(PATH="$MOCK_GH_DIR:$PATH" TARGET_ROOT="$1" PLUGIN_CACHE_ROOT="$2" bash "$DETECT_SH" 2>&1)
  DETECT_CODE=$?
}
run_detect_with_gh "$MULTI_TOPO_TARGET" "$REPO_ROOT"
if [ -n "$(get_kv "$DETECT_OUT" FORK_PROPOSAL)" ] && [ "$(get_kv "$DETECT_OUT" FORK_EXISTS)" = "yes" ]; then
  pass "AD3: multi-repo + gh-exists mock -> FORK_PROPOSAL derived, FORK_EXISTS=yes"
else
  failc "AD3" "expected a derived FORK_PROPOSAL with FORK_EXISTS=yes; got FORK_PROPOSAL=$(get_kv "$DETECT_OUT" FORK_PROPOSAL) FORK_EXISTS=$(get_kv "$DETECT_OUT" FORK_EXISTS)"
fi

echo "== AD3: gh mock (fork does not exist) -> FORK_EXISTS=no =="
cat > "$MOCK_GH" <<'MOCKGH_NO'
#!/bin/sh
case "$*" in
  *"repo view"*) exit 1 ;;
  *) exit 0 ;;
esac
MOCKGH_NO
chmod +x "$MOCK_GH"
run_detect_with_gh "$MULTI_TOPO_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" FORK_EXISTS)" = "no" ]; then
  pass "AD3: gh-not-found mock -> FORK_EXISTS=no"
else
  failc "AD3" "expected FORK_EXISTS=no with a gh 'not found' mock; got $(get_kv "$DETECT_OUT" FORK_EXISTS)"
fi

echo "== AD3 (OC-2, gh-absent): gh unavailable -> FORK_EXISTS=unknown, still exit 0 (graceful degradation) =="
NO_GH_PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^$MOCK_GH_DIR\$" | grep -vE '/usr/(local/)?bin$|/opt/homebrew/bin$' | tr '\n' ':')
if [ -z "$NO_GH_PATH" ]; then NO_GH_PATH="/nonexistent"; fi
if [ ! -f "$DETECT_SH" ]; then
  DETECT_OUT=""; DETECT_CODE=127
else
  DETECT_OUT=$(PATH="$NO_GH_PATH" TARGET_ROOT="$MULTI_TOPO_TARGET" PLUGIN_CACHE_ROOT="$REPO_ROOT" bash "$DETECT_SH" 2>&1)
  DETECT_CODE=$?
fi
if [ "$DETECT_CODE" -eq 0 ] && [ "$(get_kv "$DETECT_OUT" FORK_EXISTS)" = "unknown" ]; then
  pass "AD3 (OC-2): gh unavailable -> FORK_EXISTS=unknown, exit 0"
else
  failc "AD3 (OC-2)" "expected FORK_EXISTS=unknown with exit 0 when gh is absent; got exit=$DETECT_CODE FORK_EXISTS=$(get_kv "$DETECT_OUT" FORK_EXISTS)"
fi

echo "== AD3 (dormant): single-repo fixture -> FORK_PROPOSAL empty (gate dormant) =="
if [ ! -f "$DETECT_SH" ]; then
  failc "AD3 (dormant)" "detect.sh missing at $DETECT_SH -- an empty FORK_PROPOSAL from a missing script is not a verified dormant-gate behavior"
else
  run_detect "$GITHUB_TARGET" "$REPO_ROOT"
  if [ -z "$(get_kv "$DETECT_OUT" FORK_PROPOSAL)" ]; then
    pass "AD3 (dormant): single-repo fixture -> FORK_PROPOSAL empty"
  else
    failc "AD3 (dormant)" "expected empty FORK_PROPOSAL on a single-repo (zero-submodule) fixture; got $(get_kv "$DETECT_OUT" FORK_PROPOSAL)"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# AD4 — scaffold-identity.sh: never-overwrite (i) + derived-draft generation (ii)
# ══════════════════════════════════════════════════════════════════════════════

echo "== AD4(i): CLAUDE.local.md present -> byte-unchanged + 'skipped' branch printed (R3 never-overwrite) =="
mk_git_repo "$IDENTITY_PRESENT_TARGET"
printf '# CLAUDE.local.md — pre-existing target-authored content\n' > "$IDENTITY_PRESENT_TARGET/CLAUDE.local.md"
PRE_SUM=$(shasum -a 256 "$IDENTITY_PRESENT_TARGET/CLAUDE.local.md" 2>/dev/null | awk '{print $1}')
run_scaffold "$IDENTITY_PRESENT_TARGET" "dummy-org" "throwaway-dummy" "main" "single"
POST_SUM=$(shasum -a 256 "$IDENTITY_PRESENT_TARGET/CLAUDE.local.md" 2>/dev/null | awk '{print $1}')
if [ -n "$PRE_SUM" ] && [ "$PRE_SUM" = "$POST_SUM" ] \
   && [ "$SCAFFOLD_CODE" -eq 0 ] \
   && printf '%s' "$SCAFFOLD_OUT" | grep -qiE 'present|skip'; then
  pass "AD4(i): pre-existing CLAUDE.local.md is byte-unchanged and the 'present, skipped' branch is printed"
else
  failc "AD4(i)" "expected byte-unchanged file + a 'present/skip' branch message; pre=$PRE_SUM post=$POST_SUM exit=$SCAFFOLD_CODE out=$SCAFFOLD_OUT"
fi

echo "== F1: detect.sh emits LOCAL_MD_EXISTS correctly (yes on present, no on absent) =="
run_detect "$IDENTITY_PRESENT_TARGET" "$REPO_ROOT"
LOCAL_MD_YES=$(get_kv "$DETECT_OUT" LOCAL_MD_EXISTS)
run_detect "$ABSENT_TARGET" "$REPO_ROOT"
LOCAL_MD_NO=$(get_kv "$DETECT_OUT" LOCAL_MD_EXISTS)
if [ "$LOCAL_MD_YES" = "yes" ] && [ "$LOCAL_MD_NO" = "no" ]; then
  pass "F1: LOCAL_MD_EXISTS=yes on a CLAUDE.local.md-present target, =no on an absent one"
else
  failc "F1" "expected LOCAL_MD_EXISTS yes/no per fixture; got present-target='$LOCAL_MD_YES' absent-target='$LOCAL_MD_NO'"
fi

echo "== AD4(ii): CLAUDE.local.md absent -> derived draft written with derived values + '(set manually)' placeholders =="
mk_git_repo "$IDENTITY_ABSENT_TARGET"
run_scaffold "$IDENTITY_ABSENT_TARGET" "dummy-org" "" "main" "single"
DRAFT="$IDENTITY_ABSENT_TARGET/CLAUDE.local.md"
if [ "$SCAFFOLD_CODE" -eq 0 ] && [ -f "$DRAFT" ] \
   && grep -qF "dummy-org" "$DRAFT" \
   && grep -qF "main" "$DRAFT" \
   && grep -qiE '\(set manually\)' "$DRAFT"; then
  pass "AD4(ii): absent CLAUDE.local.md -> derived draft written with derived org/branch values and a (set manually) placeholder for the empty REPO field"
else
  failc "AD4(ii)" "expected a written draft containing derived values + '(set manually)' for the empty field; exit=$SCAFFOLD_CODE draft-exists=$([ -f "$DRAFT" ] && echo yes || echo no)"
fi

echo "== AD4 (F3, unknown topology): empty TOPOLOGY -> 'Topology: (set manually)' label in draft =="
mk_git_repo "$IDENTITY_UNKNOWN_TARGET"
run_scaffold "$IDENTITY_UNKNOWN_TARGET" "dummy-org" "throwaway-dummy" "main" ""
UNKNOWN_DRAFT="$IDENTITY_UNKNOWN_TARGET/CLAUDE.local.md"
if [ "$SCAFFOLD_CODE" -eq 0 ] && [ -f "$UNKNOWN_DRAFT" ] \
   && grep -qF "Topology: (set manually)" "$UNKNOWN_DRAFT"; then
  pass "AD4 (F3, unknown topology): empty TOPOLOGY renders 'Topology: (set manually)' in the draft"
else
  failc "AD4 (F3, unknown topology)" "expected 'Topology: (set manually)' in the draft on an empty TOPOLOGY; exit=$SCAFFOLD_CODE draft-exists=$([ -f "$UNKNOWN_DRAFT" ] && echo yes || echo no) topology-line='$(grep -F 'Topology:' "$UNKNOWN_DRAFT" 2>/dev/null)'"
fi

# ══════════════════════════════════════════════════════════════════════════════
# C4-AC-1/2/3/6 (issue #979 cycle 4) — set-review-backend.sh persistence seam
# ══════════════════════════════════════════════════════════════════════════════

echo "== C4-AC-1: codex-default config + explicit BACKEND=claude -> .review.backend == claude, exit 0 =="
mk_git_repo "$BACKEND_TARGET"
mkdir -p "$BACKEND_TARGET/.claude"
printf '{ "review": { "backend": "codex" } }\n' > "$BACKEND_TARGET/.claude/autoflow.local.json"
run_set_backend "$BACKEND_TARGET" "claude"
if [ "$BACKEND_CODE" -eq 0 ] \
   && [ "$(jq -r '.review.backend' "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null)" = "claude" ]; then
  pass "C4-AC-1: explicit BACKEND=claude on a codex-default config persists .review.backend == claude, exit 0"
else
  failc "C4-AC-1" "expected exit 0 + .review.backend == claude after an explicit-claude run; exit=$BACKEND_CODE out=$BACKEND_OUT config=$(cat "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null)"
fi

echo "== C4-AC-2: empty BACKEND -> exit 2, config byte-unchanged =="
mk_git_repo "$BACKEND_TARGET"
mkdir -p "$BACKEND_TARGET/.claude"
printf '{ "review": { "backend": "codex" } }\n' > "$BACKEND_TARGET/.claude/autoflow.local.json"
PRE_EMPTY_SUM=$(shasum -a 256 "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null | awk '{print $1}')
run_set_backend "$BACKEND_TARGET" ""
POST_EMPTY_SUM=$(shasum -a 256 "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null | awk '{print $1}')
if [ "$BACKEND_CODE" -eq 2 ] && [ -n "$PRE_EMPTY_SUM" ] && [ "$PRE_EMPTY_SUM" = "$POST_EMPTY_SUM" ]; then
  pass "C4-AC-2: empty BACKEND -> exit 2, config file byte-unchanged"
else
  failc "C4-AC-2" "expected exit 2 + byte-unchanged config on empty BACKEND; exit=$BACKEND_CODE pre=$PRE_EMPTY_SUM post=$POST_EMPTY_SUM out=$BACKEND_OUT"
fi

echo "== C4-AC-2: bogus BACKEND=xyz -> exit 2, config byte-unchanged =="
mk_git_repo "$BACKEND_TARGET"
mkdir -p "$BACKEND_TARGET/.claude"
printf '{ "review": { "backend": "codex" } }\n' > "$BACKEND_TARGET/.claude/autoflow.local.json"
PRE_BOGUS_SUM=$(shasum -a 256 "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null | awk '{print $1}')
run_set_backend "$BACKEND_TARGET" "xyz"
POST_BOGUS_SUM=$(shasum -a 256 "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null | awk '{print $1}')
if [ "$BACKEND_CODE" -eq 2 ] && [ -n "$PRE_BOGUS_SUM" ] && [ "$PRE_BOGUS_SUM" = "$POST_BOGUS_SUM" ]; then
  pass "C4-AC-2: bogus BACKEND=xyz -> exit 2, config file byte-unchanged"
else
  failc "C4-AC-2" "expected exit 2 + byte-unchanged config on bogus BACKEND; exit=$BACKEND_CODE pre=$PRE_BOGUS_SUM post=$POST_BOGUS_SUM out=$BACKEND_OUT"
fi

echo "== C4-AC-3: jq-present merge fidelity -- switching backend preserves sibling custom keys =="
mk_git_repo "$BACKEND_TARGET"
mkdir -p "$BACKEND_TARGET/.claude"
printf '{ "review": { "backend": "codex" }, "custom": { "k": 1 } }\n' > "$BACKEND_TARGET/.claude/autoflow.local.json"
run_set_backend "$BACKEND_TARGET" "claude"
if [ "$BACKEND_CODE" -eq 0 ] \
   && [ "$(jq -r '.review.backend' "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null)" = "claude" ] \
   && [ "$(jq -r '.custom.k' "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null)" = "1" ]; then
  pass "C4-AC-3: switching backend to claude preserves the sibling .custom.k key (single-key merge, not a whole-file clobber)"
else
  failc "C4-AC-3" "expected .review.backend == claude AND .custom.k == 1 preserved after the switch; exit=$BACKEND_CODE config=$(cat "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null)"
fi

echo "== C4-AC-6: jq-absent + pre-existing config -> REFUSE (exit 1, byte-unchanged) =="
mk_git_repo "$BACKEND_TARGET"
mkdir -p "$BACKEND_TARGET/.claude"
printf '{ "review": { "backend": "codex" } }\n' > "$BACKEND_TARGET/.claude/autoflow.local.json"
PRE_NOJQ_SUM=$(shasum -a 256 "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null | awk '{print $1}')
NO_JQ_PATH=$(path_without_jq)
run_set_backend "$BACKEND_TARGET" "claude" "$NO_JQ_PATH"
POST_NOJQ_SUM=$(shasum -a 256 "$BACKEND_TARGET/.claude/autoflow.local.json" 2>/dev/null | awk '{print $1}')
if [ "$BACKEND_CODE" -eq 1 ] && [ -n "$PRE_NOJQ_SUM" ] && [ "$PRE_NOJQ_SUM" = "$POST_NOJQ_SUM" ]; then
  pass "C4-AC-6: jq-absent run against a pre-existing config refuses (exit 1), file byte-unchanged (no clobber)"
else
  failc "C4-AC-6" "expected exit 1 + byte-unchanged config when jq is absent from PATH and a file pre-exists; exit=$BACKEND_CODE pre=$PRE_NOJQ_SUM post=$POST_NOJQ_SUM out=$BACKEND_OUT path=$NO_JQ_PATH"
fi

echo "== C4-AC-6: jq-absent + no pre-existing config -> writes the canonical literal, exit 0 (nothing to preserve) =="
mk_git_repo "$BACKEND_TARGET"
rm -rf "$BACKEND_TARGET/.claude"
NO_JQ_PATH_ABSENT=$(path_without_jq)
run_set_backend "$BACKEND_TARGET" "claude" "$NO_JQ_PATH_ABSENT"
if [ "$BACKEND_CODE" -eq 0 ] && [ -f "$BACKEND_TARGET/.claude/autoflow.local.json" ] \
   && grep -qF 'claude' "$BACKEND_TARGET/.claude/autoflow.local.json"; then
  pass "C4-AC-6: jq-absent run against an absent config writes the canonical claude literal, exit 0"
else
  failc "C4-AC-6" "expected exit 0 + a written canonical-literal config when jq is absent and no file pre-exists; exit=$BACKEND_CODE exists=$([ -f "$BACKEND_TARGET/.claude/autoflow.local.json" ] && echo yes || echo no) out=$BACKEND_OUT path=$NO_JQ_PATH_ABSENT"
fi

echo "== C4-AC-4 (static): SKILL.md Step-4 block wires the backend-persistence seam, post-init.sh, via a stable marker =="
# Verification design §1 C4-AC-4 / feature design §5: Step 4 is the terminal
# '## Step' (no '## Step 5' exists; its sub-steps are bold **a.**..**d.**, not
# headings), so 'awk /^## Step 4/{flag=1} flag' extracts Step-4-to-EOF, the
# whole Step-4 block. Mirrors the AC3(#963) marker-anchored, window-extracted
# model already in this suite.
if [ ! -f "$INSTALL_SKILL_MD" ]; then
  failc "C4-AC-4" "install SKILL.md missing at $INSTALL_SKILL_MD"
else
  STEP4_BLOCK=$(awk '/^## Step 4/{flag=1} /^## Step [5-9]/{flag=0} flag' "$INSTALL_SKILL_MD")
  if [ -z "$STEP4_BLOCK" ]; then
    failc "C4-AC-4" "could not extract a non-empty Step 4 block (## Step 4 .. EOF) from $INSTALL_SKILL_MD"
  elif ! printf '%s\n' "$STEP4_BLOCK" | grep -qF '<!-- REVIEWER-BACKEND-PERSIST -->'; then
    failc "C4-AC-4" "stable marker <!-- REVIEWER-BACKEND-PERSIST --> not found within the SKILL.md Step 4 block -- the backend-persistence wiring is missing or misplaced"
  elif ! printf '%s\n' "$STEP4_BLOCK" | grep -qiE 'set-review-backend\.sh|autoflow\.local\.json'; then
    failc "C4-AC-4" "marker present but Step 4 block does not name set-review-backend.sh / autoflow.local.json"
  elif ! printf '%s\n' "$STEP4_BLOCK" | grep -qiE 'explicit|claude'; then
    failc "C4-AC-4" "marker + invocation present but Step 4 block lacks the explicit-selection / claude condition"
  else
    INIT_LINE=$(grep -n 'init\.sh' "$INSTALL_SKILL_MD" | grep -v '^\s*#' | tail -1 | cut -d: -f1)
    PERSIST_LINE=$(grep -n '<!-- REVIEWER-BACKEND-PERSIST -->' "$INSTALL_SKILL_MD" | tail -1 | cut -d: -f1)
    if [ -z "$INIT_LINE" ] || [ -z "$PERSIST_LINE" ]; then
      failc "C4-AC-4" "could not locate line numbers for the init.sh invocation and/or the REVIEWER-BACKEND-PERSIST marker to verify ordering"
    elif [ "$PERSIST_LINE" -le "$INIT_LINE" ]; then
      failc "C4-AC-4" "expected the REVIEWER-BACKEND-PERSIST marker (line $PERSIST_LINE) to appear AFTER the init.sh invocation (line $INIT_LINE) -- the persistence write must run only after the file exists"
    else
      pass "C4-AC-4: SKILL.md Step 4 block carries the <!-- REVIEWER-BACKEND-PERSIST --> marker, names the persistence seam, gates it on the explicit claude selection, and is ordered after the init.sh stamp"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# C5-AC-3/4/6 (issue #979 cycle 5, review-response, Codex Medium
# issue-comment 4931950297) — detect.sh does not report a malformed or
# empty-value config as REVIEW_BACKEND=codex; absent/{}/null still report
# codex (regression pin).
#
# RED expectation (this commit): HEAD's
# `REVIEW_BACKEND=$(jq … 2>/dev/null || echo codex)` + `[ -n ] || REVIEW_BACKEND=codex`
# idiom swallows jq's exit status and masks an empty value, so a malformed
# or empty-value config is reported as REVIEW_BACKEND=codex — the
# 'REVIEW_BACKEND=invalid' assertions below FAIL at HEAD.
# ══════════════════════════════════════════════════════════════════════════════

echo "== C5-AC-3: malformed .claude/autoflow.local.json -> detect.sh reports REVIEW_BACKEND=invalid (not codex) =="
mk_git_repo "$BACKEND5_TARGET"
mkdir -p "$BACKEND5_TARGET/.claude"
printf '{ "review": { "backend": "claude"' > "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "invalid" ]; then
  pass "C5-AC-3: malformed config -> detect.sh reports REVIEW_BACKEND=invalid"
else
  failc "C5-AC-3" "expected REVIEW_BACKEND=invalid on a malformed config; got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

echo "== C5-AC-6(C): empty .review.backend (\"\") -> detect.sh reports REVIEW_BACKEND=invalid =="
printf '{ "review": { "backend": "" } }\n' > "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "invalid" ]; then
  pass "C5-AC-6(C): empty .review.backend value -> detect.sh reports REVIEW_BACKEND=invalid"
else
  failc "C5-AC-6(C)" "expected REVIEW_BACKEND=invalid on an empty-string backend value; got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

echo "== C5-AC-4: absent file / {} / null still report REVIEW_BACKEND=codex (regression pin) =="
rm -f "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "codex" ]; then
  pass "C5-AC-4 (absent file): detect.sh still reports REVIEW_BACKEND=codex"
else
  failc "C5-AC-4 (absent file)" "expected REVIEW_BACKEND=codex on an absent config; got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

printf '{}\n' > "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "codex" ]; then
  pass "C5-AC-4 (empty object {}): detect.sh still reports REVIEW_BACKEND=codex"
else
  failc "C5-AC-4 (empty object {})" "expected REVIEW_BACKEND=codex on an absent-key config; got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

printf '{ "review": { "backend": null } }\n' > "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "codex" ]; then
  pass "C5-AC-4 (null backend): detect.sh still reports REVIEW_BACKEND=codex"
else
  failc "C5-AC-4 (null backend)" "expected REVIEW_BACKEND=codex on a null .review.backend; got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

# ══════════════════════════════════════════════════════════════════════════════
# C6-AC-1/2 (issue #979 cycle 6, review-response, Round-5 Codex Low finding) —
# detect.sh's compound guard `[ -f "$_bcfg" ] && command -v jq >/dev/null 2>&1`
# silently keeps REVIEW_BACKEND at its codex default when the config file is
# PRESENT but jq is ABSENT from PATH -- indistinguishable from the
# config-absent case. The split must report `invalid` for present+jq-absent
# (C6-AC-1) while NOT over-triggering the absent+jq-absent case, which must
# still report `codex` (C6-AC-2).
#
# RED expectation (this commit): HEAD's single compound guard short-circuits
# on `command -v jq` failing, so the whole body (including the would-be
# `invalid` assignment) is skipped and REVIEW_BACKEND stays at the line-165
# `codex` default even with a present, valid, non-codex config -- the
# C6-AC-1 assertion below FAILS at HEAD. C6-AC-2 already passes at HEAD (the
# config-absent case is unaffected by the guard split) and must stay green.
# ══════════════════════════════════════════════════════════════════════════════

# run_detect_no_jq <target-root> <plugin-cache-root> -- invokes detect.sh
# under a jq-stripped PATH (path_without_jq's symlink farm), mirroring
# run_detect_with_gh's PATH-injection pattern (verification design DCR-1).
# Sets DETECT_OUT / DETECT_CODE globals.
run_detect_no_jq() {
  if [ ! -f "$DETECT_SH" ]; then
    DETECT_OUT=""; DETECT_CODE=127; return
  fi
  DETECT_OUT=$(PATH="$(path_without_jq)" TARGET_ROOT="$1" PLUGIN_CACHE_ROOT="$2" bash "$DETECT_SH" 2>&1)
  DETECT_CODE=$?
}

echo "== C6-AC-1: config present (valid, non-codex backend) + jq absent from PATH -> detect.sh reports REVIEW_BACKEND=invalid (never codex) =="
mk_git_repo "$BACKEND5_TARGET"
mkdir -p "$BACKEND5_TARGET/.claude"
printf '{ "review": { "backend": "claude" } }\n' > "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect_no_jq "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "invalid" ] && [ "$DETECT_CODE" -eq 0 ]; then
  pass "C6-AC-1: config present + jq absent -> detect.sh reports REVIEW_BACKEND=invalid, exit 0 (reporter, not enforcer)"
else
  failc "C6-AC-1" "expected REVIEW_BACKEND=invalid and exit=0 when the config is present but jq is absent from PATH; got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

echo "== C6-AC-2: config absent + jq absent -> detect.sh still reports REVIEW_BACKEND=codex (no over-trigger, regression pin) =="
rm -f "$BACKEND5_TARGET/.claude/autoflow.local.json"
run_detect_no_jq "$BACKEND5_TARGET" "$REPO_ROOT"
if [ "$(get_kv "$DETECT_OUT" REVIEW_BACKEND)" = "codex" ]; then
  pass "C6-AC-2: config absent + jq absent -> detect.sh still reports REVIEW_BACKEND=codex"
else
  failc "C6-AC-2" "expected REVIEW_BACKEND=codex when the config is absent and jq is absent (no over-trigger); got REVIEW_BACKEND=$(get_kv "$DETECT_OUT" REVIEW_BACKEND) exit=$DETECT_CODE"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
