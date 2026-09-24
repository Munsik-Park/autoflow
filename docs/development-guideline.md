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

### When to create an ADR

Create or update an ADR before implementation when a change affects one of
these **trigger areas**. This list is the one the ADR-conformance checks read
— GATE:PLAN's *ADR-conformance check* and GATE:QUALITY's *Fit — ADR
conformance* item in `docs/autoflow-guide.md` decide "trigger area hit" and
"N/A" against it — so it lives in this usage document, which every target
receives, rather than in the ADR registry, which does not ship.

- Host/submodule responsibility boundaries.
- Deployment topology or CI/CD authority.
- Tenant isolation, accounting ownership, file visibility, or access control.
- Secret/config management.
- Agent workflow gates, evaluation policy, or merge authority.
- External service dependencies.

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
- This repository commits only deployment-level checks (ADR-0024 D1: `packaging`, `manifest`).
  Any other change is verified by a one-shot run under `.autoflow/issue-{N}-local/`, recorded in the
  PR body (issue #293): a change to AutoFlow's own rules (a rule document, a rule and its device) is
  settled there; a change to what a stamp delivers (a hook, a shipped script, a workflow) is checked
  there too, and its behavior across targets shows where it is stamped — a failure on a real target
  comes back as an issue.
- Host tool/mechanism changes run `scripts/test/check-host-purity-delta.sh` (host-purity DELTA
  guard).
- LibreChat submodule changes should use the submodule's package scripts and
  should respect submodule ownership.

## 8. Documentation Policy

- Review outputs should be navigable through clear file names, summaries,
  indexes, and cross-references where useful.
- Existing operating manuals remain source-of-truth documents; review baseline
  docs should route to them, not duplicate or override them.
- **A rule's body has one home.** A rule is stated in full in one section,
  which declares itself the rule's only home. Another site that needs the rule
  carries only what it acts on itself — a transition condition, the check its
  device makes, a cap's number — and cites the home; it does not restate which
  cases the rule covers, where it routes them or when it closes them
  (`docs/records/design-rationale.md` > Decision 30).
- **A rule change is checked against every site before it is committed.** The
  home lists search terms that find every sentence stating or citing the rule.
  Before committing a change to the rule, run `git grep` with those terms and
  read the hits as one set; a site that disagrees is reduced to a citation, not
  re-worded. Hits in `docs/records/` are read, not rewritten. A home without
  search terms gets them in the same change.
