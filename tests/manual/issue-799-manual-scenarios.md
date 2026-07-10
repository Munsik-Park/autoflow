# Issue #799 — Manual Verification Scenarios (Tier-2/Tier-3, delegated)

These acceptance criteria are **not scriptable** as fixed-string/`git diff`
oracles — they are primacy/completeness/semantic-equivalence judgments a
grep cannot make — or are **environment-dependent** (already covered by an
existing E2E harness). They are delegated per the verification design
(`.autoflow/issue-799-verification-design.md` §2 Tier 2 / Tier 3).

- **AC1-src** (Tier 2): the rewritten README Quick Start install steps match
  `setup/SETUP-GUIDE.md` > "Install as a consumed tool" step-for-step (one
  path, not two divergent ones — `docs/maintained-docs.md:150` sync rule).
- **AC2-pos wording accuracy** (Tier 2): the replaced structure-tree
  annotation for `setup/init.sh` / `setup/SETUP-GUIDE.md` is accurate
  (describes the current consumed-tool role), not merely blanked out.
- **AC2-tree exhaustiveness** (Tier 2): the structure tree is exhaustive
  against `ls` — the automated suite only spot-checks a fixed subset of
  currently-shipped top-level entries; it cannot assert "nothing else is
  missing."
- **AC5D-index-pos coherence** (Tier 2): if the `docs/INDEX.md` implementation
  routing row survives (re-pointed rather than removed), the replacement is a
  coherent topology-agnostic pointer (e.g. to `docs/repo-boundary-rules.md`),
  not a dangling stub that merely resolves to *some* existing path.
- **AC1-e2e** (Tier 3, reuse — no new harness): the documented `--target`
  install flow actually installs into a target end-to-end. Already exercised
  by `tests/plugin/verify-e2e-dummy-target.sh` / CI job
  `.github/workflows/e2e-dummy-target.yml`, which drives `setup/init.sh
  --target` against a dummy library target. Cited as existing coverage; not
  re-authored for this docs issue.

---

## AC1-src — README Quick Start ↔ SETUP-GUIDE.md step agreement

**Why not automated:** semantic equivalence between two prose documents
("do these describe the same sequence of commands, in the same order, with
no divergent third variant") is a judgment call, not a fixed-string match.

**Steps:**

1. Open `README.md` Quick Start section and `setup/SETUP-GUIDE.md` > "Install
   as a consumed tool" (`:12-67`) side by side.
2. Confirm every command in the README Quick Start appears in SETUP-GUIDE.md
   in the same order and with the same flags (`--target <path>`, `/plugin
   marketplace add Munsik-Park/autoflow`, `/plugin install
   autoflow@autoflow`).
3. Confirm the README does not present a third, invented variant not found in
   SETUP-GUIDE.md.
4. Confirm any legacy/in-place mention in the README is explicitly labeled
   "legacy/reference" and matches SETUP-GUIDE.md's own framing (`:5-8`), never
   presented as the default.

**Pass condition:** the two documents describe one install path in agreement;
no drift, no unlabeled second path.

---

## AC2-pos — structure-tree annotation wording accuracy

**Why not automated:** the automated suite (AC2-neg) only proves the stale
`template-era; kept as reference` string is gone; it cannot judge whether the
replacement wording is *correct*, only that it exists.

**Steps:**

1. Read the annotation next to `setup/init.sh` and `setup/SETUP-GUIDE.md` in
   README's structure tree.
2. Confirm it describes their current role: consumed-tool installer /
   consumed-tool install guide — not a vague placeholder, not simply blank.

**Pass condition:** annotation text is accurate and specific, not a
find-and-delete leftover.

---

## AC2-tree — structure-tree exhaustiveness

**Why not automated:** the automated suite spot-checks a fixed subset of
directories (`docs/adr/`, `docs/phases/`, `.claude/agents/`,
`.claude/workflows/`, `.github/workflows/`, `scripts/`, `tests/`, `plugin/`,
`setup/manifest.json`); it cannot prove "nothing else is missing" — that
requires a diff against the live filesystem.

**Steps:**

```bash
ls -la
```

Compare against the README structure tree; confirm every currently-shipped
top-level entry that matters to a consumer is represented (or explicitly and
intentionally omitted, e.g. `.git/`, `node_modules/`).

**Pass condition:** no top-level entry a new consumer would need to know
about is silently missing from the tree.

---

## AC5D-index-pos — INDEX.md replacement route coherence

**Why not automated:** the automated suite only checks that a surviving
routing row resolves to an existing on-disk path (`test -e`); it cannot judge
whether the replacement pointer is a *sensible* topology-agnostic
destination for a reader following the Quick Routing table.

**Steps:**

1. Open `docs/INDEX.md`'s Quick Routing table.
2. If the former `services/librechat` implementation row was re-pointed
   (rather than removed), confirm the new target (e.g.
   `docs/repo-boundary-rules.md`) is a coherent, topology-agnostic
   destination — a multi-repo consumer reading it would land somewhere
   useful, not a dangling stub.

**Pass condition:** the row (if retained) points somewhere a reader can
actually use; if removed, no dangling reference is left behind (already
covered by AC4-guard).

---

## AC1-e2e — documented install flow executes end-to-end

**Why not automated here:** already covered by an existing harness; adding a
second environment-dependent E2E for a docs issue would duplicate coverage.

**Reference:** `tests/plugin/verify-e2e-dummy-target.sh`, run in CI via
`.github/workflows/e2e-dummy-target.yml`. This suite provisions a
structurally-real, zero-submodule dummy library target and drives
`setup/init.sh --target <path>` against it, confirming the consumed-tool
install flow works end-to-end.

**Pass condition:** the existing CI job stays green; no new manual step is
required beyond confirming this job's continued coverage of the `--target`
flow this issue documents.
