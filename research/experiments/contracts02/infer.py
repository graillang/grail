"""Monotone origin/capture inference for the restricted expression IR."""

from __future__ import annotations

import hashlib
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Any

from contracts import Param, Summary, canonical, decode
from model import Info, Obligation, Origin, Rejected, Ty, merge, overlap


@dataclass
class Function:
    name: str
    params: tuple[Param, ...]
    result: Ty
    body: dict[str, Any]

    @staticmethod
    def parse(raw: Any) -> Function:
        if not isinstance(raw, dict) or set(raw) != {
            "name",
            "params",
            "result",
            "body",
        }:
            raise Rejected("invalid function IR")
        if not isinstance(raw["name"], str) or not raw["name"]:
            raise Rejected("invalid function name")
        return Function(
            raw["name"],
            tuple(Param.parse(p) for p in raw["params"]),
            Ty.parse(raw["result"]),
            raw["body"],
        )


def evaluate(
    expr: Any,
    params: list[Info],
    functions: dict[str, Function],
    summaries: dict[str, Summary],
    current: Function,
    depth: int = 0,
) -> Info:
    if depth > 128 or not isinstance(expr, dict) or len(expr) != 1:
        raise Rejected("invalid/too-deep expression")
    op, value = next(iter(expr.items()))

    def ev(e: Any) -> Info:
        return evaluate(e, params, functions, summaries, current, depth + 1)

    if op == "param":
        if type(value) is not int or not 0 <= value < len(params):
            raise Rejected("bad parameter reference")
        return params[value]
    if op == "unit" and value is True:
        return Info(Ty("unit"))
    if op == "local_view" and isinstance(value, str):
        return Info(Ty("view"), {(): frozenset({Origin(-1, (value,), "local")})})
    if op == "get" and isinstance(value, dict) and set(value) == {"value", "path"}:
        return ev(value["value"]).project(tuple(value["path"]))
    if op == "borrow":
        source = ev(value)
        if source.ty.kind != "bytes" or () not in source.stores:
            raise Rejected("borrow requires an input storage place")
        return Info(
            Ty("view"),
            {(): frozenset({source.stores[()]})},
            obligations=source.obligations,
            productive=source.productive,
        )
    if op in {"record", "capture"} and isinstance(value, dict):
        entries = [(k, ev(v)) for k, v in sorted(value.items())]
        result = Info(
            Ty.parse({op: {k: v.ty.raw() for k, v in entries}}),
            productive=all(v.productive for _, v in entries),
        )
        for key, child in entries:
            result.flows.update(
                {(key,) + p: origins for p, origins in child.flows.items()}
            )
            result.stores.update(
                {(key,) + p: origin for p, origin in child.stores.items()}
            )
            result.obligations |= child.obligations
        return result
    if op == "choice" and isinstance(value, list) and value:
        branches = [ev(v) for v in value]
        return merge(branches[0].ty, branches)
    if (
        op in {"list", "tree_branch"}
        and isinstance(value, dict)
        and set(value) == {"element", "items"}
    ):
        inner = Ty.parse(value["element"])
        ty = Ty("list" if op == "list" else "tree", inner=inner)
        children = [ev(v) for v in value["items"]]
        if op == "list":
            joined = merge(inner, children)
            return Info(
                ty,
                {("*",) + p: origins for p, origins in joined.flows.items()},
                obligations=joined.obligations,
                productive=all(v.productive for v in children),
            )
        joined = merge(ty, children)
        joined.productive = all(v.productive for v in children)
        return joined
    if op == "leaves":
        source = ev(value)
        if source.ty.kind != "tree":
            raise Rejected("leaves requires a tree")
        return Info(
            Ty("list", inner=source.ty.inner),
            source.flows.copy(),
            obligations=source.obligations,
            productive=source.productive,
        )
    if op == "tree_leaf":
        child = ev(value)
        if child.stores or child.callback is not None:
            raise Rejected("owning/callback tree payload unsupported")
        return Info(
            Ty("tree", inner=child.ty),
            {("*",) + p: origins for p, origins in child.flows.items()},
            obligations=child.obligations,
            productive=child.productive,
        )
    if op == "call" and isinstance(value, dict) and set(value) == {"fn", "args"}:
        if value["fn"] not in summaries:
            raise Rejected("unknown callee")
        args = [ev(v) for v in value["args"]]
        callee = summaries[value["fn"]]
        for formal, actual in zip(callee.params, args):
            for origin in actual.stores.values():
                if (
                    formal.mode == "modify"
                    and current.params[origin.parameter].mode != "modify"
                ):
                    raise Rejected("callee requires modification of a read-only input")
        footprints = [
            (formal.mode, origin)
            for formal, actual in zip(callee.params, args)
            for origin in [
                *actual.stores.values(),
                *(o for v in actual.flows.values() for o in v),
            ]
        ]
        for i, (mode, origin) in enumerate(footprints):
            for other_mode, other in footprints[i + 1 :]:
                if (
                    "modify" in {mode, other_mode}
                    and origin.parameter == other.parameter
                    and overlap(origin.path, other.path)
                ):
                    raise Rejected("overlapping transient call permissions")
        return callee.apply(args)
    if (
        op == "visit"
        and isinstance(value, dict)
        and set(value) == {"source", "callback", "mode"}
    ):
        source, callback = ev(value["source"]), ev(value["callback"])
        if (
            source.ty.kind != "bytes"
            or callback.ty.kind != "callback"
            or callback.callback is None
        ):
            raise Rejected("visit requires storage and callback input")
        origin = source.stores.get(())
        if origin is None or value["mode"] not in {"read", "modify"}:
            raise Rejected("invalid visit source/mode")
        if (
            value["mode"] == "modify"
            and current.params[origin.parameter].mode != "modify"
        ):
            raise Rejected("visit modifies a read-only parameter")
        return Info(
            Ty("unit"),
            obligations=frozenset(
                {Obligation(callback.callback, origin, value["mode"])}
            ),
        )
    raise Rejected(f"unsupported operation: {op}")


