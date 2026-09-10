# Issue #198 — Manual Scenario M1: live Record run over the failure-mode column (composition oracle L2)

Source: `.autoflow/issue-198-verification-design.md` > the design-added `—` row (composition
oracle), `## Verification depth` > L2 and `## Composition oracle`; feature design D8–D14; ledger
F16–F24 and O4 (3), (4).

**What this scenario verifies.** After GREEN, a real scribe — given the amended scribe prompt
(`.claude/workflows/architect-deliberation.js`) and the amended guide
(`docs/autoflow-guide.md` > ARCHITECT > Output artifacts) — writes the verification design and the
feature design the amendment directs. It traces all four `T ∩ S` identifiers:

| Trace | Check |
|---|---|
| `verification-design.ac-row-grain` | C1 |
| `verification-design.layer-failure-mode` | C2, C3 |
| `verification-design.existing-coverage-reason` | C4 |
| `feature-design.content-list` | C5 |

**Why it is a scenario and not a suite.** `test/workflows/run.mjs` replaces the scribe with a
responder, so no file is ever written (L1 covers the instruction only). This run drives the real
Workflow runtime and a real scribe writes the real files; nothing stands in for the shared state.
It is **not** delegated to the user: it runs at VERIFY and blocks the transition (D9). VALIDATE lists
it as executed at VERIFY, with its evidence artifact — not as "delegated to user".

**The scribe is an LLM.** One run is one sample: a pass is weak evidence, a fail is strong evidence.
A second run is not part of this scenario (verification design > Considered and not added).

---

## Roles

| Role | Does | Does not |
|---|---|---|
| Orchestrator | Step 1 (setup), Step 2 (run), Step 3 (completeness), Step 5 (retire); starts the cause branch on a fail | read the written designs to judge them (D11) |
| Test AI | Step 4: binds the surfaces, reads the written files against C1–C5, writes the result artifact, returns an anchor plus one line | edit the fixture outputs |

## When it runs

- **At VERIFY**, once step 1 is all PASS and before the phase transition (D9). For this cycle, step 1
  includes a direct `node test/workflows/run.mjs`: the harness is outside
  `scripts/test/run-suites.sh` (O4 (4)).
- **Re-run (D14).** On any route — REFINE, an `impl` or `test` re-entry, a GATE:QUALITY `doc`
  remedy, a HANDOFF `DOC_COMMIT` — a change to either bound surface since the last run re-runs this
  scenario before the next gate re-score or reviewer re-review reads the result. The staleness check
  is in Step 4 > *Surface binding*. A result whose recorded surface hashes are not current reads
  `not-run`.

## Fixture

- **Fixture id: `fm-column-oracle`**, passed as JSON args (D10). The id is non-numeric and
  carries no `issue-198-` prefix, as D10 requires. It is also **digit-free**. The workflow's
  prose-args fallback salvages digits (`architect-deliberation.js` prose fallback, tiers 1–3), so
  an id containing digits that reached the workflow as prose would resolve silently to a numeric
  issue id. A digit-free id makes that mistake fail loudly (`args.issue is required`). The id is
  also filename-safe (`[a-z-]`), because it is templated into `.autoflow/issue-<id>-*` paths
  unvalidated.
- **Committed inputs.**
  - `tests/fixtures/issue-198/record-oracle-transcript-body.md` — the turns and both reports of an
    ended discussion. It agrees three things:
    - a criterion (AC1) with two verifications;
    - an `existing-coverage` criterion (AC2);
    - a `none` criterion (AC3);
    - plus `T` with one entry and `S` declared empty.

    It states each verification's failure mode as a discussion conclusion and says nothing about
    where a document should record it. That makes the placement the prompt's and the guide's, which
    is what this scenario reads.
  - `tests/fixtures/issue-198/record-oracle-phase-b.md` — the acceptance-criteria table. Scribe
    clause (2) reads `.autoflow/issue-<id>-phase-b.md` (O4 (3)).
- **Transcript header: generated at run time, not committed** (O4 (3)). Step 1 runs the shipped
  `scripts/architect/relay-state.sh init`, so the `## Topic` the scribe reads is the one the tree
  under test produces, including any GREEN change to the topic text. `init` accepts a digit-only
  issue (`relay-state.sh` > `cmd_init`), so Step 1 initialises with a digit placeholder and
  substitutes the fixture id.
