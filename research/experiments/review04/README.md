# Review 04: clarify claims before extending the checker

Small installed-rustc probes, compiled/executed in the existing memory01 sandbox. No third-party
crate/build scripts or dependencies. Not a Grail implementation, benchmark or soundness proof.

```sh
python research/experiments/review04/check.py
```

Six expected outcomes:

- Reusing a Vec of views after `clear` while dropping the old source is rejected by this rustc.
- A consuming, independently retyped empty-Vec helper accepts the same lifetime transition in safe
  Rust. This is an API/type-state example, not a guarantee that the allocation is reused.
- An owned mutable closure is Sync but not callable through the Fn shared-receiver bound.
- A Cell-owning closure is callable through Fn but is not Sync.

The last four cases demonstrate separate call-permission and thread-sharing properties, not a
soundness bug in the proposed language. Its complete rules do not exist yet. Derived metadata and
parameter modes may hide Rust's trait names; they cannot omit the underlying obligations.

The recorded set comparison shows that an additive post-contract `after = before ∪ additions`
cannot express clearing all dependencies. This is a logical limitation of that interpretation,
not a test run against an implementation of the external review.
