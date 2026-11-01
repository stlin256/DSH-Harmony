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
    return " ".join(
        value
        for value in (
            attributes.get("text", ""),
            attributes.get("accessibilityText", ""),
            attributes.get("originalText", ""),
        )
        if value
    )


def inside(root_bounds: tuple[int, int, int, int], value: str) -> bool:
    left, top, right, bottom = parse_bounds(value)
    root_left, root_top, root_right, root_bottom = root_bounds
    return (
        left >= root_left
        and top >= root_top
        and right <= root_right
        and bottom <= root_bottom
        and right > left
        and bottom > top
    )


def center(value: str) -> tuple[int, int]:
    left, top, right, bottom = parse_bounds(value)
    return ((left + right) // 2, (top + bottom) // 2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout", type=Path)
    text_group = parser.add_mutually_exclusive_group(required=True)
    text_group.add_argument("--find-text")
    text_group.add_argument(
        "--find-text-hex",
        help="UTF-8 text encoded as hexadecimal; avoids shell code-page failures",
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
    args = parser.parse_args()

    find_text = (
        bytes.fromhex(args.find_text_hex).decode("utf-8")
        if args.find_text_hex
        else args.find_text
    )
    parsed = json.loads(args.layout.read_text(encoding="utf-8"))
    root = parsed[0] if isinstance(parsed, list) else parsed
    root_bounds = parse_bounds(root["attributes"]["bounds"])
    matches: list[tuple[dict[str, Any], list[dict[str, Any]]]] = []
    container_matches: list[tuple[dict[str, Any], list[dict[str, Any]]]] = []
    for node, ancestors in walk(root):
        attributes = node.get("attributes", {})
        if attributes.get("visible") != "true":
            continue
        if not inside(root_bounds, attributes.get("bounds", "")):
            continue
        candidate_label = label(node)
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

    if args.container_text_hex:
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
                if candidate.get("attributes", {}).get("visible") == "true"
                and inside(root_bounds, candidate.get("attributes", {}).get("bounds", ""))
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
    x, y = center(target["attributes"]["bounds"])

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
