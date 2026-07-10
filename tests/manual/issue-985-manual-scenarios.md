# Issue #985 — Manual/Environment-Dependent Verification Scenarios

These acceptance criteria are **not** covered by
`tests/test-issue-985-doc-assertions.sh` — they are semantic/editorial
judgments a grep cannot make, or they depend on a real GitHub Actions
environment / the `reuse` CLI that this bash-only harness cannot reproduce.
Delegated per the verification design
(`.autoflow/issue-985-verification-design.md` Part 3 / AC3 / AC4).

---

## AC4-NARRATIVE — README single-install-story coherence (manual, Part 3 #1)

**Why not automated:** the scripted suite asserts the discrete presence of
`/plugin marketplace add Munsik-Park/autoflow` and the Elastic License 2.0 summary
section (`AC4-INSTALL-PATH`, `AC4-LICENSE-SUMMARY`). Whether the README reads
as *one coherent narrative end-to-end* — no orphaned "or clone the repo"
branch, no dangling link into a removed internal doc, install steps ordered
and self-consistent — is editorial judgment, not grep-checkable.

**Steps:**

1. Read the rewritten `README.md` top to bottom as a first-time visitor would.
2. Confirm the install path is presented as a single sequence: `/plugin
   marketplace add Munsik-Park/autoflow` → `/plugin install autoflow@autoflow` →
   `/autoflow:install`, with no competing "or clone this repo and run
   `setup/init.sh` directly" branch presented as an equally-valid alternative
   entry point.
3. Confirm no link or reference into a path removed by §7 (
   `docs/improvement-backlog.md`, `docs/host-service-decoupling-plan.md`,
   `docs/librechat-deploy-extraction-plan.md`, `docs/LibreChat_프로젝트안.docx`,
   `docs/adr/0001-*.md`, `Jenkinsfile`) survives.
4. Confirm the licensing summary section reads coherently in the surrounding
   narrative flow (not a jarring insert).

**Pass condition:** a reader following the README top-to-bottom reaches a
working install with no orphaned branch and no dead link.

---

## CLAUDE.md secondary-prose fidelity (manual, Part 3 #2)

**Why not automated:** `run-doc-invariants.sh` (L1/L5) guards the *literal*
`796-*`/`794-*` pinned strings survive the rewrite. Whether the retained
multi-repo "secondary" prose still reads as coherent guidance after the
connev-org-specific forward-routing subsection is removed — not merely that
the pinned literals are present — is a human read.

**Steps:**

1. Read `CLAUDE.md` > Deployment Topology / Issue Management after the D1
   Tier-1 removal of the "Forward routing (post-#785 inversion)" llmroute
   subsection.
2. Confirm the surrounding *Secondary (multi-repo)* prose still makes sense
   as generalized guidance (generic service-host placeholder, not a
   half-finished sentence or a reference to a routing rule that no longer
   exists in the same section).
3. Cross-check against `docs/repo-boundary-rules.md`'s parallel edit for
   internal consistency.

**Pass condition:** the retained secondary prose reads as complete,
self-consistent guidance with only example identifiers generalized.

---

## Dead-link disposition uniformity (manual, Part 3 #3)

**Why not automated:** `AC1-SWEEP`/`AC1-NO-DANGLING-REF` catch a *removed*
path's dangling reference and the raw `connev` token census, but the
`connev-llm/...#N` issue-anchor **policy choice** (D9: rewrite `#N`/`#M`
**template placeholders** to `Munsik-Park/autoflow#N`; real numbered historical
anchors need no rule because none survive outside deleted docs) is a
uniformity judgment across files, not a single grep assertion.

**Steps:**

1. Enumerate every surviving `connev-llm/claude-autoflow#N` /
   `connev-llm/claude-autoflow#M` occurrence pre-change (per feature design
   D9: `docs/autoflow-guide.md`, `docs/git-workflow.md`, `CLAUDE.md`,
   `tests/manual/issue-800-manual-scenarios.md`, the doc-invariant rows).
2. Confirm every surviving occurrence is a `#N`/`#M` **template placeholder**
   (not a real numbered issue/PR reference) and that each is rewritten to
   `Munsik-Park/autoflow#N` uniformly — no file left on the old coordinate and no
   file given a different disposition (e.g. "internal ref" marker) than the
   others.
3. Confirm the one real numbered anchor found pre-change (`#760`, in the
   §7-deleted `docs/improvement-backlog.md`) required no rewrite because the
   file is deleted, and this is not silently treated as a precedent for
   keeping other real anchors verbatim (none survive to test that case).

