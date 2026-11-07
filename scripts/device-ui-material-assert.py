#!/usr/bin/env python3
"""Assert that the elevated bottom Dock has a controlled material falloff."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from PIL import Image


def parse_bounds(value: str) -> tuple[int, int, int, int]:
    match = re.fullmatch(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]", value or "")
    if not match:
        raise ValueError(f"invalid bounds: {value!r}")
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def walk(node: dict[str, Any], ancestors: list[dict[str, Any]] | None = None):
    current = (ancestors or []) + [node]
    yield node, current
    for child in node.get("children", []):
        yield from walk(child, current)


def find_dock(root: dict[str, Any]) -> tuple[int, int, int, int]:
    root_bounds = parse_bounds(root["attributes"]["bounds"])
    root_left, root_top, root_right, root_bottom = root_bounds
    for node, ancestors in walk(root):
        if node.get("attributes", {}).get("type") != "TextArea":
            continue
        for ancestor in reversed(ancestors[:-1]):
            attributes = ancestor.get("attributes", {})
            if attributes.get("type") != "Stack":
                continue
            bounds = parse_bounds(attributes.get("bounds", ""))
            left, top, right, bottom = bounds
            if (
                left > root_left
                and right < root_right
                and top > root_top + (root_bottom - root_top) * 0.55
                and bottom == root_bottom
                and right - left >= (root_right - root_left) * 0.65
            ):
                return bounds
    raise ValueError("could not locate the elevated Dock bounds around the composer")


def average_luminance(
    image: Image.Image,
    x0: int,
    x1: int,
    y: int,
) -> float:
    top = max(0, y - 1)
    bottom = min(image.height, y + 2)
    total = 0.0
    count = 0
    for py in range(top, bottom):
        for px in range(max(0, x0), min(image.width, x1)):
            red, green, blue = image.getpixel((px, py))[:3]
            total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            count += 1
    return total / max(1, count)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout", type=Path)
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("--theme", required=True, choices=("light", "dark"))
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()

    parsed = json.loads(args.layout.read_text(encoding="utf-8"))
    root = parsed[0] if isinstance(parsed, list) else parsed
    dock_bounds = find_dock(root)
    left, top, right, bottom = dock_bounds

    with Image.open(args.screenshot) as source:
        image = source.convert("RGB")
    root_bounds = parse_bounds(root["attributes"]["bounds"])
    scale_x = image.width / max(1, root_bounds[2] - root_bounds[0])
    scale_y = image.height / max(1, root_bounds[3] - root_bounds[1])

    scaled_left = round(left * scale_x)
    scaled_right = round(right * scale_x)
    scaled_top = round(top * scale_y)
    scaled_bottom = round(bottom * scale_y)
    sample_width = max(8, round((scaled_right - scaled_left) * 0.025))
    x0 = scaled_left + 4
    x1 = min(scaled_right, x0 + sample_width)
    if x1 - x0 < 4:
        print("FAIL: Dock left margin is too narrow for material sampling", file=sys.stderr)
        return 1

    page_y = max(0, scaled_top - max(8, round(12 * scale_y)))
    page = average_luminance(image, x0, x1, page_y)
    # Keep away from the composer card and home indicator by sampling the
    # unobstructed Dock margin only.
    fractions = [0.03, 0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82, 0.92]
    samples = [
        round(
            average_luminance(
                image,
                x0,
                x1,
                round(scaled_top + fraction * (scaled_bottom - scaled_top)),
            ),
            2,
        )
        for fraction in fractions
    ]
    entry_delta = abs(samples[0] - page)
    steps = [abs(b - a) for a, b in zip(samples, samples[1:])]
    max_step = max(steps, default=0.0)
    span = max(samples) - min(samples)

    hard_edge_limit = 24.0 if args.theme == "light" else 18.0
    max_step_limit = 24.0 if args.theme == "light" else 18.0
    failures: list[str] = []
    if entry_delta > hard_edge_limit:
        failures.append(
            f"hard Dock top edge: {entry_delta:.2f} luminance jump "
            f"(limit {hard_edge_limit:.2f})"
        )
    if max_step > max_step_limit:
        failures.append(
            f"abrupt material step: {max_step:.2f} luminance jump "
            f"(limit {max_step_limit:.2f})"
        )
    # The vertical samples cross the Dock's content (edit hint, queue rows,
    # composer), which is legitimately uniform. A flat span only indicates a
    # missing material when the Dock also fails to separate from the page, so
    # the entry edge delta is the authoritative dark-theme signal.
    if args.theme == "dark" and span < 3.0 and entry_delta < 4.0:
        failures.append(
            f"dark Dock falloff is effectively flat: {span:.2f} luminance range "
            f"with only {entry_delta:.2f} entry separation"
        )

    report = {
        "dockBounds": list(dock_bounds),
        "sampleX": [x0, x1],
        "pageLuminance": round(page, 2),
        "sampleFractions": fractions,
        "sampleLuminance": samples,
        "entryDelta": round(entry_delta, 2),
        "maxStep": round(max_step, 2),
        "span": round(span, 2),
        "theme": args.theme,
        "passed": not failures,
        "failures": failures,
    }
    output = json.dumps(report, ensure_ascii=False, indent=2)
    print(output)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: Dock material has a continuous, visible falloff")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
