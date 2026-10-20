# Reviewer Contract

REVIEW reviews every pull request a cycle opens with more than one reviewer and
aggregates their reviews into one verdict
([ADR-0026](records/adr/0026-aggregated-review.md),
[ADR-0033](records/adr/0033-review-unit-and-script-reviewers.md)). This document
is the single home for the reviewers — who reviews, on what input, what each one
leaves, their configuration, and their start-confirmation oracle. How a round
runs and how its reviews are aggregated is
[`units/review.md`](units/review.md) > *Reviewer review* and *Review
aggregation*.

## Reviewers

Every reviewer is run by its own script, in the reviewed repository's working
directory, with an environment fitted to its CLI; no two reviewers share one.

| Reviewer | Input | Runtime |
|----------|-------|---------|
| `claude` | the PR (diff, body, linked issue), its rule file, and the cycle's design artifacts in the attempt's record directory `--records` names — analysis report, feature design, verification design, decision ledger, build report | `<autoflow-root>/scripts/review/claude-review-pr.sh` — `claude -p` with read-only tools and the `gh` / `git` reads the review needs, every other tool denied without a prompt (`--permission-mode dontAsk`), and the reviewed repository's own `.claude/` settings not loaded (`--setting-sources user`) — in a trusted checkout their permission rules would add tools; the prompt names the rule file by its absolute path, and the final message is the review |
| `codex` | the PR (diff, body, linked issue), its rule file | `<autoflow-root>/scripts/review/codex-review-pr.sh` — `codex exec` in the repo working dir, which loads that tree's `AGENTS.md` itself; the prompt names the rule file by its absolute path |
| the target's side | what that system reads | a review a system on the target's side runs on the pull request by itself — a review bot — read by the aggregator from the pull request ([`units/review.md`](units/review.md) > *Review aggregation*) |

A new reviewer is a name the resolver supports
(`<autoflow-root>/scripts/review/lib/review-config.sh`), its wrapper and its
rule file.

## Rule files

The review rules every reviewer applies — posture, severity levels, method,
lenses and Output Format — are
`<autoflow-root>/docs/review/review.md`. Each reviewer's own rule file, beside
it, names what that reviewer reads and where its review goes:
`<autoflow-root>/docs/review/review-claude.md`,
`<autoflow-root>/docs/review/review-codex.md`. The wrapper names the rule file
in its prompt, and states what `<autoflow-root>` is.

Per reviewer, two keys of the configuration (*Config location*) replace or add
to these:

- `.review.<reviewer>.rules` — another rule file in place of
  `<autoflow-root>/docs/review/review-<reviewer>.md`. A wrapper whose rule file is absent stops
  (exit `2`) before the reviewer starts.
- `.review.<reviewer>.lenses` — a file of further review lenses (the defect
  axes `<autoflow-root>/docs/review/review.md` > Review Lenses lists), which the prompt names
  beside the rule file. Absent from a repository, it is left out of that
  repository's review, with a line on stderr.

A relative path is read from the root of the reviewed repository, so one entry
can name each target's own file.

## Contract

```
Contract: reviewer
  Output : one review record per reviewer, PR and round —
           <attempt-dir>/issue-{N}-local/review/raw-<reviewer>-<owner>.<name>-<pr>-r<k>.md —
           in the <autoflow-root>/docs/review/review.md Output Format, in Korean.
  A reviewer posts no PR comment and changes no label.

Contract: aggregator  (<autoflow-root>/docs/units/review.md > Review aggregation)
  Input  : every review record of the PR and round, and the reviews the
           target's side left on the PR.
  Output : one PR comment; the PR's findings file (source and disposition per
           finding). A finding the aggregator rejects is recorded with its
           grounds and counts toward no verdict.
```

Each wrapper takes the record path:

```
<autoflow-root>/scripts/review/claude-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>] [--records <attempt-dir>]
<autoflow-root>/scripts/review/codex-review-pr.sh --pr <N> --out <record> [--repo <owner/name>] [--expected-head <branch>]
```

Each stops (exit `3`) when the PR is not that OPEN PR on that head branch, and
treats a run that leaves no record as failed (exit `5`).

## Config location

The reviewers are configured in one file, the operator's
`~/.autoflow/config.json` (`$HOME/.autoflow/config.json`), created once by the
plugin's SessionStart hook (*Operator file* below). A target's
`.claude/autoflow.local.json` is not read for reviewers: the reviewers AutoFlow
runs are the same in every project
([ADR-0033](records/adr/0033-review-unit-and-script-reviewers.md)).

```json
{ "review": { "reviewers": ["claude", "codex"] } }
```

