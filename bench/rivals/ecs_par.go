// Go twin of bench/ecs_par.grl: bench/rivals/ecs.go's update split into one static chunk per
// GOMAXPROCS goroutine each frame, joined with a WaitGroup - Go's plain way to run a loop on
// every core. GOMAXPROCS sets the workers; the sum is serial.
package main

import (
	"fmt"
	"runtime"
	"strconv"
	"sync"
)

func xs(x uint64) uint64 {
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	return x
}

func main() {
	const n = 1000000
	px, py, pz := make([]float32, n), make([]float32, n), make([]float32, n)
	vx, vy, vz := make([]float32, n), make([]float32, n), make([]float32, n)
	var x uint64 = 88172645463325252
	for i := 0; i < n; i++ {
		x = xs(x)
		px[i] = float32(int64(x%1000)) * 0.5
		py[i] = float32(int64((x>>10)%1000)) * 0.5
		pz[i] = float32(int64((x>>20)%1000)) * 0.5
		vx[i] = float32(int64((x>>30)%100)) * 0.01
		vy[i] = float32(int64((x>>40)%100)) * 0.01
		vz[i] = float32(int64((x>>50)%100)) * 0.01
	}
	var dt, damping, gravity float32 = 0.016, 0.999, 0.0981
	workers := runtime.GOMAXPROCS(0)
	chunk := (n + workers - 1) / workers
	for frame := 0; frame < 600; frame++ {
		var wg sync.WaitGroup
		for w := 0; w < workers; w++ {
			lo, hi := w*chunk, min((w+1)*chunk, n)
			wg.Add(1)
			go func(lo, hi int) {
				defer wg.Done()
				for i := lo; i < hi; i++ {
					vx[i] = vx[i] * damping
					vy[i] = vy[i]*damping - gravity*dt
					vz[i] = vz[i] * damping
					px[i] = px[i] + vx[i]*dt
					py[i] = py[i] + vy[i]*dt
					pz[i] = pz[i] + vz[i]*dt
				}
			}(lo, hi)
		}
		wg.Wait()
	}
	sum := 0.0
	for i := 0; i < n; i++ {
		sum = sum + float64(px[i]) + float64(py[i]) + float64(pz[i])
	}
	fmt.Println(strconv.FormatFloat(sum, 'g', -1, 64))
}
