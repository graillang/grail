"""Concrete sequence/record interpreter. Does not import dependency transformers or inference."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from typing import Any

from research.experiments.contracts02.model import Ty, unify


@dataclass(frozen=True, order=True)
class Token:
    owner: str
    generation: int = 0


@dataclass(frozen=True)
class Concrete:
    ty: Ty
    data: Any

    def project(self, parts: tuple[str, ...]) -> Concrete:
        result = self
        for part in parts:
            result = result.data[part]
        return result

    def assign(self, parts: tuple[str, ...], replacement: Concrete) -> Concrete:
        if not parts:
            assert self.ty == replacement.ty
            return replacement
        name, *rest = parts
        fields = dict(self.data)
        fields[name] = fields[name].assign(tuple(rest), replacement)
        return Concrete(self.ty, fields)


def make(ty: Ty, label: str, size: int) -> Concrete:
    if ty.kind == "view":
        return Concrete(ty, Token(label))
    if ty.kind == "unit":
        return Concrete(ty, None)
    if ty.kind == "record":
        return Concrete(
            ty,
            {name: make(child, f"{label}.{name}", size) for name, child in ty.fields},
        )
    if ty.kind == "list":
        assert ty.inner is not None
        return Concrete(
            ty, tuple(make(ty.inner, f"{label}[{i}]", size) for i in range(size))
        )
    raise AssertionError(f"not concrete: {ty}")


def observe(value: Concrete) -> dict[tuple[str, ...], frozenset[Token]]:
    if value.ty.kind == "unit":
        return {}
    if value.ty.kind == "view":
        return {(): frozenset({value.data})}
    result: dict[tuple[str, ...], frozenset[Token]] = {}
    children = (
        value.data.items()
        if value.ty.kind == "record"
        else (("*", item) for item in value.data)
    )
    for prefix, child in children:
        for suffix, roots in observe(child).items():
            path = (prefix,) + suffix
            result[path] = result.get(path, frozenset()) | roots
    return result


def plain_copy(ty: Ty) -> bool:
    return ty.kind in {"view", "unit"} or (
        ty.kind == "record" and all(plain_copy(t) for _, t in ty.fields)
    )


@dataclass
class Frame:
    args: list[Concrete | None]
    locals: dict[str, Concrete]
    types: dict[str, Ty]

    def get(self, place: Any) -> Concrete:
        value = (
            self.args[place["arg"]] if "arg" in place else self.locals[place["local"]]
        )
        assert value is not None
        return value.project(tuple(place.get("path", [])))

    def put(self, place: Any, value: Concrete) -> None:
        if "arg" in place:
            index = place["arg"]
            original = self.args[index]
            assert original is not None
            self.args[index] = original.assign(tuple(place.get("path", [])), value)
        else:
            name = place["local"]
            self.locals[name] = self.locals[name].assign(
                tuple(place.get("path", [])), value
            )

    def expression(self, expr: Any) -> Concrete:
        if "unit" in expr:
            return Concrete(Ty("unit"), None)
        if "empty" in expr:
            ty = Ty.parse(expr["empty"]).substitute(self.types)
            return make(ty, "never-used", 0)
        if "record" in expr:
            fields = {k: self.expression(v) for k, v in expr["record"].items()}
            ty = Ty.parse({"record": {k: v.ty.raw() for k, v in fields.items()}})
            return Concrete(ty, fields)
        place = expr.get("move", expr.get("read"))
        value = self.get(place)
        if "move" in expr and not plain_copy(value.ty):
            assert not place.get("path")
            if "arg" in place:
                self.args[place["arg"]] = None
            else:
                del self.locals[place["local"]]
        return value


def run(
    definition: Any,
    actuals: list[Concrete],
    definitions: dict[str, Any],
    choices: Iterator[bool],
) -> tuple[Concrete, dict[int, Concrete]]:
    types = {}
    for param, value in zip(definition["params"], actuals, strict=True):
        unify(Ty.parse(param["type"]), value.ty, types)
    frame = Frame(list(actuals), {}, types)

    def steps(body: list[Any]) -> None:
        for instruction in body:
            op = instruction["op"]
            if op == "let":
                frame.locals[instruction["name"]] = frame.expression(
                    instruction["value"]
                )
            elif op == "clear":
                old = frame.get(instruction["target"])
                frame.put(instruction["target"], Concrete(old.ty, ()))
            elif op == "append":
                old = frame.get(instruction["target"])
                new = frame.expression(instruction["value"])
                frame.put(instruction["target"], Concrete(old.ty, (*old.data, new)))
            elif op in {"replace", "take_all"}:
                old = frame.get(instruction["target"])
                new = (
                    frame.expression(instruction["value"])
                    if op == "replace"
                    else Concrete(old.ty, ())
                )
                frame.put(instruction["target"], new)
                frame.locals[instruction["dest"]] = old
            elif op == "swap":
                a, b = frame.get(instruction["left"]), frame.get(instruction["right"])
                frame.put(instruction["left"], b)
                frame.put(instruction["right"], a)
            elif op == "branch":
                steps(instruction["then"] if next(choices) else instruction["else"])
            elif op == "call":
                callee = definitions[instruction["fn"]]
                arguments = [
                    frame.get(a["place"])
                    if "place" in a
                    else frame.expression(a["value"])
                    for a in instruction["args"]
                ]
                result, updates = run(callee, arguments, definitions, choices)
                for i, updated in updates.items():
                    frame.put(instruction["args"][i]["place"], updated)
                frame.locals[instruction["dest"]] = result
            else:
                raise AssertionError(f"unknown oracle instruction: {op}")

    steps(definition["body"])
    result = frame.expression(definition["return"])
    post = {}
    for i, param in enumerate(definition["params"]):
        if param["mode"] == "mut":
            value = frame.args[i]
            assert value is not None
            post[i] = value
    assert result.ty == Ty.parse(definition["result"]).substitute(types)
    return result, post


def branches(definition: Any, definitions: dict[str, Any]) -> int:
    def count(body: list[Any]) -> int:
        total = 0
        for instruction in body:
            if instruction["op"] == "branch":
                total += 1 + count(instruction["then"]) + count(instruction["else"])
            elif instruction["op"] == "call":
                total += branches(definitions[instruction["fn"]], definitions)
        return total

    return count(definition["body"])


def client_trace(
    case: Any, definitions: dict[str, Any], choices: Iterator[bool]
) -> bool:
    """Execute concrete calls and generation invalidations; check validity at call/use boundaries."""

    def initial(raw: Any) -> Concrete:
        roots = {tuple(row["path"]): row["roots"] for row in raw["flows"]}

        def build(ty: Ty, prefix: tuple[str, ...] = ()) -> Concrete:
            if ty.kind == "unit":
                return Concrete(ty, None)
            if ty.kind == "view":
                assert len(roots[prefix]) == 1
                owner, gen = roots[prefix][0].rsplit("#", 1)
                return Concrete(ty, Token(owner, int(gen)))
            if ty.kind == "record":
                return Concrete(
                    ty, {key: build(child, prefix + (key,)) for key, child in ty.fields}
                )
            assert ty.kind == "list" and ty.inner is not None
            element = prefix + ("*",)
            present = any(
                p[: len(element)] == element and values for p, values in roots.items()
            )
            return Concrete(ty, (build(ty.inner, element),) if present else ())

        return build(Ty.parse(raw["type"]))

    storage = {name: initial(raw) for name, raw in case["initial"].items()}
    generations: dict[str, int] = {}

    def valid(value: Concrete) -> bool:
        return all(
            generations.get(token.owner, 0) == token.generation
            for tokens in observe(value).values()
            for token in tokens
        )

    for action in case["actions"]:
        if "call" in action:
            fn = definitions[action["call"]]
            places = [(a["slot"], tuple(a.get("path", []))) for a in action["args"]]
            actuals = [storage[slot].project(parts) for slot, parts in places]
            if not all(valid(value) for value in actuals):
                return False
            permissions = [
                p["mode"] if p["mode"] != "take" or not plain_copy(v.ty) else "copy"
                for p, v in zip(fn["params"], actuals, strict=True)
            ]
            for i, (slot, parts) in enumerate(places):
                for j in range(i + 1, len(places)):
                    other_slot, other_parts = places[j]
                    common = min(len(parts), len(other_parts))
                    modes = {permissions[i], permissions[j]}
                    if (
                        slot == other_slot
                        and parts[:common] == other_parts[:common]
                        and "copy" not in modes
                        and modes & {"mut", "take"}
                    ):
                        return False
            result, posts = run(fn, actuals, definitions, choices)
            for i, mode in enumerate(permissions):
                if mode == "take":
                    slot, parts = places[i]
                    assert not parts
                    del storage[slot]
            for i, value in posts.items():
                slot, parts = places[i]
                storage[slot] = storage[slot].assign(parts, value)
            if action.get("dest") is not None:
                storage[action["dest"]] = result
        elif "drop" in action:
            del storage[action["drop"]]
        elif "source" in action:
            owner = action["owner"]
            storage[action["source"]] = Concrete(
                Ty("view"), Token(owner, generations.get(owner, 0))
            )
        elif "end" in action:
            owner = action["end"]
            generations[owner] = generations.get(owner, 0) + 1
        elif "use" in action:
            if not valid(storage[action["use"]]):
                return False
        else:
            raise AssertionError("unknown concrete client operation")
    return True
