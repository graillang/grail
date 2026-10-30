"""Shared typed-IR workload fixtures; no inferred origins are supplied here."""

from __future__ import annotations

from typing import Any


def p(i: int) -> dict[str, int]:
    return {"param": i}


def borrow(i: int) -> dict[str, Any]:
    return {"borrow": p(i)}


def call(name: str, *args: Any) -> dict[str, Any]:
    return {"call": {"fn": name, "args": list(args)}}


def function(
    name: str, types: list[Any], result: Any, body: Any, modes: list[str] | None = None
) -> dict[str, Any]:
    return {
        "name": name,
        "params": [
            {"type": ty, "mode": mode}
            for ty, mode in zip(types, modes or ["read"] * len(types), strict=True)
        ],
        "result": result,
        "body": body,
    }


def providers() -> list[dict[str, Any]]:
    generic = {"var": "T"}
    tree = {"tree": "view"}
    return [
        function("first", ["bytes"], "view", borrow(0)),
        function(
            "choose", ["bytes", "bytes"], "view", {"choice": [borrow(0), borrow(1)]}
        ),
        function(
            "pair",
            ["bytes", "bytes"],
            {"record": {"short": "view", "long": "view"}},
            {"record": {"short": borrow(0), "long": borrow(1)}},
        ),
        function(
            "capture",
            ["bytes"],
            {"capture": {"source": "view"}},
            {"capture": {"source": borrow(0)}},
        ),
        function("identity", [generic], generic, p(0), ["value"]),
        function(
            "wrap",
            [generic],
            {"record": {"payload": generic}},
            {"record": {"payload": p(0)}},
            ["value"],
        ),
        function(
            "unwrap",
            [{"record": {"payload": generic}}],
            generic,
            {"get": {"value": p(0), "path": ["payload"]}},
            ["value"],
        ),
        function(
            "parse",
            ["bytes"],
            tree,
            {
                "choice": [
                    {"tree_leaf": borrow(0)},
                    {
                        "tree_branch": {
                            "element": "view",
                            "items": [call("parse", p(0))],
                        }
                    },
                ]
            },
        ),
        function("leaves", [tree], {"list": "view"}, {"leaves": p(0)}, ["value"]),
        function(
            "visit",
            ["bytes", "callback"],
            "unit",
            {"visit": {"source": p(0), "callback": p(1), "mode": "modify"}},
            ["modify", "value"],
        ),
        function(
            "visit_read",
            ["bytes", "callback"],
            "unit",
            {"visit": {"source": p(0), "callback": p(1), "mode": "read"}},
            ["read", "value"],
        ),
        function(
            "visit_forward",
            ["bytes", "callback"],
            "unit",
            call("visit", p(0), p(1)),
            ["modify", "value"],
        ),
        function(
            "two_modify",
            ["bytes", "bytes", "callback"],
            "unit",
            {"visit": {"source": p(0), "callback": p(2), "mode": "modify"}},
            ["modify", "modify", "value"],
        ),
        function(
            "owned_fields",
            [{"record": {"left": "bytes", "right": "bytes"}}],
            {"record": {"left": "view", "right": "view"}},
            {
                "record": {
                    field: {"borrow": {"get": {"value": p(0), "path": [field]}}}
                    for field in ["left", "right"]
                }
            },
        ),
    ]


def owner(name: str, ty: Any = "bytes") -> dict[str, Any]:
    return {"op": "owner", "name": name, "type": ty}


def invoke(dest: str, name: str, *args: str) -> dict[str, Any]:
    return {"op": "call", "dest": dest, "fn": name, "args": [{"var": a} for a in args]}


def use(name: str, *path: str) -> dict[str, Any]:
    return {"op": "use", "var": name, "path": list(path)}


def callback(body: list[Any], captures: list[str] | None = None) -> dict[str, Any]:
    return {"op": "callback", "name": "cb", "captures": captures or [], "body": body}


