"""Protect dependency erasure, entry snapshots and access/move invariants."""

from __future__ import annotations

import copy
import unittest

from research.experiments.contracts02.model import Rejected, Ty
from research.experiments.transforms05.client import call
from research.experiments.transforms05.contract import decode
from research.experiments.transforms05.fixtures import (
    SEQ,
    T,
    arg,
    definitions,
    move,
    procedure,
)
from research.experiments.transforms05.infer import infer
from research.experiments.transforms05.value import Pre, Value


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contracts = {}
        for definition in definitions():
            c = infer(definition, cls.contracts)
            cls.contracts[c.name] = c
        cls.contracts = decode(
            {"schema": 1, "contracts": [c.raw() for c in cls.contracts.values()]}
        )

    def test_clear_has_no_post_dependencies(self):
        self.assertEqual(self.contracts["clear"].post[0].flows, {})

    def test_append_keeps_old_and_new(self):
        self.assertEqual(
            self.contracts["append"].post[0].flows[("*",)],
            frozenset({Pre(0, ("*",), True), Pre(1, (), True)}),
        )

    def test_replace_keeps_old_only_in_return(self):
        c = self.contracts["replace_all"]
        self.assertEqual(c.result.flows[("*",)], frozenset({Pre(0, ("*",), True)}))
        self.assertEqual(c.post[0].flows[("*",)], frozenset({Pre(1, ("*",), True)}))

    def test_composition_removes_cleared_entry_state(self):
        self.assertEqual(
            self.contracts["clear_append"].post[0].flows[("*",)],
            frozenset({Pre(1, (), True)}),
        )

    def test_branch_union_is_conservative(self):
        self.assertEqual(
            self.contracts["maybe_clear"].post[0].flows[("*",)],
            frozenset({Pre(0, ("*",), True)}),
        )
        self.assertEqual(
            self.contracts["clear_or_replace"].post[0].flows[("*",)],
            frozenset({Pre(1, ("*",), True)}),
        )

    def test_opaque_record_instantiation_preserves_fields(self):
        ty = Ty.parse({"record": {"a": "view", "b": "view"}})
        old = Value(
            Ty("list", inner=ty),
            {("*", "a"): frozenset({"old-a"}), ("*", "b"): frozenset({"old-b"})},
        )
        new = Value(
            old.ty, {("*", "a"): frozenset({"new-a"}), ("*", "b"): frozenset({"new-b"})}
        )
        result, post = self.contracts["replace_all"].apply([old, new])
        self.assertEqual(result.flows, old.flows)
        self.assertEqual(post[0].flows, new.flows)

    def test_swap_is_instantiated_from_one_snapshot(self):
        a, b = (
            Value(Ty("view"), {(): frozenset({"a"})}),
            Value(Ty("view"), {(): frozenset({"b"})}),
        )
        _, post = self.contracts["swap"].apply([a, b])
        self.assertEqual(post[0].flows, b.flows)
        self.assertEqual(post[1].flows, a.flows)

    def test_refinement_allows_safe_imprecision(self):
        exact = self.contracts["clear"]
        wide = copy.deepcopy(exact)
        wide.post[0].flows = {("*",): frozenset({Pre(0, ("*",), True)})}
        self.assertTrue(exact.refines(wide))
        self.assertFalse(wide.refines(exact))

    def test_missing_mutable_post_is_not_silent_preserve_or_clear(self):
        raw = self.contracts["clear"].raw()
        raw["post"] = []
        with self.assertRaises(Rejected):
            decode({"schema": 1, "contracts": [raw]})

    def test_cannot_clear_noncontainer(self):
        with self.assertRaises(Rejected):
            infer(
                procedure(
                    "bad",
                    ["view"],
                    ["mut"],
                    "unit",
                    [{"op": "clear", "target": arg(0)}],
                )
            )

    def test_cannot_move_read_opaque_parameter(self):
        with self.assertRaises(Rejected):
            infer(procedure("bad", [T], ["read"], T, [], move(0)))

    def test_cannot_silently_copy_generic_payload(self):
        with self.assertRaises(Rejected):
            infer(
                procedure(
                    "bad",
                    [SEQ, T],
                    ["mut", "read"],
                    "unit",
                    [{"op": "append", "target": arg(0), "value": {"read": arg(1)}}],
                )
            )

    def test_internal_alias_call_rejected(self):
        with self.assertRaises(Rejected):
            infer(
                procedure(
                    "bad",
                    [T],
                    ["mut"],
                    "unit",
                    [
                        {
                            "op": "call",
                            "fn": "swap",
                            "args": [{"place": arg(0)}, {"place": arg(0)}],
                            "dest": "u",
                        }
                    ],
                ),
                self.contracts,
            )

    def test_conditional_move_cannot_be_used_again(self):
        with self.assertRaises(Rejected):
            infer(
                procedure(
                    "bad",
                    [T],
                    ["take"],
                    T,
                    [
                        {
                            "op": "branch",
                            "then": [{"op": "let", "name": "x", "value": move(0)}],
                            "else": [],
                        }
                    ],
                    move(0),
                )
            )

    def test_client_rejects_alias_before_mutating_storage(self):
        original = Value(Ty.parse({"list": "view"}), {("*",): frozenset({"old"})})
        storage = {"cache": original}
        with self.assertRaises(Rejected):
            call(self.contracts["swap"], storage, [("cache", ()), ("cache", ())])
        self.assertEqual(storage, {"cache": original})

    def test_disjoint_record_places_swap_from_same_snapshot(self):
        ty = Ty.parse({"record": {"a": "view", "b": "view"}})
        storage = {
            "pair": Value(ty, {("a",): frozenset({"a"}), ("b",): frozenset({"b"})})
        }
        call(self.contracts["swap"], storage, [("pair", ("a",)), ("pair", ("b",))])
        self.assertEqual(
            storage["pair"].flows, {("a",): frozenset({"b"}), ("b",): frozenset({"a"})}
        )

    def test_copy_take_can_snapshot_mutated_view_slot(self):
        storage = {"x": Value(Ty("view"), {(): frozenset({"source"})})}
        call(self.contracts["replace_slot"], storage, [("x", ()), ("x", ())], "old")
        self.assertEqual(storage["x"].flows, storage["old"].flows)

    def test_noncopy_take_binding_is_consumed(self):
        ty = Ty.parse({"list": "view"})
        storage = {
            "cache": Value(ty, {("*",): frozenset({"old"})}),
            "incoming": Value(ty, {("*",): frozenset({"new"})}),
        }
        call(
            self.contracts["replace_all"],
            storage,
            [("cache", ()), ("incoming", ())],
            "saved",
        )
        self.assertNotIn("incoming", storage)
        self.assertEqual(storage["saved"].flows, {("*",): frozenset({"old"})})
        self.assertEqual(storage["cache"].flows, {("*",): frozenset({"new"})})

    def test_malformed_source_list_is_rejected(self):
        raw = self.contracts["append"].raw()
        raw["post"][0]["routes"][0]["pre"] = ["not-an-object"]
        with self.assertRaises(Rejected):
            decode({"schema": 1, "contracts": [raw]})


if __name__ == "__main__":
    unittest.main()
