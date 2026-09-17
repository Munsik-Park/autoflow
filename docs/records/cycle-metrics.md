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
no file in this repository or in a target repository is created or changed.

| Path | Written | Content |
|---|---|---|
| `sessions/<session-id>.json` | once per session | the session aggregate (below) |
| `issues.tsv`, `issues.json` | every run, from `sessions/` | one row per issue and arm |
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
`--no-collect` (re-derive only), `--gh` (ask `gh` for each linked PR's state; the only network use).

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
`--projects-root`. A record with no covering source is left exactly as it is, on its older schema;
the run reports how many (`schema 2: upgraded N from the transcripts, N from a preserved copy; N
kept on an older schema`), `issues.tsv` counts them per row (`stale_schema_sessions`), and a later
run retries. A record is never deleted to be rebuilt. Schema 2 (the agent role from the declared
`subagent_type`) upgraded 195 records from the transcripts and 2 from the preserved copy, with none
left behind.

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
  directory, git branches.

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
- A segment opens at the operator prompt that led to its first reference and closes 30 minutes past
  its last one (or where the next segment opens, or when an agent spawned inside it ends). Calls
  outside every segment are counted as unattributed, not charged to an issue.
- An issue row sums its segments across sessions; an agent belongs to the segment it started in.
- The orchestrator's base-context share is computed per segment — the context the segment opened
  with, times that segment's calls — and then summed, so it does not depend on the order the
  session records are read in; the merged call series is in time order.
- A segment's boundary with the next segment is exclusive; the session's own last record is
  included in its last segment.
- Outcome columns belong to the arm that produced them: they are read for the AutoFlow arm only, and
  another arm's row leaves them empty rather than borrowing them. They come from the issue's `.autoflow` artifacts — the archive copy, else the live
  directory: `cycle`, gate averages, ARCHITECT turns and rounds (per transcript file, `### Brief` blocks + 1 where it holds a turn, summed over the cycles' transcripts), the number
  of GATE:PLAN / AUDIT / GATE:QUALITY evaluation reports, `[review-autofix]` ledger headings,
  reviewer rounds (`review-comment-*` files), CI rounds (`issue-{N}-local/handoff-ci-*.log`). A CI
  round is judged by the `exit=<n>` line in its log, never by its position — a later log is often a
  green re-confirmation: `exit=12` (red build) is a failed round, any other non-zero exit
  (`confirm-ci-green.sh`: not mergeable, no check published, no verdict) is counted apart as
  `ci_other_rounds`, and a log with no exit line is `ci_undetermined` and counted as nothing else.
- **`kind`.** A session that references an issue's `.autoflow` files three times becomes a row
  whether or not it ran a cycle — drafting the issue, analysing a finished cycle. Such a row is all
  orchestrator and carries no outcome, and in the share-over-time chart it reads as a 100% point
  that hides the real cycles' 11–36%. A row is `cycle` when any one of these holds, recorded as
  `kind_basis` in `issues.json`, and `non-cycle` otherwise:
  - `label` — the row is tied to its issue by `labels.tsv` (the other arm of a comparison has no
    state by construction and is never classified away);
  - `role-spawn` — at least one of its agents was spawned with an AutoFlow role
    (`subagent_type: autoflow-*`);
  - `state-date` — it has no role spawn, the issue's state file exists, and the state's `date` lies
    within a day of the row's segments. The state file is looked up by issue number, so a later
    session that only read a finished cycle's files finds that cycle's state too; the date keeps a
    cycle that stopped right after PREFLIGHT or at triage and drops the reader.

  The table lists every row and marks the non-cycle ones; the two cross-issue charts draw `cycle`
  rows only, with a toggle to include the rest. On the first classification 8 of 56 rows were
  non-cycle.
- The repository name is the base name of the session's working directory, so two clones of one
  target fall into the same rows.

## A/B labels

`_metrics/labels.tsv`, tab-separated, written by hand:

```
session-id	arm	issue	operator_minutes	note
```

A session run without AutoFlow leaves no state file and no `.autoflow` reference, so this row is the
only thing that ties it to an issue: the whole session is attributed to the labelled issue. The two
arms of one issue are two rows (`repo#N` and `repo#N@B`). Operator prompt counts and wall time are
derived from the transcript for both arms; `operator_minutes` is the operator's own figure for the
arm they drove. A label is per session: an issue row **sums** the minutes of its labelled sessions,
each session once however many segments it has in that issue, and joins their notes in session
order. A value that is not a number adds nothing.

## Verification record

Issue #268's check on real data: the llmroute #593 session
(`f87197aa-8e24-4a7f-b4fe-a03986f0597e`) re-derives the hand-computed figures the issue cites —
cache read 456,429,536 over the session, 143,210,057 of it the orchestrator's, and the two ARCHITECT
participants' re-written wakes at 255,314 and 283,663 cache-write tokens.
