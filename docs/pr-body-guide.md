# PR Body Authoring Guide

PR body 작성 시 참고하는 가이드. delivery module과 수동 PR 작성자 모두 대상.

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
- 기록 폴더(`<attempt-dir>/*`)의 scratch 는 리뷰 입력으로 링크하지 않고, 리뷰어가 봐야 할 근거는
  linked issue 나 commit 된 문서, 또는 PR body 로 옮긴다.

정책: Repository documents may be used as review evidence only when the PR links or
names the relevant document/section, or when the reviewer independently discovers
directly relevant repo context while tracing the changed surface. Do not rely on
reviewers to infer hidden design intent from unrelated repository documents.

### 5. Verification dispositions (검증 처분의 노출)

AutoFlow가 연 host PR body는 `## Verification dispositions` 섹션을 싣는다 — verification design이
실행 가능한 test가 아닌 방법으로 검증하는 모든 항목(applied criterion과 feature design이 범위에 포함한
항목)을, 그 row에 적힌 검증 방법과 사유와 함께 나열한다. 처분을 부르는 말은 design의 것이다.

- 운영자 주도 PR(AutoFlow 모듈 밖에서 운영자가 진행한 작업의 PR)에는 이 섹션을 요구하지 않는다.
  verification design이 없기 때문이다. 수용 기준의 충족은 *6. 수용 기준 대조*로 보인다.
- 이 섹션은 3단 acceptance-criterion guard의 두 번째 tier다: design module이 검증
  방법의 축소를 결정하고, review module의 reviewer가 그 reason의 타당성을 판단하며,
  criterion의 **내용**이 바뀔 때는 그 변경을 보인 모듈이 advisor를 spawn해 정하고 그 결정을 따른다
  ([`role-contracts.md`](role-contracts.md) > Advisor). 규칙 본문은 [U3 Design](units/design.md) >
  *Test necessity* 와 *Report routing*.
- 형식은 항목 id + 검증 방법 + reason 한 줄. reason은 verification design의 셀을
  옮겨 적고 새로 쓰지 않는다.
- 모든 항목이 실행 가능한 test로 검증되면 섹션을 생략하지 않고 그 사실을 한 줄로 적는다.
- target 트리에 남지 않는 한 번 실행한 test는 같은 섹션에 그 항목의 **run record** — build
  report의 `## Run record`에 기록된 command와 summary line — 를 한 줄로 싣는다
  ([U6 Delivery](units/delivery.md) > *Push and pull request*).
- AI가 도구로 관찰해 검증한 항목은 같은 섹션에 실행 주체, observation record의 경로와 결과 줄을
  한 줄로 싣는다. 사람의 관찰이나 mock으로 검증한 항목은 reason에 그 이유를 싣고, 도구가 없어서라면
  그 도구 요청을 *7. 도구 요청*에 적는다 ([`submodule-common-rules.md`](submodule-common-rules.md) >
  Verification and Tools > *The tools the work needs*; [U3 Design](units/design.md) > *Tools*).
- 변경이 target 트리에 **추가한 테스트 파일**은 같은 섹션에 파일별로 나열한다 — 경로,
  남겨 두는 이유, 그리고 ci module이 확인한, 그 파일을 실제로 실행한 CI job(실행한 job이 없으면 그
  사실, target에 CI가 없으면 `no CI; local run only`). 추가한 파일이 없으면 그 사실을 한 줄로 적는다
  ([`submodule-common-rules.md`](submodule-common-rules.md) > Verification and Tools > *What a change leaves in the target's tree*;
  [U6 Delivery](units/delivery.md) > *CI*, *Added test files*).

예:

```
## Verification dispositions

- AC2 — existing-coverage: `scripts/test/check-suite-manifest.sh` 가 동일 property를
  build마다 검사한다.
- AC4 — none: 값이 사용자가 편집하는 sample 파일에 있어, 첫 편집에서 검증 대상이
  사라진다. 부재 비용 0.
- AC1 — one-shot test: `bash <attempt-dir>/build-1/local/ac1-retry.sh` → `PASS 3/3`
- AC3 — AI observation (browser): `<attempt-dir>/build-1/local/ac3-observation.md` →
  `observation: match` — 렌더링된 목록 화면을 이슈가 링크한 시안과 대조.
- Added test files: `tests/retry-backoff.test.ts` — 재시도 간격은 배포 후 설정값에
  따라 달라지므로 target의 회귀 대상; CI job `unit (ubuntu-latest)`에서 실행 확인.
```

### 6. 수용 기준 대조

운영자 주도 PR과 AutoFlow PR 모두, PR body에 linked issue의 수용 기준을 대조하는 절을
싣는다.

- 절 머리에 결과가 어느 commit 기준인지 밝힌다: "`<sha>` 시점의 결과".
- 기준마다 한 줄로 쓴다: 기준 번호(AutoFlow PR은 applied criteria의 id),
  충족 여부, 확인한 commit, 근거 위치(`path` > section, `path:line`, 실행 기록의 summary line 등).
- 충족하지 못했거나 일부만 충족한 기준은 그렇게 적고 사유를 같은 줄에 붙인다. 후속 처리는
  *3. 한계와 known gaps*에 적는다.
- 이 절은 AutoFlow PR의 *5. Verification dispositions*를 대신하지 않는다. dispositions는 검증 방법의
  처분이고, 이 절은 기준의 충족 여부다.
- 항목은 제시만 한다. 이 형식을 검사하는 장치는 없다.

예:

```
## 수용 기준 대조 (#42)

`a1b2c3d` 시점의 결과.

- 1 — 충족 · `a1b2c3d` · `src/retry.ts:40-58`, `<attempt-dir>/build-1/local/ac1-retry.log` → `PASS 3/3`
- 2 — 충족 · `9f8e7d6` · `docs/retry.md` > Backoff
- 3 — 일부 충족: 설정 파일 경로만 반영, 환경변수 경로는 후속 #43 · `a1b2c3d` · `src/config.ts:12`
```

### 7. 도구 요청

AutoFlow PR body는 작업의 모든 도구 요청 — invocation이 주는 각 실행의 `tool-requests.json`
(`tool_requests`) — 을 싣는다. 요청마다 없었던 것, 대신 한 것, 그 때문에 검증하지 못한 것을 한 줄로
적어, 운영자가 도구를 갖추고 다시 실행할지, PR을 닫고 도구를 따로 갖출지, merge하고 도구를 더할지
정할 수 있게 한다 ([U6 Delivery](units/delivery.md) > *Push and pull request*).

---

## 적용

본 가이드는 권고. PR 유형에 따라 일부 섹션은 적용되지 않을 수 있다.

- [U6 Delivery](units/delivery.md) > *Push and pull request*, *CI* 가 본 가이드를 cross-reference (delivery module, ci module).
- 수동 PR 작성 시도 동일하게 참조.

새 principle 추가 시 형식 유지 (이름 + 본문 + 예시 1-2건).
