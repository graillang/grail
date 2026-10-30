"""May/must interval semantics and a toy memory-interface cache collision."""

from __future__ import annotations

import hashlib
import itertools
import json
from dataclasses import dataclass


def powerset(n: int) -> list[frozenset[int]]:
    return [frozenset(i for i in range(n) if bits & (1 << i)) for bits in range(1 << n)]


@dataclass(frozen=True)
class Interval:
    may: frozenset[int]
    must: frozenset[int]

    def __post_init__(self) -> None:
        if not self.must <= self.may:
            raise ValueError("uninhabited may/must interval")

    def models(self, actual: frozenset[int]) -> bool:
        return self.must <= actual <= self.may

    def refines(self, public: Interval) -> bool:
        return self.may <= public.may and public.must <= self.must

    def fingerprint(self, *, bad_may_only: bool = False) -> str:
        raw = {"schema": "research-interval-1", "may": sorted(self.may)}
        if not bad_may_only:
            raw["must"] = sorted(self.must)
        return hashlib.sha256(
            json.dumps(raw, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()


def check() -> dict:
    populations = []
    for n in range(1, 5):
        sets = powerset(n)
        intervals = [
            Interval(upper, lower) for upper in sets for lower in sets if lower <= upper
        ]
        mismatches = 0
        wrong_may_only = 0
        witness = None
        for implementation, public in itertools.product(intervals, repeat=2):
            behaviors = [s for s in sets if implementation.models(s)]
            semantic = all(public.models(s) for s in behaviors)
            actual = implementation.refines(public)
            mismatches += actual != semantic
            if implementation.may <= public.may and not semantic:
                wrong_may_only += 1
                if witness is None:
                    behavior = next(s for s in behaviors if not public.models(s))
                    witness = {
                        "implementation_may": sorted(implementation.may),
                        "implementation_must": sorted(implementation.must),
                        "public_may": sorted(public.may),
                        "public_must": sorted(public.must),
                        "behavior": sorted(behavior),
                    }
        assert mismatches == 0
        assert wrong_may_only > 0
        populations.append(
            {
                "n": n,
                "consistent_intervals": len(intervals),
                "pairs": len(intervals) ** 2,
                "semantic_mismatches": mismatches,
                "bad_may_only_pairs": wrong_may_only,
                "counterexample": witness,
            }
        )
    both = frozenset({0, 1})
    strong = Interval(frozenset({0, 1, 2}), both)
    weak = Interval(strong.may, frozenset({0}))
    old_behavior, fresh_behavior = both, frozenset({0, 2})
    assert strong.models(old_behavior) and weak.models(fresh_behavior)
    assert not strong.models(fresh_behavior)
    assert strong.refines(weak) and not weak.refines(strong)
    assert strong.fingerprint(bad_may_only=True) == weak.fingerprint(bad_may_only=True)
    assert strong.fingerprint() != weak.fingerprint()
    # This is only an in-memory check cache, not a compiler implementation.
    stale_cache = {strong.fingerprint(bad_may_only=True): both <= strong.must}
    reused = stale_cache[weak.fingerprint(bad_may_only=True)]
    fresh_check = both <= weak.must
    assert reused and not fresh_check
    invalid = 0
    for upper, lower in itertools.product(powerset(3), repeat=2):
        if not lower <= upper:
            try:
                Interval(upper, lower)
            except ValueError:
                invalid += 1
            else:
                raise AssertionError("inconsistent interval accepted")
    return {
        "populations": populations,
        "invalid_intervals_rejected_n3": invalid,
        "cache_case": {
            "may_only_key_equal": True,
            "full_key_equal": False,
            "stale_accept": reused,
            "fresh_accept": fresh_check,
            "old_behavior": sorted(old_behavior),
            "new_behavior": sorted(fresh_behavior),
            "old_full_key": strong.fingerprint(),
            "new_full_key": weak.fingerprint(),
        },
        "scope": "consistent intervals over powersets, n=1..4; toy cache; no source ABI or artifact certification",
    }


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
