/* abi_shim.c - C functions for the call_abi fixture: floats, narrow integers and stack arguments.
 * Included by shim.c on Linux and assembled alone for the Windows cases. */
#if defined(_WIN32)
/* MSVC-target code that touches floating point references _fltused, normally from the CRT;
 * the Windows test images link with /nodefaultlib, so the shim defines it. */
int _fltused = 0;
#endif

double c_fadd(double a, double b) { return a + b; }
/* 2^24 + 1 rounds back to 2^24 in binary32 but not in binary64: proves real f32 arithmetic. */
float c_fadd32(float a, float b) { return a + b; }
double c_mix(int a, double b, unsigned u, float f, long long g) { return a + b + u + f + g; }
/* Win64 passes the fifth and sixth arguments on the stack; SysV keeps them in xmm0/xmm1. */
double c_mix6(int a, int b, int c, int d, float e, double f)
{
    return a * 1000.0 + b * 100.0 + c * 10.0 + d + e + f;
}
/* Ten floats: two past the eight float registers (stack on SysV/AAPCS64, integer registers on RV64). */
double c_many_f(double a0, double a1, double a2, double a3, double a4, double a5, double a6,
                double a7, double a8, double a9)
{
    return a0 + 2 * a1 + 3 * a2 + 4 * a3 + 5 * a4 + 6 * a5 + 7 * a6 + 8 * a7 + 9 * a8 + 10 * a9;
}
long long c_many_i(long long a0, long long a1, long long a2, long long a3, long long a4,
                   long long a5, long long a6, long long a7, long long a8, long long a9)
{
    return a0 + 2 * a1 + 3 * a2 + 4 * a3 + 5 * a4 + 6 * a5 + 7 * a6 + 8 * a7 + 9 * a8 + 10 * a9;
}
int c_neg32(int x) { return -x; }
unsigned c_u32max(void) { return 0xFFFFFFFFu; }
signed char c_s8(signed char x) { return (signed char)(x - 1); }
unsigned short c_u16(unsigned short x) { return (unsigned short)(x + 1); }
/* RV64 callees may compare 32-bit arguments as sign-extended 64-bit words. */
int c_u32_above(unsigned x) { return x > 2147483648u; }

/* ---- record results: two registers, one register and a hidden result pointer ---- */
struct pair32 { int a; int b; };                  /* 8 bytes: rax / x0 / a0 everywhere */
struct span16 { long long start; long long len; }; /* 16 bytes: rax:rdx, x0:x1, a0:a1; Win64 sret */
struct triple { long long x; long long y; int z; }; /* 24 bytes: hidden result pointer */
struct pair32 c_make_pair(int a, int b) { struct pair32 r = { a, b }; return r; }
struct span16 c_make_span(long long start, long long len) { struct span16 r = { start, len }; return r; }
struct triple c_make_triple(long long x, long long y, int z, double scale)
{
    struct triple r = { (long long)(x * scale), y, z };
    return r;
}
