"""Structured dependency values; no program bodies or inference."""

from __future__ import annotations

from collections.abc import Hashable
from dataclasses import dataclass, field
from typing import Generic, TypeVar

from research.experiments.contracts02.model import Path, Rejected, Ty, unify

Atom = TypeVar("Atom", bound=Hashable)


def data_type(ty: Ty) -> None:
    if ty.kind not in {"unit", "view", "record", "list", 'mut'}:
        raise Rejected("type outside the shared view-data experiment")
    for _, child in ty.fields:
        data_type(child)
    if ty.inner is not None:
        data_type(ty.inner)


def copyable(ty: Ty) -> bool:
    if ty.kind in {"unit", "view"}:
        return True
    return ty.kind == "record" and all(copyable(t) for _, t in ty.fields)


@dataclass(frozen=True, order=True)
class Pre:
    argument: int
    path: Path
    tail: bool = False


@dataclass
class Value(Generic[Atom]):
    ty: Ty
    flows: dict[Path, frozenset[Atom]] = field(default_factory=dict)

    def project(self, path: Path) -> Value[Atom]:
        length = len(path)
        return Value(
            self.ty.at(path),
            {p[length:]: q for p, q in self.flows.items() if p[:length] == path},
        )

    def assign(self, path: Path, value: Value[Atom]) -> Value[Atom]:
        if self.ty.at(path) != value.ty:
            raise Rejected("assignment changes the base shape")
        length = len(path)
        keep = {p: q for p, q in self.flows.items() if p[:length] != path}
        keep.update({path + p: q for p, q in value.flows.items()})
        return Value(self.ty, keep)

    def prefixed(self, prefix: Path, ty: Ty) -> Value[Atom]:
        return Value(ty, {prefix + p: q for p, q in self.flows.items()})


def entry(index: int, ty: Ty) -> Value[Pre]:
    data_type(ty)
    return Value(
        ty,
        {
            p: frozenset({Pre(index, p, t.kind == 'mut')})
            for p, t in ty.leaves()
            if t.kind in {"view", 'mut'}
        },
    )


def join(a: Value[Atom], b: Value[Atom]) -> Value[Atom]:
    if a.ty != b.ty:
        raise Rejected("branch/base shape mismatch")
    return Value(
        a.ty,
        {
            p: a.flows.get(p, frozenset()) | b.flows.get(p, frozenset())
            for p in a.flows.keys() | b.flows.keys()
        },
    )


def instantiate(
    symbolic: Value[Pre], actuals: list[Value[Atom]], bindings: dict[str, Ty]
) -> Value[Atom]:
    result: Value[Atom] = Value(symbolic.ty.substitute(bindings))
    for output, sources in symbolic.flows.items():
        for source in sources:
            value = actuals[source.argument].project(source.path)
            if source.tail:
                for suffix, roots in value.flows.items():
                    key = output + suffix
                    result.flows[key] = result.flows.get(key, frozenset()) | roots
            else:
                result.flows[output] = result.flows.get(
                    output, frozenset()
                ) | value.flows.get((), frozenset())
    return result


def bindings_for(formals: list[Ty], actuals: list[Value[Atom]]) -> dict[str, Ty]:
    if len(formals) != len(actuals):
        raise Rejected("wrong argument count")
    bindings: dict[str, Ty] = {}
    for expected, actual in zip(formals, actuals, strict=True):
        data_type(actual.ty)
        unify(expected, actual.ty, bindings)
    return bindings
