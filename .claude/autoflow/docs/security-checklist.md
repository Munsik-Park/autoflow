# Security Checklist

> Every PR must pass this security checklist before merge. Items are verified during AUDIT (independent security audit) and re-checked at GATE:QUALITY's `Security` item, then again during human PR review.

---

## Tech Stack Context

**Project**: AutoFlow (reference deployment)
**Stack**: Node.js (Bun/npm) + React (Vite) + MongoDB + MeiliSearch + Docker Compose / Helm, with pluggable LLM provider integrations (OpenAI, Anthropic, Google, Azure, AWS Bedrock, Ollama, etc.) and optional RAG/MCP backends.

**Scope notes**:
- The host (orchestrator) repository itself ships only meta artifacts (rules, docs, hooks, setup scripts). Its threat surface is bounded by *who can run the hook* and *what the hook trusts*.
- The runtime threat surface lives in the `services/librechat` sub-repo. Items below explicitly mark which side they apply to.

---

## Security Items

### 1. Authentication & Authorization

**Applies to**: `services/librechat` (runtime).

- [ ] All API routes under `services/librechat/api/` require valid auth (JWT / session) — no accidental unauthenticated endpoints.
- [ ] OAuth / OIDC integrations validate `state`, `nonce`, and redirect URIs; tokens are stored server-side, never echoed to the client.
- [ ] Password hashing uses bcrypt/argon2 with a current work factor; no plaintext or fast-hash storage.
- [ ] Admin / moderator routes enforce role checks server-side, not just by hiding UI.
- [ ] Refresh tokens rotate on use; revocation is enforced (logout / password change invalidates sessions).
- [ ] Rate limiting is enforced on login, registration, password-reset, and LLM-completion endpoints.

