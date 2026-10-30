"""Adversarial tests: inferred contracts, consumers and unsupported constructs."""

from __future__ import annotations

import copy
import json
import unittest

from client import Checker
from contracts import canonical, decode
from fixtures import borrow, call, clients, function, owner, p, providers, use
from infer import infer
from model import Rejected
from oracle import check


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifact, cls.stats = infer(providers())
        cls.summaries = decode(cls.artifact)

    def test_clients(self):
        for case in clients():
            with self.subTest(case=case["name"]):
                if case["accept"]:
                    Checker(self.summaries, case["steps"]).check()
                else:
                    with self.assertRaises(Rejected):
                        Checker(self.summaries, case["steps"]).check()

    def test_concrete_dependency_oracle(self):
        result = check(providers(), self.summaries)
        self.assertGreater(result["concrete_returns_checked"], 0)
        self.assertEqual(result["failures"], [])
        self.assertEqual(result["no_results"], [])

    def test_root_index_matches_reference(self):
        for case in clients():
            with self.subTest(case=case["name"]):
                try:
                    Checker(self.summaries, case["steps"], indexed=False).check()
                    accepted = True
                except Rejected:
                    accepted = False
                self.assertEqual(accepted, case["accept"])

    def test_no_lifetime_or_root_annotations_in_inputs(self):
        self.assertNotIn("source_sets", json.dumps(providers()))
        self.assertNotIn("origins", json.dumps(providers()))

    def test_provider_composition_uses_imported_contracts(self):
        body = function(
            "downstream",
            ["bytes"],
            {"record": {"payload": "view"}},
            call("wrap", call("identity", call("first", p(0)))),
        )
        artifact, _ = infer([body], imports=self.summaries)
        contract = decode(artifact)["downstream"]
        self.assertEqual(len(artifact["functions"]), 1)
        self.assertEqual(next(iter(contract.flows[("payload",)])).parameter, 0)
        self.assertEqual(next(iter(contract.flows[("payload",)])).kind, "storage")

    def test_owning_value_parameter_is_not_silently_borrowed(self):
        with self.assertRaisesRegex(Rejected, "owning value moves"):
            infer([function("consume", ["bytes"], "view", borrow(0), ["value"])])

    def test_import_changes_invalidate_dependency_digest(self):
        left, _ = infer([function("pick", ["bytes", "bytes"], "view", borrow(0))])
        right, _ = infer([function("pick", ["bytes", "bytes"], "view", borrow(1))])
        downstream = [
            function("forward", ["bytes", "bytes"], "view", call("pick", p(0), p(1)))
        ]
        a, _ = infer(downstream, imports=decode(left))
        b, _ = infer(downstream, imports=decode(right))
        self.assertEqual(a["body_sha256"], b["body_sha256"])
        self.assertNotEqual(a["imports_sha256"], b["imports_sha256"])
        self.assertNotEqual(a["functions"], b["functions"])

    def test_owner_drop_is_not_silent_reclamation(self):
        with self.assertRaises(Rejected):
            Checker(self.summaries, [owner("a"), {"op": "drop", "var": "a"}]).check()

    def test_recursive_summary_converges(self):
        self.assertEqual(len(self.summaries["parse"].flows[("*",)]), 1)
        self.assertTrue(self.summaries["parse"].productive)

    def test_generic_summary_does_not_expand_instances(self):
        summary = self.summaries["identity"].raw()
        self.assertEqual(len(summary["outputs"]), 1)
        self.assertEqual(summary["source_sets"][0][0]["kind"], "prefix")

    def test_field_specific_not_flat_union(self):
        summary = copy.deepcopy(self.summaries["pair"])
        union = frozenset(o for values in summary.flows.values() for o in values)
        summary.flows = {path: union for path in summary.flows}
        changed = {**self.summaries, "pair": summary}
        case = next(c for c in clients() if c["name"] == "field_sensitive_last_use")
        Checker(self.summaries, case["steps"]).check()
        with self.assertRaises(Rejected):
            Checker(changed, case["steps"]).check()

    def test_local_escape_rejected(self):
        with self.assertRaisesRegex(Rejected, "local storage"):
            infer([function("bad", [], "view", {"local_view": "scratch"})])

    def test_nonproductive_recursion_rejected(self):
        with self.assertRaisesRegex(Rejected, "nonproductive"):
            infer([function("loop", ["bytes"], "view", call("loop", p(0)))])

    def test_unknown_operation_rejected(self):
        with self.assertRaises(Rejected):
            infer([function("bad", [], "unit", {"foreign": True})])

    def test_write_through_read_parameter_rejected(self):
        bad = function(
            "bad",
            ["bytes", "callback"],
            "unit",
            {"visit": {"source": p(0), "callback": p(1), "mode": "modify"}},
        )
        with self.assertRaisesRegex(Rejected, "read-only"):
            infer([bad])

    def test_internal_call_alias_rejected(self):
        fs = providers()
        fs.append(
            function(
                "bad",
                ["bytes", "callback"],
                "unit",
                call("two_modify", p(0), p(0), p(1)),
                ["modify", "value"],
            )
        )
        with self.assertRaisesRegex(Rejected, "overlapping"):
            infer(fs)

    def test_work_budget(self):
        with self.assertRaisesRegex(Rejected, "budget"):
            infer(providers(), max_analyses=1)

    def test_schema_bad_parameter(self):
        artifact = copy.deepcopy(self.artifact)
        f = next(f for f in artifact["functions"] if f["name"] == "first")
        f["source_sets"][0][0]["parameter"] = 100
        with self.assertRaises(Rejected):
            decode(artifact)

    def test_schema_bad_source_type(self):
        artifact = copy.deepcopy(self.artifact)
        f = next(f for f in artifact["functions"] if f["name"] == "first")
        f["source_sets"][0][0]["kind"] = "loan"
        with self.assertRaises(Rejected):
            decode(artifact)

    def test_schema_does_not_establish_semantic_honesty(self):
        # Deliberately lying, structurally valid contract: the producer's true body returns b.
        artifact, _ = infer([function("pick", ["bytes", "bytes"], "view", borrow(1))])
        artifact["functions"][0]["source_sets"][0][0]["parameter"] = 0
        forged = decode(artifact)
        Checker(
            forged,
            [
                owner("a"),
                owner("b"),
                {
                    "op": "call",
                    "dest": "v",
                    "fn": "pick",
                    "args": [{"var": "a"}, {"var": "b"}],
                },
                {"op": "end", "owner": "b"},
                use("v"),
            ],
        ).check()
        observed = check(
            [function("pick", ["bytes", "bytes"], "view", borrow(1))], forged
        )
        self.assertTrue(observed["failures"])
        # This test passes by exposing the TCB limitation; it is NOT an accepted assurance claim.

    def test_serialization_deterministic(self):
        again, _ = infer(providers())
        self.assertEqual(canonical(self.artifact), canonical(again))


if __name__ == "__main__":
    unittest.main()
