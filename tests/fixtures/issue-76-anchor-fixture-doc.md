# Fixture document for issue #76 anchor-resolution negative coverage

This document is a hermetic fixture — it is never read by `tests/run-doc-invariants.sh`'s
real registry, only by the fixture registries in `tests/fixtures/issue-76-anchor-*.json`,
driven from `tests/test-issue-76-runner-self-test-contract.sh`.

| 1 | a table row that appears twice below, making the "| 1 |" anchor AMBIGUOUS |
| 1 | the second occurrence of the same leading cell |
| 3 | a table row that appears exactly once — the VALID single-match "line" case |

**Unique Bold Lead**
This paragraph is the body of the unique bold-lead block. It runs until the
next terminator — a thematic break, since no `section_end` is set for this
entry and no heading follows before the break.

---

**Duplicate Bold Lead**
first occurrence body.

**Duplicate Bold Lead**
second occurrence body — this duplicate is what makes the "**Duplicate Bold
Lead**" anchor AMBIGUOUS under a `"line"`/`"block"` section_kind.

**Block With Explicit End**
line one of the block.
line two of the block.
BLOCK_TERMINATOR_MARKER
line three — outside the block, after the explicit section_end terminator.
