# Security Checklist — AutoFlow Repository

> This repository's own security checklist, declared in `.claude/autoflow.local.json` > `audit.security_checklist`. AUDIT reads the version it is given — the file at the revision `<autoflow-root>/scripts/gate/security-checklist.sh status` names —, and GATE:QUALITY's `Security` item references the AUDIT result (`<autoflow-root>/docs/evaluation-system.md` > AUDIT). It does not apply to targets: a target's security checklist is the target's own, declared in its own `.claude/autoflow.local.json`.

---

## Scope

This repository ships meta artifacts as the plugin package — rules, docs, the gate hook and the scripts the plugin runs. Its threat surface is bounded by *who can run the hook* and *what the hook trusts*.

The items below are grouped under AUDIT's five rubric items. A rubric item with no section here is scored from the change alone.

---

## Security Items

### 1. Authentication & Authorization

- [ ] `hooks/check-autoflow-gate.sh` denies, in every session and with no state: `gh pr merge`; a push to the remote default branch (`origin/HEAD`, else `main`); `gh issue create` and its REST form; an `Agent` spawn with no explicit `model`. With no `jq` the same denies, the ledger check aside, are read from the raw input. (Re-verify on any hook change.)
- [ ] The hook keeps a decision ledger (`issue-<N>-ledger.md`) append-only: a Write/Edit/MultiEdit that changes or removes prior text is denied. (Re-verify on any hook change.)

### 2. Input Validation

- [ ] `scripts/gate/security-checklist.sh` accepts a declared checklist path only when it is repository-relative and stays inside the repository, and reads the checklist from git objects (`git show <rev>:<path>`), never from outside the repository.

### 3. Data Exposure Prevention

- [ ] The attempt's record directory — under the record root, outside every checkout's tree, never committed — holds the runs' outputs as working data; AI evaluation output that quotes user input is not pushed to public mirrors.

---

## Update Protocol

This file is updated when a new attack surface is introduced (a hook change, or a new script the plugin ships) or when a CVE in a dependency requires permanent mitigation steps.

Inside an attempt, a change to this file is read by AUDIT only once a `[checklist-decision]` ledger entry accepts it ([`decision-ledger.md`](decision-ledger.md) > *Security-checklist decisions*).
