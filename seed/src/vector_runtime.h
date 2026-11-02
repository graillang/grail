/* Trusted capacity arithmetic only; element movement and destruction are emitted per checked type. */
static void gr_vec_reserve(ga *v, size_t size) {
    if (!size || v->n == UINT64_MAX || v->n >= SIZE_MAX / size) abort();
    uint64_t needed = v->n + 1;
    if (needed <= v->c) return;
    uint64_t limit = SIZE_MAX / size;
    uint64_t capacity = v->c ? v->c : (limit < 8 ? limit : 8);
    while (capacity < needed) {
        if (capacity > limit / 2) { capacity = needed; break; }
        capacity *= 2;
    }
    void *p = realloc(v->p, (size_t)capacity * size);
    if (!p) abort();
    v->p = p; v->c = capacity;
}
