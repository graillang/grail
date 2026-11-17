// Sieve of Eratosthenes up to 50 million, three rounds; prints the sum of the prime counts
// (twin of bench/sieve.c; each round's limit depends on the previous round's count).
package main

import "fmt"

func main() {
	const n = 50000000
	count, total := 0, 0
	for round := 0; round < 3; round++ {
		limit := n - (count & 1)
		composite := make([]bool, limit+1)
		count = 0
		for i := 2; i <= limit; i++ {
			if !composite[i] {
				count++
				for j := i * i; j <= limit; j += i {
					composite[j] = true
				}
			}
		}
		total += count
	}
	fmt.Println(total)
}
