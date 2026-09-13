#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: setup/thin-root-layer/ docs/thin-root-layer.md setup/manifest.json .claude-plugin/marketplace.json docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md docs/adr/README.md docs/tool-delivery-contract.md
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: thin-root-layer acceptance suite — Issue #791 [#785-S4b]
# =============================================================================
# RED->GREEN harness for the thin root layer: the always-on CLAUDE.md @import
# shim, the .claude/workflows residence + skill-substitutability AC, the
# CLAUDE_CODE_* env contract, and the committed settings pin. Plain POSIX sh +
# jq/grep/awk/diff/git only (DCR-5, matches tests/plugin/verify-package.sh
# harness form) — no bats, no new runtime dependency.
#
# Acceptance criteria (.autoflow/issue-791-verification-design.md §1):
#   AC1a/AC1b  shim artifact content + marker-fence non-vacuity keystone
#   AC2a/AC2b  workflow-residence resolution (SKILL-SUBSTITUTION=REJECTED) +
#              manifest naming both workflow source files
#   AC3a/AC3b  CLAUDE_CODE_* env contract enumeration + census-subset keystone
#   AC4a/AC4b  settings-pin artifact + marketplace no-skew + README-fence parity
#   AC5a       verify-package.sh is present (the whole-suite re-run is
#              retired -- plugin-package.yml:93 runs it)
#   AC5c       AC6d non-vacuity guard: static exactness + synthetic-pin arm
#   AC4c       (issue #245) the two provisions that enumerate the committed
#              settings pin -- R1 (docs/tool-delivery-contract.md) and
#              ADR-0015 D1 -- and the ADR registry row that describes the
#              amendment state the same fact
#
# Issue #963 additions (.autoflow/issue-963-verification-design.md §1
# AC1/AC4): a new "AC1 M-leg / AC4 dual-hash" block (read-only, no
# gen-manifest-hashes.sh run) asserts BOTH the manifest copy row and the
# json-merge row pin the current settings-pin.json sha256 (closes FINDING-B:
# AC2e in verify-install-into-target.sh only staleness-guards the copy row).
# Issue #95 inversion: the #963 positive assertion that the pin ships
# env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1" is inverted -- the Agent
# Teams channel is retired (ADR-0017 / ADR-0021), so AC4a now asserts the pin
# carries NO env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS key at all.
#
# Issue #245: the repo-level enabledPlugins declaration is the project-scope
# installation-record generator, so the pin stops carrying it. In this suite:
#   - AC4a's positive `enabledPlugins["autoflow@autoflow"] == true` assertion
#     is DELETED rather than inverted. The negative is held tree-wide by
#     verify-package.sh's AC6d scan once that scan's pin-path exclusion is
#     removed, and a second arm asserting the same property here would be the
#     duplicate the admission rule exists to prevent.
#   - the AC4a keystone loses its subject (the composed <plugin>@<marketplace>
#     token was a pin key) and is RE-ANCHORED on the pin's marketplace name
#     against marketplace.json's declared .name. The composed assertion is
#     deliberately not re-created anywhere; its plugin-name half is
#     verify-package.sh's AC6e.
#   - AC5c(b)-ii INVERTS with the exclusion it guards: the sanctioned
#     exclusion pathspec must now be ABSENT from verify-package.sh. The AC6d
#     loop guard AC5c(b)-i and the blanket-broadening token ban still stand
#     and still have work to do.
#
# NOTE (design §3 RED framing): AC1c (M), AC1d (E), AC2c-live (E) are NOT
# automated here — see .autoflow/issue-791-manual-scenarios.md. AC2c-static
# and AC5b are NOT in this suite's explicit scope per the RED dispatch (they
# are not in the enumerated A-typed AC list this suite implements).
#
# RED framing (verification design §3/§8-C1):
#   AC1a/AC1b/AC2a/AC2b/AC3a/AC3b/AC4a/AC4b/AC-Rg fail concretely today (no
#   setup/thin-root-layer/, no docs/thin-root-layer.md exist — Phase 3
#   verified). AC5a is a presence assertion and passes throughout. The design
#   §8-C1 driver it once carried — verify-package.sh's AC6d flipping green->RED
#   once GREEN commits the pin without the §3.5 edit — is now carried where that
#   AC lives, by verify-package.sh's own registered CI step (plugin-package.yml:93);
#   the whole-suite re-run here is retired (issue #103). AC5c(b) below keeps
#   this file's static
#   half of the same reconciliation.
#   AC5c(b)-ii (exact sanctioned exclusion token present) FAILs today (the
#   §3.5 edit has not landed); AC5c(a) (synthetic stray-pin arm) and AC5c(b)-i
#   (loop-not-removed) are regression guards that hold both before and after
#   GREEN.
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

