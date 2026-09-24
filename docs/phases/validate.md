# VALIDATE — Verification Done

> Phase playbook for VALIDATE. [`CLAUDE.md`](../../CLAUDE.md) > Phase Playbook Loading
> Contract routes to this file; the other phases are listed in
> [`autoflow-guide.md`](../autoflow-guide.md) > Phase Playbooks.

```
1. Automated tests: the cycle's local run record — VERIFY step 1's (or REFINE step 2's) command,
   log and summary line — is confirmed against the log (the recorded line read at the cited path,
   not a re-run) and covers every `automated` and `delivery-check` row of the verification design,
   and every `manual` row executed by the AI through its observation record (VERIFY step 1).
   Match the design table's rows against the record: a row with no record, or whose log is absent
   or does not carry the recorded line, is run here — a cycle-layer asset by its path, a test in the target's tree the way the target runs
   its tests — and its record filled in, not failed ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *A
   missing run is filled where it is found*). Regression verification is HANDOFF step 5's CI; no
   whole-tree run happens here ([`submodule-common-rules.md`](../submodule-common-rules.md) > Verification and Tools > *Local verification*).
2. Minimal-implementation check: PASS confirmed (achieved in VERIFY step 3).
3. Manual checklist: list the manual scenarios executed by a person (mark "delegated to user"); a
   scenario executed by the AI is covered by step 1.
4. Maintained-docs check: confirm impacted docs are updated, and that the REFINE report
   (`.autoflow/issue-{N}-refine-report.md`) exists with its `simplify:` / `simplify-grounds:`
   lines and its four sections present — an empty section says `none`; an omitted section or a
   missing decision line fails this step ([REFINE](refine.md) > REFINE report).
5. Manifest coherence check: if the diff touched a manifest-registered source
   (Change Surface Rules > Derived artifacts), confirm `setup/manifest.json` was
   regenerated in the same change — re-run the set-intersection check locally.
6. Deploy/CI-path verification check: if the diff matched the INTEGRATE
   deploy/CI-path condition (### Deploy/CI-path conditional verification),
   confirm the INTEGRATE deploy/CI-path bundle (a)/(b)/(c) ran and passed
   against the target service repo — re-state the matched paths. (Or diff
   touched no deploy/CI-path surface.)
7. Lint-chain check: if the diff touched files the target repo's lint chain
   covers (Change Surface Rules > Lint chain on the staged surface), confirm the
   lint chain ran clean on them at commit time — re-derive it from the committing
   role's per-chain lint-outcome anchor. A discovered chain covering a
   staged file clears only on a confirmed execution — locally at commit time, or
   by a named pull-request CI job that HANDOFF's CI-green confirmation requires;
   a stated reason alone never clears it. The clearing outcomes are `clean`,
   `fixed-and-staged`, `not-applicable` or `not-run (ci-deferred)` whose
   covering-job evidence re-derives (Change Surface Rules > `not-run` reason
   classes), and the deferral is discharged at HANDOFF step 5.
   `not-run (unexecuted)` does not clear this step: the committing role runs the
   chain over the staged surface and re-reports the outcome for re-evaluation,
   or — if the chain is genuinely not executable in this checkout and no covering
   job can be named — the cycle pauses for the user (`active:false`,
   `phase:"awaiting-user"`), presented situation-first per host CLAUDE.md >
   Execution Principles > Human-decision presentation.
```

**Verdict**: automated tests all PASS + every `manual` row executed by the AI recorded `observation: match` + minimal-implementation PASS + manual scenarios executed by a person listed + manifest coherence confirmed (or diff touched no manifest source) + deploy/CI-path verification confirmed (or diff touched no deploy/CI-path surface) + lint outcome confirmed per discovered chain, with no `unexecuted` chain outstanding (or diff touched no lint-covered file). Manual items marked "delegated to user" do not block VALIDATE.
