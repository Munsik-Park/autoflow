# Criterion review measurements — ten runs on one reference issue (2026-10-05 – 2026-10-13)

A measurement record. It changes no rule, gate, hook or bundle, and it sits under `docs/records/`
so nothing here reaches a target. It is the evidence behind the criterion-review procedure as it
stands at plugin 0.2.34 (`docs/criterion-review.md`) and behind the issues that shaped it — #429,
#430, #434, #439, #442, #445 — and the open follow-up #448.

The runs were coordinated from this repository by sessions that were not AutoFlow cycles; each
kept a machine-local runbook. The raw material — runbooks, prompts, harness scripts, records,
grades, transcripts' contamination greps — stays on the operator's machine under
`~/.autoflow/_metrics/` (§8). Cited issue and PR numbers without a repository prefix are this
repository's; the measured target is `connev-llm/llmroute`.

---

## 1. Question

Run 3 took `connev-llm/llmroute#639` — a UI issue with six acceptance criteria across three
areas — through one full cycle: $279.22, 8h29m, ten advisor entries, six of them `[ac-decision]`
changes to the criteria made inside the cycle. The question carried through runs 4–10 was:

> Can a review of the acceptance criteria *before* the cycle find, against the code, the criterion
> defects that run 3 only discovered inside the cycle — without losing what it already finds, and
> at a cost that is worth paying?

## 2. Measurement design

### 2.1 Issues

| Role | Issue | Why |
|---|---|---|
| Reference | `connev-llm/llmroute#639` | Run 3's in-cycle criterion changes give a known answer set |
| Validation | `connev-llm/llmroute#707` (e2e tenant gate), `connev-llm/llmroute#601` (stale deploy path) | Different defect types; guards against tuning the procedure to one issue |

Every review read a frozen base (`llmroute` and its two sub-repos at fixed commits) and a frozen
copy of the issue body (sha256 recorded per run), in a fresh `git clone --local` per execution with
`origin` pointed at an invalid URL.

### 2.2 Checklists

Fixed before the runs they graded, and frozen by sha256 from run 8 on
(`unit-session-639-r8/checklists/`):

| Issue | Items |
|---|---|
| #639 | C1–C8 (run 3's criterion defects), D1–D7 (run 3's design points), S1 (split into three issues). **Targets**: C4 code-block syntax colour against the block background in the dark theme; C7 the parallel-response credit rule that hides every column's credit when one column has no usage record, against AC3; C8 the raw model ID shown outside the answer area. **C8v** (from run 8): C8 restricted to the search-results row — the shared-link page receives no model ID, so naming only it is a false positive. **Keep items**: C1, C5, C6, D1, D4, S1 |
| #707 | C1–C3, S1 |
| #601 | C1–C5, D1, S1 |

