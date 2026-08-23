# Manual Scenarios — Issue #74 (C7 pilot execution record)

These are the criteria `.autoflow/issue-74-verification-design.md` names as
**not automatable**, because each is a claim about an act rather than about a
file's contents: the tool payloads actually issued to the two pilot arms, the
duty block actually handed to each arm, and the provenance link between each
scratch per-spawn record and its frozen-union row. `tests/test-issue-74-c7-pilot.sh`
machine-checks everything that has a durable file trace; this document is the
record of the rest.

## 1. The two arm payloads (verbatim)

Held equal per `.autoflow/issue-74-feature-design.md` §4 *Arm payloads*: same
model (`sonnet`), same fixture path (`tests/fixtures/c7-pilot/`), same
replicate index set (`1..3`), and one shared prompt block appended
byte-identically to both.

### `named` arm — `Agent` tool input (× 3 replicates, one at a time)

```json
{
  "team_name": "issue-74-cycle",
  "name": "test-c7-baseline-r<n>",
  "model": "sonnet",
  "subagent_type": null
}
```

Prompt = the **shared block** (§2 below) + the **duty-text block** (§3 below,
carried verbatim because this channel has no `subagent_type` and therefore no
agent-definition file to load it from).

### `direct` arm — `Agent` tool input (× 3 replicates)

```json
{
  "subagent_type": "autoflow-tester",
  "model": "sonnet"
}
```

Prompt = the **shared block** (§2 below) only. The duty text reaches this arm
through the loaded `.claude/agents/autoflow-tester.md` definition, not through
the prompt — appending it again would hand the duty twice, which Feature §4
states as the residual asymmetry this design does not remove (disclosed in
§6 below).

## 2. Shared prompt block (byte-identical across both arms)

```
Fixture: tests/fixtures/c7-pilot/ (repo-relative, at the current HEAD).

Perform the VERIFY step-3 minimal-implementation check and the step-4
mock-boundary fidelity check over this fixture, exactly as your standing duty
requires. Before the step-4 check, re-enumerate the iteration set from the
fixture tree at HEAD.

Write your result to .autoflow/issue-74-pilot-<arm>-r<n>.json in this shape:
{ "outcomes": { "step3_planted": "detected|clean|not-run",
                "step3_clean":   "detected|clean|not-run",
                "step4_planted": "detected|clean|not-run",
                "step4_clean":   "detected|clean|not-run" },
  "iteration_set": ["<double> -> <real interface>", ...],
  "observed_head": "<git rev-parse HEAD>" }
Report only that you wrote the file and its path.
```

## 3. Duty-text block — `named` arm only (verbatim body of
`.claude/agents/autoflow-tester.md` at the frozen tree, below its frontmatter)

Pinned to commit `42ab6f2c6eac8e3a4da4aab24af47791cd812ddc` — the RED
stage-1 fixture-authoring commit, which is HEAD for the whole pilot (Feature
§2 *Branch ordering and the one-tree condition*). Re-derivable with
`git show 42ab6f2c6eac8e3a4da4aab24af47791cd812ddc:.claude/agents/autoflow-tester.md`.
At that commit the file is byte-identical to the copy at the time this
document was written, so the block below is quoted from the working tree.

```
You are an AutoFlow **testing** agent (Test AI). Your contract is
`docs/teammate-contracts.md` > Test AI and `docs/autoflow-guide.md` > RED and VERIFY.

Hard rules:
- Write tests from the acceptance criteria only — independent of the
  developer's implementation intent.
- Modify test files only; implementation code is read-only to you.
- Confirm Red (all new tests fail) before reporting RED complete; confirm
  Green on re-runs. Run jest with `--silent --reporters=summary`.
- Perform the VERIFY minimal-implementation check on the implementation diff:
  all covered → PASS; uncovered code → ask the Developer AI to remove it or add
  a test; infrastructure / config / non-testable code → exception, with the
  reason stated. This duty holds however this spawn was created.
- Before that check's mock-boundary counterpart,
  **re-enumerate the iteration set from the test tree at HEAD** — every test double
  in scope and the real interface each stands for — and state it in the report; the
  set is derived from the tree, never carried from memory or from a prior artifact.
- Perform the VERIFY mock-boundary fidelity check over that set: re-derive each
  real interface at HEAD (signature, argument count, return shape, error path),
  confirm the double matches, and cite the real implementation's `file:line` in
  the report; a diverging double is a masked failure, not a Green. This duty
  holds however this spawn was created.
- Report with an Evidence anchor (test summary line) per
  `docs/submodule-common-rules.md` > Reporting Format.
- **[MUST]** Run every Bash command in the **foreground**; never `run_in_background`
  (test/build runs included). Wait for the result, then report — background +
  completion-notification is orchestrator-only. See
  `docs/teammate-common-rules.md` > Bash Execution Mode.
```

