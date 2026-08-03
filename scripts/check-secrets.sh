#!/usr/bin/env bash
# Secrets.xcconfig 검증 — 배포 전에 잘못된 시크릿을 걸러낸다.
#
# 왜 필요한가: GitHub Secret은 값을 다시 읽을 수 없고 전체 덮어쓰기만 된다. 그래서 실수로
# 예시값(구글 테스트 AdMob ID)이나 빈 값을 넣어도 아무 경고 없이 TestFlight까지 올라간다.
# 앱은 AdMob App ID가 없으면 배너를 아예 렌더하지 않고, 로드 실패 시 높이 0으로 숨겨서
# 실패가 조용하다(ClipNote/Ads/AdBannerView.swift). 즉 사람이 알아채기 어렵다.
#
# ⚠️ 이 저장소는 공개다. 값 자체는 절대 출력하지 않는다 — 존재 여부·형식 판정만 찍는다.
#
# 사용: bash scripts/check-secrets.sh [Secrets.xcconfig 경로]
set -uo pipefail

FILE="${1:-Secrets.xcconfig}"

if [ ! -f "$FILE" ]; then
  echo "::error::$FILE 이 없다. deploy.yml 이 SECRETS_XCCONFIG 를 쓰기 전에 호출됐는지 확인."
  exit 1
fi

# `KEY = value` 에서 값만 뽑는다(앞뒤 공백 제거). 값은 변수에만 담고 출력하지 않는다.
value_of() {
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$FILE" | head -1 | sed 's/[[:space:]]*$//'
}

# 구글 공식 테스트 퍼블리셔 — 실배포에 들어가면 실광고가 절대 붙지 않는다.
GOOGLE_TEST_PUB="ca-app-pub-3940256099942544"

fail=0
warn=0

require() {
  local key="$1" v
  v="$(value_of "$key")"
  if [ -z "$v" ]; then
    echo "::error::$key : 비어 있음"
    fail=1
    return 1
  fi
  echo "  $key : 있음"
  return 0
}

echo "SECRETS_XCCONFIG 검증"

require API_BASE && {
  v="$(value_of API_BASE)"
  # xcconfig 는 `//` 를 주석으로 먹는다. 그래서 URL 은 `https:/$()/host` 로 우회해야 한다.
  # 이게 깨지면 API_BASE 가 `https:` 로 잘려 앱이 실행 즉시 죽는다(deploy.yml 주석 참고).
  case "$v" in
    *'$()'*) echo "    └ https:/\$()/ 우회 표기 정상" ;;
    *'//'*)  echo "::error::API_BASE 에 이스케이프되지 않은 // 가 있다 — xcconfig 가 주석으로 잘라 앱이 부팅 중 죽는다. https:/\$()/clipnote.co.kr 형태로 바꿔라."; fail=1 ;;
    *)       echo "::warning::API_BASE 형식을 판정하지 못했다 — 직접 확인 필요."; warn=1 ;;
  esac
}

require SUPABASE_URL
require SUPABASE_ANON_KEY
require NAVER_CLIENT_ID

# AdMob — 앱 ID 는 물결(~), 광고 단위는 슬래시(/). 바꿔 넣으면 광고가 안 붙는다.
check_admob() {
  local key="$1" sep="$2" sepname="$3" v
  require "$key" || return
  v="$(value_of "$key")"
  case "$v" in
    "$GOOGLE_TEST_PUB"*)
      echo "::error::$key 가 구글 테스트 ID($GOOGLE_TEST_PUB)다 — 실광고가 붙지 않는다. AdMob 콘솔의 실제 ID로 교체해라."
      fail=1 ;;
    ca-app-pub-*)
      case "$v" in
        *"$sep"*) echo "    └ 형식 정상($sepname 포함)" ;;
        *) echo "::error::$key 에 $sepname 가 없다 — 앱 ID(~)와 광고 단위 ID(/)를 바꿔 넣은 것 같다."; fail=1 ;;
      esac ;;
    *)
      echo "::error::$key 가 ca-app-pub- 로 시작하지 않는다."
      fail=1 ;;
  esac
}

check_admob ADMOB_APP_ID '~' '물결(~)'
check_admob ADMOB_BANNER_UNIT_ID '/' '슬래시(/)'

echo
if [ "$fail" -ne 0 ]; then
  echo "::error::시크릿 검증 실패 — 배포를 중단한다. 갱신 방법은 docs/DEPLOY.md 참고."
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "검증 통과(경고 있음)."
else
  echo "검증 통과."
fi
