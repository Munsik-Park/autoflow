# Issue #100 — Manual/Environment-Dependent Verification Scenarios

Only one acceptance criterion is delegated here per the verification design
(`.autoflow/issue-100-verification-design.md` §1, `AC-real-world-latency` row —
type `manual`). Every other criterion carries a concrete automated method:
`tests/test-bounded-execution-fallback.sh` (the fallback-behavior legs against
the two shipped scripts and the static site-closure lint) or a directly
re-derivable static check.

---

## M1 — `AC-real-world-latency`: the reported symptom is gone on a real coreutils-less machine

**Status: delegated to user.**

**Source AC:** `AC-real-world-latency` — the reported symptom (a piped run of a
real suite finishing long after its last assertion, on a machine without GNU
`timeout`/`gtimeout`) is gone.

**Why not automated:** GitHub-hosted CI runners always carry `timeout`, so the
naturally-occurring form of the defect — a genuinely coreutils-less machine —
is unreachable there; it can only be forced with a sanitized `PATH`, which is
exactly what `AC-pipe-release`
(`tests/test-bounded-execution-fallback.sh`) already does as the deterministic
surrogate for this scenario. This manual run exists to confirm the surrogate
actually models the real box, not to replace it.

**Relationship to the automated surrogate, stated explicitly:** `AC-pipe-release`
forces the fallback branch by prepending a sanitized `PATH` in front of a real
invocation of `scripts/preflight/check-review-backend.sh --probe`, and asserts
(via bash `SECONDS`) that a piped reader reaches EOF at subject completion
rather than at the watchdog's bound. That is a hermetic, repeatable proxy for
the same mechanism this scenario exercises informally, by hand, on a machine
that lacks the coreutils binaries for a genuine (not `PATH`-forced) reason.
A pass here with no corresponding change in `AC-pipe-release`'s own behavior
is expected — it is confirmation, not new coverage.

**Steps:**

1. Use (or provision) a machine — a macOS host with no Homebrew `coreutils`
   installed is the box the original defect was reported on — where neither
   `timeout` nor `gtimeout` resolves on `PATH` (`command -v timeout` and
   `command -v gtimeout` both fail; do **not** sanitize `PATH` by hand for
   this step — the point is a machine that lacks the binaries for real).
2. Pick one real suite that itself calls a bounded-execution fallback site —
   `tests/test-issue-979-probe.sh` is a convenient choice, since its own
   `--probe` legs drive `scripts/preflight/check-review-backend.sh` through a
   short `PROBE_TIMEOUT_SECS` bound with a subject that exits well before it.
3. **Before the fix** (checkout the commit immediately prior to this cycle's
   GREEN implementation, `b79d855`'s parent): run the suite piped to `tail`,
   e.g. `bash tests/test-issue-979-probe.sh | tail -n 5`, and record wall-clock
   time from invocation to the shell prompt returning (`time bash
   tests/test-issue-979-probe.sh | tail -n 5`). Expect the prompt to return
   noticeably later than the suite's own last printed assertion line — the
   watchdog's inherited, unredirected pipe copy holding `tail` open past
   subject completion.
4. **After the fix** (the current tree, this cycle's implementation applied):
   repeat the identical command. Expect the prompt to return at essentially
   the same moment the suite's own last assertion line prints — no
   perceptible extra wait.
5. Record both wall-clock timings (or at minimum, whether a perceptible delay
   was observed in each case) in the PR or issue thread as this scenario's
   result.

**Pass condition:** the "after" run's wall clock is not perceptibly longer than
the suite's own printed completion, on a machine that genuinely lacks
`timeout`/`gtimeout` — matching what `AC-pipe-release` already demonstrates
under a `PATH`-forced sanitized environment.
