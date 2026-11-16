// 256x256 f32 matrix multiply, 20 times; prints a checksum of the result (twin of bench/matmul.c).
package main

import "fmt"

func main() {
	const n = 256
	a := make([]float32, n*n)
	b := make([]float32, n*n)
	c := make([]float32, n*n)
	for i := 0; i < n*n; i++ {
		a[i] = float32(i%7) * 0.25
		b[i] = float32(i%11) * 0.5
	}
	for round := 0; round < 20; round++ {
		for i := 0; i < n; i++ {
			for j := 0; j < n; j++ {
				var s float32
				for k := 0; k < n; k++ {
					s = s + a[i*n+k]*b[k*n+j]
				}
				c[i*n+j] = s
			}
		}
	}
	sum := 0.0
	for i := 0; i < n*n; i++ {
		sum += float64(c[i])
	}
	fmt.Println(sum)
}