**Pass condition:** the same disposition rule (template-rewrite) is applied
to every surviving `connev-llm/claude-autoflow#N` occurrence, with no
per-file ad hoc exception.

---

## Elastic License 2.0 fitness (manual, Part 3 #4)

**Why not automated:** `AC-LICENSE` asserts the mechanical facts (Elastic
License 2.0 text present, Copyright notice present, `LICENSES/Elastic-2.0.txt`
present). Whether the README's allow/deny summary correctly restates Elastic
License 2.0's actual terms (hosted/managed-service provision prohibited;
distribution/bundling/personal/internal use/modification allowed), and
whether the one-line commercial-exception notice is accurate, is a
legal-intent judgment out of scope for automation.

**Steps:**

1. Read the full `LICENSE` file (Elastic License 2.0 verbatim text) and
   confirm it matches the upstream Elastic License 2.0 text exactly (no
   accidental edits during the swap).
2. Read the README's allow/deny summary section and confirm it accurately
   restates Elastic License 2.0's actual permission boundary (hosted/managed
   service provision to third parties prohibited; distribution/bundling,
   personal/internal use, and modification permitted) — not a generic or
   mistaken paraphrase — and that the one-line commercial-exception notice
   (hosted/managed service requires a commercial license; contact path
   present) is accurate and does not fold in the separate connev-route
   bundling terms (per the owner's 2026-07-10 decision: those stay in a
   separate commercial document, not in `LICENSE` body).
3. Confirm this is the license the project owner (`Munsik-Park`) intends for
   the public release (this is a human ratification of the 2026-07-10
   owner decision superseding PolyForm Internal Use, not inferred from the
   issue text).

**Pass condition:** a human with the license text open confirms the README
summary is an accurate restatement and the Elastic License 2.0 choice is
intentional.

---

## `reuse lint` real run (manual/environment-dependent, Part 3 #5)

**Why not automated in RED:** `reuse` (the Python REUSE-spec linter) is not
installed in this repo's toolchain (verified: no `package.json`/jest, no
bundled `reuse`). `AC3-SPDX-COVERAGE` is a **tool-free proxy** — necessary
but not sufficient — that checks inline-header presence and that
`REUSE.toml` + `LICENSES/LicenseRef-*.txt` exist. It does **not** validate
`REUSE.toml`'s coverage of the bulk `.md`/`.json`/`.jsonl`/`.txt` set the way
the real linter does.

**Steps (run once, manually, before or during HANDOFF if not yet CI-gated):**

1. Run `pipx run reuse lint` (or `pip3 install reuse && reuse lint`, or
   `docker run --rm --volume "$PWD:/data" fsfe/reuse lint` if `pipx`/`pip3`
   are unavailable) from the repository root.
2. Confirm the command exits 0 with no "MISSING COPYRIGHT/LICENSING
   INFORMATION" entries.
3. If entries are reported, confirm each is either genuinely uncovered (a
   real gap to fix) or a `REUSE.toml` glob issue (fix the glob, not the
   file).
4. Record the PASS (command + exit code + date) in this cycle's HANDOFF
   notes; the durable authoritative gate is the new
   `.github/workflows/reuse.yml` (`fsfe/reuse-action`) observed green in CI
   at INTEGRATE/HANDOFF (`AC3-CI-GREEN`), not this manual run.

**Pass condition:** `reuse lint` exits 0 locally (or the `reuse.yml` CI
workflow is green — either satisfies AC3's `reuse lint PASS` clause).

---

## AC3-CI-GREEN — 6 GitHub Actions workflows green (environment-dependent, HANDOFF)

**Why not automated in RED:** requires a real GitHub Actions run; `bash
tests/test-issue-985-doc-assertions.sh`'s `AC3-WORKFLOW-COUNT` only checks
the workflow **file count/names** locally, not that they execute green.

**Steps:**

1. At INTEGRATE/HANDOFF, open the PR's Checks tab.
2. Confirm all 6 workflows (`e2e-dummy-target.yml`, `host-purity-delta.yml`,
   `plugin-package.yml`, `schema-hook-contract.yml`,
   `workflow-regression.yml`, `reuse.yml`) report green, with no unrelated
   regression introduced by the identifier sweep or the SPDX header
   insertions (a malformed header could break a script's shebang-adjacent
   parsing — confirm none do).

**Pass condition:** all 6 workflows green on the PR before HANDOFF completes.
