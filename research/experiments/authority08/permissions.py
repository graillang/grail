"""Ghost interval permissions, not a source borrow checker or proposed runtime loan table."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Cap:
    owner: str
    lo: int
    hi: int
    mode: str = "mut"

    def __post_init__(self) -> None:
        assert 0 <= self.lo <= self.hi and self.mode in {"read", "mut"}

    def cells(self) -> frozenset[int]:
        return frozenset(range(self.lo, self.hi))

    def qualifier(self) -> tuple[str, str]:
        return self.owner, self.mode


def overlap(a: Cap, b: Cap) -> bool:
    return a.owner == b.owner and max(a.lo, b.lo) < min(a.hi, b.hi)


def separate(caps: list[Cap]) -> bool:
    return all(
        not overlap(a, b) or a.mode == b.mode == "read"
        for i, a in enumerate(caps)
        for b in caps[i + 1 :]
    )


def split(parent: Cap, at: int) -> tuple[Cap, Cap]:
    assert parent.mode == "mut" and parent.lo <= at <= parent.hi
    return Cap(parent.owner, parent.lo, at, parent.mode), Cap(
        parent.owner, at, parent.hi, parent.mode
    )


def parent_access(parent: Cap, children: list[Cap], query: Cap, write: bool) -> bool:
    assert parent.mode == "mut"
    assert (
        query.owner == parent.owner and parent.lo <= query.lo <= query.hi <= parent.hi
    )
    assert all(
        c.owner == parent.owner and parent.lo <= c.lo <= c.hi <= parent.hi
        for c in children
    )
    assert separate(children)
    return all(
        not overlap(query, child) or (not write and child.mode == "read")
        for child in children
    )


def check_finite() -> dict[str, object]:
    # Source-root/mode summaries coincide, but one pair has overlapping write authority.
    good = [Cap("data", 0, 2), Cap("data", 2, 4)]
    bad = [Cap("data", 0, 4), Cap("data", 0, 4)]
    assert [c.qualifier() for c in good] == [c.qualifier() for c in bad]
    assert separate(good) and not separate(bad)
    split_cases = queries = 0
    for size in range(9):
        parent = Cap("data", 0, size)
        for at in range(size + 1):
            parts = list(split(parent, at))
            assert (
                separate(parts)
                and parts[0].cells() | parts[1].cells() == parent.cells()
            )
            split_cases += 1
        for lo in range(size + 1):
            for hi in range(lo, size + 1):
                for mode in ["read", "mut"]:
                    child = Cap("data", lo, hi, mode)
                    # Independently materialize per-cell rights for the finite oracle.
                    parent_reads = parent.cells() - (
                        child.cells() if mode == "mut" else frozenset()
                    )
                    parent_writes = parent.cells() - child.cells()
                    child_writes = child.cells() if mode == "mut" else frozenset()
                    assert (
                        not parent_writes & child.cells()
                        and not child_writes & parent_reads
                    )
                    for qlo in range(size + 1):
                        for qhi in range(qlo, size + 1):
                            query = Cap("data", qlo, qhi)
                            for write in [False, True]:
                                expected = query.cells() <= (
                                    parent_writes if write else parent_reads
                                )
                                assert (
                                    parent_access(parent, [child], query, write)
                                    == expected
                                )
                                assert parent_access(
                                    parent, [], query, write
                                )  # rights resume when loan ends
                                queries += 1
    return {
        "bound": "integer intervals within [0,n], 0 <= n <= 8; one-level child loans only",
        "source_summary_collision": {
            "summary": [list(c.qualifier()) for c in good],
            "good_ranges": [[c.lo, c.hi] for c in good],
            "bad_ranges": [[c.lo, c.hi] for c in bad],
            "good_separate": True,
            "bad_separate": False,
        },
        "split_cases": split_cases,
        "parent_access_queries": queries,
        "mismatches": 0,
        "interpretation": "well-formed permission construction matters; this does not require new public qualifier slots or a runtime loan graph",
    }
