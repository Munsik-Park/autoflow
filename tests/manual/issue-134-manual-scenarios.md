# Issue #134 — Manual Verification Scenarios

Companion: `.autoflow/issue-134-verification-design.md` (`## Acceptance criteria →
verification type → method`). Covers the acceptance criteria that are manual or
environment-dependent — properties of a live session (message ordering, an
agent's own tool choice, a real Bash `PreToolUse` payload shape, a live sweep's
wall clock) that no repository artifact records.

---

## M1 — quiesce-rule-followed: no acceptance run is invalidated by a mid-run commit

**AC**: `quiesce-rule-followed` — in a live cycle no acceptance run is invalidated
by a teammate commit landing mid-run.

**Why manual**: the ordering this rule governs (HOLD sent *before* the capture
point; the resuming instruction bundled with GO in one message; a re-entry
instruction followed by a separate HOLD denied) is observable only in a live
session's message stream — no repository artifact records message order.
`tests/test-run-economy.sh` proves the rule's text exists and is referenced at
every derived capture-point site; it cannot prove the orchestrator actually
followed it in a given cycle.

**Procedure** (recorded once per pilot cycle after this issue lands):

1. At each of the four capture-point sites (GREEN step 5, VERIFY step 1, REFINE
   step 2, VALIDATE step 1), confirm the orchestrator sent `HOLD` to every live
   teammate **before** taking the capture point (`git status --porcelain`, then
   `git rev-parse HEAD^{tree}` / `HEAD`).
2. Confirm no tree-work instruction was sent again until the run (or the
   inherited-Match branch) completed.
3. Confirm the resuming instruction traveled **bundled with GO in one message**
   — not as a separate message following a bare HOLD.
4. Record any `green-tree-register.sh --append` refusal on a moved tree
   (drift) as a **failure of this criterion** — it is the observable symptom of
   a commit landing between the capture point and the run's completion.

**Outcome → verdict**: all four sites HOLD-before-capture-point, and every
resume is GO-bundled → PASS. Any capture point taken after a live teammate had
already been told to resume tree work, or a resume sent as a message separate
from GO → FAIL, and the register-drift/refusal (if any) is the evidence.

---

## M2 — dev-sweep-absent-in-practice: the Developer AI issues no whole-tree sweep

**AC**: `dev-sweep-absent-in-practice` — a Developer AI in a live cycle issues no
whole-tree sweep.

**Why manual**: the violation class is keyed on the run's **executed set**, not
on the `--all` spelling (`docs/submodule-common-rules.md:263` — a bare
`bash scripts/test/run-suites.sh` selects the whole tree on a `push` event or an
empty delta). A bare invocation's selection is visible only in the run's own
session transcript / report, not in any committed artifact.

**Procedure**:

1. After GREEN, read the Developer AI's report and the session record for
   **every** `run-suites.sh` invocation it issued.
2. For each invocation, record the run's own executed-suite-count / selection
   line (`run-suites.sh` prints the resolved set it is about to execute) —
   never infer selection from the command's spelling alone.
3. Flag as a violation any invocation whose executed set was the whole
   enumerated tree, whether reached via `--all` or via a bare invocation whose
   delta resolved empty.

**Outcome → verdict**: no invocation's executed set is the whole enumerated
tree → PASS. Any invocation (flagged or bare) whose executed set is the whole
tree → FAIL.

---

## M3 — background-deny-reaches-the-runtime: the real Bash payload carries the surface the deny reads

**AC**: `background-deny-reaches-the-runtime` — the real Claude Code Bash
payload carries whichever surface the deny reads.

