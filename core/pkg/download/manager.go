package download

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type DownloadStatus string

const (
	StatusDownloading DownloadStatus = "downloading"
	StatusCompleted   DownloadStatus = "completed"
	StatusError       DownloadStatus = "error"
	StatusCancelled   DownloadStatus = "cancelled"
	StatusPaused      DownloadStatus = "paused"
)

type DownloadRequest struct {
	ID             string                 `json:"id"`
	URL            string                 `json:"url"`
	TargetDir      string                 `json:"targetDir"`
	FileName       string                 `json:"fileName"`
	Meta           map[string]interface{} `json:"meta"`
	PosterURL      string                 `json:"posterUrl"`
	BackdropURL    string                 `json:"backdropUrl"`
	RootTargetDir  string                 `json:"rootTargetDir"`
	RootMeta       map[string]interface{} `json:"rootMeta"`
}

type DownloadProgress struct {
	ID             string         `json:"id"`
	Title          string         `json:"title"`
	TotalBytes     int64          `json:"totalBytes"`
	DownloadedBytes int64          `json:"downloadedBytes"`
	SpeedBytes     float64        `json:"speedBytes"` // Bytes per second
	Status         DownloadStatus `json:"status"`
	ErrorMsg       string         `json:"errorMsg,omitempty"`
}

type activeDownload struct {
	req       DownloadRequest
	progress  *DownloadProgress
	cancel    context.CancelFunc
	ctx       context.Context
	lastBytes int64
	lastTime  time.Time
	mu        sync.Mutex
	pausing   bool // true when we're pausing (not truly cancelling)
}

var (
	managerMu sync.RWMutex
	downloads = make(map[string]*activeDownload)
)

// StartDownload initiates a new download
func StartDownload(req DownloadRequest) error {
	managerMu.Lock()
	defer managerMu.Unlock()

	if _, exists := downloads[req.ID]; exists {
		return fmt.Errorf("download already exists for id: %s", req.ID)
	}

	ctx, cancel := context.WithCancel(context.Background())
	
	title := req.ID
	if name, ok := req.Meta["name"].(string); ok {
		title = name
	}

	dl := &activeDownload{
		req:    req,
		cancel: cancel,
		ctx:    ctx,
		progress: &DownloadProgress{
			ID:     req.ID,
			Title:  title,
			Status: StatusDownloading,
		},
		lastTime: time.Now(),
	}

	downloads[req.ID] = dl

	go dl.start()

	return nil
}

// GetStatuses returns the current progress of all downloads
func GetStatuses() []DownloadProgress {
	managerMu.RLock()
	defer managerMu.RUnlock()

	var statuses []DownloadProgress
	for _, dl := range downloads {
		dl.mu.Lock()
		statuses = append(statuses, *dl.progress)
		dl.mu.Unlock()
	}
	return statuses
}

// CancelDownload cancels an active download, deletes its incomplete files, and removes it from the queue
func CancelDownload(id string) error {
	managerMu.Lock()
	defer managerMu.Unlock()

	dl, exists := downloads[id]
	if !exists {
		return fmt.Errorf("download not found")
	}

	dl.mu.Lock()
	wasPaused := (dl.progress.Status == StatusPaused)
	if dl.progress.Status == StatusDownloading || dl.progress.Status == StatusPaused {
		if dl.cancel != nil {
			dl.cancel()
		}
		dl.progress.Status = StatusCancelled
	}
	dl.mu.Unlock()

	// If it was paused, the background goroutine is already dead and handles are closed.
	// We can safely delete the directory now, but retry in a loop for Windows locks.
	if wasPaused {
		go func(dir string) {
			for i := 0; i < 5; i++ {
				err := os.RemoveAll(dir)
				if err == nil {
					break
				}
				time.Sleep(200 * time.Millisecond)
			}
		}(dl.req.TargetDir)
	}

	delete(downloads, id)
	return nil
}

func (dl *activeDownload) start() {
	err := dl.downloadFile()
	
	dl.mu.Lock()
	defer dl.mu.Unlock()
	if err != nil {
		if dl.ctx.Err() == context.Canceled {
			if dl.pausing {
				// Just paused — don't touch files, status already set to Paused
				dl.pausing = false
			} else {
				dl.progress.Status = StatusCancelled
				go cleanupDownloadDir(dl.req.TargetDir, dl.req.RootTargetDir)
			}
		} else {
			dl.progress.Status = StatusError
			dl.progress.ErrorMsg = err.Error()
			log.Printf("Download error for %s: %v", dl.req.ID, err)
			go cleanupDownloadDir(dl.req.TargetDir, dl.req.RootTargetDir)
		}
	} else {
		dl.progress.Status = StatusCompleted
		dl.progress.DownloadedBytes = dl.progress.TotalBytes
		
		// Auto-remove completed items from queue
		go func(id string) {
			time.Sleep(3 * time.Second)
			RemoveDownload(id)
		}(dl.req.ID)
	}
}

func cleanupDownloadDir(dir, rootDir string) {
	for i := 0; i < 5; i++ {
		time.Sleep(200 * time.Millisecond)
		err := os.RemoveAll(dir)
		if err == nil {
			// Cascade delete empty parent directories up to rootDir
			if rootDir != "" && len(rootDir) < len(dir) {
				parent := filepath.Dir(dir)
				for len(parent) >= len(rootDir) {
					// os.Remove only deletes if directory is completely empty
					if err := os.Remove(parent); err != nil {
						break
					}
					if parent == rootDir {
						break
					}
					parent = filepath.Dir(parent)
				}
			}
			break
		}
	}
}

