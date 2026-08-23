package server

import (
	"archive/zip"
	"bytes"
	"crypto/md5"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/cinekernel/core/pkg/addon"
	"github.com/cinekernel/core/pkg/download"
	"github.com/cinekernel/core/pkg/nntpstream"
	"github.com/cinekernel/core/pkg/player"
	webdavfs "github.com/cinekernel/core/pkg/webdav"
	"golang.org/x/net/webdav"
)

var nzbCache = make(map[string][]byte)
var nzbCacheMu sync.RWMutex

type Server struct {
	addr        string
	mux         *http.ServeMux
	addonClient *addon.Client
}

func NewServer(addr string) *Server {
	// Initialize torrent engine in the background
	go func() {
		err := player.InitTorrentEngine()
		if err != nil {
			log.Printf("Failed to initialize torrent engine: %v", err)
		}
	}()

	s := &Server{
		addr:        addr,
		mux:         http.DefaultServeMux,
		addonClient: addon.NewClient(),
	}
	s.routes()
	return s
}

func (s *Server) routes() {
	s.mux.HandleFunc("/api/status", s.handleStatus)
	// Addon manager routes
	s.mux.HandleFunc("/api/addons/installed", s.handleInstalledAddons)

	// Proxy routes
	s.mux.HandleFunc("/api/catalog", s.handleCatalog)
	s.mux.HandleFunc("/api/meta", s.handleMeta)
	s.mux.HandleFunc("/api/streams", s.handleStreams)

	// Torrent Play route
	s.mux.HandleFunc("/api/play", s.handlePlay)
	s.mux.HandleFunc("/api/play/nzb", s.handlePlayNZB)
	s.mux.HandleFunc("/webdav/", s.handleWebdav)
	s.mux.HandleFunc("/proxy/", s.handleProxy)
	s.mux.HandleFunc("/api/stop", s.handleStop)
	s.mux.HandleFunc("/api/shortpath", s.handleShortPath)
	s.mux.HandleFunc("/api/playlink", s.handlePlayLink)
	s.mux.HandleFunc("/api/deletelink", s.handleDeleteLink)
	s.mux.HandleFunc("/local", s.handleLocalFile)

	// Download routes
	s.mux.HandleFunc("/api/download/start", s.handleDownloadStart)
	s.mux.HandleFunc("/api/download/status", s.handleDownloadStatus)
	s.mux.HandleFunc("/api/download/cancel", s.handleDownloadCancel)
	s.mux.HandleFunc("/api/download/pause", s.handleDownloadPause)
	s.mux.HandleFunc("/api/download/resume", s.handleDownloadResume)
	s.mux.HandleFunc("/api/download/remove", s.handleDownloadRemove)
	s.mux.HandleFunc("/api/download/defaultdir", s.handleDownloadDefaultDir)
}

func (s *Server) Start() error {
	log.Printf("Listening on http://localhost%s", s.addr)

	// Enable CORS for frontend clients
	corsHandler := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	}

	handler := corsHandler(s.mux)
	return http.ListenAndServe(s.addr, handler)
}

func (s *Server) handleShortPath(w http.ResponseWriter, r *http.Request) {
	b64path := r.URL.Query().Get("b64path")
	if b64path == "" {
		http.Error(w, "Missing b64path", http.StatusBadRequest)
		return
	}
	decoded, err := base64.URLEncoding.DecodeString(b64path)
	if err != nil {
		http.Error(w, "Invalid b64path", http.StatusBadRequest)
		return
	}
	shortPath, err := getShortPathName(string(decoded))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(shortPath))
}

// ---- Native Hardlink Playback ----
// FVP's FFmpeg over HTTP on Windows randomly deadlocks on MKV cluster boundaries.
// To bypass HTTP completely, we create a temporary NTFS hardlink with an ASCII-only
// name in the same directory. This allows FVP to use VideoPlayerController.file natively.

func (s *Server) handlePlayLink(w http.ResponseWriter, r *http.Request) {
	b64path := r.URL.Query().Get("b64path")
	if b64path == "" {
		http.Error(w, "Missing b64path", http.StatusBadRequest)
		return
	}
	decoded, err := base64.URLEncoding.DecodeString(b64path)
	if err != nil {
		http.Error(w, "Invalid b64path", http.StatusBadRequest)
		return
	}
	originalPath := string(decoded)

	dir := filepath.Dir(originalPath)
	ext := filepath.Ext(originalPath)
	
	// Create a safe ASCII filename
	safeName := fmt.Sprintf(".telita_play_%d%s", time.Now().UnixNano(), ext)
	linkPath := filepath.Join(dir, safeName)
	
	// Create hardlink (instant, 0 bytes, no admin rights needed)
	err = os.Link(originalPath, linkPath)
	if err != nil {
		log.Printf("[LOCAL-LINK] Failed to create hardlink: %v", err)
		http.Error(w, "Link creation failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	
	log.Printf("[LOCAL-LINK] Created hardlink %s -> %s", linkPath, originalPath)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"link_path": linkPath})
}