SHIM="$REPO_ROOT/setup/thin-root-layer/claude-md-shim.md"
PIN="$REPO_ROOT/setup/thin-root-layer/settings-pin.json"
TRLD="$REPO_ROOT/docs/thin-root-layer.md"
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
PLUGIN_README="$REPO_ROOT/plugin/autoflow/README.md"
VERIFY_PACKAGE_SH="$REPO_ROOT/tests/plugin/verify-package.sh"
IMPORT_LINE='@./.claude/autoflow/METHODOLOGY.md'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

failc() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s -- %s\n' "$1" "$2"
}

skipc() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf 'SKIP: %s -- %s\n' "$1" "$2"
}

# ── AC1a: shim artifact exists, exactly one pinned import line ─────────────
echo "== AC1a: CLAUDE.md @import shim artifact =="
if [ -f "$SHIM" ]; then
  pass "AC1a: setup/thin-root-layer/claude-md-shim.md exists"
  IMPORT_COUNT=$(grep -cF "$IMPORT_LINE" "$SHIM" 2>/dev/null || echo 0)
  if [ "$IMPORT_COUNT" -eq 1 ]; then
    pass "AC1a: exactly one pinned import line '$IMPORT_LINE'"
  else
    failc "AC1a" "import line count=$IMPORT_COUNT (expected 1) for literal '$IMPORT_LINE'"
  fi
else
  failc "AC1a" "shim artifact missing at $SHIM (find setup/thin-root-layer -type f = no match, pre-GREEN)"
fi

# ── AC1b: marker fence + import-line-inside-markers keystone ───────────────
echo "== AC1b: AUTOFLOW-IMPORT marker fence (non-vacuity: import line INSIDE markers) =="
if [ -f "$SHIM" ]; then
  BEGIN_LINE=$(grep -n 'AUTOFLOW-IMPORT:BEGIN' "$SHIM" | head -1 | cut -d: -f1)
  END_LINE=$(grep -n 'AUTOFLOW-IMPORT:END' "$SHIM" | head -1 | cut -d: -f1)
  if [ -n "$BEGIN_LINE" ] && [ -n "$END_LINE" ] && [ "$BEGIN_LINE" -lt "$END_LINE" ]; then
    pass "AC1b: BEGIN/END markers present and BEGIN precedes END"
    BETWEEN=$(awk -v b="$BEGIN_LINE" -v e="$END_LINE" 'NR>b && NR<e' "$SHIM")
    if [ -n "$BETWEEN" ] && printf '%s\n' "$BETWEEN" | grep -qF "$IMPORT_LINE"; then
      pass "AC1b keystone: the import line sits strictly BETWEEN the markers (non-empty range, contains import)"
    else
      failc "AC1b keystone" "import line not found strictly between BEGIN/END (range content: '$BETWEEN')"
    fi
  else
    failc "AC1b" "markers missing or BEGIN does not precede END (begin_line=$BEGIN_LINE end_line=$END_LINE)"
  fi
else
  failc "AC1b" "shim artifact missing at $SHIM"
fi

# ── AC2a: workflow-residence verdict + concrete-constraint keystone ────────
echo "== AC2a: workflow-residence decision (SKILL-SUBSTITUTION verdict) =="
if [ -f "$TRLD" ]; then
  pass "AC2a: docs/thin-root-layer.md exists"
  if grep -qF 'SKILL-SUBSTITUTION = REJECTED' "$TRLD" && grep -qF 'WORKFLOW = REQUIRED' "$TRLD"; then
    pass "AC2a: verdict token 'SKILL-SUBSTITUTION = REJECTED' / 'WORKFLOW = REQUIRED' present"
  else
    failc "AC2a" "grep-checkable verdict token missing in $TRLD"
  fi
  if grep -qiE 'out-of-context|caller.?s[^.]{0,15}context|no (plugin )?workflow(s)?[ -]?(component )?slot' "$TRLD"; then
    pass "AC2a keystone: decision names a concrete deciding constraint (context-isolation / no-workflow-slot), not a bare 'we considered it'"
  else
    failc "AC2a keystone" "no concrete deciding-constraint phrase found (out-of-context isolation / no plugin workflows slot)"
  fi
