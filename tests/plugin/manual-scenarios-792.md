# Manual Scenarios — Issue #792 [#785-S5] install-into-TARGET mode

**Test AI · RED · cycle 1 · 2026-07-06**

These scenarios cover acceptance criteria typed **E** (environment-dependent) or
**M** (manual) in `.autoflow/issue-792-verification-design.md` §1.
They are itemized here for VALIDATE per DCR-3.
**None of these criteria are auto-PASS from automated suite output.**

---

## AC1h — Live `@import` resolution (E)

**Type**: Environment-dependent (live Claude Code client required)

**Spec citation**: `code.claude.com/docs/en/memory` (fetched 2026-07-06, cited in
`docs/thin-root-layer.md` Item 1).

**Scenario**: A real Claude Code session is opened inside a target project that
has been through the install-into-TARGET flow (`init.sh --target <path>`). Verify
that the live Claude Code client resolves the `@./.claude/autoflow/METHODOLOGY.md`
import line in `CLAUDE.md` and loads the methodology document.

**Steps**:
1. Run `bash setup/init.sh --target <scratch-target-dir>` from the autoflow repo root.
2. Open a Claude Code session with `<scratch-target-dir>` as the project root.
3. Confirm the client loads `METHODOLOGY.md` (visible in session context or
   verified by asking the model about a phrase unique to `METHODOLOGY.md`).
4. Confirm no "import not found" or resolution error is reported.

**Pass condition**: The methodology content is visible in the Claude Code session
context and no import error is produced.

**Note**: AC1g (automated) statically verifies that every `@`-import target in the
installed tree resolves to an existing file within the ≤4-hop depth budget.
AC1h tests the live client's actual loader, which is the only residual E-risk
not covered by AC1g.

---

## AC1i — Live `Workflow({name})` invocation (E)

**Type**: Environment-dependent (live Claude Code client + v2.1.154+ runtime required)

**Scenario**: From inside a Claude Code session in the installed target project,
verify that the workflow files copied to `.claude/workflows/` are invokable by
the `Workflow({name: "..."})` runtime.

**Steps**:
1. Complete the install as in AC1h step 1–2.
2. Invoke a workflow (e.g., `architect-deliberation` or `verify-cause-branch`)
   from within the Claude Code session using the `Workflow({name: ...})` call.
3. Confirm the workflow loads without a "not found" or "invalid workflow" error.

**Pass condition**: The workflow script in `.claude/workflows/` is accepted and
begins executing by the Claude Code workflow runtime (v2.1.154+).

**Note**: The automated suite (AC1d) verifies byte-identical copy of the workflow
files. AC1i tests the runtime's ability to invoke them — contingent on the live
client version, not a property the suite can assert in-repo.

---

## AC3f — Live end-to-end self-verify (E)

**Type**: Environment-dependent (live Claude Code session + installed target)

**Scenario**: From inside a Claude Code session in the installed target project
(or from the target's shell), run the drift detector and confirm it completes
cleanly in the real environment.

**Steps**:
1. Complete the install as in AC1h step 1.
2. Run the drift detector:
   ```sh
   sh .claude/autoflow/drift-check.sh
   ```
   from within the installed target directory.
3. Confirm the detector exits 0 and prints `RESULT: N passed, 0 failed` (all D1
   checks PASS; D2 may SKIP if the autoflow plugin is not installed in the session).

**Pass condition**: Detector exits 0. If D2 emits a SKIP line (plugin not locally
resolvable), the overall exit remains 0. Any FAIL line is a defect.

**Note**: The automated suite (AC3b–AC3e) covers all deterministic script-logic
arms. AC3f specifically tests the in-session invocation path — confirming the
script runs without environment-specific failures (path resolution, permissions,
missing tools) that only surface in a live Claude Code session context.

---

## AC4d — Operator follows the guide by hand (M)

**Type**: Manual (human-in-the-loop)

**Scenario**: A developer who has not seen the implementation reads
`setup/SETUP-GUIDE.md` from start to finish and successfully installs AutoFlow
into a scratch target project following only what the guide documents.

**Steps**:
1. Set up a scratch directory representing an external project root:
   ```sh
   mkdir /tmp/scratch-target && cd /tmp/scratch-target && git init
   ```
2. Follow `setup/SETUP-GUIDE.md`'s install-as-consumed-tool section step by step
   (do not refer to implementation files or this repo's source).
3. After completing the guide, verify:
   - `CLAUDE.md` contains the `AUTOFLOW-IMPORT:BEGIN/END` block.
   - `.claude/autoflow/METHODOLOGY.md` exists.
   - `.claude/workflows/architect-deliberation.js` and `verify-cause-branch.js` exist.
   - `.claude/settings.json` contains the pin keys.
   - `CLAUDE.local.md` was created (if absent before).
4. Run the drift detector:
   ```sh
   sh .claude/autoflow/drift-check.sh
   ```
   and confirm exit 0.

**Pass condition**: A developer following only the guide can produce a working
install without needing to read source code. All four verification items in step 3
hold and the drift detector exits 0.

---

## Itemization note (VALIDATE)

At VALIDATE, the assignee should confirm:

- [ ] AC1h: dated spec citation present in `docs/thin-root-layer.md` (already: 2026-07-06)
- [ ] AC1i: workflow runtime version requirement (v2.1.154+) documented in `setup/SETUP-GUIDE.md`
- [ ] AC3f: guide instructs running `sh .claude/autoflow/drift-check.sh` as a post-install step
- [ ] AC4d: guide is legible and complete enough for a fresh developer to follow without cross-referencing source
