#!/usr/bin/env python3
"""Assert that the task-plan Dock overlays instead of reflowing the transcript."""

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


def walk(
    node: dict[str, Any],
    ancestors: list[dict[str, Any]] | None = None,
):
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


def visible(attributes: dict[str, Any]) -> bool:
    if attributes.get("visible") != "true":
        return False
    try:
        return float(attributes.get("opacity", "1")) > 0.01
    except (TypeError, ValueError):
        return True


def parse_layout(path: Path) -> tuple[dict[str, Any], list[tuple[dict[str, Any], list[dict[str, Any]]]]]:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    root = parsed[0] if isinstance(parsed, list) else parsed
    return root, list(walk(root))


def exact_nodes(
    nodes: list[tuple[dict[str, Any], list[dict[str, Any]]]],
    text: str,
) -> list[tuple[dict[str, Any], list[dict[str, Any]]]]:
    return [
        (node, ancestors)
        for node, ancestors in nodes
        if visible(node.get("attributes", {})) and label(node) == text
    ]


def largest_list(
    nodes: list[tuple[dict[str, Any], list[dict[str, Any]]]],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    candidates = [
        (node, ancestors)
        for node, ancestors in nodes
        if visible(node.get("attributes", {}))
        and node.get("attributes", {}).get("type") == "List"
    ]
    if not candidates:
        raise ValueError("visible transcript List was not found")
    return max(
        candidates,
        key=lambda item: (
            (lambda bounds: (bounds[2] - bounds[0]) * (bounds[3] - bounds[1]))(
                parse_bounds(item[0]["attributes"]["bounds"])
            )
        ),
    )


def first_list_item(
    list_node: dict[str, Any],
) -> dict[str, Any]:
    for child in list_node.get("children", []):
        if child.get("attributes", {}).get("type") == "ListItem":
            return child
    raise ValueError("visible transcript List has no first ListItem")


def clickable_row(
    node: dict[str, Any],
    ancestors: list[dict[str, Any]],
) -> dict[str, Any]:
    for candidate in reversed(ancestors):
        attributes = candidate.get("attributes", {})
        if attributes.get("clickable") == "true" and visible(attributes):
            return candidate
    return node


def common_ancestor(
    first: list[dict[str, Any]],
    second: list[dict[str, Any]],
) -> dict[str, Any]:
    second_ids = {id(node) for node in second}
    for node in reversed(first):
        if id(node) in second_ids:
            return node
    raise ValueError("task-plan header and expanded content have no common ancestor")


def node_bounds(node: dict[str, Any]) -> tuple[int, int, int, int]:
    return parse_bounds(node.get("attributes", {}).get("bounds", ""))


def center(bounds: tuple[int, int, int, int]) -> tuple[int, int]:
    left, top, right, bottom = bounds
    return ((left + right) // 2, (top + bottom) // 2)


def list_text_signature(
    nodes: list[tuple[dict[str, Any], list[dict[str, Any]]]],
) -> list[tuple[int, str]]:
    list_node, _ = largest_list(nodes)
    result: list[tuple[int, str]] = []
    for node, ancestors in walk(list_node):
        attributes = node.get("attributes", {})
        text = label(node)
        if not text or not visible(attributes):
            continue
        _, y = center(node_bounds(node))
        result.append((y, text))
    return sorted(result)


def assert_same_list(
    name: str,
    expected: tuple[int, int, int, int],
    actual: tuple[int, int, int, int],
) -> None:
    if abs(expected[1] - actual[1]) > 2 or abs(expected[3] - actual[3]) > 2:
        raise ValueError(
            f"{name}: transcript List moved or resized: {expected} -> {actual}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--collapsed", type=Path, required=True)
    parser.add_argument("--expanded", type=Path, required=True)
    parser.add_argument("--scrolled", type=Path)
    parser.add_argument("--item", default="检查隐私与账户入口")
    args = parser.parse_args()

    try:
        _, collapsed_nodes = parse_layout(args.collapsed)
        _, expanded_nodes = parse_layout(args.expanded)

        collapsed_header = exact_nodes(collapsed_nodes, "任务计划")
        if not collapsed_header:
            raise ValueError("collapsed task-plan header was not found")
        collapsed_header_node, collapsed_header_ancestors = collapsed_header[0]
        collapsed_row = clickable_row(collapsed_header_node, collapsed_header_ancestors)
        collapsed_dock = node_bounds(collapsed_row)
        collapsed_list_node, _ = largest_list(collapsed_nodes)
        collapsed_list = node_bounds(collapsed_list_node)
        collapsed_spacer = node_bounds(first_list_item(collapsed_list_node))

        if abs(collapsed_dock[1] - collapsed_list[1]) > 4:
            raise ValueError(
                "collapsed Dock is not anchored at the transcript top: "
                f"dock={collapsed_dock}, list={collapsed_list}"
            )
        if (abs(collapsed_spacer[1] - collapsed_list[1]) > 4 or
                abs(collapsed_spacer[3] - collapsed_dock[3]) > 4):
            raise ValueError(
                "collapsed transcript spacer does not match the Dock height: "
                f"spacer={collapsed_spacer}, dock={collapsed_dock}, "
                f"list={collapsed_list}"
            )

        expanded_header = exact_nodes(expanded_nodes, "任务计划")
        expanded_item = exact_nodes(expanded_nodes, args.item)
        if not expanded_header:
            raise ValueError("expanded task-plan header was not found")
        if not expanded_item:
            raise ValueError(f"expanded task-plan item was not found: {args.item}")
        expanded_header_node, expanded_header_ancestors = expanded_header[0]
        expanded_item_node, expanded_item_ancestors = expanded_item[0]
        expanded_group = common_ancestor(
            expanded_header_ancestors + [expanded_header_node],
            expanded_item_ancestors + [expanded_item_node],
        )
        expanded_dock = node_bounds(expanded_group)
        expanded_list_node, _ = largest_list(expanded_nodes)
        expanded_list = node_bounds(expanded_list_node)
        expanded_spacer = node_bounds(first_list_item(expanded_list_node))

        if abs(expanded_dock[1] - collapsed_dock[1]) > 2:
            raise ValueError(
                "expanding the Dock moved its header: "
                f"{collapsed_dock} -> {expanded_dock}"
            )
        if expanded_dock[3] <= collapsed_dock[3] + 20:
            raise ValueError(
                "expanded Dock did not grow downward: "
                f"{collapsed_dock} -> {expanded_dock}"
            )
        assert_same_list("expanded vs collapsed", collapsed_list, expanded_list)
        if expanded_dock[3] <= expanded_list[1]:
            raise ValueError("expanded Dock does not overlap the transcript List")
        if (abs(expanded_spacer[1] - expanded_list[1]) > 4 or
                abs(expanded_spacer[3] - expanded_dock[3]) > 4):
            raise ValueError(
                "expanded transcript spacer does not match the Dock height: "
                f"spacer={expanded_spacer}, dock={expanded_dock}, "
                f"list={expanded_list}"
            )
        collapsed_spacer_height = collapsed_spacer[3] - collapsed_spacer[1]
        expanded_spacer_height = expanded_spacer[3] - expanded_spacer[1]
        if expanded_spacer_height <= collapsed_spacer_height + 20:
            raise ValueError(
                "top spacer did not grow with the expanded Dock: "
                f"{collapsed_spacer} -> {expanded_spacer}"
            )

        left, top, right, bottom = expanded_list
        width = max(1, right - left)
        height = max(1, bottom - top)
        scroll_x = (left + right) // 2
        scroll_start_y = top + int(height * 0.68)
        scroll_end_y = top + int(height * 0.42)
        if scroll_start_y <= expanded_dock[3] + 24:
            scroll_start_y = min(bottom - 16, expanded_dock[3] + max(120, height // 5))
            scroll_end_y = min(scroll_start_y - 120, expanded_dock[3] + 72)
        if scroll_end_y >= scroll_start_y:
            raise ValueError("transcript List is too short for an outside-Dock swipe")

        if args.scrolled:
            _, scrolled_nodes = parse_layout(args.scrolled)
            _ = largest_list(scrolled_nodes)
            if list_text_signature(expanded_nodes) == list_text_signature(scrolled_nodes):
                raise ValueError("outside-Dock swipe did not move transcript content")
            assert_same_list(
                "scrolled vs expanded",
                expanded_list,
                node_bounds(largest_list(scrolled_nodes)[0]),
            )

        print(json.dumps({
            "collapsedDock": collapsed_dock,
            "collapsedSpacer": collapsed_spacer,
            "expandedDock": expanded_dock,
            "expandedSpacer": expanded_spacer,
            "transcriptList": expanded_list,
            "scroll": {
                "x": scroll_x,
                "startY": scroll_start_y,
                "endY": scroll_end_y,
                "width": width,
            },
        }))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
