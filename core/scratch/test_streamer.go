package main

import (
	"io"
	"log"
	"os"
	"time"

	"github.com/cinekernel/core/pkg/nntpstream"
)

func main() {
	log.Println("Initializing NNTP Pool...")
	pool, err := nntpstream.NewPool(nntpstream.Config{
		Host:        "nntp.torbox.app",
		Port:        563,
		Username:    "872bd23e-a69c-4c0c-91c5-10b42678e491",
		Password:    "8yw0TgDNcRt5zVFJsx0YMQ",
		Connections: 2,
	})
	if err != nil {
		log.Fatalf("Pool init failed: %v", err)
	}
	defer pool.Close()

	log.Println("Parsing test.nzb...")
	f, err := os.Open("test.nzb")
	if err != nil {
		log.Fatalf("Open NZB failed: %v", err)
	}
	defer f.Close()

	mediaFile, err := nntpstream.ParseNZB(f)
	if err != nil {
		log.Fatalf("Parse NZB failed: %v", err)
	}
	log.Printf("Found Media File: %s", mediaFile.Name)
	log.Printf("Total Size (raw): %d bytes", mediaFile.Size)
	log.Printf("Total Segments: %d", len(mediaFile.Segments))

	streamer := nntpstream.NewStreamer(pool, mediaFile)
	defer streamer.Close()

	// Read first 5MB or at least some chunks
	buffer := make([]byte, 1024*1024) // 1MB buffer
	totalRead := 0

	log.Println("Starting to read from streamer...")
	start := time.Now()

	for i := 0; i < 5; i++ {
		n, err := io.ReadFull(streamer, buffer)
		totalRead += n
		log.Printf("Read %d bytes (Total: %d). Error: %v", n, totalRead, err)
		if err != nil && err != io.ErrUnexpectedEOF {
			break
		}
	}
	duration := time.Since(start)
	log.Printf("Read %d MB in %s (Speed: %.2f MB/s)", totalRead/(1024*1024), duration, float64(totalRead/(1024*1024))/duration.Seconds())
}
