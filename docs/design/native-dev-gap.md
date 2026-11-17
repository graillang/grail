# Native dev build against Go: the instruction gap

Measured with callgrind instruction counts (two problem sizes, so setup cancels; Go under
`GODEBUG=asyncpreemptoff=1`), dev builds (`--overflow=checked`), x86-64. Every executed
instruction of ours is classified by `.work/gap/classify.py`-style tooling (callgrind
`--dump-instr`): register moves, xmm moves, frame traffic, checks, arithmetic.

## Where it stands (2026-11-17)

| program | start | now | Go | ratio now |
|---|---|---|---|---|
| nbody, 20k steps | 141.7M | 60.1M | ~22M | 2.7x |
| sieve | 942M | 381M | - | - |
| fnv | 827M | 538M | - | ~1.3x per hashed byte |
| fib(32) | 155.1M | 105.8M | 102.9M | 1.03x |

Done, in the order they landed: inline `u8[]` stores; array element ops with immediates; two-address
SSE arithmetic; leaq-then-load of a slot as a slot load; constant shift counts and constant
compares; accumulators off %rax; live-range allocation of the callee-saved registers; exact call
reads from signature facts; raw address offsets; f64 loads/stores as `movsd`; array elements
addressed from their own registers; SSE liveness by register number; and (gaps15-bce,
/root/prover_wrap) interval proofs removing nbody's index overflow and bounds checks.

## Next, by measured potential

1. **Float results in their destination register** (front end, native.grl `float_text`). The front
   end computes every float operation in the scratch pair - `movaps A,%xmm0; movaps B,%xmm1; OPsd
   %xmm1,%xmm0` - and the optimiser folds that back only when the result goes straight to a
   promoted register. In nbody 98 `movaps` remain because the result crosses an overflow check or
   goes to a different register. Emitting `OPsd` on the destination's own register (or the left
   operand's, when it is not used again) removes the copies at the source: about 2 instructions per
   float operation, up to ~400 per nbody step (~15% of what remains).
2. ~~Owned-vector header hoisting~~ (item 6): done - the loop-stability fact (FACT_LOOP_STABLE)
   lets the data pointer (and length when needed) be loaded before the loop; fnv -11%.
3. **CSE of index arithmetic within an iteration** (`i*3` computed once per body in nbody).
4. **Memory-operand arithmetic** where an element is used once: in place, rarely fires today
   because elements land in promoted registers; grows with 1.
