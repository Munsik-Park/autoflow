#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# tests/issue-92/test-docs.bats — AC4-AC9 documentation greps (cycle 1 + cycle 2 + cycle 3 delta).
#
# T4-1 (cycle 1; issue #222 retarget): docs/autoflow-guide.md HANDOFF step 4 references the script + --draft + blocked-by-subrepo.
# T5-1 (cycle 1; issue #222 retarget): docs/autoflow-guide.md has "Merge Sequencing (external review)" subsection with 5 numbered steps.
# T5-2 (cycle 3): Step 3 prose mentions 4 machine-verification gates incl. host-only diff + Contents: Write.
# T6-1 (cycle 1): CLAUDE.md PR Issue Auto-Close section mentions HOST-CLOSE-LINE.
# T7-1 (cycle 1): docs/git-workflow.md Merge Strategy has "Merge Sequencing (external review)" pointing to F7.
# T8-1a..d (cycle 2): F7 Operator prerequisites H2 + 4 H3 subsections.
# T8-2a (cycle 2): F7 Per-issue procedure H2 + H3 subsections preserved.
# T8-2b (cycle 3): F7 Multi-repo cycle subsection names all 8 workflow steps.
# T8-3a (cycle 2): F7 dispatch token states Contents: Write (positive).
# T8-3b (cycle 2): F7 does not state the incorrect `metadata: read + actions: write` (negative).
# T8-4 (cycle 2): F7 Token-as-merge-gate warning enumerates the 3 gates (Option B — unchanged).
# T8-5a..d (cycle 3): F7 Retry safety H3 + host-only enforcement note + Exit 80 in failure-mode list + retry-safety body.
# T9-1 (cycle 1): maintained-docs.md registry has all 4 new entries.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
GIT_WF="${REPO_ROOT}/docs/git-workflow.md"
GUIDE="${REPO_ROOT}/docs/autoflow-guide.md"
F7="${REPO_ROOT}/docs/external-review-sequencing.md"
MAINT="${REPO_ROOT}/docs/maintained-docs.md"

# Extract the HANDOFF section body. Issue #222 moved the phase bodies out of
# CLAUDE.md into the phase-body source of truth docs/autoflow-guide.md, where
# HANDOFF is an h2; capture from `## HANDOFF` to the next `## ` heading so its
# `### HANDOFF failure` / `### Merge Sequencing` subsections stay in the block.
extract_handoff_block() {
  awk '
    /^## HANDOFF/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section { print }
  ' "$GUIDE"
}

@test "T4-1a: autoflow-guide.md HANDOFF block references scripts/handoff/create-host-pr.sh" {
  [ -f "$GUIDE" ]
  block="$(extract_handoff_block)"
  printf '%s\n' "$block" | grep -qF 'scripts/handoff/create-host-pr.sh'
}

@test "T4-1b: autoflow-guide.md HANDOFF block references --draft" {
  [ -f "$GUIDE" ]
  block="$(extract_handoff_block)"
  printf '%s\n' "$block" | grep -qF -- '--draft'
}

@test "T4-1c: autoflow-guide.md HANDOFF block references blocked-by-subrepo" {
  [ -f "$GUIDE" ]
  block="$(extract_handoff_block)"
  printf '%s\n' "$block" | grep -qF 'blocked-by-subrepo'
}

@test "T5-1a: autoflow-guide.md has 'Merge Sequencing (external review)' subsection" {
  [ -f "$GUIDE" ]
  grep -qE '^#{3,4} Merge Sequencing \(external review\)' "$GUIDE"
}

@test "T5-1b: 'Merge Sequencing (external review)' subsection has 5 numbered steps" {
  [ -f "$GUIDE" ]
  # Capture from the subsection heading to the next heading of any level
  # starting with #.
  body="$(awk '
    /^#{3,4} Merge Sequencing \(external review\)/ { in_section = 1; next }
    in_section && /^#{1,4} / { in_section = 0 }
    in_section { print }
  ' "$GUIDE")"
  count="$(printf '%s\n' "$body" | grep -cE '^[0-9]+\. ' || true)"
  [ "$count" -eq 5 ]
}

# Issue #795 (ADR-0015 D3): the subrepo-merged dispatch/status-check machine
# was physically removed. Merge Sequencing step 3 is INVERTED from "dispatch +
# payload schema + machine gates" to the operator's manual pointer-reconcile
# confirmation; the machine tokens must be absent, the operator gate present.
@test "T5-2: Merge Sequencing step 3 is operator pointer-reconcile prose, no dispatch machine (issue #795)" {
  [ -f "$GUIDE" ]
  body="$(awk '
    /^#{3,4} Merge Sequencing \(external review\)/ { in_section = 1; next }
    in_section && /^#{1,4} / { in_section = 0 }
    in_section { print }
  ' "$GUIDE")"
  # Removed dispatch machine must be gone from the block.
  ! printf '%s\n' "$body" | grep -qF 'subrepo-merged'
  ! printf '%s\n' "$body" | grep -qF 'repository_dispatch'
  ! printf '%s\n' "$body" | grep -qF 'merge_commit_sha'
  # Surviving operator gate: the pointer-equality confirmation + label gate.
  printf '%s\n' "$body" | grep -qiE 'submodule pointer equals'
  printf '%s\n' "$body" | grep -qiF 'blocked-by-subrepo'
}

