# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

AutoFlow is a reusable framework of composable modules — each with a contract, run once on its invocation — for a change worked, evaluated apart from the work, and handed off as an open, reviewed PR; merge, close and deploy stay outside AutoFlow's authority.

The repository root is the plugin root (ADR-0027 D1): `.claude-plugin/`, `agents/`, `hooks/`, `skills/` and `bin/` are the plugin's components, and `docs/` and `scripts/` are the files its roles read and run by path.

## Development Commands

- **Test**: a change's functional verification is a one-shot run of cycle-layer assets under the run's `<out>/local/`, each invoked by its path (`docs/submodule-common-rules.md` > Verification and Tools > *Local verification*). The committed checks are the deployment-level ones (`packaging`, `manifest`), each run directly by its path — the list is the `run:` steps of `.github/workflows/contract-suites.yml`, `plugin-package.yml` and `e2e-dummy-target.yml`.
- **Command bodies and carriers**: `skills/<module>/SKILL.md` — one command per module, `/autoflow:<module> <invocation.json>` — are generated from `docs/core.md` by `scripts/skills/gen-skill-bodies.sh` and committed; a module's body carries the parts of the core its module uses, by the classification `scripts/skills/core-units.tsv` (ADR-0038 D9). The same generator writes, by the classification `scripts/skills/role-docs.tsv`, the documents each command body carries after its core, and the generated part of every agent definition (`agents/*.md`) and reviewer rule file (`docs/review/review-claude.md`, `docs/review/review-codex.md`) below its marker line (ADR-0035). Edit the core, the documents and a carrier's own text above its marker — and the classifications, for a part added or one whose carriers change — then regenerate; `tests/plugin/verify-skill-bodies.sh` checks that the committed carriers equal the generator's output, that every part of the core is classified and each module body follows the classification, that every module contract has a body, that each carrier carries what `role-docs.tsv` names, the root declaration and the `<autoflow-root>/…` path closure.

## Writing AutoFlow Documents

- **`[MUST]`** marks a hard constraint enforced by a gate, hook, or role contract, and **`[DENY]`** a prohibited action; the tags carry the weight, so no extra emphasis is stacked on them, and a `[MUST]` applies exactly to the scope it names (`docs/core.md` > Instruction Conventions).
- A rule and the device that enforces it change in the same change (`docs/core.md` > Rule Scope, principle 4).
- An AutoFlow path in a document, an agent definition or a command body is written `<autoflow-root>/docs/…` or `<autoflow-root>/scripts/…`; a target path stays a bare relative path (`.claude/autoflow.local.json`), and a record path is written `<attempt-dir>/…` — the attempt's record directory under the record root, which each invocation names (`records`). Links between AutoFlow documents stay file-relative (ADR-0027 D3).

## AutoFlow Core

AutoFlow's rules are [`docs/core.md`](docs/core.md). They reach a session through a module's command, `/autoflow:<module>` (the parts of the core its module uses), and a subagent through its agent definition — not through this file, which does not import the core, so a module run on this repository carries it once. Outside a module run, read the core when the work needs it.

A session in this repository runs the installed plugin: the released rules and scripts, with this working tree as the target. `claude --plugin-dir .` runs the working tree's own rules, documents and scripts instead; the plugin of the same name replaces the installed one for that session.
