#!/usr/bin/env python3
"""달리는 공룡 스프라이트 시트를 프레임 4장으로 자른다.

시트 한 장(`art/dino-sheet.png`)을 받아 `ClipNote/Assets.xcassets/DinoRun{1..4}.imageset`
을 만든다. 다시 돌려도 같은 결과가 나오고, 원본은 건드리지 않는다.

## 왜 4등분하지 않는가

프레임 간격이 눈으로 보기에만 고르다. 폭을 그냥 4로 나누면 꼬리나 앞발이 옆 칸으로
넘어가 잘린다. 알파 채널로 **글자 그대로 어디에 그림이 있는지** 찾아서 자른다.

## 워터마크

생성 도구가 남긴 흐릿한 마크는 반투명이다. 공룡은 불투명이라, 알파 문턱값(200)으로
훑으면 마크는 애초에 "그림 있음" 으로 잡히지 않는다 — 자를 영역 밖으로 밀려난다.
문턱값을 낮추면 마크까지 영역에 들어오니 낮추지 말 것.

## 프레임 정렬

걷기 동작은 **몸이 제자리에 있고 다리만 움직이는** 그림이다. 프레임마다 여백을 따로
떼면 그 상대 위치가 무너져 걸을 때 위아래·좌우로 덜컹거린다. 그래서 네 칸을 **같은
크기의 상자**로 잘라내고, 상자 안에서의 위치는 원본 그대로 둔다.

사용:
    python3 scripts/slice-dino.py            # 자르고 이미지셋까지 생성
    python3 scripts/slice-dino.py --report   # 무엇을 찾았는지만 출력(파일 안 씀)
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow 가 필요하다: pip install Pillow")

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "art" / "dino-sheet.png"
ASSETS = ROOT / "ClipNote" / "Assets.xcassets"
NAME = "DinoRun"
FRAMES = 4

# 이 값 이상만 "그림" 으로 본다. 워터마크를 걸러내는 문턱이다 — 위 주석 참고.
OPAQUE = 200


def occupied_columns(image: Image.Image) -> list[bool]:
    """열마다 불투명 픽셀이 있는지."""
    alpha = image.getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    result = []
    for x in range(width):
        found = False
        for y in range(height):
            if pixels[x, y] >= OPAQUE:
                found = True
                break
        result.append(found)
    return result


def runs(flags: list[bool]) -> list[tuple[int, int]]:
    """True 가 이어지는 구간을 [시작, 끝) 으로."""
    spans, start = [], None
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            spans.append((start, index))
            start = None
    if start is not None:
        spans.append((start, len(flags)))
    return spans


def row_bounds(image: Image.Image, left: int, right: int) -> tuple[int, int]:
    """[left, right) 구간에서 불투명 픽셀이 있는 첫/마지막 행."""
    alpha = image.getchannel("A")
    pixels = alpha.load()
    top, bottom = None, None
    for y in range(image.size[1]):
        if any(pixels[x, y] >= OPAQUE for x in range(left, right)):
            if top is None:
                top = y
            bottom = y
    if top is None:
        raise SystemExit("빈 구간이 잡혔다 — 시트를 확인할 것")
    return top, bottom + 1


def contents_json(filename: str) -> str:
    """단일 배율(Single Scale) 이미지셋.

    픽셀 아트라 배율 슬롯을 나누지 않는다. 원본 픽셀 그대로 들고 있다가 그릴 때
    `.interpolation(.none)` 으로 확대해야 도트가 뭉개지지 않는다.
    """
    doc = {
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    return json.dumps(doc, indent=2) + "\n"


def main() -> int:
    report_only = "--report" in sys.argv

    if not SHEET.exists():
        sys.exit(f"{SHEET.relative_to(ROOT)} 가 없다 — 스프라이트 원본을 먼저 커밋할 것")

    sheet = Image.open(SHEET).convert("RGBA")
    print(f"시트 {sheet.size[0]}×{sheet.size[1]}")

    spans = runs(occupied_columns(sheet))
    if len(spans) != FRAMES:
        sys.exit(
            f"가로로 {len(spans)}덩어리가 잡혔다(기대: {FRAMES}) — "
            f"프레임이 붙어 있거나 시트에 다른 그림이 섞여 있다: {spans}"
        )

    boxes = []
    for left, right in spans:
        top, bottom = row_bounds(sheet, left, right)
        boxes.append((left, top, right, bottom))
        print(f"  프레임 {len(boxes)}: x {left}–{right} ({right - left}px), "
              f"y {top}–{bottom} ({bottom - top}px)")

    # 모든 프레임을 담는 같은 크기의 상자. 여백을 따로 떼지 않는 이유는 위 주석 참고.
    cell_w = max(r - l for l, _, r, _ in boxes)
    top = min(t for _, t, _, _ in boxes)
    bottom = max(b for _, _, _, b in boxes)
    cell_h = bottom - top
    print(f"공통 상자 {cell_w}×{cell_h} (윗변 y={top}, 아랫변 y={bottom})")

    if report_only:
        print("--report 라 파일은 쓰지 않았다")
        return 0

    for index, (left, _, right, _) in enumerate(boxes, start=1):
        # 상자 안에서 가로는 가운데, 세로는 공통 윗변·아랫변에 맞춘다.
        # 세로를 공통으로 잡아야 발바닥 높이가 프레임마다 흔들리지 않는다.
        pad = (cell_w - (right - left)) // 2
        crop = sheet.crop((left - pad, top, left - pad + cell_w, bottom))

        directory = ASSETS / f"{NAME}{index}.imageset"
        directory.mkdir(parents=True, exist_ok=True)
        filename = f"{NAME.lower()}{index}.png"
        crop.save(directory / filename)
        (directory / "Contents.json").write_text(contents_json(filename), encoding="utf-8")
        print(f"✓ {directory.relative_to(ROOT)}/{filename}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
