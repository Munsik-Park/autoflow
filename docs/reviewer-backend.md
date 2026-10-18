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
| built-in (`claude`) | every pull request | the PR (diff, body, linked issue), `<autoflow-root>/.codex/review.md`, the cycle's design artifacts — analysis report, feature design, verification design, decision ledger, build report | a fresh `autoflow-reviewer` spawn (`<autoflow-root>/agents/autoflow-reviewer.md`), on the model `.claude/autoflow/spawn-policy.json` names for `handoff-review` |
| external (`codex`) | when the external-reviewer configuration names it (*Config location*) | the PR (diff, body, linked issue), `<autoflow-root>/.codex/review.md` | `<autoflow-root>/scripts/review/codex-review-pr.sh` — `codex exec` in the repo working dir, loading the repo's `AGENTS.md`; the prompt names AutoFlow's `<autoflow-root>/.codex/review.md` by its absolute path |

An external reviewer is another vendor's model reviewing the same pull request;
the same model is not run twice under two settings. A new external reviewer is a
name the resolver supports (`<autoflow-root>/scripts/review/lib/review-config.sh`) plus its
runtime.

## Contract

```
Contract: reviewer
  Output : one review record per reviewer, PR and round —
           .autoflow/{repo-key}-issue-{N}/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md —
           in the <autoflow-root>/.codex/review.md Output Format, in Korean.
  A reviewer posts no PR comment and changes no label.

Contract: aggregator  (<autoflow-root>/docs/units/delivery.md > Review aggregation)
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
<autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>]
```

It stops (exit `3`) when the PR is not that OPEN PR on that head branch, and
treats a run that leaves no record as failed (exit `5`).

## Config location

The external reviewers are configured in one of two files, in this order — the
first whose `.review` is present (not JSON `null`) decides
([ADR-0028](records/adr/0028-user-level-reviewer-config.md)):

| Source | File | Owner |
|---|---|---|
| `local` | `.claude/autoflow.local.json` at the target's repository root | the target, which writes it itself |
| `user` | `~/.autoflow/config.json` (`$HOME/.autoflow/config.json`) | the operator; created once by the plugin's SessionStart hook (*Operator file* below) |
| `none` | neither has `.review` | — the built-in review runs alone |

```json
{ "review": { "reviewers": ["codex"] } }
```

Both files have this shape and are read by the same parser,
`<autoflow-root>/scripts/review/lib/review-config.sh`, type-aware (the key's
JSON type first, then its value). `.review.reviewers` lists the external
reviewers run beside the built-in review; `[]` names none — in the target file
that is "no external review for this repository", and the operator file is not
consulted. When `reviewers` is absent, the earlier single-reviewer key is read:
`.review.backend: "codex"` reads as `["codex"]`. A file whose `.review` is
absent or `null` — a target file holding only other declarations, for one —
passes to the next source. The reviewer list, each reviewer's model and its
effort all come from the one deciding file; nothing is mixed across the two.

The target file is found at the root of the repository the consumer runs in
(`git rev-parse --show-toplevel`), whatever subdirectory it runs from, so the
same two files give the same result from any working directory in the target.
`REVIEW_CONFIG_PATH`, when set in the environment, names the target file in
place of `.claude/autoflow.local.json` (a relative value is read from that
root); the operator file is always `$HOME/.autoflow/config.json`. The sample
`<autoflow-root>/.claude/autoflow.local.json.example` carries no `review`, so a
target started from it takes the operator file.

