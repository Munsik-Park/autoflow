# Issue #114 — Manual/Environment-Dependent Verification Scenarios

Two items in `.autoflow/issue-114-verification-design.md` have no in-repo automated
observer and are discharged here rather than by a committed CI leg:
`AC-oversized-payload-demonstration` (§3) and, as a note only (it needs no scenario
steps of its own — see below), `AC-no-ci-retry-recurrence` (§3). Every other
acceptance criterion is discharged by an automated leg — the standing structural
guard and the two doc-convention legs added to
`tests/test-issue-964-sigpipe-safe-pipes.sh` (`AC5-A`, `AC6-A`, `AC6-B`), the
existing `tests/plugin/verify-install-into-target.sh` `AC2e` leg for the derived
manifest, and the before/after verdict-sequence comparison over
`tests/test-issue-952-wizard-removal.sh` performed directly by the Test AI/Developer
AI at RED (baseline capture) and VERIFY (re-run + diff) rather than as a committed
spec file (verification design §6: no new spec file besides this one).

---

## AC-oversized-payload-demonstration — the here-string replacement is safe above pipe capacity; the piped form is not

**Why not automated:** the outcome is a function of the runner's pipe capacity, an
environment property no shell suite in this repository observes or controls
(verification design §1.2/§3). Committing the sweep as a CI-gated assertion would
introduce a *new* environment-dependent red — the exact failure class this issue
exists to remove. The oracle below is phrased so it is evaluable without knowing
the boundary in advance, per verification design §3 > *Oracle — three properties*.

### Fixed inputs

- A POSIX shell on the operator's host, `bash` and `grep` available, `set -uo
  pipefail` in effect for the sweep script.
- A needle placed at the **head** of the swept payload (match position matters —
  a needle at the end lets the consumer drain the pipe before matching, which
  does not exercise the hazard).
- A size range that brackets this host's actual pipe capacity — start well below a
  plausible floor (e.g. 4 KB) and sweep upward past a plausible ceiling (e.g.
  4 MB), doubling or otherwise stepping finely enough to bracket the flip.

### Steps

1. Write a small sweep script (or reuse a throwaway one) that, for each payload
   size `S` in the range and for several repetitions at each `S`:
   - builds a payload of size `S` bytes with a fixed needle at byte offset 0,
   - runs the **piped** form under `pipefail`:
     `printf '%s\n' "$ctx" | grep -qF "$NEEDLE"` and records the pipeline's exit
     status,
   - runs the **here-string** form under the same `pipefail`:
     `grep -qF "$NEEDLE" <<<"$ctx"` and records its exit status.
2. Record, per size, whether every repetition of the piped form agreed (all pass
   or all fail) and whether every repetition of the here-string form passed.
3. Evaluate the three properties from verification design §3 against the
   collected data:
   - **Monotone step, not a race** — across the swept range, the piped form's
     outcomes form a single pass→fail transition: no size passes above a size
     that failed, and at each size the repetitions are unanimous (no "usually
     fails" band).
   - **The replacement is unconditionally safe** — the here-string form passes on
     every repetition at every swept size, including the largest.
   - **The sweep actually crossed the boundary** — at least one swept size fails
     under the piped form (otherwise the sweep sat entirely below capacity and
     evidences nothing).
4. Record the outcome — `passed` (all three properties hold) or `deviation` (name
   which property failed and at what size) — with the sweep script and its raw
   per-size/per-repetition output as the anchor.

### Expected outcome

The piped form's outcomes form one monotone step across the swept range with no
intermediate band; the here-string form passes at every size in the range,
including sizes above the piped form's failure threshold; and at least one swept
size demonstrates the piped form actually failing, confirming the sweep crossed
the boundary rather than staying entirely below it.

---

## AC-no-ci-retry-recurrence — note, no scenario steps

Per verification design §3, this item is **not verifiable within this cycle**: no
artifact can assert "this failure does not recur", and a same-host soak loop
proves nothing under §1.2 because the outcome is deterministic in an environment
term (pipe capacity) that does not vary across iterations on one host. It is
discharged at VALIDATE by the standing structural leg (`AC5-A` — a reintroduced
hazard shape reds immediately) plus the recorded reopen criterion: since §1.3
establishes the reported CI reds are not reproduced by the stated mechanism at the
suite's real payload sizes, a green CI run after the conversion is regression
evidence only, and a recurrence of the same error text after every pipe at these
sites is removed points to a residual cause elsewhere — an informative reopen, not
a repeat. No manual scenario is written for this item; this note exists so the
item is not left dangling (verification design §3's own instruction).