func (s *Server) handleDeleteLink(w http.ResponseWriter, r *http.Request) {
	b64path := r.URL.Query().Get("b64path")
	if b64path == "" {
		http.Error(w, "Missing b64path", http.StatusBadRequest)
		return
	}
	decoded, err := base64.URLEncoding.DecodeString(b64path)
	if err != nil {
		http.Error(w, "Invalid b64path", http.StatusBadRequest)
		return
	}
	linkPath := string(decoded)
	
	// Ensure we only delete our own temp files
	if strings.Contains(filepath.Base(linkPath), ".telita_play_") {
		os.Remove(linkPath)
		log.Printf("[LOCAL-LINK] Deleted hardlink %s", linkPath)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// ---- In-memory local file buffer with bitrate-throttled delivery ----
// The deadlock: bytes.NewReader (or disk) can serve data at GB/s. FVP fills its
// internal TCP receive buffer in milliseconds. When FFmpeg then tries to seek to
// the next MKV cluster, it must close the saturated TCP connection and open a new
// Range request — but the blocked write prevents a clean teardown → deadlock.
//
// Fix: throttle delivery to 1.5× the file's actual bitrate. The TCP buffer never
// saturates; FVP can seek cleanly at every cluster boundary.

var (
	localCache   *localFileCache
	localCacheMu sync.RWMutex
)

type localFileCache struct {
	path    string
	name    string
	modTime time.Time
	total   int64
	data    []byte     // full file data (loaded in background)
	mu      sync.Mutex // guards data / done
	done    bool
}

func getLocalCache(filePath string) (*localFileCache, error) {
	localCacheMu.RLock()
	if localCache != nil && localCache.path == filePath {
		c := localCache
		localCacheMu.RUnlock()
		return c, nil
	}
	localCacheMu.RUnlock()

	fi, err := os.Stat(filePath)
	if err != nil {
		return nil, err
	}
	c := &localFileCache{
		path:    filePath,
		name:    fi.Name(),
		modTime: fi.ModTime(),
		total:   fi.Size(),
	}
	localCacheMu.Lock()
	localCache = c
	localCacheMu.Unlock()
	go c.preload()
	return c, nil
}

func (c *localFileCache) preload() {
	data, err := os.ReadFile(c.path)
	c.mu.Lock()
	if err == nil {
		c.data = data
	}
	c.done = true
	c.mu.Unlock()
	log.Printf("[LOCAL-BUF] Preload done: %d bytes", len(data))
}

func (c *localFileCache) waitReady() {
	for {
		c.mu.Lock()
		done := c.done
		c.mu.Unlock()
		if done {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// parseMKVDurationSecs scans the first 128 KB of the file for the EBML
// Segment Info Duration element (ID 0x4489) and TimecodeScale (0x2AD7B1).
// Returns 0 if not found or not an MKV.
func parseMKVDurationSecs(data []byte) float64 {
	if len(data) < 4 {
		return 0
	}
	// Must start with EBML magic
	if data[0] != 0x1A || data[1] != 0x45 || data[2] != 0xDF || data[3] != 0xA3 {
		return 0
	}

	probe := data
	if len(probe) > 131072 {
		probe = probe[:131072]
	}

	// Simple linear scan for TimecodeScale and Duration element IDs.
	// This is not a full EBML parser but works for well-formed MKV files.
	timecodeScale := int64(1000000) // default: 1 ms per tick
	var duration float64

	for i := 0; i < len(probe)-8; i++ {
		// TimecodeScale: 0x2A D7 B1 (3-byte ID)
		if i+7 < len(probe) && probe[i] == 0x2A && probe[i+1] == 0xD7 && probe[i+2] == 0xB1 {
			sz := int(probe[i+3]) // vint size (should be 0x83 = 3 bytes)
			if sz == 0x83 && i+7 < len(probe) {
				timecodeScale = int64(probe[i+4])<<16 | int64(probe[i+5])<<8 | int64(probe[i+6])
			}
		}
		// Duration: 0x44 0x89 (2-byte ID)
		if probe[i] == 0x44 && probe[i+1] == 0x89 {
			sz := int(probe[i+2]) // vint encoded size
			actualSz := sz & 0x7F
			if (sz == 0x84 || sz == 0x88) && i+3+actualSz <= len(probe) {
				raw := probe[i+3 : i+3+actualSz]
				if actualSz == 4 {
					bits := uint32(raw[0])<<24 | uint32(raw[1])<<16 | uint32(raw[2])<<8 | uint32(raw[3])
					duration = float64(math.Float32frombits(bits))
				} else if actualSz == 8 {
					bits := uint64(raw[0])<<56 | uint64(raw[1])<<48 | uint64(raw[2])<<40 | uint64(raw[3])<<32 |
						uint64(raw[4])<<24 | uint64(raw[5])<<16 | uint64(raw[6])<<8 | uint64(raw[7])
					duration = math.Float64frombits(bits)
				}
				if duration > 0 {
					// duration is in TimecodeScale units; convert to seconds
					return duration * float64(timecodeScale) / 1e9
				}
			}
		}
	}
	return 0
}

// bitrateForFile returns the estimated bytes-per-second for the file.
// Falls back to 5 Mbps (625 KB/s) if duration cannot be detected.
func bitrateForFile(data []byte, fileSize int64) int64 {
	durSec := parseMKVDurationSecs(data)
	if durSec > 1 {
		bps := float64(fileSize) / durSec // bytes per second at 1x
		log.Printf("[LOCAL-BUF] Detected duration=%.1fs bitrate=%.0f KB/s throttle=%.0f KB/s",
			durSec, bps/1024, bps*1.5/1024)
		return int64(bps * 1.5)
	}
	// Fallback: 5 Mbps
	log.Printf("[LOCAL-BUF] Duration not detected; using default 5 Mbps throttle")
	return 625 * 1024
}

// throttledReader wraps a bytes.Reader and enforces a maximum read rate.
type throttledReader struct {
	r     *bytes.Reader
	rate  int64     // bytes per second
	read  int64     // bytes consumed in this window
	start time.Time // window start
}

func newThrottledReader(data []byte, ratePerSec int64) *throttledReader {
	return &throttledReader{
		r:     bytes.NewReader(data),
		rate:  ratePerSec,
		start: time.Now(),
	}
}

func (t *throttledReader) Read(p []byte) (int, error) {
	n, err := t.r.Read(p)
	if n > 0 {
		t.read += int64(n)
		// How long should serving t.read bytes have taken?
		expected := time.Duration(float64(t.read) / float64(t.rate) * float64(time.Second))
		elapsed := time.Since(t.start)
		if expected > elapsed {
			time.Sleep(expected - elapsed)
		}
	}
	return n, err
}

func (t *throttledReader) Seek(offset int64, whence int) (int64, error) {
	// Reset throttle budget on every seek (new range window).
	t.read = 0
	t.start = time.Now()
	return t.r.Seek(offset, whence)
}

func (s *Server) handleLocalFile(w http.ResponseWriter, r *http.Request) {
	b64path := r.URL.Query().Get("b64path")
	if b64path == "" {
		http.Error(w, "Missing b64path", http.StatusBadRequest)
		return
	}
	decoded, err := base64.URLEncoding.DecodeString(b64path)
	if err != nil {
		http.Error(w, "Invalid b64path", http.StatusBadRequest)
		return
	}
	filePath := string(decoded)
	log.Printf("[LOCAL] Request Range=%q path=%s", r.Header.Get("Range"), filePath)

	c, err := getLocalCache(filePath)
	if err != nil {
		http.Error(w, "Cannot open file: "+err.Error(), http.StatusNotFound)
		return
	}
	c.waitReady()

	c.mu.Lock()
	data := c.data
	c.mu.Unlock()

	if len(data) == 0 {
		http.Error(w, "File load failed", http.StatusInternalServerError)
		return
	}

	rate := bitrateForFile(data[:min(131072, len(data))], c.total)
	tr := newThrottledReader(data, rate)
	
	encodedName := url.PathEscape(c.name)
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", "attachment; filename*=UTF-8''"+encodedName)
	http.ServeContent(w, r, c.name, c.modTime, tr)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}



func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok", "version": "1.0.0"})
}

func (s *Server) handleInstalledAddons(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	// Dummy response for now
	json.NewEncoder(w).Encode([]map[string]interface{}{
		{
			"id":          "com.linvo.cinemeta",
			"name":        "Cinemeta",
			"description": "Provides movie and series metadata",
			"types":       []string{"movie", "series"},
		},
	})
}

func (s *Server) handleCatalog(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	resp, err := s.addonClient.FetchCatalog(q.Get("manifest"), q.Get("type"), q.Get("id"), "")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (s *Server) handleMeta(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	resp, err := s.addonClient.FetchMeta(q.Get("manifest"), q.Get("type"), q.Get("id"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (s *Server) handleStreams(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	resp, err := s.addonClient.FetchStreams(q.Get("manifest"), q.Get("type"), q.Get("id"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (s *Server) handlePlay(w http.ResponseWriter, r *http.Request) {
	infoHash := r.URL.Query().Get("infoHash")
	if infoHash == "" {
		http.Error(w, "missing infoHash", http.StatusBadRequest)
		return
	}

	trackers := "&tr=udp://tracker.opentrackr.org:1337/announce" +
		"&tr=udp://open.tracker.cl:1337/announce" +
		"&tr=udp://9.rarbg.com:2810/announce" +
		"&tr=udp://tracker.openbittorrent.com:6969/announce" +
		"&tr=http://tracker.openbittorrent.com:80/announce" +
		"&tr=udp://opentracker.i2p.rocks:6969/announce"
	magnetURI := "magnet:?xt=urn:btih:" + infoHash + trackers
	streamURL, err := player.StreamMagnet(magnetURI)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"streamUrl": streamURL})
}

func (s *Server) handlePlayNZB(w http.ResponseWriter, r *http.Request) {
	log.Printf("[NNTP] Received play request: %s", r.URL.String())
	nzbUrl := strings.TrimSpace(r.URL.Query().Get("nzbUrl"))
	serverURI := strings.TrimSpace(r.URL.Query().Get("server"))

	if nzbUrl == "" || serverURI == "" {
		http.Error(w, "missing nzbUrl or server parameters", http.StatusBadRequest)
		return
	}

	// Parse server URI e.g. nntps://user:pass@host:port/connections
	u, err := url.Parse(serverURI)
	if err != nil {
		http.Error(w, fmt.Sprintf("invalid server URI: %v", err), http.StatusBadRequest)
		return
	}

	pass, _ := u.User.Password()
	conns := 8
	if u.Path != "" && u.Path != "/" {
		if importConns, err := strconv.Atoi(strings.TrimPrefix(u.Path, "/")); err == nil && importConns > 0 {
			conns = importConns
		}
	}
	port := 563
	if u.Port() != "" {
		port, _ = strconv.Atoi(u.Port())
	}

	cfg := nntpstream.Config{
		Host:        u.Hostname(),
		Port:        port,
		Username:    u.User.Username(),
		Password:    pass,
		Connections: conns,
	}

	// Build a stable cache key from the NZB URL + server identity
	hasher := md5.New()
	hasher.Write([]byte(nzbUrl + "|" + u.Hostname() + u.User.Username()))
	cacheKey := hex.EncodeToString(hasher.Sum(nil))

	// Check if we already downloaded this NZB
	nzbCacheMu.RLock()
	nzbBytes, hasNzb := nzbCache[nzbUrl]
	nzbCacheMu.RUnlock()

	// Fetch NZB bytes only if not already cached
	if !hasNzb {
		if strings.HasPrefix(nzbUrl, "http://") || strings.HasPrefix(nzbUrl, "https://") {
			// Some indexers provide links with '&' instead of '?' for the first parameter
			if !strings.Contains(nzbUrl, "?") && strings.Contains(nzbUrl, "&") {
				nzbUrl = strings.Replace(nzbUrl, "&", "?", 1)
			}

			req, err := http.NewRequest("GET", nzbUrl, nil)
			if err != nil {
				log.Printf("[NNTP] Error creating NZB request: %v", err)
				http.Error(w, fmt.Sprintf("failed to create request: %v", err), http.StatusInternalServerError)
				return
			}

			// Spoof SABnzbd User-Agent to bypass Cloudflare API protections on indexers
			req.Header.Set("User-Agent", "SABnzbd/5.0.4")

			client := &http.Client{
				Timeout: 30 * time.Second,
				CheckRedirect: func(req *http.Request, via []*http.Request) error {
					if len(via) >= 10 {
						return fmt.Errorf("stopped after 10 redirects")
					}
					// If indexer's redirect drops the query string (API key), restore it
					if req.URL.RawQuery == "" && via[0].URL.RawQuery != "" {
						req.URL.RawQuery = via[0].URL.RawQuery
					}
					// Ensure User-Agent is preserved across redirects
					req.Header.Set("User-Agent", "SABnzbd/5.0.4")
					return nil
				},
			}

			resp, err := client.Do(req)
			if err != nil {
				log.Printf("[NNTP] Error downloading NZB: %v", err)
				http.Error(w, fmt.Sprintf("failed to fetch nzb: %v", err), http.StatusBadGateway)
				return
			}
			defer resp.Body.Close()

			if resp.StatusCode != 200 {
				log.Printf("[NNTP] Upstream NZB error: HTTP %d", resp.StatusCode)
				http.Error(w, fmt.Sprintf("nzb upstream returned %d", resp.StatusCode), http.StatusBadGateway)
				return
			}
			nzbBytes, err = io.ReadAll(resp.Body)
			if err != nil {
				http.Error(w, fmt.Sprintf("failed to download nzb: %v", err), http.StatusBadGateway)
				return
			}

		} else {
			localPath := strings.TrimPrefix(nzbUrl, "file://")
			nzbBytes, err = os.ReadFile(localPath)
			if err != nil {
				http.Error(w, fmt.Sprintf("failed to read local nzb: %v", err), http.StatusInternalServerError)
				return
			}
		}

		// Check if the downloaded/read file is a ZIP archive (magic bytes: PK\x03\x04)
		if len(nzbBytes) > 4 && nzbBytes[0] == 0x50 && nzbBytes[1] == 0x4B && nzbBytes[2] == 0x03 && nzbBytes[3] == 0x04 {
			log.Printf("[NNTP] File is a ZIP archive, attempting to extract NZB...")

			// Try to read it as a zip file
			zipReader, err := zip.NewReader(bytes.NewReader(nzbBytes), int64(len(nzbBytes)))
			if err != nil {
				log.Printf("[NNTP] Failed to parse ZIP archive: %v", err)
				http.Error(w, "failed to parse zip archive", http.StatusBadGateway)
				return
			}

			var foundNzb bool
			for _, zf := range zipReader.File {
				if strings.HasSuffix(strings.ToLower(zf.Name), ".nzb") {
					rc, err := zf.Open()
					if err != nil {
						log.Printf("[NNTP] Failed to open NZB inside ZIP: %v", err)
						continue
					}
					extractedBytes, err := io.ReadAll(rc)
					rc.Close()
					if err == nil {
						log.Printf("[NNTP] Successfully extracted %s from ZIP", zf.Name)
						nzbBytes = extractedBytes
						foundNzb = true
						break
					}
				}
			}

			if !foundNzb {
				http.Error(w, "no .nzb file found inside the zip archive", http.StatusBadGateway)
				return
			}
		}

		nzbCacheMu.Lock()
		nzbCache[nzbUrl] = nzbBytes
		nzbCacheMu.Unlock()
	}

	// Get or create a persistent session (pool + parsed NZB + persistent Streamer)
	session, err := nntpstream.GlobalCache.GetOrCreate(cacheKey, cfg, nzbBytes)
	if err != nil {
		log.Printf("[NNTP] Session init failed: %v", err)
		http.Error(w, fmt.Sprintf("failed to init session: %v", err), http.StatusInternalServerError)
		return
	}

	session.UpdateLastUsed()

	if session.IsPacked && session.RARMap != nil {
		// Return WebDAV URL for the virtual MKV
		fileName := session.CleanFilename()

		webdavURL := fmt.Sprintf("http://127.0.0.1:12021/webdav/%s/%s",
			url.PathEscape(cacheKey),
			url.PathEscape(fileName),
		)

		log.Printf("[NNTP] Returning WebDAV stream URL: %s", webdavURL)

		http.Redirect(w, r, webdavURL, http.StatusFound)
	} else if session.MediaFile != nil {
		// Direct media file
		fileName := session.CleanFilename()

		webdavURL := fmt.Sprintf("http://127.0.0.1:12021/webdav/%s/%s",
			url.PathEscape(cacheKey),
			url.PathEscape(fileName),
		)

		log.Printf("[NNTP] Returning WebDAV stream URL: %s", webdavURL)

		http.Redirect(w, r, webdavURL, http.StatusFound)
	} else {
		http.Error(w, "no playable media found in NZB", http.StatusNotFound)
	}
}

func (s *Server) handleDownloadStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req download.DownloadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	if req.TargetDir == "" {
		if u, err := user.Current(); err == nil {
			req.TargetDir = filepath.Join(u.HomeDir, "Downloads")
		} else {
			req.TargetDir = filepath.Join(os.TempDir(), "TelitaDownloads")
		}
	}

	if err := download.StartDownload(req); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) handleDownloadDefaultDir(w http.ResponseWriter, r *http.Request) {
	dir := ""
	if u, err := user.Current(); err == nil {
		dir = filepath.Join(u.HomeDir, "Downloads")
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"dir": dir})
}

func (s *Server) handleDownloadStatus(w http.ResponseWriter, r *http.Request) {
	statuses := download.GetStatuses()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(statuses)
}

func (s *Server) handleDownloadCancel(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	if err := download.CancelDownload(payload.ID); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) handleDownloadPause(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	if err := download.PauseDownload(payload.ID); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) handleDownloadResume(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	if err := download.ResumeDownload(payload.ID); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) handleDownloadRemove(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	if err := download.RemoveDownload(payload.ID); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) handleWebdav(w http.ResponseWriter, r *http.Request) {
	// Path should be /webdav/{cacheKey}/...
	pathParts := strings.SplitN(strings.TrimPrefix(r.URL.Path, "/webdav/"), "/", 2)
	if len(pathParts) == 0 || pathParts[0] == "" {
		http.Error(w, "missing cache key", http.StatusBadRequest)
		return
	}

	cacheKey, err := url.PathUnescape(pathParts[0])
	if err != nil {
		http.Error(w, "invalid cache key", http.StatusBadRequest)
		return
	}

	// Try to get session from cache (it should have been created by /api/play/nzb)
	session, err := nntpstream.GlobalCache.Get(cacheKey)
	if err != nil || session == nil {
		http.Error(w, "session not found or expired (call /api/play/nzb first)", http.StatusNotFound)
		return
	}

	session.UpdateLastUsed()

	// Create WebDAV filesystem for this session
	fs := &webdavfs.NZBFileSystem{Session: session}

	// Create WebDAV handler, stripping the /webdav/{cacheKey} prefix
	prefix := "/webdav/" + pathParts[0]

	handler := &webdav.Handler{
		Prefix:     prefix,
		FileSystem: fs,
		LockSystem: webdav.NewMemLS(),
		Logger: func(r *http.Request, err error) {
			if err != nil {
				log.Printf("[WebDAV] %s %s - ERROR: %v", r.Method, r.URL.Path, err)
			} else {
				log.Printf("[WebDAV] %s %s", r.Method, r.URL.Path)
			}
		},
	}

	handler.ServeHTTP(w, r)
}

func (s *Server) handleStop(w http.ResponseWriter, r *http.Request) {
	err := player.DropAllTorrents()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "stopped"})
}

func (s *Server) handleProxy(w http.ResponseWriter, r *http.Request) {
	target := r.URL.Query().Get("d")
	if target == "" {
		http.Error(w, "missing d parameter", http.StatusBadRequest)
		return
	}

	proxyHeadersStr := r.URL.Query().Get("proxyheaders")
	var customHeaders map[string]string
	if proxyHeadersStr != "" {
		if err := json.Unmarshal([]byte(proxyHeadersStr), &customHeaders); err != nil {
			log.Printf("[Proxy] Failed to parse proxyheaders: %v", err)
		}
	}

	targetURL, err := url.Parse(target)
	if err != nil {
		http.Error(w, "invalid d parameter", http.StatusBadRequest)
		return
	}

	req, err := http.NewRequest(r.Method, targetURL.String(), nil)
	if err != nil {
		http.Error(w, "failed to create request", http.StatusInternalServerError)
		return
	}

	// Copy standard headers from the client (e.g., Range)
	for k, vv := range r.Header {
		for _, v := range vv {
			req.Header.Add(k, v)
		}
	}

	// Override with custom proxy headers
	for k, v := range customHeaders {
		req.Header.Set(k, v)
	}

	// We use DefaultTransport but remove default timeouts since video streams are long-lived
	client := &http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			// Ensure custom headers are preserved across redirects
			for k, v := range customHeaders {
				req.Header.Set(k, v)
			}
			return nil
		},
	}

	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "proxy request failed", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	// Copy response headers back
	for k, vv := range resp.Header {
		for _, v := range vv {
			w.Header().Add(k, v)
		}
	}
	w.WriteHeader(resp.StatusCode)

	io.Copy(w, resp.Body)
}
