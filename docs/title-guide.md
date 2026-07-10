# Issue & PR Title Guide

이슈와 PR 제목은 목록 화면에서 스캔할 때 **타입 → epic 위치 → 이슈 번호** 순으로
즉시 파악할 수 있어야 한다. 공통 접두어를 대괄호로 묶고, 나머지 설명은 자유롭게 기술한다.

## 형식

```
[type · epic-slice · #N]  자유 설명    ← epic 서브이슈 PR
[type · epic-slice]       자유 설명    ← epic 서브이슈 (이슈 생성 시 번호 미정)
[type · #N]               자유 설명    ← 독립 이슈 / epic 트래커 / 독립 이슈 PR
```

| 항목 | 설명 |
|------|------|
| `type` | `feat` / `fix` / `chore` / `docs` — 아래 표 참고 |
| `epic-slice` | Epic 번호와 슬라이스 코드 (`#73-S3f`, `#72-S5a` 등). epic 서브이슈에만 사용 |
| `#N` | GitHub 이슈 번호. **이슈 제목에는 생략 가능** (생성 전 번호 미정); **PR 제목에는 필수** |
| 자유 설명 | 길이·언어 제한 없음 |

## type 값

| type | 언제 |
|------|------|
| `feat` | 새 기능 구현 |
| `fix` | 버그 수정 |
| `chore` | 설정·인프라·자동화 |
| `docs` | 문서 단독 변경 |

## 예시

### 이슈 제목

```
[feat · #73-S3f]  소진 내역 탭 프론트 — 기간 필터 + 검색
[feat · #72-S5a]  멤버 관리 테이블 프론트엔드
[feat · #224]     Enterprise 멤버 활동 감사 로그 구현
[fix  · #200]     YouTube 자막 취득 실패 — youtubeiAdapter track.fetch() 제거
[chore · #43]     PAT rotation 문서화
```

### PR 제목

```
[feat · #73-S3f · #231]  소진 내역 탭 프론트 — 기간 필터 + 검색
[feat · #72-S5a · #217]  멤버 관리 테이블 프론트엔드
[feat · #224]             Enterprise 멤버 활동 감사 로그 (submodule pointer)
[fix  · #200]             YouTube 자막 취득 실패 — youtubeiAdapter
[chore · #43]             PAT rotation 문서화
```

## 접두어 구성 원리

`epic-slice`와 `#N`은 역할이 다르다. 같이 써도 혼란스럽지 않다.

| 참조 | 의미 | 이슈 | PR |
|------|------|------|----|
| `epic-slice` (`#73-S3f`) | 어느 Epic의 몇 번째 슬라이스인가 | ✅ | ✅ |
| `#N` (이슈 번호) | 어떤 GitHub 이슈를 닫는가 | 생략 가능 | **필수** |

epic 서브이슈가 아닌 경우(독립 이슈, epic 트래커)는 `epic-slice` 없이 `#N`만 사용한다.

## 커밋 메시지와의 관계

커밋 메시지 규칙(`CLAUDE.md` > Commit Rules)은 별도로 유지된다.

```
feat(#231): 소진 내역 탭 프론트 — 기간 필터 + 검색   ← 커밋
[feat · #73-S3f · #231] 소진 내역 탭 프론트            ← PR 제목
```

커밋은 `type(#N):` 형식, 이슈·PR 제목은 `[type · ref]` 형식으로 구별한다.
두 형식 모두 `type`과 이슈 번호를 포함하므로 상호 추적이 가능하다.

---

## Changelog

- 2026-06-02: 초기 작성.
