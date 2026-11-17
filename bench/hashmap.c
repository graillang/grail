// The C twin of bench/hashmap.grl. C has no standard hash map: this is the open-addressing table
// with linear probing and tombstones a C program writes for itself (a multiplicative hash).
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
typedef struct { uint64_t *keys, *vals; unsigned char *state; size_t cap, len, used; } Map;
static size_t slot_of(const Map *m, uint64_t k) { return (size_t)((k * 0x9E3779B97F4A7C15ull) >> 1) & (m->cap - 1); }
static void grow(Map *m);
static void put(Map *m, uint64_t k, uint64_t v) {
    if ((m->used + 1) * 4 > m->cap * 3) grow(m);
    size_t i = slot_of(m, k), tomb = (size_t)-1;
    for (;; i = (i + 1) & (m->cap - 1)) {
        if (m->state[i] == 0) break;
        if (m->state[i] == 2) { if (tomb == (size_t)-1) tomb = i; continue; }
        if (m->keys[i] == k) { m->vals[i] = v; return; }
    }
    if (tomb != (size_t)-1) i = tomb; else m->used++;
    m->keys[i] = k; m->vals[i] = v; m->state[i] = 1; m->len++;
}
static void grow(Map *m) {
    Map old = *m;
    m->cap = old.cap ? old.cap * 2 : 16;
    m->keys = malloc(m->cap * 8); m->vals = malloc(m->cap * 8); m->state = calloc(m->cap, 1);
    m->len = 0; m->used = 0;
    for (size_t i = 0; i < old.cap; i++) if (old.state[i] == 1) put(m, old.keys[i], old.vals[i]);
    free(old.keys); free(old.vals); free(old.state);
}
static uint64_t *get(const Map *m, uint64_t k) {
    if (!m->cap) return NULL;
    for (size_t i = slot_of(m, k);; i = (i + 1) & (m->cap - 1)) {
        if (m->state[i] == 0) return NULL;
        if (m->state[i] == 1 && m->keys[i] == k) return &m->vals[i];
    }
}
static int del(Map *m, uint64_t k, uint64_t *out) {
    if (!m->cap) return 0;
    for (size_t i = slot_of(m, k);; i = (i + 1) & (m->cap - 1)) {
        if (m->state[i] == 0) return 0;
        if (m->state[i] == 1 && m->keys[i] == k) { *out = m->vals[i]; m->state[i] = 2; m->len--; return 1; }
    }
}
int main(void) {
    const uint64_t n = 1000000;
    Map m = {0};
    uint64_t *keys = malloc(n * 8), x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) { x = xs(x); keys[i] = x; put(&m, x, i); }
    uint64_t sum = 0, removed = 0, found = 0, v;
    for (uint64_t i = 0; i < n; i++) { uint64_t *p = get(&m, keys[i]); if (p) sum += *p; }
    for (uint64_t i = 0; i < n; i += 2) if (del(&m, keys[i], &v)) removed += v;
    for (uint64_t i = 0; i < n; i++) if (get(&m, keys[i])) found++;
    printf("%llu %llu %llu %llu\n", (unsigned long long)sum, (unsigned long long)removed, (unsigned long long)found, (unsigned long long)m.len);
    return 0;
}
