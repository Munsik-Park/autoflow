# ADR-0031: AutoFlow does not consider compaction

## Status

Accepted (operator decisions 2026-10-19, PR #475: "AutoFlow의 요구사항은 idle compaction off입니다.
auto compaction은 방어할 수 없습니다. 따라서 AutoFlow는 compaction을 고려하지 않습니다", and the
removal of the devices that exist only for compaction). Supersedes ADR-0027 D2's three compaction
bullets — the rules that must hold after a compaction first in the body within 18,000 bytes, and
the body's first line instructing a compacted session to invoke the command again — and ADR-0027's
amendment of `docs/tool-delivery-contract.md` R1 that CI checks "each command body's leading
section fits the compaction re-attach budget".

## Context

ADR-0027 D2 shaped the command bodies around Claude Code's compaction behavior (measurement M2:
after a compaction an invoked skill body is re-attached up to its first 5,000 tokens, 25,000 in
total). It put a `core:leading-end` marker in `docs/core.md`, split four core sections into a
leading part and a "(continued)" part, opened `/autoflow:cycle` with a re-invocation rule, and had
`tests/plugin/verify-skill-bodies.sh` check the leading part (18,000 bytes), the whole
criterion-review body (18,000 bytes) and the first body line.

The operator set the requirement that AutoFlow runs with idle compaction off; auto compaction
cannot be defended against, so AutoFlow does not consider it (issue #464 > 운영자 방침 already reads
"compaction은 AutoFlow에서 측정하거나 대비하지 않는다"). While #465 was in review, a rule added for a
compaction re-invocation (the "spent" rule of a `new` request) led to a further rule for its own
gap — the case ADR-0030 D9 records.

## Decision

**D1 — No device exists for compaction.** Removed:

- the `/autoflow:cycle` body's "After a compaction" re-invocation line and the description's "and
  again after a compaction";
- the `core:leading-end` marker in `docs/core.md`, with the four "(continued)" sections merged back
  into their sections (content unchanged), and the core's "After a compaction, re-read the current
  unit's document" sentence;
- the generator's marker handling (`scripts/skills/gen-skill-bodies.sh` `section`);
- `verify-skill-bodies.sh` legs B1 (first line, leading-part budget) and B2 (criterion-review body
  budget); the root-declaration leg stays as B1;
- the leading-part rule in the root `CLAUDE.md`, the budget check in
  `docs/tool-delivery-contract.md` R1, and `docs/units/preparation.md`'s "After a compaction" line.

**D2 — No size limit on a command body.** The 18,000-byte limits had no ground but the re-attach
cap: ADR-0027 derives them from M2 alone, and no document, check or issue in the repository gives
another. How much of the core a unit session receives is issue #464's question, which it settles by
cost, not by a limit.

**D3 — Kept: the read-dedup hook** (`hooks/check-read-dedup.sh`). Its stub dangles when the earlier
read is no longer in context; a rewind does that as well as a compaction (the hook's own record,
anthropics/claude-code#46749), so it does not exist for compaction alone.

## Alternatives Considered

- **Keeping the budget as a size discipline** — not taken: no ground other than compaction was found
  (D2), and a limit without its ground is a rule that keeps itself.

## Consequences

### Positive

- The core reads in one order, with no section split for re-attachment, and nothing is written or
  checked for a state AutoFlow does not run in.

### Negative

- A session that does compact runs without the re-invocation prompt; the requirement is idle
  compaction off.

### Neutral / Trade-Offs

- ADR-0027's measurement M2 stays as the record of the behavior it measured.

## Related Issues / PRs

- #465 (PR #475), #454 (ADR-0027), #464.
