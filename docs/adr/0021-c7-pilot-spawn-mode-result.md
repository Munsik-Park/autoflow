# ADR-0021: C7 pilot result — the anonymous direct spawn matches the named-spawn baseline

## Status

Proposed

## Context

ADR-0017 (`docs/adr/0017-teammate-removal-feasibility.md`) is Accepted with condition **C7**
blocking (`:87`): "one migrated cycle runs the Test AI as an anonymous direct spawn, and its step-3
and step-4 detection outcomes are compared against the named-spawn baseline". **C8** (`:88`) asks
for cost and latency on the same pilot cycle. Both are answered here, in the migration slice
ADR-0017 `:188-190` reserved them for.

C7's phrase "the named-spawn baseline" had no referent. The issue's literal target — the per-cycle
digest record `docs/` once carried, retired by issue #71 — is absent at HEAD, and its last content
before that removal carried a fixed per-cycle schema of gate scores, regression counters, architect rounds, loop-check class and review
severity — no field recording whether VERIFY step 3 or step 4 *detected* anything. That absence is
the gap ADR-0017 `:86` (C6) itself records. The baseline was therefore **produced in-cycle rather
than retrieved**: both arms — named team spawn and anonymous direct spawn — ran over the identical
probe input, in the same cycle, at the same model, against a single frozen tree. A concurrently
measured baseline controls the probe, the model and the prompt, which a historical record could not.

## Decision

**The pilot's verdict is `EQUAL_OR_BETTER`. The spawn-mode migration ADR-0017 conditionally approved
proceeds**, and this cycle carries its edit set.

### Probe design and ground truth

Running the pilot against a real cycle diff is not admissible as the measurement: a diff with no
uncovered hunk and no diverging double leaves both arms reporting `clean` on both steps, and the
comparison separates nothing — the same non-discriminating shape ADR-0017 `:181-183` rejected in its
own corroboration alternative. The probe is therefore a **seeded fixture** with planted ground truth,
`tests/fixtures/c7-pilot/`, carrying both a planted condition and a clean control per step so that an
arm answering `detected` to everything scores no better than one answering `clean` to everything. Its
expected answers live outside the handed tree, in the sibling `tests/fixtures/c7-pilot-ground-truth.md`.

| Condition | Ground truth |
| --- | --- |
| `step3-planted` — a `probe-cli` branch whose sentinel token appears on no `probe_assert` line | step 3 must answer `detected` |
| `step3-clean` — a second branch whose sentinel token is asserted on | step 3 must answer `clean` |
| `step4-planted` — a mock shim diverging from its real interface in exactly one dimension (the error-path / exit-status contract), argv shape held matching | step 4 must answer `detected` |
| `step4-clean` — a second shim matching its real interface in all four dimensions | step 4 must answer `clean` |

The substrate is the repository's own medium — extensionless shell shims over committed real
interfaces, and a `git diff`-form patch — not JavaScript: the tree carries no `package.json`, no jest
configuration and no `*.test.js`, and its established test double is `tests/issue-25/mock-gh/gh`.
"Covered" is made mechanically decidable by fixture content rather than by inspection: each branch
emits a sentinel token unique in the fixture tree, `probe-suite` defines exactly one assertion helper
`probe_assert`, and a branch counts as covered when its sentinel appears as an argument on a line
invoking that helper. Invoking a branch and asserting on it are distinct, and step 3 is about the
second.

The step-4 plant is deliberately one-dimensional. `.claude/agents/autoflow-tester.md:23-27` obliges
the arm to re-derive four things — signature, argument count, return shape, error path. A double
diverging in two of them is caught by re-deriving either, so it would measure whether the arm ran any
check at all rather than the enumerated re-derivation, and would drive both arms' detection to the
ceiling where a tie still passes the validity precondition. The error path is the planted dimension
because argv divergence is loud in this substrate (`tests/issue-25/mock-gh/gh:39,49` dispatches on
argv) while an exit-status divergence is silent yet contract-bearing (`:45-46`, `:74-75`) — argv
parity is a positive property of the planted double, so no arm can reach `detected` off a dispatch
failure instead of off the check.

