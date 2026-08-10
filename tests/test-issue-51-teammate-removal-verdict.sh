#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #51 — teammate-removal feasibility verdict (ADR-0017)
# (cycle-scoped suite, frozen filename — ledger E5)
# =============================================================================
# Verification design: .autoflow/issue-51-verification-design.md (round-10
# ACCEPT, §8d). AC -> lane -> method table: §1. Ratified registry entry set
# (12 entries, promoted to tests/fixtures/doc-invariants.json at GREEN, in
# the SAME commit that creates the headings they anchor — §4 ordering
# constraint): §5.0. Ratified 17-heading skeleton: §5.1. RED expectation: §6.
#
# Deliverable class: this cycle ships a DECISION DOCUMENT
# (docs/adr/0017-teammate-removal-feasibility.md), not runtime code. AC1-AC7,
# AC10, AC12, AC14-AC16 are TEMPORARY discriminators here: once GREEN creates
# the ADR and promotes the matching content to the twelve permanent registry
# entries (origin_issue: 51), the duplicated content-presence checks in this
# file become redundant with the registry runner and are expected to be
# deleted in a later cleanup pass (the #43 precedent -
# tests/test-issue-43-report-channel-contract.sh's header). What remains
# PERMANENTLY in this file (content the registry structurally cannot hold —
# docs/doc-invariant-registry.md rejects any diff/count/delta-shaped
# predicate, and workflow-file / manifest-file assertions are outside the
# registry's ADR/README scope):
#
#   AC1(d)   — base-relative Status-value fence (lane A-delta, branch-scoped)
#   AC6(b)/(c) — migration-slice DELTA + byte-invariance fence (lane A-delta)
#   AC8/O1   — manifest composition oracle (real setup/gen-manifest-hashes.sh)
#   AC9/O2   — registry composition oracle (real tests/run-doc-invariants.sh)
#   AC12     — CI wiring (run: step + paths: entries + ordering arm)
#   R51-COUNT / meta guard — origin_issue==51 registry entry count (12) and
#              literal-contiguity/direction-of-predicate meta check
#
# Lane A-delta members are enforced only on this cycle's own dev branch
# (dev/*-issue-51 / dev/*-issue-51-*); off that branch they print
# DEFERRED-OBSERVABLE and assert nothing (verification design §0, adopted
# verbatim in shape from ea68a4c / tests/test-issue-7-oracle-hardening.sh).
# On-branch with an unresolvable base ref -> FAIL loud, never a silent SKIP
# (tests/lib/base-ref.sh contract).
#
# RED expectation (this commit — docs/adr/0017-*.md does not exist yet):
#   FAIL (discriminators): AC1(a)(b)(c)(d), AC2, AC3, AC4, AC5, AC7, AC10,
#     AC14, AC15, AC16, AC12 (no run: step / paths: entries yet), O1(b)
#     (no manifest row named for the ADR), O2(b) (origin_issue==51 count is
#     0, not 12).
#   PASS (guards, must stay green throughout): AC6(a) is a discriminator (no
#     ADR to carry the deferral statement) until GREEN; AC6(b)/(c) PASS from
#     the outset (the fence must never be tripped); O1(a) regen-clean, true
#     before and after; O2(a) exit 0 + 0 failed, true before and after.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/lib/base-ref.sh
. "$SCRIPT_DIR/lib/base-ref.sh"

ADR_REL="docs/adr/0017-teammate-removal-feasibility.md"
ADR="$PROJECT_ROOT/$ADR_REL"
TEMPLATE="$PROJECT_ROOT/docs/adr/0000-adr-template.md"
ADR_README="$PROJECT_ROOT/docs/adr/README.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
AGENT_TESTER="$PROJECT_ROOT/.claude/agents/autoflow-tester.md"
WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY="$SCRIPT_DIR/fixtures/doc-invariants.json"
RUNNER="$SCRIPT_DIR/run-doc-invariants.sh"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
GATE_HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
GATE_SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers
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

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

