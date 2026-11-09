/* abi_shim.c - C functions for the call_abi fixture: floats, narrow integers and stack arguments.
 * Included by shim.c on Linux and assembled alone for the Windows cases. */
#if defined(_WIN32)
/* MSVC-target code that touches floating point references _fltused, normally from the CRT;
 * the Windows test images link with /nodefaultlib, so the shim defines it. */
int _fltused = 0;
/* Aggregate initialisers may lower to memset, which the CRT normally provides. */
void *memset(void *d, int c, unsigned long long n)
{
    unsigned char *p = (unsigned char *)d;
    while (n--) *p++ = (unsigned char)c;
    return d;
}
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

/* ---- variadic: a C function that reads its arguments with va_arg ---- */
#include <stdarg.h>
long long c_vsum(int count, ...)
{
    va_list ap;
    long long total = 0;
    va_start(ap, count);
    for (int i = 0; i < count; ++i)
        total += va_arg(ap, long long);
    va_end(ap);
    return total;
}
/* Mixed: a format of 'i' (long long) and 'd' (double) codes. Doubles cross variadically in
 * vector registers (SysV, AAPCS64), integer registers (RV64), or both (Win64). */
double c_vmix(const char *kinds, ...)
{
    va_list ap;
    double total = 0;
    va_start(ap, kinds);
    for (const char *k = kinds; *k; ++k)
        total += *k == 'd' ? va_arg(ap, double) : (double)va_arg(ap, long long);
    va_end(ap);
    return total;
}

/* ---- a COM-shaped object: the first word is a vtable of method pointers taking `self` ---- */
struct fake_com { void **vtbl; long long base; };
static long long fake_add(struct fake_com *self, long long a) { return self->base + a; }
static long long fake_many(struct fake_com *self, long long a, long long b, long long c, double d,
                           long long e, float f, long long g)
{
    return self->base + a + b + c + (long long)(d * 10) + e + (long long)(f * 100) + g;
}
static void *fake_vtbl[] = { (void *)fake_add, (void *)fake_many };
static struct fake_com fake_obj = { fake_vtbl, 1000 };
void *c_com_object(void) { return &fake_obj; }
void *c_com_slot(void *obj, long long index) { return (*(void ***)obj)[index]; }

/* ---- records with float fields, by pointer: a viewport-shaped struct (cf. D3D12_VIEWPORT) ---- */
struct viewport { float x, y, width, height; float min_depth, max_depth; int flags; double scale; };
double c_viewport_area(const struct viewport *v)
{
    return (double)v->width * v->height * v->scale + v->flags + v->min_depth + v->max_depth;
}
void c_viewport_fill(struct viewport *v)
{
    v->x = 1.5f; v->y = -2.25f; v->width = 640; v->height = 480;
    v->min_depth = 0.0f; v->max_depth = 1.0f; v->flags = 7; v->scale = 0.125;
}

/* ---- C calling Grail callbacks with floats and narrow integers ---- */
double c_call_fmix(double (*cb)(double, signed char, float, unsigned short, long long, float))
{
    /* Mixed classes: on SysV/AAPCS/RV the integers pack into the integer registers and the
     * floats into the vector registers; on Win64 every argument keeps its position (the sixth,
     * a float, goes on the stack). Garbage in the upper bits of the narrow integers is legal
     * C caller behaviour, so the callee must extend them itself. */
    return cb(1.5, (signed char)-3, 0.25f, (unsigned short)65000, 1000000LL, -2.5f);
}
float c_call_f32(float (*cb)(float, float))
{
    return cb(1.25f, 2.5f) * 2.0f;
}

/* ---- records with float fields returned by value: each shape takes a different path ----
 * vec2  {f32,f32}       SysV xmm0 | AAPCS HFA s0,s1 | RV fa0,fa1 | Win64 rax
 * vec3d {f64,f64,f64}   SysV sret | AAPCS HFA d0-d2 | RV sret    | Win64 sret
 * fi    {f32,i32}       SysV rax  | AAPCS x0        | RV fa0+a0  | Win64 rax
 * di    {f64,i64}       SysV xmm0,rax | AAPCS x0,x1 | RV fa0+a0  | Win64 sret
 * quad  {f32 x4}        SysV xmm0,xmm1 | AAPCS HFA s0-s3 | RV a0,a1 | Win64 sret */
struct vec2 { float x, y; };
struct vec3d { double x, y, z; };
struct fi { float f; int i; };
struct di { double d; long long i; };
struct quad { float a, b, c, d; };
struct vec2 c_vec2(float x, float y) { struct vec2 r = { x, y }; return r; }
struct vec3d c_vec3d(double s) { struct vec3d r = { s, s * 2, s * 3 }; return r; }
struct fi c_fi(float f, int i) { struct fi r = { f, i }; return r; }
struct di c_di(double d, long long i) { struct di r = { d, i }; return r; }
struct quad c_quad(float s) { struct quad r = { s, s + 1, s + 2, s + 3 }; return r; }

/* ---- nested records: C embeds the inner struct's bytes at its aligned offset ---- */
struct inner2 { short a; long long b; };            /* 16 bytes, align 8 */
struct outer2 { char tag; struct inner2 in; int tail; struct inner2 last; };
long long c_outer_sum(const struct outer2 *o) { return o->tag + o->in.a + o->in.b + o->tail + o->last.a + o->last.b; }
void c_outer_fill(struct outer2 *o) { o->tag = 3; o->in.a = -7; o->in.b = 100000000000LL; o->tail = 42; o->last.a = 9; o->last.b = -5; }
long long c_outer_size(void) { return (long long)sizeof(struct outer2) * 1000 + (long long)__builtin_offsetof(struct outer2, in) * 100 + (long long)__builtin_offsetof(struct outer2, tail) * 10 + (long long)(__builtin_offsetof(struct outer2, last) / 8); }
struct pair_in { int x; int y; };
struct wrap { struct pair_in p; long long z; };
struct wrap c_make_wrap(int x, int y) { struct wrap w = { { x, y }, (long long)x * y }; return w; }
