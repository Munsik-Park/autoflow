# Issue Proposal — Draft Grammar and Filing Procedure

An issue is filed from a **draft on disk**, never from arguments typed at the
moment of filing. `gh issue create` is denied at the tool boundary
(`.claude/hooks/check-autoflow-gate.sh` > Section 1); the only filing path is:

```bash
scripts/issue/create-issue.sh --draft <path> [--repo <owner/name>] [--dry-run]
```

## Why the draft is mandatory

The obligation to check for duplicates before filing used to be prose. An agent
could state that it had searched, and file regardless — the statement and the
act had no mechanical relation, so an incomplete check and a thorough one
produced the same output. The wrapper removes the gap: it derives search terms
from the draft's **own title**, runs the query itself, and then compares what
that query returned against the candidates the draft dispositioned. It never
judges whether a disposition is *correct* — that judgment is the operator's, at
layer three. It refuses when the draft disposes of nothing the wrapper found.

Three layers guard the path, and each covers what the others cannot:

| Layer | Mechanism | What it stops |
|-------|-----------|---------------|
| 1 | hook deny on `gh issue create` and its REST form | filing that bypasses the wrapper entirely |
| 2 | `scripts/issue/create-issue.sh` re-runs the query and compares dispositions | filing on an asserted-but-unperformed check |
| 3 | the operator permission prompt on the wrapper | filing without a human in the loop |

Layer three works by **omission**. The recommended allow-list entry for a script
of this shape would be `"Bash(scripts/issue/create-issue.sh:*)"` — and it is
deliberately **not** shipped in any allow list, so invoking the wrapper raises an
approval prompt. Adding that entry, or a broad `Bash(scripts/*)` /
`Bash(scripts/issue/*)`, to `.claude/settings.json` or
`.claude/settings.local.json` silently disables layer three: the wrapper still
runs, but nobody is asked. Keep the wrapper off every allow list.

## Draft grammar

Write the draft **directly inside** `.autoflow/`, at its top level. That is the
directory the cleanup archive matcher searches at `maxdepth 1`; a draft under
`.autoflow/fixtures/` would be archived into a different slot, and one deeper
still into none, so the wrapper refuses both.

Four required level-2 sections, in **any order** — each runs from its own
heading to the next level-2 heading or to end of file:

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

| Section | Content | Wrapper's check |
|---------|---------|-----------------|
| `## Title` | one line — the issue title | non-empty single line |
| `## Grounds` | why the issue is warranted | at least one anchor: a `path:line`, a commit SHA, or a URL |
| `## Duplicate check` | a `searched:` line listing the query terms, then either `candidates: none` or one `#<number> — <disposition>` row per candidate | the `searched:` line is present and non-empty; its tokens feed the term derivation; the candidate rows are the set the disposition invariant compares against |
| `## Body` | the text from its heading to the next level-2 heading | non-empty; becomes the issue body |

The grammar is deliberately thin. It exists so the wrapper can perform a
mechanical comparison — not to make the draft a form an agent fills in to earn a
pass.

## The two names of the artifact

| Stage | Path | Swept by the cleanup archive matcher? |
|-------|------|---------------------------------------|
| Before creation (draft) | `.autoflow/issue-proposal-<slug>.md` | **no** — deliberate |
| After creation | `.autoflow/issue-<N>-proposal.md` | **yes**, with issue `<N>`'s cycle |

A draft has no issue number, so no name available to it can be swept by a matcher
keyed on digits — an unfiled draft therefore outlives any other issue's cleanup,
which is correct, because it belongs to no cycle and only its author can abandon
it. Once the issue exists the artifact does belong to a cycle, and the wrapper's
rename puts it in the `issue-<N>-*` companion form the matcher sweeps.

## What the wrapper does

1. Refuses unless the draft is a regular file directly inside the repository's
   `.autoflow/`. The directory being **absent** is diagnosed separately from a
   misplaced draft, with a different message: a target that has never run
   PREFLIGHT would otherwise be told only that its draft is elsewhere, and could
   not tell that *nothing* is elsewhere. The wrapper does not create the
   directory. A draft that is itself a symlink is refused rather than resolved —
   renaming a link would move the link and leave the content outside every
   cycle's archival set.
2. Refuses a draft missing any required element, naming **every** missing one so
   the caller can repair it without guessing.
3. Derives title terms by a rule with no implementation freedom: strip a leading
   `[tag]`; lowercase the ASCII range only; split on whitespace and ASCII
   punctuation, with bytes outside ASCII never acting as separators, so a
   non-ASCII run survives as one token; keep a token of `[a-z0-9]` at ≥ 4
   codepoints and a token carrying non-ASCII at ≥ 2; deduplicate keeping first
   appearance; keep the first 8. Codepoints are counted **locale-free** —
   `wc -m` disagrees with itself across locales and would derive a different
   query on a different machine.
4. Appends the `searched:` line's tokens under the same lowercase/separator rule,
   with no floor and no cap. Recorded terms are strictly **additive**: they can
   only lengthen the query, so a narrow recorded search can never shrink the
   wrapper's own.
5. Refuses if the title derives **no** term. With it empty the query would
   collapse to the draft's own recorded terms and the wrapper would be re-running
   the agent's search while calling it independent verification.
6. Runs **one query per term**, `--state all`, `--limit 100`. A single joined
   query ANDs its terms inside one argument and collapses to near-zero results,
   under-blocking by construction. If any one term returns a full page, that
   term's candidate set is provably incomplete → refuse, naming the term.
7. Refuses if any returned issue number is not already dispositioned in the
   draft, listing the undispositioned numbers.
8. On success — and only then — renames the draft to
   `.autoflow/issue-<N>-proposal.md`, with `<N>` parsed from the URL `gh`
   returned. A URL with no parsable trailing number is a failed bind: the draft
   stays put rather than being renamed to a guess.

`--dry-run` runs every check and creates nothing, leaving the draft in place.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | created, or `--dry-run` passed every check |
| `64` | usage, or the draft is not directly inside the derived `.autoflow` (including that directory being absent) |
| `65` | refusal — missing section, no grounding anchor, no derivable term, an undispositioned candidate, or a query at its page limit |
| `70` | the issue was created but its number could not be bound |
| other | `gh`'s own exit, propagated |

The floors, the cap, the tag strip and their order are **fixed constants in the
script, not flags**. An agent-tunable derivation is an agent-authored query,
which is the one thing layer two must not accept; an unrecognised argument is a
usage error.

## Accepted limits

These are stated rather than argued away — each is an under-block the design
accepts, with layer three as the catch:

- The term cap drops terms on ordinary titles, so a duplicate reachable only
  through a dropped term is never surfaced, and the wrapper reports a clean
  check. Raising the cap trades this for truncation refusals on the tracker's
  commonest terms.
- A term is queried in the surface form the title wrote, so a duplicate phrased
  with a different inflection of the same word falls outside the candidate set.
  Querying stems would require script-specific morphology — exactly the judgment
  layer two exists to avoid.
- On a large tracker a common derived term can return a full page and trip the
  truncation refusal, leaving the agent unable to file until a human intervenes.
  Deliberate: the escape is the operator's, not the agent's.
- Creation through a non-`gh` client (a raw `curl` with a token) is not matched,
  and quoted or command-substituted evasion of the deny is stripped by the hook's
  scan exactly as it is for every other Section 1 deny. The threat model is the
  routine self-authorized filing, not a determined evasion.