- **Fixture facts** — the reference the checks compare against:

| Row | Verification | The failure it alone catches |
|---|---|---|
| AC1 · V1 | repository unit test over `NotesRepository.list_for_owner` (in-memory schema) | the listing query omits the `deleted_at IS NULL` predicate |
| AC1 · V2 | API integration test against a real Postgres, across two pages | the raw-SQL page `PageQuery` builds still returns a deleted note — a path V1 never runs |
| AC2 | existing suite `tests/api/test_route_auth.py` | a route under `/notes` registered without the session-auth middleware |
| AC3 | `none` | — (no cell). Reason: a wrong description sentence costs a documentation fix and fails no call |

AC2's reason for owing no new layer: the suite walks `app.routes`, so it covers the new route with
no change.

---

## Procedure

### Step 1 — Setup (orchestrator, shell, repository root)

```bash
set -u
FID=fm-column-oracle
PH=4040404040                       # digit placeholder: relay-state.sh init accepts digits only
A=.autoflow; F=.autoflow/fixtures; T=.autoflow/issue-$FID-architect-transcript.md
# 1a. The tracked tree is quiet: the result binds the tree it ran on (D14).
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "SETUP BLOCK: tracked tree is dirty"; exit 1; }
# 1b. Retire a previous run's files. The Record's DELTA RULE appends a delta round when a feature
#     design already exists, so a run over leftover files would not be the first Record this reads.
mkdir -p "$F"
prev=$(ls "$F"/issue-198-oracle-run*-architect-transcript.md 2>/dev/null | wc -l | tr -d ' ')
if ls "$A"/issue-$FID-* >/dev/null 2>&1; then
  prev=$((prev + 1))
  for f in "$A"/issue-$FID-*; do mv "$f" "$F/issue-198-oracle-run$prev-${f#"$A"/issue-$FID-}"; done
fi
RUN=$((prev + 1)); echo "RUN=$RUN"
# 1c. The header from the shipped relay script, then the committed turns and reports.
bash scripts/architect/relay-state.sh init "$T.init" "$PH" || { echo "SETUP BLOCK: relay-state.sh init failed"; exit 1; }
sed "s/$PH/$FID/g" "$T.init" > "$T" && rm -f "$T.init"
if grep -q "$PH" "$T"; then echo "SETUP BLOCK: placeholder survived substitution"; exit 1; fi
cat tests/fixtures/issue-198/record-oracle-transcript-body.md >> "$T"
cp tests/fixtures/issue-198/record-oracle-phase-b.md "$A/issue-$FID-phase-b.md"
# 1d. The assembled transcript must read as an ended discussion with both reports.
bash scripts/architect/relay-state.sh state "$T"
```

Step 1d must print `turns=6`, `round=1`, `last=test`, `ended=true`, `reports=dev,test`,
`reports_missing=-`, `next=record`. Any other output, or any `SETUP BLOCK` line, stops the scenario
before the run. That is a fixture or setup defect, repaired and re-run from Step 1.

### Step 2 — Run (orchestrator)

```
Workflow({ name: "architect-deliberation", args: { issue: "fm-column-oracle" } })
```

- Wait by ending the turn.
- Invoke the Workflow tool with JSON args, **not** the `architect-deliberation` skill. The skill
  forwards free text, and the prose fallback cannot resolve a digit-free id.
- Keep the returned `stopped` and `summary` verbatim for Step 4.
- The run writes only `.autoflow/*` files, which are gitignored, so it never moves the tree.

### Step 3 — Completeness, K2 (orchestrator, shell; no design is read)

```bash
FID=fm-column-oracle
for d in feature-design verification-design; do test -s ".autoflow/issue-$FID-$d.md" && echo "present: $d" || echo "ABSENT: $d"; done
```

The run is `not-run` — never a pass — when either of these holds:
- the Workflow returned a non-null `stopped`;
- either line reads `ABSENT`.

VERIFY does not transition on a `not-run` result. Repair its cause and re-run from Step 1 (D13).
Otherwise spawn the Test AI for Step 4 with three things: this document's path, `RUN`, and the
verbatim `stopped` and `summary`.

### Step 4 — Read and record (Test AI)

Written files under test:
- `VD` = `.autoflow/issue-fm-column-oracle-verification-design.md`
- `FD` = `.autoflow/issue-fm-column-oracle-feature-design.md`

