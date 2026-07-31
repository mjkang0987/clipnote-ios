#!/usr/bin/env python3
"""문자열 카탈로그 무결성 검사.

리눅스 CI/컨테이너에는 Xcode 가 없어서 `xcodebuild` 로는 못 돌린다. 그런데 다국어가 깨지는
방식은 대부분 **조용하다** — 번역이 빠지면 한국어로 폴백하고, 키를 잘못 쓰면 키가 그대로
그려진다. 빌드도 테스트도 통과한다. 그래서 카탈로그 JSON 을 직접 읽어 다음을 본다.

1. 모든 키가 지원 언어를 다 갖는가 (빠지면 그 언어만 한국어로 나온다)
2. 언어별 포맷 지시자가 한국어와 같은가 (`String(format:)` 인자 개수가 어긋나면 **런타임 크래시**)
3. 코드가 쓰는 키가 카탈로그에 있는가 (없으면 화면에 `settings.title` 같은 키가 그대로 뜬다)
4. 카탈로그 키를 코드가 쓰고 있는가 (죽은 번역이 쌓이는 걸 막는다)
5. 사전화를 마친 파일에 한글 리터럴이 되살아나지 않았는가 (아래 CLEAN_FILES 래칫)
6. 카탈로그가 **정규 형식**으로 저장돼 있는가 (아래 canonical_json 참고)
7. `Text("리터럴")` 이 남아 있지 않은가 (아래 check_text_literals 참고)

사용:
    python3 scripts/check-localizations.py            # 검사
    python3 scripts/check-localizations.py --format   # 카탈로그를 정규 형식으로 다시 쓴다
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Shared/Localization/Localizable.xcstrings"

# `AppLanguage` 와 `project.yml` 의 CFBundleLocalizations 도 같은 목록이어야 한다.
# 그 둘의 일치는 Xcode 가 필요해 `LocalizationStoreTests` 가 본다.
LANGUAGES = ["ko", "en", "ja", "zh-Hans"]
SOURCE_LANGUAGE = "ko"

# 사전화를 끝낸 파일. 여기 올라온 파일에 한글 리터럴이 새로 생기면 실패한다.
# 화면을 하나 끝낼 때마다 여기에 추가한다 — 이 목록이 진행 상황이자 되돌림 방지 장치다.
CLEAN_FILES = [
    "ClipNote/Views/SettingsView.swift",
    "ClipNote/Views/HeaderMenu.swift",
    "ClipNote/Views/RootView.swift",
    "ClipNote/Views/HomeView.swift",
    "ClipNote/Views/HomeViewModel.swift",
    "ClipNote/Clips/ClipsView.swift",
    "ClipNote/Views/EditClipModal.swift",
    "ClipNote/Views/TagApplyModal.swift",
    "ClipNote/Views/ShareResultModal.swift",
    "ClipNote/Views/ClipCardView.swift",
    "ClipNote/Views/SharePreviewCard.swift",
    "ClipNote/Views/LoginView.swift",
    "ClipNote/Auth/AuthStore.swift",
    "ClipNote/Views/AboutView.swift",
    "ClipNote/Views/FaqView.swift",
    "ClipNote/Views/OnboardingView.swift",
    "ClipNote/Views/SpotlightTour.swift",
    "ClipNote/Views/AccountDeleteView.swift",
    "ClipNoteShare/ShareViewController.swift",
    "ClipNote/Views/ConfirmLayer.swift",
]

# 한글이 들어 있어도 번역 대상이 아닌 것.
LITERAL_ALLOWLIST = {
    # 각 언어를 그 언어로 표기하는 게 의도다.
    ("Shared/Localization/AppLanguage.swift", "한국어"),
}

KEY_CALL_START = re.compile(r"\bt\(")
# `Text("…")` — 보간이 들어가도 리터럴이면 `LocalizedStringKey` 로 해석돼 Xcode 가 추출한다.
# `Text(verbatim: "…")` 과 `Text(문자열변수)` 는 걸리지 않는다.
TEXT_LITERAL = re.compile(r'\bText\(\s*"')
STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
HANGUL = re.compile(r"[가-힣]")
# `%@`·`%lld`·`%1$@`·`%.2f` — 위치 지정자·플래그·너비·길이 수식어를 모두 넘겨 변환자를 잡는다.
# 길이 수식어(`ll`)까지 포함해 비교해야 한다: 한국어가 `%lld` 인데 다른 언어가 `%d` 면
# 64비트에서 인자를 잘못 읽는다.
FORMAT_SPEC = re.compile(
    r"%(?:(\d+)\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(hh|h|ll|l|q|z|t|j|L)?([@a-zA-Z])"
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def canonical_json(doc: dict) -> str:
    """카탈로그의 정규 형식.

    **왜 필요한가** — 이 파일은 사람(스크립트)과 Xcode가 번갈아 쓴다. 형식이 다르면 Xcode 가
    문자열 카탈로그를 열거나 빌드할 때마다 자기 형식으로 전체를 다시 써서, 내용이 하나도
    안 바뀌었는데도 파일 전체가 diff 로 잡힌다. 그러면 `git pull` 이 막히고, 매번 로컬 변경을
    버리게 된다(실제로 그렇게 됐다).

    그래서 **Xcode 가 쓰는 형식**에 맞춘다. 문자열 카탈로그는 Foundation `JSONSerialization` 의
    `.prettyPrinted | .sortedKeys` 로 직렬화되므로 다음과 같다.

    - 키·값 구분자가 `" : "` (콜론 앞에도 공백). 파이썬 기본값 `": "` 와 다르다
    - 들여쓰기 2칸, 중첩 객체를 한 줄로 접지 않는다
    - 키는 알파벳순
    - 한글을 이스케이프하지 않는다
    - **끝에 개행을 붙이지 않는다** — `JSONSerialization` 이 만든 바이트를 그대로 쓰기 때문
    """
    return json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))


def check_format(raw: str, doc: dict, errors: list[str]) -> None:
    if raw != canonical_json(doc):
        fail(
            errors,
            "카탈로그가 정규 형식이 아니다 — `python3 scripts/check-localizations.py --format` 로 "
            "다시 쓴다. (형식이 갈리면 Xcode 가 만질 때마다 파일 전체가 diff 로 잡혀 pull 이 막힌다)",
        )


def swift_files() -> list[Path]:
    return sorted(
        p
        for p in ROOT.rglob("*.swift")
        if ".build" not in p.parts and "DerivedData" not in p.parts
    )


def strip_comments(text: str) -> str:
    """주석 안의 문자열·한글을 검사 대상에서 뺀다.

    문자열 리터럴 안의 `//` 를 주석으로 오인하면 안 되므로 문자를 훑는다.
    """
    out = []
    i, n = 0, len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def specifiers(value: str) -> list[str]:
    """포맷 지시자 목록. 위치 지정자가 있으면 그 순서로 정렬해 비교한다.

    위치 지정자(`%1$@`)를 쓰면 언어마다 문장 순서를 바꿔도 되므로, 등장 순서가 아니라
    **인자 번호 순서**로 세운 목록을 비교한다.
    """
    found = FORMAT_SPEC.findall(value)  # [(index, length, conversion), ...]
    if any(index for index, _, _ in found):
        found = sorted(found, key=lambda item: int(item[0] or 0))
    return [length + conversion for _, length, conversion in found]


def referenced_keys(text: str) -> list[str]:
    """`t(...)` 호출 안에 있는 문자열 리터럴을 전부 키로 본다.

    `t("a")` 만 보면 `t(flag ? "a" : "b")` 를 놓친다. 놓친 키는 "쓰는 곳이 없다"로 잘못
    보고되고, 그걸 무시하는 습관이 들면 검사가 무력해진다. 그래서 여는 괄호부터 훑어 리터럴을
    거두되, **첫 인자까지만** 본다 — `t("clips.emptyForTag", args: tag ?? "")` 의 `""` 는
    키가 아니라 포맷 인자다. 뒤 인자에 있는 중첩 `t(` 호출은 finditer 가 따로 잡는다.

    첫 인자 안에도 키가 아닌 리터럴이 섞일 수 있다 —
    `t(res.error == "network" ? "settings.withdrawNetworkFailed" : "settings.withdrawFailed")`
    의 `"network"` 는 비교 대상이다. 키는 예외 없이 `네임스페이스.이름` 꼴이므로 점이 있는
    리터럴만 키로 본다(`check_catalog` 가 카탈로그 쪽에서 이 규칙을 강제한다).
    """
    keys: list[str] = []
    for match in KEY_CALL_START.finditer(text):
        i = match.end()
        depth, n = 1, len(text)
        argument = []
        while i < n and depth > 0:
            ch = text[i]
            if ch == '"':
                end = i + 1
                while end < n and text[end] != '"':
                    end += 2 if text[end] == "\\" else 1
                argument.append(text[i : end + 1])
                i = end + 1
                continue
            if ch == "," and depth == 1:
                break
            depth += (ch == "(") - (ch == ")")
            i += 1
        keys.extend(
            literal[1:-1] for literal in argument if "." in literal[1:-1]
        )
    return keys


def check_catalog(catalog: dict, errors: list[str]) -> dict[str, dict]:
    if catalog.get("sourceLanguage") != SOURCE_LANGUAGE:
        fail(errors, f"sourceLanguage 가 {SOURCE_LANGUAGE} 가 아니다: {catalog.get('sourceLanguage')}")

    strings = catalog.get("strings", {})
    for key, entry in sorted(strings.items()):
        # 키는 예외 없이 `네임스페이스.이름` 꼴이어야 한다. 코드 쪽 검사(`referenced_keys`)가
        # 점을 기준으로 키와 일반 리터럴을 가르기 때문에, 점 없는 키를 만들면 조용히 누락된다.
        if "." not in key:
            fail(errors, f"[{key}] 키에 네임스페이스가 없다 — `화면.이름` 꼴로 짓는다")

        locs = entry.get("localizations", {})

        missing = [lang for lang in LANGUAGES if lang not in locs]
        if missing:
            fail(errors, f"[{key}] 번역 누락: {', '.join(missing)}")

        extra = [lang for lang in locs if lang not in LANGUAGES]
        if extra:
            fail(errors, f"[{key}] 지원하지 않는 언어: {', '.join(extra)}")

        values = {}
        for lang in LANGUAGES:
            unit = locs.get(lang, {}).get("stringUnit", {})
            value = unit.get("value")
            if not value:
                fail(errors, f"[{key}] {lang} 값이 비었다")
                continue
            values[lang] = value

        source = values.get(SOURCE_LANGUAGE)
        if source is None:
            continue
        expected = specifiers(source)
        for lang, value in values.items():
            if lang == SOURCE_LANGUAGE:
                continue
            actual = specifiers(value)
            if actual != expected:
                fail(
                    errors,
                    f"[{key}] {lang} 포맷 지시자가 한국어와 다르다 "
                    f"({expected} != {actual}) — String(format:) 이 런타임에 죽는다",
                )

        # 같은 문구가 전 언어에 그대로면 번역을 잊은 것이다(고유명사는 예외라 경고만 하지 않고
        # 주석으로 의도를 밝히게 한다).
        if len(set(values.values())) == 1 and not entry.get("comment"):
            fail(
                errors,
                f"[{key}] 4개 언어 값이 모두 같다 — 번역 누락이면 채우고, "
                f"의도라면 comment 로 이유를 남긴다",
            )

    return strings


def check_usage(strings: dict, errors: list[str]) -> None:
    used: dict[str, list[str]] = {}
    for path in swift_files():
        text = strip_comments(path.read_text(encoding="utf-8"))
        for key in referenced_keys(text):
            used.setdefault(key, []).append(str(path.relative_to(ROOT)))

    # 테스트는 일부러 없는 키를 조회한다(폴백 검증). 그건 사용처로 세지 않는다.
    test_only = {
        key
        for key, files in used.items()
        if all(f.startswith("ClipNoteTests/") for f in files)
    }

    for key, files in sorted(used.items()):
        if key in strings:
            continue
        if key in test_only:
            continue
        fail(errors, f"[{key}] 코드가 쓰는데 카탈로그에 없다 ({files[0]})")

    for key in sorted(strings):
        if key not in used:
            fail(errors, f"[{key}] 카탈로그에만 있고 쓰는 곳이 없다")


def strip_previews(text: str) -> str:
    """`#Preview { … }` 블록을 들어낸다.

    Xcode 캔버스 전용이라 사용자에게 도달하지 않는다. 예시 데이터에 한글을 쓰는 게 오히려
    자연스럽고(한국어 제목의 줄바꿈을 봐야 한다), 번역해 봐야 볼 사람이 없다.
    """
    out = []
    i, n = 0, len(text)
    while i < n:
        start = text.find("#Preview", i)
        if start == -1:
            out.append(text[i:])
            break
        out.append(text[i:start])
        brace = text.find("{", start)
        if brace == -1:
            break
        depth, j = 1, brace + 1
        while j < n and depth > 0:
            depth += (text[j] == "{") - (text[j] == "}")
            j += 1
        i = j
    return "".join(out)


def check_text_literals(errors: list[str]) -> None:
    """`Text("리터럴")` 을 막는다.

    SwiftUI `Text` 는 문자열 **리터럴**을 받으면 `LocalizedStringKey` 오버로드로 간다. 보간이
    들어가도 마찬가지다(`Text("· \\(item)")`). 그러면 Xcode 가 빌드할 때마다 그 리터럴을 문자열
    카탈로그에 밀어 넣어, 내용이 그대로여도 파일이 통째로 바뀌고 `git pull` 이 막힌다.

    빌드 설정(`SWIFT_EMIT_LOC_STRINGS: NO`)으로도 끌 수 있지만 그건 프로젝트를 재생성해야
    적용된다 — 한 번 안 돌리면 다시 오염된다. **애초에 추출 대상이 아니게** 두는 게 확실하다.

    - 번역이 필요한 문구 → `Text(i18n.t("키"))` (문자열 변수라 추출 대상이 아니다)
    - 번역이 필요 없는 것(브랜드명·기호·번호) → `Text(verbatim: "…")`
    """
    for path in swift_files():
        text = strip_previews(strip_comments(path.read_text(encoding="utf-8")))
        if TEXT_LITERAL.search(text):
            relative = path.relative_to(ROOT)
            fail(
                errors,
                f'{relative} 에 `Text("리터럴")` 이 있다 — Xcode 가 문자열 카탈로그에 밀어 넣는다. '
                f'번역 문구면 `Text(i18n.t("키"))`, 아니면 `Text(verbatim: "…")` 으로 쓴다',
            )


def check_clean_files(errors: list[str]) -> None:
    for relative in CLEAN_FILES:
        path = ROOT / relative
        if not path.exists():
            fail(errors, f"{relative} 가 없다 — CLEAN_FILES 를 고쳐야 한다")
            continue
        text = strip_previews(strip_comments(path.read_text(encoding="utf-8")))
        for literal in STRING_LITERAL.findall(text):
            if not HANGUL.search(literal):
                continue
            if (relative, literal) in LITERAL_ALLOWLIST:
                continue
            fail(errors, f"{relative} 에 한글 리터럴이 남았다: \"{literal}\"")


def main() -> int:
    raw = CATALOG.read_text(encoding="utf-8")
    catalog = json.loads(raw)

    if "--format" in sys.argv:
        CATALOG.write_text(canonical_json(catalog), encoding="utf-8")
        print(f"✓ 정규 형식으로 다시 씀 — {CATALOG.relative_to(ROOT)}")
        return 0

    errors: list[str] = []
    check_format(raw, catalog, errors)
    strings = check_catalog(catalog, errors)
    check_usage(strings, errors)
    check_clean_files(errors)
    check_text_literals(errors)

    if errors:
        print(f"✗ {len(errors)}건")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"✓ 키 {len(strings)}개 / 언어 {len(LANGUAGES)}개 / 사전화 완료 파일 {len(CLEAN_FILES)}개")
    return 0


if __name__ == "__main__":
    sys.exit(main())