// PauseDownload pauses an active download
func PauseDownload(id string) error {
	managerMu.Lock()
	defer managerMu.Unlock()

	dl, exists := downloads[id]
	if !exists {
		return fmt.Errorf("download not found")
	}

	dl.mu.Lock()
	if dl.progress.Status == StatusDownloading {
		dl.pausing = true // signal start() not to delete files
		dl.progress.Status = StatusPaused
		dl.cancel()
	}
	dl.mu.Unlock()

	return nil
}

// ResumeDownload resumes a paused or cancelled download
func ResumeDownload(id string) error {
	managerMu.Lock()
	defer managerMu.Unlock()

	dl, exists := downloads[id]
	if !exists {
		return fmt.Errorf("download not found")
	}

	dl.mu.Lock()
	defer dl.mu.Unlock()

	if dl.progress.Status == StatusDownloading || dl.progress.Status == StatusCompleted {
		return fmt.Errorf("download is not paused")
	}

	dl.ctx, dl.cancel = context.WithCancel(context.Background())
	dl.progress.Status = StatusDownloading
	dl.progress.ErrorMsg = ""
	dl.lastTime = time.Now()
	dl.lastBytes = dl.progress.DownloadedBytes

	go dl.start()

	return nil
}

// RemoveDownload removes a download from the queue
func RemoveDownload(id string) error {
	managerMu.Lock()
	defer managerMu.Unlock()

	dl, exists := downloads[id]
	if !exists {
		return fmt.Errorf("download not found")
	}

	dl.mu.Lock()
	if dl.progress.Status == StatusDownloading {
		dl.cancel()
	}
	dl.mu.Unlock()

	delete(downloads, id)
	return nil
}

func (dl *activeDownload) downloadFile() error {
	// Create Target directory structure
	err := os.MkdirAll(dl.req.TargetDir, 0755)
	if err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}

	// If a root directory is provided (e.g., for series), save the main series metadata there
	if dl.req.RootTargetDir != "" {
		os.MkdirAll(dl.req.RootTargetDir, 0755)
		if dl.req.RootMeta != nil {
			metaBytes, _ := json.MarshalIndent(dl.req.RootMeta, "", "  ")
			os.WriteFile(filepath.Join(dl.req.RootTargetDir, "meta.json"), metaBytes, 0644)
		}
		if dl.req.PosterURL != "" {
			_ = downloadSimple(dl.req.PosterURL, filepath.Join(dl.req.RootTargetDir, "poster.jpg"))
		}
		if dl.req.BackdropURL != "" {
			_ = downloadSimple(dl.req.BackdropURL, filepath.Join(dl.req.RootTargetDir, "backdrop.jpg"))
		}
		
		// Save episode specific metadata in target dir
		if dl.req.Meta != nil {
			metaBytes, _ := json.MarshalIndent(dl.req.Meta, "", "  ")
			os.WriteFile(filepath.Join(dl.req.TargetDir, "meta.json"), metaBytes, 0644)
		}
		// In a series, the episode thumbnail (if any) could be mapped to posterUrl, but we already used that for root.
		// We'll let the frontend pass the episode thumbnail inside the episode Meta object, or we can just skip it here.
	} else {
		// Single movie fallback
		if dl.req.Meta != nil {
			metaBytes, _ := json.MarshalIndent(dl.req.Meta, "", "  ")
			os.WriteFile(filepath.Join(dl.req.TargetDir, "meta.json"), metaBytes, 0644)
		}
		if dl.req.PosterURL != "" {
			_ = downloadSimple(dl.req.PosterURL, filepath.Join(dl.req.TargetDir, "poster.jpg"))
		}
		if dl.req.BackdropURL != "" {
			_ = downloadSimple(dl.req.BackdropURL, filepath.Join(dl.req.TargetDir, "backdrop.jpg"))
		}
	}

	filePath := filepath.Join(dl.req.TargetDir, dl.req.FileName)

	var startBytes int64 = 0
	if fileInfo, err := os.Stat(filePath); err == nil {
		startBytes = fileInfo.Size()
	}

	req, err := http.NewRequestWithContext(dl.ctx, "GET", dl.req.URL, nil)
	if err != nil {
		return err
	}

	if startBytes > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", startBytes))
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 400 {
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	openFlags := os.O_CREATE | os.O_WRONLY
	if resp.StatusCode == 206 { // Partial Content
		openFlags |= os.O_APPEND
	} else {
		openFlags |= os.O_TRUNC
		startBytes = 0
	}

	dl.mu.Lock()
	if startBytes == 0 {
		dl.progress.TotalBytes = resp.ContentLength
	} else if dl.progress.TotalBytes == 0 {
		dl.progress.TotalBytes = startBytes + resp.ContentLength
	}
	dl.progress.DownloadedBytes = startBytes
	dl.lastBytes = startBytes
	dl.mu.Unlock()

	out, err := os.OpenFile(filePath, openFlags, 0644)
	if err != nil {
		return err
	}
	defer out.Close()

	// Track progress
	buf := make([]byte, 32*1024)
	for {
		n, err := resp.Body.Read(buf)
		if n > 0 {
			_, wErr := out.Write(buf[:n])
			if wErr != nil {
				return wErr
			}
			
			dl.mu.Lock()
			dl.progress.DownloadedBytes += int64(n)
			
			// Calculate speed every second
			now := time.Now()
			if now.Sub(dl.lastTime) >= time.Second {
				bytesSinceLast := dl.progress.DownloadedBytes - dl.lastBytes
				dl.progress.SpeedBytes = float64(bytesSinceLast) / now.Sub(dl.lastTime).Seconds()
				dl.lastBytes = dl.progress.DownloadedBytes
				dl.lastTime = now
			}
			dl.mu.Unlock()
		}

		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
	}

	return nil
}

func downloadSimple(url, dest string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}
