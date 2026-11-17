// The cost of a foreign call: 10M calls of libc's `labs` through cgo, best of five rounds (twin of
// the gaps12-sched bench/ffi_call.c). Times to stderr, the checksum to stdout.
package main

/*
#include <stdlib.h>
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
			acc += int64(C.labs(C.long(i - 5000000)))
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
