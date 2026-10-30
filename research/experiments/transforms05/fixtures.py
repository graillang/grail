"""Procedure fixtures have types/modes but no written dependency postconditions."""

from __future__ import annotations

from typing import Any

T = {"var": "T"}
SEQ = {"list": T}


def arg(i: int, *path: str) -> dict[str, Any]:
    return {"arg": i, "path": list(path)}


def move(i: int) -> dict[str, Any]:
    return {"move": arg(i)}


def procedure(
    name: str,
    types: list[Any],
    modes: list[str],
    result: Any,
    body: list[Any],
    returned: Any | None = None,
) -> dict[str, Any]:
    return {
        "name": name,
        "params": [
            {"type": ty, "mode": mode} for ty, mode in zip(types, modes, strict=True)
        ],
        "result": result,
        "body": body,
        "return": returned or {"unit": True},
    }


def definitions() -> list[dict[str, Any]]:
    return [
        procedure(
            "append",
            [SEQ, T],
            ["mut", "take"],
            "unit",
            [{"op": "append", "target": arg(0), "value": move(1)}],
        ),
        procedure("clear", [SEQ], ["mut"], "unit", [{"op": "clear", "target": arg(0)}]),
        procedure(
            "replace_all",
            [SEQ, SEQ],
            ["mut", "take"],
            SEQ,
            [{"op": "replace", "target": arg(0), "value": move(1), "dest": "old"}],
            {"move": {"local": "old"}},
        ),
        procedure(
            "take_all",
            [SEQ],
            ["mut"],
            SEQ,
            [{"op": "take_all", "target": arg(0), "dest": "old"}],
            {"move": {"local": "old"}},
        ),
        procedure(
            "replace_slot",
            [T, T],
            ["mut", "take"],
            T,
            [{"op": "replace", "target": arg(0), "value": move(1), "dest": "old"}],
            {"move": {"local": "old"}},
        ),
        procedure(
            "swap",
            [T, T],
            ["mut", "mut"],
            "unit",
            [{"op": "swap", "left": arg(0), "right": arg(1)}],
        ),
        procedure(
            "maybe_clear",
            [SEQ],
            ["mut"],
            "unit",
            [{"op": "branch", "then": [{"op": "clear", "target": arg(0)}], "else": []}],
        ),
        procedure(
            "clear_append",
            [SEQ, T],
            ["mut", "take"],
            "unit",
            [
                {
                    "op": "call",
                    "fn": "clear",
                    "args": [{"place": arg(0)}],
                    "dest": "u0",
                },
                {
                    "op": "call",
                    "fn": "append",
                    "args": [{"place": arg(0)}, {"value": move(1)}],
                    "dest": "u1",
                },
            ],
        ),
        procedure(
            "clear_or_replace",
            [SEQ, SEQ],
            ["mut", "take"],
            "unit",
            [
                {
                    "op": "branch",
                    "then": [{"op": "clear", "target": arg(0)}],
                    "else": [
                        {
                            "op": "replace",
                            "target": arg(0),
                            "value": move(1),
                            "dest": "discard",
                        }
                    ],
                }
            ],
        ),
        procedure(
            "return_pair",
            [T, T],
            ["take", "take"],
            {"record": {"a": T, "b": T}},
            [],
            {"record": {"a": move(0), "b": move(1)}},
        ),
        procedure(
            "clear_left",
            [{"record": {"left": SEQ, "right": SEQ}}],
            ["mut"],
            "unit",
            [{"op": "clear", "target": arg(0, "left")}],
        ),
    ]