This block is asserted verbatim by `tests/test-issue-74-c7-pilot.sh`'s
`arm-substrate-parity` arm against `git show <tree>:.claude/agents/autoflow-tester.md`,
where `<tree>` is `tests/fixtures/c7-pilot-arms.json`'s frozen `tree` field —
not against a moving HEAD (Verification design > `arm-substrate-parity`).

## 4. Spawn/shutdown order — the `named` arm

Per Feature §7 *team-size headroom*: the three `named` replicates
(`test-c7-baseline-r1..r3`) were spawned and shut down **one at a time** — at
most one pilot teammate existed at any moment, so the arm added one team
occupant, not three. Each replicate's shutdown touched no tracked file, so
`HEAD` stayed unmoved for the whole pilot and the one-tree condition held
across all six spawns (three `named`, three `direct`).

Order executed: `test-c7-baseline-r1` (spawn → run → shutdown) →
`test-c7-baseline-r2` (spawn → run → shutdown) → `test-c7-baseline-r3`
(spawn → run → shutdown) → `direct` r1, r2, r3 (each a single-shot spawn,
no shutdown step — a direct spawn is reaped at its final response).

## 5. Capture protocol

Each spawn wrote its own `.autoflow/issue-74-pilot-<arm>-r<n>.json`
(spawn-owned fields: `outcomes`, `iteration_set`, `observed_head` — the three
things only the arm knows, per Feature §4 *Per-spawn record*). The
orchestrator then stamped `arm`, `replicate`, `delivery`, `latency_seconds`,
`turns` around each call — its own observation of the call, not a claim it
relayed — and froze the union into `tests/fixtures/c7-pilot-arms.json`.

## 6. Verbatim-copy step — provenance of the frozen union

Per Feature §4 *Frozen comparison input*, each `tests/fixtures/c7-pilot-arms.json`
`records[]` entry's `outcomes`, `iteration_set` and `observed_head` were
copied **verbatim** from that spawn's own
`.autoflow/issue-74-pilot-<arm>-r<n>.json` (six source files:
`issue-74-pilot-named-r1.json` … `issue-74-pilot-direct-r3.json`); only
`arm`, `replicate`, `delivery`, `latency_seconds`, `turns` were added at
freeze time, by the orchestrator, from its own knowledge of the call. In
particular `observed_head` — the one field the orchestrator could have
supplied from its own `git rev-parse HEAD` instead of copying — was copied
from each spawn's own record, so that the one-tree witness (`observed_head`
equal to the frozen `tree`) is a claim about what the arm saw, not a restated
orchestrator assertion. No automated check can bind the two once the scratch
records are archived at the next PREFLIGHT; this line is the recorded human
procedure per Feature §4.

## 7. Required departures (carried into ADR-0021, not asserted away here)

1. **C7's literal form.** This pilot substitutes a seeded fixture probe for
   "one migrated cycle" (C7's literal wording) — a real cycle diff with no
   planted defect would leave both arms reporting `clean` on everything and
   separate nothing (Feature §2 *Non-discriminating probe*).
2. **External validity of the substrate.** The probe is a fixture on the
   repository's shell medium, not the live change surface of a cycle; an
   arm's competence on a fixture is evidence about the fixture.
3. **Residual prompt-position asymmetry.** The duty text is byte-identical
   across arms, but the `direct` arm receives it as a loaded agent
   definition (system-prompt position) while the `named` arm receives it as
   prompt text (user-prompt position) — a property of the channel itself,
   not a controlled variable.

## 8. C8 — cost / latency (recorded, not compared)

Wall-clock and turn count per replicate are in `tests/fixtures/c7-pilot-arms.json`
(`latency_seconds`, `turns`). Token cost is not recorded: no tool surface
exposes per-spawn token usage (ADR-0017 `:167-169`). The structural fact that
the `named` channel requires an extra mailbox turn the `direct` channel does
not is readable directly from the `delivery` field (`sendmessage` vs
`direct-return`) and the `turns` field (`1` vs `0`) in the frozen records.