**Surface binding (D14).** Record each value in the result artifact:

```bash
git rev-parse HEAD
git status --porcelain --untracked-files=no            # must be empty: the tree is the one the run used
L=$(grep -n 'You are the scribe of an AutoFlow ARCHITECT deliberation' .claude/workflows/architect-deliberation.js | cut -d: -f1)
echo "scribe prompt line: $L"; sed -n "${L}p" .claude/workflows/architect-deliberation.js | shasum -a 256
# The column's defining clause: the bullet GREEN wrote beside the `Type` / `Issue AC` bullets in
# docs/autoflow-guide.md > ARCHITECT > Output artifacts. It says what the cell names, what it is
# compared against and what an unfillable cell means (D2). Record its range <A>-<B> and its first
# line verbatim.
sed -n '<A>,<B>p' docs/autoflow-guide.md | shasum -a 256
```

To check staleness later, re-locate both surfaces and re-hash the same number of lines:
- the scribe prompt by the `grep` above;
- the defining clause by `grep -nF` of its recorded first line.

A hash that differs, or a surface that cannot be re-located, makes the recorded result `not-run`
and re-runs this scenario.

**Validity.** `VD` and `FD` carry no `## Delta — round` heading. A delta heading means the run
recorded over leftover files rather than a first Record, so the result is `not-run`: re-run from
Step 1.

**Checks.** Each check is `PASS` or `FAIL` and cites `path:line` anchors in the written files. When
comparing a cell with the *Fixture facts*, judge its meaning: a paraphrase of the right failure is
the right failure, and a cell naming a different row's failure is wrong.

**One discriminator, used by C3 and C5.** A sentence that names a verification (a test, a layer or
a suite) *together with the defect it detects* restates a failure mode. These may stay:
- a sentence that names no verification — for example D2's ground that `PageQuery`'s raw SQL
  bypasses ORM scopes, which is design content;
- narrative that states no per-layer failure mode — the risk line, a count of layers, "no layer was
  removed", or a pointer to the table.

- **C0 — the classifier reads the new table (observation, not scored).**
  - Record the composition-oracle output attached in `VD`.
  - Record whether this reproduces it:
    `bash scripts/architect/composition-oracle.sh .autoflow/issue-fm-column-oracle-verification-design.md; echo "exit status: $?"`
  - The fixture agrees `T` = `notes.deleted_at` and `S` = none, so the expected output is
    `result: empty` with `exit status: 11`.
  - A reader-side oracle was considered and not added, so C0 does not decide the outcome.
- **C1 — row grain.** The acceptance-criteria table carries:
  - exactly two `AC1` rows, one for V1 and one for V2;
  - one `AC2` row;
  - one `AC3` row.

  FAIL if AC1 has a single row, or if any single row names both V1 and V2.
- **C2 — the column.** The table has a failure-mode column. The V1, V2 and AC2 cells each name that
  row's failure from *Fixture facts*, and the V1 and V2 cells can be told apart. The AC3 (`none`)
  cell is a dash. FAIL if any of these holds:
  - no such column;
  - an owed cell that is empty or a dash;
  - V1 and V2 cells that cannot be told apart;
  - a failure mode written on the `none` row.
- **C3 — stated once.** Outside the table, no sentence of `VD` restates what V1, V2 or the AC2
  suite catches. This covers `Test necessity`, `Verification depth` and every other section.
  - Candidate finder, an aid and not the verdict:
    `grep -n -i 'deleted_at IS NULL\|PageQuery\|raw.SQL\|middleware' <VD> | grep -v ':|'`
  - Judge each hit with the discriminator above.
