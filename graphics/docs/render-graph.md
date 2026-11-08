# The render graph

`grail_graph.h` / `src/grail_graph.c` decide what a frame *is*: which passes run, in what order,
and which transitions each needs. No device, no backend, no GPU — the output is an execution order
and a list of `gr_barrier` values that `gr_cmd_barrier` already accepts, which is what makes this
layer exhaustively testable on a machine with no driver.

## The frame is described, not ordered

A pass names the resources it reads and writes; nothing about declaration order decides execution.

```c
gr_graph_add_resource(graph, "scene", GR_GRAPH_RESOURCE_TEXTURE, texture_handle, &scene);
gr_graph_add_pass(graph, "shade", &shade);
gr_graph_pass_write(graph, clear, scene, GR_STATE_COLOR_ATTACHMENT);
gr_graph_pass_read(graph, shade, scene, GR_STATE_SHADER_READ);
gr_graph_pass_set_side_effect(graph, shade, 1);
gr_graph_compile(graph, &report);
```

Edges are derived by versioning each resource: every access depends on the previous access to the
same resource. A topological sort then produces the order, with declaration order only breaking
ties — which is why a frame can be reorganised without changing its behaviour, and why the test
declares the reader before the writer and still gets the writer first.

A **cycle can only come from `gr_graph_pass_depends`**, because versioning always points forward.
Refusing it rather than picking an order is deliberate: a cyclic frame has no correct order to pick.

## Barriers are derived

Each resource carries the state it is in, starting at the state it was imported with, or
`GR_STATE_UNDEFINED` for one the frame creates. When a pass needs a different state, the transition
is emitted before that pass and the state advances. A pass that reads what the previous pass wrote
*in the same state* gets no barrier at all — that is the entire reason to derive them instead of
hand-writing them, and `test_state_continuity` asserts it produces exactly one barrier across three
passes that all stay in `COLOR_ATTACHMENT`.

## Culling runs backwards

A pass is live if it has a side effect, or if it writes something a live pass reads. Iterating to a
fixpoint over the reverse execution order means a whole dead chain collapses in one compile: in the
test, a feeder and a middle pass disappear until the side-effecting pass starts reading their
output, at which point both come back.

## Validation

Every check happens in `gr_graph_compile`, so a caller cannot submit a frame that was never
validated. The report names the error, the pass and the resource:

| error | cause |
| --- | --- |
| `DUPLICATE_PASS` | two passes with one name — every report would be ambiguous |
| `DUPLICATE_WRITE` | one pass writing one resource twice — no order between the two writes, so neither barriers nor culling could be right |
| `USE_BEFORE_WRITE` | a read with no writer and no imported initial state |
| `CYCLE` | the dependency edges contain a cycle |
| `EMPTY` | nothing declared |
| `TOO_MANY` | a capacity was exceeded (reported as `GR_ERROR_EXHAUSTED`) |

`gr_graph_reset` clears a frame for the next one, and `gr_graph_compile` is repeatable: derived
edges and barriers are rebuilt, never accumulated.

## Driving the graph on the GPU

`test_vk_backend` runs a three-pass frame where nothing is hand-ordered and no barrier is
hand-written:

```
fill   writes A                  solid.ps gradient
grade  reads A, writes B         tonemap.ps sampling A
final  reads B, writes C         tonemap.ps sampling B
```

The passes are declared **in reverse** (`final`, `grade`, `fill`); the graph orders them `2,1,0`
and derives five transitions — A undefined→colour, A colour→sampled, B undefined→colour, B
colour→sampled, C undefined→colour. The recording loop is the whole integration: for each step in
the derived order, apply `gr_graph_pass_barriers` through `gr_cmd_barrier`, then render that pass's
target. The driver accepting the submission and the readback matching a two-stage tonemap is what
proves the derivation, not the fact that the code compiled.

Readback is host work rather than a pass, so the two transition to `TRANSFER_SRC` are issued
directly after the graph.

## Evidence

`make -C graphics test` runs `test_graph`, 119 checks:

- order derived from dependencies, with the writer declared after the reader and still executing
  first; three derived barriers with the expected `(resource, src, dst)` in the expected places;
- a sizing call (`capacity 0`) that reports without writing, and `GR_NEED_MORE` when the array is
  short;
- state continuity producing one barrier where three would be written by hand;
- culling: two dead passes, then none, as one read is added;
- every validation error, each in its own small graph, including the cycle that only an explicit
  edge can create;
- `final_state` for the next frame's import, and compile being idempotent.

On the GPU (`vk-smoke`): the three-pass frame above, with the graph ordering it `2,1,0` and
deriving 5 barriers, producing `b=0xa7d7d6fd9121e3b0` and `c=0x454eb9e1aef922b8` — different,
because the last pass applied the tonemap a second time rather than copying.

Two defects the tests caught in the graph itself, both in the first version: `graph_clear_derived`
zeroed the edge count and therefore **discarded the caller's explicit edges**, making
`gr_graph_pass_depends` a no-op and cycle detection unreachable; and the barrier pass sliced each
pass's accesses as a contiguous range, which is only true when one pass declares all of its accesses
before any other pass declares one — the test declared the reader first and caught it immediately.
