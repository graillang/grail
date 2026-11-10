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
