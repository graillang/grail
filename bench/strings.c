// The C twin of bench/strings.grl: snprintf to build, a scan to split, strtoull and strtod to parse.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
typedef struct { char *p; size_t len, cap; } Buf;
static void put(Buf *b, const char *s, size_t n) {
    if (b->len + n > b->cap) { b->cap = (b->len + n) * 2; b->p = realloc(b->p, b->cap); }
    memcpy(b->p + b->len, s, n); b->len += n;
}
int main(void) {
    const uint64_t n = 1000000;
    Buf text = {0}, out = {0};
    char tmp[96];
    uint64_t x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) {
        x = xs(x);
        uint64_t a = x % 100000, b = (x >> 20) % 100000;
        int k = snprintf(tmp, sizeof tmp, "k%llu,%llu,%llu.%llu%llu\n", (unsigned long long)i, (unsigned long long)a,
                         (unsigned long long)(b / 100), (unsigned long long)((b % 100) / 10), (unsigned long long)(b % 10));
        put(&text, tmp, (size_t)k);
    }
    uint64_t int_sum = 0;
    double float_sum = 0;
    char *p = text.p, *end = text.p + text.len;
    while (p < end) {
        char *nl = memchr(p, '\n', (size_t)(end - p));
        if (!nl) nl = end;
        char *c1 = memchr(p, ',', (size_t)(nl - p)), *c2 = memchr(c1 + 1, ',', (size_t)(nl - c1 - 1));
        uint64_t a = strtoull(c1 + 1, NULL, 10);
        char save = *nl; *nl = 0;
        double f = strtod(c2 + 1, NULL);
        *nl = save;
        int_sum += a;
        float_sum = float_sum + f;
        int k = snprintf(tmp, sizeof tmp, "%llu:%zu;", (unsigned long long)(a * 2), (size_t)(c1 - p));
        put(&out, tmp, (size_t)k);
        p = nl + 1;
    }
    uint64_t h = 14695981039346656037ull;
    for (size_t i = 0; i < out.len; i++) h = (h ^ (unsigned char)out.p[i]) * 1099511628211ull;
    printf("%llu %.17g %zu %llu\n", (unsigned long long)int_sum, float_sum, out.len, (unsigned long long)h);
    return 0;
}