@test "T6-1: CLAUDE.md PR Issue Auto-Close section mentions HOST-CLOSE-LINE" {
  [ -f "$CLAUDE_MD" ]
  body="$(awk '
    /^### PR Issue Auto-Close/ { in_section = 1; next }
    in_section && /^### / { in_section = 0 }
    in_section { print }
  ' "$CLAUDE_MD")"
  printf '%s\n' "$body" | grep -qF 'HOST-CLOSE-LINE'
}

@test "T7-1a: docs/git-workflow.md Merge Strategy has Merge Sequencing (external review)" {
  [ -f "$GIT_WF" ]
  grep -qE '^#{3,4} Merge Sequencing \(external review\)' "$GIT_WF"
}

@test "T7-1b: docs/git-workflow.md Merge Sequencing subsection points to F7" {
  [ -f "$GIT_WF" ]
  body="$(awk '
    /^#{3,4} Merge Sequencing \(external review\)/ { in_section = 1; next }
    in_section && /^#{1,4} / { in_section = 0 }
    in_section { print }
  ' "$GIT_WF")"
  printf '%s\n' "$body" | grep -qF 'external-review-sequencing.md'
}

@test "T8-0: F7 docs/external-review-sequencing.md exists" {
  [ -f "$F7" ]
}

@test "T8-1a: F7 has 'Operator prerequisites' H2" {
  [ -f "$F7" ]
  count="$(grep -cE '^## Operator prerequisites$' "$F7" || true)"
  [ "$count" -eq 1 ]
}

