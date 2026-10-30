"""Finite concrete dependency semantics, independent of inference/route composition.

This enumerates source choices and bounded recursive calls, NOT program values or machine memory.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import islice, product
from typing import Any

from contracts import Summary
from model import Info, Origin, Path, Rejected, Ty


@dataclass(frozen=True)
class Concrete:
    ty: Ty
    atom: str = ""
    children: tuple[Concrete, ...] = ()
    leaf: bool = False

    def project(self, path: Path) -> list[Concrete]:
        if not path:
            return [self]
        head, *tail = path
        if self.ty.kind in {"record", "capture"}:
            keys = [k for k, _ in self.ty.fields]
            return self.children[keys.index(head)].project(tuple(tail))
        if head == "*" and self.ty.kind in {"list", "tree"}:
            return [r for v in self.payloads() for r in v.project(tuple(tail))]
        raise Rejected("concrete projection mismatch")

    def payloads(self) -> list[Concrete]:
        if self.ty.kind == "list":
            return list(self.children)
        if self.ty.kind == "tree":
            if self.leaf:
                return list(self.children)
            return [x for child in self.children for x in child.payloads()]
        raise Rejected("not a concrete container")

    def dependencies(self, prefix: Path = ()) -> dict[Path, set[str]]:
        if self.ty.kind == "view":
            return {prefix: {self.atom}}
        result: dict[Path, set[str]] = {}
        if self.ty.kind in {"record", "capture"}:
            parts = [
                (prefix + (key,), child)
                for (key, _), child in zip(self.ty.fields, self.children, strict=True)
            ]
        elif self.ty.kind in {"tree", "list"}:
            parts = [(prefix + ("*",), child) for child in self.payloads()]
        else:
            parts = []
        for path, child in parts:
            for key, sources in child.dependencies(path).items():
                result.setdefault(key, set()).update(sources)
        return result

    def storage(self, prefix: Path = ()) -> dict[Path, str]:
        if self.ty.kind == "bytes":
            return {prefix: self.atom}
        if self.ty.kind in {"record", "capture"}:
            return {
                p: atom
                for (key, _), child in zip(self.ty.fields, self.children, strict=True)
                for p, atom in child.storage(prefix + (key,)).items()
            }
        return {}


def materialize(ty: Ty, label: str) -> Concrete:
    if ty.kind in {"view", "bytes"}:
        return Concrete(ty, label)
    if ty.kind in {"record", "capture"}:
        return Concrete(
            ty, children=tuple(materialize(t, label + "." + k) for k, t in ty.fields)
        )
    if ty.kind in {"list", "tree"}:
        assert ty.inner is not None
        payloads = tuple(materialize(ty.inner, label + f"[{i}]") for i in range(2))
        if ty.kind == "list":
            return Concrete(ty, children=payloads)
        return Concrete(
            ty, children=tuple(Concrete(ty, children=(v,), leaf=True) for v in payloads)
        )
    if ty.kind in {"unit", "callback"}:
        return Concrete(ty)
    raise Rejected("oracle requires ground input types")


class Semantics:
    def __init__(self, definitions: list[dict[str, Any]], cap: int = 256):
        self.functions = {f["name"]: f for f in definitions}
        self.cap = cap
        self.recursion_cutoffs = 0
        self.truncated_products = 0

    def combinations(self, lists: list[list[Concrete]]) -> list[tuple[Concrete, ...]]:
        combinations = list(islice(product(*lists), self.cap + 1))
        if len(combinations) > self.cap:
            self.truncated_products += 1
        return combinations[: self.cap]

    def call(self, name: str, args: list[Concrete], fuel: int) -> list[Concrete]:
        if fuel == 0:
            self.recursion_cutoffs += 1
            return []
        return self.expression(self.functions[name]["body"], args, fuel - 1)

    def expression(
        self, expr: dict[str, Any], env: list[Concrete], fuel: int
    ) -> list[Concrete]:
        op, value = next(iter(expr.items()))
        if op == "param":
            return [env[value]]
        if op == "unit":
            return [Concrete(Ty("unit"))]
        if op == "local_view":
            return [Concrete(Ty("view"), "LOCAL:" + value)]
        if op == "get":
            return [
                r
                for v in self.expression(value["value"], env, fuel)
                for r in v.project(tuple(value["path"]))
            ]
        if op == "borrow":
            return [
                Concrete(Ty("view"), v.atom) for v in self.expression(value, env, fuel)
            ]
        if op == "choice":
            return list(
                dict.fromkeys(
                    r for child in value for r in self.expression(child, env, fuel)
                )
            )
        if op in {"record", "capture"}:
            entries = sorted(value.items())
            variants = [self.expression(v, env, fuel) for _, v in entries]
            return [
                Concrete(
                    Ty(
                        op,
                        tuple((k, v.ty) for (k, _), v in zip(entries, vs, strict=True)),
                    ),
                    children=vs,
                )
                for vs in self.combinations(variants)
            ]
        if op == "tree_leaf":
            return [
                Concrete(Ty("tree", inner=v.ty), children=(v,), leaf=True)
                for v in self.expression(value, env, fuel)
            ]
        if op in {"list", "tree_branch"}:
            ty = Ty(
                "list" if op == "list" else "tree", inner=Ty.parse(value["element"])
            )
            variants = [self.expression(v, env, fuel) for v in value["items"]]
            return [Concrete(ty, children=vs) for vs in self.combinations(variants)]
        if op == "leaves":
            return [
                Concrete(Ty("list", inner=v.ty.inner), children=tuple(v.payloads()))
                for v in self.expression(value, env, fuel)
            ]
        if op == "call":
            variants = [self.expression(v, env, fuel) for v in value["args"]]
            return list(
                dict.fromkeys(
                    r
                    for vs in self.combinations(variants)
                    for r in self.call(value["fn"], list(vs), fuel)
                )
            )
        if op == "visit":
            return [Concrete(Ty("unit"))]
        raise Rejected("unsupported oracle operation")


def check(
    definitions: list[dict[str, Any]], summaries: dict[str, Summary], *, fuel: int = 8
) -> dict[str, Any]:
    semantics = Semantics(definitions)
    labels: dict[str, int] = {}

    def label(name: str) -> Origin:
        return Origin(labels.setdefault(name, len(labels)), (), "storage")

    returned = 0
    failures = []
    no_results = []
    ground_types = [
        Ty("view"),
        Ty.parse({"record": {"a": "view", "b": {"list": "view"}}}),
        Ty.parse({"capture": {"source": "view"}}),
        Ty.parse({"tree": "view"}),
    ]
    for f in definitions:
        if Ty.parse(f["result"]).kind == "unit":
            continue  # Scoped-callback protocol tested by separate client tests, not this oracle.
        generic = any(
            t.kind == "var"
            for p in f["params"]
            for _, t in Ty.parse(p["type"]).leaves()
        )
        for ground in ground_types if generic else [Ty("unit")]:
            inputs = [
                materialize(Ty.parse(p["type"]).substitute({"T": ground}), f"arg{i}")
                for i, p in enumerate(f["params"])
            ]
            actuals = [
                Info(
                    v.ty,
                    {
                        p: frozenset(label(s) for s in sources)
                        for p, sources in v.dependencies().items()
                    },
                    {p: label(atom) for p, atom in v.storage().items()},
                )
                for v in inputs
            ]
            abstract = summaries[f["name"]].apply(actuals)
            outputs = semantics.call(f["name"], inputs, fuel)
            if not outputs:
                no_results.append(f["name"])
            for output in outputs:
                returned += 1
                if output.ty != abstract.ty:
                    failures.append(
                        {"function": f["name"], "reason": "output shape mismatch"}
                    )
                for path, sources in output.dependencies().items():
                    expected = {label(s) for s in sources}
                    if not expected <= abstract.flows.get(path, frozenset()):
                        failures.append(
                            {
                                "function": f["name"],
                                "path": list(path),
                                "sources": sorted(sources),
                            }
                        )
    return {
        "concrete_returns_checked": returned,
        "failures": failures,
        "no_results": no_results,
        "recursive_fuel_cutoffs": semantics.recursion_cutoffs,
        "truncated_cartesian_products": semantics.truncated_products,
        "fuel": fuel,
    }