The file is read by `<autoflow-root>/scripts/review/lib/review-config.sh`,
type-aware (the key's JSON type first, then its value). `.review.reviewers`
lists the reviewers that run. When it is absent, `null` or `[]` it names none of
its own, and the default reviewers run — `claude` and `codex`; so do they when
the file is absent. Each reviewer's model, effort, rule file and lenses file
come from the same file (*Rule files*, *Model and effort*).

The file **cannot be read as configured** when it is present while `jq` is not
on PATH, is not valid JSON, has a non-object `.review`, a `reviewers` value that
is not an array of supported names, or a per-reviewer value *Model and effort*
or *Rule files* rejects. It never fails closed. It is checked whole — every
condition above, the list and every supported reviewer's settings — on every
run, so every consumer reaches the same verdict on the same file. When it
cannot be read, nothing in it applies and no reviewer runs: the readout names
it (`source: user <path>`), and every consumer prints the fixed marker line
`user-config: UNREADABLE <path> — <error>` and exits `6` — distinct from success,
from exit `2` and from every exit below; no wrapper starts its reviewer. The
orchestrator asks the operator whether to proceed without those reviewers
([`units/preparation.md`](units/preparation.md) > *Stop conditions*,
[`units/review.md`](units/review.md) > *Reviewer review*): proceeding runs the
round on the reviews of the target's side alone; stopping leaves the operator
to fix the file and run the step again, which reads it anew.

### Operator file

The plugin's SessionStart hook, `<autoflow-root>/hooks/ensure-user-config.sh`,
runs at every session start in every project the plugin is enabled in. When
`~/.autoflow/config.json` is absent it creates it, outside the target's tree,
with

```json
{ "review": { "reviewers": [] } }
```

— no reviewer named, so the default reviewers run until the operator lists them
there — and only then tells the operator where it is and what it holds. An
existing file is never changed, broken or not. Concurrent session starts create
it once: the content is written to a temporary file and published with a hard
link, which fails when the file exists, so a file another session created is
never overwritten, only the creating session notifies, and no reader sees a
partial file. The same file holds the operator's other AutoFlow values — the
record root, `record_root` ([`state-tracking.md`](state-tracking.md) > *Record
location*). Each key is read and validated by its own reader: an error in
`.review` does not touch the record root, and an error in `record_root` does not
touch the reviewers; a file that is not valid JSON, or no `jq`, leaves both
unreadable.

## Model and effort

Each reviewer's model and reasoning effort can be pinned in the operator file
(*Config location*). Every key is optional:

```json
{
  "review": {
    "reviewers": ["claude", "codex"],
    "codex": { "model": "gpt-6-sol", "effort": "high" }
  }
}
```

**Single source of truth.** `<autoflow-root>/scripts/review/lib/review-config.sh` is the one
parser, validator and flag-mapper for the whole `review` section. It is
**sourced** by the live wrappers (`claude-review-pr.sh`, `codex-review-pr.sh`)
and `check-review-backend.sh` (presence path and `--probe`) from the plugin
root. It alone reads the file; no consumer reads it on its own.

**Flag mapping** (`build_review_backend_args`, the only place it is written):

| Reviewer | model | effort |
|----------|-------|--------|
| `claude` | `claude --model <model>` | `claude --effort <effort>` |
| `codex` | `codex exec --model <model>` | `codex exec -c model_reasoning_effort=<effort>` |

**Precedence** (per value, most specific first):

| Value | Order |
|-------|-------|
| model | `.review.<reviewer>.model` → the reviewer's default (`claude`: `opus`; `codex`: `gpt-6-sol`) |
| effort | `.review.<reviewer>.effort` → **inherit** |

**Inherit means no flag.** When the effort key is absent (or JSON `null`) the
wrapper passes none, and the CLI applies its own configuration (`claude`: its
settings; `codex`: `~/.codex/config.toml`, `model_reasoning_effort`). The model
default lives in the resolver so that a file that pins nothing still reviews on
it.

**Supported effort values** (the vocabulary lives in `review-config.sh` and is
edited there when a CLI's set evolves — model identifiers are not validated):

| Reviewer | Accepted `effort` | Source |
|----------|-------------------|--------|
| `claude` | `low` `medium` `high` `xhigh` `max` | `claude --help` > `--effort` (Claude Code 2.1.304). |
| `codex` | `none` `minimal` `low` `medium` `high` `xhigh` `max` `ultra` `persistent` | the named variants of `enum ReasoningEffort`, `codex-rs/protocol/src/openai_models.rs`. |

**Rejected values** — part of "cannot be read as configured" (*Config
location*: the `UNREADABLE` result), always **before the reviewer launches**:

- `.review.<reviewer>` is present but not an object;
- `.review.<reviewer>.model`, `.effort`, `.rules` or `.lenses` is present but
  empty (`""`) or not a string;
- `.review.<reviewer>.effort` is a string outside that reviewer's vocabulary.

**Readout lines.** Every consumer prints where the configuration came from and
the operator file's state, in the same form:

```
source: user <path> | none
user-config: absent [<path>] | ok <path> | UNREADABLE <path> — <error>
```

Every diagnostic and remedy names the operator file.

**Start marker.** A wrapper's marker names the reviewer and the effective
model and effort — `[codex-review] starting codex for PR #<N>
(model=gpt-6-sol effort=high) at …`, or `effort=inherit` when none is pinned —
and prints nothing else from the environment (no credentials, no unrelated
variables). `--probe` prints the same summary as
`[check-review-backend] --probe: <reviewer> (model=… effort=…)` before its
round-trip, and passes the identical flags.

**Orchestrator vs. reviewer.** These pins govern only the reviewer subprocess;
the orchestrating session's own model and effort follow the user's session
settings, and the aggregator's the `handoff-review-triage` row of
`.claude/autoflow/spawn-policy.json`. None of them reads another.

## Availability (PREFLIGHT, advisory)

`<autoflow-root>/scripts/preflight/check-review-backend.sh` resolves the
reviewers through the shared resolver, prints them as one
`reviewers: <names|none>` line on stdout — the readout REVIEW runs them from
([`units/review.md`](units/review.md) > *Reviewer review*) — followed by the
`source:` and `user-config:` lines (*Model and effort* > Readout lines), and
probes each reviewer's CLI **presence only** (`command -v`):

| Exit | Meaning |
|------|---------|
| `0` | every configured reviewer's CLI is present |
| `1` | a configured reviewer's CLI is absent — named on stderr with its remedies (install it, or list the reviewers to run without it in the operator file) |
| `2` | usage error |
| `6` | the operator file cannot be read as configured — the marker line `user-config: UNREADABLE <path> — <error>`; no reviewer is checked |

PREFLIGHT records the result in the `preflight-review-config` record entry
([`units/preparation.md`](units/preparation.md) > *Stop conditions*). An absent
CLI does **not** stop the cycle: REVIEW runs the other reviewers without it and
the aggregated comment names the omission
([`units/review.md`](units/review.md) > *Reviewer review*). An unreadable
operator file (exit `6`) is put to the operator, who chooses between proceeding
without those reviewers and fixing the file. Auth is **not** probed here: a
present-but-unauthenticated reviewer passes and its auth failure surfaces at the
REVIEW run, where it counts as a failed run.

## On-demand auth probe (`--probe`)

`<autoflow-root>/scripts/preflight/check-review-backend.sh --probe` is a **separate on-demand
mode**: it performs **one real authenticated round-trip** against each
configured reviewer — the same model-API connection a `claude -p` or a
`codex exec` opens.

**Triggers — on-demand only:** the operator runs it after writing or changing
the reviewer configuration. It is **not** run per-cycle, is **not** wired into
PREFLIGHT, and **no hook consumes it** — a probe failure is narrated, never used
to gate a cycle.

**Exit-code contract** (extends the presence `0/1/2`):

| Exit | Meaning |
|------|---------|
| `0` | Round-trip succeeded for every configured reviewer. |
| `1` | A configured reviewer's CLI is **absent** (no round-trip is attempted for it). |
| `2` | Usage error. |
| `3` | **Indeterminate** — the probe could not reach a verdict (timeout / no-TTY interactive-login required). Bounded by `PROBE_TIMEOUT_SECS` (default 20s). |
| `4` | A reviewer's CLI is **present but the round-trip failed** (unauthenticated / rejected) — the condition that surfaces at the REVIEW run. |
| `6` | The operator file cannot be read as configured (*Config location*); no round-trip is attempted. The probe's report goes to the operator who ran it. |

## Start-confirmation oracle

`<autoflow-root>/scripts/review/review-start-check.sh --pr <N> [--reviewer <name>] [--repo <owner/name>] [--log <the run's output>]`
reads these signals for a reviewer's run and reports the first one it finds
([`units/review.md`](units/review.md) > *Reviewer review*): a running process
of that reviewer's CLI (`--reviewer`; reviewers run side by side on one PR) whose prompt names
`pull request #<N>`, or, for `codex`, a session rollout under
`~/.codex/sessions/` written since the launch whose prompt does; an advancing
rollout `mtime` is codex's long-run health signal, and the review runs in the
background to completion. Each wrapper closes its CLI's stdin (`< /dev/null`)
and prints the completion marker `[review] <reviewer> completed for PR #<N>
(exit=…)` when the subprocess returns; a non-zero exit means the run failed or
left no record. A wrapper that stopped on an unreadable operator file prints the
marker line `user-config: UNREADABLE …` instead and no completion marker;
`review-start-check.sh --log` reports it as exit `4`.

## Trade-offs

- **Two vendors, two inputs.** The `claude` review reads the cycle's design
  artifacts; the `codex` review reads only the pull request. The measurement
  behind issue #411 found their findings largely disjoint, so the aggregation
  keeps a finding only one of them raised.
- **Account allowance.** The `claude` review runs on the same account allowance
  as the orchestrator, once per pull request and round.
