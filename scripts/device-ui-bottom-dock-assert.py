#!/usr/bin/env python3
"""Assert that extra bottom-Dock content owns a matching transcript spacer."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


def parse_bounds(value: str) -> tuple[int, int, int, int]:
    match = re.fullmatch(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]", value or "")
    if not match:
        raise ValueError(f"invalid bounds: {value!r}")
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def walk(node: dict[str, Any]):
    yield node
    for child in node.get("children", []):
        yield from walk(child)


def load(path: Path) -> dict[str, Any]:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    return parsed[0] if isinstance(parsed, list) else parsed


def transcript_list(root: dict[str, Any]) -> dict[str, Any]:
    candidates = [
        node
        for node in walk(root)
        if node.get("attributes", {}).get("type") == "List"
        and parse_bounds(node.get("attributes", {}).get("bounds", ""))[0] >= 0
    ]
    if not candidates:
        raise ValueError("visible transcript List was not found")
    return max(
        candidates,
        key=lambda node: (
            (lambda bounds: (bounds[2] - bounds[0]) * (bounds[3] - bounds[1]))(
                parse_bounds(node["attributes"]["bounds"])
            )
        ),
    )


def text_content(node: dict[str, Any]) -> str:
    values = []
    for child in walk(node):
        attributes = child.get("attributes", {})
        for key in ("text", "originalText", "accessibilityText"):
            value = attributes.get(key, "")
            if value and value not in values:
                values.append(value)
    return " ".join(values)


def tail_geometry(path: Path) -> dict[str, Any]:
    root = load(path)
    container = transcript_list(root)
    list_bounds = parse_bounds(container["attributes"]["bounds"])
    items = [
        child
        for child in container.get("children", [])
        if child.get("attributes", {}).get("type") == "ListItem"
    ]
    if not items:
        raise ValueError(f"transcript List has no ListItem: {path}")
    last = items[-1]
    last_bounds = parse_bounds(last["attributes"]["bounds"])
    last_text = text_content(last)
    previous_text_bounds = last_bounds if last_text else None
    if previous_text_bounds is None:
        for item in reversed(items[:-1]):
            if text_content(item):
                previous_text_bounds = parse_bounds(item["attributes"]["bounds"])
                break
    return {
        "path": str(path),
        "listBounds": list_bounds,
        "listHeight": list_bounds[3] - list_bounds[1],
        "tailBounds": last_bounds,
        "tailHeight": last_bounds[3] - last_bounds[1],
        "tailHasText": bool(last_text),
        "previousTextBounds": previous_text_bounds,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", type=Path, required=True)
    parser.add_argument("--elevated", type=Path, required=True)
    parser.add_argument("--queue", type=Path, required=True)
    parser.add_argument("--error", type=Path, required=True)
    args = parser.parse_args()

    try:
        quiet = tail_geometry(args.quiet)
        elevated = tail_geometry(args.elevated)
        queue = tail_geometry(args.queue)
        error = tail_geometry(args.error)

        if not quiet["tailHasText"]:
            raise ValueError("quiet state unexpectedly has an extra tail spacer")

        for name, geometry in (
            ("elevated", elevated),
            ("queue", queue),
            ("error", error),
        ):
            if geometry["tailHasText"]:
                raise ValueError(f"{name} state has no textless tail spacer")
            if geometry["tailHeight"] < 80:
                raise ValueError(f"{name} tail spacer is too small: {geometry}")
            previous = geometry["previousTextBounds"]
            if previous is None or geometry["tailBounds"][1] <= previous[3]:
                raise ValueError(f"{name} tail spacer does not follow text content: {geometry}")
            shrink = quiet["listBounds"][3] - geometry["listBounds"][3]
            if shrink + 48 < geometry["tailHeight"]:
                raise ValueError(
                    f"{name} transcript viewport did not shrink with extra Dock content: "
                    f"shrink={shrink}, spacer={geometry['tailHeight']}"
                )

        print(json.dumps({
            "quiet": quiet,
            "elevated": elevated,
            "queue": queue,
            "error": error,
        }))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