@test "T8-1b: F7 has 'Label' H3 subheading" {
  [ -f "$F7" ]
  count="$(grep -cE '^### Label$' "$F7" || true)"
  [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Issue #795 (ADR-0015 D3): the subrepo-merged repository_dispatch
# status-check machinery was physically removed from
# docs/external-review-sequencing.md (feature D2 / §3). The F7 structure tests
# below are INVERTED accordingly: the surviving operator sections
# (Merge-order clearance, Host-only/Multi-repo cycles, Reconcile preflight)
# are asserted present; the removed dispatch/token/payload/status sections
# (Dispatch token, Sub-repo read token, Token-as-merge-gate warning, Payload
# schema, Retry safety) are asserted ABSENT. (T8-1c was already stale at HEAD —
# it asserted a 'Branch protection' heading renamed to 'Merge-order clearance'
# in an earlier cycle — and is realigned here.)
# ---------------------------------------------------------------------------
@test "T8-1c: F7 has 'Merge-order clearance (operator)' H3 subheading" {
  [ -f "$F7" ]
  count="$(grep -cE '^### Merge-order clearance \(operator\)$' "$F7" || true)"
  [ "$count" -eq 1 ]
}

@test "T8-1d: F7 no longer has 'Dispatch token' / 'Token-as-merge-gate warning' H3s (issue #795 — dispatch machine removed)" {
  [ -f "$F7" ]
  ! grep -qE '^### Dispatch token$' "$F7"
  ! grep -qE '^### Token-as-merge-gate warning$' "$F7"
}

@test "T8-2a: F7 has 'Per-issue procedure' H2 + 'Host-only cycle' / 'Multi-repo cycle' H3s; 'Payload schema' removed (issue #795)" {
  [ -f "$F7" ]
  ph2="$(grep -cE '^## Per-issue procedure$' "$F7" || true)"
  [ "$ph2" -eq 1 ]
  ! grep -qE '^### Payload schema$' "$F7"
  mr_count="$(grep -cE '^### Multi-repo cycle' "$F7" || true)"
  [ "$mr_count" -eq 1 ]
  ho_count="$(grep -cE '^### Host-only cycle' "$F7" || true)"
  [ "$ho_count" -eq 1 ]
}

@test "T8-2b: F7 'Multi-repo cycle' names the operator merge-order steps, not workflow steps (issue #795)" {
  [ -f "$F7" ]
  body="$(awk '
    /^### Multi-repo cycle/ { in_section = 1; next }
    in_section && /^#{2,3} / { in_section = 0 }
    in_section { print }
  ' "$F7")"
  # The dispatch workflow is gone; the surviving procedure is operator-manual.
  ! printf '%s\n' "$body" | grep -qiF 'validate payload'
  ! printf '%s\n' "$body" | grep -qF 'subrepo-merged'
  printf '%s\n' "$body" | grep -qiF 'merge the sub-repo'
  printf '%s\n' "$body" | grep -qiE 'submodule pointer'
  printf '%s\n' "$body" | grep -qiF 'blocked-by-subrepo'
}

@test "T8-3a: F7 no longer carries the 'Dispatch token' section (issue #795 — dispatch machine removed)" {
  [ -f "$F7" ]
  ! grep -qE '^### Dispatch token$' "$F7"
}

@test "T8-3b: F7 does not prescribe the incorrect 'metadata: read + actions: write' (negative — still holds after removal)" {
  [ -f "$F7" ]
  # The incorrect PAT-scope phrasing must not appear as an active permission
  # prescription. After #795 removed the Dispatch token section the phrase is
  # gone entirely; this negative guard continues to hold.
  ! grep -nE '(equire|use|need).*metadata: read \+ actions: write' "$F7"
  ! grep -nE 'metadata: read \+ actions: write.*(equired|sufficient|correct)' "$F7"
}

@test "T8-4: F7 no longer has the 'Token-as-merge-gate warning' section (issue #795)" {
  [ -f "$F7" ]
  ! grep -qE '^### Token-as-merge-gate warning$' "$F7"
}

@test "T8-5a: F7 no longer has a 'Retry safety' H3 (issue #795 — publish/status machine removed)" {
  [ -f "$F7" ]
  ! grep -qE '^### Retry safety$' "$F7"
}

@test "T8-5b: F7 'Host-only cycle' states no merge-order gate, no dispatch machine (issue #795)" {
  [ -f "$F7" ]
  body="$(awk '
    /^### Host-only cycle/ { in_section = 1; next }
    in_section && /^#{1,3} / { in_section = 0 }
    in_section { print }
  ' "$F7")"
  ! printf '%s\n' "$body" | grep -qF 'subrepo-merged'
  ! printf '%s\n' "$body" | grep -qiF 'exit 80'
  # Surviving statement: a host-only PR carries no merge-order gate.
  printf '%s\n' "$body" | grep -qiE 'no .*blocked-by-subrepo|no merge-order gate'
}

@test "T8-5c: F7 'Multi-repo cycle' no longer lists dispatch failure modes / Exit 80 (issue #795)" {
  [ -f "$F7" ]
  body="$(awk '
    /^### Multi-repo cycle/ { in_section = 1; next }
    in_section && /^#{2,3} / { in_section = 0 }
    in_section { print }
  ' "$F7")"
  ! printf '%s\n' "$body" | grep -qiE 'Exit 80'
  ! printf '%s\n' "$body" | grep -qF 'subrepo-merged'
}

@test "T8-5d: F7 Merge-order clearance is operator-owned label removal (issue #795 — retry/publish machine removed)" {
  [ -f "$F7" ]
  ! grep -qE '^### Retry safety$' "$F7"
  body="$(awk '
    /^### Merge-order clearance/ { in_section = 1; next }
    in_section && /^#{2,3} / { in_section = 0 }
    in_section { print }
  ' "$F7")"
  printf '%s\n' "$body" | grep -qiF 'operator'
  printf '%s\n' "$body" | grep -qiF 'blocked-by-subrepo'
}

@test "T9-1a: maintained-docs.md registers docs/external-review-sequencing.md" {
  [ -f "$MAINT" ]
  grep -qF 'docs/external-review-sequencing.md' "$MAINT"
}

@test "T9-1b: maintained-docs.md registers .github/pull_request_template.md" {
  [ -f "$MAINT" ]
  grep -qF '.github/pull_request_template.md' "$MAINT"
}

# Issue #795 (ADR-0015 D3): the handoff-sequence.yml workflow was physically
# removed, so its maintained-docs registry row is deleted (feature D4). Inverted
# from "registers" to "no longer registers".
@test "T9-1c: maintained-docs.md no longer registers the removed handoff-sequence.yml workflow" {
  [ -f "$MAINT" ]
  ! grep -qF '.github/workflows/handoff-sequence.yml' "$MAINT"
}

@test "T9-1d: maintained-docs.md registers scripts/handoff/create-host-pr.sh" {
  [ -f "$MAINT" ]
  grep -qF 'scripts/handoff/create-host-pr.sh' "$MAINT"
}

# Issue #795: tests/manual/issue-495-manual-scenarios.md was the manual
# companion of the deleted #495 token-scope suite (its subject, the workflow,
# is gone); it was deleted with its subject, so this guard now covers only the
# surviving issue-92 manual checklist.
@test "T9-2: issue-92 manual checklist describes no dropped workflow label-removal step (7-step contract)" {
  CHECKLIST="${REPO_ROOT}/tests/issue-92/manual-checklist.md"
  [ -f "$CHECKLIST" ]
  # A retired workflow had no "steps 7, 8" pair or a workflow "Remove label"
  # step; blocked-by-subrepo removal is the operator's manual step. Operator-
  # owned-removal prose ("remove the blocked-by-subrepo label manually") is NOT
  # matched here.
  STALE='steps? 7[-, ]+(and )?8|Publish / Remove|Remove blocked-by-subrepo label|Remove label|label remove is idempotent'
  ! grep -qiE "$STALE" "$CHECKLIST"
}