### Arms, and what was held equal

The two arms differ in exactly one variable, the spawn channel: `named` =
`{ team_name, name: "test-c7-baseline-r<n>", model: "sonnet" }`, exercising the teammate name-prefix
declaration; `direct` = `{ subagent_type: "autoflow-tester", model: "sonnet" }`, exercising the
`subagent_type` declaration. `R = 3` replicates per arm. Model, prompt text, fixture path and
replicate index were held fixed; no commit, amend or tracked-file edit occurred between the first
spawn and the last return, and all six spawn-written `observed_head` values equal the single frozen
`tree` — `42ab6f2c6eac8e3a4da4aab24af47791cd812ddc`. The frozen union is
`tests/fixtures/c7-pilot-arms.json`; the cycle-scoped suite `tests/test-issue-74-c7-pilot.sh` —
retired with its cycle at PR #147 per its `retire-with: #74` header, retrievable as
`git show 7a7f98a^:tests/test-issue-74-c7-pilot.sh` — re-derived the verdict from it.

Duty-text parity was a hard requirement, because the channels do not carry the duties equally. The
`direct` arm receives the step-3, iteration-set and step-4 duties through the agent definition its
`subagent_type` loads; the `named` arm has no definition, and
`.claude/hooks/check-autoflow-gate.sh` resolved a spawn carrying a `name` by that prefix alone. The
`named` arm's prompt therefore carried the body of `.claude/agents/autoflow-tester.md` verbatim, as
it stood at the frozen tree, in addition to the shared prompt block appended byte-identically to both
arms. The two prompts are consequently **not** whole-string identical, and were not made so: appending
the definition to the `direct` arm as well would hand that arm its duties twice, which is a second
uncontrolled difference rather than the removal of one.

The prompt named the fixture path, the two checks to perform, the re-enumeration obligation and the
record path. It did not name the planted conditions, state how many existed, or hint that any did.

### Rates, the `discriminating` margin, and the verdict

Over `R = 3` replicates per arm, where `detect_rate(a, s)` is the fraction of replicates answering
`detected` on `step<s>_planted` and `fp_rate(a, s)` the fraction answering `detected` on
`step<s>_clean`:

| Arm | `detect_rate` step 3 | `fp_rate` step 3 | `detect_rate` step 4 | `fp_rate` step 4 |
| --- | --- | --- | --- | --- |
| `named` (baseline) | 1 | 0 | 1 | 0 |
| `direct` | 1 | 0 | 1 | 0 |

The validity precondition is a **margin**, not a detection floor:
`discriminating(s) = detect_rate(named, s) − fp_rate(named, s) > 0`. Both hold — `1 − 0 > 0` at step 3
and at step 4 — so the baseline separated the planted condition from its control and the comparison
measures something. The margin form is load-bearing: a floor alone would admit a baseline answering
`detected` to everything (detect_rate 1, fp_rate 1), against which a `direct` arm doing likewise
would satisfy both comparison inequalities and yield a confident migration verdict off pure noise.

With `discriminating` satisfied at both steps and `detect_rate(direct, s) ≥ detect_rate(named, s)`
and `fp_rate(direct, s) ≤ fp_rate(named, s)` at both steps, the predicate returns **`EQUAL_OR_BETTER`**.

One recording note, carried so the rates are read as computed: the three `named` records carry no
`step3_clean` subject — each read the diff as introducing only the planted branch and did not evaluate
the covered branch as a diff subject. An absent subject scores `not-run`, which counts as a
non-false-positive. That is conservative in the direction favouring neither arm: it lowers no `named`
rate and raises no `direct` rate.

### C8 — cost and latency

