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