A file **cannot be read as configured** when it is present while `jq` is not on
PATH, is not valid JSON, has a non-object `.review`, a `reviewers` value that is
not an array of supported names, a `backend` value other than `codex`
(`.review.backend: "claude"` among them — the `claude` backend was removed,
since the built-in review is Claude's), or a model/effort value *Model and
effort* rejects. What follows depends on the file:

- **The target file fails closed** (exit `2`) in both consumers
  (`codex-review-pr.sh`, `check-review-backend.sh`): it is opened when present,
  and each key is checked when it is read. The diagnostic names the file.
- **The operator file never fails closed.** It is checked whole — every
  condition above, the list and every supported reviewer's model and effort —
  on every run, so both consumers reach the same verdict on the same file.
  - When it is the **source** (the target has no `.review`) and cannot be read,
    nothing in it applies and no external reviewer runs. Both consumers print
    the fixed marker line `user-config: UNREADABLE <path> — <error>` and exit
    `6` — distinct from success, from exit `2` and from every exit below;
    `codex-review-pr.sh` starts no codex. The orchestrator asks the operator
    whether to proceed without external review ([`units/preparation.md`](units/preparation.md) >
    *Stop conditions*, [`units/delivery.md`](units/delivery.md) > *Reviewer review*): proceeding
    runs the built-in review alone; stopping leaves the operator to fix the file
    and run the step again, which reads it anew.
  - When the **target decides**, a broken operator file is a warning,
    `user-config: WARNING <path> — <error>`; the result and the exit code are
    the target's, and nothing is asked.

### Operator file

The plugin's SessionStart hook, `<autoflow-root>/hooks/ensure-user-config.sh`,
runs at every session start in every project the plugin is enabled in. When
`~/.autoflow/config.json` is absent it creates it, outside the target's tree,
with

```json
{ "review": { "reviewers": [] } }
```

— external review off until the operator sets `"reviewers": ["codex"]` there —
and only then tells the operator where it is and what it holds. An existing file
is never changed, broken or not. Concurrent session starts create it once: the
content is written to a temporary file and published with a hard link, which
fails when the file exists, so a file another session created is never
overwritten, only the creating session notifies, and no reader sees a partial
file. The same file holds the operator's other AutoFlow values.

## Model and effort

Each external reviewer's model and reasoning effort can be pinned in the
deciding file (*Config location*). Every key is optional:

```json
{
  "review": {
    "reviewers": ["codex"],
    "codex": { "model": "gpt-6-sol", "effort": "high" }
  }
}
```

**Single source of truth.** `<autoflow-root>/scripts/review/lib/review-config.sh` is the one
parser, validator and flag-mapper for the whole `review` section. It is
**sourced** by both the live wrapper (`codex-review-pr.sh`) and
`check-review-backend.sh` (presence path and `--probe`) from the plugin root.
It alone selects the source; neither consumer reads either file on its own.

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
the resolver so that a deciding file that pins nothing still reviews on it —
the model is never taken from the other file.

**Supported effort values** (the vocabulary lives in `review-config.sh` and is
edited there when a CLI's set evolves — model identifiers are not validated):

| Reviewer | Accepted `effort` | Source |
|----------|-------------------|--------|
| `codex` | `none` `minimal` `low` `medium` `high` `xhigh` `max` `ultra` `persistent` | the named variants of `enum ReasoningEffort`, `codex-rs/protocol/src/openai_models.rs`. |

**Rejected values** — part of "cannot be read as configured" (*Config
location*: exit `2` for the target file, the `UNREADABLE` result or the
warning for the operator file), always **before the reviewer launches**:

- `.review.<reviewer>` is present but not an object;
- `.review.<reviewer>.model` or `.effort` is present but empty (`""`) or not a
  string;
- `.review.<reviewer>.effort` is a string outside that reviewer's vocabulary.

**Readout lines.** Both consumers print where the configuration came from and
the operator file's state, in the same form:

```
source: local <path> | user <path> | none
user-config: absent [<path>] | ok <path> | WARNING <path> — <error> | UNREADABLE <path> — <error>
```

Every diagnostic, warning and remedy names the file that decided the value —
for an unreadable operator file, that file.

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

`<autoflow-root>/scripts/preflight/check-review-backend.sh` resolves the external
reviewers through the shared resolver, prints them as one
`reviewers: <names|none>` line on stdout — the readout HANDOFF runs them from
([`units/delivery.md`](units/delivery.md) > *Reviewer review*) — followed by the
`source:` and `user-config:` lines (*Model and effort* > Readout lines), and
probes each reviewer's CLI **presence only** (`command -v`):

| Exit | Meaning |
|------|---------|
| `0` | every configured external reviewer's CLI is present, or none is configured |
| `1` | a configured reviewer's CLI is absent — named on stderr with its remedies (install it, or drop it from `.review.reviewers` in the file that configured it) |
| `2` | the target's `.claude/autoflow.local.json` cannot be read as configured |
| `6` | the operator file is the source and cannot be read as configured — the marker line `user-config: UNREADABLE <path> — <error>`; no reviewer is checked |

PREFLIGHT records the result in the `preflight-review-config` record entry
([`units/preparation.md`](units/preparation.md) > *Stop conditions*). An absent
CLI does **not** stop the cycle: HANDOFF runs the built-in review without that
reviewer and the aggregated comment names the omission
([`units/delivery.md`](units/delivery.md) > *Reviewer review*). A target file
that cannot be read (exit `2`) stops it. An unreadable operator file (exit `6`)
is put to the operator, who chooses between proceeding without external review
and fixing the file. Auth is **not** probed here: a present-but-unauthenticated
reviewer passes and its auth failure surfaces at the HANDOFF run, where it
counts as a failed run.

## On-demand auth probe (`--probe`)

`<autoflow-root>/scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode**: it performs **one real authenticated round-trip** against each
configured external reviewer — for `codex`, the same model-API connection a
`codex exec` opens. With no external reviewer configured it reports so and exits
`0`.

**Triggers — on-demand only:** the operator runs it after writing or changing
the reviewer configuration. It is **not** run per-cycle, is **not** wired into
PREFLIGHT, and **no hook consumes it** — a probe failure is narrated, never used
to gate a cycle.

**Exit-code contract** (extends the presence `0/1/2`):

| Exit | Meaning |
|------|---------|
| `0` | Round-trip succeeded for every configured reviewer, or none is configured. |
| `1` | A configured reviewer's CLI is **absent** (no round-trip is attempted for it). |
| `2` | Usage error, or the target file cannot be read as configured. |
| `3` | **Indeterminate** — the probe could not reach a verdict (timeout / no-TTY interactive-login required). Bounded by `PROBE_TIMEOUT_SECS` (default 20s). |
| `4` | A reviewer's CLI is **present but the round-trip failed** (unauthenticated / rejected) — the condition that surfaces at the HANDOFF run. |
| `6` | The operator file is the source and cannot be read as configured (*Config location*); no round-trip is attempted. The probe's report goes to the operator who ran it. |

## Start-confirmation oracle

`<autoflow-root>/scripts/review/review-start-check.sh --pr <N> [--repo <owner/name>] [--log <the run's output>]`
reads these signals for an external run and reports the first one it finds
([`units/delivery.md`](units/delivery.md) > *Reviewer review*): a session
rollout under `~/.codex/sessions/` written since the launch whose prompt names
`pull request #<N>`, or a running process whose prompt does; an advancing
rollout `mtime` is the long-run health signal, and the review runs in the
background to completion. The wrapper closes `codex exec` stdin (`< /dev/null`)
and prints completion marker `[review] codex completed for PR #<N> (exit=…)`
when the subprocess returns; a non-zero exit means the run failed or left no
record. A wrapper that stopped on an unreadable operator file prints the marker
line `user-config: UNREADABLE …` instead and no completion marker;
`review-start-check.sh --log` reports it as exit `4`.

The built-in review is a spawn the harness tracks: its return value is its
report, and no start check applies.

## Trade-offs

- **Two vendors, two inputs.** The built-in review reads the cycle's design
  artifacts; the external reviewer reads only the pull request. The measurement
  behind issue #411 found their findings largely disjoint, so the aggregation
  keeps a finding only one of them raised.
- **Account allowance.** The built-in review runs on the same account allowance
  as the orchestrator, once per pull request and round.
