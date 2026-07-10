# doc-invariant registry — 797 non-vacuity positive-control fixture (issue #951)

Static fixture consumed by `tests/test-issue-951-registry.sh` (C5 / AC1 797
whole-file `absent` non-vacuity check). Two variants of the same file are
needed at test time: this CLEAN variant (the wrong-dialect literal absent —
the registry entry must PASS) and a runtime-seeded copy where the RED suite
injects the wrong-dialect literal (the registry entry must FAIL). The RED
suite makes the seeded copy in a temp path; this committed file is the clean
baseline only.

## Sample section

This section deliberately contains no dialect violation. Ordinary prose only.
