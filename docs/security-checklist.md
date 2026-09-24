# Security Checklist — AutoFlow Repository

> This repository's own security checklist, declared in `.claude/autoflow.local.json` > `audit.security_checklist`. AUDIT reads it at the version `scripts/gate/security-checklist.sh status` names, and GATE:QUALITY's `Security` item references the AUDIT result (`docs/autoflow-guide.md` > AUDIT). It is **not** stamped to targets: a target's security checklist is the target's own, declared in its own scaffold.

---

## Scope

This repository ships meta artifacts — rules, docs, the gate hook, the installer and the scripts it stamps into targets. Its threat surface is bounded by *who can run the hook* and *what the hook trusts*.

The items below are grouped under AUDIT's five rubric items. A rubric item with no section here is scored from the change alone.

---

## Security Items

### 1. Authentication & Authorization

- [ ] `.claude/hooks/check-autoflow-gate.sh` does not trust AI-supplied `pass` flags — verdicts are computed from raw `scores` only (re-verify on any hook change).
- [ ] `.claude/hooks/check-autoflow-gate.sh` validates the whole state document against a **closed-world** declarative schema on load and **fails closed (`exit 2`) for score-gated commands on any deviation**. Closed-world = a positive allow-list that rejects everything not explicitly declared: single top-level object; `active` boolean; and — when active — top-level keys restricted to the `gate-schema.json:top_level_keys` whitelist (or a `cycle_key_grammar` `fix_regression_cycle_N`), each declared field type-checked, `phases` only at root + `fix_regression*` cycles, each gated phase's `verdict` ∈ `gate-schema.json:verdict_enum` (or empty/absent — gate-not-triggered), and each score a number (or `{score:number}`) in `score_range` `[0,10]`. Any other shape → MALFORMED. Non-gated/repair commands stay unblocked. The validator's literals follow `tests/fixtures/gate-schema.json` (single source); the two change together, and the cycle that changes either checks one against the other in its one-shot run. Scope: validation is closed-world over the gate-feeding surface (the top-level document + the four gated phases); a **non-gated** phase entry (e.g. `gate_hypothesis_structure`, or an unrecognised key/extra field inside a phase) is tolerated while the gates read only the gated phases' `verdict`/`scores` and the phases-location guard rejects any nested `phases` smuggle. (Re-verify on any hook change.)

### 2. Input Validation

- [ ] `scripts/gate/security-checklist.sh` accepts a declared checklist path only when it is repository-relative and stays inside the repository, and reads the checklist from git objects (`git show <rev>:<path>`), never from outside the repository.

### 3. Data Exposure Prevention

- [ ] `.autoflow/issue-*.json` is gitignored and treated as working data; AI evaluation output that quotes user input is not pushed to public mirrors.

### 5. Dependency Vulnerabilities

- [ ] `setup/init.sh` does `set -euo pipefail` and uses only the system `sed`/`cp` — no curl|sh of remote scripts.

---

## Update Protocol

This file is updated when a new attack surface is introduced (a hook change, or a new stamped script or installer step) or when a CVE in a dependency requires permanent mitigation steps.

Maintainer: Human (never auto-edited). Inside an AutoFlow cycle a change to this file is read by AUDIT only once the operator accepts it (`CLAUDE.md` > Decision Ledger > *Security-checklist decisions*).
