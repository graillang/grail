"""Checked contract schema and substitution; no provider body interpreter or inference."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from model import Info, Obligation, Origin, Path, Rejected, Ty, unify


@dataclass(frozen=True)
class Param:
    ty: Ty
    mode: str

    @staticmethod
    def parse(raw: Any) -> Param:
        if not isinstance(raw, dict) or set(raw) != {"type", "mode"}:
            raise Rejected("invalid parameter")
        if raw["mode"] not in {"read", "modify", "value"}:
            raise Rejected("invalid access mode")
        ty = Ty.parse(raw["type"])
        if raw["mode"] == "modify" and any(t.kind != "bytes" for _, t in ty.leaves()):
            raise Rejected(
                "modify parameters require owning byte places in this fragment"
            )
        if raw["mode"] == "value" and any(t.kind == "bytes" for _, t in ty.leaves()):
            raise Rejected("owning value moves are outside this place/loan experiment")
        return Param(ty, raw["mode"])

    def raw(self) -> dict[str, Any]:
        return {"type": self.ty.raw(), "mode": self.mode}


@dataclass
class Summary:
    name: str
    params: tuple[Param, ...]
    result: Ty
    flows: dict[Path, frozenset[Origin]]
    obligations: frozenset[Obligation] = frozenset()
    productive: bool = False

    def apply(self, args: list[Info]) -> Info:
        if len(args) != len(self.params):
            raise Rejected("wrong argument count")
        bindings: dict[str, Ty] = {}
        for param, actual in zip(self.params, args, strict=True):
            unify(param.ty, actual.ty, bindings)
        output = Info(self.result.substitute(bindings), productive=self.productive)
        for out, origins in self.flows.items():
            for origin in origins:
                actual = args[origin.parameter].project(origin.path)
                if origin.kind == "prefix":
                    for suffix, dependencies in actual.flows.items():
                        key = out + suffix
                        output.flows[key] = (
                            output.flows.get(key, frozenset()) | dependencies
                        )
                elif origin.kind == "loan":
                    output.flows[out] = output.flows.get(
                        out, frozenset()
                    ) | actual.flows.get((), frozenset())
                elif origin.kind == "storage":
                    if () not in actual.stores:
                        raise Rejected("storage source is not an owning place")
                    output.flows[out] = output.flows.get(out, frozenset()) | frozenset(
                        {actual.stores[()]}
                    )
                else:
                    raise Rejected("unexportable origin")
        for obligation in self.obligations:
            callback = args[obligation.callback].callback
            source = (
                args[obligation.source.parameter]
                .project(obligation.source.path)
                .stores.get(())
            )
            if callback is None or source is None:
                raise Rejected("unsupported callback/source substitution")
            output.obligations |= frozenset(
                {Obligation(callback, source, obligation.mode)}
            )
        output.obligations |= frozenset(o for arg in args for o in arg.obligations)
        return output

    def raw(self, intern: bool = True) -> dict[str, Any]:
        sets: list[list[dict[str, Any]]] = []
        indices: dict[frozenset[Origin], int] = {}
        outputs = []
        for path, origins in sorted(self.flows.items()):
            if not origins:
                continue
            if not intern or origins not in indices:
                indices[origins] = len(sets)
                sets.append([origin_raw(o) for o in sorted(origins)])
            outputs.append({"path": list(path), "sources": indices[origins]})
        return {
            "name": self.name,
            "params": [p.raw() for p in self.params],
            "result": self.result.raw(),
            "source_sets": sets,
            "outputs": outputs,
            "callbacks": [
                {"callback": o.callback, "source": origin_raw(o.source), "mode": o.mode}
                for o in sorted(self.obligations)
            ],
            "may_return": self.productive,
        }


def origin_raw(origin: Origin) -> dict[str, Any]:
    return {
        "parameter": origin.parameter,
        "path": list(origin.path),
        "kind": origin.kind,
    }


def read_path(raw: Any) -> Path:
    if (
        not isinstance(raw, list)
        or any(not isinstance(x, str) for x in raw)
        or len(raw) > 32
    ):
        raise Rejected("invalid contract path")
    return tuple(raw)


def read_origin(raw: Any, params: tuple[Param, ...]) -> Origin:
    if not isinstance(raw, dict) or set(raw) != {"parameter", "path", "kind"}:
        raise Rejected("invalid origin schema")
    i = raw["parameter"]
    if type(i) is not int or not 0 <= i < len(params):
        raise Rejected("origin parameter out of bounds")
    path = read_path(raw["path"])
    kind = raw["kind"]
    expected = {"storage": "bytes", "loan": "view", "prefix": "var"}
    if kind not in expected or params[i].ty.at(path).kind != expected[kind]:
        raise Rejected("origin kind/type mismatch")
    return Origin(i, path, kind)


def decode(raw: Any) -> dict[str, Summary]:
    if (
        not isinstance(raw, dict)
        or set(raw)
        != {"schema", "producer", "body_sha256", "imports_sha256", "functions"}
        or raw["schema"] != 1
    ):
        raise Rejected("invalid module contract schema")
    if not isinstance(raw["functions"], list) or len(raw["functions"]) > 10000:
        raise Rejected("invalid module function count")
    result: dict[str, Summary] = {}
    for f in raw["functions"]:
        if set(f) != {
            "name",
            "params",
            "result",
            "source_sets",
            "outputs",
            "callbacks",
            "may_return",
        }:
            raise Rejected("invalid function contract schema")
        if not isinstance(f["name"], str) or not f["name"] or f["name"] in result:
            raise Rejected("invalid or duplicate function name")
        if type(f["may_return"]) is not bool:
            raise Rejected("invalid productivity flag")
        params = tuple(Param.parse(p) for p in f["params"])
        ty = Ty.parse(f["result"])
        if any(t.kind in {"bytes", "callback"} for _, t in ty.leaves()):
            raise Rejected("owning/callback outputs are unsupported")
        sets = [
            frozenset(read_origin(o, params) for o in group)
            for group in f["source_sets"]
        ]
        flows: dict[Path, frozenset[Origin]] = {}
        for item in f["outputs"]:
            if set(item) != {"path", "sources"}:
                raise Rejected("invalid output route")
            path = read_path(item["path"])
            index = item["sources"]
            if type(index) is not int or not 0 <= index < len(sets) or path in flows:
                raise Rejected("bad source-set reference or duplicate route")
            out_ty = ty.at(path)
            for origin in sets[index]:
                source_ty = params[origin.parameter].ty.at(origin.path)
                if origin.kind == "prefix":
                    if out_ty.kind != "var" or out_ty != source_ty:
                        raise Rejected("generic prefix output mismatch")
                elif out_ty.kind != "view":
                    raise Rejected("view route output mismatch")
            flows[path] = sets[index]
        if f["may_return"]:
            for path, leaf in ty.leaves():
                if (
                    "*" not in path
                    and leaf.kind in {"view", "var"}
                    and not flows.get(path)
                ):
                    raise Rejected("missing non-container result provenance")
        obligations = set()
        for item in f["callbacks"]:
            if set(item) != {"callback", "source", "mode"}:
                raise Rejected("invalid callback requirement")
            index = item["callback"]
            if (
                type(index) is not int
                or not 0 <= index < len(params)
                or params[index].ty.kind != "callback"
            ):
                raise Rejected("invalid callback parameter")
            source = read_origin(item["source"], params)
            if source.kind != "storage" or item["mode"] not in {"read", "modify"}:
                raise Rejected("invalid scoped callback source/access")
            if item["mode"] == "modify" and params[source.parameter].mode != "modify":
                raise Rejected("callback modifies a read-only input")
            obligations.add(Obligation(index, source, item["mode"]))
        if obligations and ty.kind != "unit":
            raise Rejected("effectful callback/result combination unsupported")
        result[f["name"]] = Summary(
            f["name"], params, ty, flows, frozenset(obligations), f["may_return"]
        )
    return result


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
