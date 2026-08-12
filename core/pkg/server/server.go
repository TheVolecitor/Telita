package server

import (
	"archive/zip"
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/cinekernel/core/pkg/addon"
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
		mux:         http.NewServeMux(),
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
	s.mux.HandleFunc("/api/stop", s.handleStop)
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

	return http.ListenAndServe(s.addr, corsHandler(s.mux))
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

		webdavURL := fmt.Sprintf("http://127.0.0.1:8081/webdav/%s/%s",
			url.PathEscape(cacheKey),
			url.PathEscape(fileName),
		)

		log.Printf("[NNTP] Returning WebDAV stream URL: %s", webdavURL)

		http.Redirect(w, r, webdavURL, http.StatusFound)
	} else if session.MediaFile != nil {
		// Direct media file
		fileName := session.CleanFilename()

		webdavURL := fmt.Sprintf("http://127.0.0.1:8081/webdav/%s/%s",
			url.PathEscape(cacheKey),
			url.PathEscape(fileName),
		)

		log.Printf("[NNTP] Returning WebDAV stream URL: %s", webdavURL)

		http.Redirect(w, r, webdavURL, http.StatusFound)
	} else {
		http.Error(w, "no playable media found in NZB", http.StatusNotFound)
	}
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
