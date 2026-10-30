"""Infer state transformers from a small, acyclic view-data procedure IR."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from research.experiments.contracts02.model import Rejected, Ty, overlap
from research.experiments.transforms05.contract import Contract, Parameter, decode, path
from research.experiments.transforms05.value import (
    Pre,
    Value,
    copyable,
    data_type,
    entry,
    join,
)


@dataclass
class State:
    params: tuple[Parameter, ...]
    args: list[Value[Pre] | None]
    locals: dict[str, Value[Pre]]

    def clone(self) -> State:
        return State(self.params, self.args.copy(), self.locals.copy())

    def place(
        self, raw: Any, write: bool = False
    ) -> tuple[str, int | str, tuple[str, ...]]:
        if (
            not isinstance(raw, dict)
            or set(raw) - {"arg", "local", "path"}
            or ("arg" in raw) == ("local" in raw)
        ):
            raise Rejected("invalid place")
        parts = path(raw.get("path", []))
        if "*" in parts:
            raise Rejected("indexed/heap writes are outside the exact-place fragment")
        if "arg" in raw:
            index = raw["arg"]
            if (
                type(index) is not int
                or not 0 <= index < len(self.args)
                or self.args[index] is None
            ):
                raise Rejected("unknown/moved argument")
            if write and self.params[index].mode not in {"mut", "take"}:
                raise Rejected("write through a read parameter")
            return "arg", index, parts
        name = raw["local"]
        if name not in self.locals:
            raise Rejected("unknown/moved local")
        return "local", name, parts

    def read(self, place: tuple[str, int | str, tuple[str, ...]]) -> Value[Pre]:
        kind, key, parts = place
        value = self.args[int(key)] if kind == "arg" else self.locals[str(key)]
        if value is None:
            raise Rejected("moved value")
        return value.project(parts)

    def write(
        self, place: tuple[str, int | str, tuple[str, ...]], value: Value[Pre]
    ) -> None:
        kind, key, parts = place
        current = self.args[int(key)] if kind == "arg" else self.locals[str(key)]
        if current is None:
            raise Rejected("moved destination")
        new = current.assign(parts, value)
        if kind == "arg":
            self.args[int(key)] = new
        else:
            self.locals[str(key)] = new

    def expression(self, raw: Any) -> Value[Pre]:
        if not isinstance(raw, dict) or len(raw) != 1:
            raise Rejected("invalid value expression")
        op, value = next(iter(raw.items()))
        if op in {"read", "move"}:
            place = self.place(value)
            result = self.read(place)
            if op == "read" and not copyable(result.ty):
                raise Rejected("noncopyable/opaque value must be moved")
            if op == "move" and not copyable(result.ty):
                kind, key, parts = place
                if parts:
                    raise Rejected("partial moves outside this fragment")
                if kind == "arg":
                    if self.params[int(key)].mode != "take":
                        raise Rejected("moving out of a borrowed parameter")
                    self.args[int(key)] = None
                else:
                    del self.locals[str(key)]
            return result
        if op == "unit" and value is True:
            return Value(Ty("unit"))
        if op == "empty":
            ty = Ty.parse(value)
            data_type(ty)
            if any(t.kind in {"view", "var"} and "*" not in p for p, t in ty.leaves()):
                raise Rejected("cannot fabricate a nonempty view/opaque value")
            return Value(ty)
        if op == "record" and isinstance(value, dict):
            fields = {k: self.expression(v) for k, v in sorted(value.items())}
            ty = Ty.parse({"record": {k: v.ty.raw() for k, v in fields.items()}})
            return Value(
                ty,
                {
                    (k,) + p: roots
                    for k, v in fields.items()
                    for p, roots in v.flows.items()
                },
            )
        raise Rejected("unsupported expression")


def disjoint(places: list[tuple[str, int | str, tuple[str, ...], str]]) -> None:
    for i, (kind, root, parts, mode) in enumerate(places):
        for other_kind, other_root, other_parts, other_mode in places[i + 1 :]:
            if (
                (kind, root) == (other_kind, other_root)
                and overlap(parts, other_parts)
                and ("mut" in {mode, other_mode} or "take" in {mode, other_mode})
            ):
                raise Rejected("overlapping call access/move permissions")


def merge_states(a: State, b: State) -> State:
    args = [
        join(x, y) if x is not None and y is not None else None
        for x, y in zip(a.args, b.args, strict=True)
    ]
    locals_ = {
        name: join(a.locals[name], b.locals[name])
        for name in a.locals.keys() & b.locals.keys()
    }
    return State(a.params, args, locals_)


def execute(
    body: list[Any],
    state: State,
    contracts: dict[str, Contract],
    budget: list[int],
    depth: int = 0,
) -> State:
    if depth > 32:
        raise Rejected("branch nesting budget exhausted")
    for instruction in body:
        budget[0] -= 1
        if budget[0] < 0 or not isinstance(instruction, dict):
            raise Rejected("instruction budget exhausted or invalid instruction")
        op = instruction.get("op")
        if op == "let" and set(instruction) == {"op", "name", "value"}:
            name = instruction["name"]
            if name in state.locals:
                raise Rejected("duplicate local")
            state.locals[name] = state.expression(instruction["value"])
        elif op == "clear" and set(instruction) == {"op", "target"}:
            target = state.place(instruction["target"], write=True)
            current = state.read(target)
            if current.ty.kind != "list":
                raise Rejected("clear requires a sequence")
            state.write(target, Value(current.ty))
        elif op == "append" and set(instruction) == {"op", "target", "value"}:
            target = state.place(instruction["target"], write=True)
            current = state.read(target)
            value = state.expression(instruction["value"])
            if current.ty.kind != "list" or current.ty.inner != value.ty:
                raise Rejected("append payload mismatch")
            state.write(target, join(current, value.prefixed(("*",), current.ty)))
        elif op in {"replace", "take_all"}:
            expected = {"op", "target", "dest"} | (
                {"value"} if op == "replace" else set()
            )
            if set(instruction) != expected or instruction["dest"] in state.locals:
                raise Rejected("invalid replace/move-out")
            target = state.place(instruction["target"], write=True)
            old = state.read(target)
            if op == "replace":
                new = state.expression(instruction["value"])
            else:
                if old.ty.kind != "list":
                    raise Rejected("take_all requires a sequence")
                new = Value(old.ty)
            state.write(target, new)
            state.locals[instruction["dest"]] = old
        elif op == "swap" and set(instruction) == {"op", "left", "right"}:
            left = state.place(instruction["left"], write=True)
            right = state.place(instruction["right"], write=True)
            disjoint([(*left, "mut"), (*right, "mut")])
            old_left, old_right = state.read(left), state.read(right)
            state.write(left, old_right)
            state.write(right, old_left)
        elif op == "branch" and set(instruction) == {"op", "then", "else"}:
            state = merge_states(
                execute(
                    instruction["then"], state.clone(), contracts, budget, depth + 1
                ),
                execute(
                    instruction["else"], state.clone(), contracts, budget, depth + 1
                ),
            )
        elif op == "call" and set(instruction) == {"op", "fn", "args", "dest"}:
            contract = contracts.get(instruction["fn"])
            if (
                contract is None
                or len(instruction["args"]) != len(contract.params)
                or instruction["dest"] in state.locals
            ):
                raise Rejected("unknown/invalid callee")
            actuals = []
            reservations = []
            targets = {}
            for i, (param, raw) in enumerate(
                zip(contract.params, instruction["args"], strict=True)
            ):
                if param.mode in {"read", "mut"}:
                    if set(raw) != {"place"}:
                        raise Rejected("access argument needs a place")
                    target = state.place(raw["place"], write=param.mode == "mut")
                    actuals.append(state.read(target))
                    reservations.append((*target, param.mode))
                    if param.mode == "mut":
                        targets[i] = target
                else:
                    if set(raw) != {"value"}:
                        raise Rejected("take argument needs a value")
                    expr = raw["value"]
                    if isinstance(expr, dict) and set(expr) == {"move"}:
                        target = state.place(expr["move"])
                        if not copyable(state.read(target).ty):
                            reservations.append((*target, "take"))
                    actuals.append(state.expression(expr))
            disjoint(reservations)
            result, posts = contract.apply(actuals)
            for i, value in posts.items():
                state.write(targets[i], value)
            state.locals[instruction["dest"]] = result
        else:
            raise Rejected(f"unsupported instruction: {op}")
    return state


def infer(raw: dict[str, Any], imports: dict[str, Contract] | None = None) -> Contract:
    if set(raw) != {"name", "params", "result", "body", "return"} or not isinstance(
        raw["body"], list
    ):
        raise Rejected("invalid procedure IR")
    params = tuple(Parameter.parse(p) for p in raw["params"])
    result_type = Ty.parse(raw["result"])
    data_type(result_type)
    state = execute(
        raw["body"],
        State(params, [entry(i, p.ty) for i, p in enumerate(params)], {}),
        imports or {},
        [10000],
    )
    result = state.expression(raw["return"])
    if result.ty != result_type:
        raise Rejected("declared result shape mismatch")
    post = {}
    for i, param in enumerate(params):
        if param.mode == "mut":
            if state.args[i] is None:
                raise Rejected("mutable argument consumed")
            post[i] = state.args[i]
    contract = Contract(raw["name"], params, result, post)
    decode({"schema": 1, "contracts": [contract.raw()]})
    return contract