else
  failc "AC2a" "docs/thin-root-layer.md missing at $TRLD"
fi

# ── AC2b: manifest names both workflow basenames; source files exist ───────
echo "== AC2b: workflow residence manifest =="
if [ -f "$TRLD" ]; then
  if grep -qF 'architect-deliberation.js' "$TRLD" && grep -qF 'verify-cause-branch.js' "$TRLD"; then
    pass "AC2b: manifest names both architect-deliberation.js and verify-cause-branch.js"
  else
    failc "AC2b" "manifest table does not name both workflow basenames in $TRLD"
  fi
else
  failc "AC2b" "docs/thin-root-layer.md missing at $TRLD"
fi
if [ -f "$REPO_ROOT/.claude/workflows/architect-deliberation.js" ] && [ -f "$REPO_ROOT/.claude/workflows/verify-cause-branch.js" ]; then
  pass "AC2b: both source workflow scripts exist at .claude/workflows/"
else
  failc "AC2b" "one or both source workflow scripts missing under .claude/workflows/"
fi

# ── AC3a: CLAUDE_CODE_* env enumeration + census-subset keystone ───────────
echo "== AC3a: CLAUDE_CODE_* env contract enumeration =="
if [ -f "$TRLD" ]; then
  MISSING_VARS=""
  for v in CLAUDE_CODE_DISABLE_WORKFLOWS CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT; do
    grep -qF "$v" "$TRLD" || MISSING_VARS="$MISSING_VARS $v"
  done
  if [ -z "$MISSING_VARS" ]; then
    pass "AC3a: env table lists CLAUDE_CODE_DISABLE_WORKFLOWS, CLAUDE_PROJECT_DIR, CLAUDE_PLUGIN_ROOT"
  else
    failc "AC3a" "env table missing:$MISSING_VARS"
  fi

  # census keystone: census (scoped to the pinned thin-root boundary) ⊆ enumerated set.
  # Boundary = .claude/workflows/, .claude/hooks/, setup/thin-root-layer/, docs/thin-root-layer.md
  # (excludes plugin/** and services/ — #790-owned, its own census).
  CENSUS=$(grep -rhoE 'CLAUDE_(CODE_)?[A-Z_]+' \
    "$REPO_ROOT/.claude/workflows" "$REPO_ROOT/.claude/hooks" \
    "$REPO_ROOT/setup/thin-root-layer" "$TRLD" 2>/dev/null | sort -u)
  UNCOVERED=""
  for v in $CENSUS; do
    grep -qF "$v" "$TRLD" || UNCOVERED="$UNCOVERED $v"
  done
  if [ -z "$UNCOVERED" ]; then
    pass "AC3a keystone: thin-root-boundary census ⊆ enumerated set in docs/thin-root-layer.md (census: $(printf '%s' "$CENSUS" | tr '\n' ' '))"
  else
    failc "AC3a keystone" "census var(s) not enumerated in $TRLD:$UNCOVERED"
  fi
else
  failc "AC3a" "docs/thin-root-layer.md missing at $TRLD"
fi

# ── AC3b: load-bearing MUST-not-be-1 clause + loader-provisioned labels ────
echo "== AC3b: load-bearing env constraints =="
if [ -f "$TRLD" ]; then
  if grep 'DISABLE_WORKFLOWS' "$TRLD" | grep -qiE 'MUST (remain unset|not be)|must not be .?1.?|must remain unset'; then
    pass "AC3b: MUST-not-be-1 clause present on the CLAUDE_CODE_DISABLE_WORKFLOWS row"
  else
    failc "AC3b" "no MUST-not-be-1 clause found for CLAUDE_CODE_DISABLE_WORKFLOWS"
  fi
  if grep 'CLAUDE_PROJECT_DIR' "$TRLD" | grep -qiE 'harness|loader' \
     && grep 'CLAUDE_PLUGIN_ROOT' "$TRLD" | grep -qiE 'harness|loader'; then
    pass "AC3b: CLAUDE_PROJECT_DIR / CLAUDE_PLUGIN_ROOT labeled loader/harness-provisioned (not host-required)"
  else
    failc "AC3b" "CLAUDE_PROJECT_DIR / CLAUDE_PLUGIN_ROOT not both labeled loader/harness-provisioned"
  fi
