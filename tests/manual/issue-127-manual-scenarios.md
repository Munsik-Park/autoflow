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