For the validation issues the reported figure is **not-named**: items the issue body does not name,
8 per round (#707 3 + #601 5). **item-named** is the items the body names.

From run 6 the checklists grade *detection* (the defect is recorded with its substance), not
*disposition* (the same handling the cycle's advisor chose); the switch alone moved the run-5
baseline from 1/16 to 6/16.

### 2.3 Grading

One fresh grader per record (`general-purpose`, `model: opus`), blind to run ID and condition,
reading only the checklist and the record, judged by the checklist's "Substance required for
found" column. Score: found 1, partial 0.5, 16 for #639. One grader per record carries a measured
±1 spread on the total (run 5), so a total within ±1 is not read as a difference.

### 2.4 Contamination control

From run 9: `gh` authentication cut (`GH_CONFIG_DIR` empty, `GH_TOKEN`/`GITHUB_TOKEN` unset),
`WebFetch`/`WebSearch` disallowed, one prompt line forbidding a lookup of the target issue. After
every run a grep over the main and subagent transcripts for the target issue, its closed PRs and
archive branches, earlier runs' stores and records, and the procedure issues whose bodies carry
#639's measurements; each hit is classified by its context.

### 2.5 Judgment rule (fixed before runs 9 and 10)

- **Reproduction**: #639 C8v or C7 found in at least 2 of 3 rounds, and no keep item missed.
- **Validation**: not-named above 11/24 (the run-8 single-review baseline).

Earlier runs fixed their own rules before execution; each is stated in its runbook.

## 3. Runs 1–4 — the cycle split by functional unit

| Run | Issue | Condition | Result | `/usage` |
|---|---|---|---|---|
| 1 | `llmroute#723` | One session per unit (S1–S6), harness advisor tool on | Completed; 31 advisor-tool calls, Fable 45% of cost | $152.09 |
| 2 | `llmroute#724` | Same, advisor tool off (#429) | Completed; decision points went to the `autoflow-advisor` subagent (1 entry); every gate passed first time | $80.82 |
| 3 | `llmroute#639` | Same, advisor tool off | Completed; 10 `A` entries, 6 `[ac-decision]`; 7 unit re-runs, 11 re-scores; PRs closed and kept on `archive/639-run3` as the reference | $279.22 |
| 4 | `llmroute#639` | Criterion review before the cycle (#430, 0.2.30); the operator accepted the split and ran area A only | The review found 4 of run 3's 6 `[ac-decision]` points in full and 2 in part; cycle had 0 `[ac-decision]`, 0 re-entries; stopped at HANDOFF on a red CI by instruction | $57.40 (review $3.78) |

Run 4's reduced scope (two criteria instead of six) explains much of its lower cost; the review's
effect and the scope's effect are not separable in one run. A re-run of run 4's review across
three models × five efforts (16 records) found C7 in none: no model or effort reached the
parallel-credit rule, which pointed at the review's questions and inputs rather than model
capacity. Runs 5–10 measured only the review.

## 4. Runs 5–10 — the criterion review

### 4.1 Per run

| Run | Bundle / condition | #639 C4 · C7 · C8(v) | #639 score | Validation not-named | Cost (runs only) | Led to |
|---|---|---|---|---|---|---|
| 5 | 0.2.30 + policy text: P1 look outside the checklist, P2 perspective-based reading | 0/12 for the three targets | P0 12.3 · P1 11.8 · P2 12.0 | within 1 of P0 | $61.8 | #434 — the review was confined to what the criteria name |
| 6 | 0.2.31 (#434: impact analysis, actual-vs-expected, no restriction to named objects) | 0/18 | 11.50 (P0 12.33) | 6/16 = P0 6/16 | $24.15 | — |
| 6 follow-up | A second pass taking the first record as input and asking where a confirmed cause also acts and whether a required behaviour conflicts with a rule in force; separate session or same session | Opus/high: separate C8 3/3, same session C8 2/3; C7 found twice in all conditions (Sonnet) | 10.5–15.0 | — | $142.12 across conditions | #439 — a second stage in the same session |
| 7 | 0.2.32 (#439: two stages; stage 2 assessed the impact of the expected approach) | 0/3 · 0/3 · 0/3 | 12.83 | 10/24 | $26.76 | — |
| 7 arms | LSP tool alone (A/B), method named (C), a five-step search direction with LSP (D), + condition step (E), English principles (F); independent verification session | D: C8 2/3, C4 2/3, not-named 14/24; E/F: C8 0/3; verification added no C7 | 12.2–14.2 | 13–16/24 | $201.50 (whole run) | — |
| 8 A | Reproduce D | D C8v 0/3 (one share-page-only false positive) | 13.33 | 15/24 | $59.88 | C8v defined |
| 8 B | Evaluate-and-revise loop on D records (5 calls per record) | C8v 3/3, C4 2/3, C7 1/3 | 14.67 | 20/24 | $273.59 | — |
| 8 F | Four-step review: first pass → wide case analysis → targets → per-criterion re-analysis without the first verdicts → integration | C8v **3/3**, C7 1/3, C4 0/3 | 14.33 | **16/24** (P4 single review 11/24) | $150.23 | #442 — re-analysis and integration |
| 9 | 0.2.33 (#442) stamped, the procedure's own spawns | C4 1/3 · C7 1/3 · C8v **0/3** | 14.0 · 14.0 · 13.0 | **15/24** | $113.84 | #445 — remove the approach stage; ask cause reach and rule conflict; advisor first outside the cycle |
| 10 | 0.2.34 (#445) stamped: stage-2 tracer, in-depth analysis, reconciler, advisor answers open questions | C4 3/3 · C7 1/3 · C8v **2/3** | 14.5 · 15.5 · 13.0 | **17/24** | $394.95 | #448 |

Run 9 judged by §2.5: reproduction **not met** (C8v 0/3, C7 1/3), validation met (15/24).
Run 10 judged by §2.5: reproduction **met** (C8v 2/3, no keep item missed in any round),
validation **met** (17/24). Item-named stayed 9/9 and no keep item was missed in any run from 5 on.

### 4.2 What moved C8 and C7

- **Wording added to one review did not move them** (runs 5, 6, 7, 8 C/D/D2 single checks). Each
  new item was applied as written — the records carried the new sections — and the reach stayed
  where the reviewer's first reading had put it: C8 stopped at surfaces inside the answer area,
  C7 at the column header that shows the credit.
- **A second look that does not inherit the first verdict moved C8.** The run-6 follow-up, the
  run-8 B loop, run 8 F and run 10 each re-asked from a confirmed cause or a listed case, in a
  context that had not settled it, and C8 or C8v reached 2/3 or 3/3. Run 7's verification
  session, which was handed the first record's verdicts and grounds, re-confirmed them and added
  no #639 target: a separate session is not by itself a separate frame.
- **C7 stayed at 1/3 or below in every condition.** Where it was missed the record had read the
  parallel-credit path but judged the requirement already met ("parallel columns already show
  credit"), or listed the producer rule as a conditional hold instead of a conflict with AC3.
- **Run 9 vs run 10.** Run 9's three C8v misses had the same shape: the search-results screen was
  handled only in AC1's scope judgment. In run 10 the stage-2 tracer raised it as a `new` finding
  for AC2 in rounds 1 and 2; in round 3 it again treated `/search` and `/share` only for AC1 and
  judged them outside the cause's reach.

### 4.3 Cost

| Condition | #639 per record | #707 | #601 |
|---|---|---|---|
| Run 8 P4, single review | $1.8–5.2 | — | — |
| Run 8 F, external four-step | $23–26 | $10–11 | $15–16 |
| Run 9, 0.2.33 stamped | $18.7–19.5 | $5.9–7.7 | $10.0–13.2 |
| Run 10, 0.2.34 stamped | $69.6–77.4 | $23.4–33.5 | $24.5–39.5 |

Run 10's $394.95 splits into Opus $167.37 (review session, tracer, in-depth, reconciler) and
Fable $227.56 (58%, the `advisor` spawns at `fable`/`max` per `spawn-policy.json`). Its Opus share
alone is 1.5× run 9's whole cost. Advisors answered 5–6 open questions per #639 record and 1–3 per
validation record; in run 9 the same kind of question was left to the operator.

## 5. Findings across the ten runs

1. Pre-cycle review is cheap relative to a cycle and catches most criterion defects that run 3 met
   in-cycle (run 4: 4 full + 2 partial of 6), but its reach is set by its first reading.
2. Detection of defects the issue does not name rose from 10–11/24 (single review) to 15–17/24
   with the staged procedure (runs 8 F, 9, 10), without loss on named items or keep items.
3. The one target that moved between runs 9 and 10 (C8v 0/3 → 2/3) moved with the stage-2 question
   about how far a confirmed cause reaches; it was not stable (round 3 missed it).
4. C7 — a rule in force that defeats the required behaviour in a case the issue does not report —
   was not reliably found by any condition. #707 C3 (the legacy public shared-link runtime) was
   missed in all six rounds of runs 9 and 10, and #601 D1 was partial or missed in all of them.
5. Cost rose with each structural addition; at 0.2.34 most of it is the advisor answering open
   questions at `fable`/`max`.

## 6. Run 10 operational observations

- **Background advisors and `claude -p`.** With advisors spawned in the background, `claude -p`
  stopped them ten minutes after the last turn ("Background tasks still running 10m after the last
  turn … Set CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 to wait indefinitely"). Rounds 2 and 3 set
  that variable. This concerns headless measurement only.
- **Sequential versus parallel advisors.** Without instruction, the round-1 #639 session ran its
  five advisors one after another (06:39–07:23, 10–12 minutes each). With one prompt line asking
  for parallel spawns when there were two or more questions, rounds 2 and 3 sent independent
  questions together and dependent ones after (5+1, 4+2); the #639 review fell from about 104 to
  about 59 minutes. Cost did not fall. Parallel or sequential is a working choice of the AI
  (`CLAUDE.md` > Rule Scope, principle 2); #448 asks the advisor procedure to state that
  independent decisions may be spawned together, without making it a `[MUST]`.
- **Ledger identifier collision.** Parallel advisors called `ledger-entry-id.sh next` before each
  other's append and received the same serial: `A3`/`A4` in one #639 ledger, `A1`/`A3` in one #601
  ledger (`check` exit 1). The sessions re-derived the entries under new identifiers, and once the
  re-derivation itself collided. Filed as #448.
- **Interruptions.** Round 1 #639 hit the 90-minute harness timeout during sequential advisors;
  round 3 hit the account's session usage limit mid-reconciliation. Both were resumed once in the
  same session (`--resume`); `total_cost_usd` of a resumed run is the session's cumulative cost.
  Only round 2 ran uninterrupted.
- **Contamination.** No access to the target issue in any run. `curl` sits outside the
  `WebFetch` block: one round-1 session fetched a library's source with it, and one round-2 advisor
  tried `gh api` on a library's docs and was refused by the cut authentication. Grep hits were the
  target's own code comments citing its issue #445, ADR text citing #739, and the plugin's
  `spawn-policy.json` description citing this repository's #445.

## 7. Limits

- Three rounds per condition and one grader per record; a difference of one found item in three
  rounds is within the spread.
- The checklists derive from run 3's cycle. A defect that run 3 did not meet is not counted.
- #639 is the issue the procedure text was iterated on; #707 and #601 are the only checks against
  over-fitting, and no new issue was chosen in advance of a run.
- Cost and structure are not separated: no condition compared the staged procedure with several
  independent single reviews of the same total cost.
- Runs 1–4 compare different issues (1–3) or a reduced scope (4); their cost differences mix issue
  size with the condition.
- From run 9 the harness cut GitHub authentication and the web tools; a material only reachable
  there (such as #639's design mockups, linked from `llmroute#284`) was out of reach of the
  review, which a real review would have.

## 8. Raw material

On the operator's machine, under `~/.autoflow/_metrics/`:

| Runs | Runbook | Store |
|---|---|---|
| 1 | `unit-session-runbook-723.md` | `unit-session-723/` |
| 2 | `unit-session-runbook-724.md` | `unit-session-724/` |
| 3 | `unit-session-runbook-639.md` | `unit-session-639/` |
| 4–10 | `unit-session-runbook-639-r<N>.md` | `unit-session-639-r<N>/` (prompts, harness scripts, `FROZEN.sha256`, records, grades, aggregates) |

Each run's handoff and start prompt are `unit-session-639-run<N>-handoff.md` and
`unit-session-639-run<N>-prompt.txt` beside them. The measurement clones were deleted after each
run; the records and grades are kept in the stores.
