# Replacing values that contain borrows

References and views can live inside other values. Replacing such a value must update its
storage's retained origins, not just exchange a machine word.

{{example:writeback}}

The generic function replaces a stored readonly view and returns the previous descriptor. The
caller retains both underlying byte owners for as long as the corresponding values require them.
Incoming borrows cannot be shorter-lived than the contract of external storage.

Assignments, exchange, and captured vector updates propagate guards across calls. Weak updates
can retain old guards longer than strictly necessary, and opaque local-frame writes require a
retained owner witness. Opaque external writes without a recoverable invariant contract are
rejected rather than accepted on the strength of an erased lifetime label.

**Try it:** add `second.push(3)` before reading `current`. The live stored view should prevent it.