def callees(expr: Any) -> set[str]:
    result: set[str] = set()
    if isinstance(expr, dict):
        if set(expr) == {"call"} and isinstance(expr["call"], dict):
            result.add(expr["call"].get("fn", ""))
        for child in expr.values():
            result |= callees(child)
    elif isinstance(expr, list):
        for child in expr:
            result |= callees(child)
    return result


def infer(
    raw_functions: list[Any],
    *,
    imports: dict[str, Summary] | None = None,
    max_analyses: int = 100000,
    max_relations: int = 200000,
) -> tuple[dict[str, Any], dict[str, int]]:
    definitions = [Function.parse(f) for f in raw_functions]
    functions = {f.name: f for f in definitions}
    if len(functions) != len(definitions):
        raise Rejected("duplicate or reserved function name")
    imported = imports or {}
    if set(imported) & set(functions):
        raise Rejected("import/local function name collision")
    summaries = {f.name: Summary(f.name, f.params, f.result, {}) for f in definitions}
    summaries.update(imported)
    callers: dict[str, set[str]] = defaultdict(set)
    for f in definitions:
        for callee in callees(f.body):
            if callee not in summaries:
                raise Rejected("unknown function dependency")
            callers[callee].add(f.name)
    pending = deque(functions)
    queued = set(pending)
    analyses = 0
    while pending:
        name = pending.popleft()
        queued.remove(name)
        analyses += 1
        if analyses > max_analyses:
            raise Rejected("inference work budget exhausted")
        f = functions[name]
        value = evaluate(
            f.body,
            [Info.parameter(i, p.ty) for i, p in enumerate(f.params)],
            functions,
            summaries,
            f,
        )
        if value.ty != f.result:
            raise Rejected(f"{name}: result type mismatch")
        if any(t.kind in {"bytes", "callback"} for _, t in f.result.leaves()):
            raise Rejected("owning/callback returns unsupported")
        if any(o.kind == "local" for origins in value.flows.values() for o in origins):
            raise Rejected(
                f"{name}: result retains local storage that dies with the function"
            )
        if value.obligations and f.result.kind != "unit":
            raise Rejected("callback effects combined with non-unit output unsupported")
        if sum(len(v) for v in value.flows.values()) > max_relations:
            raise Rejected("origin relation budget exhausted")
        new = Summary(
            name, f.params, f.result, value.flows, value.obligations, value.productive
        )
        if new != summaries[name]:
            summaries[name] = new
            for caller in sorted(callers[name]):
                if caller not in queued:
                    pending.append(caller)
                    queued.add(caller)
    summaries = {name: summaries[name] for name in functions}
    if any(not s.productive for s in summaries.values()):
        raise Rejected("nonproductive recursive definition outside export fragment")
    artifact = {
        "schema": 1,
        "producer": "contracts02-research-v1",
        "body_sha256": hashlib.sha256(canonical(raw_functions)).hexdigest(),
        "imports_sha256": hashlib.sha256(
            canonical([v.raw() for _, v in sorted(imported.items())])
        ).hexdigest(),
        "functions": [s.raw() for _, s in sorted(summaries.items())],
    }
    decode(artifact)
    return artifact, {
        "functions": len(functions),
        "analyses": analyses,
        "relations": sum(len(v) for s in summaries.values() for v in s.flows.values()),
    }
