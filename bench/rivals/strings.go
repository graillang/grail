// Go twin of bench/strings.grl: fmt to build, strings.Split to cut, strconv to parse.
package main

import (
	"fmt"
	"strconv"
	"strings"
)

func xs(x uint64) uint64 {
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	return x
}

func main() {
	const n = 1000000
	var text strings.Builder
	var x uint64 = 88172645463325252
	for i := uint64(0); i < n; i++ {
		x = xs(x)
		a, b := x%100000, (x>>20)%100000
		fmt.Fprintf(&text, "k%d,%d,%d.%d%d\n", i, a, b/100, (b%100)/10, b%10)
	}
	var intSum uint64
	floatSum := 0.0
	var out strings.Builder
	for _, line := range strings.Split(text.String(), "\n") {
		if line == "" {
			continue
		}
		fields := strings.Split(line, ",")
		a, _ := strconv.ParseUint(fields[1], 10, 64)
		f, _ := strconv.ParseFloat(fields[2], 64)
		intSum += a
		floatSum = floatSum + f
		fmt.Fprintf(&out, "%d:%d;", a*2, len(fields[0]))
	}
	o := out.String()
	var h uint64 = 14695981039346656037
	for i := 0; i < len(o); i++ {
		h = (h ^ uint64(o[i])) * 1099511628211
	}
	fmt.Println(intSum, strconv.FormatFloat(floatSum, 'g', -1, 64), len(o), h)
}
