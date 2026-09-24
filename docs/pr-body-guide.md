# PR Body Authoring Guide

PR body 작성 시 참고하는 가이드. AI orchestrator와 수동 PR 작성자 모두 대상.

## Principles

### 1. Claim의 정확도

PR이 body에서 약속하는 동작 / 검증 / 보호 범위는 실제로 구현하는 것과 정확히
일치해야 한다.

- 강한 표현 (machine-verified, fully enforced, idempotent, atomic, race-free
  등) 은 실제로 그 수준을 충족할 때만 사용.
- 부분적 보장은 부분적으로 명시 — "X는 machine-verified, Y는 reviewer-attested"
  처럼 분리 가능하면 분리.

### 2. 거부된 대안의 노출

implementation을 결정하는 과정에서 고려했으나 거부한 대안이 있다면, 거부
사유와 함께 body에 노출한다.

- 거부 사유는 정확하게: "architectural boundary 위반"인지 "비용 trade-off"인지
  분명히 구분.
- 간단한 PR (typo fix 등) 에는 적용되지 않을 수 있다.

### 3. 한계와 known gaps

이 PR이 cover하지 않는 path / 잔존 risk / 후속 작업이 필요한 항목을 명시.

- "이 PR이 다루지 않는 것" 섹션 또는 body 본문에 단락으로.
- 후속 issue 번호가 있다면 cross-reference.

### 4. 판단 근거의 명시적 링크 (PR-reachability)

리뷰어는 PR에서 출발해 판단 근거에 도달할 수 있어야 한다. 문서가 저장소에
존재하는 것만으로는 부족하다 — PR이 어떤 ADR / design note / architecture
context / AC 를 판단 근거로 삼았는지 `path > section` 형태로 명시한다.

- ADR / design note / architecture context 를 명시적으로 링크. ADR 불필요 시
  사유 한 줄 ("ADR not required: ...").
- linked issue 의 AC 를 PR 에서 도달 가능하게 (이슈 링크 + AC 섹션, 또는 body 에 명시).
- `.autoflow/*` scratch 는 리뷰 입력으로 링크하지 않고, 리뷰어가 봐야 할 근거는
  linked issue 나 commit 된 문서로 옮긴다.

정책: Repository documents may be used as review evidence only when the PR links or
names the relevant document/section, or when the reviewer independently discovers
directly relevant repo context while tracing the changed surface. Do not rely on
reviewers to infer hidden design intent from unrelated repository documents.

### 5. Verification dispositions (검증 처분의 노출)

host PR body는 `## Verification dispositions` 섹션을 싣는다 — issue의 acceptance
criterion 중 automated test로 검증되지 않는 모든 항목을, 그 disposition
(`existing-coverage` / `delivery-check` / `manual` / `environment-dependent` /
`none`) 과 verification design row에 적힌 한 줄 reason과 함께 나열한다.

- 이 섹션은 3단 acceptance-criterion guard의 두 번째 tier다: deliberation이 검증
  방법의 축소를 결정하고, external reviewer가 그 reason의 타당성을 판단하며,
  operator는 criterion의 **내용**이 바뀔 때만 개입한다. 규칙 본문은 [`phases/architect.md`](phases/architect.md) >
  Output artifacts > *Test necessity* 와 *Report routing*.
- 형식은 AC id + disposition + reason 한 줄. reason은 verification design의 셀을
  옮겨 적고 새로 쓰지 않는다.
- issue AC 전부가 `automated` 이면 섹션을 생략하지 않고 그 사실을 한 줄로 적는다.
- `cycle` 층의 `automated` row(`Type` 셀에 `standing:` 토큰이 없는 row)는 같은 섹션에 그
  row의 **run record** — VERIFY step 1이 실행한 command와 summary line — 를 한 줄로 싣는다
  (`phases/handoff.md` > step 4).
- AI가 도구로 실행한 `manual` row는 같은 섹션에 실행 주체, observation record의 경로와 결과 줄을
  한 줄로 싣는다. 사람이 실행하는 `manual` row는 reason에 도구를 확보할 수 없었던 이유가 들어
  있다 ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *The tools the work needs*; `phases/architect.md` > *Tools*).
- cycle이 target 트리에 **추가한 테스트 파일**은 같은 섹션에 파일별로 나열한다 — 경로,
  남겨 두는 이유, 그리고 HANDOFF 5단계가 CI 로그에서 확인한 실행 job(target에 CI가 없으면
  `no CI; local run only`). 추가한 파일이 없으면 그 사실을 한 줄로 적는다
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *What a cycle leaves in the target's tree*;
  `phases/handoff.md` > step 4·5).

예:

```
## Verification dispositions

- AC2 — existing-coverage: `scripts/test/check-suite-manifest.sh` 가 동일 property를
  build마다 검사한다.
- AC4 — none: 값이 사용자가 편집하는 sample 파일에 있어, 첫 편집에서 검증 대상이
  사라진다. 부재 비용 0.
- AC1 — automated (cycle): `bash .autoflow/issue-42-local/ac1-retry.sh` → `PASS 3/3`
- AC3 — manual (AI: browser): `.autoflow/issue-42-local/ac3-observation.md` →
  `observation: match` — 렌더링된 목록 화면을 이슈가 링크한 시안과 대조.
- Added test files: `tests/retry-backoff.test.ts` — 재시도 간격은 배포 후 설정값에
  따라 달라지므로 target의 회귀 대상; CI job `unit (ubuntu-latest)`에서 실행 확인.
```

---

## 적용

본 가이드는 권고. PR 유형에 따라 일부 섹션은 적용되지 않을 수 있다.

- [`phases/handoff.md`](phases/handoff.md) 가 본 가이드를 cross-reference (AI orchestrator).
- 수동 PR 작성 시도 동일하게 참조.

새 principle 추가 시 형식 유지 (이름 + 본문 + 예시 1-2건).
