package server

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/cinekernel/core/pkg/addon"
	"github.com/cinekernel/core/pkg/player"
)

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
			"id": "com.linvo.cinemeta",
			"name": "Cinemeta",
			"description": "Provides movie and series metadata",
			"types": []string{"movie", "series"},
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

func (s *Server) handleStop(w http.ResponseWriter, r *http.Request) {
	err := player.DropAllTorrents()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "stopped"})
}
