#!/usr/bin/env python3
"""달리는 공룡 스프라이트 시트를 프레임 4장 이미지셋으로 만든다.

`art/dino.png`(작업용 원본)을 받아 `ClipNote/Assets.xcassets/DinoRun{1..4}.imageset`
을 만든다. 원본은 건드리지 않고, 다시 돌려도 같은 결과가 나온다.

받은 원본이 그대로 쓸 수 없는 상태라 네 단계를 거친다.

## 1. 체커보드 걷어내기

"투명 배경" 으로 받았지만 알파가 전부 255였다 — 투명을 나타내는 회색 격자무늬가
**그림으로 구워져** 들어갔다(그래서 5MB). 회색 두 톤(약 247/208)에 압축 잡티까지 섞여 있다.

색만 보고 지우면 눈동자 흰자처럼 밝은 부분까지 뚫린다. 그래서 가장자리에서 시작해
번져 나가며(flood fill) **바깥과 이어진 회색만** 지운다. 테두리에 둘러싸인 밝은 색은
바깥과 이어지지 않으니 살아남는다.

## 2. 원래 해상도로 되돌리기

2816×1536 은 47×45 짜리 도트 그림을 약 11.8배로 키운 것이다(실루엣 경계가 그 주기에
가장 잘 붙는다 — 우연 대비 3.5배). 그대로 두면 5MB 를 앱에 싣고, 작게 그릴 때 도트가
뭉개진다.

칸의 **평균**을 내면 외곽선이 사라진다. 격자 위상이 미세하게 어긋나 두 칸이 섞이기
때문이다. 대신 칸 안에서 **가장 많이 나온 색**을 고른다 — 위상이 조금 틀려도 경계가 산다.

## 3. 잔상 지우기

체커보드와 검은 외곽선 사이의 압축 잡티가 흰 테두리로 남는다. 어두운 배경에서 드러난다.
투명과 맞닿은 밝은 회색 점만 골라 지운다(안쪽 밝은 색은 건드리지 않는다).

## 4. 프레임 나누기

프레임 간격이 눈으로만 고르다. 폭을 4로 나누면 꼬리·앞발이 옆 칸으로 넘어간다.
알파로 실제 그림이 있는 자리를 찾아 자른다.

세로는 네 프레임의 **공통 윗변·아랫변**을 쓴다. 프레임마다 여백을 따로 떼면 걸을 때
발바닥 높이가 흔들린다.

사용:
    python3 scripts/slice-dino.py            # 자산 생성
    python3 scripts/slice-dino.py --report   # 무엇을 찾았는지만 출력(파일 안 씀)
"""

from __future__ import annotations

import json
import sys
from collections import Counter, deque
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow 가 필요하다: pip install Pillow")

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "art" / "dino.png"
ASSETS = ROOT / "ClipNote" / "Assets.xcassets"
NAME = "DinoRun"
FRAMES = 4

# 배경(체커보드) 판정: 채도가 거의 없고 밝다.
BG_SATURATION = 14
BG_MIN_BRIGHTNESS = 185
# 잔상 판정: 배경보다 느슨하게 본다. 투명과 맞닿은 것만 지우므로 느슨해도 안전하다.
HALO_SATURATION = 45
HALO_MIN_BRIGHTNESS = 150
# 도트 한 칸의 크기(px). 실루엣 경계의 주기로 측정한 값.
CELL = 11.785


def strip_background(image: Image.Image) -> Image.Image:
    """가장자리와 이어진 회색을 투명으로. 방법과 이유는 위 1번 참고."""
    width, height = image.size
    pixels = list(image.getdata())

    def is_gray(index: int) -> bool:
        r, g, b = pixels[index][:3]
        return max(r, g, b) - min(r, g, b) <= BG_SATURATION and min(r, g, b) >= BG_MIN_BRIGHTNESS

    candidate = bytearray(1 if is_gray(i) else 0 for i in range(width * height))
    background = bytearray(width * height)
    queue: deque[int] = deque()

    def seed(index: int) -> None:
        if candidate[index] and not background[index]:
            background[index] = 1
            queue.append(index)

    for x in range(width):
        seed(x)
        seed((height - 1) * width + x)
    for y in range(height):
        seed(y * width)
        seed(y * width + width - 1)

    while queue:
        index = queue.popleft()
        x, y = index % width, index // width
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                seed(ny * width + nx)

    result = Image.new("RGBA", (width, height))
    result.putdata([
        (p[0], p[1], p[2], 0 if background[i] else 255)
        for i, p in enumerate(pixels)
    ])
    return result


