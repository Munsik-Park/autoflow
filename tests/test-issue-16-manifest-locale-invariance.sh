#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: locale-invariant manifest generation — Issue #16
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-16-verification-design.md §1). New dedicated file — the
# feature design §7 devil's-advocate flag + verification design §0 R1
# reconciliation moved these arms out of tests/adr-0016-conformance-check.sh
# (concern mismatch: that file is scoped to ADR-0016 registration, not
# generator locale-invariance). AC4 separately re-runs the existing
# adr-0016-conformance-check.sh .source-keyed guards UNMODIFIED — it does not
# land in this file.
#
# Scope (verification design §1):
#   AC1 — generator is locale-pinned at the source (static grep for the
#         script-entry `export LC_ALL=C` form, Option B).
#   AC2 — committed manifest matches a fresh regen in an isolated temp copy
#         (Derived-artifacts freshness / C2 companion-regen coherence).
#   AC3 — byte-identical regen output across a C vs. differing-UTF-8 locale
#         pair, probed from the real .source set; SKIPs honestly if no
#         installed pair discriminates. This is the core RED/GREEN
#         discriminator for the locale defect itself (verification design
#         §1 AC3 RED/GREEN discrimination note, §3 item 6).
#   AC4 — existing order-insensitive guards remain green (regression
#         confirmation only, zero new code — re-runs
#         tests/adr-0016-conformance-check.sh as a subprocess and checks its
#         own PASS/FAIL summary; does not duplicate its assertions here).
#   AC5 — the manifest change is order-only: same .source/.sha256/.dest/.kind
#         set + same artifact count vs. a pre-fix baseline captured to the
#         gitignored scratch fixture .autoflow/issue-16-manifest-baseline.json
#         during this RED commit. Self-SKIPs when that fixture is absent
#         (cycle-scoped gate — verification design §1 AC5 "Resolved, round 2").
#
# RED expectation (this commit, no LC_ALL pin in setup/gen-manifest-hashes.sh
# yet): AC1 FAILs (grep target absent). AC3 FAILs when the runner's ambient
# locale differs from the discriminating UTF-8 partner picked by the probe
# (both regen runs then disagree with each other before the fix — actually:
# pre-fix the two explicit LC_ALL=C / LC_ALL=<utf8> runs already reorder
# differently regardless of the runner's own ambient locale, since neither
# run relies on inheritance yet — this is what makes AC3 the true RED/GREEN
# discriminator, see verification design §1 AC3 "RED/GREEN discrimination").
# AC2 may PASS or FAIL depending on the runner's own ambient locale (verif.
# design §3 item 6 — not a coverage gap, AC3 is the honest discriminator).
# AC4 stays green (zero new code, pre-existing arms are order-insensitive by
# construction). AC5 captures its baseline fixture during this RED run (first
# invocation) and then runs as a real gate; a later standing re-run without
# the fixture self-SKIPs.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GEN_MANIFEST_SH="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"
BASELINE_FIXTURE="$PROJECT_ROOT/.autoflow/issue-16-manifest-baseline.json"
ADR_0016_TEST="$PROJECT_ROOT/tests/adr-0016-conformance-check.sh"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-953-cycle-digest.sh /
# tests/test-issue-800-doc-assertions.sh)
# ---------------------------------------------------------------------------

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

skip_test() {
  local desc="$1"
  TESTS=$((TESTS + 1))
  PASS=$((PASS + 1))
  echo "  SKIP: $desc"
}

# ---------------------------------------------------------------------------
# AC1 — generator is locale-pinned at the source (static, Option B form)
# ---------------------------------------------------------------------------

echo "=== AC1 (RED discriminator) — generator pins LC_ALL=C at script entry ==="

assert_true "AC1-a: setup/gen-manifest-hashes.sh contains a script-entry 'export LC_ALL=C' pin" \
  "grep -nE '^[[:space:]]*export[[:space:]]+LC_ALL=C\b' '$GEN_MANIFEST_SH' >/dev/null 2>&1"

