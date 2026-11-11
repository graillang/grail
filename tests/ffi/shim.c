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
#include "byval_shim.c"
#include "out_shim.c"
#include "words_shim.c"

/* ---- bare data pointers (CPtr / CMutPtr) ---- */
long long c_ptr_sum(const unsigned char *p, long long n) { long long s = 0; for (long long i = 0; i < n; i++) s += p[i]; return s; }
void c_ptr_fill(unsigned char *p, long long n, long long v) { for (long long i = 0; i < n; i++) p[i] = (unsigned char)(v + i); }
long long c_is_null(const void *p) { return p == 0; }
struct cbuf { const unsigned char *data; long long len; };
long long c_buf_sum(const struct cbuf *b) { return c_ptr_sum(b->data, b->len); }

/* ---- records reached through a pointer Grail owns (tests/ffi/record_pointers.grl) ----
 *
 * `cptr(&r)` hands C the address of r's own C-layout fields, which is what a create-info
 * struct needs when it points at another struct: `p_app` is a `const struct app_info *`
 * filled by Grail, not by C. */
struct app_info {
    unsigned api_version;
    unsigned flags;
};
struct create_info {
    unsigned s_type;
    unsigned pad;
    const struct app_info *p_app;
    const void *p_names;
    unsigned count;
};
long long c_create_info(const struct create_info *info) {
    return (long long)info->p_app->api_version + (long long)info->count + (long long)info->s_type;
}
long long c_app_version(const struct app_info *app) { return (long long)app->api_version; }

/* A `&mut` of an extern record that is a field of a plain Grail record: C must receive the address
 * of that record's own fields. The result reads both fields before writing them, so a pointer to
 * the container's field word (or to a proxy slot) produces a different checksum, and the write must
 * be visible to Grail afterwards in this field and in no other. */
struct field_pair { long long x, y; };
long long c_pair_write(struct field_pair *p, long long v) {
    long long seen = p->x * 100 + p->y;
    p->x = v;
    p->y = v + 1;
    return seen;
}

/* A record out-parameter: C writes the struct in place and leaves `flags` alone, so the caller's
 * zero-filled binding is what `flags` reads afterwards. The result is the value C found there. */
long long c_fill_app(struct app_info *app) {
    long long seen = (long long)app->flags;
    app->api_version = 4194304;
    return seen;
}

/* An array of handles: a fixed-capacity record of handle fields is the array, and its own
 * address is the `T *` C writes. */
struct handle_slots {
    unsigned s_type;
    unsigned pad;
    unsigned long long h0;
    unsigned long long h1;
    unsigned long long h2;
    unsigned long long h3;
};
long long c_alloc_handles(struct handle_slots *slots) {
    slots->h0 = 11;
    slots->h1 = 22;
    slots->h2 = 33;
    slots->h3 = 44;
    return 0;
}
long long c_sum_handles(const struct handle_slots *slots) {
    return (long long)(slots->h0 + slots->h1 + slots->h2 + slots->h3);
}
/* The handle the caller's array holds in slot 0, as a handle result: Grail compares it with the
 * field it read, which is the check that C's write landed in the storage Grail owns. */
unsigned long long c_slot0(const struct handle_slots *slots) { return slots->h0; }

/* An array of structs: the record's bytes are the array, and an element is an interior address. */
struct ref_pair {
    unsigned a;
    unsigned b;
};
struct ref_array {
    struct ref_pair first;
    struct ref_pair second;
};
long long c_ref_sum(const struct ref_pair *first, const struct ref_pair *second) {
    return (long long)(first->a + first->b + second->a + second->b);
}

/* Two declarations of one symbol, both taking the same count record: the regression case for the
 * exit-time abort the RHI work hit (docs/rhi.md). The two C-visible signatures differ, the C
 * function reads the record either way. */
struct count_record {
    unsigned s_type;
    unsigned count;
};
long long c_enum_count(const struct count_record *count) { return (long long)count->count; }

/* Callbacks with more arguments than the argument registers (tests/ffi/callback_stack.grl): ten
 * integers, ten doubles and four narrow/single values, so every target passes some on the stack,
 * and ten doubles before an integer, which RV64 spills into the integer registers first. */
typedef double (*cs_wide)(long, long, long, long, long, long, long, long, long, long,
                          double, double, double, double, double, double, double, double, double, double,
                          short, float, unsigned char, long);
double c_call_wide(cs_wide cb) {
  return cb(1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
            0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5,
            -3, 2.25f, 200, 11);
}
typedef double (*cs_floats)(double, double, double, double, double, double, double, double, double, double, long);
double c_call_floats(cs_floats cb) {
  return cb(0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 7);
}

/* Callbacks writing into a struct C passes by pointer (tests/ffi/callback_record_write.grl). The
 * guards around `p` catch a write that lands outside it; the checksum is computed by C after the
 * callback returns, so a write Grail kept in a private copy shows up as a wrong result. */
struct rw_point { int x; int y; double w; };
struct rw_frame { long before; struct rw_point p; long after; };
typedef int (*rw_cb)(struct rw_point *, int);
long c_call_record_write(rw_cb cb, int mode) {
  struct rw_frame f = {111, {4, 5, 0.5}, 222};
  int r = cb(&f.p, mode);
  if (f.before != 111 || f.after != 222) return -1;
  return (long)r * 100000 + (long)f.p.x * 1000 + (long)f.p.y * 10 + (long)(f.p.w * 4);
}
