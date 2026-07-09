package main

import (
	"fmt"
	"strings"
)

func parseYpartLine(line string) (int64, int64, error) {
	beginIdx := strings.Index(line, "begin=")
	if beginIdx == -1 {
		return 0, 0, fmt.Errorf("no begin in =ypart")
	}
	endIdx := strings.Index(line, "end=")
	if endIdx == -1 {
		return 0, 0, fmt.Errorf("no end in =ypart")
	}

	var begin, end int64
	_, err := fmt.Sscanf(line[beginIdx:], "begin=%d", &begin)
	if err != nil {
		return 0, 0, err
	}
	_, err = fmt.Sscanf(line[endIdx:], "end=%d", &end)
	if err != nil {
		return 0, 0, err
	}
	return begin - 1, end, nil // convert to 0-indexed
}

func main() {
	line := "=ypart begin=114417965 end=115134764"
	b, e, err := parseYpartLine(line)
	fmt.Printf("b: %d, e: %d, err: %v\n", b, e, err)
}
