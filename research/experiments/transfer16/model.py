"""Finite may-target versus exact-cover comparison; not a pointer/type checker."""

from __future__ import annotations

from itertools import combinations, permutations


def subsets(n: int):
    for size in range(n + 1):
        yield from combinations(range(n), size)


def check() -> dict:
    names = ("strong_may", "weak_may", "arity_only", "checked_cover")
    policies = {
        name: {
            "cases": 0,
            "missing_cases": 0,
            "missing_edges": 0,
            "extra_edges": 0,
            "first_missing": None,
            "first_missing_with_cover": None,
        }
        for name in names
    }
    cases = 0
    certified = 0
    # n originals and one always-live fresh target. All output maps are injective.
    for n in range(1, 5):
        original = set(range(n))
        old = [{f"old_{i}"} for i in range(n)]
        for targets in permutations(range(n + 1), n):
            # Producer-side semantic witness, NOT inferred from lifetime bounds.
            # This toy computes it from its primitive target map; no real producer is certified.
            cover = set(targets) == original
            for written in subsets(n):
                cases += 1
                certified += cover
                actual = [set(q) for q in old]
                for handle in written:
                    if targets[handle] < n:
                        actual[targets[handle]] = {"new"}
                for name, stats in policies.items():
                    all_done = len(written) == n
                    clear = (
                        name == "strong_may"
                        and bool(written)
                        or name == "arity_only"
                        and all_done
                        or name == "checked_cover"
                        and cover
                        and all_done
                    )
                    predicted = [
                        {"new"} if clear else q | ({"new"} if written else set())
                        for q in old
                    ]
                    missing = sum(
                        len(a - q) for a, q in zip(actual, predicted, strict=True)
                    )
                    stats["cases"] += 1
                    stats["missing_edges"] += missing
                    stats["extra_edges"] += sum(
                        len(q - a) for a, q in zip(actual, predicted, strict=True)
                    )
                    if missing:
                        stats["missing_cases"] += 1
                        if cover and stats["first_missing_with_cover"] is None:
                            stats["first_missing_with_cover"] = {
                                "n": n,
                                "targets": targets,
                                "written": written,
                            }
                        if stats["first_missing"] is None:
                            stats["first_missing"] = {
                                "n": n,
                                "targets": targets,
                                "written": written,
                                "cover": cover,
                                "actual": [sorted(q) for q in actual],
                                "predicted": [sorted(q) for q in predicted],
                            }
    assert policies["weak_may"]["missing_cases"] == 0
    assert policies["checked_cover"]["missing_cases"] == 0
    assert policies["strong_may"]["missing_cases"] > 0
    assert policies["arity_only"]["missing_cases"] > 0
    return {
        "cases": cases,
        "truthful_cover_cases": certified,
        "policies": policies,
        "scope": "injective n-handle maps into n originals plus one fresh target, n=1..4; all write subsets; uniform new dependency",
    }


if __name__ == "__main__":
    import json

    print(json.dumps(check(), indent=2))