**Why manual (composition-oracle)**: no repository artifact establishes that a
`PreToolUse` `Bash` payload actually carries a `run_in_background` field — the
token appears in this repository only in prose and in doc-assertion / hook
fixture suites, never in a recorded real payload. A synthetic payload (as
`tests/test-gate-hardening.sh`'s `bash_bg_json` helper constructs) proves only
that the hook's own logic is correct when the field is present; it cannot prove
the harness ever sends it.

**Procedure** (operator-run, one real backgrounded invocation):

1. Issue one real backgrounded invocation of a command matching the deny (e.g.
   ask an agent to run `bash scripts/test/run-suites.sh --all &`, or trigger a
   `run_in_background: true` Bash call against a `run-suites.sh` command).
2. Record the hook's refusal text verbatim, and which surface produced it —
   the payload surface (`run_in_background` field) or a shell surface (`BG_TAIL`
   / `BG_PREFIX`, firing on the command string regardless of the payload).

**Outcome → verdict** (fixed in advance so the observation cannot discharge
itself):

- **(a)** refusal produced by the payload field → **PASS**, both surfaces live.
- **(b)** refusal produced by a shell surface while the payload field is absent
  or inert → **conditional PASS with an obligation**: the deny is live but
  shell-only. File a follow-up to record the payload surface as documented dead
  coverage and to stop the deny message implying payload enforcement.
- **(c)** no surface refuses → **FAIL, routed back to ARCHITECT**: the
  enforcement claim this cycle rests on is false and no repository-side leg can
  detect it.

---

## M4 — sweep-fits-the-tool-ceiling: the foreground VALIDATE sweep completes within the Bash tool's timeout

**AC**: `sweep-fits-the-tool-ceiling` — the foreground mandate does not make the
unconditional VALIDATE sweep unrunnable.

**Why manual (re-measured every cycle, not a frozen constant)**: the margin
between a measured sweep and the Bash tool's one-hour foreground bound shrinks
monotonically as suites are added — a number frozen in a test would go stale
for a reason unrelated to anything this cycle installs. The two archived #130
sweeps (cycle-2: 64/64 in ≈19.1 min; cycle-1, killed at 60/64 in the
**backgrounded** run: ≈25.6 min accumulated) establish that neither approaches
the 60-minute ceiling, but every cycle re-measures its own sweep.

**Procedure**:

1. Run VALIDATE step 1's whole-tree sweep in the **foreground**, with an
   explicit `timeout` on the Bash call.
2. Record the sweep's wall clock and the `timeout` value used.
3. If the sweep does not complete in one foreground call, **re-run it whole —
   never splice** two runs' result lines into one register entry (the spliced
   composite line is the provenance defect #130's own GATE:QUALITY evaluator
   flagged).

**Outcome → verdict**:

- **(a)** completes within the `timeout` and under three quarters of the
  Bash tool's harness bound → **PASS**.
- **(b)** completes but at or above three quarters of that bound →
  **PASS with an obligation** — file the deferred runner-parallelism item
  (`parallel-defer`, feature design > *parallel-defer*) before the next cycle.
- **(c)** does not complete in one foreground call → **FAIL** — the
  disposition is a whole re-run, never a splice.

---

## M5 — multiline-payload-reaches-the-runtime: the real Bash payload delivers a multi-line `command` in the byte shape the fold reads

**AC**: `multiline-payload-reaches-the-runtime` — the real Claude Code Bash
`PreToolUse` payload delivers a multi-line `command` in the byte shape
`_fold_continuations` / `_strip_heredoc_bodies` read (cycle 2, PR #137
finding F1).

**Why manual (composition-oracle)**: no repository artifact establishes that a
real `PreToolUse` `Bash` payload's `command` field ever carries an embedded
newline in the shape a backslash-newline continuation or a heredoc produces —
that token appears in this repository only in prose and in
`tests/test-gate-hardening.sh`'s synthetic `bash_json` fixtures (which encode
an embedded newline via `jq -Rs`, proving the harness's own JSON construction,
not the runtime's). A synthetic payload proves the hook's logic is correct
when a multi-line `command` is present; it cannot prove the real harness ever
sends one.

**Procedure** (operator-run, two real Bash tool calls):

1. Issue one real Bash tool call whose `command` is a continuation-split,
   denied invocation — e.g. a command literally shaped
   `bash scripts/test/run-suites.sh --all \` followed by a newline and `&`.
   Observe the refusal and record which surface produced it (`BG_TAIL` /
   `BG_PREFIX` / the payload `run_in_background` surface).
2. Issue a second real Bash tool call whose `command` is a continuation-split
   **foreground** `--selected` run of a single suite — no trailing `&`.
   Observe that it is admitted and actually executes.

**Outcome → verdict** (fixed in advance so the observation cannot discharge
itself):

- **(a)** call 1 is refused and call 2 is admitted and runs → **PASS**: the
  runtime delivers a multi-line `command` byte-for-byte in the shape the fold
  reads, in both the deny and the admit direction.
- **(b)** call 1 is refused but call 2 is ALSO refused (over-block) → **FAIL,
  routed back to ARCHITECT**: the fold or strip is joining or stripping more
  than the design specifies, and no repository-side leg can detect that this
  is happening against a REAL multi-line payload rather than a synthetic one.
- **(c)** call 1 is admitted (the deny does not fire) → **FAIL, routed back to
  ARCHITECT**: either the runtime never delivered the embedded newline in the
  shape the synthetic legs assume, or the hook logic that passes every
  synthetic leg does not hold against the real payload — either way the
  enforcement claim this cycle rests on is false.
