// Go twin of bench/json.grl: encoding/json into any (numbers are float64, as Go decodes them).
package main

import (
	"encoding/json"
	"fmt"
	"strings"
)

type totals struct{ ints, strings, nodes uint64 }

func walk(v any, t *totals) {
	t.nodes++
	switch x := v.(type) {
	case float64:
		if x == float64(int64(x)) {
			t.ints += uint64(int64(x))
		}
	case string:
		t.strings += uint64(len(x))
	case []any:
		for _, item := range x {
			walk(item, t)
		}
	case map[string]any:
		for k, item := range x {
			t.strings += uint64(len(k))
			walk(item, t)
		}
	}
}

func main() {
	const n = 92000
	var text strings.Builder
	text.WriteString("{\"items\":[")
	for i := 0; i < n; i++ {
		if i > 0 {
			text.WriteString(",")
		}
		text.WriteString("{\"id\":")
		fmt.Fprintf(&text, "%d,\"name\":\"item%d\",\"tags\":[\"t%d\",\"u%d\"],\"value\":%d,\"nested\":", i, i, i%7, i%13, i*37%100003)
		text.WriteString("{\"a\":")
		fmt.Fprintf(&text, "%d,\"b\":[1,2,3],\"label\":\"n%d\"", i%100, i%1000)
		text.WriteString("}}")
	}
	text.WriteString("]}")
	s := text.String()
	var doc any
	if err := json.Unmarshal([]byte(s), &doc); err != nil {
		panic(err)
	}
	var t totals
	walk(doc, &t)
	out, err := json.Marshal(doc)
	if err != nil {
		panic(err)
	}
	fmt.Println(len(s), t.nodes, t.ints, t.strings, len(out))
}
