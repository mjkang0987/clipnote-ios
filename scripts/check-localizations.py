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

사용: python3 scripts/check-localizations.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "ClipNote/Localization/Localizable.xcstrings"

# `AppLanguage` 와 `project.yml` 의 CFBundleLocalizations 도 같은 목록이어야 한다.
# 그 둘의 일치는 Xcode 가 필요해 `LocalizationStoreTests` 가 본다.
LANGUAGES = ["ko", "en", "ja", "zh-Hans"]
SOURCE_LANGUAGE = "ko"

# 사전화를 끝낸 파일. 여기 올라온 파일에 한글 리터럴이 새로 생기면 실패한다.
# 화면을 하나 끝낼 때마다 여기에 추가한다 — 이 목록이 진행 상황이자 되돌림 방지 장치다.
CLEAN_FILES = [
    "ClipNote/Views/SettingsView.swift",
]

# 한글이 들어 있어도 번역 대상이 아닌 것.
LITERAL_ALLOWLIST = {
    # 각 언어를 그 언어로 표기하는 게 의도다.
    ("ClipNote/Localization/AppLanguage.swift", "한국어"),
}

KEY_CALL = re.compile(r'\bt\(\s*"([^"\\]+)"')
STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
HANGUL = re.compile(r"[가-힣]")
# `%@`·`%d`·`%1$@` — 위치 지정자를 포함해 잡는다.
FORMAT_SPEC = re.compile(r"%(?:(\d+)\$)?([@a-zA-Z])")


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


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
    """포맷 지시자 목록. 위치 지정자가 있으면 그 순서로 정렬해 비교한다."""
    found = FORMAT_SPEC.findall(value)
    if any(index for index, _ in found):
        return [kind for _, kind in sorted(found, key=lambda p: int(p[0] or 0))]
    return [kind for _, kind in found]


def check_catalog(catalog: dict, errors: list[str]) -> dict[str, dict]:
    if catalog.get("sourceLanguage") != SOURCE_LANGUAGE:
        fail(errors, f"sourceLanguage 가 {SOURCE_LANGUAGE} 가 아니다: {catalog.get('sourceLanguage')}")

    strings = catalog.get("strings", {})
    for key, entry in sorted(strings.items()):
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
        for key in KEY_CALL.findall(text):
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


def check_clean_files(errors: list[str]) -> None:
    for relative in CLEAN_FILES:
        path = ROOT / relative
        if not path.exists():
            fail(errors, f"{relative} 가 없다 — CLEAN_FILES 를 고쳐야 한다")
            continue
        text = strip_comments(path.read_text(encoding="utf-8"))
        for literal in STRING_LITERAL.findall(text):
            if not HANGUL.search(literal):
                continue
            if (relative, literal) in LITERAL_ALLOWLIST:
                continue
            fail(errors, f"{relative} 에 한글 리터럴이 남았다: \"{literal}\"")


def main() -> int:
    errors: list[str] = []
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = check_catalog(catalog, errors)
    check_usage(strings, errors)
    check_clean_files(errors)

    if errors:
        print(f"✗ {len(errors)}건")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"✓ 키 {len(strings)}개 / 언어 {len(LANGUAGES)}개 / 사전화 완료 파일 {len(CLEAN_FILES)}개")
    return 0


if __name__ == "__main__":
    sys.exit(main())
