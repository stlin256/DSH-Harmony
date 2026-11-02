#!/usr/bin/env python3
"""Compose deterministic contact sheets for ordered device evidence captures."""

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


def fit(image: Image.Image, target_height: int) -> Image.Image:
    width = round(image.width * target_height / image.height)
    return image.resize((width, target_height), Image.Resampling.LANCZOS)


def chunks(items: list[Path], size: int) -> list[list[Path]]:
    return [items[index:index + size] for index in range(0, len(items), size)]


def fitted_label(
    draw: ImageDraw.ImageDraw,
    text: str,
    label_font: ImageFont.FreeTypeFont,
    max_width: int,
) -> str:
    if draw.textlength(text, font=label_font) <= max_width:
        return text
    suffix = "..."
    for end in range(len(text) - 1, -1, -1):
        candidate = text[:end].rstrip() + suffix
        if draw.textlength(candidate, font=label_font) <= max_width:
            return candidate
    return suffix


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--glob", default="*-expanded.jpeg")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--prefix", default="expanded")
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--rows", type=int, default=2)
    parser.add_argument("--height", type=int, default=760)
    args = parser.parse_args()

    items = sorted(args.input.glob(args.glob))
    if not items:
        raise FileNotFoundError(f"no captures matched {args.glob!r} in {args.input}")

    padded = 48
    gap = 22
    label_height = 58
    target_height = args.height
    heading_font = font(22, True)
    label_font = font(16, True)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    for sheet_index, sheet_items in enumerate(
        chunks(items, args.columns * args.rows),
        start=1,
    ):
        scaled: list[Image.Image] = []
        for item in sheet_items:
            with Image.open(item) as image:
                scaled.append(fit(image.convert("RGB"), target_height))

        cell_width = max(image.width for image in scaled)
        row_count = (len(sheet_items) + args.columns - 1) // args.columns
        width = padded * 2 + cell_width * args.columns + gap * (args.columns - 1)
        height = (
            padded * 2
            + (target_height + label_height) * row_count
            + gap * (row_count - 1)
        )
        board = Image.new("RGB", (width, height), "#F4F6F9")
        draw = ImageDraw.Draw(board)
        caption = f"{args.prefix} · real device captures · sheet {sheet_index}"
        draw.text((padded, 10), caption, font=heading_font, fill="#20242B")

        for index, (item, image) in enumerate(zip(sheet_items, scaled)):
            column = index % args.columns
            row = index // args.columns
            x = padded + column * (cell_width + gap)
            y = padded + row * (target_height + label_height + gap)
            draw.rounded_rectangle(
                (
                    x - 8,
                    y - 8,
                    x + cell_width + 8,
                    y + target_height + label_height,
                ),
                radius=18,
                fill="#FFFFFF",
            )
            image_x = x + (cell_width - image.width) // 2
            board.paste(image, (image_x, y))
            label = (
                item.parent.name
                if item.stem == "screen" and item.parent != args.input
                else item.stem.removesuffix("-expanded")
            )
            draw.text(
                (x + 6, y + target_height + 13),
                fitted_label(draw, label, label_font, cell_width - 12),
                font=label_font,
                fill="#20242B",
            )

        output = args.out_dir / f"{args.prefix}-{sheet_index:02d}.jpeg"
        board.save(output, "JPEG", quality=92, optimize=True)
        print(output)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
