"""Finite protocol model: user handle consumption does not imply device acknowledgment."""

from __future__ import annotations

from collections import deque
from collections.abc import Iterator
from dataclasses import asdict, dataclass, replace
from typing import Any


@dataclass(frozen=True)
class State:
    mode: str
    operations: tuple[str, ...]
    handles: frozenset[int]
    registered: frozenset[int]
    buffer_alive: bool = True

    def active(self) -> frozenset[int]:
        return frozenset(
            i
            for i, phase in enumerate(self.operations)
            if phase in {"running", "cancel_requested"}
        )

    def raw(self) -> dict[str, Any]:
        value = asdict(self)
        value["operations"] = list(self.operations)
        value["handles"] = sorted(self.handles)
        value["registered"] = sorted(self.registered)
        return value


def steps(state: State, policy: str) -> Iterator[tuple[str, State]]:
    assert policy in {"scope_owned", "handle_only", "clear_on_any_ack"}
    yield "stall", state  # No fairness or eventual acknowledgment is assumed.
    if state.mode.startswith("exited_"):
        return
    for i, phase in enumerate(state.operations):
        if phase == "idle" and state.mode == "body":
            phases = list(state.operations)
            phases[i] = "running"
            yield (
                f"submit[{i}]",
                replace(
                    state,
                    operations=tuple(phases),
                    handles=state.handles | {i},
                    registered=state.registered | {i},
                ),
            )
        if phase in {"running", "cancel_requested"}:
            phases = list(state.operations)
            phases[i] = "stopped"
            registered = (
                frozenset() if policy == "clear_on_any_ack" else state.registered - {i}
            )
            yield (
                f"acknowledge[{i}]",
                replace(state, operations=tuple(phases), registered=registered),
            )
        if phase == "stopped" and i in state.handles and state.mode == "body":
            yield f"finish[{i}]", replace(state, handles=state.handles - {i})
    if state.mode == "body":
        # Non-suspending abandonment requests cancellation, but does not assert it succeeded.
        phases = tuple(
            "cancel_requested" if p == "running" else p for p in state.operations
        )
        registered = frozenset() if policy == "handle_only" else state.registered
        yield (
            "error_abandon_handles",
            replace(
                state,
                mode="error_cleanup",
                operations=phases,
                handles=frozenset(),
                registered=registered,
            ),
        )
        if not state.handles:
            yield "normal_exit", replace(state, mode="normal_cleanup")
    if (
        state.mode in {"error_cleanup", "normal_cleanup"}
        and not state.registered
        and not state.handles
    ):
        outcome = "error" if state.mode == "error_cleanup" else "normal"
        yield (
            "release_buffer",
            replace(state, mode=f"exited_{outcome}", buffer_alive=False),
        )


def safe(state: State) -> bool:
    return not state.active() or state.buffer_alive


def trace_to(
    state: State, parents: dict[State, tuple[State, str] | None]
) -> list[dict[str, Any]]:
    trace = []
    while True:
        edge = parents[state]
        trace.append({"action": edge[1] if edge else "init", "state": state.raw()})
        if edge is None:
            return list(reversed(trace))
        state = edge[0]


def explore(policy: str, count: int) -> dict[str, Any]:
    assert 1 <= count <= 3
    initial = State("body", ("idle",) * count, frozenset(), frozenset())
    parents: dict[State, tuple[State, str] | None] = {initial: None}
    queue = deque([initial])
    violations = []
    transitions = 0
    stalled = None
    while queue:
        state = queue.popleft()
        if not safe(state):
            violations.append(state)
        if state.active() and state.mode == "error_cleanup" and stalled is None:
            stalled = state
        for action, target in steps(state, policy):
            transitions += 1
            if target not in parents:
                parents[target] = state, action
                queue.append(target)
    normal = sum(s.mode == "exited_normal" for s in parents)
    error = sum(s.mode == "exited_error" for s in parents)
    return {
        "policy": policy,
        "operation_bound": count,
        "reachable_states": len(parents),
        "transitions_including_stalls": transitions,
        "unsafe_states": len(violations),
        "normal_exit_states": normal,
        "error_exit_states": error,
        "shortest_counterexample": trace_to(violations[0], parents)
        if violations
        else None,
        "pending_error_stall": {
            "prefix": trace_to(stalled, parents),
            "cycle_action": "stall",
        }
        if stalled
        else None,
        "active_operations_always_registered": all(
            s.active() <= s.registered for s in parents
        ),
        "exit_drops_all_user_handles": all(
            not s.handles for s in parents if s.mode.startswith("exited_")
        ),
    }
