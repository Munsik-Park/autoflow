# Issue #52 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

This acceptance criterion is **not** covered by `tests/fixtures/doc-invariants.json`
(registry entries `52-*`) or `tests/test-issue-52-peer-facilitator-premise.sh` — it is a
claim about live Claude Code Agent Teams message-routing behavior, not about
document text, and is not reproducible in CI (verification design
`.autoflow/issue-52-verification-design.md` §2 "Not automatable", §3).

**Coverage boundary, stated plainly.** Automated coverage for #52 proves the
*design record* no longer states the peer-teammate-isolation premise without
citation, and that all three claim sites carry the same evidence pointer
(registry STATE assertions) plus that the manifest and registry compositions
stay consistent (composition oracles). None of that proves the premise itself
— whether a `SendMessage` from one named teammate to its peer is actually
auto-injected into the **lead's** own turn stream. That live-runtime
observation is this file's M1.

**Deviation from the issue's written procedure, recorded up front.** The probe
team below runs as **two** named members (`test-*`, `dev-*`) under the
orchestrator as lead, not the three-member shape the issue body originally
sketches. `CLAUDE.md` > Spawn mode by role lifetime closes with "Test AI and
Developer AI are the only named spawns; every other role is anonymous direct",
and the gate hook classifies a team spawn by name-prefix alone over the
accepted set (`.claude/hooks/check-autoflow-gate.sh:283-291`), which carries no
facilitator prefix — a third named member would require a spawn mode the
`[MUST]` rule reserves to anonymous direct spawns. Two members are sufficient
for the measured relation (teammate → peer teammate); a third member would sit
on neither end of the measured hop. This is a grounded deviation from the
issue's written procedure, not an unexplained shortcut — see feature design
`observation-executor` > "Probe team shape — exactly two named members."

---

## M1 — peer-teammate SendMessage injection into the lead's turn stream (Tier 3)

**Source AC:** `injection-probe-run` (verification design §1) — the peer-teammate
probe is executed against the live runtime and its outcome licenses one of the
two drafted branches at feature design `outcome-branch-text`, cited from
`docs/design-rationale.md` > Decision 8 and the two referring sites.

**Why not automated:** whether a teammate→peer-teammate `SendMessage` is
auto-injected into the **lead's** conversation is a property of the Claude
Code Agent Teams runtime, outside this repository's control and not exercised
by any script here. A stubbed or simulated mailbox would prove only that the
stub behaves as written — exactly the substitution that produced the uncited
premise this issue exists to remove (verification design §3).

**Steps:**

1. Under the orchestrator as lead, spawn a flat two-member team: one `test-*`
   teammate and one `dev-*` teammate (per the deviation note above), each
   spawn declaring `model` explicitly per the gate hook's requirement.
2. Choose two distinct nonce literals: a **peer nonce** and a **control
   nonce**.
3. Have the `test-*` teammate send the **control nonce** directly to the lead
   via its own `SendMessage(to: "team-lead", ...)`. Confirm the send returns
   successfully — this is the **send confirmation** for the control channel.
4. Have the `test-*` teammate send the **peer nonce** to the `dev-*` teammate
   via `SendMessage(to: "<dev teammate name>", ...)`. Confirm the send returns
   successfully — this is the **send confirmation** for the peer hop.
5. Have the `dev-*` teammate, on receiving the peer nonce, compute a **derived
   token** from it (a stated, reversible-in-record transformation — e.g. the
   nonce with a fixed suffix appended, not the nonce verbatim) and
   `SendMessage(to: "team-lead", ...)` that derived token back to the lead.
   This is the **receipt confirmation**: it establishes the peer-to-peer hop
   completed without echoing the raw peer nonce, so an auto-injected copy of
   the raw nonce arriving in the lead's stream by the injection path remains
   distinguishable from this receipt echo (ledger E18).
