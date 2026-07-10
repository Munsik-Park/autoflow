#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
#
# resync-submodules.sh
# ---------------------------------------------------------------------------
# 호스트 레포의 서브모듈 "재구조화"(예: services/librechat → services=llmroute
# 중첩)를 여러 작업 환경에서 안전·멱등하게 로컬 정렬한다.
#
# `git pull --recurse-submodules` 단독으로는 처리되지 않는 세 가지를 보정한다.
#   1) .git/config 의 옛 서브모듈 섹션 잔재 (.gitmodules 에 더는 없는 이름)
#   2) 미초기화 서브모듈 경로를 막고 있는 옛 체크아웃 working tree 잔재
#   3) 현재 서브모듈과 무관한 .git/modules/<orphan> 고아 gitdir
#
# 특정 서브모듈 이름을 하드코딩하지 않는다 — 모두 .gitmodules 에서 도출하므로
# 이미 정렬된 환경에서는 no-op 이고, 향후 다른 재구조화에도 그대로 쓸 수 있다.
#
# 사용법 (호스트 레포 안 어디서든 실행):
#   bash scripts/resync-submodules.sh             # 정렬 실행
#   bash scripts/resync-submodules.sh --dry-run   # 무엇을 할지 출력만 (변경 없음)
#   bash scripts/resync-submodules.sh --force     # 잔재에 미커밋 변경이 있어도 폐기하고 강행
# ---------------------------------------------------------------------------
set -euo pipefail

FORCE=0
DRY=0
for a in "$@"; do
  case "$a" in
    --force)   FORCE=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "알 수 없는 인자: $a (사용 가능: --dry-run, --force)" >&2; exit 2 ;;
  esac
done

do_git() { if [ "$DRY" = 1 ]; then echo "  DRY: git $*"; else git "$@"; fi; }
do_rm()  { if [ "$DRY" = 1 ]; then echo "  DRY: rm -rf -- $1"; else rm -rf -- "$1"; fi; }

# 잔재 경로(p)가 "삭제해도 안전한 clean Git residue"인지 양성 판정한다.
# 안전 조건(모두 충족): ① 하위에 git working tree가 하나 이상 존재하고,
# ② 그 working tree들이 모두 clean(untracked 포함)하며, ③ working tree 밖의
# 일반 파일이 없다(= 경로 전체가 git checkout 들로만 설명됨).
# 하나라도 어긋나면(=git 흔적 없는 일반 데이터/dirty/분류 불가 파일) 1을 돌려
# non-force 삭제를 막는다. 반환 0=삭제 안전, 1=안전하지 않음(사유 stderr).
is_removable_residue() {
  local p="$1" gitf root stray
  local roots=()
  # ① git working tree root 수집 (.git 은 submodule=파일/일반 repo=디렉터리 모두 매칭)
  while IFS= read -r gitf; do
    roots+=( "$(dirname "$gitf")" )
  done < <(find "$p" -maxdepth 4 -name .git 2>/dev/null)
  if [ "${#roots[@]}" -eq 0 ]; then
    echo "    ↳ git checkout 흔적 없음 — 일반 파일/디렉터리로 보임: $p" >&2
    return 1
  fi
  # ② 각 working tree clean 확인 (untracked/수정 모두)
  for root in "${roots[@]}"; do
    if [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]; then
      echo "    ↳ 미커밋/untracked 변경: $root" >&2
      return 1
    fi
  done
  # ③ git checkout 밖의 잔여 파일 검사 (각 root 를 prune → node_modules 등 미탐색)
  local pruneargs=()
  for root in "${roots[@]}"; do
    pruneargs+=( -path "$root" -prune -o )
  done
  stray="$(find "$p" "${pruneargs[@]}" -type f -print 2>/dev/null | head -n 1)"
  if [ -n "$stray" ]; then
    echo "    ↳ git checkout 밖의 파일 존재(예: $stray)" >&2
    return 1
  fi
  return 0
}

# ── 0. 호스트 레포 루트로 이동 ─────────────────────────────────────────────
cd "$(git rev-parse --show-toplevel)"
echo "▶ repo: $(pwd)   (dry-run=$DRY, force=$FORCE)"

# ── 1. 호스트 superproject 최신화 (fast-forward 만; 로컬 미머지 커밋은 보존) ─
branch="$(git rev-parse --abbrev-ref HEAD)"
echo "▶ host fetch ($branch)"
if [ "$DRY" = 1 ]; then
  # dry-run은 무변경 계약 — fetch는 .git/FETCH_HEAD·remote-tracking ref(특히 --prune
  # 삭제)를 바꾸므로 dry-run에서는 실행하지 않고 예정 작업으로만 출력한다.
  echo "  DRY: git fetch --prune origin"
else
  git fetch --prune origin || { echo "✗ fetch 실패 (네트워크/원격 확인)" >&2; exit 1; }
fi
if [ "$branch" = "HEAD" ]; then
  echo "  detached HEAD — host 머지 생략(서브모듈 정렬만 진행)"
