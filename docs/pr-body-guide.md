# PR Body Authoring Guide

A guide to consult when writing a PR body. For the delivery module, the ci module and manual PR authors alike.

## Principles

### 1. Claim accuracy

The behavior / verification / scope of protection a PR promises in its body must match exactly
what it actually implements.

- Use strong expressions (machine-verified, fully enforced, idempotent, atomic, race-free,
  etc.) only when that level is actually met.
- State a partial guarantee as partial — where they can be separated, separate them, as in
  "X is machine-verified, Y is reviewer-attested".

### 2. Exposing rejected alternatives

If there are alternatives that were considered but rejected in the course of deciding the implementation, expose them
in the body with the reason for rejecting them.

- State the reason for rejection precisely: clearly distinguish whether it is an "architectural boundary violation" or a
  "cost trade-off".
- This may not apply to a simple PR (a typo fix, etc.).

### 3. Limitations and known gaps

State the paths this PR does not cover / the remaining risks / the items that need follow-up work.

- In a "What this PR does not cover" section, or as a paragraph in the body text.
- If there is a follow-up issue number, cross-reference it.

### 4. Explicit links to the decision basis (PR-reachability)

A reviewer must be able to start from the PR and reach its decision basis. A document existing in the
repository is not enough — state, in the form `path > section`, which ADR / design note / architecture
context / AC the PR took as its decision basis.

- Link the ADR / design note / architecture context explicitly. When no ADR is needed, one line
  of reason ("ADR not required: ...").
- Make the linked issue's AC reachable from the PR (the issue link + its AC section, or stated in the body).
- Do not link the scratch in the record directory (`<attempt-dir>/*`) as review input; move the grounds the reviewer must see
  into the linked issue, a committed document, or the PR body.

Policy: Repository documents may be used as review evidence only when the PR links or
names the relevant document/section, or when the reviewer independently discovers
directly relevant repo context while tracing the changed surface. Do not rely on
reviewers to infer hidden design intent from unrelated repository documents.

### 5. Verification dispositions (exposing the verification dispositions)

A host PR AutoFlow opened makes its verification dispositions readable — it states every item the verification design
verifies by a method other than an executable test (the applied criteria and the items the feature design brought into
scope), with the verification method and the reason. The words that name a disposition are the design's.

- An operator-led PR (the PR of work the operator carried out outside the AutoFlow modules) is not asked for this content,
  because it has no verification design. Whether its acceptance criteria are met is shown by *6. Acceptance criteria check*.
- This content is the second tier of the three-tier acceptance-criterion guard: the design module decides a reduction of
  the verification method, the review module's reviewer judges whether that reason holds,
  and when a criterion's **content** changes, the module that showed the change spawns the advisor to decide it and follows that decision
  ([`role-contracts.md`](role-contracts.md) > Advisor). The rule text is in [U3 Design](units/design.md) >
  *Test necessity* and *Report routing*.
- The example form is one line of item id + verification method + reason.
- A test run once that does not stay in the target's tree carries, in the same section, that item's **run record** — the command and
  the summary line recorded in the build report — on one line
  ([U6 Delivery](units/delivery.md) > *Push and pull request*).
- An item the AI verified by observing it with a tool carries, in the same section, who ran it, the observation record's path and the result
  on one line. An item verified by a person's observation or a mock carries why in its reason, and if it is because a tool was missing,
  that tool request is written in *7. Tool requests* ([`submodule-common-rules.md`](submodule-common-rules.md) >
  Verification and Tools > *The tools the work needs*; [U3 Design](units/design.md) > *Tools*).
- The **test files the change added** to the target's tree are listed file by file in the same section — the path,
  the reason it is kept, and the CI job that actually ran that file, as the ci module confirmed it (if no job ran it, that
  fact; if the target has no CI, `no CI; local run only`). If no file was added, that fact is written on one line
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *What a change leaves in the target's tree*;
  [U6 Delivery](units/delivery.md) > *CI*, *Added test files*).

Example:

```
## Verification dispositions

- AC2 — existing-coverage: `scripts/test/check-suite-manifest.sh` checks the same property
  on every build.
- AC4 — none: the value is in a sample file the user edits, so the object of verification
  disappears at the first edit. Cost of absence: 0.
- AC1 — one-shot test: `bash <attempt-dir>/build-1/local/ac1-retry.sh` → `PASS 3/3`
- AC3 — AI observation (browser): `<attempt-dir>/build-1/local/ac3-observation.md` →
  match — the rendered list screen checked against the mockup the issue links.
- Added test files: `tests/retry-backoff.test.ts` — the retry interval varies with the setting
  after deployment, so it is a regression subject of the target's; its run confirmed in CI job `unit (ubuntu-latest)`.
```

### 6. Acceptance criteria check

For an operator-led PR and an AutoFlow PR alike, checking the linked issue's acceptance criteria in the PR body
lets the reviewer read at once whether each criterion is met.

- At the head of the section, state which commit the results stand at: "Results as of `<sha>`."
- Write one line per criterion: the criterion number (for an AutoFlow PR, the applied criteria's id),
  whether it is met, the commit it was confirmed at, the evidence location (`path` > section, `path:line`, a run record's summary line, etc.).
- A criterion not met, or only partly met, is written as such, with the reason on the same line. Follow-up handling is
  written in *3. Limitations and known gaps*.
- This section does not replace an AutoFlow PR's *5. Verification dispositions*. The dispositions are the disposition of
  the verification method; this section is whether the criteria are met.
- The items are only suggested. No device checks this form.

Example:

```
## Acceptance criteria check (#42)

Results as of `a1b2c3d`.

- 1 — met · `a1b2c3d` · `src/retry.ts:40-58`, `<attempt-dir>/build-1/local/ac1-retry.log` → `PASS 3/3`
- 2 — met · `9f8e7d6` · `docs/retry.md` > Backoff
- 3 — partly met: only the config-file path applied, the environment-variable path follows in #43 · `a1b2c3d` · `src/config.ts:12`
```

### 7. Tool requests

An AutoFlow PR body states the work's tool requests — each run's `tool-requests.json`
(`tool_requests`) the invocation gives. For each request, one line states what was missing, what was done instead, and what could not be verified because of it,
so that the operator can decide whether to provide the tool and run again, close the PR and provide the tool separately, or merge and add the tool
([U6 Delivery](units/delivery.md) > *Push and pull request*).

---

## Applicability

This guide is a recommendation. Depending on the PR type, some sections may not apply.

When adding a new principle, keep the form (name + body + 1-2 examples).
