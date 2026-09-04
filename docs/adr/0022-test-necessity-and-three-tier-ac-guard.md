# ADR-0022: A test exists only when it is needed; acceptance-criterion reductions pass through three tiers

## Status

Accepted; the Reconcile tier-3 trigger superseded by issue #166 (see Superseding note)

## Context

AutoFlow's premise was that everything verifiable gets a test. RED converts every `automated` row,
the untestable-items bullet offers manual delegation or a mock for the rest, and VERIFY step 3 asked
whether any part of the implementation diff was uncovered — a coverage question, whose only
answer-shaped remedy is another test. Nothing in the flow asked whether a given test was worth its
cost, and the one clause that bounded depth (ADR-0018, *Verification depth*) bounded **layers**, not
individual tests, and compared each layer only against other test layers.

Two costs followed.

**The unneeded test is paid for three times.** A prior cycle authored an equality assertion over a
sample file — a check that the shipped sample's literal values matched a table in the spec. The
subject was user-editable: at the target's first edit the assertion's subject is gone, so the test
protects nothing after delivery. Its cost was paid at authoring, again at every verification run
during the cycle, and again in maintenance; its absence would have cost nothing at any point,
because no consumer requires the sample to hold any particular literal — the behavior that reads the
sample is what a consumer requires, and that behavior had its own coverage. The cycle produced the
test because the flow's default was *test it*, not because anyone answered a question about it.

**Every reduction reached the operator.** ADR-0020 made changing an issue's acceptance criteria the
operator's authority and stopped the run on five finding kinds — `dropped`, `not-carried`,
`deferred`, `weakened`, `substituted`. Three of those five (`not-carried`, `deferred`, `weakened`)
are statements about *how* a criterion is verified, not about *what* the criterion says. They paused
the run for a human on a verification-method choice, and a pause that fires on ordinary
verification-design judgment trains the operator to click it through — which costs the pause its
value on the two findings that genuinely need a human.

## Decision

**A test exists only when it is needed, and the burden of proof lies on the test. Reductions in
verification method pass through three tiers, of which the operator is only the third.**

1. **Necessity is a judgment with two inputs**, answered in the verification-design row that carries
   the proposed verification: **required behavior** (is this a behavior or contract a consumer
   actually requires, as opposed to an imagined failure mode?) and **cost of absence** (if no
   verification exists and this breaks after merge, who loses what, concretely?). A proposed
   verification that cannot answer both is not written. Not writing a test needs no justification.
   Under uncertainty the disposition is `none` — the asymmetry recorded in Context is the reason:
   the unneeded test's cost is real and recurring, the missing test's cost on such subjects was nil.

2. **The per-criterion disposition vocabulary is closed**: `automated`, `existing-coverage`,
   `delivery-check`, `manual`, `environment-dependent`, `none`. Every disposition other than
   `automated` on an **issue** AC row carries a one-line reason; a design-added criterion owes none.
   `existing-coverage` makes a non-test mechanism a valid answer to "what catches this" — a lint
   rule, schema, compiler or type check, build or packaging check — which also widens ADR-0018's
   per-layer comparison beyond other test layers.

3. **Automated rows carry a test kind** — `driving`, `regression`, `characterization` — which is
   also RED's expectation: `driving` and `regression` must fail before the fix; a
   `characterization` test records existing behavior and may pass from the start, so a green
   characterization test is no longer an investigation trigger.

4. **Three-tier guard on acceptance criteria**, replacing "any AC touch pauses for the operator":
   (i) the **deliberation** may choose a reduced disposition for an issue AC, with its reason stated
   in the row — weak reasons end here; (ii) the **external reviewer** sees every reduced disposition
   and its reason in the host PR body (`## Verification dispositions`) and judges each one —
   doubtful judgments end here; (iii) the **operator** is asked only when the AC's **content** must
   change: excluded, revised, or split.

5. **The Reconcile finding set narrows to three kinds**: `dropped` (no row carries the id),
   `unreasoned` (a row carries it with a non-`automated` disposition and states no reason), and
   `substituted` (the row asserts a different property than the issue's — *retired by issue #160;
   see Notes > Amendment*). The comparison channel
   still transcribes and never judges — it reports whether a reason is *stated*, never whether it is
   *good*, since judging a reason is exactly the faculty ADR-0020 refused to hand it. Reason
   **quality** is scored where a rubric already exists: GATE:PLAN's `Scope` verification-depth items,
   adding no scored item and changing no threshold.

6. **VERIFY step 3 becomes a scope check**, keeping its name. It asks whether the implementation
   introduces observable behavior or contract outside the agreed scope, not whether every diff hunk
   is covered. Out-of-scope behavior is removed, or — if required — raised as a scope question; it is
   never absorbed by silently adding a test. A helper, private branch or internal abstraction whose
   required behavior is protected at a higher level owes no direct test of its own.

## Alternatives Considered

- **Keep the coverage form of VERIFY step 3 and add a necessity clause at ARCHITECT only.** Refused.
  The two would contradict each other inside one cycle: ARCHITECT declines a test on necessity
  grounds and step 3 then reports the same code as an uncovered hunk, whose remedy is that test. The
  necessity policy is only stable if the post-implementation check asks about scope rather than
  coverage.
