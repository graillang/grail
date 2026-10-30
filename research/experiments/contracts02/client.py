"""Linear-client dependency/permission checker using contracts, never provider bodies."""

from __future__ import annotations

from collections import defaultdict
from typing import Any

from contracts import Summary
from model import Info, Origin, Path, Rejected, Ty, overlap


def uses(step: dict[str, Any]) -> list[tuple[str, Path]]:
    op = step.get("op")
    if op == "call":
        return [(a["var"], tuple(a.get("path", []))) for a in step["args"]]
    if op in {"use", "project"}:
        return [(step["var"], tuple(step.get("path", [])))]
    if op == "callback":
        return [(name, ()) for name in step["captures"]]
    return []


class Checker:
    def __init__(self, summaries: dict[str, Summary], steps: list[dict[str, Any]]):
        self.summaries = summaries
        self.steps = steps
        self.values: dict[str, Info] = {}
        self.defined: set[str] = set()
        self.root_names: dict[int, str] = {}
        self.alive: set[int] = set()
        self.callbacks: dict[int, dict[str, Any]] = {}
        self.future: dict[str, list[tuple[int, Path]]] = defaultdict(list)
        for index, step in enumerate(steps):
            for name, path in uses(step):
                self.future[name].append((index, path))

    def put(self, name: str, value: Info) -> None:
        if not isinstance(name, str) or name in self.defined:
            raise Rejected("client bindings must be fresh SSA names")
        self.defined.add(name)
        self.values[name] = value

    def value(self, arg: dict[str, Any]) -> Info:
        if set(arg) - {"var", "path"} or arg.get("var") not in self.values:
            raise Rejected("unknown client value or argument syntax")
        result = self.values[arg["var"]].project(tuple(arg.get("path", [])))
        for origin in [
            *result.stores.values(),
            *(o for v in result.flows.values() for o in v),
        ]:
            if origin.parameter not in self.alive:
                raise Rejected(
                    f"value refers to ended storage {self.root_names.get(origin.parameter)}"
                )
        return result

    def live(self, point: int) -> list[tuple[str, Path, Origin]]:
        result = []
        for name, value in self.values.items():
            future = [p for i, p in self.future[name] if i >= point]
            for path, origins in value.flows.items():
                if any(overlap(path, p) for p in future):
                    result.extend((name, path, origin) for origin in origins)
        return result

    def modification(self, origin: Origin, point: int) -> None:
        for name, path, loan in self.live(point):
            if loan.parameter == origin.parameter and overlap(loan.path, origin.path):
                owner = self.root_names[origin.parameter]
                raise Rejected(
                    f"Cannot modify/end {owner}: {name}.{dot(path)} still reads its storage; "
                    f"contract dependency points to {owner}.{dot(loan.path)}"
                )

    def callback_expr(
        self, expr: Any, locals_: dict[str, Info], captures: dict[str, Info]
    ) -> Info:
        if not isinstance(expr, dict) or len(expr) != 1:
            raise Rejected("invalid callback expression")
        op, value = next(iter(expr.items()))
        if op == "local" and value in locals_:
            return locals_[value]
        if op == "capture" and isinstance(value, str) and value in captures:
            return captures[value]
        if op == "unit" and value is True:
            return Info(Ty("unit"))
        if op in {"record", "captured"} and isinstance(value, dict):
            entries = {
                k: self.callback_expr(v, locals_, captures) for k, v in value.items()
            }
            ty = Ty.parse(
                {
                    "capture" if op == "captured" else "record": {
                        k: v.ty.raw() for k, v in entries.items()
                    }
                }
            )
            return Info(
                ty,
                {
                    (k,) + p: origins
                    for k, v in entries.items()
                    for p, origins in v.flows.items()
                },
            )
        if op == "call" and isinstance(value, dict) and set(value) == {"fn", "args"}:
            summary = self.summaries.get(value["fn"])
            if (
                summary is None
                or summary.obligations
                or any(p.mode == "modify" for p in summary.params)
            ):
                raise Rejected("nested callback effects unsupported")
            return summary.apply(
                [self.callback_expr(e, locals_, captures) for e in value["args"]]
            )
        raise Rejected("unsupported callback expression")

    def invoke(self, callback_id: int, source: Origin, mode: str) -> None:
        definition = self.callbacks.get(callback_id)
        if definition is None:
            raise Rejected("unknown callback")
        locals_ = {
            "item": Info(
                Ty("view"),
                {(): frozenset({Origin(source.parameter, source.path, "fresh")})},
            )
        }
        captures = definition["values"]
        for step in definition["body"]:
            op = step.get("op")
            if op == "let":
                if step["name"] in locals_:
                    raise Rejected("duplicate callback local")
                locals_[step["name"]] = self.callback_expr(
                    step["value"], locals_, captures
                )
            elif op in {"store", "return"}:
                value = self.callback_expr(step["value"], locals_, captures)
                if any(
                    o.kind == "fresh"
                    for origins in value.flows.values()
                    for o in origins
                ):
                    raise Rejected(
                        "Callback retains invocation-only item through a value/capture"
                    )
                if op == "store" or value.ty.kind != "unit":
                    raise Rejected("callback store/non-unit return outside fragment")
            elif op == "inspect":
                self.callback_expr(step["value"], locals_, captures)
            elif op == "write_item" and mode == "modify":
                pass
            else:
                raise Rejected(
                    "unsupported callback operation or write through read access"
                )

    def check(self) -> None:
        allowed = {
            "owner",
            "call",
            "project",
            "use",
            "invalidate",
            "end",
            "drop",
            "callback",
            "alias",
        }
        for point, step in enumerate(self.steps):
            op = step.get("op")
            if op not in allowed:
                raise Rejected(f"unsupported client operation: {op}")
            if op == "owner":
                ty = Ty.parse(step.get("type", "bytes"))
                if any(t.kind != "bytes" for _, t in ty.leaves()):
                    raise Rejected("owner declaration requires byte-storage fields")
                root = len(self.root_names)
                self.root_names[root] = step["name"]
                self.alive.add(root)
                self.put(
                    step["name"],
                    Info(
                        ty,
                        stores={p: Origin(root, p, "storage") for p, _ in ty.leaves()},
                    ),
                )
            elif op == "alias":
                self.put(step["name"], self.value({"var": step["of"]}))
            elif op in {"use", "project"}:
                value = self.value({"var": step["var"], "path": step.get("path", [])})
                if op == "project":
                    self.put(step["dest"], value)
            elif op == "drop":
                if step["var"] not in self.values:
                    raise Rejected("drop of unknown value")
                if self.values[step["var"]].stores:
                    raise Rejected(
                        "use end, not drop, to release owning storage in this fragment"
                    )
                del self.values[step["var"]]
            elif op in {"invalidate", "end"}:
                value = self.value({"var": step["owner"], "path": step.get("path", [])})
                if not value.stores:
                    raise Rejected("invalidation requires owning storage")
                for source in value.stores.values():
                    self.modification(source, point)
                if op == "end":
                    if step.get("path"):
                        raise Rejected("partial owner deallocation outside fragment")
                    self.alive.difference_update(
                        o.parameter for o in value.stores.values()
                    )
            elif op == "callback":
                captures = {
                    name: self.value({"var": name}) for name in step["captures"]
                }
                ident = len(self.callbacks)
                self.callbacks[ident] = {"body": step["body"], "values": captures}
                flows = {
                    ("$capture", name) + p: origins
                    for name, v in captures.items()
                    for p, origins in v.flows.items()
                }
                for name, value in captures.items():
                    for path, source in value.stores.items():
                        flows[("$capture", name) + path] = frozenset({source})
                self.put(step["name"], Info(Ty("callback"), flows, callback=ident))
            elif op == "call":
                summary = self.summaries.get(step["fn"])
                if summary is None or not summary.productive:
                    raise Rejected("unknown/nonreturning contract")
                args = [self.value(a) for a in step["args"]]
                result = summary.apply(args)
                footprints = []
                for index, (param, actual) in enumerate(
                    zip(summary.params, args, strict=True)
                ):
                    for origin in [
                        *actual.stores.values(),
                        *(o for v in actual.flows.values() for o in v),
                    ]:
                        footprints.append((index, param.mode, origin))
                        if param.mode == "modify":
                            self.modification(origin, point)
                for i, (arg, mode, origin) in enumerate(footprints):
                    for other_arg, other_mode, other in footprints[i + 1 :]:
                        if (
                            arg != other_arg
                            and "modify" in {mode, other_mode}
                            and origin.parameter == other.parameter
                            and overlap(origin.path, other.path)
                        ):
                            raise Rejected(
                                "Call arguments/captures have overlapping read/modify access"
                            )
                for obligation in result.obligations:
                    self.invoke(obligation.callback, obligation.source, obligation.mode)
                result.obligations = frozenset()
                self.put(step["dest"], result)


def dot(path: Path) -> str:
    return ".".join(path) or "<whole>"
