# Conditional ownership checkpoint

The checker joins initialization by intersection and cleanup obligations by union.
A binding or field moved on only one continuing branch cannot subsequently be read,
borrowed or moved. Disjoint, definitely initialized fields remain usable. Loan roots
and ancestor restrictions from either path remain in force until their carrier ends.

Owned fields and standalone byte owners have native drop flags. Checked `EndIfLive`
cleanup destroys only the values still present on the executed path. Explicit `drop`
still requires a definitely initialized binding; it is not an unchecked repeated drop.

Loops apply the same initialization join at their fixed point and to break exits.
Consuming an entry value and immediately breaking is supported. Consuming it again
on a possible later iteration is rejected. New iteration-local resources still must
be consumed before a backedge. Addressed scalar definitions retain their existing
intersection rule. This does not add source declarations without initializers or
field reassignment syntax.

Checked IR and template bundles use schema 3; rebuild old template artifacts.
Tests in `seed/tests/ownership_joins.rs` cover acceptance, use-after-move rejection,
zero/multiple iterations, and native cleanup under ASan/UBSan at O0/O2. This checkpoint
is not a soundness theorem and does not complete bootstrap v0.
