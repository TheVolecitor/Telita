package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"time"
)

func main() {
	nzbUrl := "https://api.nzb.life/getnzb/956271986604ca354a4900ba0059b8e4.nzb?i=351016&r=864d6653dcb80cc7a74815c20e210ea1"
	server := "nntp://872bd23e-a69c-4c0c-91c5-10b42678e491:8yw0TgDNcRt5zVFJsx0YMQ@nntp.torbox.app:563/10"

	// 1. Hit API to initialize the session
	initURL := fmt.Sprintf("http://127.0.0.1:8081/api/play/nzb?nzbUrl=%s&server=%s", url.QueryEscape(nzbUrl), url.QueryEscape(server))
	log.Printf("Initializing session: %s", initURL)
	
	resp, err := http.Get(initURL)
	if err != nil {
		log.Fatalf("Init failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		log.Fatalf("Init returned status %d: %s", resp.StatusCode, string(body))
	}

	var result struct {
		StreamUrl string `json:"streamUrl"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Fatalf("Failed to parse init response: %v", err)
	}

	streamURL := result.StreamUrl
	log.Printf("Session initialized! WebDAV URL: %s", streamURL)

	// Wait 2 seconds for headers to parse
	time.Sleep(2 * time.Second)

	// Get total file size with HEAD request
	req, _ := http.NewRequest("HEAD", streamURL, nil)
	headResp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Fatalf("HEAD request failed: %v", err)
	}
	headResp.Body.Close()
	
	totalSize := headResp.ContentLength
	log.Printf("Total Virtual File Size: %d bytes (%.2f MB)", totalSize, float64(totalSize)/1024/1024)
	
	if totalSize <= 0 {
		log.Fatalf("Total size is 0 or unknown. Streamer failed to map properly.")
	}

	rand.Seed(time.Now().UnixNano())
	
	// Test seeking: 5 random 50MB parts
	for i := 0; i < 5; i++ {
		// Pick a random starting offset (ensure we have at least 50MB left)
		maxOffset := totalSize - (50 * 1024 * 1024)
		if maxOffset < 0 { maxOffset = 0 }
		
		startBytes := rand.Int63n(maxOffset + 1)
		endBytes := startBytes + (50 * 1024 * 1024) - 1
		
		log.Printf("[Test %d/5] Seeking to byte %d-%d (%.2f MB)...", i+1, startBytes, endBytes, float64(startBytes)/1024/1024)
		
		req, _ := http.NewRequest("GET", streamURL, nil)
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", startBytes, endBytes))
		
		startTime := time.Now()
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			log.Printf("[Test %d/5] Request failed: %v", i+1, err)
			continue
		}
		
		if res.StatusCode != 206 && res.StatusCode != 200 {
			log.Printf("[Test %d/5] Bad status code: %d", i+1, res.StatusCode)
			res.Body.Close()
			continue
		}
		
		// Read body
		written, err := io.Copy(io.Discard, res.Body)
		res.Body.Close()
		
		duration := time.Since(startTime)
		mbps := (float64(written) / 1024 / 1024) / duration.Seconds()
		
		log.Printf("[Test %d/5] Successfully downloaded %d bytes in %v (%.2f MB/s)", i+1, written, duration, mbps)
		
		time.Sleep(5 * time.Second) // Wait 5 seconds between chunks as requested
	}
}
