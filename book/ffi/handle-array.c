/* The C half of the book's handle-array example. Freestanding: no libc, no headers. */
struct command_buffers {
    unsigned long long b0;
    unsigned long long b1;
    unsigned long long b2;
    unsigned long long b3;
};
/* C allocates four command buffers - opaque tokens Grail never constructs - and writes them into
   the record the caller owns. */
long long c_alloc_buffers(struct command_buffers *out) {
    out->b0 = 4097;
    out->b1 = 4098;
    out->b2 = 4099;
    out->b3 = 4100;
    return 4;
}
/* C reads the array back through a pointer to the same record. */
long long c_sum_buffers(const struct command_buffers *in) {
    return (long long)in->b0 + (long long)in->b1 + (long long)in->b2 + (long long)in->b3;
}
/* One handle, handed back, so the caller can compare it with the one it read out of the array. */
unsigned long long c_first(const struct command_buffers *in) {
    return in->b0;
}
