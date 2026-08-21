# Issue #127 — Manual/Environment-Dependent Verification Scenarios

The row "Live runtime accepts the resume args form and the register-load
schema" (`.autoflow/issue-127-verification-design.md` > Acceptance criteria)
is the only acceptance criterion with no automated path: the hosted Workflow
runtime is not launchable from this repository's test tree —
`test/workflows/run.mjs` states its own scope explicitly (`test/workflows/run.mjs:8-11`,
"They do NOT exercise a live Claude Code Workflow runtime"), and the script
cannot observe its own environment (no filesystem, `import(` rejected at
parse time). Verification design > Testability assessment, *The argument
surface is harness-drivable, not runtime-only*: admission and prose salvage
are script-local normalization run before any agent call, so the harness
drives them directly (`test/workflows/run.mjs`, "AC127-*" cases); only the
runtime's actual delivery form for the `resume` key, and the real `schema`
return shape a live register-load sub-agent produces, stay with this scenario.

---

## M1 — Resume args delivery and register-load schema under the real hosted Workflow runtime (Tier 3, environment-dependent)

**Source AC:** "Live runtime accepts the resume args form and the
register-load schema" — what the runtime actually sends for the `resume` key
is observed here and asserted nowhere else; the harness's argument-surface
cases (AC127-2a/2b/2c) deliberately claim nothing about the real transport
form.

**Setup:** On a session satisfying the Workflow prerequisites
(`docs/teammate-contracts.md` > Facilitator > Realization > Invocation /
version / config — Claude Code v2.1.154+, Dynamic workflows enabled), pick an
issue whose most recent ARCHITECT deliberation returned `ESCALATE` and left a
register artifact at `.autoflow/issue-<N>-architect-register.json` (a normal
cap-exhaustion or infra-missing ESCALATE is sufficient; it need not be a
design-contradiction escalation).

**Procedure:** Run `Workflow({ name: "architect-deliberation", args: { issue: "<N>", resume: true } })`
and let it proceed to completion. Record:

1. the exact runtime-delivered shape of `args` observed inside the script
   (e.g. via a temporary diagnostic `console.log(typeof args, args)` at the
   top of the normalization block, mirroring the args-probe diagnostic the
   existing JSON-string-args comment references) — specifically whether
   `resume` round-trips as a JSON boolean or as some other runtime-specific
   encoding;
2. the register-load `agent()` call's returned object shape against the
   closed `REGISTER_FILE` schema (`found`, `artifacts_present`, `lastRound`,
   `verdict`, `entries`) — whether a real sub-agent, given the schema, returns
   every field or omits one the mock harness always supplies;
3. whether the resume run correctly skips Draft (no `dev-draft`/`test-draft`
   call appears in the workflow's own console log) and starts at the
   register's `lastRound + 1`;
4. the final returned `resumed`, `register`, and `registerWritten` fields.

**Pass:** `resume: true` reaches the script as a boolean (or a value the
normalization block's admission rule already tolerates), the register-load
call returns a value satisfying the closed schema, Draft is skipped, and the
run's returned fields match what `test/workflows/run.mjs`'s AC127-* cases
predict for an equivalent input shape.

**Fail:** the runtime delivers `resume` in a form the admission rule rejects
or silently drops, the live register-load sub-agent returns a shape the
schema does not constrain it to (e.g. a string instead of an object, or a
missing required field) in a way the mock harness cannot reproduce, or Draft
still runs despite `resume: true`.

**Status:** delegated to user (operator-run; requires a live Claude Code
session with Dynamic workflows enabled and a real prior ESCALATE + register
artifact — not executable from this repository's automated test tree).

---

## M2 — runtime-reject-capability (Tier 3, environment-dependent)

**Source AC:** the `runtime-reject-capability` row
(`.autoflow/issue-127-verification-design.md:51`, "Whether the hosted
Workflow runtime's injected `agent()` ever rejects or throws") — the cycle-2
row for the terminal post-verdict call rejection-absorption fix. Named again
under Verification depth determination's *Live runtime* layer
(`.autoflow/issue-127-verification-design.md:158`, "Whether the hosted
injection ever produces the failure the guard absorbs. Delegated, with its
reason stated in its criterion row; no automated layer can reach it").

**Why this is not automatable from this repository:** `test/workflows/run.mjs`
supplies its own mock `agent`, so the harness can only demonstrate that the
script *absorbs* an injected rejection or synchronous throw — it can never
demonstrate that the real hosted runtime's `agent()` injection actually
produces one. This is a system-boundary property of the Workflow runtime,
not a property of `architect-deliberation.js`, and the repository has no
handle on that runtime to observe it. Per the source row, this gates
nothing: the absorption guard is owed by the return contract's own sentence
(`docs/teammate-contracts.md` > Facilitator > Return Contract) regardless of
whether the runtime ever exercises it, so a negative observation here would
not retire the fix.

**Operator procedure:** On a session satisfying the Workflow prerequisites
(`docs/teammate-contracts.md` > Facilitator > Realization > Invocation /
version / config — Claude Code v2.1.154+, Dynamic workflows enabled), run a
live ARCHITECT deliberation to a decided verdict and arrange for its
register-write sub-agent call to fail — e.g. point `registerPath` at an
unwritable location (a read-only directory, or a path under a directory that
does not exist and cannot be created) so the sub-agent's write attempt fails
and its `agent()` call rejects or throws back into the workflow. Let the
workflow run to completion and record:

1. whether `Workflow({ name: "architect-deliberation", args: { issue: "<N>" } })`
   still **resolves** (does not reject the whole workflow invocation);
2. the returned `verdict` — must equal the value the deliberation rounds
   already decided (`CONVERGED` or `ESCALATE`), unaltered by the failed
   write;
3. the returned `registerWritten` field — must be `false`;
4. the append-only ledger at the run's `ledger` path — must carry the normal
   settled-decision or non-convergence entry for this run, i.e. the terminal
   Ledger phase's own call was unaffected by the register-write failure
   (a distinct call, upstream of Register).

**Pass:** the workflow resolves with the already-decided `verdict` intact,
`registerWritten: false`, and the ledger entry present and normal — i.e. the
real hosted runtime's rejection/throw (whatever form it actually takes) is
absorbed by the deferred wrap the same way the harness's mock rejection and
mock synchronous throw are absorbed in `test/workflows/run.mjs`
(`write-reject-absorbed`, `write-sync-throw-absorbed`).

**Fail:** the workflow invocation itself rejects, the returned `verdict`
differs from the one the rounds decided, or the ledger entry is missing or
malformed — any of which would mean the real runtime's failure mode reaches
this script in a shape the deferred-wrap guard does not actually absorb.

**Status:** delegated to user (operator-run; requires a live Claude Code
session with Dynamic workflows enabled and a way to force a real
register-write sub-agent failure — not executable from this repository's
automated test tree; per the source row, gates nothing in this cycle).
