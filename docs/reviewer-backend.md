# Reviewer Contract

HANDOFF reviews every pull request a cycle opens with more than one reviewer and
aggregates their reviews into one verdict
([ADR-0026](records/adr/0026-aggregated-review.md)). This document is the single
home for the reviewers — who reviews, on what input, what each one leaves, the
external reviewers' configuration, and their start-confirmation oracle. How a
round runs and how its reviews are aggregated is
[`units/delivery.md`](units/delivery.md) > *Reviewer review* and *Review
aggregation*.

## Reviewers

| Reviewer | Runs | Input | Runtime |
|----------|------|-------|---------|
| built-in (`claude`) | every pull request | the PR (diff, body, linked issue), `.codex/review.md`, the cycle's design artifacts — analysis report, feature design, verification design, decision ledger, build report | a fresh `autoflow-reviewer` spawn (`.claude/agents/autoflow-reviewer.md`), on the model `.claude/autoflow/spawn-policy.json` names for `handoff-review` |
| external (`codex`) | when `.claude/autoflow.local.json` names it | the PR (diff, body, linked issue), `.codex/review.md` | `scripts/review/codex-review-pr.sh` — `codex exec` in the repo working dir, loading `AGENTS.md` → `.codex/review.md` |

An external reviewer is another vendor's model reviewing the same pull request;
the same model is not run twice under two settings. A new external reviewer is a
name the resolver supports (`scripts/review/lib/review-config.sh`) plus its
runtime.

## Contract

```
Contract: reviewer
  Output : one review record per reviewer, PR and round —
           .autoflow/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md —
           in the .codex/review.md Output Format, in Korean.
  A reviewer posts no PR comment and changes no label.

Contract: aggregator  (docs/units/delivery.md > Review aggregation)
  Input  : every review record of the PR and round.
  Output : one PR comment; the PR's findings file (source and disposition per
           finding); `blocked-by-review` taken off the PR when the round is
           clean. A finding the aggregator rejects is recorded with its
           grounds and counts toward no verdict.

Label  : the orchestrator puts `blocked-by-review` on the PR when it runs a
         round; the aggregator takes it off when the round is clean.
```

The external wrapper takes the record path:

```
scripts/review/codex-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>]
```

It stops (exit `3`) when the PR is not that OPEN PR on that head branch, and
treats a run that leaves no record as failed (exit `5`).

## Config location

The external reviewers are recorded in the target-owned scaffold
`.claude/autoflow.local.json`:

```json
{ "review": { "reviewers": ["codex"] } }
```

Read type-aware by `scripts/review/lib/review-config.sh` (the key's JSON type
first, then its value). `.review.reviewers` lists the external reviewers run
beside the built-in review; `[]` names none. When it is absent, the earlier
single-reviewer key is read: `.review.backend: "codex"` reads as `["codex"]`.
**Both absent ⇒ no external reviewer** — the built-in review runs alone. The
scaffold, shipped with `codex`, is delivered by `init.sh` and **never
overwritten** on re-install.

A present file that cannot be read as configured **fails closed** (exit `2`) in
the consumers (`codex-review-pr.sh`, `check-review-backend.sh`), and the
install-time reporter (`detect.sh`) reports `REVIEW_REVIEWERS=invalid`: invalid
JSON, a file present while `jq` is not on PATH, a non-object `.review`, a
`reviewers` value that is not an array of supported names, or a `backend` value
other than `codex`. `.review.backend: "claude"` is among them — the `claude`
backend was removed, since the built-in review is Claude's.

## Model and effort

Each external reviewer's model and reasoning effort can be pinned in the same
scaffold. Every key is optional:

```json
{
  "review": {
    "reviewers": ["codex"],
    "codex": { "model": "gpt-6-sol", "effort": "high" }
  }
}
```

**Single source of truth.** `scripts/review/lib/review-config.sh` is the one
parser, validator and flag-mapper for the whole `review` section. It is
**sourced** by both the live wrapper (`codex-review-pr.sh`) and
`check-review-backend.sh` (presence path and `--probe`), and it ships to targets
as a `copy` artifact. Neither consumer reads `.claude/autoflow.local.json` on
its own.

**Flag mapping** (`build_review_backend_args`, the only place it is written):

| Reviewer | model | effort |
|----------|-------|--------|
| `codex` | `codex exec --model <model>` | `codex exec -c model_reasoning_effort=<effort>` |

**Precedence** (per value, most specific first):

| Value | Order |
|-------|-------|
| model | `.review.<reviewer>.model` → the reviewer's default (`codex`: `gpt-6-sol`) |
| effort | `.review.<reviewer>.effort` → **inherit** |

**Inherit means no flag.** When the effort key is absent (or JSON `null`) the
wrapper passes none, and the CLI applies its own configuration
(`~/.codex/config.toml`, `model_reasoning_effort`). The model default lives in
the resolver so that a target whose never-overwritten scaffold pins nothing
still reviews on it; the scaffold delivered by `init.sh` pins nothing.

