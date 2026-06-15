package torrent

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/anacrolix/torrent"
)

type Engine struct {
	client *torrent.Client
}

func NewEngine() (*Engine, error) {
	cfg := torrent.NewDefaultClientConfig()
	// Use 100% Pure RAM Storage with Smart Eviction (No Disk I/O)
	// We allocate a maximum 150MB buffer (roughly 2-3 minutes of 4K content).
	// Old chunks are evicted, but file indexes (start/end) are pinned.
	cfg.DefaultStorage = NewMemoryStorage(150 * 1024 * 1024) // 150 MB max RAM
	cfg.DataDir = "" // No disk writes!
	
	cfg.NoUpload = false
	cfg.Seed = false
	cfg.Debug = false

	client, err := torrent.NewClient(cfg)
	if err != nil {
		return nil, err
	}

	return &Engine{
		client: client,
	}, nil
}

// StreamMagnet adds the magnet, waits for info, finds the video file, and returns the HTTP stream URL
func (e *Engine) StreamMagnet(magnetURI string) (string, error) {
	t, err := e.client.AddMagnet(magnetURI)
	if err != nil {
		return "", err
	}

	log.Printf("Added magnet, getting info for %s...\n", t.InfoHash().HexString())
	
	// Wait for metadata
	select {
	case <-t.GotInfo():
	case <-time.After(30 * time.Second):
		return "", fmt.Errorf("timeout waiting for torrent metadata")
	}

	log.Printf("Got info for %s. Name: %s\n", t.InfoHash().HexString(), t.Name())

	// Start downloading the largest file (assume it's the video)
	var largestFile *torrent.File
	var maxLen int64
	for _, f := range t.Files() {
		if f.Length() > maxLen {
			maxLen = f.Length()
			largestFile = f
		}
	}

	if largestFile == nil {
		return "", fmt.Errorf("no files found in torrent")
	}

	log.Printf("Selected largest file for streaming: %s (%d bytes)\n", largestFile.DisplayPath(), largestFile.Length())

	// In a real app, we would start an HTTP server here or register a handler.
	// For simplicity in this iteration, we just return the local file path if it was fully downloaded,
	// BUT since we want to stream immediately, we need a local HTTP server.

	// The simplest way to handle streaming is to use a global HTTP server in the engine
	// Since we only stream one thing at a time for now:
	streamURL := fmt.Sprintf("http://localhost:8080/stream?hash=%s", t.InfoHash().HexString())
	return streamURL, nil
}

// ServeHTTP serves the torrent file content over HTTP to the local player
func (e *Engine) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	hashStr := r.URL.Query().Get("hash")
	if hashStr == "" {
		http.Error(w, "missing hash", http.StatusBadRequest)
		return
	}

	var t *torrent.Torrent
	for _, tt := range e.client.Torrents() {
		if tt.InfoHash().HexString() == hashStr {
			t = tt
			break
		}
	}

	if t == nil {
		http.Error(w, "torrent not found", http.StatusNotFound)
		return
	}

	// Find largest file again
	var largestFile *torrent.File
	var maxLen int64
	for _, f := range t.Files() {
		if f.Length() > maxLen {
			maxLen = f.Length()
			largestFile = f
		}
	}

	if largestFile == nil {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}

	// Create a reader for the file
	reader := largestFile.NewReader()
	
	// Set a targeted sliding window buffer (e.g., ~50MB) 
	// This ensures the engine ONLY buffers the upcoming 5-10 minutes instead of the entire file.
	reader.SetReadahead(1024 * 1024 * 50) 

	w.Header().Set("Content-Disposition", "attachment; filename=\""+largestFile.DisplayPath()+"\"")
	http.ServeContent(w, r, largestFile.DisplayPath(), time.Time{}, reader)
}

// StartServer starts the HTTP streaming server on port 8080
func (e *Engine) StartServer() {
	http.HandleFunc("/stream", e.ServeHTTP)
	log.Println("Torrent Streaming Server running on http://localhost:8080")
	go func() {
		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Printf("Streaming server error: %v\n", err)
		}
	}()
}

// DropAllTorrents drops all currently active torrents to free up memory and bandwidth.
func (e *Engine) DropAllTorrents() {
	for _, t := range e.client.Torrents() {
		t.Drop()
	}
	log.Println("Dropped all active torrents.")
}
