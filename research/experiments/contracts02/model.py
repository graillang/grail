"""Types and symbolic provenance for a deliberately restricted research IR."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

Path = tuple[str, ...]


class Rejected(ValueError):
    """A typed-IR or client program is outside the accepted fragment."""


@dataclass(frozen=True)
class Ty:
    kind: str
    fields: tuple[tuple[str, Ty], ...] = ()
    inner: Ty | None = None
    name: str = ""

    @staticmethod
    def parse(raw: Any, depth: int = 0) -> Ty:
        if depth > 32:
            raise Rejected("type nesting exceeds research budget")
        if isinstance(raw, str) and raw in {"bytes", "view", "unit", "callback"}:
            return Ty(raw)
        if not isinstance(raw, dict) or len(raw) != 1:
            raise Rejected(f"unsupported type: {raw!r}")
        kind, value = next(iter(raw.items()))
        if kind in {"record", "capture"} and isinstance(value, dict):
            if any(not isinstance(k, str) or k in {"", "*"} for k in value):
                raise Rejected("invalid field name")
            return Ty(
                kind,
                tuple((k, Ty.parse(v, depth + 1)) for k, v in sorted(value.items())),
            )
        if kind in {"list", "tree"}:
            return Ty(kind, inner=Ty.parse(value, depth + 1))
        if kind == "var" and isinstance(value, str) and value:
            return Ty(kind, name=value)
        raise Rejected(f"unsupported type: {raw!r}")

    def raw(self) -> Any:
        if self.kind in {"record", "capture"}:
            return {self.kind: {k: v.raw() for k, v in self.fields}}
        if self.kind in {"list", "tree"}:
            assert self.inner is not None
            return {self.kind: self.inner.raw()}
        if self.kind == "var":
            return {"var": self.name}
        return self.kind

    def leaves(self, path: Path = ()) -> list[tuple[Path, Ty]]:
        if self.kind in {"record", "capture"}:
            return [(p, t) for k, v in self.fields for p, t in v.leaves(path + (k,))]
        if self.kind in {"list", "tree"}:
            assert self.inner is not None
            return self.inner.leaves(path + ("*",))
        return [(path, self)]

    def at(self, path: Path) -> Ty:
        value = self
        for part in path:
            if value.kind in {"record", "capture"}:
                entries = dict(value.fields)
                if part not in entries:
                    raise Rejected(f"unknown field {part}")
                value = entries[part]
            elif value.kind in {"list", "tree"} and part == "*":
                assert value.inner is not None
                value = value.inner
            else:
                raise Rejected(f"cannot project {part} from {value.raw()}")
        return value

    def substitute(self, bindings: dict[str, Ty]) -> Ty:
        if self.kind == "var":
            return bindings.get(self.name, self)
        return Ty(
            self.kind,
            tuple((k, v.substitute(bindings)) for k, v in self.fields),
            self.inner.substitute(bindings) if self.inner else None,
            self.name,
        )


def unify(expected: Ty, actual: Ty, bindings: dict[str, Ty]) -> None:
    if expected.kind == "var":
        old = bindings.setdefault(expected.name, actual)
        if old != actual:
            raise Rejected("inconsistent generic argument")
        if any(t.kind in {"bytes", "callback"} for _, t in actual.leaves()):
            raise Rejected("generic owning/callback values are outside this fragment")
        return
    if expected.kind != actual.kind or [k for k, _ in expected.fields] != [
        k for k, _ in actual.fields
    ]:
        raise Rejected(f"type mismatch: {expected.raw()} vs {actual.raw()}")
    for (_, x), (_, y) in zip(expected.fields, actual.fields, strict=True):
        unify(x, y, bindings)
    if expected.inner is not None:
        if actual.inner is None:
            raise Rejected("missing container payload")
        unify(expected.inner, actual.inner, bindings)


@dataclass(frozen=True, order=True)
class Origin:
    parameter: int
    path: Path
    kind: str


@dataclass(frozen=True, order=True)
class Obligation:
    callback: int
    source: Origin
    mode: str


@dataclass
class Info:
    ty: Ty
    flows: dict[Path, frozenset[Origin]] = field(default_factory=dict)
    stores: dict[Path, Origin] = field(default_factory=dict)
    callback: int | None = None
    obligations: frozenset[Obligation] = frozenset()
    productive: bool = True

    @staticmethod
    def parameter(index: int, ty: Ty) -> Info:
        result = Info(ty, callback=index if ty.kind == "callback" else None)
        for path, leaf in ty.leaves():
            if leaf.kind in {"view", "var"}:
                result.flows[path] = frozenset(
                    {Origin(index, path, "prefix" if leaf.kind == "var" else "loan")}
                )
            elif leaf.kind == "bytes":
                result.stores[path] = Origin(index, path, "storage")
            elif leaf.kind == "callback" and path:
                raise Rejected("nested callbacks are unsupported")
        return result

    def project(self, path: Path) -> Info:
        ty = self.ty.at(path)
        n = len(path)
        return Info(
            ty,
            {p[n:]: v for p, v in self.flows.items() if p[:n] == path},
            {p[n:]: v for p, v in self.stores.items() if p[:n] == path},
            self.callback if not path else None,
            self.obligations,
            self.productive,
        )


def merge(ty: Ty, values: list[Info]) -> Info:
    if any(v.ty != ty for v in values):
        raise Rejected("branch/container type mismatch")
    result = Info(ty, productive=any(v.productive for v in values))
    for value in values:
        if value.stores:
            raise Rejected("merge storage after borrowing it, not as owning values")
        result.obligations |= value.obligations
        for path, origins in value.flows.items():
            result.flows[path] = result.flows.get(path, frozenset()) | origins
    return result


def overlap(a: Path, b: Path) -> bool:
    return all(x == y or x == "*" or y == "*" for x, y in zip(a, b))