elif [ "$DRY" = 1 ]; then
  echo "  DRY: git merge --ff-only origin/$branch"
elif ! git merge --ff-only "origin/$branch"; then
  echo "✗ host fast-forward 실패: 로컬에 미머지 커밋이 있을 수 있음. 수동 정리 후 재실행." >&2
  exit 1
fi

# ── 2. .gitmodules → .git/config 재배선 ───────────────────────────────────
echo "▶ submodule sync"
do_git submodule sync --recursive

# 현재 .gitmodules 의 서브모듈 이름 집합 (정렬 기준)
# [MUST] zero-submodule 가드: .gitmodules 가 없거나(=single-repo, #798 이후 이 레포)
# 서브모듈 엔트리가 0개면 `git config --get-regexp` 는 exit 1 을 반환한다. `set -euo
# pipefail` 아래에서 이 할당이 실패해 스크립트가 중단되므로, 파이프 전체에 `|| true`
# 를 붙여 no-match 시 gm_names 를 빈 문자열로 만든다(early-exit 아님 — 이후 3~6단계가
# 그대로 실행되어 .git/config 옛 섹션과 고아 gitdir 잔재를 정리해야 한다). sed 정규화는
# [MUST] 유지: 이를 빼면 gm_names 항목이 bare <name> 이 아니라 `submodule.<name>.path`
# 가 되어, 살아있는 서브모듈이 있는 multi-repo 타깃에서 3·5단계의 grep -qxF 비교가
# 어긋나 active 섹션/gitdir 을 오삭제한다(zero-submodule oracle 로는 못 잡는 회귀).
gm_names="$(git config -f .gitmodules --name-only --get-regexp '^submodule\..*\.path$' \
            | sed -e 's/^submodule\.//' -e 's/\.path$//' || true)"

# ── 3. .git/config 의 옛 서브모듈 섹션 제거 (.gitmodules 에 없는 이름) ─────
echo "▶ stale .git/config 섹션 점검"
cfg_names="$(git config --local --name-only --get-regexp '^submodule\..*\.url$' 2>/dev/null \
             | sed -e 's/^submodule\.//' -e 's/\.url$//' || true)"
if [ -n "$cfg_names" ]; then
  while IFS= read -r nm; do
    [ -z "$nm" ] && continue
    if ! printf '%s\n' "$gm_names" | grep -qxF "$nm"; then
      echo "  제거: submodule.$nm"
      if [ "$DRY" = 1 ]; then echo "  DRY: git config --remove-section submodule.$nm"
      else git config --local --remove-section "submodule.$nm" 2>/dev/null || true; fi
    fi
  done <<EOF
$cfg_names
EOF
fi

# ── 4. 미초기화 서브모듈 경로의 옛 working tree 잔재 제거 ──────────────────
echo "▶ 미초기화 경로 잔재 점검"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  flag="${line:0:1}"; rest="${line:1}"
  rem="${rest#* }"; subpath="${rem%% *}"      # "<sha> <path> (desc)" → <path>
  [ "$flag" = "-" ] || continue               # '-' = 미초기화
  if [ -d "$subpath" ] && [ -n "$(ls -A "$subpath" 2>/dev/null)" ]; then
    echo "  잔재 발견: $subpath"
    if is_removable_residue "$subpath"; then
      do_rm "$subpath"                       # clean Git residue — 삭제 안전
    elif [ "$FORCE" = 1 ]; then
      echo "  --force: 안전 판정 실패했으나 강제 폐기"
      do_rm "$subpath"
    else
      echo "✗ '$subpath' 는 clean Git residue로 확인되지 않음(위 사유). 데이터일 수 있으니 백업/이동 후 --force 로 재실행." >&2
      exit 1
    fi
  fi
done < <(git submodule status)

# ── 5. .git/modules 의 고아 gitdir 제거 (현재 서브모듈 이름과 무관한 것) ───
echo "▶ orphan gitdir 점검"
if [ -d .git/modules ]; then
  for d in .git/modules/*/; do
    [ -d "$d" ] || continue
    nm="$(basename "$d")"
    if ! printf '%s\n' "$gm_names" | grep -qxF "$nm"; then
      echo "  고아 gitdir 제거: $d"
      do_rm "${d%/}"
    fi
  done
fi

# ── 6. 새 중첩 구조 init + 체크아웃 ───────────────────────────────────────
echo "▶ submodule update --init --recursive"
do_git submodule update --init --recursive

# ── 7. 검증 ───────────────────────────────────────────────────────────────
echo "▶ verify"
if [ "$DRY" = 1 ]; then
  echo "  (dry-run: 실제 변경 없음 — 위 DRY 항목이 실행 예정 작업)"
  exit 0
fi
st="$(git submodule status --recursive)"
printf '%s\n' "$st"
if printf '%s\n' "$st" | grep -qE '^[-+U]'; then
  echo "✗ 일부 서브모듈이 아직 미정렬(-/+/U 플래그). 위 출력을 확인하세요." >&2
  exit 1
fi
echo "✓ 모든 서브모듈 동기화 완료"
