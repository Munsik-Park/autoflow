# doc-invariant registry — anchor well-formedness fixture (issue #951)

Static fixture consumed by `tests/test-issue-951-registry.sh` (C6 anchor
well-formedness: a registry entry's `section` must resolve to exactly one
heading in its `file`). Not a doc-invariant target itself — do not add
this file to the registry as a real invariant source.

## Unique Heading

Anchor content unique-heading-body. A registry entry anchored on
`Unique Heading` must resolve to exactly this one heading (positive control).

## Duplicate Heading

Body variant A.

## Duplicate Heading

Body variant B. A registry entry anchored on `Duplicate Heading` must be
REJECTED at load time (ambiguous anchor — 2 matches) because this heading
text appears twice in this file.
