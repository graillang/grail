/* Argument-register exhaustion and indirect results (tests/ffi/abi_edges.grl). Each function
 * weighs its arguments by position, so an argument read from the wrong register or stack slot
 * changes the result.
 *   c_fp_spill     7 doubles, then a two-double HFA, then a double. AAPCS64: the HFA needs two
 *                  v registers and only d7 is left, so it goes on the stack and so does the
 *                  trailing double (NSRN = 8 after an HFA spills). SysV: the record goes to memory
 *                  but the trailing double still takes xmm7. Win64: 16 bytes, by reference.
 *   c_fp_spill8    8 doubles, then a two-float HFA: no v register is left (AAPCS64 stack; SysV memory;
 *                  Win64: 8 bytes, in its positional stack slot).
 *   c_int_spill5   5 integers, a 16-byte integer record, an integer. SysV: the record needs two
 *                  registers and only r9 is left, so it goes to memory and the trailing integer takes
 *                  r9. AAPCS64: x5:x6, then x7.
 *   c_int_spill7   7 integers, a 16-byte record, an integer. AAPCS64: only x7 is left: the record
 *                  and the trailing integer go on the stack (NGRN = 8).
 *   c_ret24_8      eight integers and a 24-byte result: x8 on AAPCS64 (not an argument register),
 *                  rdi on SysV and rcx on Win64 (shifting every integer argument by one). */
struct ed_d2 { double a, b; };
struct ed_f2 { float a, b; };
struct ed_i2 { long long a, b; };
struct ed_r24 { long long x, y, z; };

long long c_fp_spill(double d0, double d1, double d2, double d3, double d4, double d5, double d6,
                     struct ed_d2 s, double t)
{
    double v = d0 + d1 * 2 + d2 * 3 + d3 * 4 + d4 * 5 + d5 * 6 + d6 * 7;
    return (long long)(v * 1000.0) + (long long)(s.a * 100.0 + s.b * 10.0 + t);
}
long long c_fp_spill8(double d0, double d1, double d2, double d3, double d4, double d5, double d6,
                      double d7, struct ed_f2 s)
{
    double v = d0 + d1 * 2 + d2 * 3 + d3 * 4 + d4 * 5 + d5 * 6 + d6 * 7 + d7 * 8;
    return (long long)(v * 1000.0) + (long long)(s.a * 10.0f + s.b);
}
long long c_int_spill5(long long a, long long b, long long c, long long d, long long e,
                       struct ed_i2 s, long long t)
{
    return a + b * 2 + c * 3 + d * 4 + e * 5 + s.a * 1000 + s.b * 100000 + t * 10000000;
}
long long c_int_spill7(long long a, long long b, long long c, long long d, long long e,
                       long long f, long long g, struct ed_i2 s, long long t)
{
    return a + b * 2 + c * 3 + d * 4 + e * 5 + f * 6 + g * 7 + s.a * 1000 + s.b * 100000 + t * 10000000;
}
struct ed_r24 c_ret24_8(long long a, long long b, long long c, long long d, long long e,
                        long long f, long long g, long long h)
{
    struct ed_r24 r = { a + b * 10 + c * 100 + d * 1000, e + f * 10 + g * 100 + h * 1000, a * h };
    return r;
}