# extract_section mirrors tests/run-doc-invariants.sh's own extractor
# (durable heading anchor, level-aware close, optional section_end,
# bare-`---` thematic-break terminator when no section_end is given).
extract_section() {          # heading_text file [section_end]
  local heading="$1" file="$2" endpat="${3:-}"
  awk -v h="$heading" -v endpat="$endpat" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (endpat!="" && /^#{1,6} +/ && $0 ~ endpat)  { f=0; next }
      else if (/^#{1,6} +/ && level($0)<=L)          { f=0; next }
      else if (endpat=="" && /^---[ \t]*$/)          { f=0; next }
      else print
    }
  ' "$file" 2>/dev/null
}

# count_heading mirrors the runner's exact stripped-text equality anchor.
# Prints 0 (never empty) when the target file does not yet exist, so callers
# can compare it as an integer without a missing-file special case.
count_heading() {            # anchor file
  local anchor="$1" file="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return
  fi
  awk -v h="$anchor" '
    /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) c++
    }
    END { print c+0 }
  ' "$file" 2>/dev/null
}

body_has() {                 # body literal match
  local body="$1" literal="$2" match="${3:-fixed}"
  if [ "$match" = "regex" ]; then
    grep -qE -- "$literal" <<<"$body"
  else
    grep -qF -- "$literal" <<<"$body"
  fi
}

