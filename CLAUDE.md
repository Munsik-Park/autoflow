# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

AutoFlow is a reusable framework for an evaluation-gated, role-separated development lifecycle (`PREFLIGHT` → `HANDOFF`) whose terminal phase hands off an open PR; merge, close and deploy stay outside AutoFlow's authority.

## Development Commands

- **Test**: a change's functional verification is a one-shot run of cycle-layer assets under `.autoflow/{repo-key}-issue-{N}/issue-{N}-local/`, each invoked by its path (`docs/submodule-common-rules.md` > Verification and Tools > *Local verification*). The committed checks are the deployment-level ones (`packaging`, `manifest`), each run directly by its path — the list is the `run:` steps of `.github/workflows/contract-suites.yml`, `plugin-package.yml` and `e2e-dummy-target.yml`.

## AutoFlow Core

AutoFlow's rules are [`docs/core.md`](docs/core.md), imported below. It cites [`docs/state-tracking.md`](docs/state-tracking.md) for the state file's detail and each unit document's `## Transitions` section for that unit's Flow Control rows.

@docs/core.md