6. After the receipt-confirmation turn has landed in the lead's context (the
   **bounded observation window**), inspect the lead's own turn stream in
   full — every `SendMessage`-delivered turn and every raw teammate-to-
   teammate exchange, if any is visible.
7. For each occurrence of the **raw peer nonce literal** found anywhere in the
   lead's stream, record: the apparent sender, the delivery path (a
   `SendMessage`-injected turn addressed to the lead, vs. any other visible
   channel), and running occurrence count. Do the same for the **control
   nonce** (**positive control result**).
8. If any of send confirmation (peer or control), receipt confirmation, or
   positive-control observation is missing or failed, record the run as
   **inconclusive** and re-run from step 2 with fresh nonces — an inconclusive
   run licenses neither outcome branch (feature design `observation-executor`
   > "Inconclusive runs are not outcomes").
9. Fill in the Observation record below and append the same fields to
   `.autoflow/issue-52-ledger.md` as a new entry.

**Pass condition:** a run is **admissible as evidence** only when all of the
following hold (verification design §3, `probe-validity`): distinct peer and
control nonces; peer-hop send confirmation; derived-token receipt
confirmation; control nonce observed in the lead's stream (positive control
holds); and the lead's stream inspected only after the receipt-confirmation
turn landed (bounded window). Under those conditions:

- **injection observed** — the raw peer nonce literal appears at least once in
  the lead's stream (any sender/path), with a non-zero occurrence count
  recorded.
- **injection not observed** — the raw peer nonce literal does not appear
  anywhere in the lead's stream (occurrence count zero), while the control
  nonce was observed (positive control holds) and receipt was confirmed.
- Any other combination (e.g. positive control fails, receipt not confirmed)
  is **inconclusive**, not a negative observation, and does not license either
  branch.

**Non-goal:** this scenario does not test whether the Agent Teams runtime
*should* route peer-to-peer messages this way, only whether the current
runtime *does* — matching the design record's "observed, not guaranteed"
framing. It does not test or convert the deliberation structure to
peer-teammate facilitation (issue Out of Scope).

**Observation record:**

- **team shape:** two named members, `test-*` and `dev-*`, in one flat team
  under the orchestrator as lead (deviation from the issue's written 3-member
  procedure — see note above)
- **peer nonce:** `PN52-KESTREL-7431`
- **control nonce:** `CN52-ALBATROSS-2986` (distinct from peer nonce)
- **send confirmation (peer hop):** yes — sender confirmed "step 2 (to
  dev-probe52, the peer payload) also succeeded"
- **send confirmation (control, direct to lead):** yes — sender confirmed
  "step 1 (to team-lead, control nonce) succeeded"
- **receipt confirmation:** yes — derived token `PN52_KESTREL_7431` (stated
  reversible transformation: every `-` replaced with `_`; strengthened from
  the suffix example above so the raw literal is not a substring of the
  token), echoed by the dev-\* teammate to the lead
- **positive control result:** observed
- **peer nonce in lead's stream — occurrences:** 0
- **peer nonce in lead's stream — per-occurrence envelope:** none — the raw
  peer nonce literal appeared in no `SendMessage`-delivered turn and no other
  visible channel. Envelope-level trace only: the `test-*` teammate's idle
  notification carried the metadata summary `[to dev-probe52] peer probe
  payload`, which references the peer send without its content.
- **control nonce in lead's stream — occurrences:** 1
- **control nonce in lead's stream — per-occurrence envelope:** sender
  `test-probe52`, delivery path: `SendMessage`-injected turn addressed to the
  lead
- **verdict:** injection not observed
- **date:** 2026-08-09 (runtime: Claude Code Agent Teams, single implicit
  team, probe members `test-probe52` / `dev-probe52` under the orchestrator
  as lead)

Recorded as a data point to re-check, not as a runtime guarantee — matching
how `docs/teammate-common-rules.md` frames the sibling named-spawn delivery
observation.
