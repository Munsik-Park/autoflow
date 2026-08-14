# Issue Proposal — Draft Grammar and Filing Procedure

An issue is filed from a **draft on disk**, never from arguments typed at the
moment of filing. `gh issue create` is denied at the tool boundary
(`.claude/hooks/check-autoflow-gate.sh` > Section 1); the only filing path is:

```bash
scripts/issue/create-issue.sh --draft .autoflow/<name>.md
```

## Why the draft is mandatory

The obligation to check for duplicates before filing used to be prose. An agent
could state that it had searched, and file regardless — the statement and the
act had no mechanical relation, so an incomplete check and a thorough one
produced the same output. The wrapper removes the gap: it derives the search
terms from the draft's **own title** and runs the search itself. A draft cannot
narrow its own check, because the `searched:` line it records is unioned onto
the derived terms and never subtracted from them.

Three layers guard the path, and each one covers what the others cannot:

| Layer | Mechanism | What it stops |
|-------|-----------|---------------|
| 1 | hook deny on `gh issue create` and its REST form | filing that bypasses the wrapper entirely |
| 2 | `scripts/issue/create-issue.sh` re-runs the search | filing on an asserted-but-unperformed check |
| 3 | the operator permission prompt on the wrapper | filing without a human in the loop |

Layer three works by **omission**: the wrapper is deliberately absent from every
shipped allow-list, so invoking it raises an approval prompt. Adding a broad
`Bash(scripts/*)` or `Bash(scripts/issue/*)` entry to `.claude/settings.json` or
`.claude/settings.local.json` silently disables it — the wrapper still runs, but
nobody is asked. Keep the wrapper off the allow-list.

## Draft grammar

Write the draft to the **top level** of `.autoflow/`. A subdirectory is outside
the cycle archive's `maxdepth 1` sweep, so a draft parked there would not be
collected with the rest of the issue's files; the wrapper refuses one.

Sections are `## `-headed and may appear in **any order**:

```markdown
## Title
[feat] one line, exactly as the issue title should read

## Grounds
scripts/issue/create-issue.sh:120 — the check runs here, not in the caller

## Duplicate check
searched: create-issue duplicate gate
candidates: none

## Body
The issue body, verbatim. Everything here — and nothing from the other
sections — becomes the created issue's body.
```

| Section | Required content |
|---------|------------------|
| `## Title` | one non-empty line; a leading `[tag]` is classification, not subject matter, and is excluded from the search terms |
| `## Grounds` | at least one verifiable anchor — a `path:line`, a commit SHA, or a URL |
| `## Duplicate check` | a `searched:` line naming the terms you searched; add candidates you found, or `candidates: none` |
| `## Body` | non-empty; this is the only section that reaches GitHub |

## What the wrapper does

1. Refuses unless the draft sits at the top level of the repository's `.autoflow/`.
2. Refuses a draft missing any required section, or a `## Grounds` section with
   no anchor.
3. Derives search terms from the title: a leading `[tag]` is stripped, the rest
   is split on whitespace, and each token must clear a length floor — 4
   codepoints for an all-ASCII token, 2 for one carrying non-ASCII. Shorter
   tokens match most of the tracker and would make every draft collide. If
   nothing survives, the check would be vacuous and the wrapper refuses.
4. Unions in the terms from the `searched:` line, then runs **one query per
   term**. A single joined query is an AND across the terms and recalls only a
   near-identical title; the union across per-term queries is what recalls a
   paraphrase.
5. Refuses if any query recalls an open issue, naming it, or if any query comes
   back on a saturated page — a full page means the answer was cut off, so
   "no duplicate here" is a claim about the page, not about the tracker.
6. On success, renames the draft to `.autoflow/issue-<N>-proposal.md`, binding
   the record to the number GitHub actually assigned. A rename to a guessed
   number is never performed: if the number cannot be read back, the draft is
   left where it is.

The search is scoped to **open** issues. A closed issue is a decision already
taken, so it is not live work a new filing would duplicate; re-filing against a
closed decision is a judgment the author makes, with grounds.

`--dry-run` runs every check and creates nothing, leaving the draft in place.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | created, or `--dry-run` passed every check |
| `64` | usage or precondition — bad arguments, no `.autoflow/`, draft outside its top level |
| `65` | draft data — malformed draft, underivable title, duplicate recalled, saturated page |
| `70` | the issue was created but its number could not be read back |
| other | `gh`'s own exit, propagated |

The derivation takes **no options**. A flag that could cap or widen the term set
would let the caller satisfy the duplicate check by shrinking it, which is the
failure this wrapper exists to remove; an unrecognised argument is a usage
error.