- **Make configuration/data and implementation internals exempt categories.** Refused. Necessity is
  a judgment, and a category exemption converts it back into a classification — "production config
  boots the app" and "every reference resolves" are data-subject checks that can be entirely worth
  their cost. The two areas are recorded as guidance notes: the same two judgments applied where they
  are most often answered wrong.
- **Keep all five ADR-0020 finding kinds and let the operator confirm reasoned reductions quickly.**
  Refused. A pause is not cheap in proportion to how fast it can be dismissed: a pause that fires on
  ordinary judgment is dismissed by habit, and the habit carries over to the pauses that matter.
- **Let the comparison channel judge whether a stated reason is good.** Refused, on ADR-0020's own
  ground — that judgment is capturable by a well-written rationale, which is why it belongs to the
  external reviewer (who sees the change) and to a scoring rubric, not to a transcription channel.
- **Carry reduced dispositions to the reviewer through the linked issue rather than the PR body.**
  Refused. `docs/pr-body-guide.md` > Principle 4 already requires the reviewer's judgment basis to be
  PR-reachable; a tier that depends on the reviewer finding the artifact is a tier that may not run.

## Consequences

### Positive

- The default flips: a test is written because someone answered why it must exist, not because the
  subject was verifiable. The recurring cost of unneeded tests stops being incurred silently.
- Reductions become visible to the party best placed to judge them — a reviewer reading the change —
  instead of stopping the run for a human who must reconstruct the design's context to answer.
- `existing-coverage` gives the verification design a way to name a lint, schema or build check as
  the thing that catches a failure mode, which it previously had to either duplicate as a test or
  leave unstated.

### Negative

- `none` under uncertainty will sometimes be the wrong call, and the miss surfaces after merge. The
  tiers bound it rather than eliminate it: the reviewer sees every `none` with its reason, so a
  wrong one is catchable before hand-off, and the recorded reason makes the miss diagnosable
  afterward.
- The operator loses sight of reductions they previously saw at the pause. That is the intent, and
  it is a real transfer of attention from the operator to the reviewer; it is safe only because the
  reviewer tier is mandatory and its input is in the PR body.
- One finding kind is retired that had no replacement elsewhere: `deferred`. A criterion postponed
  out of the cycle with a stated reason now leaves the deliberation without an operator decision.
  Tier 2 is where a postponement that should have been an issue split is expected to be caught.

### Neutral / Trade-Offs

- **Effective from** — the obligations bind verification designs authored after the clause lands,
  the same convention the composition-oracle, verification-depth and AC-authority clauses use. A
  cycle already past ARCHITECT is not retroactively deficient.
- The disposition and kind vocabularies live in exactly one place
  (`docs/autoflow-guide.md` > ARCHITECT > Output artifacts > *Test necessity*); every other document,
  agent definition and workflow prompt references it.

## Related Issues / PRs

- Issue #153 — this decision and its implementation.
- Issue #160 — amends item 5: retires the `substituted` kind (Notes > *Amendment (issue #160)*).
- Amends `docs/adr/0020-acceptance-criterion-authority.md`: the operator keeps authority over
  acceptance-criterion **content**; a verification-method reduction with a stated reason is the
  deliberation's, judged by the external reviewer. ADR-0020's halt, fail-closed sentinels,
  `[ac-decision]` grammar, resume and budget accounting are unchanged.
- Builds on `docs/adr/0018-verification-depth-justification.md` (per-layer unique-failure-mode
  justification) by widening "another layer" to non-test mechanisms.

## Notes

- Numbering: 0022 is the next free integer, contiguous after 0021.
- The decision alters agent-workflow gates and evaluation policy — a `docs/adr/README.md` >
  "When to Create an ADR" trigger area — so it lands with the mechanism it governs.
- **Amendment (issue #160)** — the Reconcile finding set is `dropped` / `unreasoned` only.
  `substituted` was the one kind that required reading meaning ("asserts a different property"),
  and item 5's own premise is that the channel never judges: asked of that channel, the reading
  degraded to a wording comparison, which fails both ways — it paused #157 cycle 1 on a legitimate
  split of one criterion into two rows with different verification methods (the AC's content
  unchanged), and it passes a real misreading that keeps the wording. Strengthening the wording
  rule cannot separate the two without judging meaning, which the channel contract forbids. The
  misreading check is assigned to the places that already read an AC's meaning: GATE:PLAN
  `Test plan` (input: the AC table) and GATE:QUALITY's assertion-claim alignment. The verification
  design's criterion cell stays — a row states the proposition its method checks; it is not a copy
  kept for comparison. Everything else in this ADR is unchanged.

## Superseding note (issue #166)
<!-- wording drafted under issue #166; operator confirmation pending -->

Tier 3's automatic trigger — the Reconcile channel's `dropped` and `unreasoned` findings raised
against the converged verification design — is retired with the ARCHITECT deliberation's return to
its original form.

Tiers 1 and 2 are unchanged: the deliberation chooses a verification disposition with its reason
stated in the row, and the external reviewer judges every reduction and its reason from the host PR
body. Tier 3 is reached through the orchestrator's routing of the deliberation report — an agreed
conclusion that changes an acceptance criterion's content goes to the operator before GATE:PLAN —
and through the two gates' AC-authority checks, which are unchanged and scored. The test-necessity
clause, the disposition vocabulary and the reason obligation are unaffected.
