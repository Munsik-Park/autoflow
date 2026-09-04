# PR Body Authoring Guide

PR body 작성 시 참고하는 가이드. AI orchestrator와 수동 PR 작성자 모두 대상.
가이드는 living document — 시간이 지나며 항목이 추가될 수 있다.

## Principles

### 1. Claim의 정확도

PR이 body에서 약속하는 동작 / 검증 / 보호 범위는 실제로 구현하는 것과 정확히
일치해야 한다. overstated claim (실제보다 강한 약속) 은 리뷰에서 catch되며
추가 round-trip을 만든다.

- 강한 표현 (machine-verified, fully enforced, idempotent, atomic, race-free
  등) 은 실제로 그 수준을 충족할 때만 사용.
- 부분적 보장은 부분적으로 명시 — "X는 machine-verified, Y는 reviewer-attested"
  처럼 분리 가능하면 분리.

### 2. 거부된 대안의 노출

implementation을 결정하는 과정에서 고려했으나 거부한 대안이 있다면, 거부
사유와 함께 body에 노출한다. 리뷰어가 거부 정당화의 타당성을 평가할 수 있게
한다.

- 거부 사유는 정확하게: "architectural boundary 위반"인지 "비용 trade-off"인지
  분명히 구분.
- 간단한 PR (typo fix 등) 에는 적용되지 않을 수 있다.

### 3. 한계와 known gaps

이 PR이 cover하지 않는 path / 잔존 risk / 후속 작업이 필요한 항목을 명시.
이미 인지된 한계를 리뷰어가 다시 catch하지 않게 한다.

- "이 PR이 다루지 않는 것" 섹션 또는 body 본문에 단락으로.
- 후속 issue 번호가 있다면 cross-reference.

### 4. 판단 근거의 명시적 링크 (PR-reachability)

리뷰어는 PR에서 출발해 판단 근거에 도달할 수 있어야 한다. 문서가 저장소에
존재하는 것만으로는 부족하다 — PR이 어떤 ADR / design note / architecture
context / AC 를 판단 근거로 삼았는지 `path > section` 형태로 명시한다.

- ADR / design note / architecture context 를 명시적으로 링크. ADR 불필요 시
  사유 한 줄 ("ADR not required: ...").
- linked issue 의 AC 를 PR 에서 도달 가능하게 (이슈 링크 + AC 섹션, 또는 body 에 명시).
  AC 미확인으로 인한 반복 `High` 오판을 막는다.
- `.autoflow/*` scratch 는 gitignore 라 PR 에서 도달 불가 — 리뷰 입력으로 링크하지
  않고, 리뷰어가 봐야 할 근거는 linked issue 나 commit 된 문서로 옮긴다.

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
  operator는 criterion의 **내용**이 바뀔 때만 개입한다. reviewer가 보지 못한 축소는
  판단되지 않은 축소다. 규칙 본문은 [`autoflow-guide.md`](autoflow-guide.md) >
  ARCHITECT > Output artifacts > *Test necessity* 와 ARCHITECT > *Report routing*.
- 형식은 AC id + disposition + reason 한 줄. reason은 verification design의 셀을
  옮겨 적고 새로 쓰지 않는다 — PR body와 design이 갈라지면 reviewer가 판단하는
  대상이 무엇인지 불분명해진다.
- issue AC 전부가 `automated` 이면 섹션을 생략하지 않고 그 사실을 한 줄로 적는다.
  빈 섹션과 누락된 섹션은 reviewer에게 구분되지 않는다.

예:

```
## Verification dispositions

- AC2 — existing-coverage: `scripts/test/check-suite-manifest.sh` 가 동일 property를
  build마다 검사한다.
- AC4 — none: 값이 사용자가 편집하는 sample 파일에 있어, 첫 편집에서 검증 대상이
  사라진다. 부재 비용 0.
```

---

## 적용

본 가이드는 권고. PR 유형에 따라 일부 섹션은 적용되지 않을 수 있다.

- [`autoflow-guide.md`](autoflow-guide.md) > HANDOFF 가 본 가이드를 cross-reference (AI orchestrator).
- 수동 PR 작성 시도 동일하게 참조.

새 principle 추가 시 형식 유지 (이름 + 본문 + 예시 1-2건) + Changelog 한 줄.

---

## Changelog

- 2026-08-25: Principle 5 (Verification dispositions — automated 아닌 issue AC의 disposition + reason 노출; 3단 guard의 reviewer tier) 추가 (#153).
- 2026-06-05: Principle 4 (판단 근거의 명시적 링크 / PR-reachability) 추가.
- 2026-05-22: 초기 작성.