| Arm | Latency (s), per replicate | Delivery turns | Delivery path |
| --- | --- | --- | --- |
| `named` | 54 / 51 / 72 | 1 each | `sendmessage` (no losses, no re-requests) |
| `direct` | 79 / 69 / 74 | 0 each | `direct-return` |

Latency is spawn-to-record-write wall clock, measured by a uniform method including queueing, and is
the orchestrator's own observation of each call. On this sample the direct channel was not faster;
the difference is within the spread of three unreplicated draws and no direction is asserted from it.
The structural fact the turn column reports is not a sample estimate: the named channel requires one
mailbox turn the direct channel does not, readable from the delivery-path table rather than inferred.

**Token cost was not measured on the pilot arms, and is not estimated here.** No tool surface exposes
per-spawn token usage, so there is nothing to record; ADR-0017 `:167-169` already refuses to assert a
direction it cannot measure, and this record holds that line rather than substituting a plausible
number. C8 is answered with wall-clock, turn count and the structural extra-turn statement, and its
token half stays open at the arm granularity.

**Session-transcript aggregation of this cycle's named teammates (recorded 2026-08-24, C8 method over
the session JSONL — `message.usage` per assistant message, de-duplicated by `message.id`, re-write =
a non-first turn with `cache_creation ≥ 0.9 × (cache_read + cache_creation)`).** This cycle began
before the migration and ran its RED/GREEN/VERIFY teammates in the named mode, so its transcripts are
a **pre-migration baseline**, not a measurement of the migrated default:

| Agent | Turns | Re-write turns (excl. first) | Peak context |
|---|---|---|---|
| test-74 (sonnet, named) | 234 | 7 | 486K |
| dev-74 (opus, named) | 122 | 4 | 225K |
| orchestrator | — | 11 idle-notification "no action" answer turns (11 notifications) | — |

These values sit inside the pattern ADR-0017 > Notes > C8 measured on #122/#130 (peaks 293–515K),
corroborating the cost case for the migration. The after-side measurement — the same aggregation on
the first cycle run under the migrated default — is issue #146, split out of this issue's acceptance
criteria by operator decision (2026-08-24): the 150K figure that entered with #136 is an AI-proposed
projection, not an operator threshold, so the confirmation is a before/after contrast judged by the
operator, not a fixed-cutoff gate.

### Three departures from what C7 literally asked

Stated as decision contents, so a later reader — the owner deciding ADR-0017's Status included — does
not read this record as reporting something it did not measure.

1. **C7's literal form was substituted.** C7 asks for "one migrated cycle" whose own step-3/step-4
   outcomes are compared. This pilot substitutes a **seeded probe** on a fixture, for the reason
   above: a real cycle diff carrying no planted defect leaves both arms reporting `clean` and
   separates nothing, so the literal form would have produced a verdict from a measurement that could
   not discriminate.
2. **The fixture substrate limits external validity.** The probe is a fixture on the repository's
   shell medium, not the live change surface of a cycle. It is the closest available substrate — the
   repository's real doubles *are* extensionless shell shims over command interfaces — but an arm's
   competence on a fixture is evidence about the fixture. The rates above are not unconditional
   claims about arm behaviour on arbitrary real diffs.
3. **A residual prompt-position asymmetry between the arms is channel-intrinsic and remains.** Duty
   text was held byte-identical, but the `direct` arm received it as an agent definition attached by
   `subagent_type` while the `named` arm received it as prompt text — a difference the channel itself
   imposes, not one the pilot chose. Any residual effect of that position is inseparable from the
   channel effect being measured, so the comparison is **not** position-controlled.

### What this record does not do

This record does not rewrite ADR-0017's body and does not change its Status. ADR-0017 `:96-98` and
`:215-217` reserve correction to a later superseding ADR, and its `## Notes` reserves the Status
transition to the owner. The verdict here **confirms** ADR-0017's conditional go rather than reversing
it, so **no supersession is proposed**: ADR-0017 stands as Accepted, with C7 and C8 now discharged by
this record. Had the verdict been `INFERIOR`, this ADR would instead have recorded the reversal and
proposed supersession, leaving the `Accepted → Superseded` transition to the owner.

