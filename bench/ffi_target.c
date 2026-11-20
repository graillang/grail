// Real non-builtin foreign function target for bench/ffi_call: compiled to a separate object archive
// (.work/libffi_target.a) and linked without LTO so no compiler (including Grail-LLVM's clang -O2
// pass) can recognize it as a libc builtin and inline away the ABI boundary call.
#include <stdint.h>

int64_t grail_bench_abs(int64_t x) {
    return x < 0 ? -x : x;
}
