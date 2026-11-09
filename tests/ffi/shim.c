#include <stddef.h>
/* Freestanding C shim for the Grail FFI tests.
 *
 * Deliberately links no libc and has no startup code: it proves that a Grail
 * program can call foreign code without pulling in a C runtime, and that the
 * declared symbol names, argument registers and result register match the C ABI
 * of x86-64, AArch64 and RISC-V 64, which share this integer slice.
 */
long long c_add(long long a, long long b) { return a + b; }
long long c_mul(long long a, long long b) { return a * b; }
long long c_negate(long long v) { return -v; }
unsigned long long c_identity(unsigned long long v) { return v; }
long long c_sum4(long long a, long long b, long long c, long long d) {
    return a + b + c + d;
}
/* Six arguments cover every integer argument register in all three ABIs. */
long long c_choose(long long a, long long b, long long c, long long d, long long e, long long f) {
    return a - b + c - d + e - f;
}

/* C string and byte views: (pointer, length) pairs and NUL-terminated pointers. */
long long c_strlen(const char *s) {
    long long n = 0;
    while (s[n] != 0) {
        n++;
    }
    return n;
}
long long c_sum_bytes(const unsigned char *p, unsigned long n) {
    long long total = 0;
    for (unsigned long i = 0; i < n; i++) {
        total += p[i];
    }
    return total;
}
long long c_fill(unsigned char *p, unsigned long n, unsigned char v) {
    for (unsigned long i = 0; i < n; i++) {
        p[i] = v;
    }
    return (long long)n;
}
/* Opaque handle round trip: C owns the meaning, Grail only carries the token. */
unsigned long long c_open(unsigned long long seed) { return (seed << 4) | 5; }
unsigned long long c_close(unsigned long long handle) { return handle & 1; }

/* C-layout records: the shim reads the fields Grail writes, and writes fields for
 * Grail to read, through the same pointer. Any layout disagreement changes the
 * sums, so this is a real offset/size check rather than a reflection query. */
struct point {
    long long x;
    long long y;
};
long long c_point_sum(const struct point *p) { return p->x + p->y; }
long long c_point_swap(struct point *p) {
    long long temporary = p->x;
    p->x = p->y;
    p->y = temporary;
    return p->x;
}

struct mixed {
    int a;
    short b;
    signed char c;
    long long d;
};
long long c_mixed_size(void) { return (long long)sizeof(struct mixed); }
long long c_mixed_off_a(void) { return (long long)offsetof(struct mixed, a); }
long long c_mixed_off_b(void) { return (long long)offsetof(struct mixed, b); }
long long c_mixed_off_c(void) { return (long long)offsetof(struct mixed, c); }
long long c_mixed_off_d(void) { return (long long)offsetof(struct mixed, d); }
long long c_mixed_sum(const struct mixed *m) { return m->a + m->b + m->c + m->d; }
long long c_mixed_fill(struct mixed *m, long long d) {
    m->a = 1234;
    m->b = -2;
    m->c = 7;
    m->d = d;
    return 0;
}

/* C-to-Grail callbacks. The shim clobbers every callee-saved integer register
 * around the callback, so a callback that fails to preserve rbx/r12-r15 returns
 * the sentinel instead of the expected value. */
typedef long long (*grail_callback)(long long);
long long c_apply(grail_callback callback, long long value) {
    return callback(value);
}
long long c_apply_preserving(grail_callback callback, long long value) {
#if defined(__x86_64__)
    register long long keep_bx __asm__("rbx") = 0x1234;
    register long long keep_12 __asm__("r12") = 0x2345;
    register long long keep_13 __asm__("r13") = 0x3456;
    register long long keep_14 __asm__("r14") = 0x4567;
    register long long keep_15 __asm__("r15") = 0x5678;
    long long result = callback(value);
    if (keep_bx != 0x1234 || keep_12 != 0x2345 || keep_13 != 0x3456 || keep_14 != 0x4567 || keep_15 != 0x5678) {
        return -1;
    }
    return result;
#else
    /* Other targets keep their own callee-saved set; the callback call itself is
     * still exercised, and the generated code preserves the registers it uses. */
    return callback(value);
#endif
}

#include "abi_shim.c"

/* ---- bare data pointers (CPtr / CMutPtr) ---- */
long long c_ptr_sum(const unsigned char *p, long long n) { long long s = 0; for (long long i = 0; i < n; i++) s += p[i]; return s; }
void c_ptr_fill(unsigned char *p, long long n, long long v) { for (long long i = 0; i < n; i++) p[i] = (unsigned char)(v + i); }
long long c_is_null(const void *p) { return p == 0; }
struct cbuf { const unsigned char *data; long long len; };
long long c_buf_sum(const struct cbuf *b) { return c_ptr_sum(b->data, b->len); }
