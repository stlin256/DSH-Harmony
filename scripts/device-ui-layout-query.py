#!/usr/bin/env python3
"""Query visible HarmonyOS uitest layout nodes for repeatable device E2E."""

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
    return " ".join(values) if values else attributes.get("hint", "")


def inside(root_bounds: tuple[int, int, int, int], value: str) -> bool:
    left, top, right, bottom = parse_bounds(value)
    root_left, root_top, root_right, root_bottom = root_bounds
    visible_left = max(left, root_left)
    visible_top = max(top, root_top)
    visible_right = min(right, root_right)
    visible_bottom = min(bottom, root_bottom)
    return visible_right > visible_left and visible_bottom > visible_top


def effectively_visible(
    attributes: dict[str, Any],
    root_bounds: tuple[int, int, int, int],
) -> bool:
    if attributes.get("visible") != "true":
        return False
    try:
        opacity = float(attributes.get("opacity", "1"))
    except (TypeError, ValueError):
        opacity = 1.0
    return opacity > 0.01 and inside(root_bounds, attributes.get("bounds", ""))


def center(value: str) -> tuple[int, int]:
    left, top, right, bottom = parse_bounds(value)
    return ((left + right) // 2, (top + bottom) // 2)


def visible_center(root_bounds: tuple[int, int, int, int], value: str) -> tuple[int, int]:
    left, top, right, bottom = parse_bounds(value)
    root_left, root_top, root_right, root_bottom = root_bounds
    return (
        (max(left, root_left) + min(right, root_right)) // 2,
        (max(top, root_top) + min(bottom, root_bottom)) // 2,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout", type=Path)
    text_group = parser.add_mutually_exclusive_group(required=True)
    text_group.add_argument("--find-text")
    text_group.add_argument(
        "--find-text-hex",
        help="UTF-8 text encoded as hexadecimal; avoids shell code-page failures",
    )
    text_group.add_argument(
        "--rightmost-clickable-below",
        nargs=2,
        type=int,
        metavar=("X", "Y"),
        help="select the first enabled clickable row below an anchor, preferring the rightmost node",
    )
    text_group.add_argument(
        "--rightmost-clickable-near",
        nargs=3,
        type=float,
        metavar=("X", "Y", "RADIUS"),
        help="select the rightmost enabled clickable node near an anchor row",
    )
    parser.add_argument(
        "--container-text-hex",
        help="UTF-8 container label as hexadecimal; limits the search to its nearest complete row",
    )
    parser.add_argument(
        "--target",
        choices=("text", "clickable", "checkable"),
        default="clickable",
        help="return the visible matching text center or its nearest clickable ancestor",
    )
    parser.add_argument("--expect-checked", choices=("true", "false"))
    parser.add_argument("--expect-background")
    parser.add_argument("--expect-count", type=int)
    parser.add_argument(
        "--exact-text",
        action="store_true",
        help="match the complete visible text instead of a substring",
    )
    parser.add_argument("--minimum-y", type=int)
    parser.add_argument("--maximum-y", type=int)
    args = parser.parse_args()

    find_text = None
    if args.find_text_hex:
        find_text = bytes.fromhex(args.find_text_hex).decode("utf-8")
    elif args.find_text:
        find_text = args.find_text
    parsed = json.loads(args.layout.read_text(encoding="utf-8"))
    root = parsed[0] if isinstance(parsed, list) else parsed
    root_bounds = parse_bounds(root["attributes"]["bounds"])
    matches: list[tuple[dict[str, Any], list[dict[str, Any]]]] = []
    container_matches: list[tuple[dict[str, Any], list[dict[str, Any]]]] = []
    for node, ancestors in walk(root):
        attributes = node.get("attributes", {})
        if not effectively_visible(attributes, root_bounds):
            continue
        _, candidate_y = center(attributes["bounds"])
        if args.minimum_y is not None and candidate_y < args.minimum_y:
            continue
        if args.maximum_y is not None and candidate_y > args.maximum_y:
            continue
        candidate_label = label(node)
        if find_text is not None:
            matches_text = (
                candidate_label == find_text
                if args.exact_text
                else find_text in candidate_label
            )
            if matches_text:
                matches.append((node, ancestors))
        if (
            args.container_text_hex
            and bytes.fromhex(args.container_text_hex).decode("utf-8") in label(node)
        ):
            container_matches.append((node, ancestors))

    if args.rightmost_clickable_below:
        anchor_x, anchor_y = args.rightmost_clickable_below
        candidates = []
        for node, ancestors in walk(root):
            attributes = node.get("attributes", {})
            if (not effectively_visible(attributes, root_bounds) or
                    attributes.get("clickable") != "true" or
                    attributes.get("enabled") != "true"):
                continue
            x, y = center(attributes["bounds"])
            if args.minimum_y is not None and y < args.minimum_y:
                continue
            if args.maximum_y is not None and y > args.maximum_y:
                continue
            if x > anchor_x and 0 < y - anchor_y <= 500:
                candidates.append((y, -x, node, ancestors))
        if not candidates:
            print("no enabled clickable node found below the anchor", file=sys.stderr)
            return 1
        candidates.sort(key=lambda candidate: (candidate[0], candidate[1]))
        _, _, node, ancestors = candidates[0]
        matches = [(node, ancestors)]
    elif args.rightmost_clickable_near:
        anchor_x, anchor_y, radius = args.rightmost_clickable_near
        candidates = []
        for node, ancestors in walk(root):
            attributes = node.get("attributes", {})
            if (not effectively_visible(attributes, root_bounds) or
                    attributes.get("clickable") != "true" or
                    attributes.get("enabled") != "true"):
                continue
            x, y = center(attributes["bounds"])
            if args.minimum_y is not None and y < args.minimum_y:
                continue
            if args.maximum_y is not None and y > args.maximum_y:
                continue
            delta_y = abs(y - anchor_y)
            if x > anchor_x and delta_y <= radius:
                candidates.append((delta_y, -x, node, ancestors))
        if not candidates:
            print("no enabled clickable node found near the anchor", file=sys.stderr)
            return 1
        candidates.sort(key=lambda candidate: (candidate[0], candidate[1]))
        _, _, node, ancestors = candidates[0]
        matches = [(node, ancestors)]
    elif args.container_text_hex:
        if not container_matches:
            print(
                f"visible container text not found: "
                f"{bytes.fromhex(args.container_text_hex).decode('utf-8')}",
                file=sys.stderr,
            )
            return 1
        _, container_ancestors = container_matches[0]
        for ancestor in reversed(container_ancestors):
            descendant_matches = [
                (candidate, candidate_ancestors)
                for candidate, candidate_ancestors in walk(ancestor)
                if effectively_visible(candidate.get("attributes", {}), root_bounds)
                and (
                    label(candidate) == find_text
                    if args.exact_text
                    else find_text in label(candidate)
                )
            ]
            if descendant_matches:
                matches = descendant_matches
                break

    match_count = len(matches)
    if args.expect_count is not None and match_count != args.expect_count:
        print(
            f"visible text count mismatch for {find_text}: "
            f"expected {args.expect_count}, got {match_count}",
            file=sys.stderr,
        )
        return 1
    if not matches and args.expect_count == 0:
        print(json.dumps({
            "text": find_text,
            "count": 0,
            "x": None,
            "y": None,
            "checked": None,
            "background": "",
        }))
        return 0
    if not matches:
        print(f"visible text not found: {find_text}", file=sys.stderr)
        return 1
    node, ancestors = matches[0]
    target = node
    if args.target == "clickable":
        for candidate in reversed(ancestors):
            if candidate.get("attributes", {}).get("clickable") == "true":
                target = candidate
                break
    elif args.target == "checkable":
        clickable: dict[str, Any] | None = None
        for candidate in reversed(ancestors):
            if candidate.get("attributes", {}).get("clickable") == "true":
                clickable = candidate
                break
        search_roots = [clickable] if clickable is not None else [node]
        for search_root in search_roots:
            for candidate, _ in walk(search_root):
                if candidate.get("attributes", {}).get("checkable") == "true":
                    target = candidate
                    break
            if target is not node:
                break
    x, y = visible_center(root_bounds, target["attributes"]["bounds"])

    checked: str | None = None
    for candidate in reversed(ancestors):
        attributes = candidate.get("attributes", {})
        if attributes.get("checkable") == "true":
            checked = attributes.get("checked", "")
            break
    if checked is None and target is not node:
        for candidate, _ in walk(target):
            attributes = candidate.get("attributes", {})
            if attributes.get("checkable") == "true":
                checked = attributes.get("checked", "")
                break
    if args.expect_checked is not None and checked != args.expect_checked:
        print(
            f"checked state mismatch for {find_text}: "
            f"expected {args.expect_checked}, got {checked!r}",
            file=sys.stderr,
        )
        return 1
    background = target.get("attributes", {}).get("backgroundColor", "")
    if args.expect_background and background.lower() != args.expect_background.lower():
        print(
            f"background mismatch for {find_text}: "
            f"expected {args.expect_background}, got {background!r}",
            file=sys.stderr,
        )
        return 1

    print(json.dumps({
        "text": find_text,
        "count": match_count,
        "x": x,
        "y": y,
        "checked": checked,
        "background": background,
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
