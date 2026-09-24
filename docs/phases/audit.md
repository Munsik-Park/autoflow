# AUDIT — Security Audit (independent evaluation)

> Phase playbook for AUDIT. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

After VALIDATE, run a project-specific security audit on the change. Complements
GATE:QUALITY's `Security` item with 5 dedicated, project-specific items.

**Evaluator**: fresh-spawned Evaluation AI.
**Input**: change diff + the target's security checklist at the version the checklist status names
(*Security checklist* below), or none when none is declared. In a **review-response cycle**,
additionally the previous cycle's AUDIT report (`.autoflow/issue-{N}-c{C-1}-audit.md`, preserved at
PREFLIGHT) — its `## Low findings` list is the re-score's starting set.

**Security checklist — the target's own**. AutoFlow ships no checklist and names no item: AutoFlow owns how
AUDIT scores — the fresh evaluator, the five items below, the PASS thresholds — and the target owns
what each item is judged by. A target declares its checklist in the target-owned scaffold
`.claude/autoflow.local.json` (`{"audit":{"security_checklist":"<repository-relative path>"}}`).
At AUDIT entry the orchestrator runs
`bash scripts/gate/security-checklist.sh status --ledger .autoflow/issue-{N}-ledger.md` and acts on
its one record line:

| Exit | Verdict | AUDIT reads |
|------|---------|-------------|
| 0 | `none-declared` | no checklist — the five items are scored from the change alone, and the report records that none was declared |
| 0 | `unchanged` | the checklist as of the cycle's base commit (`score=<base>:<path>`) |
| 0 | `changed-decided` | the changed version a `[checklist-decision]` entry accepted (`score=HEAD:<path>`, or `none` for a dropped declaration) |
| 3 | `changed-undecided` | nothing yet — **[MUST]** AUDIT is not spawned: the orchestrator presents the change to the operator situation-first and pauses (`active:false`, `phase:"awaiting-user"`) |
| 2 | — | nothing — a malformed declaration, a declared file not committed, an uncommitted edit to the declaration or the checklist, or no resolvable base; repair it and re-run |

- **A change the cycle makes to its checklist.** A change to the file, or to the declaration that
  points at it, has no effect on that cycle's AUDIT until the operator accepts it. The answer is a `[checklist-decision]`
  ledger entry ([`decision-ledger.md`](../decision-ledger.md) > *Security-checklist decisions*):
  `accepted`, carrying the committed version's blob and non-empty Decision and Grounds lines under
  the authority `operator decision` → the status re-run reports `changed-decided`;
  `rejected` → the change is reverted and the status re-run. The pause consumes no re-entry budget.
- **The evaluator reads the named version.** The spawn prompt carries the record line; the evaluator
  re-runs the same status (it only reads), reads the checklist at the `score=` spec with `git show`,
  never the working-tree file, and copies the line into its report. A report whose line differs from
  the one the orchestrator recorded is a report defect: reject and re-spawn.

**Report file**: the evaluator's report is written to `.autoflow/issue-{N}-audit.md` and carries a
`## Security checklist` section (the status record line) and a
`## Low findings` section (each Low item with `path:line` at the audited commit and a one-line claim; `none` when empty).
The state file keeps only the scores.

**Review-response re-score**: the fresh evaluator does not re-derive the whole audit.
It re-scores **the change surface of this cycle** (the review-response diff) against the checklist,
re-checks each prior Low finding only where that diff touches its file, and inherits the rest by
citation — the same narrowed-input rule as GATE:QUALITY's re-entry re-score, using the same
`rescore` output field. Fresh spawn is unchanged; the input is.

## Scoring (5 items × 10 points)

Items adapt to the project's threat surface; defaults below. The target's checklist is what each
item is judged by; with none declared, the criteria below are the whole of it.

| Item | Criterion |
|------|-----------|
| Authn/Authz       | Are auth flows on changed endpoints complete? |
| Input validation  | Are external inputs (queries, parameters, payloads) validated/escaped? |
| Data exposure     | Are tokens / passwords / PII kept out of logs and responses? |
| Infra isolation   | Are internal ports/services not exposed externally? |
| Dependencies      | No known vulnerabilities in changed external dependencies? |

- **PASS** (avg ≥ 7.5, each ≥ 7, security ≤ 3 → immediate block) → recommendation triage
  ([GATE:QUALITY](gate-quality.md) > *Recommendation triage*) → GATE:QUALITY.
- **FAIL** → fix, re-evaluate (max 2×). Third FAIL → human.

GATE:QUALITY's `Security` item references the AUDIT result.
