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
2. Pick a bounded-execution call site that satisfies **both** selection
   conditions below — the conditions come first, so this step does not rot
   again the next time an individual call site gains reaping:
   1. the call site carried **no watchdog-reaping logic at the pre-fix
      commit**, so the pre-fix run really contains the defect; and
   2. the bounded call is **invoked immediately before driver exit**, so the
      watchdog's residual sleep is what holds the pipe open — nothing later in
      the driver masks it.

   `run_bounded_in` in `tests/test-push-context-base-ref.sh` satisfies both and
   is the subject the recorded measurement used
   (https://github.com/Munsik-Park/autoflow/issues/100#issuecomment-5304785157
   §2/§3, comment `5304785157`). That measurement is also why the earlier
   recommendation is gone: the previously named probe suite's pre-fix
   `run_bounded` **already reaped** the watchdog, so it exhibits a zero-second
   gap before *and* after the fix and an operator reads "fix confirmed" from a
   run that never contained the defect — a false-negative pass condition.
3. **Before the fix** (checkout the commit immediately prior to this cycle's
   GREEN implementation, `b79d855`'s parent — the same commit the recorded
   measurement cites): extract that commit's `run_bounded_in` body into a
   throwaway driver whose last action is the bounded call, run it piped to
   `tail`, and record wall-clock time from invocation to the shell prompt
   returning (`time bash <driver> | tail -n 5`). Extract rather than
   re-author, so the "before" leg measures the shipped pre-fix code. Expect
   the prompt to return noticeably later than the driver's own last printed
   line — the watchdog's inherited, unredirected pipe copy holding `tail` open
   past subject completion.
4. **After the fix** (the current tree, this cycle's implementation applied):
   repeat the identical command against the current tree's `run_bounded_in`,
   with the driver otherwise unchanged. Expect the prompt to return at
   essentially the same moment the driver's own last line prints — no
   perceptible extra wait.
5. Record both wall-clock timings (or at minimum, whether a perceptible delay
   was observed in each case) in the PR or issue thread as this scenario's
   result.

**Pass condition:** the "after" run's wall clock is not perceptibly longer than
the suite's own printed completion, on a machine that genuinely lacks
`timeout`/`gtimeout` — matching what `AC-pipe-release` already demonstrates
under a `PATH`-forced sanitized environment.
