#include <stdint.h>
typedef struct { int64_t a, b; } Pair16;
int64_t c_pair_sum(Pair16 p) { return p.a * 1000 + p.b; }
int64_t c_bump(int64_t v) { return v + 1; }
