/* __m256 by value (docs/design/simd.md, S4c): in ymm registers only when both sides are built for AVX,
 * so this file is its own object, compiled with -mavx (tools/test-ffi.mjs), and the Grail fixture is
 * built with --cpu=x86-64-v3. A function-level target("avx") does not change clang's calling convention
 * for a translation unit built without AVX: such a callee reads __m256 arguments from the stack. */
#include <immintrin.h>
/* 256 bits: in ymm registers when the caller and callee are built for AVX. */
__m256 c_vec8_add(__m256 a, __m256 b) { return _mm256_add_ps(a, b); }
float c_vec8_sum(__m256 a) {
    float f[8];
    _mm256_storeu_ps(f, a);
    float t = 0;
    for (int i = 0; i < 8; i++) t += f[i] * (float)(i + 1);
    return t;
}
