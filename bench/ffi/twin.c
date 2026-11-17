#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
typedef struct { int64_t a, b; } Bv16;
typedef struct { double d; int64_t i; } BvMd;
typedef struct { int64_t a, b, c; } Bv24;
int64_t c_add3(int64_t, int64_t, int64_t); int64_t c_byval16(Bv16); int64_t c_byval_md(BvMd); int64_t c_byval24(Bv24);
Bv16 c_make16(int64_t, int64_t); double c_fma(double, double, double); float c_fmaf(float, float, float);
int64_t c_sum_view(const unsigned char *, uint64_t); int64_t c_apply(int64_t (*)(int64_t), int64_t); int64_t c_loop(int64_t (*)(int64_t), int64_t);
int64_t cb(int64_t v) { return v + 1; }
int main(int argc, char **argv) {
  int which = atoi(argv[1]); int64_t n = 10000000, t = 0; double d = 0; float f = 0; unsigned char buf[16] = {3};
  for (int64_t i = 0; i < n; i++) {
    switch (which) {
      case 0: t ^= i; break;
      case 1: t = c_add3(i, t & 1023, 1); break;
      case 2: { Bv16 s = {i, t & 1023}; t = c_byval16(s); break; }
      case 3: { BvMd s = {(double)i, t & 1023}; t = c_byval_md(s); break; }
      case 4: { Bv24 s = {i, t & 1023, 1}; t = c_byval24(s); break; }
      case 5: { Bv16 r = c_make16(i, t & 1023); t = r.a ^ r.b; break; }
      case 6: d = c_fma(d, 0.5, 1.0); break;
      case 7: f = c_fmaf(f, 0.5f, 1.0f); break;
      case 8: t ^= c_sum_view(buf, 16); break;
      case 9: t ^= c_apply(cb, i); break;
    }
  }
  if (which == 10) t = c_loop(cb, n);
  printf("%lld %f %f\n", (long long)t, d, (double)f);
}