else
  failc "AC3b" "docs/thin-root-layer.md missing at $TRLD"
fi

# ── AC4a: settings-pin artifact + no-skew cross-check ──────────────────────
echo "== AC4a: settings-pin.json artifact =="
if [ -f "$PIN" ] && jq -e . "$PIN" >/dev/null 2>&1; then
  pass "AC4a: setup/thin-root-layer/settings-pin.json exists and is valid JSON"
  EKM=$(jq -r '.extraKnownMarketplaces["autoflow"] // empty' "$PIN")
  # The pin always asserts at least the marketplace entry. This is not an
  # incidental presence check: D1's json-merge leg is the fixed-point test
  # `(.[0] * .[1]) == .[0]`, whose discriminating power is exactly the number
  # of keys the pin asserts -- at zero keys it passes against any settings file
  # whatsoever. The target-side half of the same floor is
  # verify-install-into-target.sh AC3-245 (b).
  if [ -n "$EKM" ] && [ "$EKM" != "null" ]; then
    pass "AC4a: extraKnownMarketplaces.autoflow present (the pin is never empty -- D1's json-merge leg keeps a subject to discriminate)"
  else
    failc "AC4a" "extraKnownMarketplaces.autoflow missing -- an empty pin makes D1's json-merge leg pass against any settings file whatsoever"
  fi
  if [ -f "$MARKETPLACE" ] && jq -e . "$MARKETPLACE" >/dev/null 2>&1; then
    MP_NAME=$(jq -r '.name // empty' "$MARKETPLACE")
    PIN_MP_KEY=$(jq -r '.extraKnownMarketplaces | keys[0] // empty' "$PIN")
    if [ -n "$PIN_MP_KEY" ] && [ "$PIN_MP_KEY" = "$MP_NAME" ]; then
      pass "AC4a keystone (re-anchored, issue #245): the pin's marketplace name '$PIN_MP_KEY' matches marketplace.json's declared .name (no skew)"
    else
      failc "AC4a keystone" "the pin's marketplace name '$PIN_MP_KEY' != marketplace.json .name '$MP_NAME' -- the two-file no-skew fact lost the witness the retired composed <plugin>@<marketplace> token used to carry"
    fi
  else
    failc "AC4a keystone" "marketplace.json missing/invalid at $MARKETPLACE — cannot cross-check"
  fi
  if jq -e '(.env // {}) | has("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS") | not' "$PIN" >/dev/null 2>&1; then
    pass "AC4a (issue #95): settings-pin.json carries no env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS key (Agent Teams channel retired)"
  else
    failc "AC4a (issue #95)" "env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS still present in $PIN -- the retired Agent Teams pin must not be shipped"
  fi
else
  failc "AC4a" "settings-pin.json missing or invalid JSON at $PIN"
fi

# ── AC1 M-leg / AC4 dual-hash (issue #963, DCR-1/FINDING-B): manifest
# hash conformance, side-effect-free read-only form. Recompute the pin's
# sha256 ONCE and assert BOTH the manifest "copy" row (dest
# .claude/autoflow/settings-pin.json) AND the "json-merge" row (dest
# .claude/settings.json) equal it -- the copy row is already guarded by
# verify-install-into-target.sh AC2e (kind=="copy" only); the json-merge row
# is NOT (AC2e iterates kind=="copy" only), so this closes that gap. Never
# runs setup/gen-manifest-hashes.sh (it overwrites setup/manifest.json
# unconditionally) -- pure JSON/hash read, no working-tree mutation.
echo "== AC1 M-leg / AC4 dual-hash (issue #963): manifest copy+json-merge rows both pin the current settings-pin.json sha256 =="
MANIFEST_JSON="$REPO_ROOT/setup/manifest.json"
if [ -f "$PIN" ] && [ -f "$MANIFEST_JSON" ]; then
  if command -v shasum >/dev/null 2>&1; then
    PIN_SHA=$(shasum -a 256 "$PIN" | awk '{print $1}')
  else
    PIN_SHA=$(sha256sum "$PIN" | awk '{print $1}')
  fi
  COPY_SHA=$(jq -r '[.artifacts[] | select(.kind == "copy" and .dest == ".claude/autoflow/settings-pin.json")][0].sha256 // empty' "$MANIFEST_JSON")
  MERGE_SHA=$(jq -r '[.artifacts[] | select(.kind == "json-merge" and .dest == ".claude/settings.json")][0].sha256 // empty' "$MANIFEST_JSON")
  if [ -n "$PIN_SHA" ] && [ "$COPY_SHA" = "$PIN_SHA" ]; then
    pass "AC1 M-leg: manifest copy row (dest .claude/autoflow/settings-pin.json) sha256 == current shasum -a 256 of settings-pin.json"
  else
    failc "AC1 M-leg" "manifest copy row sha256 ('$COPY_SHA') != current settings-pin.json sha256 ('$PIN_SHA')"
  fi
  if [ -n "$PIN_SHA" ] && [ "$MERGE_SHA" = "$PIN_SHA" ]; then
    pass "AC4 dual-hash: manifest json-merge row (dest .claude/settings.json) sha256 == current shasum -a 256 of settings-pin.json"
  else
    failc "AC4 dual-hash" "manifest json-merge row sha256 ('$MERGE_SHA') != current settings-pin.json sha256 ('$PIN_SHA') -- AC2e's copy-only staleness guard misses this row (FINDING-B)"
  fi
