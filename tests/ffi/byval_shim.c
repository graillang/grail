/* byval_shim.c - C twins for records passed by value (`v: byval R`, decision B7).
 * Included by shim.c. Every function computes a checksum over all of the struct's fields, with a
 * distinct weight per field, so a misplaced eightbyte, register or stack slot changes the result
 * instead of accidentally cancelling out. The shapes are chosen so each target's rule is exercised:
 *
 *   bv4    4 bytes      INTEGER register
 *   bv8    8 bytes      one register, both fields packed
 *   bv16   16 bytes     two integer registers
 *   bv24   24 bytes     SysV: the caller's stack; AAPCS64 and RV64: by reference
 *   bvmix  int + float  SysV/AAPCS64: one INTEGER register; RV64: a0 + fa0
 *   bvmd   double + long long    SysV: xmm0 + rdi; AAPCS64: x0,x1; RV64: fa0 + a0
 *   bv2f   float + float        ImVec2-shaped: SysV xmm0; AAPCS64 HFA s0,s1; RV64 fa0,fa1
 *   bvarr  int[4]       an embedded array, 16 bytes: two registers or by reference
 */
struct bv4 { int a; };
struct bv8 { int a; int b; };
struct bv16 { long long a; long long b; };
struct bv24 { long long a; long long b; long long c; };
struct bvmix { int i; float f; };
struct bvmd { double d; long long i; };
struct bv2f { float x, y; };
struct bvarr { int v[4]; };
struct bv4f { float a, b, c, d; }; /* 16 bytes: a homogeneous float aggregate of four fields */

long long c_byval4(struct bv4 s) { return (long long)s.a * 3; }
long long c_byval8(struct bv8 s) { return (long long)s.a + (long long)s.b * 1000; }
long long c_byval16(struct bv16 s) { return s.a + s.b * 1000; }
long long c_byval24(struct bv24 s) { return s.a + s.b * 1000 + s.c * 1000000; }
long long c_byval_mix(struct bvmix s) { return (long long)s.i * 1000 + (long long)(s.f * 4.0f); }
long long c_byval_md(struct bvmd s) { return (long long)(s.d * 10.0) + s.i * 1000; }
long long c_byval_2f(struct bv2f s)
{
    return (long long)(s.x * 100.0f) + (long long)(s.y * 10000.0f);
}
long long c_byval_arr(struct bvarr s)
{
    return (long long)s.v[0] + (long long)s.v[1] * 10 + (long long)s.v[2] * 100 +
           (long long)s.v[3] * 1000;
}
long long c_byval_4f(struct bv4f s)
{
    return (long long)s.a + (long long)(s.b * 10.0f) + (long long)(s.c * 100.0f) +
           (long long)(s.d * 1000.0f);
}
/* A byval record between other arguments: its placement must not disturb either register file. */
long long c_byval_after(long long pre, struct bv16 s, double post)
{
    return pre + (s.a + s.b * 1000) + (long long)(post * 2.0);
}
/* Two byval records in one call, one integer-shaped and one float-shaped. */
long long c_byval_two(struct bv8 a, struct bv2f b)
{
    return (long long)a.a + (long long)a.b * 10 + (long long)b.x + (long long)b.y * 100;
}
/* The address of the same kind of function, so Grail can call it through a `cfn` whose signature
 * declares a byval parameter. */
long long c_byval_ref16(struct bv16 s) { return s.a * 1000000 + s.b; }
void *c_byval_slot(void) { return (void *)&c_byval_ref16; }
/* A byval record after six integer arguments: SysV puts it in the outgoing stack area after the
 * registers, AAPCS64 and RV64 pass it by reference in the register that is left. */
long long c_byval_tail(long long a, long long b, long long c, long long d, long long e, long long f,
                       struct bv24 s)
{
    return a + b * 10 + c * 100 + d * 1000 + e * 10000 + f * 100000 + s.a + s.b * 1000 +
           s.c * 1000000;
}
/* A byval record that lands in the stack area followed by a scalar that must not overwrite it. */
long long c_byval_mix_stack(long long a0, long long a1, long long a2, long long a3, long long a4,
                            long long a5, struct bv8 s, long long g)
{
    return a0 + a1 * 10 + a2 * 100 + a3 * 1000 + a4 * 10000 + a5 * 100000 + s.a + s.b * 1000 +
           g * 10000000;
}
/* ---- 12- and 40-byte records, a callee that writes its copy, and records returned by value ---- */
/* 12 bytes is the smallest size that is neither a power of two nor a whole number of eightbyte
 * register words: SysV packs it into two INTEGER eightbytes (the last one 4 bytes wide), AAPCS64
 * passes it in two x registers, Win64 and RV64 pass it by reference because it is not 1/2/4/8
 * bytes (Win64) or because it is over 2*XLEN (RV64). */
struct bv12 { int a; int b; int c; };
/* 40 bytes: both integer register files are out of eightbytes even from a cold start, so SysV
 * uses MEMORY, AAPCS64 and RV64 pass by reference, and Win64 passes by reference. */
struct bv40 { long long a, b, c, d, e; };
/* A 12-byte record whose fields are floats: an AAPCS64 homogeneous float aggregate of three
 * fields in v0-v2, a SysV SSE eightbyte plus an INTEGER one, by reference on Win64. */
struct bv3f { float a, b, c; };

long long c_byval12(struct bv12 s)
{
    return (long long)s.a + (long long)s.b * 1000 + (long long)s.c * 1000000;
}
long long c_byval40(struct bv40 s)
{
    return s.a + s.b * 10 + s.c * 100 + s.d * 1000 + s.e * 10000;
}
long long c_byval_3f(struct bv3f s)
{
    return (long long)(s.a * 100.0f) + (long long)(s.b * 10000.0f) + (long long)(s.c * 1000000.0f);
}
/* The callee mutates its own copy: none of it may reach the caller's record, which the caller
 * checks after the call, and the checksum proves the callee received real field values first. */
long long c_byval_mutate(struct bv16 s)
{
    long long sum = s.a + s.b * 1000;
    s.a = -7;
    s.b = -9;
    return sum;
}
/* Records returned by value, one per size class of the byval shapes above. */
struct bv4 c_bv_ret4(void) { struct bv4 r = { 17 }; return r; }
struct bv12 c_bv_ret12(long long seed)
{
    struct bv12 r = { (int)seed, (int)(seed + 1), (int)(seed + 2) };
    return r;
}
struct bv16 c_bv_ret16(long long a, long long b) { struct bv16 r = { a, b }; return r; }
struct bv24 c_bv_ret24(long long a)
{
    struct bv24 r = { a, a * 2, a * 3 };
    return r;
}
struct bv40 c_bv_ret40(long long seed)
{
    struct bv40 r = { seed, seed + 1, seed + 2, seed + 3, seed + 4 };
    return r;
}
/* Both directions in one call: a record arrives by value and a record goes back by value. On Win64
 * the argument is a pointer to a caller copy and the result a hidden result pointer, so the two
 * address registers are live at once. */
struct bv12 c_bv_roundtrip12(struct bv12 s)
{
    struct bv12 r = { s.c, s.b, s.a };
    return r;
}
struct bv40 c_bv_roundtrip40(struct bv40 s)
{
    struct bv40 r = { s.e, s.d, s.c, s.b, s.a };
    return r;
}
