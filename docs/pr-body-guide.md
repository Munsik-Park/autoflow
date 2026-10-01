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

AutoFlow cycle의 host PR body는 `## Verification dispositions` 섹션을 싣는다 — issue의 acceptance
criterion 중 automated test로 검증되지 않는 모든 항목을, 그 disposition
(`existing-coverage` / `delivery-check` / `manual` / `environment-dependent` /
`none`) 과 verification design row에 적힌 한 줄 reason과 함께 나열한다.

- 운영자 주도 PR(AutoFlow cycle 밖에서 운영자가 진행한 작업의 PR)에는 이 섹션을 요구하지 않는다.
  verification design이 없기 때문이다. 수용 기준의 충족은 *6. 수용 기준 대조*로 보인다.
- 이 섹션은 3단 acceptance-criterion guard의 두 번째 tier다: design unit이 검증
  방법의 축소를 결정하고, external reviewer가 그 reason의 타당성을 판단하며,
  advisor는 criterion의 **내용**이 바뀔 때만 1차 판단하고 운영자는 재시도 단계에서 그 판단을 번복할 수 있다
  ([`role-contracts.md`](role-contracts.md) > Advisor). 규칙 본문은 [U3 Design](units/design.md) >
  Output artifacts > *Test necessity* 와 *Report routing*.
- 형식은 AC id + disposition + reason 한 줄. reason은 verification design의 셀을
  옮겨 적고 새로 쓰지 않는다.
- issue AC 전부가 `automated` 이면 섹션을 생략하지 않고 그 사실을 한 줄로 적는다.
- `cycle` 층의 `automated` row(`Type` 셀에 `standing:` 토큰이 없는 row)는 같은 섹션에 그
  row의 **run record** — build report의 `## Run record`에 기록된 command와 summary line — 를 한 줄로 싣는다
  ([U6 Delivery](units/delivery.md) > *Push and pull request*).
- AI가 도구로 실행한 `manual` row는 같은 섹션에 실행 주체, observation record의 경로와 결과 줄을
  한 줄로 싣는다. 사람이 실행하는 `manual` row는 reason에 도구를 확보할 수 없었던 이유가 들어
  있다 ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *The tools the work needs*; [U3 Design](units/design.md) > *Tools*).
- cycle이 target 트리에 **추가한 테스트 파일**은 같은 섹션에 파일별로 나열한다 — 경로,
  남겨 두는 이유, 그리고 HANDOFF의 CI 확인에서 `scripts/handoff/ci-test-file-jobs.sh`가 CI job 로그에서 찾은 실행 job(target에 CI가 없으면
  `no CI; local run only`). 추가한 파일이 없으면 그 사실을 한 줄로 적는다
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *What a cycle leaves in the target's tree*;
  [U6 Delivery](units/delivery.md) > *CI* > *Added test files*).

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

### 6. 수용 기준 대조

운영자 주도 PR과 AutoFlow cycle PR 모두, PR body에 linked issue의 수용 기준을 대조하는 절을
싣는다.

- 절 머리에 결과가 어느 commit 기준인지 밝힌다: "`<sha>` 시점의 결과".
- 기준마다 한 줄로 쓴다: 기준 번호(cycle PR은 분석 report `## Acceptance criteria`의 AC id),
  충족 여부, 확인한 commit, 근거 위치(`path` > section, `path:line`, 실행 기록의 summary line 등).
- 충족하지 못했거나 일부만 충족한 기준은 그렇게 적고 사유를 같은 줄에 붙인다. 후속 처리는
  *3. 한계와 known gaps*에 적는다.
- 이 절은 cycle PR의 *5. Verification dispositions*를 대신하지 않는다. dispositions는 검증 방법의
  처분이고, 이 절은 기준의 충족 여부다.
- 항목은 제시만 한다. 이 형식을 검사하는 장치는 없다.

예:

```
## 수용 기준 대조 (#42)

`a1b2c3d` 시점의 결과.

- 1 — 충족 · `a1b2c3d` · `src/retry.ts:40-58`, `.autoflow/issue-42-local/ac1-retry.log` → `PASS 3/3`
- 2 — 충족 · `9f8e7d6` · `docs/retry.md` > Backoff
- 3 — 일부 충족: 설정 파일 경로만 반영, 환경변수 경로는 후속 #43 · `a1b2c3d` · `src/config.ts:12`
```

---

## 적용

본 가이드는 권고. PR 유형에 따라 일부 섹션은 적용되지 않을 수 있다.

- [U6 Delivery](units/delivery.md) > *Push and pull request* 가 본 가이드를 cross-reference (AI orchestrator).
- 수동 PR 작성 시도 동일하게 참조.

새 principle 추가 시 형식 유지 (이름 + 본문 + 예시 1-2건).
