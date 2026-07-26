# AutoFlow declarative step contract — draft

Status: **draft**. Hand-written declarations, validated descriptively against the
issue #35 canary cycle (see [`validation-issue-35.md`](validation-issue-35.md)).
No engine, no runner exists; the runner **design** lives in
[`runner-architecture.md`](runner-architecture.md).

## Layers

| Layer | Holds | Who changes it |
| --- | --- | --- |
| **Declaration** (`steps/`, `roles/`) | step requires/produces, role mission + I/O, loop convergence condition | nobody — portable |
| **Criteria** (`criteria/`) | what to evaluate, what counts as passing | the domain |
| **Binding** (`bindings/`) | model name, effort, endpoint, cap values | the operator |

Lower layers **overlay** the top one: they fill in what the declaration
deliberately omits; they never contradict it.

## Conventions (not a schema)

The fields used in `steps/` and `roles/` are conventions. A field a step does
not need is omitted. Reserved `next` targets: `end` (hand off — the flow's
authority stops here), `escalate` (human decision), `close` (terminate with an
issue disposition). Values of `next` keys are step ids.

A binding may extend a step's `produces` with repo-local derived artifacts
(manifest regeneration, guard registration); the declared `produces` list is
the portable minimum, not an exhaustive inventory (finding F1 of the #35
validation).

## Portable invariants

These are the design decisions of `docs/design-rationale.md` restated as
runner-independent obligations. Any runner claiming to execute this contract
enforces all of them.

1. **Isolation is the input list** — a role receives exactly its declared
   `input`, nothing else. (D1: the structure analyzer never sees the issue.)
2. **Evaluator sessions are fresh** — never reused, no prior history. (D2)
3. **Gate verdicts are computed** — the runner derives pass/fail from raw
   scores; an agent's own pass claim is never read. (D3)
4. **Steps are stateless** — a step consumes only its declared `requires`;
   past evaluation results are never injected. (D4)
5. **Transitions are completion-condition based** — no pre-execution
   difficulty judgment; no step is skipped for perceived simplicity. (D5)
6. **Every loop is bounded** — the declaration names the convergence
   condition (`until` / retry edge); a cap **must exist**, but its value is
   operator overlay in the binding. (D7)
7. **Deliberation is isolated** — round-by-round cross-talk never reaches the
   coordinator or any later step; only converged artifacts and a structured
   verdict cross the boundary, and only accepted content carries between
   rounds. (D8)
8. **Settled decisions are append-only** — recorded with grounds and
   authority; re-opening requires a new verified fact. (D8 ledger)
9. **The flow ends by handing off** — it never merges, closes a PR, or
   deploys. (HANDOFF scope)
10. **Criteria are repo/org-scoped** — never selected per issue; and they live
    outside the declaration entirely. (settled — handoff §4)

## Tree

```
spec/
├── steps/        16 step declarations — requires / loop / produces / next
├── roles/        mission + I/O contract per role
├── criteria/     deliberately empty — decided when a second domain exists
└── bindings/     claude.yaml — the only layer that knows the vendor
```