# ---------------------------------------------------------------------------
# AC2 — committed manifest matches a fresh regen (isolated temp copy;
# test-953 AC6 tree-copy idiom, keeps the working tree clean).
# ---------------------------------------------------------------------------

echo ""
echo "=== AC2 — committed setup/manifest.json matches a fresh regen (isolated temp copy) ==="

AC2_TMP="$(mktemp -d)"
(cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$AC2_TMP" && tar -xf -) 2>/dev/null
( cd "$AC2_TMP" && bash setup/gen-manifest-hashes.sh >/tmp/ac2-gen-out-$$.log 2>&1 )
AC2_GEN_EXIT=$?

assert_true "AC2-gen-exit0: the generator exits 0 in the isolated temp copy" \
  "[ '$AC2_GEN_EXIT' -eq 0 ]"
assert_true "AC2-byte-identical: the regenerated setup/manifest.json is byte-identical to the committed one" \
  "cmp -s '$AC2_TMP/setup/manifest.json' '$MANIFEST_JSON'"

rm -rf "$AC2_TMP" "/tmp/ac2-gen-out-$$.log" 2>/dev/null

# ---------------------------------------------------------------------------
# AC3 — byte-identical regen output across a C vs. differing-UTF-8 locale
# pair, probed from the REAL .source closure set (not a synthetic sample).
# Probe-then-SKIP: honest SKIP if no installed pair reorders the real set.
# ---------------------------------------------------------------------------

echo ""
echo "=== AC3 (core RED/GREEN discriminator) — byte-identical regen across differing locales ==="

AC3_UTF8_CANDIDATE=""
AC3_LOCALE_LIST="$(locale -a 2>/dev/null)"
for cand in ko_KR.UTF-8 en_US.UTF-8 C.UTF-8; do
  if printf '%s\n' "$AC3_LOCALE_LIST" | grep -qiF "$cand"; then
    src_c="$(jq -r '.artifacts[].source' "$MANIFEST_JSON" 2>/dev/null | LC_ALL=C sort)"
    src_utf="$(jq -r '.artifacts[].source' "$MANIFEST_JSON" 2>/dev/null | LC_ALL="$cand" sort 2>/dev/null)"
    if [ -n "$src_c" ] && [ "$src_c" != "$src_utf" ]; then
      AC3_UTF8_CANDIDATE="$cand"
      break
    fi
  fi
done

if [ -z "$AC3_UTF8_CANDIDATE" ]; then
  skip_test "AC3: no installed locale pair (C + candidate UTF-8) discriminates the real .source set — cannot test on this runner"
else
  echo "  (probe) discriminating pair: C vs $AC3_UTF8_CANDIDATE"

  AC3_TMP_C="$(mktemp -d)"
  AC3_TMP_UTF="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$AC3_TMP_C" && tar -xf -) 2>/dev/null
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$AC3_TMP_UTF" && tar -xf -) 2>/dev/null

  ( cd "$AC3_TMP_C" && LC_ALL=C bash setup/gen-manifest-hashes.sh >/tmp/ac3-c-out-$$.log 2>&1 )
  AC3_C_EXIT=$?
  ( cd "$AC3_TMP_UTF" && LC_ALL="$AC3_UTF8_CANDIDATE" bash setup/gen-manifest-hashes.sh >/tmp/ac3-utf-out-$$.log 2>&1 )
  AC3_UTF_EXIT=$?

  assert_true "AC3-gen-exit0-c: the generator exits 0 under LC_ALL=C" \
    "[ '$AC3_C_EXIT' -eq 0 ]"
  assert_true "AC3-gen-exit0-utf: the generator exits 0 under LC_ALL=$AC3_UTF8_CANDIDATE" \
    "[ '$AC3_UTF_EXIT' -eq 0 ]"
  assert_true "AC3-byte-identical-cross-locale: regenerating under LC_ALL=C and LC_ALL=$AC3_UTF8_CANDIDATE produces byte-identical setup/manifest.json (pre-fix: FAILs — the two runs inherit their differing ambient LC_ALL and reorder; post-fix: the in-script export LC_ALL=C overrides both)" \
    "cmp -s '$AC3_TMP_C/setup/manifest.json' '$AC3_TMP_UTF/setup/manifest.json'"

  rm -rf "$AC3_TMP_C" "$AC3_TMP_UTF" "/tmp/ac3-c-out-$$.log" "/tmp/ac3-utf-out-$$.log" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# AC4 — existing order-insensitive guards remain green (regression