**Host-scope sub-item**:
- [ ] `.claude/hooks/check-autoflow-gate.sh` does not trust AI-supplied `pass` flags — verdicts are computed from raw `scores` only (existing rule; re-verify on any hook change).
- [ ] `.claude/hooks/check-autoflow-gate.sh` validates the whole state document against a **closed-world** declarative schema on load and **fails closed (`exit 2`) for score-gated commands on any deviation**. Closed-world = a positive allow-list that rejects everything not explicitly declared (vs an open-world list that only rejects known-bad shapes — the latter leaks a new fail-open per unchecked field): single top-level object; `active` boolean; and — when active — top-level keys restricted to the `gate-schema.json:top_level_keys` whitelist (or a `cycle_key_grammar` `fix_regression_cycle_N`), each declared field type-checked, `phases` only at root + `fix_regression*` cycles, each gated phase's `verdict` ∈ `gate-schema.json:verdict_enum` (or empty/absent — gate-not-triggered), and each score a number (or `{score:number}`) in `score_range` `[0,10]`. Any other shape → MALFORMED. A syntactically-valid-but-schema-corrupt state (e.g. `"active":"true"`; a non-canonical `verdict` containing "skip" such as `"pending-but-skip-this"`; an out-of-range score `999`; an unknown top-level key or wrong-typed field) thus cannot be silently mis-read as inactive or pass a gate (fail-open); non-gated/repair commands stay unblocked to avoid deadlock. The validator's literals are drift-checked against `tests/fixtures/gate-schema.json` (single source) by `tests/test-issue-245-schema-validation.sh` CLASS A. Scope: validation is closed-world over the gate-feeding surface (the top-level document + the four gated phases); a **non-gated** phase entry (e.g. `gate_hypothesis_structure`, or an unrecognised key/extra field inside a phase) is intentionally tolerated — it cannot reach a gate (the gates read only the gated phases' `verdict`/`scores`, and the phases-location guard rejects any nested `phases` smuggle), so closing it would add over-block/deadlock risk for zero exploit-closure. (issue #245 R3; re-verify on any hook change.)

### 2. Input Validation

**Applies to**: `services/librechat` (runtime).

- [ ] User chat messages flowing to LLM providers do not concatenate untrusted strings into system prompts; tool-call arguments are schema-validated.
- [ ] MongoDB queries use parameterized objects, never user-built `$where` / JavaScript evaluation; `$regex` inputs are sanitized or length-capped.
- [ ] File uploads (chat attachments, RAG ingest) validate MIME type, extension, and size; binary content is scanned for embedded payloads where feasible.
- [ ] User-supplied URLs (RAG fetch, MCP server discovery, image proxy) are validated against an allowlist or blocked from internal/private CIDRs to prevent SSRF.
- [ ] Markdown / HTML rendered in the client uses a sanitizer (e.g., DOMPurify) — no raw `dangerouslySetInnerHTML` on user content.
- [ ] WebSocket / SSE stream messages are size-bounded and rate-limited per connection.

### 3. Data Exposure Prevention

**Applies to**: `services/librechat` (runtime) and host (logging configuration).

- [ ] **LLM provider API keys** (OpenAI/Anthropic/Google/Azure/Bedrock/etc.) live in env vars or a secret store — never committed, never logged, never returned in API responses or error payloads.
- [ ] Server logs redact: auth tokens, refresh tokens, OAuth codes, password fields, full conversation bodies (or are stored on a separate, access-controlled stream).
- [ ] Error responses to the client are generic (`{"error": "internal"}`); stack traces, DB schema details, and file paths stay server-side.
- [ ] Conversation transcripts that contain PII / sensitive data are retained per a documented retention policy; user deletion requests propagate to MongoDB and MeiliSearch indexes.
- [ ] Cross-tenant data access is impossible: every MongoDB read is scoped by authenticated `userId`; MeiliSearch queries enforce per-user filter tokens.
- [ ] Per-user / per-conversation token usage and cost data are not visible to other users.
- [ ] Host-side: `.autoflow/issue-*.json` is gitignored and treated as working data; AI evaluation output that quotes user input is not pushed to public mirrors.

### 4. Infrastructure Isolation

**Applies to**: `services/librechat` (deploy/compose/helm).

- [ ] MongoDB port (default 27017) is bound to the internal Docker network only — never published to the host or public LB.
- [ ] MeiliSearch master key is set to a strong random value and stored as a secret; the search service is not publicly exposed without an API key gate.
- [ ] Reverse proxy / ingress terminates TLS; HTTP→HTTPS redirect is enforced; HSTS is set in production.
- [ ] Containers run as non-root where the upstream image allows; readonly root filesystem where possible.
  - **Accepted risk (issue #56) — per-client DB tier ran as in-container UID 0. [RESOLVED by #685 — per-client DB tier retired.]** This accepted risk no longer applies: the per-client `clients/<slug>` `mongodb`/`meilisearch` overrides were removed in #685 (shared-instance convergence, issue #685), so no per-client DB tier remains to run as UID 0. The original analysis is retained below as historical record (Human-owned — confirm closure at review). The per-client overrides (`clients/<slug>/docker-compose.override.yml`) set `user: "0:0"` on `mongodb`/`meilisearch` because the read-only base forces `user: "${UID}:${GID}"` (=`1000:1000`) while the per-client tenant-isolation override swaps the DB binds for a fresh Docker **named** volume whose directory Docker creates root-owned (`755`); a `1000:1000` process cannot write it (mongo journal EACCES `exitCode 100`, meili `os error 13`). This is a deliberate, bounded defense-in-depth trade made under the **no-sudo deploy contract** (the privilege-free init/entrypoint-chown alternative — issue #56 option 2 — was evaluated and rejected at ARCHITECT because `deploy_client()` must not require host privilege). Compensating controls (all verified): the DB tier joins **`librechat_internal` only**, never `ontology-platform_ontology_prod`; it publishes **no host ports**; containers are **unprivileged** (no `privileged:`, no `cap_add`, no host bind mount — a Docker named volume only); they are unreachable from the public LLM-egress route. Re-evaluate this accepted risk only if a host bind mount or any capability is ever layered onto the DB services, which would materially escalate residual risk.
- [ ] Docker Compose `.env`, Helm `values.yaml`, and Kubernetes Secrets are not committed; example files use placeholder values only.
- [ ] CORS allowlist is explicit (no `*` for credentialed requests); cookies use `Secure; HttpOnly; SameSite=Lax|Strict`.
- [ ] No internal services (Mongo, Meili, RAG vector store) are reachable from the public LLM-egress route.

### 5. Dependency Vulnerabilities

**Applies to**: `services/librechat` (runtime) and host (hook + setup script).

- [ ] `services/librechat/package-lock.json` and `services/librechat/bun.lock` are committed and consistent (no `package.json` change without a lockfile update).
- [ ] `npm audit --omit=dev` (or `bun audit`) reports no `critical` or `high` items at PR time — exceptions documented with CVE id + rationale.
- [ ] No `postinstall` scripts execute arbitrary network code at install time; lifecycle scripts are reviewed when dependencies are added.
- [ ] `dependabot.yml` or equivalent is configured to bump direct deps on a defined cadence; major bumps go through ARCHITECT/GATE:PLAN.
- [ ] Container base images (`Dockerfile`, `Dockerfile.multi`) are pinned to a digest or specific tag; rebuilds run a CVE scan (Trivy / Grype) in CI.
- [ ] Host-side: `setup/init.sh` does `set -euo pipefail` and uses only the system `sed`/`cp` — no curl|sh of remote scripts.

---

## Integration with AutoFlow

### During AUDIT
A fresh-spawned Evaluation AI scores these 5 items independently. PASS criteria: average ≥ 7.5, each ≥ 7, security ≤ 3 → block.

### During GATE:QUALITY
The 10-item quality evaluation references the AUDIT result for its `Security` item to avoid duplicate work.

### During PR Review
The PR template includes this checklist. The PR author must check each applicable item before requesting review.

### CI Integration (recommended)
- **SAST**: Semgrep or CodeQL with rulesets for Node.js + React.
- **SCA**: Dependabot or Snyk for `services/librechat/package.json`.
- **Secret scanning**: GitHub Secret Scanning + pre-commit `gitleaks`.
- **Image scanning**: Trivy step before pushing container images.

---

## Update Protocol

This file is updated when:
- A new attack surface is introduced (new auth flow, new external dependency, new exposed port).
- A CVE in a direct dependency requires permanent mitigation steps.
- The LLM provider integration set changes (new provider added, key handling differs).
- The deployment topology changes (Compose → K8s, new ingress, etc.).

Maintainer: Human (security-sensitive — never auto-edited).
