# Cycle metrics — collecting cost and outcome per issue (issue #268)

A record tool. It reads what Claude Code and AutoFlow already left on this machine, keeps the
aggregate, and draws it. It changes no rule, gate, hook or bundle, no gate reads what it writes
(`CLAUDE.md` > Rule Scope, principle 1), and it is not shipped to a target — this file sits under
`docs/records/` for the same reason: the bundle is the link closure of `CLAUDE.md` and
`docs/INDEX.md` minus this tier (`setup/gen-manifest-hashes.sh`, `RECORD_TIER_PREFIX`), so nothing
here reaches a target.

## Why it has to run on a schedule

The raw material is the Claude Code transcript, and the harness deletes it. The retention is the
`cleanupPeriodDays` setting ("how many days Claude Code keeps transcripts before deleting them",
Claude Code settings reference); it is not set on the operator's machine, and the oldest transcript
found there on 2026-09-17 was 29 days old. The `.autoflow` archive does not hold transcripts. A
session that expires before it is collected is lost, so the collector runs **at least weekly**.

It calls no model and needs no Claude session: it is two standard-library Python scripts.

## Commands

```
python3 scripts/metrics/cycle-metrics.py      # collect new sessions, then regenerate issues.tsv / issues.json
python3 scripts/metrics/render-metrics.py     # write cycle-metrics.html
```

Everything is written under `${AUTOFLOW_ARCHIVE_ROOT:-$HOME/.autoflow}/_metrics/` and nowhere else —
no file in this repository or in a target repository is created or changed. The reviewer and CI
rounds are filled only for PRs a `--gh` run has fetched into `github/`; a run without the flag reads
those cached copies and leaves the rest empty.

| Path | Written | Content |
|---|---|---|
| `sessions/<session-id>.json` | once per session | the session aggregate (below) |
| `github/<owner>__<repo>__<n>.json` | by `--gh`, once per closed PR | what the outcome reads from one PR (below) |
| `issues.tsv`, `issues.json` | every run, from `sessions/` and `github/` | one row per issue and arm |
| `cycle-metrics.html` | by the renderer | one self-contained page, no external resource |
| `labels.tsv` | by the operator | A/B labels (below) |

A session is finalized once its last record is older than `--settle-hours` (default 12); a younger
one is reported as `unsettled` and picked up by a later run. A collected session is not written
again, with one exception: a session one of whose source transcripts **grew** after collection (a
resumed session) is re-aggregated. Growth is judged per source, never on the total, and the new
record is **merged** with the old one rather than replacing it: an agent whose transcript has
expired in the meantime keeps its prior aggregate (marked `source_expired`), and a main transcript
that shrank or vanished leaves the whole record alone.

Useful flags: `--projects-root DIR` (repeatable; the first root holding a session id wins — a
stripped metering-only copy of expired transcripts can be given as a second root), `--session ID`,
`--no-collect` (re-derive only), `--gh` (fetch each cycle row's linked PRs with `gh`; the only network
use — see *Reviewer and CI rounds*).

### Scheduling

macOS (`launchd`) — `~/Library/LaunchAgents/com.autoflow.cycle-metrics.plist`, then
`launchctl load ~/Library/LaunchAgents/com.autoflow.cycle-metrics.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.autoflow.cycle-metrics</string>
  <key>ProgramArguments</key><array>
    <string>/bin/sh</string><string>-c</string>
    <string>cd "$HOME/work/autoflow" &amp;&amp; python3 scripts/metrics/cycle-metrics.py &amp;&amp; python3 scripts/metrics/render-metrics.py</string>
  </array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/tmp/cycle-metrics.log</string>
  <key>StandardErrorPath</key><string>/tmp/cycle-metrics.log</string>
</dict></plist>
```

Linux (`cron`), daily at 09:00:

```
0 9 * * * cd "$HOME/work/autoflow" && python3 scripts/metrics/cycle-metrics.py && python3 scripts/metrics/render-metrics.py >> /tmp/cycle-metrics.log 2>&1
```

Replace the checkout path with this repository's location on the machine. A daily run costs a few
seconds (197 sessions were aggregated in about 6 s on the first backfill) and already-collected
sessions are skipped by a `stat`.

