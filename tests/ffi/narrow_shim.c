/* narrow_shim.c - C twins that read a narrow integer argument through its whole 64-bit register.
 * Included by shim.c.
 *
 * A C callee that declares the parameter as `unsigned long long` sees exactly the word the caller
 * put in the register, so these twins observe the upper half of an argument Grail declared as
 * i8..i32/u8..u32. Each ABI states what belongs there (docs/ffi.md, "Direct calls") and
 * NS_U32_WORD is the value a `u32` with every bit set must arrive as:
 *
 *   System V x86-64, AAPCS64  a value narrower than 32 bits is extended to 32 bits (unsigned
 *                             zero, signed sign) and the upper half is unspecified; Grail passes
 *                             the type's canonical word, so an unsigned 32-bit value has zeroes.
 *   RV64 LP64D                the value is zero- or sign-extended to 32 bits by its type, then
 *                             sign-extended to XLEN, so a u32 with bit 31 set arrives sign-extended.
 *
 * `-Wall -Wextra` (tools/abi-test.mjs) does not compile this file, but every function uses its
 * parameters anyway, so nothing here depends on a warning being off.
 */
#if defined(__riscv)
#define NS_U32_WORD 0xFFFFFFFFFFFFFFFFULL
#else
#define NS_U32_WORD 0x00000000FFFFFFFFULL
#endif

/* One twin per width: the word the argument register held. */
unsigned long long ns_u8(unsigned long long v) { return v; }
unsigned long long ns_i8(unsigned long long v) { return v; }
unsigned long long ns_u16(unsigned long long v) { return v; }
unsigned long long ns_i16(unsigned long long v) { return v; }
unsigned long long ns_u32(unsigned long long v) { return v; }
unsigned long long ns_i32(unsigned long long v) { return v; }

/* The same symbol declared twice, narrow and wide, with the narrow parameter after a byte view -
 * so it is the fourth integer word, the shape the stdlib reported for `connect`. Each twin answers
 * 1 when it received the word its own ABI requires, so one expectation covers every target. */
long long ns_connect_u32(long long fd, const unsigned char *addr, unsigned long long addrlen,
                         unsigned long long len) {
  return (fd == 3) && (addr != 0) && (addrlen == 7) && (len == NS_U32_WORD);
}
long long ns_connect_u64(long long fd, const unsigned char *addr, unsigned long long addrlen,
                         unsigned long long len) {
  return (fd == 3) && (addr != 0) && (addrlen == 7) && (len == 0x00000000FFFFFFFFULL);
}

/* Results: the callee sets only the low bits of the result register, as a C function of that type
 * may, and Grail must re-extend from the declared width (the upper half is unspecified by every
 * one of these ABIs). */
unsigned int ns_ret_u32(void) { return 0x80000001u; }
int ns_ret_i32(void) { return -2147483647; }
unsigned short ns_ret_u16(void) { return 65535u; }
short ns_ret_i16(void) { return -3; }
unsigned char ns_ret_u8(void) { return 200u; }
signed char ns_ret_i8(void) { return -56; }

/* Narrow scalars inside a 16-byte record passed by value: one twin per field, so a field written or
 * read at the wrong offset or width changes that field's answer instead of cancelling out. */
struct ns_narrow {
  unsigned char a;
  signed char b;
  unsigned short c;
  short d;
  unsigned int e;
  int f;
};
long long ns_field_u8(struct ns_narrow v) { return v.a; }
long long ns_field_i8(struct ns_narrow v) { return v.b; }
long long ns_field_u16(struct ns_narrow v) { return v.c; }
long long ns_field_i16(struct ns_narrow v) { return v.d; }
long long ns_field_u32(struct ns_narrow v) { return v.e; }
long long ns_field_i32(struct ns_narrow v) { return v.f; }