## Alternatives Considered

- **Compare against a historical named-spawn baseline.** Rejected: no such record exists. The field
  C7 needs was never in the per-cycle digest record `docs/` once carried — retired by issue #71 and
  absent at HEAD — and the external archive holds no key for this repository (ADR-0017 `:185`).
- **Run the pilot on this cycle's real VERIFY input.** Rejected as non-discriminating (above).
- **Plant the step-4 divergence in two or more contract dimensions.** Rejected: it measures whether
  any check ran rather than whether the enumerated re-derivation ran, and saturates both arms'
  detection where a tie at the ceiling still passes the validity precondition.
- **Record the pilot by rewriting ADR-0017.** Rejected: ADR-0017's own text reserves correction to a
  later ADR and the Status transition to the owner.
- **Estimate token cost from turn counts.** Rejected: it would assert a direction no instrument
  measured, which is the failure ADR-0017 `:167-169` names.

## Consequences

### Positive

- C7 and C8 are discharged with a re-derivable record: the frozen union stays in the tree, and the
  retired verdict suite (`git show 7a7f98a^:tests/test-issue-74-c7-pilot.sh`, retired at PR #147)
  let a later reader recompute the verdict rather than trust this prose — the recomputation needs
  only `tests/fixtures/c7-pilot-arms.json` and the predicate stated in this record.
- The baseline is stronger than the one C7 described — concurrently measured, with probe, model and
  prompt controlled.
- The migration proceeds with the hook's role-prefix branch removed jointly with it (ADR-0017 Q3),
  so no unreachable branch retains a live precedence rule over `subagent_type`.

### Negative

- The verdict rests on a fixture, not on live cycle behaviour (departure 2), and on three replicates
  per arm.
- Both arms saturated at `detect_rate` 1 / `fp_rate` 0, so the pilot establishes that the direct
  channel is not worse on this probe; it does not rank the channels.
- The token half of C8 remains unanswered until a per-spawn usage surface exists.

### Neutral / Trade-Offs

- `R = 3` fixes the admissible margin floor at `1/3 − 0`. Changing `R` reshapes that floor, so it is
  a visible edit to the fixture, the disclosed floor and the predicate's edge arm together, never a
  tuning choice.
- The pilot's own `named` arm was the last use of the teammate channel for the Test AI; the arms are
  not reproducible in place after the migration edit set lands, which is why the union is frozen under
  `tests/fixtures/` rather than left in gitignored scratch.

## Related Issues / PRs

- Issue #74 — the migration slice this record is produced in.
- ADR-0017 (`docs/adr/0017-teammate-removal-feasibility.md`) — the conditional decision whose C7 and
  C8 this record discharges.
- Issue #40 — the cycle whose report-loss measurement motivates the migration; its record is retained
  in `docs/teammate-common-rules.md` per ADR-0017 Q5.
- ADR-0003 (`docs/adr/0003-autoflow-ends-at-handoff.md`) — untouched; nothing here moves the
  termination boundary.

## Notes

- Status: `Proposed`. The `Proposed` to `Accepted` transition is the owner's decision, per
  `docs/adr/README.md` > Status Values.
- The frozen union's `records[]` entries carry `outcomes`, `iteration_set` and `observed_head`
  verbatim from each spawn's scratch record; `arm`, `replicate`, `delivery`, `latency_seconds` and
  `turns` are orchestrator-stamped. An arm never self-labels the pilot's only independent variable.
  The copy step is recorded in the cycle's manual-scenario document — retired with the cycle at
  PR #147, retrievable as `git show 7a7f98a^:tests/manual/issue-74-manual-scenarios.md` (an archived
  copy also lives in the cycle's external archive).