### Schema upgrades

A session record carries the `schema` it was written under. When the collector's schema is newer, a
record is **replaced only by a collection that covers it** — at least its orchestrator calls, and
every one of its agents with at least its calls. The roots are tried in the order given, so a
session whose transcript has expired is upgraded from a preserved copy passed as a later
`--projects-root`. A record with no covering source is left exactly as it is, on its older schema — also when its
source has grown in the meantime (a resumed session whose agent transcript expired): the merge that
handles that case is for a record of the current schema only, since merging would stamp the record
with the new schema while the agents it keeps still carry the old one's fields;
the run reports how many (`schema 2: upgraded N from the transcripts, N from a preserved copy; N
kept on an older schema`), `issues.tsv` counts them per row (`stale_schema_sessions`), and a later
run retries. A record is never deleted to be rebuilt. Schema 2 (the agent role from the declared
`subagent_type`) upgraded 195 records from the transcripts and 2 from the preserved copy, with none
left behind. Schema 3 (state writes read from the shell and the edit tools, reviewer launches,
`AskUserQuestion` answers, the harness's session cost — issue #282) upgraded 161 records from the
transcripts on 2026-09-23; 56 records whose transcripts had expired stay on schema 2, and the rules
below say what each field falls back to for them.

## What a session record holds

Aggregate values only. No transcript text, no tool output and no prompt body is stored — those carry
the target's code.

- per agent: role (the `subagent_type` the orchestrator's `Agent` call declared — joined by tool-use id,
  or by spawn name for a named teammate, whose meta file holds the name in `agentType` and no
  tool-use id), model, the spawn's short `description` label, phase-key and the
  method that recovered it, API call count, cache read / cache write / output, peak context,
  start / end, and the same figures per wake for a resumed agent;
- the orchestrator's calls, one row each: timestamp, context, cache read, cache write, output, and
  whether the call re-wrote its whole prefix;
- the `.autoflow/issue-{N}` reference runs, operator prompt timestamps, linked PRs, the working
  directory, git branches;
- the issues whose **own state file** the session wrote (`state_writes`): the `Write` / `Edit` /
  `MultiEdit` / `NotebookEdit` tools on `.autoflow/issue-{N}.json`, and a shell command that writes it —
  a redirect into the path, the path as the last argument of `mv` / `cp` / `install`, `tee`, `sed -i`,
  or a script that opens it for writing. Only the working tree's own file counts: a relative
  `.autoflow/…` path, one under a working directory of the session, or a shell or script variable
  assigned to either. A copy written under a scratch or temp directory is not the state file;
- each configured-reviewer launch (`reviewer_runs`): the timestamp, the `--repo` if given and the
  `--pr` of every `codex-review-pr.sh` in an orchestrator shell command;
- the timestamps of the `AskUserQuestion` calls the operator **answered** (`operator.answers`). A
  question the operator rejected is not an answer; what they typed next is an operator prompt;
- the harness's own cost of the session (`cost`): the last `cost-state` record of the transcript —
  `totalCostUSD` and each model's `costUSD`, the figure the session displays, restored on a resume.

A stripped copy keeps no tool input and no tool result, so `state_writes`, `reviewer_runs` and
`operator.answers` are `null` in a record built from one; a record on schema 2 has no
`reviewer_runs`, `operator.answers` or `cost`, and its `state_writes` saw the `Write` tool only.

The method is ADR-0017 > Notes > C8, from the one implementation both tools share
(`scripts/metrics/transcript_stats.py`, also used by `scripts/architect/deliberation-metrics.py`):
usage is de-duplicated by `message.id` keeping the record with the largest output, and a re-write is
a call other than the first whose `cache_creation >= 0.9 x (cache_read + cache_creation)`.

**Phase-key recovery.** The key is recovered from the orchestrator's `spawn-policy.sh model <key>`
readouts. Readouts are batched in practice (one `for k in ...` loop ahead of several spawns), so the
read-out keys are narrowed by the policy's `agent_type` for the spawn's `subagent_type`, and the
spawn's description label decides among them. Each agent records which method decided
(`readout+description`, `description`, `readout`, `agent-type`, `workflow-site`) or none, and every
run prints the rate. On the first backfill it was 771 of 863 AutoFlow-role spawns (89.3%). A spawn
the policy has no row for — a PR-body draft, a VERIFY step run by the Test AI — has no key to
recover and stays `none`. When `.autoflow/issue-{N}-phases.jsonl` exists (the issue #35 emitter; wired
into no phase today) its markers are joined as `phase_marker`.

## How an issue row is derived

`issues.tsv` is rebuilt from `sessions/` on every run, so a correction to the rules below recomputes
every past issue.

- A session moves to an issue at **three consecutive** `.autoflow/issue-{N}` references; a single
  look at another issue's file (PREFLIGHT reading a prior cycle's state) moves nothing. One issue is
  `active` at a time (PR Wait Rule), so the segments do not overlap.