def clients() -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []

    def add(name: str, accept: bool, *steps: Any) -> None:
        cases.append({"name": name, "accept": accept, "steps": list(steps)})

    add(
        "borrowed_tree_and_leaves",
        True,
        owner("input"),
        invoke("ast", "parse", "input"),
        invoke("leaves", "leaves", "ast"),
        {"op": "drop", "var": "ast"},
        use("leaves"),
        {"op": "end", "owner": "input"},
    )
    add(
        "reject_tree_invalidation",
        False,
        owner("input"),
        invoke("ast", "parse", "input"),
        {"op": "invalidate", "owner": "input"},
        use("ast"),
    )
    prefix = [owner("short"), owner("long"), invoke("pair", "pair", "short", "long")]
    add(
        "field_projection_survives_other_owner",
        True,
        *prefix,
        {"op": "project", "dest": "kept", "var": "pair", "path": ["long"]},
        {"op": "end", "owner": "short"},
        use("kept"),
    )
    add(
        "field_sensitive_last_use",
        True,
        *prefix,
        use("pair", "short"),
        {"op": "end", "owner": "short"},
        use("pair", "long"),
    )
    add(
        "whole_pair_keeps_both_owners",
        False,
        *prefix,
        {"op": "end", "owner": "short"},
        use("pair"),
    )
    add(
        "generic_wrap_unwrap",
        True,
        owner("input"),
        invoke("view", "first", "input"),
        invoke("box", "wrap", "view"),
        invoke("again", "unwrap", "box"),
        use("again"),
        {"op": "invalidate", "owner": "input"},
    )
    add(
        "generic_forward_keeps_origin",
        False,
        owner("input"),
        invoke("tree", "parse", "input"),
        invoke("same", "identity", "tree"),
        {"op": "end", "owner": "input"},
        use("same"),
    )
    add(
        "captured_view_keeps_owner",
        False,
        owner("input"),
        invoke("closure", "capture", "input"),
        {"op": "end", "owner": "input"},
        use("closure"),
    )
    add(
        "capture_last_use_releases",
        True,
        owner("input"),
        invoke("closure", "capture", "input"),
        use("closure"),
        {"op": "invalidate", "owner": "input"},
    )
    add(
        "choice_requires_both_bounds",
        False,
        owner("a"),
        owner("b"),
        invoke("v", "choose", "a", "b"),
        {"op": "end", "owner": "b"},
        use("v"),
    )
    add(
        "disjoint_owned_fields",
        True,
        owner("object", {"record": {"left": "bytes", "right": "bytes"}}),
        invoke("views", "owned_fields", "object"),
        {"op": "invalidate", "owner": "object", "path": ["right"]},
        use("views", "left"),
    )
    add(
        "same_owned_field_conflict",
        False,
        owner("object", {"record": {"left": "bytes", "right": "bytes"}}),
        invoke("views", "owned_fields", "object"),
        {"op": "invalidate", "owner": "object", "path": ["left"]},
        use("views", "left"),
    )
    add(
        "scoped_callback_modify",
        True,
        owner("input"),
        callback(
            [
                {"op": "let", "name": "alias", "value": {"local": "item"}},
                {"op": "inspect", "value": {"local": "alias"}},
                {"op": "write_item"},
            ]
        ),
        invoke("done", "visit_forward", "input", "cb"),
        {"op": "end", "owner": "input"},
    )
    for name, value in [
        ("direct", {"local": "item"}),
        ("generic", call("identity", {"local": "item"})),
        ("aggregate", {"record": {"text": {"local": "item"}}}),
        ("capture", {"captured": {"saved": {"local": "item"}}}),
    ]:
        add(
            "callback_escape_" + name,
            False,
            owner("input"),
            callback([{"op": "store", "target": "saved", "value": value}]),
            invoke("done", "visit", "input", "cb"),
        )
    add(
        "callback_return_escape",
        False,
        owner("input"),
        callback([{"op": "return", "value": {"local": "item"}}]),
        invoke("done", "visit", "input", "cb"),
    )
    add(
        "callback_captured_alias",
        False,
        owner("input"),
        {"op": "alias", "name": "alias", "of": "input"},
        callback([{"op": "inspect", "value": {"capture": "alias"}}], ["alias"]),
        invoke("done", "visit", "input", "cb"),
    )
    add(
        "callback_read_cannot_write",
        False,
        owner("input"),
        callback([{"op": "write_item"}]),
        invoke("done", "visit_read", "input", "cb"),
    )
    add(
        "two_modify_aliases",
        False,
        owner("input"),
        callback([]),
        invoke("done", "two_modify", "input", "input", "cb"),
    )
    add(
        "two_modify_disjoint",
        True,
        owner("a"),
        owner("b"),
        callback([]),
        invoke("done", "two_modify", "a", "b", "cb"),
    )
    add(
        "callback_scope_does_not_escape",
        True,
        owner("a"),
        callback([]),
        invoke("done", "visit", "a", "cb"),
        {"op": "end", "owner": "a"},
    )
    add("unknown_operation_rejected", False, {"op": "unsafe_magic"})
    add(
        "use_after_drop_rejected",
        False,
        owner("a"),
        invoke("v", "first", "a"),
        {"op": "drop", "var": "v"},
        use("v"),
    )
    add(
        "generic_owned_value_rejected",
        False,
        owner("a"),
        invoke("moved", "identity", "a"),
    )
    return cases
