# Development Guideline

## 1. Work Type Policy

Classify work before implementation:

| Type | Meaning |
| --- | --- |
| `planning` | Product goal, user flow, scope, or acceptance criteria clarification. |
| `design` | Technical design needed before implementation. |
| `adr` | Architecture decision record needed. |
| `implementation` | Feature or behavior implementation. |
| `refactoring` | Structure change without intended behavior change. |
| `bug` | Defect correction. |
| `tech-debt` | Known structural or maintainability debt. |
| `test` | Test coverage or verification improvement. |
| `docs` | Documentation work. |
| `ops` | CI, deployment, credentials, monitoring, or operational process. |

## 2. Issue Policy

- Every non-trivial implementation issue should reference the planning,
  design, ADR, or issue-breakdown document that makes it ready.
- Generated epic slices are not automatically implementation-ready. If the
  body says acceptance criteria or base structure must be strengthened at
  start time, do that before coding.
- Issues that change deployment, tenant isolation, billing ownership, file
  access, agent workflow, or repository boundaries should be checked against
  ADR candidates first.
- PRs should solve one main issue only.

## 3. Design Policy

- Large changes require a short design note before implementation.
- Current-state documentation and target-state design must be separated.
- If the current design is unclear, document observed behavior first and mark
  owner-confirmation questions explicitly.
- Do not overdesign. Add decisions only where they materially reduce ambiguity,
  risk, or future rework.

## 4. ADR Policy

- Architecture-impacting changes require an ADR or a documented owner decision
  before merge.
- Undocumented architecture decisions are unresolved until recorded.
- Proposed ADRs should distinguish observed current state from recommended
  target state.

## 5. PR Policy

- Keep the existing host PR template contract, especially `HOST-CLOSE-LINE`,
  sub-repo dependency checklist, and AutoFlow status fields.
- Do not merge, close issues, or deploy as part of review work.
- For GitHub PR/issue reviews, use local `gh` CLI rather than public web
  lookup for private or permission-restricted repository data.
- Host PRs that depend on sub-repo changes must preserve the external review
  sequencing contract.

## 6. Refactoring Policy

- Do not mix refactoring with feature work unless unavoidable.
- Refactoring should be queued and ordered by risk, affected tests, and
  boundary ownership.
- Refactor only after current state, risks, and required tests are documented.

## 7. Testing Policy

- Choose tests based on changed surface.
- Host shell/deployment changes should run the relevant `tests/test-*.sh` harnesses, including `tests/test-issue-788-host-purity-delta.sh` (host-purity DELTA guard) when touching host tool/mechanism files.
- AutoFlow hook/schema changes should include schema-hook and gate contract
  tests.
- Workflow script changes should include `node test/workflows/run.mjs`.
- LibreChat submodule changes should use the submodule's package scripts and
  should respect submodule ownership.

## 8. Documentation Policy

- New documents must be registered in `docs/maintained-docs.md`.
- Review outputs should be navigable through clear file names, summaries,
  indexes, and cross-references where useful.
- Existing operating manuals remain source-of-truth documents; review baseline
  docs should route to them, not duplicate or override them.