- **Performing and referencing.** A session's segment of issue N *performs* N when a `labels.tsv`
  label links the session to N (below), or the session wrote N's own state file. Any other session
  with a segment of N only read N's files — an advisory session reading another session's cycle, a
  draft, a post-hoc analysis — and its segment goes to a **reference row** `repo#N~ref`, never into
  N's cycle row: its calls, agents, prompts and cost are not the cycle's. A session whose record
  cannot tell (schema 2, a stripped copy) stays in N's row as before. On 2026-09-23 this put 24
  segments into 22 reference rows, among them the four advisory sessions of the llmroute A/B runs
  (`autoflow#594`, `#607`, `#630`, `#633`, which had carried arm A) and six sessions that had been
  merged into a cycle row of the same repository without performing it (`autoflow#2`, `#206`, `#217`,
  `#228`, `llmroute#279`, `#595`).
- A segment opens at the operator prompt that led to its first reference and closes 30 minutes past
  its last one (or where the next segment opens, or when an agent spawned inside it ends). Calls
  outside every segment are counted as unattributed, not charged to an issue.
- An issue row sums its segments across sessions; an agent belongs to the segment it started in.
- The orchestrator's base-context share is computed per segment — the context the segment opened
  with, times that segment's calls — and then summed, so it does not depend on the order the
  session records are read in; the merged call series is in time order.
- A segment's boundary with the next segment is exclusive; the session's own last record is
  included in its last segment.
- The artifact outcome columns belong to the arm that produced them: they are read for the AutoFlow
  arm only, and another arm's row — or a reference row — leaves them empty rather than borrowing them.
  They come from the issue's `.autoflow` artifacts — the archive copy, else the live
  directory: `cycle`, gate averages, ARCHITECT turns and rounds (per transcript file, `### Brief` blocks + 1 where it holds a turn, summed over the cycles' transcripts), the number
  of GATE:PLAN / AUDIT / GATE:QUALITY evaluation reports, `[review-autofix]` ledger headings, and,
  as auxiliary values beside the GitHub rounds below, `archive_reviewer_rounds` (`review-comment-*`
  files) and `archive_ci_*` (`issue-{N}-local/handoff-ci-*.log`). An archive CI round is judged by the
  `exit=<n>` line in its log, never by its position — a later log is often a green re-confirmation:
  `exit=12` (red build) is a failed round, any other non-zero exit (`confirm-ci-green.sh`: not
  mergeable, no check published, no verdict) is counted apart as `archive_ci_other_rounds`, and a log
  with no exit line is `archive_ci_undetermined` and counted as nothing else. Until #274,
  `confirm-ci-green.sh` also returned `exit=12` for a cancelled duplicate run, so an archive failed
  round can be a cancellation; the GitHub rounds below never count a cancelled attempt as a failure.
- **Reviewer and CI rounds** are read from GitHub, from the row's own PRs (the `pr-link` records of
  its segments), for **either arm** and for cycle rows only. `--gh` fetches each PR once it is closed
  — while it is open, on every `--gh` run — into `github/`: its state, each comment's time, author and
  whether it is in the configured reviewer's output format (a body starting `# Review Summary`,
  `.codex/review.md` > Output Format; no body is stored), and the workflow runs of its head branch
  from ten minutes before it opened to its close, with every attempt's conclusion. A run without
  `--gh` reads the cached copies. Per PR, then summed over the row's PRs:
  - `reviewer_rounds` — the configured reviewer's comments: a comment in that format posted after one
    of the row's own reviewer launches for that PR, the first such comment per launch, before the next
    launch and within two hours. A comment in the same format that no launch of the row's sessions
    accounts for — an evaluator's comparison, a review run elsewhere — is not counted: on llmroute #660
    the A/B evaluator's comparison is the fourth `# Review Summary` comment, and the row counts three.
    Across the 2026-09-23 data, 107 launches met 114 comments in that format and 100 were matched;
    launch to comment took 3.4 minutes at the median, 8.8 at p90 and 16.7 at most. A row whose record
    predates the launches (schema 2) leaves it empty.
  - `ci_rounds` — the head SHAs of the PR's runs that CI evaluated: at least one attempt of a run on
    that head ran (a head whose every run was cancelled or skipped was not evaluated).
  - `ci_fail_rounds` — the heads where an attempt concluded `failure`, `timed_out` or
    `startup_failure`. A `cancelled` attempt is not a failure; `ci_cancelled` counts those attempts.
  - `ci_reruns` — the attempts past the first of one run. A rerun evaluates the same head again, so it
    opens no round of its own. `issues.json` keeps, per PR and head, the runs, attempts, failed,
    cancelled and rerun counts behind these sums (`github`).
