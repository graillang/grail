# The dev backend without text hops

Status: design, building in steps (owner: optimiser speed). Byte-identical output at every step; the
self-host fixed point, split-test and cache-test hold it.

## Where the text is read today

A dev `grail build` of one module moves its code through text four times:

1. The front end (`native.grl`) writes assembly-like text into `c.out`, one line per instruction.
2. The optimiser (`optimize.grl`) cuts the stream into bodies and parses every line of a body into
   `ir::Body` (`ir::parse`, `ir::classify`): an opcode, two classified operands (kind, value,
   register mask) and byte spans back into the text. It prints the surviving lines (`emit_line`).
3. Whole-stream passes read the optimised text line by line: the inlining pass's call lines
   (`lines_of_interest`), the stack probes (`probe_frames`, `frame_scan`), the site table
   (`site_table`) and, for `.s` output, the atomics expansion.
4. The in-process assembler (`asm_x86`) parses the text again (`read_line`) and encodes it.

On a cold syn4000 build these were about 18% (2) and 10% (4) of the compiler process, and the
whole-stream passes several percent more. After an edit, the memo (optimize.grl `one_body`) and the
function units make (2) and (4) cost one function; the whole-stream passes still cost the module.

## Target

One record stream per function, built by the front end, optimised in place, encoded from directly.
The text is a dump: `.s` output, `--emit-ir`, and the debugging views print it from the records.

The record is `ir::Body`'s columns as they are, with the operands decoded fully instead of left as
spans: kind 3 (immediate) carries its value or a symbol-pool index, kind 4 (memory, symbol, label)
carries base/index/scale/displacement and a symbol-pool index, and each body owns its symbol pool
(`ir::Pool`: `bytes: u8[]`, `start: u64[]`, `end: u64[]`). A label is a pool entry plus the number
`ir::numbered` gives it today.

## Steps

S1 (landed): the edited build's misses and the whole-stream rescans.
- Replayed units carried their parameter facts twice, so every body missed the memo.
- `probe_frames`/`probe_backstop` are one scan with no per-line copies; the inlining pass's call
  lines travel with each memo entry and are noted as bodies are written.

S2: a line memo in `ir::parse`. The emitted lines repeat (syn4000's bodies share most of theirs):
a line with no label operand and outside data parses to the same record wherever it stands, so the
record is kept under the line's hash and replayed - the spans relocated, the per-body state
(`maxslot`, `weird`) updated as `classify` would. Label operands are renumbered through `numbered`
each time. Byte-identical by construction; removes most of parse's cost without touching the front
end.

S3: the front end hands records for the shapes it writes most. Typed emit helpers in `native.grl`
(`emit_rr`, `emit_slot_load`, `emit_slot_store`, `emit_call`, `emit_jump`, `mark`) append the text
as now and a pre-classified record to `c.recs`, with the line's offset. The optimiser takes a
record when its offset is the start of the line it would parse (checked the way `known_checked`
checks units) and parses anything else, so coverage grows helper by helper and a stale or missing
record costs only a parse. `GRAIL_OPT_STATS=1` reports the share of lines that came as records.

S4: the optimiser's output as records. `emit_line` writes a record beside its text; the per-body
records go to the assembler's `encode(record)` entry (owner: object emit), which takes the operand
decoding S3 needs anyway. A body that comes from the memo carries its records in binary in the
memo entry, as it carries its call-line offsets now. The assembler's `read_line` stays for text that
comes without records (hand-written assembly, `asm` blocks).

S5: no text on the default path. `site_table`, `frame_scan` and the inlining pass read the record
stream and the side tables the optimiser fills (sites per body, frame sizes per body, call lines);
the text is written only for `.s` output and the dumps. Then `ir::parse` is the reader of hand-written
text alone.

## Interfaces

- Optimiser to assembler: per body, `ir::Body`'s record columns for the surviving lines plus its
  pool, in emission order, and the body's text range when text is also written.
- Memo entries (optimize.grl `one_body`): versioned by the key's prefix (`grail-opt N`); a format
  change bumps N so an older entry is never read.
