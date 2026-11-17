# Native dev build against Go: the instruction gap

Measured with callgrind instruction counts (two problem sizes, so setup cancels; Go under
`GODEBUG=asyncpreemptoff=1`), dev builds (`--overflow=checked`), x86-64. Every executed
instruction of ours is classified by `.work/gap/classify.py`-style tooling (callgrind
`--dump-instr`): register moves, xmm moves, frame traffic, checks, arithmetic.

## Where it stands (2026-11-17)

| program | start | now | Go | ratio now |
|---|---|---|---|---|
| nbody, 20k steps | 141.7M | 49.6M | ~22M | 2.3x |
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

1. ~~Float results in their destination register~~: after SSE liveness by register number and the
   interval proofs only 10 `movaps` remain in nbody (from 98); about 20 instructions per step, not
   worth a front-end change now.
2. ~~Owned-vector header hoisting~~ (item 6): done - the loop-stability fact (FACT_LOOP_STABLE)
   lets the data pointer (and length when needed) be loaded before the loop; fnv -11%.
3. **Index arithmetic**: unchecked constant multiplies are now `leaq`/shift/`imulq` (nbody -13%).
   CSE of `i*3` within a straight line: done (`index_cse`, scratch r8..r11; nbody -5%).
4. **Memory-operand arithmetic** where an element is used once: in place, rarely fires today
   because elements land in promoted registers; grows with 1.
