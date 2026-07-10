# AutoFlow Improvement Backlog

방법론 감사 및 사이클 구동 스캔에서 생존한 개선 finding의 **내구 기록 및 향후 개선 백로그**.
작업자가 여러 머신에서 작업하므로, 로컬 산출물(.autoflow 보고서·세션 메모리) 대신 본 문서가 공유 기준이다.
공개 트리는 빈 상태로 시작한다 — 이전 내부 감사 기록은 공개용 트리 정리(issue #985)에서 분리되었다.

## finding 포맷

각 finding은 `### \`<id>\` — <제목>` 블록으로 기록하며, 본문 필드는
**분류 / 문제 / 영향 / 권고 / 검증 / 근거 anchor**(필요 시 **재발 상태**)를 갖는다.
PREFLIGHT step 1.5 교차-이슈 스캔(`scripts/preflight/scan-cross-issue-recurrence.sh --format=backlog`)이
방출하는 candidate 블록도 동일 grammar를 따른다 (id 네임스페이스 `xissue-scan-<class>-<날짜>`).

## 운영 규칙

- 본 백로그의 항목을 착수할 때: 항목을 이슈로 승격(단독 또는 기존 epic 슬라이스)하고, 본 문서의 해당 항목에 처분(이슈 번호)을 기입한다.
- 항목이 다른 작업으로 해소된 경우: 처분 줄에 해소 근거(PR/커밋)를 기입한다 — 항목 삭제 대신 처분 기록을 남긴다.
- anchor 검증: 착수 전 인용문 기준으로 현행 위치를 재확인한다.
- 사이클 구동 교차-이슈 스캔 intake (#954): PREFLIGHT step 1.5의 cross-issue recurrence 스캔(`scripts/preflight/scan-cross-issue-recurrence.sh`)이 `docs/cycle-digest.jsonl`에서 한 class 토큰이 최근 M=20 레코드 내 서로 다른 K=3 이슈에 재발하면, `xissue-scan-<class>-<날짜>` id 네임스페이스의 **candidate** finding을 기존 `###` finding 포맷으로 방출한다. 이 항목은 **기계 방출·인간 승격 대기**다 — 자동 수정·평가 기준 변경은 없다(Decision 4). 승격 시 다른 항목과 동일하게 처분(이슈 번호)을 기입하고 삭제하지 않는다. append는 dev 브랜치의 별도 `chore(preflight-scan)` 인프라 커밋으로 수행되며 PREFLIGHT clean-tree 창 밖에서, main이 아닌 dev 브랜치에서만 이뤄진다.

---

## Findings

(현재 없음 — 스캔 candidate 또는 감사 finding이 이 절 아래에 append된다.)