else
  failc "AC1 M-leg / AC4 dual-hash" "settings-pin.json ($PIN) or manifest.json ($MANIFEST_JSON) missing"
fi

# ── AC4b: jq-canonical equality with the README reference fence ───────────
echo "== AC4b: settings-pin.json <-> README fence (jq-canonical equality) =="
if [ -f "$PIN" ] && [ -f "$PLUGIN_README" ]; then
  README_SNIPPET=$(awk '/```json/{flag=1; next} /```/{if(flag){flag=0}} flag' "$PLUGIN_README")
  if [ -n "$README_SNIPPET" ]; then
    A=$(jq -S . "$PIN" 2>/dev/null)
    B=$(printf '%s' "$README_SNIPPET" | jq -S . 2>/dev/null)
    if [ -n "$A" ] && [ -n "$B" ] && [ "$A" = "$B" ]; then
      pass "AC4b: settings-pin.json is jq-canonically equal to the plugin/autoflow/README.md fence (semantic, not byte)"
    else
      failc "AC4b" "settings-pin.json is NOT jq-canonically equal to the README fence"
    fi
  else
    failc "AC4b" "no fenced \`\`\`json block found/parsed in $PLUGIN_README"
  fi
else
  failc "AC4b" "settings-pin.json ($PIN) or README.md ($PLUGIN_README) missing"
fi

# ── AC4c (issue #245): the pin provisions and the ADR registry row ──────
# Verification design row :28, subject as amended by the round-2 delta. Both
# clauses are two-or-more-files-state-the-same-fact checks over the provisions
# that define this suite's subject.
ADR_0015="$REPO_ROOT/docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
ADR_REGISTRY="$REPO_ROOT/docs/adr/README.md"
TOOL_CONTRACT="$REPO_ROOT/docs/tool-delivery-contract.md"