**Supported effort values** (the vocabulary lives in `review-config.sh` and is
edited there when a CLI's set evolves — model identifiers are not validated):

| Reviewer | Accepted `effort` | Source |
|----------|-------------------|--------|
| `codex` | `none` `minimal` `low` `medium` `high` `xhigh` `max` `ultra` `persistent` | the named variants of `enum ReasoningEffort`, `codex-rs/protocol/src/openai_models.rs`. |

**Fail-closed** (exit `2`, diagnostic on stderr, **before the reviewer
launches** — in both the wrapper and `check-review-backend.sh`):

- a `review` section that cannot be read as configured (*Config location*
  above);
- `.review.<reviewer>.model` or `.effort` is present but empty (`""`) or not a
  string;
- `.review.<reviewer>.effort` is a string outside that reviewer's vocabulary.

**Start marker.** The wrapper's marker names the reviewer and the effective
model and effort — `[codex-review] starting codex for PR #<N>
(model=gpt-6-sol effort=high) at …`, or `effort=inherit` when none is pinned —
and prints nothing else from the environment (no credentials, no unrelated
variables). `--probe` prints the same summary as
`[check-review-backend] --probe: <reviewer> (model=… effort=…)` before its
round-trip, and passes the identical flags.

**Orchestrator vs. reviewer.** These pins govern only the external reviewer
subprocess. The built-in review's model is the `handoff-review` row of
`.claude/autoflow/spawn-policy.json`; the orchestrating session's own model and
effort follow the user's session settings. None of them reads another.

## Availability (PREFLIGHT, advisory)

`scripts/preflight/check-review-backend.sh` resolves the `review` section
through the shared resolver, prints the configured external reviewers as one
`reviewers: <names|none>` line on stdout — the readout HANDOFF runs them from
([`units/delivery.md`](units/delivery.md) > *Reviewer review*) — and probes each
one's CLI **presence only** (`command -v`):

| Exit | Meaning |
|------|---------|
| `0` | every configured external reviewer's CLI is present, or none is configured |
| `1` | a configured reviewer's CLI is absent — named on stderr with its remedies (install it, or drop it from `.review.reviewers`) |
| `2` | the `review` section cannot be read as configured |

PREFLIGHT records the result. An absent CLI does **not** stop the cycle: HANDOFF
runs the built-in review without that reviewer and the aggregated comment names
the omission ([`units/delivery.md`](units/delivery.md) > *Reviewer review*). A
configuration that cannot be read (exit `2`) stops it
([`units/preparation.md`](units/preparation.md) > *Stop conditions*). Auth is
**not** probed here: a present-but-unauthenticated reviewer passes and its auth
failure surfaces at the HANDOFF run, where it counts as a failed run.

## On-demand auth probe (`--probe`)

`scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode**: it performs **one real authenticated round-trip** against each
configured external reviewer — for `codex`, the same model-API connection a
`codex exec` opens. With no external reviewer configured it reports so and exits
`0`.

**Triggers — on-demand only:** `/autoflow:install` auto-runs the probe
(advisory) after the stamp, and the operator runs it after changing the
reviewer configuration. It is **not** run per-cycle, is **not** wired into
PREFLIGHT, and **no hook consumes it** — a probe failure is narrated, never used
to abort an install or gate a cycle.

**Exit-code contract** (extends the presence `0/1/2`):

| Exit | Meaning |
|------|---------|
| `0` | Round-trip succeeded for every configured reviewer, or none is configured. |
| `1` | A configured reviewer's CLI is **absent** (no round-trip is attempted for it). |
| `2` | Usage/config error. |
| `3` | **Indeterminate** — the probe could not reach a verdict (timeout / no-TTY interactive-login required). Bounded by `PROBE_TIMEOUT_SECS` (default 20s). |
| `4` | A reviewer's CLI is **present but the round-trip failed** (unauthenticated / rejected) — the condition that surfaces at the HANDOFF run. |

## Start-confirmation oracle

`scripts/review/review-start-check.sh --pr <N> [--repo <owner/name>] [--log <the run's output>]`
reads these signals for an external run and reports the first one it finds
([`units/delivery.md`](units/delivery.md) > *Reviewer review*): a session
rollout under `~/.codex/sessions/` written since the launch whose prompt names
`pull request #<N>`, or a running process whose prompt does; an advancing
rollout `mtime` is the long-run health signal, and the review runs in the
background to completion. The wrapper closes `codex exec` stdin (`< /dev/null`)
and prints completion marker `[review] codex completed for PR #<N> (exit=…)`
when the subprocess returns; a non-zero exit means the run failed or left no
record.

The built-in review is a spawn the harness tracks: its return value is its
report, and no start check applies.

## Trade-offs

- **Two vendors, two inputs.** The built-in review reads the cycle's design
  artifacts; the external reviewer reads only the pull request. The measurement
  behind issue #411 found their findings largely disjoint, so the aggregation
  keeps a finding only one of them raised.
- **Account allowance.** The built-in review runs on the same account allowance
  as the orchestrator, once per pull request and round.
