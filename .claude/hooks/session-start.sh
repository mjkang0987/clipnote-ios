#!/bin/bash
# 원격 세션에 개인용 스킬을 설치한다.
#
# **왜 필요한가** — Claude Code 원격 환경에는 플러그인 로더가 없다(`~/.claude/plugins/` 가
# 없고 `/plugin` 도 막혀 있다). 계정에서 플러그인을 켜 두어도 세션에 실리지 않는다.
# 반면 `~/.claude/skills/<이름>/SKILL.md` 는 그대로 읽히므로, 플러그인 안의 스킬만
# 직접 넣어 준다. 슬래시 명령과 훅은 이 방식으로 살아나지 않는다 — 스킬만이다.
#
# **왜 저장소에 담지 않고 매번 받나** — `humanize-korean` 의 라이선스가
# NC-ND(비상업·변경금지)다. ClipNote 는 상업 앱이라 저장소에 넣으면 상업적 이용이자
# 재배포가 된다. 실행 시점에 받아 쓰면 저작물이 저장소에 남지 않는다.
# ponytail 은 MIT, marketing 은 Apache-2.0 이라 제약이 없지만 경로를 갈라 둘 이유가 없다.
#
# **실패해도 세션을 막지 않는다.** 스킬이 없다고 개발이 멈출 이유는 없다. 네트워크가
# 죽었거나 저장소가 사라져도 조용히 넘어간다(항상 exit 0).
#
# 테스트: SKILLS_DIR=/tmp/t CLAUDE_CODE_REMOTE=true .claude/hooks/session-start.sh

# 로컬 맥에서는 돌지 않는다 — 거기서는 claude.ai 플러그인이 정상 동작한다.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

DST="${SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$DST" || exit 0
TMP=$(mktemp -d) || exit 0

# 저장소|스킬이 들어 있는 경로. 경로가 스킬 하나면 그것만, 디렉터리면 그 아래 전부 가져온다.
for entry in \
  "https://github.com/DietrichGebert/ponytail|skills" \
  "https://github.com/anthropics/knowledge-work-plugins|marketing/skills" \
  "https://github.com/modu-ai/cowork-plugins|moai-content/skills/humanize-korean"
do
  url="${entry%%|*}"
  path="${entry#*|}"
  repo="$TMP/$(basename "$url")"

  # blob 필터 + sparse 로 필요한 디렉터리만 받는다. cowork-plugins 는 1300 파일이 넘어
  # 통째로 받으면 세션 시작이 눈에 띄게 느려진다.
  git clone --depth 1 --filter=blob:none --sparse -q "$url" "$repo" 2>/dev/null || continue
  git -C "$repo" sparse-checkout set "$path" >/dev/null 2>&1 || continue

  # 경로가 스킬 하나든 스킬 여럿을 담은 디렉터리든 SKILL.md 를 찾아 그 부모를 쓴다.
  find "$repo/$path" -maxdepth 2 -name SKILL.md -print0 2>/dev/null | while IFS= read -r -d '' f; do
    d=$(dirname "$f")
    name=$(basename "$d")
    # 이미 있으면 건드리지 않는다 — 계정에서 동기화된 같은 이름을 덮어쓰지 않기 위해서다.
    [ -e "$DST/$name" ] || cp -r "$d" "$DST/$name"
  done
done

[ -n "$TMP" ] && rm -rf "$TMP"
exit 0