def shrink_to_dots(image: Image.Image) -> Image.Image:
    """도트 한 칸을 픽셀 하나로. 평균이 아니라 최빈색을 쓰는 이유는 위 2번 참고."""
    width, height = image.size
    source = image.load()
    out_w, out_h = round(width / CELL), round(height / CELL)
    cell_w, cell_h = width / out_w, height / out_h

    result = Image.new("RGBA", (out_w, out_h))
    target = result.load()
    for j in range(out_h):
        y0, y1 = int(j * cell_h), max(int(j * cell_h) + 1, int((j + 1) * cell_h))
        for i in range(out_w):
            x0, x1 = int(i * cell_w), max(int(i * cell_w) + 1, int((i + 1) * cell_w))
            # 칸 가장자리는 이웃 칸과 섞여 있다. 안쪽만 본다.
            mx, my = max(1, (x1 - x0) // 4), max(1, (y1 - y0) // 4)
            samples = [source[x, y]
                       for y in range(y0 + my, max(y0 + my + 1, y1 - my))
                       for x in range(x0 + mx, max(x0 + mx + 1, x1 - mx))]
            opaque = [s for s in samples if s[3]]
            if len(opaque) * 2 < len(samples):
                target[i, j] = (0, 0, 0, 0)
                continue
            # 5비트로 뭉쳐 세고, 이긴 무리의 평균색을 쓴다(압축 잡티로 완전히 같은 색이 드물다).
            key, _ = Counter((r >> 3, g >> 3, b >> 3) for r, g, b, _ in opaque).most_common(1)[0]
            group = [s for s in opaque if (s[0] >> 3, s[1] >> 3, s[2] >> 3) == key]
            count = len(group)
            target[i, j] = (sum(s[0] for s in group) // count,
                            sum(s[1] for s in group) // count,
                            sum(s[2] for s in group) // count, 255)
    return result


def strip_halo(image: Image.Image) -> int:
    """투명과 맞닿은 밝은 회색 점을 지운다. 이유는 위 3번 참고."""
    width, height = image.size
    pixels = image.load()

    def pale(x: int, y: int) -> bool:
        r, g, b, a = pixels[x, y]
        return bool(a) and min(r, g, b) >= HALO_MIN_BRIGHTNESS \
            and max(r, g, b) - min(r, g, b) <= HALO_SATURATION

    removed = 0
    for _ in range(3):
        hits = []
        for y in range(height):
            for x in range(width):
                if not pale(x, y):
                    continue
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < width and 0 <= ny < height) or pixels[nx, ny][3] == 0:
                        hits.append((x, y))
                        break
        if not hits:
            break
        for x, y in hits:
            pixels[x, y] = (0, 0, 0, 0)
        removed += len(hits)
    return removed


def column_spans(image: Image.Image) -> list[tuple[int, int]]:
    """불투명 픽셀이 이어지는 가로 구간."""
    width, height = image.size
    alpha = image.getchannel("A").load()
    spans, start = [], None
    for x in range(width):
        filled = any(alpha[x, y] for y in range(height))
        if filled and start is None:
            start = x
        elif not filled and start is not None:
            spans.append((start, x))
            start = None
    if start is not None:
        spans.append((start, width))
    return spans


def row_bounds(image: Image.Image) -> tuple[int, int]:
    width, height = image.size
    alpha = image.getchannel("A").load()
    rows = [y for y in range(height) if any(alpha[x, y] for x in range(width))]
    return rows[0], rows[-1] + 1


def contents_json(filename: str) -> str:
    """단일 배율(Single Scale) 이미지셋.

    픽셀 아트라 배율 슬롯을 나누지 않는다. 원본 도트를 그대로 들고 있다가 그릴 때
    `.interpolation(.none)` 으로 확대해야 도트가 뭉개지지 않는다.

    **형식을 Xcode 와 똑같이 맞춘다.** Xcode 는 자산 카탈로그를 열 때마다 자기 형식으로
    다시 쓴다 — 구분자가 `" : "`, 들여쓰기 2칸, 키 정렬. 표준 JSON 으로 써 두면 빌드할
    때마다 파일이 바뀌어 `git pull` 이 막힌다. 문자열 카탈로그에서 이미 겪은 일이다.
    """
    doc = {
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    return json.dumps(doc, indent=2, sort_keys=True, separators=(",", " : ")) + "\n"


def main() -> int:
    report_only = "--report" in sys.argv

    if not SHEET.exists():
        sys.exit(f"{SHEET.relative_to(ROOT)} 가 없다 — 스프라이트 원본을 먼저 커밋할 것")

    sheet = Image.open(SHEET).convert("RGB")
    print(f"원본 {sheet.size[0]}×{sheet.size[1]}")

    cut = strip_background(sheet.convert("RGB"))
    kept = sum(1 for p in cut.getdata() if p[3])
    print(f"배경 제거 후 남은 그림 {kept:,}픽셀")

    dots = shrink_to_dots(cut)
    print(f"도트 해상도로 축소 {dots.size[0]}×{dots.size[1]} (칸 {CELL}px)")
    print(f"잔상 {strip_halo(dots)}픽셀 제거")

    spans = column_spans(dots)
    if len(spans) != FRAMES:
        sys.exit(f"가로로 {len(spans)}덩어리가 잡혔다(기대: {FRAMES}): {spans}")

    top, bottom = row_bounds(dots)
    cell_w = max(right - left for left, right in spans)
    print(f"프레임 {cell_w}×{bottom - top}, 구간 {spans}")

    if report_only:
        print("--report 라 파일은 쓰지 않았다")
        return 0

    for index, (left, right) in enumerate(spans, start=1):
        pad = (cell_w - (right - left)) // 2
        crop = dots.crop((left - pad, top, left - pad + cell_w, bottom))
        directory = ASSETS / f"{NAME}{index}.imageset"
        directory.mkdir(parents=True, exist_ok=True)
        filename = f"{NAME.lower()}{index}.png"
        crop.save(directory / filename)
        (directory / "Contents.json").write_text(contents_json(filename), encoding="utf-8")
        size = (directory / filename).stat().st_size
        print(f"✓ {directory.relative_to(ROOT)}/{filename} ({size:,}바이트)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
