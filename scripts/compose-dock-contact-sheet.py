#!/usr/bin/env python3
"""Build a deterministic quiet/elevated Dock visual-review board."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = ("msyhbd.ttc", "msyh.ttc") if bold else ("msyh.ttc", "msyhbd.ttc")
    for name in names:
        path = Path(r"C:\Windows\Fonts") / name
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def load_capture(root: Path, state: str, theme: str, variant: str = "") -> Image.Image:
    directory = f"{state}-{theme}-conversation"
    if variant:
        directory += f"-{variant}"
    path = root / directory / "screen.jpeg"
    if not path.exists():
        raise FileNotFoundError(path)
    with Image.open(path) as image:
        return image.convert("RGB")


def fit(image: Image.Image, target_height: int) -> Image.Image:
    width = round(image.width * target_height / image.height)
    return image.resize((width, target_height), Image.Resampling.LANCZOS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    rows = ("Light", "Dark")
    cells: list[tuple[str, str, Image.Image]] = []
    for theme in rows:
        quiet = load_capture(args.root, "dock-material-quiet", theme.lower())
        elevated = load_capture(args.root, "dock-material-elevated", theme.lower())
        reduced = load_capture(
            args.root,
            "dock-material-elevated",
            theme.lower(),
            "reduced-transparency",
        )
        cells.extend(
            (
                (theme, "Quiet composer", quiet),
                (theme, "Elevated Dock material", elevated),
                (theme, "Reduced transparency", reduced),
            )
        )

    target_height = 760
    padded = 28
    label_height = 58
    scaled = [fit(image, target_height) for _, _, image in cells]
    cell_width = max(image.width for image in scaled)
    gap = 22
    width = padded * 2 + cell_width * 3 + gap * 2
    height = padded * 2 + (target_height + label_height) * 2 + gap
    board = Image.new("RGB", (width, height), "#F4F6F9")
    draw = ImageDraw.Draw(board)
    heading_font = font(22, True)
    label_font = font(16, True)

    for index, (theme, label, _) in enumerate(cells):
        column = index % 3
        row = index // 3
        x = padded + column * (cell_width + gap)
        y = padded + row * (target_height + label_height + gap)
        draw.rounded_rectangle(
            (x - 8, y - 8, x + cell_width + 8, y + target_height + label_height),
            radius=18,
            fill="#FFFFFF" if row == 0 else "#171A20",
        )
        image = scaled[index]
        image_x = x + (cell_width - image.width) // 2
        board.paste(image, (image_x, y))
        draw.text(
            (x + 6, y + target_height + 13),
            f"{theme} · {label}",
            font=label_font,
            fill="#20242B" if row == 0 else "#F6F7F9",
        )

    caption = "Quiet · elevated material · reduced transparency · real device captures"
    draw.text((padded, 3), caption, font=heading_font, fill="#20242B")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    board.save(args.out, "PNG", optimize=True)
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
