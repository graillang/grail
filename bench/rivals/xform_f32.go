// x[i] = x[i] * a + y[i] over one million float32, 200 passes; prints the sum (twin of bench/xform_f32.c).
package main

import "fmt"

//go:noinline
func scaleAdd(x, y []float32, a float32) {
	for i := range x {
		x[i] = x[i]*a + y[i]
	}
}

func main() {
	const n = 1000000
	x := make([]float32, 0, n)
	y := make([]float32, 0, n)
	var xv, yv float32
	for i := 0; i < n; i++ {
		x = append(x, xv)
		y = append(y, yv)
		xv = xv + 0.5
		if 3.0 < xv {
			xv = 0
		}
		yv = yv + 0.25
		if 1.0 < yv {
			yv = 0
		}
	}
	var a float32 = 0.999
	for pass := 0; pass < 200; pass++ {
		scaleAdd(x, y, a)
		a = 0.999 - x[pass]*0.000000001
	}
	sum := 0.0
	for i := 0; i < n; i++ {
		sum += float64(x[i])
	}
	fmt.Println(sum)
}
