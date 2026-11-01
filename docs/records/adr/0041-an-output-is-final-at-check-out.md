# ADR-0041: An output is final at check-out

## Status

Proposed (issue #560). Extends check-out's result (ADR-0038 D1, ADR-0039 D3). ADR-0038 D1's "runs
once" and ADR-0040 D2's "the checks see form, each file read alone" stand.

## Context

`contract.sh` refuses a second check-out and a check-in once `<out>/result.json` exists, and the
result recorded each output's path and nothing of its content. Sessions corrected outputs after
check-out: issue #560 reports three review rounds, and the records hold seven runs, six reviews and
one analysis, with a declared output newer than the result by 5 to 42 seconds. The time shows that a
file was written, not what changed. No document ordered an output's verification against check-out,
and the review's `findings` output has `"checks": []`, so its check-out passes before its anchors
are verified. A later reader could not tell whether the file was the one check-out saw.

## Decision

**D1 — The run finishes first.** The run verifies its outputs and makes its corrections before
check-out, which is its last act on them. The core, the command bodies' Scope and the analysis and
review procedures state it.

**D2 — The result records each output's identity.** `result.json` gains `sha256`: each file
`outputs` records, by path, with its digest. `outputs` keeps its shape. `contract.sh verify
<invocation.json>` reads the result and reports each output that is `changed:`, `missing:` or
`added:`, exit 1, and exit 0 when none is. It reports; what is done with a difference is the running
side's (ADR-0038 D2). Check-in does not read it: where an input came from is not checked (Q19).

**D3 — A later correction leaves a record or takes a new run.** A correction that changes a
conclusion — a verdict, a finding's disposition, a score — or the form check-out checked is a new
run in a new directory (Q3). One that changes neither, such as a line number or the wording of a
ground, may be made in place; whoever makes it appends to `<out>/corrections.md` the file, what
changed and why, and the run's report states it. The note is not a contract output: check-out runs
before it exists and reads declared outputs only.

## Alternatives Considered

- **The rule alone (D1 without D2).** Rejected: a breach stays invisible, and a rule changes with
  the device that enforces it (`docs/core.md` > Rule Scope, principle 4).
- **The digest alone (D2 without D1 and D3).** Rejected: it shows that a file differs, not why, and
  leaves the session with no sanctioned order or path.
- **Every correction a new run.** Rejected: a review's new run calls its reviewers again, out of
  proportion to a line number. It stays the path for a correction that changes a conclusion.
- **A re-runnable or amending check-out.** Rejected: it contradicts "runs once" and the refusal of a
  directory holding a result, and rewriting the result would erase what check-out saw.
- **Content checks on the review's report.** Separated: a check of anchors reads beyond one file's
  form and would reopen ADR-0040 D2.

## Consequences

### Positive

- The record tells whether an output is the file check-out recorded, without a transcript.
- A correction made in place has a stated reason beside the output.

### Negative

- Nothing prevents an edit after check-out, and no module runs `verify` by default; a difference is
  seen when someone runs it.
- `<out>/corrections.md` is written by hand and is not itself digested; `verify` shows a change, not
  whether the note is complete or true.
- A result written before this decision has no `sha256`; `verify` exits 2 on it.
- `verify` compares against the paths the result records, so a moved record directory reads as
  `missing:`.

## Relation to other decisions

- **ADR-0038** — D1's one run stands; check-out's result gains a key. D2 is applied: `verify` reports
  and the running side decides.
- **ADR-0039** — D3's `failed` result carries the digests of the outputs it records.
- **ADR-0040** — D2 stands: a digest reads one file alone and judges nothing of its content.

## Related Issues / PRs

- Issue #560.
