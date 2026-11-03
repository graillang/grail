"""Body-free single-call consumer with exact record places and explicit dead-value drops."""

from __future__ import annotations

from collections.abc import Hashable
from typing import TypeVar

from research.experiments.contracts02.model import Path, Rejected, overlap
from research.experiments.transforms05.contract import Contract
from research.experiments.transforms05.value import Value, copyable

Atom = TypeVar("Atom", bound=Hashable)


def call(
    contract: Contract,
    storage: dict[str, Value[Atom]],
    arguments: list[tuple[str, Path]],
    destination: str | None = None,
) -> None:
    if len(arguments) != len(contract.params) or (
        destination is not None and destination in storage
    ):
        raise Rejected("invalid call arity/result binding")
    actuals = []
    exclusive = []
    moves = []
    for param, (slot, path) in zip(contract.params, arguments, strict=True):
        if slot not in storage or "*" in path:
            raise Rejected("unknown or indexed client place")
        actual = storage[slot].project(path)
        actuals.append(actual)
        if param.mode == "take" and not copyable(actual.ty):
            if path:
                raise Rejected("partial client move outside this fragment")
            moves.append(slot)
        # Copy take inputs are evaluated before activating the access parameters.
        exclusive.append(
            param.mode if param.mode != "take" or not copyable(actual.ty) else "copy"
        )
    for i, (slot, path) in enumerate(arguments):
        for j in range(i + 1, len(arguments)):
            other_slot, other_path = arguments[j]
            modes = {exclusive[i], exclusive[j]}
            if (
                slot == other_slot
                and overlap(path, other_path)
                and "copy" not in modes
                and modes & {"mut", "take"}
            ):
                raise Rejected("overlapping mutable/move client arguments")
    result, post = contract.apply(actuals)
    if any(leaf.kind == 'mut' for _, leaf in result.ty.leaves()):
        raise Rejected(
            "unresolved result type; contextual type arguments outside this client fragment"
        )
    for slot in moves:
        del storage[slot]
    for i, value in post.items():
        slot, path = arguments[i]
        storage[slot] = storage[slot].assign(path, value)
    if destination is not None:
        storage[destination] = result


def dependencies(storage: dict[str, Value[Atom]]) -> frozenset[Atom]:
    return frozenset(
        atom
        for value in storage.values()
        for roots in value.flows.values()
        for atom in roots
    )
