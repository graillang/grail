/* Homogeneous float aggregates of doubles, by value both ways (tests/ffi/hfa_records.grl).
 *   hd2  two doubles   SysV xmm0,xmm1; AAPCS64 HFA d0,d1; Win64 16 bytes: by reference; RV64 fa0,fa1
 *   hd4  four doubles  SysV memory; AAPCS64 HFA d0-d3 even at 32 bytes; Win64 by reference;
 *                      RV64 over 16 bytes: by reference
 * Results: hd2 in xmm0:xmm1 / d0,d1 / a hidden pointer on Win64; hd4 through the hidden result
 * pointer (x8 on AAPCS64) except AAPCS64, which returns an HFA of four in d0-d3. */
struct hd2 { double a, b; };
struct hd4 { double a, b, c, d; };
long long c_hfa_d2(struct hd2 s) { return (long long)(s.a * 10.0 + s.b); }
long long c_hfa_d4(struct hd4 s) { return (long long)(s.a * 1000.0 + s.b * 100.0 + s.c * 10.0 + s.d); }
long long c_hfa_d4_after(long long k, struct hd4 s, double t)
{
    return k * 100000 + (long long)(s.a * 1000.0 + s.b * 100.0 + s.c * 10.0 + s.d + t);
}
struct hd2 c_hfa_ret_d2(double x) { struct hd2 r = { x, x * 2.0 }; return r; }
struct hd4 c_hfa_ret_d4(double x) { struct hd4 r = { x, x + 1.0, x + 2.0, x + 3.0 }; return r; }