- **Operator decisions.** `operator_answers` counts the `AskUserQuestion` answers inside the row's
  segments, and `operator_decisions` is `operator_prompts + operator_answers` — every point at which
  the operator's input entered the session. Empty where either is not derivable.
- **Cost.** Deriving a cost from the token counts does not reproduce the harness's figure: a
  least-squares fit of each model's `costUSD` to its four token counts over the 2026-09-23 `cost-state`
  records gave negative unit prices and errors up to 26%. So `cost_usd` is the harness's own session
  total, and since that is
  not split by segment, it is a cycle row's only when every session of the row belongs to that cycle
  row and to no other; otherwise it is empty. It includes whatever the session did after the cycle
  in the same row. `operator_cost_usd` is the operator's own figure from `labels.tsv`.
- **A number is a count; an empty cell is "not recorded".** The artifacts the outcome columns are
  counted from were introduced over time, so an older archive holds none of them, and a 0 there
  would read as "no rounds" when nothing was recorded. Each metric is a number only where at least
  one of *its own* source artifacts exists, and is otherwise `null` in `issues.json`, empty in
  `issues.tsv` and "–" in the page:

  | Columns | Source artifact | Without it |
  |---|---|---|
  | `architect_turns`, `architect_rounds` | an `architect-transcript.md` (the relay transcript) | empty |
  | `archive_reviewer_rounds` | a `review-comment-*.md` | empty |
  | `archive_ci_rounds`, `archive_ci_fail_rounds`, `archive_ci_other_rounds`, `archive_ci_undetermined` | a `issue-{N}-local/handoff-ci-*.log` | empty |
  | `reviewer_rounds` | every PR of the row in `github/`, and the row's reviewer launches (schema 3) | empty |
  | `ci_rounds`, `ci_fail_rounds`, `ci_cancelled`, `ci_reruns` | every PR of the row in `github/` | empty |
  | `cost_usd` | a `cost-state` record for each session, none shared with another cycle row | empty |
  | `gate_plan_evals`, `audit_evals`, `gate_quality_evals` | that gate's evaluation report | empty |
  | `review_autofix`, `ac_decisions`, `ledger_entries` | the ledger | empty — and **with a ledger, 0 is a value**: the cycle recorded its decisions and none was an auto-fix |
  | `cycle`, the gate averages | the state file | empty |

  The scatter draws only rows that have a value for the chosen outcome and states below the chart
  how many it left out. On the first run of this rule, of 48 cycle rows: ARCHITECT 39 empty (the
  relay transcript first appears 2026-09-05), reviewer rounds 47, CI 48, GATE:PLAN / AUDIT /
  GATE:QUALITY reports 23 / 13 / 24, ledger-backed columns 4.
