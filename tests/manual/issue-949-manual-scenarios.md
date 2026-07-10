# Issue #949 — Manual/Environment-Dependent Verification Scenarios (Tier-3)

This acceptance criterion is **not** covered by
`tests/test-issue-949-manifest-regen-doc.sh` — it is a behavioral claim about
a *future* AutoFlow cycle's outcome, not a fact derivable from this cycle's
repo tree. Delegated per the verification design
(`.autoflow/issue-949-verification-design.md` §1/§2, "Testability
assessment") and the feature design's non-goals
(`.autoflow/issue-949-feature-design.md` §6): **AC4 is tracking-only and does
not gate this cycle's VERIFY / VALIDATE / GATE:QUALITY.**

---

## AC4 — next delivery-doc-editing cycle produces no post-hoc AC2e regen commit (Tier 3)

**Why not automated / not this cycle:** the acceptance criterion is "the next
cycle that edits a manifest-registered source does NOT need a separate,
post-hoc `regen manifest hashes …` fix-up commit after discovering CI `AC2e`
staleness" — this is only observable by watching a *later* cycle's commit
log and CI run. There is no artifact in *this* cycle's repo tree to assert
against (the witness does not exist yet); this cycle's own manifest-regen
commit (dogfooding AC-DOGFOOD/AC-SCOPE) is the *first* supporting data point,
not the AC4 witness itself.

**Precedent this closes (the failure mode AC4 checks for):**

- #798 → `ecf8bae` (post-hoc regen fix-up commit after CI `AC2e` failure)
- #799 → `4c2f5a4` (post-hoc regen fix-up commit after CI `AC2e` failure)
- #800 → `9ec9a9c` + `607720e` (two post-hoc regen fix-up commits)

**Steps (run at the next cycle that edits a `copy`-kind manifest source —
i.e. any file listed by `jq -r '.artifacts[].source' setup/manifest.json`):**

1. At that cycle's GREEN step, confirm the Developer AI ran
   `setup/gen-manifest-hashes.sh` and staged the regenerated
   `setup/manifest.json` in the **same** commit as the source edit (per
   `docs/autoflow-guide.md` > GREEN step 3, the mechanism this issue adds).
2. At that cycle's VALIDATE step, confirm the manifest-coherence checklist
   item (`docs/autoflow-guide.md` > VALIDATE item 5, added by this issue) was
   checked off, not skipped.
3. Walk that cycle's commit log (`git log --oneline <cycle-branch>`) and
   confirm there is **no** commit whose message matches a post-hoc
   staleness fix-up pattern (e.g. `regen manifest hashes`, `fix.*manifest`,
   `CI AC2e` appearing *after* the feature/fix commit that touched the
   manifest source, rather than in the same commit).
4. Confirm CI's `e2e-dummy-target` workflow (`tests/plugin/verify-install-into-target.sh`
   `AC2e`, `:635-671`) passed on the **first** CI run for that cycle's PR —
   not after a corrective push.

**Pass condition:** steps 1-2 were followed procedurally (not the observation
target itself), AND the commit log shows exactly one commit per manifest
source edit (edit + regen together), AND CI `AC2e` was green on the first
run — no corrective "regen manifest hashes" push was needed.

**Fail condition / signal to re-open:** a post-hoc regen commit appears in
that cycle's log, or CI `AC2e` failed and required a corrective push. This
would mean the playbook additions this issue makes (GREEN `[MUST]`, VALIDATE
item 5, ARCHITECT allow-list convention, `Derived artifacts` canonical
definition) did not actually change AI behavior — a design defect to file as
a new issue, not a re-litigation of this cycle's already-settled scope.

**Evidence recording:** record the observation (cycle/issue number, whether a
post-hoc regen commit occurred, CI first-run result) as a 1-line note in that
future cycle's PR body or decision ledger — this is the empirical
confirmation of AC4, deferred by design (verification design §2, "AC4 —
not automatable this cycle").

**Explicitly excluded from this cycle's gates:** this scenario is a tracking
item for the *next* cycle, not a manual test the user must run now. It does
not block this cycle's VERIFY, VALIDATE, or GATE:QUALITY (feature design §6,
non-goals).
