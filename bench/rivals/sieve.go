// Sieve of Eratosthenes up to 50 million, three times; prints the prime count (twin of bench/sieve.c).
package main

import "fmt"

func main() {
	const n = 50000000
	count := 0
	for round := 0; round < 3; round++ {
		composite := make([]bool, n+1)
		count = 0
		for i := 2; i <= n; i++ {
			if !composite[i] {
				count++
				for j := i * i; j <= n; j += i {
					composite[j] = true
				}
			}
		}
	}
	fmt.Println(count)
}
