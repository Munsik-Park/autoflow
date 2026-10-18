# ADR-0028: The external reviewers fall back to an operator-level file, `~/.autoflow/config.json`

## Status

Accepted (operator decisions 2026-10-18, issue #463 > 운영자 결정, and the criterion review's
operator overrides O1 and O2). Amends ADR-0026 D1 ("each external reviewer the target configures")
and D5 ("an unreadable review configuration still stops it"), and
`docs/tool-delivery-contract.md` > *Target-owned files*.

## Context

The cycle that verified the 0.3.0 plugin-only delivery (`Munsik-Park/orca-autoflow` issue #15, PR
#29) ran no external review: `check-review-backend.sh` printed `reviewers: none`, HANDOFF ran the
built-in review alone, and the aggregated comment said that no external reviewer was configured for
that target — on a machine with the `codex` CLI. That was the configured behavior: the external
reviewers were read only from the target's `.claude/autoflow.local.json` > `.review`.

Which external reviewer runs is the operator's value, not the repository's. The operator's five
llmroute clones each carry the same `"review": { "backend": "codex" }`; a repository that has not
copied it loses the external review. A plugin-level value the operator sets once was the obvious
candidate: Claude Code's plugin `userConfig`.

**What `userConfig` delivers** (issue #463 > 측정 결과; Claude Code 2.1.302, a `--plugin-dir`
probe plugin, values set through `--settings` > `pluginConfigs`, read from the session transcripts
and a hook log). The probe had one option set, one with a `default` only, and one `multiple: true`
option set to two items:

| # | Where | A set value | A value with only a `default` |
|---|---|---|---|
| 1 | skill and agent body `${user_config.KEY}` (main session, subagent) | substituted | left as the literal `${user_config.KEY}` |
| 2 | skill and agent body `${CLAUDE_PLUGIN_OPTION_<KEY>}` | not substituted | — |
| 3 | `CLAUDE_PLUGIN_OPTION_<KEY>` in the Bash environment (main session, subagent) | absent | absent |
| 4 | `CLAUDE_PLUGIN_OPTION_<KEY>` in a hook's environment (hooks inside a subagent included) | present | absent |
| 5 | `${user_config.KEY}` in an exec-form hook's `args` | substituted | the hook does not run (`Plugin option "…" isn't set`) |

- `pluginConfigs` in the target's `.claude/settings.json` or `.claude/settings.local.json` was not
  read (Claude Code's changelog: plugin option values "are no longer read from project-level
  `.claude/settings.json`").
- A `multiple: true` value arrives as one comma-joined string.
- A SessionStart hook can export a set value into the Bash environment through `CLAUDE_ENV_FILE`
  (main session and subagents saw it); only SessionStart receives that file.

**How Claude Code treats a broken settings file** (issue #463 > 운영자 결정; `claude -p --settings
<a malformed JSON file>`, rc 0): the session runs without that file and says so — "These settings
files did not load, so nothing in them is in effect … Each loads again once the problem listed for
it is fixed" — and the debug log records "Invalid setting skipped without dialog (automated
session)"; an interactive session asks in a dialog whether to go on.

## Decision

**D1 — The operator's file.** The operator-level external-reviewer configuration is
`$HOME/.autoflow/config.json`, in the same shape as the target file (`{ "review": { … } }`) and read
by the same parser, `<autoflow-root>/scripts/review/lib/review-config.sh`. Its location is defined
once, in `<autoflow-root>/scripts/lib/user-config.sh`. The same file is the home of the operator's
other AutoFlow values (issue #466's record root).

**D2 — Source order.** The first file whose `.review` is present (not JSON `null`) decides, and the
reviewer list, each reviewer's model and its effort all come from it:

1. `local` — the target's `.claude/autoflow.local.json` at the root of the repository the
   consumer runs in, whatever subdirectory it runs from; `"reviewers": []` decides "no external
   review for this repository". A file without `.review` passes to the next step.
2. `user` — `~/.autoflow/config.json`.
3. `none` — the built-in review runs alone.

**D3 — A broken operator file is reported, not fatal.** The target file keeps failing closed
(exit `2`). The operator file follows Claude Code's handling of a broken settings file: when it is
the source and cannot be read as configured — invalid JSON or a `.review` content error, the same
conditions as the target file — nothing in it applies, and both consumers give a result distinct
from success and from exit `2`: the fixed marker line `user-config: UNREADABLE <path> — <error>`,
exit `6` from `check-review-backend.sh` (outside its `0`–`4`) and from `codex-review-pr.sh` (which
starts no codex; the marker line, not the exit code, tells it from a codex exit). The orchestrator
that receives it asks the operator whether to proceed without external review, at PREFLIGHT and at
HANDOFF; proceeding runs the built-in review alone and the aggregated comment names the missing
review and the reason; stopping lets the operator fix the file and run the step again, and every run
reads the file anew. When the target's `.review` decides, a broken operator file is a warning
(`user-config: WARNING …`) that changes neither the result nor the exit code, and nothing is asked.

**D4 — The file is created once.** A SessionStart hook (`<autoflow-root>/hooks/ensure-user-config.sh`)
creates `~/.autoflow/config.json` with `{ "review": { "reviewers": [] } }` when it is absent —
external review stays opt-in — and only then tells the operator where it is and what it holds
(`systemMessage`). It writes a temporary file and publishes it with a hard link, which fails when the
file exists: concurrent session starts create it once, never overwrite it, notify once, and no reader
sees a partial file. An existing file is never changed.

**D5 — The source is on the record.** `check-review-backend.sh` prints `source: local <path> |
user <path> | none` and a `user-config:` line beside `reviewers:`, and PREFLIGHT records them, with
the operator's answer when asked, as the `preflight-review-config` record entry
(`docs/decision-ledger.md`, `docs/units/preparation.md` > *Stop conditions*).

**D6 — The sample names no reviewer.** `.claude/autoflow.local.json.example` no longer carries
`review`, so a target started from it takes the operator's file.

### Why not `userConfig`

Each delivery path, against the row that measured it:

- **Row 1 — `${user_config.KEY}` in a body.** It reaches text the model reads, not the resolver,
  which is a script run through Bash at PREFLIGHT and a background wrapper at HANDOFF. The value
  would reach both only by the model copying it into each command line — an unchecked copy that the
  two runs must make identically — and on a machine where the operator never set it the body holds
  the literal `${user_config.KEY}`, since a `default` is not applied.
- **Row 2 — `${CLAUDE_PLUGIN_OPTION_<KEY>}` in a body.** Not substituted: no value arrives.
- **Row 3 — the Bash environment.** Absent, set or not. This is where the resolver runs, so it
  cannot read the value directly.
- **Row 4 — a hook's environment.** Present only when set; a `default` never arrives. The hook is
  not the reader, and the one bridge to Bash — a SessionStart hook writing `CLAUDE_ENV_FILE` —
  freezes the value at session start, so a correction the operator makes is not read by the next
  run (D3 relies on every run reading anew), and `check-review-backend.sh --probe`, which the
  operator runs from a shell, never sees it.
- **Row 5 — exec-form hook `args`.** A hook that cites an option the operator has not set does not
  run, so the hook would fail on every machine where the operator never set the option.

Beyond the rows: a `multiple: true` reviewer list arrives as a comma-joined string, which would need
a second parser beside the JSON array the target file holds; and the values can be set only in the
user, `--settings` or managed settings — the same per-user scope a file under `$HOME` has. A file
that the script reads directly reaches every consumer with the same parser, is read anew on every
run, and its default is a real file. `thedotmack/claude-mem` keeps its user settings the same way
(`~/.claude-mem/settings.json`).

## Alternatives Considered

- **Plugin `userConfig`** — rejected, per row above.
- **An environment variable the operator exports** — rejected: it is absent from a session Claude
  Code starts unless the operator's shell profile sets it, and it has no file to create a default in
  or to report as broken.
- **Keep the target file only** — rejected: the operator's value is copied into every repository,
  and a repository without the copy loses the external review (the case that raised this issue).
- **Fail closed on a broken operator file (exit `2`)** — the advisor's first answer (criterion
  review, A1 and A2); overridden by the operator (O1, O2): the operator file is one per machine and
  edited by hand, and Claude Code itself skips a broken settings file and reports it.

## Consequences

### Positive

- One edit to `~/.autoflow/config.json` turns the external review on for every repository that has
  no `.review` of its own.
- A repository can still decide for itself, including "no external review" (`reviewers: []`).
- PREFLIGHT records where the configuration came from.

### Negative

- A repository that committed `.review` (the llmroute clones) keeps its own value; the operator file
  does not reach it until that `.review` is removed.
- The plugin writes outside the target's tree, under `$HOME`, in every project it is enabled in.

### Neutral / Trade-Offs

- A broken operator file asks the operator at the step it is read in, instead of stopping the cycle.
- A check that runs the consumers sets `HOME` to an empty directory, so the operator's file never
  steers it (`tests/plugin/verify-path-independence.sh`).

## Related Issues / PRs

- Issue #463 — this decision.
- Issue #454 — the plugin-only delivery whose verification cycle surfaced it; ADR-0027 (what the
  plugin delivers).
- Issue #184 — the `.review` model/effort resolution, reused unchanged.
- Issue #466 — the record root, in the same file.

## Notes

- Contracts: `docs/reviewer-backend.md` > *Config location*, *Availability*;
  `docs/tool-delivery-contract.md` > *Operator-level file*; `docs/units/preparation.md` > *Stop
  conditions* > Reviewer configuration; `docs/units/delivery.md` > *Reviewer review*.