# confirmation only; re-runs the standing adr-0016 suite unmodified as a
# subprocess and checks ITS OWN summary, per feature design §7 / verif.
# design §1 AC4 — this file adds no new .source-keyed assertions).
# ---------------------------------------------------------------------------

echo ""
echo "=== AC4 (regression confirmation, zero new code) — existing order-insensitive guards stay green ==="

if [ -x "$ADR_0016_TEST" ] || [ -f "$ADR_0016_TEST" ]; then
  AC4_OUT="$(bash "$ADR_0016_TEST" 2>&1)"
  AC4_EXIT=$?
  echo "$AC4_OUT" | tail -3 | sed 's/^/  [adr-0016] /'
  assert_true "AC4-adr0016-suite-exit0: tests/adr-0016-conformance-check.sh (AC-R3 sha256/count guards, order-insensitive by construction) exits 0 unmodified" \
    "[ '$AC4_EXIT' -eq 0 ]"
else
  assert_true "AC4-adr0016-suite-exists: tests/adr-0016-conformance-check.sh exists" "false"
fi

# ---------------------------------------------------------------------------
# AC5 — the manifest change is order-only (same .source/.sha256/.dest/.kind
# set + count vs. a pre-fix baseline). Self-SKIPs when the RED-captured
# gitignored baseline fixture is absent (cycle-scoped gate — verification
# design §1 AC5 "Resolved, round 2").
# ---------------------------------------------------------------------------

echo ""
echo "=== AC5 — manifest change is order-only (set/hash/dest/kind + count equality vs. pre-fix baseline) ==="

if [ ! -f "$BASELINE_FIXTURE" ]; then
  mkdir -p "$PROJECT_ROOT/.autoflow"
  cp "$MANIFEST_JSON" "$BASELINE_FIXTURE"
  echo "  (fixture) captured pre-fix baseline: $BASELINE_FIXTURE"
fi

if [ -f "$BASELINE_FIXTURE" ]; then
  assert_true "AC5-set-hash-equality: sorted (source, sha256, dest, kind) tuples of the committed manifest equal the pre-fix baseline's" \
    "diff <(jq -r '.artifacts[] | \"\(.source)\t\(.sha256)\t\(.dest)\t\(.kind)\"' '$MANIFEST_JSON' | sort) \
          <(jq -r '.artifacts[] | \"\(.source)\t\(.sha256)\t\(.dest)\t\(.kind)\"' '$BASELINE_FIXTURE' | sort) >/dev/null 2>&1"
  assert_true "AC5-count-equality: artifact count is unchanged vs. the pre-fix baseline" \
    "[ \"\$(jq '.artifacts | length' '$MANIFEST_JSON')\" = \"\$(jq '.artifacts | length' '$BASELINE_FIXTURE')\" ]"
else
  skip_test "AC5: pre-fix baseline fixture absent (cycle-scoped gate — not re-derivable without the pre-fix tree)"
  skip_test "AC5: pre-fix baseline fixture absent (cycle-scoped gate — not re-derivable without the pre-fix tree)"
fi

# ---------------------------------------------------------------------------
# Cleanup — restore any regenerated manifest and leave the tree clean.
# AC2/AC3 only ever regenerate inside mktemp copies (already rm -rf'd above);
# this is a defensive restore in case any step above touched the tracked
# setup/manifest.json in the real working tree.
# ---------------------------------------------------------------------------

( cd "$PROJECT_ROOT" && git checkout -- setup/manifest.json 2>/dev/null )

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[ "$FAIL" -eq 0 ]
