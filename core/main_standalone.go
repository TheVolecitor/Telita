//go:build !android
// +build !android

package main

import (
	"io"
	"os"
)

func main() {
	// Monitor Stdin: when the parent Flutter app dies, the stdin pipe breaks (EOF).
	// This ensures libcore.exe exits automatically and prevents zombie processes.
	go func() {
		io.Copy(io.Discard, os.Stdin)
		os.Exit(0)
	}()

	RunServer()
}
