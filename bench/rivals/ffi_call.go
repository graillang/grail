// The cost of a foreign call: 10M calls of the separately compiled C function grail_bench_abs
// (bench/ffi_target.c -> .work/libffi_target.a) through cgo, best of five rounds.
package main

/*
#include <stdint.h>
extern int64_t grail_bench_abs(int64_t x);
*/
import "C"

import (
	"fmt"
	"os"
	"time"
)

func main() {
	const n = 10000000
	var acc int64
	best := time.Duration(1 << 62)
	for round := 0; round < 5; round++ {
		t0 := time.Now()
		for i := int64(0); i < n; i++ {
			acc += int64(C.grail_bench_abs(C.int64_t(i - 5000000)))
		}
		best = min(best, time.Since(t0))
	}
	bare := time.Duration(1 << 62)
	for round := 0; round < 5; round++ {
		t0 := time.Now()
		for i := int64(0); i < n; i++ {
			acc += i - 5000000
		}
		bare = min(bare, time.Since(t0))
	}
	fmt.Fprintf(os.Stderr, "ffi_call %d ps\n", best.Microseconds()*1000000/n)
	fmt.Fprintf(os.Stderr, "ffi_call_only %d ps\n", max(best-bare, 0).Microseconds()*1000000/n)
	fmt.Printf("checksum %d\n", acc)
}