- **C4 — the `Reason` split on the existing-coverage row.** The AC2 row's column names what
  `tests/api/test_route_auth.py` fails on. Its `Reason` says why no new layer is owed (the suite
  walks the application's routes, so it covers the new route unchanged). FAIL if any of these holds:
  - the `Reason` restates the failure the column names;
  - the `Reason` is empty;
  - the failure appears only in the `Reason`.
- **C5 — feature-design content.** `FD` states D1–D3 with their constraints and rejected
  alternatives, and states no verification's failure mode. Where it mentions verification, it cites
  the verification design — its column or rows — rather than restating. FAIL on any section or
  sentence that states what V1, V2 or the AC2 suite catches, judged by the discriminator above.

**Outcome.**
- `pass` — C1–C5 all PASS.
- `fail` — any of C1–C5 FAIL.
- `not-run` — any of these holds:
  - Step 3 found a non-null `stopped` or an absent design;
  - the validity check failed;
  - the surface binding is not current.

**Result artifact (D11).** `.autoflow/issue-198-oracle-result.md`, append-only: each run adds one
section, and an earlier section is never edited.

```
## Run <RUN> — <YYYY-MM-DD>
- scenario: tests/manual/issue-198-manual-scenarios.md
- tree: HEAD <40-char SHA>; tracked tree clean: yes|no
- scribe prompt: .claude/workflows/architect-deliberation.js:<L> sha256 <hex>
- column's defining clause: docs/autoflow-guide.md:<A>-<B> first line "<verbatim>" sha256 <hex>
- workflow return: stopped=<null|verbatim>; summary="<verbatim>"
- written by the run: .autoflow/issue-fm-column-oracle-{feature-design,verification-design,architect-report,ledger}.md (<present|absent> each)
- run inputs: .autoflow/issue-fm-column-oracle-{architect-transcript,phase-b}.md, from tests/fixtures/issue-198/record-oracle-{transcript-body,phase-b}.md
- C0 classifier (observation): <attached output> — reproduced: yes|no
- C1 row grain: PASS|FAIL — <anchors>
- C2 column: PASS|FAIL — <anchors>
- C3 stated once: PASS|FAIL — <anchors>
- C4 Reason split: PASS|FAIL — <anchors>
- C5 feature-design content: PASS|FAIL — <anchors>
- outcome: pass | fail | not-run (<cause>)
```

Return exactly one line: `.autoflow/issue-198-oracle-result.md — Run <RUN> — <outcome> — <one-line summary>`.

### On `fail` — the cause branch (D9, K1)

The result artifact is the failure log. Its fields name every input the self-checks need, by path
(K1):
- this scenario document;
- the scribe prompt line;
- the column's defining clause;
- the files the run wrote;
- the committed fixture sources.

The self-checks read only the failure log, their own side's code and `.autoflow/issue-198-*.md`, and
the fixture outputs sit outside that glob. The orchestrator starts:

```
Workflow({ name: "verify-cause-branch", args: { issue: "198", failLog: ".autoflow/issue-198-oracle-result.md" } })
```

- **"Test code"** is this document plus the two fixture sources.
- **"Implementation"** is the amended scribe prompt and guide.
- **`RED` for this row:** revise this document or a fixture source, commit, and re-run this scenario
  from Step 1. A manual row has no Red to confirm; the L1 tests in `test/workflows/run.mjs` keep
  their ordinary Red/Green.
- **`GREEN`, `SEQUENTIAL_FIX` and `EVALUATION_AI`** apply unchanged. One failing sample with both
  sides faithful lands in arbitration.
- **Cap:** GREEN ↔ VERIFY max 3, then human. This scenario adds no cap.
- **At REFINE:** a failed re-run takes REFINE's revert-to-VERIFY-Green route instead.

### Step 5 — Retire (orchestrator, at HANDOFF completion)

```bash
FID=fm-column-oracle; A=.autoflow; F=.autoflow/fixtures; mkdir -p "$F"
prev=$(ls "$F"/issue-198-oracle-run*-architect-transcript.md 2>/dev/null | wc -l | tr -d ' ')
if ls "$A"/issue-$FID-* >/dev/null 2>&1; then
  prev=$((prev + 1))
  for f in "$A"/issue-$FID-*; do mv "$f" "$F/issue-198-oracle-run$prev-${f#"$A"/issue-$FID-}"; done
  echo "- run $prev outputs retired to $F/issue-198-oracle-run$prev-*" >> "$A/issue-198-oracle-result.md"
fi
```

The fixture id falls outside cleanup's number-boundary match, so cycle cleanup would leave the run's
files behind (`scripts/cleanup/cleanup-issue.sh`). Retiring them into `.autoflow/fixtures/` under
`issue-198-` names does two things:
- it lets cleanup archive them with issue #198;
- it takes the run's ledger out of the gate hook's advisory ledger loop, which globs top-level
  `.autoflow/issue-*-ledger.md` only.

Step 1b performs the same move before every re-run.
