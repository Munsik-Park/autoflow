# ADR-0032: A unit session carries the parts of the core its unit uses

## Status

Accepted (issue #464: the operator set the per-unit session as the default operation and left the
method — per-unit commands, an argument choosing the body, how the parts are generated — to the
working AI, with the grounds in the pull request). Amends ADR-0027 D2 *Commands* and *The core*,
reverses ADR-0027 > Alternatives > *Per-unit commands*, retires the `unit=U1…U6` argument ADR-0030
kept (its Decision item 3 and *Positive*), and amends `docs/tool-delivery-contract.md` R2.

## Context

ADR-0027 D2 made `/autoflow:cycle <N> [unit=U1…U6]` the orchestrator's command in both operating
modes and generated its body from the whole core. A session started with `unit=Uk` therefore
received the whole core whatever its unit (15e0cda: `skills/cycle/SKILL.md` 48,965 bytes), and on
the 0.3.0 verification cycle (Munsik-Park/orca-autoflow#15) every main request carried it.

ADR-0027 rejected per-unit commands on three grounds, each about one session running all six
units: the compaction re-attach cap, the shared rules carried six times by a session invoking six
commands, and the re-attach budget. ADR-0031 removed the first and the third (AutoFlow does not
consider compaction). The second holds only for a session that invokes six commands; with a
session per unit (issue #464 > 운영자 방침) each session invokes one. The premise that the core
outside the transition rows is common to every unit had not been measured.

## Decision

**D1 — One command per unit.** `/autoflow:cycle-u1 <N> [new]` … `/autoflow:cycle-u6 <N>` start a
session that runs that unit alone, from its entry to its exit transition, after confirming from
`cycle-status.sh` that the cycle stands at the unit's entry. `/autoflow:cycle <N> [new]` runs the
whole cycle in one session and carries the whole core, as before (issue #464 > 운영자 결정
2026-10-18); its `unit=` argument is retired, and a session given one reports and stops. A skill
body is static text — one command has one body — so a body per unit needs a command per unit.

**D2 — The classification.** `scripts/skills/core-units.tsv` records which unit sessions use each
part of `docs/core.md`. The unit of classification is a `## ` section; a section whose parts are
used by different units is split into those parts (`### ` sections, paragraphs, bullets, table
rows, lines of a fenced block). A unit's use covers every way its session starts: the forward
entry, a re-entry on a FAIL, `impl` or `design` route, and the entry check from `cycle-status.sh`'s
facts — so the unit table, the Regressions line, the cap and accounting paragraph and the remedy
class recording are in every unit body they reach. A part used by a unit is in that unit's body;
the grounds of each entry are in the pull request that sets it.

**D3 — The unit body.** A unit's body is the command header, then the core's parts that name the
unit or `all`, in the core's order. The header names `<autoflow-root>/docs/core.md` as the place
to read a part left out, and lists the parts left out by heading path.

**D4 — The generator and its check.** `scripts/skills/gen-skill-bodies.sh` generates every body
from the core and the classification, and fails on a part of the core no entry classifies, a block
two entries match, and an entry that matches nothing; `--list` names every generated body, and the
checks that read command bodies take that list rather than naming bodies.

**D5 — The core's scope sentence.** The core retains what crosses a unit's boundary — the
cross-unit invariants and authority rules, the router, the caps, the Execution Principles and the
state rules — and not "only what every unit needs": not every part binds every unit.

## Alternatives Considered

- **An argument that chooses the body** — not possible: a skill's body is fixed text, and the
  `$ARGUMENTS` substitution changes words inside it, not which sections it carries.
- **A body that names unit fragments to read on entry** — not taken: the rules would reach the
  session through a later `Read` rather than the command body, and the whole-cycle session, which
  must keep the whole core in its body, would need a second body anyway.
- **Classification markers inside `docs/core.md`** — not taken: a table row or a fenced line
  cannot carry a marker without breaking the table or the block, and a marker that covers what
  follows it lets a newly added part inherit a classification silently.

## Consequences

### Positive

- A unit session's first request no longer carries the core parts its unit does not use, and a
  new `## ` section, or a new block of a split section that no entry matches, fails the generation
  instead of reaching the bodies unclassified; a new block an existing prefix entry matches (a
  table row under a `|` entry) takes that entry's units.

### Negative

- Eight command descriptions instead of two appear in every session's skill listing.
- Most of the core is used by every unit (the Execution Principles, the ledger, the spawn and
  communication rules), so the unit bodies stay large; the measured reduction is the pull request's.

### Neutral / Trade-Offs

- `/autoflow:cycle <N> unit=Uk` invocations in an operator's machine-local procedure become
  `/autoflow:cycle-uk <N>`.

## Amendments

### ADR-0027 D2

- *Commands*: `/autoflow:cycle <N> [new]` runs the whole cycle; `/autoflow:cycle-u1 <N> [new]` …
  `/autoflow:cycle-u6 <N>` run one unit in the coordination mode, whose launching procedure stays
  machine-local.
- *The core*: every command body is generated from `docs/core.md`, the cross-unit invariants and
  authority rules; the whole-cycle body carries all of it, a unit's body the parts its unit uses
  (D2, D3), and the criterion-review body the sections its stage is bound by.
- *Alternatives > Per-unit commands*: reversed by D1.

### `docs/tool-delivery-contract.md` R2

The command that starts a session is `/autoflow:cycle`, a unit's `/autoflow:cycle-u1` …
`/autoflow:cycle-u6`, or `/autoflow:criterion-review`.

## Related Issues / PRs

- #464, #454 (ADR-0027), #465 (ADR-0030), PR #475 (ADR-0031), #369 (ADR-0025).
