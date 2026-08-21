# Issue #122 — Manual verification scenarios

One acceptance criterion of this cycle is **environment-dependent** and is delegated here
as a recorded observation rather than converted into an assertion or a mock — a design
decision taken at ARCHITECT (`.autoflow/issue-122-verification-design.md` > §1.7 /
§4 *Testability 평가 및 설계 변경 요청*), not a RED-time discovery.

It is not asserted against a threshold, and it is not simulated. The real GitHub API
degrade path sits **outside** the injection boundary the feature design draws for the
retirement-due advisory leg (`.autoflow/issue-122-feature-design.md` > *Retirement-due
advisory* > *Injection boundary — adopted*): the classifier inside
`scripts/test/check-suite-manifest.sh` reads only a record file an env var names, and
performs no network access of any kind. The thin fetch adapter that populates that record
lives outside the lint and is never invoked by it — that adapter's own real-network
behaviour is what this scenario covers.

---

## M1 — `retire-with-network-degrade`: the fetch adapter degrades loudly under real
## GitHub API failure

**Criterion**: `AC-lint-runtime-network` — under an authentication failure or a rate
limit from the real GitHub API, the fetch adapter that populates the retirement-due issue
state record does **not** silently produce an empty or stale record; it degrades in a way
a human operator can see.

**Why it is not a suite leg.** `check-suite-manifest.sh`'s retirement-due classifier is
hermetic by design (`.autoflow/issue-122-feature-design.md` > *Why not in the cycle-scope
guard* — "Deciding whether an issue is merged is not derivable from the tree; it needs a
network call. Putting a network dependency inside a gating hermetic lint makes a CI
outage or an unauthenticated runner into a red build."). The composition-oracle
determination (`.autoflow/issue-122-verification-design.md` §2, "교차 밖 선언") places
GitHub issue open/closed state outside the intersection the oracle rule reaches, precisely
because it is a newly-read out-of-tree input, not shared state a settled decision already
names. A suite leg here would either mock the network (composition-oracle prohibition
does not apply, but a mock is still not evidence of the *real* adapter's degrade
behaviour) or hit the live GitHub API from CI, which is the exact outage-coupling the
design declines.

**What stays automated.** The classifier's own two branches — real record file present
(advisory / degraded-loud text) vs. env var unset (degraded, no record) — are driven from
a real record file inside `tests/test-issue-122-retirement-attribution.sh`'s composition
oracle obligations and the lint's own `--self-test` fixture set (per the verification
design §3, "새 lint leg의 양성·음성·경계 케이스는 각 lint 자신의 `--self-test` fixture
집합"). Only the adapter's behaviour under a *real, failing* network call is manual.

**Who records it, and when.** The **orchestrator or the Developer AI**, once
`scripts/handoff/`-adjacent tooling or a standalone script implements the fetch adapter
(feature design > *Files changed* does not name a fixed path for it; GREEN's report
states the actual path it lands at) — run it once against a deliberately invalid GitHub
token (or with network access blocked) and confirm:

1. the adapter exits non-zero, or writes a record whose format the classifier's degraded
   branch recognises as "unavailable" (never a record claiming `open` or `closed` with no
   real answer behind it);
2. the failure is visible in the adapter's own output (stderr line or exit code), not only
   inferable from a downstream lint going quiet;
3. the classifier, handed no usable record, prints the named-suite degraded line the
   automated legs already assert (`AC-retire-with-degraded-loud`) rather than crediting
   any `retire-with:` suite as either "due" or "clear".

**Procedure**

```bash
# 1. Point the adapter at an invalid credential / unreachable endpoint.
GH_TOKEN=invalid-token bash <path-to-fetch-adapter> > /tmp/issue122-adapter.out 2>&1
echo "adapter exit: $?"
cat /tmp/issue122-adapter.out

# 2. Confirm the classifier's degraded branch is what a downstream record built from
#    that output produces.
ISSUE_STATE_RECORD=/tmp/issue122-adapter.out \
  bash scripts/test/check-suite-manifest.sh 2>&1 | grep -i "degraded\|unavailable"
```

Record the observed exit code, the adapter's stderr line, and the classifier's degraded
output in the cycle's HANDOFF notes. A silent empty record (adapter exits 0, writes
nothing recognisable) is a FAIL of this scenario, not a pass by omission.