# Branch-scope test for lane A-delta members (adopted verbatim in shape from
# ea68a4c / tests/test-issue-7-oracle-hardening.sh AC-7-7b).
on_issue_51_branch() {
  local head_branch="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
  case "$head_branch" in
    dev/*-issue-51|dev/*-issue-51-*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "=== issue #51 — teammate-removal feasibility verdict (ADR-0017) ==="

# ---------------------------------------------------------------------------
# AC1 — ADR exists, carries the 7-heading skeleton subset, the verdict
# sentence, a conformant Status value, and (lane A-delta) the base-relative
# Status literal.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC1 — decision record skeleton, verdict, Status conformance ==="

for h in "Status" "Context" "Decision" "Alternatives Considered" "Consequences" \
         "Related Issues / PRs" "Notes"; do
  n="$(count_heading "$h" "$ADR")"
  assert_true "AC1(a): '## $h' heading occurs exactly once (currently $n)" "[ '$n' -eq 1 ]"
done

DECISION_BODY="$(extract_section "Decision" "$ADR")"
assert_true "AC1(b): the ratified verdict sentence appears in the ## Decision block" \
  "body_has \"\$DECISION_BODY\" 'Migration is possible, conditionally.'"

STATUS_BODY="$(extract_section "Status" "$ADR")"
STATUS_VALUE="$(printf '%s\n' "$STATUS_BODY" | grep -vE '^[[:space:]]*$' | head -1 | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
assert_true "AC1(c): the ## Status value is one of Proposed|Accepted|Deprecated|Superseded (currently '$STATUS_VALUE')" \
  "printf '%s' '$STATUS_VALUE' | grep -qE '^(Proposed|Accepted|Deprecated|Superseded)$'"

echo ""
echo "--- AC1(d) [lane A-delta, branch-scoped] base-relative Status literal ---"
if on_issue_51_branch; then
  BASE_REF="$(resolve_base_ref)"
  if [ -z "$BASE_REF" ]; then
    echo "  FAIL: AC1(d): resolve_base_ref could not resolve a comparison base on the issue-51 branch (fail-loud, not SKIP)"
    FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1))
  else
    if ! git -C "$PROJECT_ROOT" show "$BASE_REF:$ADR_REL" >/dev/null 2>&1; then
      # This PR ADDS the ADR — it must ship Proposed (AC13/M1 delegates the
      # Proposed -> Accepted transition to the owner; AutoFlow may not
      # pre-decide it).
      assert_true "AC1(d)-added: ADR is added by this PR and ships '## Status' = Proposed" \
        "printf '%s' '$STATUS_VALUE' | grep -qx 'Proposed'"
    else
      # ADR already existed at base — this PR's diff must not move the
      # Status value (owner-performed transitions outside this PR are not
      # this fence's concern; base-relative, not a live-file literal).
      BASE_STATUS_BODY="$(git -C "$PROJECT_ROOT" show "$BASE_REF:$ADR_REL" 2>/dev/null | extract_section "Status" /dev/stdin 2>/dev/null)"
      BASE_STATUS_VALUE="$(printf '%s\n' "$BASE_STATUS_BODY" | grep -vE '^[[:space:]]*$' | head -1 | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
      assert_true "AC1(d)-unchanged: this PR's diff does not change '## Status' (base='$BASE_STATUS_VALUE', head='$STATUS_VALUE')" \
        "[ '$BASE_STATUS_VALUE' = '$STATUS_VALUE' ]"
    fi
  fi
else
  note_deferred "AC1(d): lane A-delta member inert off the issue-51 dev branch."
fi

# ---------------------------------------------------------------------------
# AC2 — Q1-Q6 dedicated sub-sections, each answer carrying >=1 grounds anchor.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC2 — Q1-Q6 sub-sections, each grounded by >=1 anchor ==="

GROUNDS_RE='([A-Za-z0-9_./-]+\.(md|sh|js|json)(:[0-9]+)?|#[0-9]+|[0-9a-f]{7,40})'
for q in Q1 Q2 Q3 Q4 Q5 Q6; do
  n="$(count_heading "$q" "$ADR")"
  assert_true "AC2: '### $q' heading occurs exactly once (currently $n)" "[ '$n' -eq 1 ]"
  qbody="$(extract_section "$q" "$ADR")"
  assert_true "AC2: ### $q answer carries >=1 grounds anchor (path, path:line, #issue, or SHA)" \
    "body_has \"\$qbody\" '$GROUNDS_RE' regex"
done

# ---------------------------------------------------------------------------
# AC3 — the rejection of the archive-incidence corpus audit is on the record,
# with its three grounds, inside ## Alternatives Considered.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC3 — corpus-audit rejection recorded with its three grounds ==="

ALT_BODY="$(extract_section "Alternatives Considered" "$ADR")"
assert_true "AC3-ground1: rejection states the anchor predicate fires on every audited document (non-discriminating)" \
  "body_has \"\$ALT_BODY\" 'non-discriminat' regex"
assert_true "AC3-ground2: rejection states the corpus is one project under two renamed keys" \
  "body_has \"\$ALT_BODY\" 'one project under (two )?renamed keys|two renamed keys' regex"
assert_true "AC3-ground3: rejection states this repository contributes zero documents to the corpus" \
  "body_has \"\$ALT_BODY\" '(this repository|this repo).{0,30}(zero|0)( documents| contribut)' regex"

# ---------------------------------------------------------------------------
# AC4 — Q1's answer rests on the in-repo ARCHITECT > Output artifacts spec
# fact, stating that VERIFY step 4's iteration set is not a required element
# of any artifact.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC4 — Q1 grounded in docs/autoflow-guide.md ARCHITECT Output artifacts ==="

Q1_BODY="$(extract_section "Q1" "$ADR")"
assert_true "AC4-source: Q1 cites docs/autoflow-guide.md as its structural-fact source" \
  "body_has \"\$Q1_BODY\" 'docs/autoflow-guide\.md' regex"
assert_true "AC4-iteration-set: Q1 states step 4's iteration set is not a required element of any artifact" \
  "body_has \"\$Q1_BODY\" 'iteration set' fixed && body_has \"\$Q1_BODY\" 'not.{0,20}required element' regex"

# ---------------------------------------------------------------------------
# AC5 — ordered migration-conditions list, an ordering-constraint statement,
# the pilot as an outstanding precondition, and the pilot-can-reverse clause.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC5 — ordered migration conditions, ordering constraint, pilot, reversal ==="

assert_true "AC5-ordering-constraint: ## Decision states an ordering constraint" \
  "body_has \"\$DECISION_BODY\" 'ordering constraint' fixed"
assert_true "AC5-pilot-token: ## Decision names the pilot as an outstanding precondition" \
  "body_has \"\$DECISION_BODY\" 'pilot' fixed"
assert_true "AC5-reversal: ## Decision states the pilot can reverse the verdict" \
  "body_has \"\$DECISION_BODY\" 'reverse the verdict|can reverse' regex"
assert_true "AC5-condition-tokens: ## Decision enumerates conditions C1 through C7" \
  "body_has \"\$DECISION_BODY\" 'C1' fixed && body_has \"\$DECISION_BODY\" 'C7' fixed"
assert_true "AC5-ordering: the first condition token (C1) precedes the pilot condition token (C7) in ## Decision" \
  "awk '/C1/{if (!c1) c1=NR} /C7/{if (!c7) c7=NR} END{exit !(c1 && c7 && c1<c7)}' <<<\"\$DECISION_BODY\""

# ---------------------------------------------------------------------------
# AC6 — no contract/hook/agent-definition/workflow/governing-doc file is
# modified this cycle. (a) deferral statement (lane A, permanent).
# (b)/(c) lane A-delta, branch-scoped.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC6 — migration-slice files untouched this cycle ==="

FULL_ADR="$(cat "$ADR" 2>/dev/null)"
assert_true "AC6(a): the record states this cycle defers the migration-slice files (hook/contract/workflow untouched)" \
  "body_has \"\$FULL_ADR\" '(defer|not (this cycle|part of this cycle|modif)).{0,80}(hook|contract|workflow|agent-definition|governing)' regex"

echo ""
echo "--- AC6(b)/(c) [lane A-delta, branch-scoped] DELTA + byte-invariance fence ---"
FENCE_FILES=(
  ".claude/hooks/check-autoflow-gate.sh"
  "tests/fixtures/gate-schema.json"
  "CLAUDE.md"
  "docs/teammate-contracts.md"
  "docs/teammate-common-rules.md"
  "docs/autoflow-guide.md"
)
if on_issue_51_branch; then
  BASE_REF6="$(resolve_base_ref)"
  if [ -z "$BASE_REF6" ]; then
    echo "  FAIL: AC6(b)/(c): resolve_base_ref could not resolve a comparison base on the issue-51 branch (fail-loud, not SKIP)"
    FAIL=$((FAIL + 2)); TESTS=$((TESTS + 2))
  else
    CHANGED_51="$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF6"...HEAD 2>/dev/null)"
    DELTA_BAD=0
    for f in "${FENCE_FILES[@]}"; do
      if printf '%s\n' "$CHANGED_51" | grep -qxF "$f"; then
        DELTA_BAD=$((DELTA_BAD + 1))
        echo "  (info) AC6(b): diff touches fenced file '$f'"
      fi
    done
    if printf '%s\n' "$CHANGED_51" | grep -qE '^\.claude/agents/autoflow-.*\.md$'; then
      DELTA_BAD=$((DELTA_BAD + 1))
      echo "  (info) AC6(b): diff touches a fenced .claude/agents/autoflow-*.md file"
    fi
    if printf '%s\n' "$CHANGED_51" | grep -qE '^\.claude/workflows/.*\.js$'; then
      DELTA_BAD=$((DELTA_BAD + 1))
      echo "  (info) AC6(b): diff touches a fenced .claude/workflows/*.js file"
    fi
    assert_true "AC6(b): diff vs base contains none of the fenced migration-slice files" \
      "[ '$DELTA_BAD' -eq 0 ]"
    assert_true "AC6(c): the gate hook and gate-schema.json are byte-unchanged vs base" \
      "git -C '$PROJECT_ROOT' diff --quiet '$BASE_REF6' -- '$GATE_HOOK' '$GATE_SCHEMA'"
  fi
else
  note_deferred "AC6(b)/(c): lane A-delta members inert off the issue-51 dev branch."
fi

# ---------------------------------------------------------------------------
# AC7 — registration completeness: the ADR is registered in all three of
# docs/adr/README.md, docs/maintained-docs.md, docs/INDEX.md (filename only).
# ---------------------------------------------------------------------------
echo ""
echo "=== AC7 — registration completeness (3/3, filename-anchored) ==="

assert_true "AC7-readme: docs/adr/README.md > Current Drafts names 0017-teammate-removal-feasibility.md" \
  "grep -qF '0017-teammate-removal-feasibility.md' '$ADR_README'"
assert_true "AC7-maintained-docs: docs/maintained-docs.md > ADRs names 0017-teammate-removal-feasibility.md" \
  "grep -qF '0017-teammate-removal-feasibility.md' '$MAINTAINED_DOCS'"
assert_true "AC7-index: docs/INDEX.md > Quick Routing names 0017-teammate-removal-feasibility.md" \
  "grep -qF '0017-teammate-removal-feasibility.md' '$INDEX_MD'"

# ---------------------------------------------------------------------------
# AC8 / O1 — manifest composition oracle: the REAL setup/gen-manifest-hashes.sh
# driven against an isolated copy of the real tree at HEAD. No fixture
# manifest, no stubbed hasher.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC8 / O1 — manifest composition oracle (real producer) ==="

O1_TMP="$(mktemp -d)"
(cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$O1_TMP" && tar -xf -) 2>/dev/null
( cd "$O1_TMP" && bash setup/gen-manifest-hashes.sh >/dev/null 2>&1 )

assert_true "O1(a)-regen-clean: committed setup/manifest.json is byte-identical to a fresh regen" \
  "cmp -s '$O1_TMP/setup/manifest.json' '$MANIFEST'"

O1_ROW_COUNT="$(jq -r --arg src "$ADR_REL" '[.artifacts[] | select(.source == $src)] | length' "$O1_TMP/setup/manifest.json" 2>/dev/null)"
assert_true "O1(b)-named-source-row: regenerated manifest has exactly one artifact row for $ADR_REL (currently ${O1_ROW_COUNT:-0})" \
  "[ \"\${O1_ROW_COUNT:-0}\" -eq 1 ]"

if [ "${O1_ROW_COUNT:-0}" -eq 1 ]; then
  O1_ROW_SHA="$(jq -r --arg src "$ADR_REL" '.artifacts[] | select(.source == $src) | .sha256' "$O1_TMP/setup/manifest.json")"
  O1_FILE_SHA="$(shasum -a 256 "$O1_TMP/$ADR_REL" 2>/dev/null | awk '{print $1}')"
  assert_true "O1(c)-hash-coherence: the ADR's manifest row sha256 matches its on-disk hash" \
    "[ '$O1_ROW_SHA' = '$O1_FILE_SHA' ]"
fi

rm -rf "$O1_TMP"

# ---------------------------------------------------------------------------
# AC9 / O2 — doc-invariant registry composition oracle: the REAL
# tests/run-doc-invariants.sh, no registry argument, against the real
# registry and the real edited documents. No global total.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC9 / O2 — doc-invariant registry composition oracle (real producer) ==="

O2_OUT="$(bash "$RUNNER" 2>&1)"
O2_RC=$?
export O2_OUT

assert_true "O2(a)-exit0: the real registry runner exits 0" "[ '$O2_RC' -eq 0 ]"
assert_true "O2(a)-0failed: the real registry runner's Results line reports 0 failed" \
  "printf '%s' \"\$O2_OUT\" | grep -qE '^Results:.*, 0 failed$'"

O2_COUNT51="$(jq -r '[.invariants[] | select(.origin_issue==51)] | length' "$REGISTRY")"
assert_true "O2(b)-issue-scoped-count: origin_issue==51 registry entry count is exactly 12 (currently $O2_COUNT51)" \
  "[ '$O2_COUNT51' -eq 12 ]"

O2_SHAPE_BAD="$(jq -r '
  [.invariants[] | select(.origin_issue==51) |
    select(.scope != "permanent" or (.predicate != "present" and .predicate != "absent" and .predicate != "ordered"))] | length
' "$REGISTRY")"
assert_true "O2(d)-shape: every origin_issue==51 entry is scope:permanent with predicate in present|absent|ordered" \
  "[ '$O2_SHAPE_BAD' -eq 0 ]"

O2_NEWLINE_BAD="$(jq -r '
  [.invariants[] | select(.origin_issue==51) |
    ((.literal // "") + " " + (.before // "") + " " + (.after // ""))] |
  map(select(contains("\n"))) | length
' "$REGISTRY")"
assert_true "O2(d)-no-embedded-newline: no origin_issue:51 literal/before/after carries an embedded newline" \
  "[ '$O2_NEWLINE_BAD' = 0 ]"

O2_DIRECTION_BAD=0
while IFS=$'\t' read -r id file section predicate match literal after; do
  [ -n "$id" ] || continue
  srcfile="$PROJECT_ROOT/$file"
  if [ -n "$section" ]; then
    body="$(extract_section "$section" "$srcfile")"
  else
    body="$(cat "$srcfile" 2>/dev/null)"
  fi
  case "$predicate" in
    present)
      body_has "$body" "$literal" "$match" || O2_DIRECTION_BAD=$((O2_DIRECTION_BAD + 1))
      ;;
    ordered)
      { body_has "$body" "$literal" "$match" && body_has "$body" "$after" "$match"; } \
        || O2_DIRECTION_BAD=$((O2_DIRECTION_BAD + 1))
      ;;
    absent)
      body_has "$body" "$literal" "$match" && O2_DIRECTION_BAD=$((O2_DIRECTION_BAD + 1))
      ;;
  esac
done < <(jq -r '.invariants[] | select(.origin_issue==51) |
  [.id, .file, (.section // ""), .predicate, (.match // "fixed"),
   (if .predicate=="ordered" then .before else .literal end),
   (.after // "")] | @tsv' "$REGISTRY")

echo "  (info) O2(e): $O2_DIRECTION_BAD/$O2_COUNT51 origin_issue:51 entries mismatch their predicate direction (0 expected)"
assert_true "O2(e)-direction-aware: every origin_issue:51 entry matches its own predicate direction" \
  "[ '$O2_DIRECTION_BAD' -eq 0 ]"

# ---------------------------------------------------------------------------
# AC10 — Q6 (cost/latency) answered without overclaiming: explicit
# not-measured statement, and no numeric measurement-shaped token.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC10 — Q6 answered without overclaiming ==="

Q6_BODY="$(extract_section "Q6" "$ADR")"
assert_true "AC10(a): ### Q6 contains an explicit not-measured statement" \
  "body_has \"\$Q6_BODY\" 'not measured|unmeasured|no.{0,10}measurement|not.{0,15}measur' regex"

Q6_NO_ISSUE_REFS="$(sed -E 's/#[0-9]+//g' <<<"$Q6_BODY")"
assert_false "AC10(b): ### Q6 (issue references excluded) contains no numeral+unit measurement-shaped token" \
  "body_has \"\$Q6_NO_ISSUE_REFS\" '[0-9]+(\.[0-9]+)? *(tokens?|ms|sec(onds?)?|%|USD|\\\$)' regex"

# ---------------------------------------------------------------------------
# AC12 — CI enforcement: the fixed-literal run: step, both paths: blocks
# (suite + manual-scenarios file), and the ordering arm (below the runner
# step's name-located line).
# ---------------------------------------------------------------------------
echo ""
echo "=== AC12 — CI enforcement (workflow run: step + paths: + ordering) ==="

SUITE_REL="tests/test-issue-51-teammate-removal-verdict.sh"
MANUAL_REL="tests/manual/issue-51-manual-scenarios.md"

assert_true "AC12-run-step: workflow has a fixed run: step invoking $SUITE_REL" \
  "grep -qE 'run: bash tests/test-issue-51-teammate-removal-verdict\\.sh' '$WORKFLOW'"

# Capture-then-match (docs/submodule-common-rules.md:212, issues #964/#973):
# awk's buffered output piped directly into a short-circuiting `grep -q`
# consumer can SIGPIPE the producer under `set -o pipefail`, flipping a
# logically-passing assertion to a flaky FAIL. Capture each block once, then
# match the captured string.
PR_PATHS_CTX="$(awk '/^  pull_request:/{f=1} /^  push:/{f=0} f' "$WORKFLOW")"
# Bounded at the next top-level key (e.g. `permissions:`) — an unbounded
# capture ran to EOF and let a match against a LATER `run:` step (which also
# names the suite/manual file) silently stand in for a `paths:` entry,
# masking a deleted paths: row (mutation-tested finding, GATE:QUALITY E36).
PUSH_PATHS_CTX="$(awk '/^  push:/{f=1;next} /^[A-Za-z]/{f=0} f' "$WORKFLOW")"
export PR_PATHS_CTX PUSH_PATHS_CTX

assert_true "AC12-pr-paths-suite: pull_request paths: names $SUITE_REL" \
  "printf '%s\n' \"\$PR_PATHS_CTX\" | grep -qF '$SUITE_REL'"
assert_true "AC12-push-paths-suite: push paths: names $SUITE_REL" \
  "printf '%s\n' \"\$PUSH_PATHS_CTX\" | grep -qF '$SUITE_REL'"
assert_true "AC12-pr-paths-manual: pull_request paths: names $MANUAL_REL" \
  "printf '%s\n' \"\$PR_PATHS_CTX\" | grep -qF '$MANUAL_REL'"
assert_true "AC12-push-paths-manual: push paths: names $MANUAL_REL" \
  "printf '%s\n' \"\$PUSH_PATHS_CTX\" | grep -qF '$MANUAL_REL'"

RUNNER_LINE="$(grep -n "name: Run doc-invariant registry runner (#951)" "$WORKFLOW" | head -1 | cut -d: -f1)"
SUITE_LINE="$(grep -nE "run: bash tests/test-issue-51-teammate-removal-verdict\\.sh" "$WORKFLOW" | head -1 | cut -d: -f1)"
assert_true "AC12(c)-ordering: the new run: step's line is below the doc-invariant registry runner step's line (runner=$RUNNER_LINE, this cycle=${SUITE_LINE:-absent})" \
  "[ -n '$RUNNER_LINE' ] && [ -n '${SUITE_LINE:-}' ] && [ '${SUITE_LINE:-0}' -gt '$RUNNER_LINE' ]"

# ---------------------------------------------------------------------------
# AC14 — the exact 17-heading skeleton, each exactly once.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC14 — 17-heading skeleton, each exactly once ==="

HEADINGS_17=(
  "Status" "Context" "Case collection" "Decision" "Q1" "Q2" "Q3" "Q4" "Q5" "Q6"
  "Alternatives Considered" "Consequences" "Positive" "Negative" "Neutral / Trade-Offs"
  "Related Issues / PRs" "Notes"
)
for h in "${HEADINGS_17[@]}"; do
  n="$(count_heading "$h" "$ADR")"
  assert_true "AC14: heading '$h' occurs exactly once (currently $n)" "[ '$n' -eq 1 ]"
done

# ---------------------------------------------------------------------------
# AC15 — migration conditions include the agent-definition contract pointer
# (autoflow-tester.md must point at docs/autoflow-guide.md > VERIFY, not
# only > RED).
# ---------------------------------------------------------------------------
echo ""
echo "=== AC15 — agent-definition contract pointer condition ==="

assert_true "AC15: ## Decision names the .claude/agents/autoflow-tester.md VERIFY-pointer condition" \
  "body_has \"\$DECISION_BODY\" '\.claude/agents/autoflow-tester\.md' regex && body_has \"\$DECISION_BODY\" 'VERIFY' fixed"

VERIFY_POINTER_COUNT="$(grep -c 'VERIFY' "$AGENT_TESTER" 2>/dev/null || true)"
echo "  (info) .claude/agents/autoflow-tester.md currently carries $VERIFY_POINTER_COUNT VERIFY reference(s) (0 at HEAD is the defect AC15's condition names — not this cycle's implementation scope)"

# ---------------------------------------------------------------------------
# AC16 — the ADR body contains no thematic-break line (would truncate the
# Decision block that six of twelve registry entries evaluate against).
# ---------------------------------------------------------------------------
echo ""
echo "=== AC16 — no thematic-break line in the ADR body ==="

THEMATIC_BREAKS="$(grep -cE '^---[ \t]*$' "$ADR" 2>/dev/null || true)"
assert_true "AC16: docs/adr/0017-teammate-removal-feasibility.md contains no '^---$' thematic-break line (currently ${THEMATIC_BREAKS:-0})" \
  "[ \"\${THEMATIC_BREAKS:-0}\" -eq 0 ]"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