- **`kind`.** A session that references an issue's `.autoflow` files three times becomes a row
  whether or not it ran a cycle — drafting the issue, analysing a finished cycle. Such a row is all
  orchestrator and carries no outcome, and in the share-over-time chart it reads as a 100% point
  that hides the real cycles' 11–36%. A row is `cycle` when one of its sessions performed the issue,
  recorded as `kind_basis` in `issues.json` and `issues.tsv`, and `non-cycle` otherwise — a reference
  row always:
  - `label` — one of the row's sessions is labelled in `labels.tsv`, and the label names this issue
    or none (the other arm of a comparison has no state by construction and is never classified
    away; an explicit arm A label counts the same). A label that names another issue links nothing
    to this row, its minutes and its arm included;
  - `state-write` — one of its sessions wrote the issue's own state file. Any write counts, a forced
    termination (`active: false`) included.

  A row whose sessions' records cannot tell a state write (schema 2, a stripped copy) is classified
  as before issue #282:
  - `role-spawn` — at least one of its agents was spawned with an AutoFlow role
    (`subagent_type: autoflow-*`);
  - `state-date` — it has no role spawn, the issue's state file exists, and the state's `date` lies
    within a day of the row's segments.

  On the schema-3 records of 2026-09-23 the state-write rule found a write in 20 of the 22 sessions
  that had made a row `cycle` by an AutoFlow role spawn; the other two had spawned roles in a
  segment of an issue whose state they never wrote (`autoflow#2`, a session resolving #179;
  `llmroute#625`, a segment inside the #281 cycle) and are reference rows now. One row became a cycle
  that was not one before: `ontology-platform#218`, whose state a session set inactive.

  The table lists every row and marks the non-cycle ones; the two cross-issue charts draw `cycle`
  rows only, with a toggle to include the rest. On the first classification 8 of 56 rows were
  non-cycle; on 2026-09-23, 25 of 84.
- The repository name is the base name of the session's working directory, so two clones of one
  target fall into the same rows.

## A/B labels

`_metrics/labels.tsv`, tab-separated, written by hand:

```
session-id	arm	issue	operator_minutes	note	cost_usd
```

A session run without AutoFlow leaves no state file and no `.autoflow` reference, so this row is the
only thing that ties it to an issue: the whole session is attributed to the labelled issue. The two
arms of one issue are two rows (`repo#N` and `repo#N@B`). Operator prompt counts and wall time are
derived from the transcript for both arms; `operator_minutes` is the operator's own figure for the
arm they drove, and `cost_usd` (optional, the sixth column) the cost they read off the session. A
label is per session: an issue row **sums** the minutes and the cost of its labelled sessions, each
session once however many segments it has in that issue, and joins their notes in session order. A
value that is not a number adds nothing.

## Verification record

Issue #268's check on real data: the llmroute #593 session
(`f87197aa-8e24-4a7f-b4fe-a03986f0597e`) re-derives the hand-computed figures the issue cites —
cache read 456,429,536 over the session, 143,210,057 of it the orchestrator's, and the two ARCHITECT
participants' re-written wakes at 255,314 and 283,663 cache-write tokens.

Issue #282's check, on a copy of the store re-collected under schema 3 and `--gh` on 2026-09-23
(95 PRs of 59 cycle rows). Against the counts the operator had taken by hand from GitHub for the five
llmroute A/B issues (`labels.tsv` notes), the derived reviewer rounds agree per PR wherever the arm's
session did nothing after the note was written: #594, #606 and #633 both arms, #607 arm B (4 and 4),
#630 arm A (3 and 3 — the evaluator's comparison on #660 excluded). Three PRs counted more
because their session ran the reviewer again after the note: #607 arm A (#477 4, #656 3, against 1
and 1 at the evaluation; the PRs were adopted and merged the next day) and #630 arm B's #659 (4, one
launched at 16:28 before its merge). The CI rounds reproduce the noted cases: #606 arm A's
LibreChat#473 has one head whose first attempt was cancelled and whose rerun passed — 1 round, 0
failed, 1 cancelled, 1 rerun; #630 arm A's LibreChat#479 has the 3 heads noted, all with failed
attempts and 8 cancelled ones. The archive counted a failed round for #633 arm A where GitHub shows
a cancelled attempt and no failure.
