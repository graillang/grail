// Go twin of bench/chan.grl: Go's buffered chan (capacity 64; 1 for ping), goroutines, close() to end.
package main

import (
	"fmt"
	"os"
	"sync"
)

func spread(producers, consumers int, each uint64) uint64 {
	c := make(chan uint64, 64)
	var pw sync.WaitGroup
	for p := 0; p < producers; p++ {
		pw.Add(1)
		go func(p uint64) {
			defer pw.Done()
			for i := uint64(0); i < each; i++ {
				c <- p*1000000 + i + 1
			}
		}(uint64(p))
	}
	sums := make([]uint64, consumers)
	var cw sync.WaitGroup
	for q := 0; q < consumers; q++ {
		cw.Add(1)
		go func(q int) {
			defer cw.Done()
			for v := range c {
				sums[q] += v
			}
		}(q)
	}
	pw.Wait()
	close(c)
	cw.Wait()
	var total uint64
	for _, s := range sums {
		total += s
	}
	return total
}

func ping(rounds int) uint64 {
	there := make(chan uint64, 1)
	back := make(chan uint64, 1)
	done := make(chan struct{})
	go func() {
		for v := range there {
			back <- v + 1
		}
		close(done)
	}()
	var v uint64
	for i := 0; i < rounds; i++ {
		there <- v
		v = <-back
	}
	close(there)
	<-done
	return v
}

func main() {
	only := 0
	if e := os.Getenv("CHAN_CASE"); e != "" {
		only = int(e[0] - '0')
	}
	if only == 0 || only == 1 {
		fmt.Printf("1:1 %d\n", spread(1, 1, 400000))
	}
	if only == 0 || only == 2 {
		fmt.Printf("N:1 %d\n", spread(4, 1, 100000))
	}
	if only == 0 || only == 3 {
		fmt.Printf("N:M %d\n", spread(4, 4, 100000))
	}
	if only == 0 || only == 4 {
		fmt.Printf("ping %d\n", ping(100000))
	}
}
