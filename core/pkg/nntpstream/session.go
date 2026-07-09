package nntpstream

import (
	"bytes"
	"context"
	"errors"
	"log"
	"strings"
	"sync"
	"time"
)

// Session holds a persistent pool and parsed NZB.
// It is shared across all Range HTTP requests for the same media file.
type Session struct {
	MediaFile *MediaFile

	// RAR un-packing fields (nil if direct media)
	RARVolumes []*MediaFile
	RARMap     *RARMap
	IsPacked   bool

	// Persistent streamers — created once, reused for all WebDAV Range requests.
	// This is critical: creating a new Streamer per GET causes all 8 workers to
	// be cancelled every time FFmpeg probes the stream with a new request.
	Streamer      *Streamer
	UnrarStreamer *UnrarStreamer

	lastUsed time.Time
}

// CleanFilename returns a URL-safe filename that explicitly ends in the proper extension (e.g. .mkv, .mp4).
func (s *Session) CleanFilename() string {
	raw := ""
	if s.IsPacked && s.RARMap != nil {
		raw = s.RARMap.Filename
	} else if s.MediaFile != nil {
		raw = s.MediaFile.Name
	}

	if raw == "" {
		return "stream.mkv"
	}

	// Try to extract filename between quotes if present
	start := strings.Index(raw, "\"")
	if start != -1 {
		end := strings.LastIndex(raw, "\"")
		if end > start {
			extracted := raw[start+1 : end]
			if len(extracted) > 0 {
				raw = extracted
			}
		}
	}

	raw = strings.ReplaceAll(raw, "/", "_")
	raw = strings.ReplaceAll(raw, "\\", "_")
	raw = strings.ReplaceAll(raw, " ", "_")

	// Ensure it ends with a valid extension for video players
	lower := strings.ToLower(raw)
	if !strings.HasSuffix(lower, ".mkv") && !strings.HasSuffix(lower, ".mp4") && !strings.HasSuffix(lower, ".avi") {
		if strings.Contains(lower, ".mp4") {
			raw += ".mp4"
		} else if strings.Contains(lower, ".avi") {
			raw += ".avi"
		} else {
			raw += ".mkv"
		}
	}
	return raw
}

type SessionCache struct {
	mu       sync.Mutex
	sessions map[string]*Session
}

var GlobalCache = &SessionCache{
	sessions: make(map[string]*Session),
}

func init() {
	// Background goroutine to evict stale sessions (idle > 5 minutes)
	go func() {
		for {
			time.Sleep(30 * time.Second)
			GlobalCache.mu.Lock()
			for key, s := range GlobalCache.sessions {
				if time.Since(s.lastUsed) > 300*time.Second {
					log.Printf("[NNTP-Cache] Evicting idle session for key: %s", key)
					if s.Streamer != nil {
						s.Streamer.Close()
					}
					if s.UnrarStreamer != nil {
						s.UnrarStreamer.Close()
					}
					delete(GlobalCache.sessions, key)
				}
			}
			GlobalCache.mu.Unlock()
		}
	}()
}

// GetOrCreate returns an existing session or creates a new one.
// For packed (RAR) NZBs, it also scans RAR headers and builds the byte map.
func (sc *SessionCache) GetOrCreate(key string, cfg Config, nzbBytes []byte) (*Session, error) {
	sc.mu.Lock()
	defer sc.mu.Unlock()

	if s, ok := sc.sessions[key]; ok {
		s.lastUsed = time.Now()
		log.Printf("[NNTP-Cache] Reusing existing session for key: %s", key)
		return s, nil
	}

	// Evict any OTHER active sessions to keep memory usage low
	for k := range sc.sessions {
		log.Printf("[NNTP-Cache] Evicting previous session: %s", k)
		delete(sc.sessions, k)
	}

	log.Printf("[NNTP-Cache] Creating new session for key: %s", key)

	// Ensure GlobalPool is initialized
	if GlobalPool == nil {
		InitGlobalPool(cfg)
	}

	// Use the full parser that detects RAR volumes
	result, err := ParseNZBFull(bytes.NewReader(nzbBytes))
	if err != nil {
		return nil, err
	}

	// Triage the NZB: test if segments are available on the provider
	triageRes := TriageNZB(context.Background(), result, 3)
	if !triageRes.IsHealthy {
		log.Printf("[NNTP-Triage] Rejecting NZB: %s", triageRes.Message)
		return nil, errors.New("triage failed: " + triageRes.Message)
	}

	s := &Session{
		IsPacked: result.IsPacked,
		lastUsed: time.Now(),
	}

	if result.IsPacked && len(result.RARVolumes) > 0 {
		// RAR archive detected — scan headers to build byte map.
		// Retry once on transient network errors.
		log.Printf("[NNTP-Cache] Detected packed NZB with %d RAR volumes, scanning headers...", len(result.RARVolumes))

		s.RARVolumes = result.RARVolumes
		s.MediaFile = result.RARVolumes[0]

		var volumeHeaders []*VolumeHeaderInfo
		var scanErr error
		for attempt := 1; attempt <= 2; attempt++ {
			volumeHeaders, scanErr = ScanRARHeaders(context.Background(), result.RARVolumes)
			if scanErr == nil {
				break
			}
			log.Printf("[NNTP-Cache] RAR header scan attempt %d failed: %v", attempt, scanErr)
			if attempt < 2 {
				time.Sleep(500 * time.Millisecond)
			}
		}

		if scanErr != nil {
			log.Printf("[NNTP-Cache] RAR header scan failed after retries: %v — falling back to raw streaming", scanErr)
			s.IsPacked = false
			s.RARVolumes = nil
			s.RARMap = nil
		} else {
			rarMap, err := BuildRARMap(volumeHeaders)
			if err != nil {
				log.Printf("[NNTP-Cache] RAR map build failed: %v — falling back to raw streaming", err)
				s.IsPacked = false
				s.RARVolumes = nil
				s.RARMap = nil
			} else {
				s.RARMap = rarMap
				log.Printf("[NNTP-Cache] RAR map built successfully: %s (%d bytes, %d extents)",
					rarMap.Filename, rarMap.TotalSize, len(rarMap.Extents))
			}
		}
	} else {
		// Direct media file (or fallback)
		s.MediaFile = result.MediaFile
	}

	sc.sessions[key] = s

	// ── Create persistent streamers NOW, once, for the lifetime of this session.
	// WebDAV OpenFile must reuse these — never create new ones per GET request.
	bgCtx := context.Background()
	if s.IsPacked && s.RARMap != nil {
		s.UnrarStreamer = NewUnrarStreamer(bgCtx, s)
		log.Printf("[NNTP-Cache] Created persistent UnrarStreamer for session %s", key)
	} else if s.MediaFile != nil {
		s.Streamer = NewStreamer(bgCtx, s)
		log.Printf("[NNTP-Cache] Created persistent Streamer for session %s (%d segments)", key, len(s.MediaFile.Segments))
	}

	return s, nil
}

// UpdateLastUsed updates the session's activity timestamp
func (s *Session) UpdateLastUsed() {
	s.lastUsed = time.Now()
}

// Get retrieves an active session without recreating it.
func (sc *SessionCache) Get(key string) (*Session, error) {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	if s, ok := sc.sessions[key]; ok {
		return s, nil
	}
	return nil, errors.New("session not found")
}

// Evict forcibly removes a session.
func (sc *SessionCache) Evict(key string) {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	if _, ok := sc.sessions[key]; ok {
		delete(sc.sessions, key)
	}
}
