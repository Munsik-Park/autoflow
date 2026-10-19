# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

AutoFlow is a reusable framework for an evaluation-gated, role-separated development lifecycle (`PREFLIGHT` → `HANDOFF`) whose terminal phase hands off an open PR; merge, close and deploy stay outside AutoFlow's authority.

The repository root is the plugin root (ADR-0027 D1): `.claude-plugin/`, `agents/`, `hooks/`, `skills/` and `bin/` are the plugin's components, and `docs/` and `scripts/` are the files its roles read and run by path.

## Development Commands

- **Test**: a change's functional verification is a one-shot run of cycle-layer assets under `<attempt-dir>/issue-{N}-local/`, each invoked by its path (`docs/submodule-common-rules.md` > Verification and Tools > *Local verification*). The committed checks are the deployment-level ones (`packaging`, `manifest`), each run directly by its path — the list is the `run:` steps of `.github/workflows/contract-suites.yml`, `plugin-package.yml` and `e2e-dummy-target.yml`.
- **Command bodies**: `skills/cycle/SKILL.md`, `skills/cycle-u1/SKILL.md` … `skills/cycle-u6/SKILL.md` and `skills/criterion-review/SKILL.md` are generated from `docs/core.md` by `scripts/skills/gen-skill-bodies.sh` and committed; a unit's body carries the parts of the core its unit uses, by the classification `scripts/skills/core-units.tsv` (ADR-0032). Edit the core — and the classification, for a part added or one whose units change — then regenerate; `tests/plugin/verify-skill-bodies.sh` checks that the committed bodies equal the generator's output, that every part of the core is classified and each unit body follows the classification, the root declaration and the `<autoflow-root>/…` path closure.

## Writing AutoFlow Documents

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract, and **`[DENY]`** a prohibited action; the tags carry the weight, so no extra emphasis is stacked on them, and a `[MUST]` applies exactly to the scope it names (`docs/core.md` > Instruction Conventions).
- A rule and the device that enforces it change in the same change (`docs/core.md` > Rule Scope, principle 4).
- An AutoFlow path in a document, an agent definition or a command body is written `<autoflow-root>/docs/…` or `<autoflow-root>/scripts/…`; a target path stays a bare relative path (`.claude/autoflow.local.json`), and a record path is written `<attempt-dir>/…` — the attempt's record directory under the record root, which `autoflow-records dir` prints. Links between AutoFlow documents stay file-relative (ADR-0027 D3).

## AutoFlow Core

AutoFlow's rules are [`docs/core.md`](docs/core.md). They reach a session through `/autoflow:cycle`, a unit's `/autoflow:cycle-u1` … `/autoflow:cycle-u6` (the parts its unit uses) and `/autoflow:criterion-review` (the cycle's criterion review stage alone) and a subagent through its agent definition — not through this file, which does not import the core, so a cycle on this repository carries it once. Outside a cycle, read the core when the work needs it.

A session in this repository runs the installed plugin: the released rules and scripts, with this working tree as the target. `claude --plugin-dir .` runs the working tree's own rules, documents and scripts instead; the plugin of the same name replaces the installed one for that session.
