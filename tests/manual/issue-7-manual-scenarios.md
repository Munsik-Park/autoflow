# Issue #7 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

This is an **operator record**, not a verification path. It discharges **no acceptance
criterion** — every live AC in the canonical set
(`.autoflow/issue-7-verification-design.md` §1.0) has an automated oracle in
`tests/test-issue-7-oracle-hardening.sh`. This file exists because two of that suite's
premises (B7, B8) and the O3 interrupt-leg oracle (B20) were measured only on
**bash 5.3.9, darwin arm64**, and issue #7 puts a second platform,
`ubuntu-latest`, into play the day AC-7-7d's CI registration lands
(`.autoflow/issue-7-verification-design.md` §2, "the manual-scenario lane is the
standing per-cycle convention" — B22, three of the three most recent cycles carry the
same kind of record: `tests/manual/issue-42-manual-scenarios.md`,
`issue-43-manual-scenarios.md`, `issue-27-manual-scenarios.md`).

**Coverage boundary, stated plainly.** The automated suite proves the hardened
oracle discriminates a real emitter fault (O2) and, once GREEN ships
`GUARD_CONTRACT_WORKROOT_PARENT`, that an interrupted run leaves no temp tree behind
on **this** host. It does not and cannot prove the two host-dependent measurements
below hold on a different kernel/mktemp implementation. That gap is what M1/M2 record.

---

## M1 — `mktemp -d` TMPDIR-vs-`-p` scoping on a GNU coreutils host (Tier 3, environment-dependent)

**Source measurement:** B8 (verification design §0) — on darwin, `mktemp -d` ignores
`$TMPDIR` but honours `-p`. This is *why* `GUARD_CONTRACT_WORKROOT_PARENT` is
implemented as a `-p` override rather than a `$TMPDIR` override (feature design §4.1,
§7).

**Why not automated:** the divergence is a property of the host's `mktemp`
implementation, not of this repo's code; CI runs `ubuntu-latest` (GNU coreutils),
which this suite has no way to provision locally.

**Steps (run on a non-darwin/GNU-coreutils host, e.g. the `ubuntu-latest` CI runner or
a local Linux container):**

1. `env TMPDIR=/tmp/probe-tmpdir /usr/bin/mktemp -d` — record whether the result is
   under `/tmp/probe-tmpdir` or under the platform default.
2. `/usr/bin/mktemp -d -p /tmp/probe-p` — record whether the result is under
   `/tmp/probe-p`.

**Pass condition:** step 2 is honoured (`-p` scoping works) regardless of what step 1
shows. If step 2 is *not* honoured on some future host, `GUARD_CONTRACT_WORKROOT_PARENT`
stops being a valid interrupt-leg seam on that host and AC-7-5n's O3 oracle in
`tests/test-issue-7-oracle-hardening.sh` would need re-design — this scenario exists to
catch that before it is discovered as a silent CI red.

---

## M2 — `EXIT`-trap timing and interrupted-child `wait` status on `ubuntu-latest` (Tier 3, environment-dependent)

**Source measurements:** B7 (a trapped `EXIT` handler is deferred until the running
foreground command returns) and B20 (`wait` returns rc 0 for a `SIGINT`-killed child —
the oracle must not assert on the child's exit status). Both were measured on bash
5.3.9, darwin arm64.

**Why not automated:** CI itself is the only reproducible non-darwin environment this
project runs in, and the automated `AC-7-5n` O3 legs in
`tests/test-issue-7-oracle-hardening.sh` already run there via AC-7-7d's CI
registration — this scenario is the operator's manual cross-check for a human
reviewing a CI failure on that leg, not a scenario this repo's tooling can run
elsewhere on demand.

**Steps (on `ubuntu-latest`, or a Linux host with bash >= 5):**

1. Run `bash tests/test-issue-7-oracle-hardening.sh` and observe the `AC-7-5n-TERM-*`
   / `AC-7-5n-INT-*` lines.
2. If either leg reports unexpectedly, check whether the deferred-handler timing (B7)
   or the rc-0-on-INT-reap behavior (B20) differs on this host — e.g. by re-running the
   minimal probe scripts described in verification design §0 B7/B20 directly on the
   runner (`trap ... EXIT`, `kill -TERM`/`kill -INT`, `wait`, inspect `$?` and the
   parent directory's contents).
3. Record the observed behavior here (append a dated note) if it diverges from the
   darwin measurements, so a future reader does not re-derive this from scratch.

**Pass condition:** the parent-empty assertion holds after reap + settle on this host
too, and the child's exit status (whatever it is) is not what the suite's own
assertions key off of — confirmed by reading `tests/test-issue-7-oracle-hardening.sh`'s
O3 block, which asserts only the poll (non-vacuous) and the post-reap parent state.

---

**Change-surface note.** This file is itself a member of the F1–F10 canonical
change-surface allow-list (`.autoflow/issue-7-verification-design.md` §1.0,
`.autoflow/issue-7-feature-design.md` §2) and is registered in all six prior-cycle
scope guards' `allow_list` arrays alongside `tests/test-issue-1-guard-contract.sh` and
`tests/test-issue-7-oracle-hardening.sh`.
