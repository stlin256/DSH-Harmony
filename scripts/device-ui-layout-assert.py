#!/usr/bin/env python3
"""Inspect HarmonyOS uitest dumps for bottom-dock layout regressions."""

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


def walk(node: dict[str, Any], ancestors: list[dict[str, Any]] | None = None):
    current = (ancestors or []) + [node]
    yield node, current
    for child in node.get("children", []):
        yield from walk(child, current)


def label(node: dict[str, Any]) -> str:
    attributes = node.get("attributes", {})
    values = []
    for value in (
        attributes.get("text", ""),
        attributes.get("accessibilityText", ""),
        attributes.get("originalText", ""),
    ):
        if value and value not in values:
            values.append(value)
    return " | ".join(values) if values else attributes.get("hint", "")


def describe(node: dict[str, Any], depth: int = 0) -> str:
    attributes = node.get("attributes", {})
    text = label(node).replace("\n", " ")
    return (
        f"{'  ' * depth}{attributes.get('type', '?')} "
        f"{attributes.get('bounds', '?')} "
        f"z={attributes.get('zIndex', '?')} "
        f"enabled={attributes.get('enabled', '?')} "
        f"hit={attributes.get('hitTestBehavior', '?')} "
        f"{text[:100]}"
    )


def visible_bounds(
    bounds: tuple[int, int, int, int],
    ancestors: list[dict[str, Any]],
) -> tuple[int, int, int, int] | None:
    left, top, right, bottom = bounds
    for ancestor in ancestors:
        attributes = ancestor.get("attributes", {})
        if attributes.get("clip") != "true":
            continue
        clip_left, clip_top, clip_right, clip_bottom = parse_bounds(
            attributes.get("bounds", "")
        )
        left = max(left, clip_left)
        top = max(top, clip_top)
        right = min(right, clip_right)
        bottom = min(bottom, clip_bottom)
        if right <= left or bottom <= top:
            return None
    return left, top, right, bottom


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout", type=Path)
    parser.add_argument("--match", action="append", default=[])
    parser.add_argument("--type", dest="node_type", default="")
    parser.add_argument("--require-composer-visible", action="store_true")
    parser.add_argument(
        "--forbid-overlap-hex",
        nargs=2,
        metavar=("TOP", "BOTTOM"),
        help="two UTF-8 labels encoded as hexadecimal; their visible bounds must not intersect",
    )
    args = parser.parse_args()

    root = json.loads(args.layout.read_text(encoding="utf-8"))
    if isinstance(root, list):
        root = root[0]
    _, _, _, screen_bottom = parse_bounds(root["attributes"]["bounds"])
    failures: list[str] = []
    found_composer = False

    nodes = list(walk(root))
    for node, ancestors in nodes:
        attributes = node["attributes"]
        text = label(node)
        type_matches = bool(args.node_type) and attributes.get("type") == args.node_type
        if type_matches:
            print("\n" + describe(node))
            left, top, right, bottom = parse_bounds(attributes["bounds"])
            if bottom > screen_bottom:
                failures.append(
                    f"{args.node_type} extends below screen: {bottom} > {screen_bottom}"
                )
        if (
            args.require_composer_visible
            and attributes.get("type") == "TextArea"
            and not found_composer
        ):
            left, top, right, bottom = parse_bounds(attributes["bounds"])
            found_composer = True
            print("\ncomposer TextArea")
            for depth, ancestor in enumerate(ancestors):
                print(describe(ancestor, depth))
            if top >= screen_bottom or bottom > screen_bottom:
                failures.append(
                    f"composer is outside the visible screen: {left},{top},{right},{bottom}"
                )
        if not text:
            continue
        if not args.match and args.node_type:
            continue
        should_match = not args.match or any(token in text for token in args.match)
        if not should_match:
            continue
        left, top, right, bottom = parse_bounds(node["attributes"]["bounds"])
        print(f"\n{text[:120] or '<unlabelled>'}")
        for depth, ancestor in enumerate(ancestors):
            print(describe(ancestor, depth))
        if bottom > screen_bottom:
            failures.append(f"{text!r} extends below screen: {bottom} > {screen_bottom}")
    if args.require_composer_visible and not found_composer:
        failures.append("composer TextArea was not present in the layout dump")
    if args.forbid_overlap_hex:
        requested = [
            bytes.fromhex(value).decode("utf-8")
            for value in args.forbid_overlap_hex
        ]
        matches: list[tuple[int, int, int, int]] = []
        for requested_label in requested:
            candidates = [
                visible
                for node, ancestors in nodes
                if node.get("attributes", {}).get("visible") == "true"
                and requested_label in label(node)
                for visible in [
                    visible_bounds(
                        parse_bounds(node["attributes"]["bounds"]),
                        ancestors,
                    )
                ]
                if visible is not None
            ]
            if not candidates:
                failures.append(f"overlap label not found: {requested_label}")
                matches = []
                break
            # Accessibility containers carry the complete row bounds; prefer
            # them over a shorter text-node match nested inside.
            matches.append(max(candidates, key=lambda bounds: bounds[3] - bounds[1]))
        if len(matches) == 2:
            top = matches[0]
            bottom = matches[1]
            intersects = not (
                top[2] <= bottom[0]
                or bottom[2] <= top[0]
                or top[3] <= bottom[1]
                or bottom[3] <= top[1]
            )
            if intersects:
                failures.append(
                    f"forbidden overlap: {requested[0]!r} {top} intersects "
                    f"{requested[1]!r} {bottom}"
                )

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("\nPASS: requested layout bounds are visible")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
