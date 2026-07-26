# Runner architecture — harness-independent execution of the step contract

Status: **design only** (approved scope: architecture, no implementation). The
declaration layer is the contract; this document describes the program that
would execute it without Claude Code as the harness. Where a number is quoted,
it is marked *measured* or *modeled* per the handoff's working agreement.

## Position

Six of the sixteen steps are mechanical (`kind: mechanical` — preflight,
dispatch, validate, deliver, integrate, handoff routing): git state, task
fan-out, automated checks, push, build, PR creation. Today an LLM orchestrator
routes all sixteen, and that tier is 28.8% of cycle cost with context growing
linearly per turn regardless of issue difficulty (*measured*, canary #35 —
704–722 tokens/turn over n=2 cycles). Moving routing into a program removes
that tier's growth entirely; the saving is *modeled*, not measured, but the
direction subsumes the block-separation idea (whose modeled ceiling was ~10% of
cycle cost) because the orchestrator tier ceases to exist rather than being
split.

The LLM keeps the work only an LLM can do: the declared `agents` of each step —
analysis, deliberation, implementation, testing, evaluation, ingestion.

## Components

| Component | Responsibility | Invariants it enforces |
| --- | --- | --- |
| **Flow engine** | reads `spec/steps/`, executes `kind: mechanical` steps directly, drives `next` routing on completion conditions | 4 (requires-only inputs), 5 (completion-condition transitions), 6 (bounded loops, caps from the binding) |
| **Gate calculator** | computes each gate verdict from the evaluator's raw `scores` against the criteria layer's thresholds | 3 (an agent's pass claim is never read) |
| **Session manager** | creates per-role LLM sessions; assembles each session's context from the role's declared `input` and nothing else; evaluator sessions are always new | 1 (isolation is the input list), 2 (fresh evaluators) |
| **Provider adapter** | realizes a session against the binding's `provider` — `claude` (API), `openai`-compatible (covers vLLM), or `claude-code` (delegation, see migration M1) | — (pure substitution; the layers above it never know the vendor) |
| **Artifact store** | persists every step's `produces` (including the mechanical steps' — closing finding F3) and the append-only decision ledger | 8 (append-only, re-open only on a new verified fact) |
| **Side-effect layer** | git/gh operations, executed **check-then-act**: before creating a branch/commit/PR/comment, observe whether it already exists and skip or reconcile | resumability (handoff open question 4) |

## How the invariants move

The current runner enforces the invariants with hooks and conventions *because
the router is itself an LLM* that must be structurally restrained. In a program
runner, several enforcement mechanisms simplify or dissolve — the invariants do
not:

- **Gate hook → gate calculator.** `check-autoflow-gate.sh` exists to stop an
  LLM orchestrator from advancing on its own judgment. A program router cannot
  "decide" to skip a gate; the calculator is the same trust-chain principle
  (Decision 3) as an auditable module instead of a defensive hook.
- **Deliberation isolation (Decision 8) splits into two halves.** The
  contamination half — an LLM coordinator oscillating because cross-talk
  accumulates in its context — dissolves: a program has no context to
  contaminate. The **artifact half remains fully binding**: round-by-round
  cross-talk is never persisted into any later step's input; only converged
  artifacts and the structured verdict cross (`carry: accepted_only`). The
  engine drives the deliberation loop itself — two provider sessions exchanging
  under `until: mutual_accept` with the binding's round cap — so the Claude
  Code `Workflow` mechanism is no longer load-bearing, and handoff open
  question 3 (does a background Workflow survive headless execution?) becomes
  moot rather than answered.
- **Role declaration → session assembly.** The spawn-role hook exists because
  an LLM orchestrator could mislabel a spawn. The session manager builds
  sessions *from* the declaration, so the role is structural by construction.
- **Resume → first-class.** The current Resume procedure reconstructs state
  from the state file and branch conventions after an abnormal end. The engine
  persists step state at every transition, so resumption is the normal path —
  with the side-effect layer's check-then-act guaranteeing that a replayed
  step does not duplicate a commit, PR, or comment (interactive runs caught
  duplicates because a human was watching; headless runs must not need one).

## Provider adapter contract (deliberately thin)

A binding resolves each role to `{provider, model, ...}`. The adapter needs
only: create a session with an assembled context, exchange messages, and
return output that satisfies the role's `output.must_contain`. Structured
output (for evaluator scores) uses the provider's native mechanism where one
exists and section-parsing as fallback. Nothing more is specified now —
prompt wording, context-window strategy, token budgets, and parallelism are
operator-side (handoff §4), and freezing an adapter interface before a second
provider exists would repeat the premature-schema failure mode.

## What is deliberately not designed

- The criteria layer's file format and judgment rule (`spec/criteria/`).
- Rubric calibration transfer between models. The migration plan below makes
  this concrete: when a non-Claude binding first runs, its gate verdicts are
  **not trusted at inherited thresholds** — a permissive-direction calibration
  error passes bad work undetected. The mechanism is unchosen; M3 marks the
  point where the operator must choose one.
- Prompt bodies, token budgets, parallelism, round-count values.

## Migration path

Each stage is independently stoppable; none modifies the methodology's rules
(improvements to the methodology itself stay upstream-first).

- **M0 (this branch)** — declaration files + #35 validation + this design.
  No code.
- **M1 — hybrid.** The engine executes the six mechanical steps and the
  routing; every `agents` step is delegated to the current Claude Code runner
  as a subprocess (the `claude-code` provider). Proves the flow engine, gate
  calculator, artifact store, and side-effect idempotency against live cycles
  while the LLM-facing behavior stays exactly today's.
- **M2 — direct sessions.** The session manager + provider adapter take over
  the `agents` steps via the `claude` API binding. Claude Code ceases to be
  the harness; Claude remains the model. Isolation, fresh evaluators, and
  deliberation looping are now engine-enforced and testable.
- **M3 — second binding.** An `openai`-compatible binding (vLLM) runs the same
  declaration. This is the swap the layer split exists for — and the point
  where the calibration question stops being theoretical. Gate thresholds are
  operator-confirmed per model before verdicts are trusted.

## Risks carried forward

- The n=2 evidence base: "orchestrator slope is constant" is a strong
  hypothesis, not a fact; the cost argument for M1+ inherits that caveat.
- F2 (regression edges unvalidated): the engine's routing table for fail paths
  is implemented from declarations that no cycle has yet exercised; M1 should
  deliberately include a regressing cycle before M2.
- Deliberation quality under non-Claude models is unknown; `until:
  mutual_accept` assumes participants that can produce grounded ACCEPTs and
  counters. M3 may surface convergence failure as the real limit — which the
  bounded loop turns into an `escalate`, not a hang (invariant 6).
