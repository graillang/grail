"""Versioned dependency transformers; applies all outputs from a single entry snapshot."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Hashable
from dataclasses import dataclass
from typing import Any, TypeVar

from research.experiments.contracts02.model import Path, Rejected, Ty
from research.experiments.transforms05.value import Pre, Value, bindings_for, data_type

Atom = TypeVar("Atom", bound=Hashable)


def canonical(raw: Any) -> bytes:
    return json.dumps(raw, sort_keys=True, separators=(",", ":")).encode()


@dataclass(frozen=True)
class Parameter:
    ty: Ty
    mode: str

    @staticmethod
    def parse(raw: Any) -> Parameter:
        if (
            not isinstance(raw, dict)
            or set(raw) != {"type", "mode"}
            or not isinstance(raw["mode"], str)
            or raw["mode"] not in {"read", "mut", "take"}
        ):
            raise Rejected("invalid parameter")
        ty = Ty.parse(raw["type"])
        data_type(ty)
        return Parameter(ty, raw["mode"])

    def raw(self) -> dict[str, Any]:
        return {"type": self.ty.raw(), "mode": self.mode}


@dataclass
class Contract:
    name: str
    params: tuple[Parameter, ...]
    result: Value[Pre]
    post: dict[int, Value[Pre]]

    def apply(
        self, actuals: list[Value[Atom]]
    ) -> tuple[Value[Atom], dict[int, Value[Atom]]]:
        from research.experiments.transforms05.value import instantiate

        bindings = bindings_for([p.ty for p in self.params], actuals)
        # Never resolve a pre(...) term by reading an already-updated mutable actual.
        entry = [Value(v.ty, v.flows.copy()) for v in actuals]
        result = instantiate(self.result, entry, bindings)
        post = {i: instantiate(v, entry, bindings) for i, v in self.post.items()}
        return result, post

    def raw(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "params": [p.raw() for p in self.params],
            "result_type": self.result.ty.raw(),
            "result": routes(self.result),
            "post": [
                {"argument": i, "routes": routes(v)}
                for i, v in sorted(self.post.items())
            ],
        }

    def fingerprint(self) -> str:
        return hashlib.sha256(canonical(self.raw())).hexdigest()

    def refines(self, public: Contract) -> bool:
        if (
            self.name != public.name
            or self.params != public.params
            or self.result.ty != public.result.ty
            or self.post.keys() != public.post.keys()
        ):
            return False
        pairs = [
            (self.result, public.result),
            *((self.post[i], public.post[i]) for i in self.post),
        ]
        return all(
            all(
                roots <= upper.flows.get(path, frozenset())
                for path, roots in value.flows.items()
            )
            for value, upper in pairs
        )


def routes(value: Value[Pre]) -> list[dict[str, Any]]:
    return [
        {
            "out": list(path),
            "pre": [
                {"argument": s.argument, "path": list(s.path), "tail": s.tail}
                for s in sorted(roots)
            ],
        }
        for path, roots in sorted(value.flows.items())
        if roots
    ]


def path(raw: Any) -> Path:
    if (
        not isinstance(raw, list)
        or len(raw) > 32
        or any(not isinstance(v, str) for v in raw)
    ):
        raise Rejected("invalid path")
    return tuple(raw)


def read_routes(raw: Any, ty: Ty, params: tuple[Parameter, ...]) -> Value[Pre]:
    if not isinstance(raw, list) or len(raw) > 10000:
        raise Rejected("invalid route collection")
    value: Value[Pre] = Value(ty)
    for route in raw:
        if not isinstance(route, dict) or set(route) != {"out", "pre"}:
            raise Rejected("invalid route")
        output = path(route["out"])
        target = ty.at(output)
        if target.kind not in {"view", 'mut'} or output in value.flows:
            raise Rejected("invalid/duplicate output position")
        if not isinstance(route["pre"], list) or len(route["pre"]) > 10000:
            raise Rejected("invalid source collection")
        sources = set()
        for raw_source in route["pre"]:
            if not isinstance(raw_source, dict) or set(raw_source) != {
                "argument",
                "path",
                "tail",
            }:
                raise Rejected("invalid pre-state source")
            index = raw_source["argument"]
            if (
                type(index) is not int
                or not 0 <= index < len(params)
                or type(raw_source["tail"]) is not bool
            ):
                raise Rejected("invalid source argument/tail")
            source_path = path(raw_source["path"])
            source_ty = params[index].ty.at(source_path)
            if raw_source["tail"]:
                if source_ty.kind != 'mut' or target != source_ty:
                    raise Rejected("opaque prefix source/target mismatch")
            elif source_ty.kind != "view" or target.kind != "view":
                raise Rejected("view source/target mismatch")
            sources.add(Pre(index, source_path, raw_source["tail"]))
        value.flows[output] = frozenset(sources)
    for position, leaf in ty.leaves():
        if (
            leaf.kind in {"view", 'mut'}
            and "*" not in position
            and not value.flows.get(position)
        ):
            raise Rejected("nonempty data position has no source")
    return value


def decode(raw: Any) -> dict[str, Contract]:
    if (
        not isinstance(raw, dict)
        or set(raw) != {"schema", "contracts"}
        or type(raw["schema"]) is not int
        or raw["schema"] != 1
    ):
        raise Rejected("invalid state-contract module")
    if not isinstance(raw["contracts"], list) or len(raw["contracts"]) > 1024:
        raise Rejected("invalid contract collection")
    result = {}
    for item in raw["contracts"]:
        if not isinstance(item, dict) or set(item) != {
            "name",
            "params",
            "result_type",
            "result",
            "post",
        }:
            raise Rejected("invalid contract schema")
        name = item["name"]
        if not isinstance(name, str) or not name or name in result:
            raise Rejected("invalid/duplicate name")
        if (
            not isinstance(item["params"], list)
            or len(item["params"]) > 64
            or not isinstance(item["post"], list)
        ):
            raise Rejected("invalid parameter/post collection")
        params = tuple(Parameter.parse(v) for v in item["params"])
        ty = Ty.parse(item["result_type"])
        data_type(ty)
        returned = read_routes(item["result"], ty, params)
        post = {}
        for entry in item["post"]:
            if not isinstance(entry, dict) or set(entry) != {"argument", "routes"}:
                raise Rejected("invalid post-state")
            index = entry["argument"]
            if (
                type(index) is not int
                or not 0 <= index < len(params)
                or params[index].mode != "mut"
                or index in post
            ):
                raise Rejected("invalid/duplicate mutable post-state")
            post[index] = read_routes(entry["routes"], params[index].ty, params)
        if set(post) != {i for i, p in enumerate(params) if p.mode == "mut"}:
            raise Rejected("missing mutable post-state (preserve must be explicit)")
        result[name] = Contract(name, params, returned, post)
    return result