# (i) Neither provision enumerates enabledPlugins as a key OF THE COMMITTED
# SETTINGS PIN. The subject is the parenthetical attached to that phrase, not
# any mention of the key elsewhere in the document: the superseding note that
# records WHY the key is gone is expected to name it.
echo "== AC4c (i) (#245): R1 / ADR-0015 D1 no longer enumerate enabledPlugins as a settings-pin key =="
for _prov in "R1:$TOOL_CONTRACT" "ADR-0015 D1:$ADR_0015"; do
  _prov_label=${_prov%%:*}
  _prov_file=${_prov#*:}
  if [ -f "$_prov_file" ]; then
    _prov_flat=$(tr '\n' ' ' < "$_prov_file" | sed 's/  */ /g')
    if ! printf '%s\n' "$_prov_flat" | grep -qF 'settings pin'; then
      failc "AC4c (i)" "$_prov_label no longer names the committed settings pin at all -- the provision has no statement left to check (non-vacuity)"
    else
      _prov_parens=$(printf '%s\n' "$_prov_flat" | grep -o 'settings pin[^(]\{0,40\}([^)]*)')
      if printf '%s\n' "$_prov_parens" | grep -qF 'enabledPlugins'; then
        failc "AC4c (i)" "$_prov_label still enumerates enabledPlugins as a key of the committed settings pin -- decision text the tree contradicts, and a member of this cycle's composition-oracle S set"
      else
        pass "AC4c (i): $_prov_label names the committed settings pin and does not enumerate enabledPlugins among its keys"
      fi
    fi
  else
    failc "AC4c (i)" "$_prov_label document missing at $_prov_file"
  fi
done

# (ii) ADR-0015's own Status record and the registry row that describes it
# state the same fact. The registry's Status cells are cumulative and
# semicolon-joined, so recording one amendment rewrites the cell in full: a
# cell that names ours while dropping an earlier one is not an untouched
# pre-existing gap, it is a history published in a format that reads as
# complete.
echo "== AC4c (ii) (#245): ADR-0015 Status amendments <-> the ADR registry row =="
if [ -f "$ADR_0015" ] && [ -f "$ADR_REGISTRY" ]; then
  ADR_STATUS=$(awk '/^## Status/{f=1;next} /^## /{if(f)exit} f' "$ADR_0015")
  ADR_AMENDMENTS=$(printf '%s\n' "$ADR_STATUS" | grep -oE 'Munsik-Park/autoflow#[0-9]+' \
                   | grep -oE '#[0-9]+' | sort -u)
  REGISTRY_ROW=$(grep -F '(0015-autoflow-distribution-plugin-plus-thin-root-layer.md)' "$ADR_REGISTRY" | head -1)
  REGISTRY_STATUS=$(printf '%s\n' "$REGISTRY_ROW" | awk -F'|' '{print $3}')
  if [ -z "$ADR_AMENDMENTS" ]; then
    failc "AC4c (ii)" "ADR-0015's Status section records no amendment issue (no 'Munsik-Park/autoflow#N' reference) -- the pair has no fact to agree on (non-vacuity)"
  elif [ -z "$REGISTRY_STATUS" ]; then
    failc "AC4c (ii)" "no ADR-0015 row found in $ADR_REGISTRY -- the registry does not describe the ADR this change amends"
  else
    ADR_MISSING=""
    for _amend in $ADR_AMENDMENTS; do
      printf '%s\n' "$REGISTRY_STATUS" | grep -qF "$_amend" || ADR_MISSING="$ADR_MISSING $_amend"
    done
    if [ -z "$ADR_MISSING" ]; then
      pass "AC4c (ii): the registry's ADR-0015 Status cell names every amendment ADR-0015's own Status records ($(printf '%s' "$ADR_AMENDMENTS" | tr '\n' ' '))"
    else
      failc "AC4c (ii)" "the registry's ADR-0015 Status cell ('$(printf '%s' "$REGISTRY_STATUS" | sed 's/^ *//; s/ *$//')') omits amendment(s)$ADR_MISSING that ADR-0015's own Status records -- the ADR's status and its registry row do not state the same fact"
    fi
  fi
else
  failc "AC4c (ii)" "ADR-0015 ($ADR_0015) or the ADR registry ($ADR_REGISTRY) missing"
fi

# ── AC5a: verify-package.sh is present ─────────────────────────────────────
echo "== AC5a: verify-package.sh is present (#790 regression carrier) =="
# The whole-suite re-run is retired (issue #103 cycle 3): that suite carries its
# own registered `run:` step at plugin-package.yml:93, which is where the #790
# regression reds — under its own name, once rather than twice. The design §8-C1
# expectation this arm carried is a statement about verify-package.sh's OWN
# AC6d, and it is that suite's step that will red when the settings-pin lands
# without the §3.5 edit; AC5c(b) below keeps this file's static half of it.
if [ -f "$VERIFY_PACKAGE_SH" ]; then
  pass "AC5a: packaging acceptance suite is present at $VERIFY_PACKAGE_SH"
else
  failc "AC5a" "tests/plugin/verify-package.sh missing at $VERIFY_PACKAGE_SH"
fi

# ── AC5c(b): static exactness — AC6d loop retained + exclusion minimality ──
echo "== AC5c(b): AC6d static exactness (loop retained; exclusion is exactly the sanctioned path) =="
if [ -f "$VERIFY_PACKAGE_SH" ]; then
  if grep -qF "ls-files -- '*.json'" "$VERIFY_PACKAGE_SH" \
     && grep -qF 'jq -e '"'"'has("enabledPlugins")'"'"'' "$VERIFY_PACKAGE_SH" \
     && grep -qF 'failc "AC6d"' "$VERIFY_PACKAGE_SH"; then
    pass "AC5c(b)-i: the AC6d tree-wide enabledPlugins scan loop + its failc are still present (not removed)"
  else
    failc "AC5c(b)-i" "AC6d scan loop / jq has(enabledPlugins) test / failc \"AC6d\" no longer found in verify-package.sh"
  fi

  # INVERTED by issue #245: the exclusion's condition -- "this file is the
  # sanctioned pin" -- is falsified once the pin no longer carries
  # enabledPlugins, and the excluded path is exactly where a future editor
  # would put the key back. The meta-guard inverts with the device it guards.
  if grep -qF "':!setup/thin-root-layer/settings-pin.json'" "$VERIFY_PACKAGE_SH"; then
    failc "AC5c(b)-ii (issue #245)" "the pin-path exclusion ':!setup/thin-root-layer/settings-pin.json' is still applied by AC6d's scan -- the scan stays blind at precisely the path most likely to re-acquire enabledPlugins"
  else
    pass "AC5c(b)-ii (issue #245): AC6d's scan applies no pin-path exclusion, so it states the negative directly -- no committed JSON in this tree declares enabledPlugins"
  fi

  BLANKET_FOUND=0
  for token in "':!setup/*'" "':!setup/**'" "':!setup/thin-root-layer/*'" "':!setup/thin-root-layer/**'"; do
    if grep -qF "$token" "$VERIFY_PACKAGE_SH"; then
      BLANKET_FOUND=1
      failc "AC5c(b)-ii" "over-broad blanket exclusion token $token found in verify-package.sh"
    fi
  done
  if [ "$BLANKET_FOUND" -eq 0 ]; then
    pass "AC5c(b)-ii: no over-broad blanket exclusion token (':!setup/*' / ':!setup/**' / ':!setup/thin-root-layer/*') is present"
  fi
else
  failc "AC5c(b)" "tests/plugin/verify-package.sh missing at $VERIFY_PACKAGE_SH"
fi

# ── AC5c(a): synthetic-pin behavioral arm (reinforcing) ────────────────────
echo "== AC5c(a): synthetic stray-pin behavioral arm (guard still trips on a DIFFERENT tracked *.json) =="
if [ -f "$VERIFY_PACKAGE_SH" ]; then
  AC6D_LINE=$(grep -F "ls-files -- '*.json'" "$VERIFY_PACKAGE_SH" | head -1)
  if [ -n "$AC6D_LINE" ]; then
    # Extract the pathspec arguments between '*.json' and the trailing
    # '2>/dev/null)' so the synthetic run mirrors whatever exclusion(s) the
    # real script currently applies (none pre-GREEN; the sanctioned one post-GREEN).
    AC6D_ARGS=$(printf '%s\n' "$AC6D_LINE" | sed -E "s/.*ls-files -- '\*\.json'(.*)2>\/dev\/null.*/\1/")

    TMP_REPO=$(mktemp -d)
    git -C "$TMP_REPO" init -q
    mkdir -p "$TMP_REPO/other/nested"
    cat > "$TMP_REPO/other/nested/stray-pin.json" <<'EOF'
{"enabledPlugins": {"foo@bar": true}}
EOF
    git -C "$TMP_REPO" add -A >/dev/null 2>&1
    git -C "$TMP_REPO" -c user.email=test@example.com -c user.name=test commit -q -m init >/dev/null 2>&1

    DECOY_HITS=""
    eval "set -- $AC6D_ARGS"
    for jf in $(git -C "$TMP_REPO" ls-files -- '*.json' "$@" 2>/dev/null); do
      if jq -e 'has("enabledPlugins")' "$TMP_REPO/$jf" >/dev/null 2>&1; then
        DECOY_HITS="$DECOY_HITS $jf"
      fi
    done
    if [ -n "$DECOY_HITS" ]; then
      pass "AC5c(a): a synthetic stray pin at other/nested/stray-pin.json (a path DIFFERENT from the sanctioned one) is still detected by AC6d's current pathspec — the guard retains discrimination"
    else
      failc "AC5c(a)" "synthetic stray pin at other/nested/stray-pin.json was NOT detected -- AC6d's pathspec would over-broadly exclude it"
    fi
    rm -rf "$TMP_REPO"
  else
    failc "AC5c(a)" "could not locate the AC6d 'ls-files -- *.json' line in verify-package.sh to derive the synthetic-run pathspec"
  fi
else
  failc "AC5c(a)" "tests/plugin/verify-package.sh missing at $VERIFY_PACKAGE_SH"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
