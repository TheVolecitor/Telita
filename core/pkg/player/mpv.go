package player

import (
	"fmt"
	"log"
	"os/exec"
	
	"github.com/cinekernel/core/pkg/torrent"
)

var globalTorrentEngine *torrent.Engine

func InitTorrentEngine() error {
	if globalTorrentEngine != nil {
		return nil
	}
	
	engine, err := torrent.NewEngine()
	if err != nil {
		return err
	}
	
	engine.StartServer()
	globalTorrentEngine = engine
	return nil
}

func StreamMagnet(magnetURI string) (string, error) {
	if globalTorrentEngine == nil {
		return "", fmt.Errorf("torrent engine not initialized")
	}
	return globalTorrentEngine.StreamMagnet(magnetURI)
}

func DropAllTorrents() error {
	if globalTorrentEngine == nil {
		return fmt.Errorf("torrent engine not initialized")
	}
	globalTorrentEngine.DropAllTorrents()
	return nil
}

type MPV struct {
}

func NewMPV() *MPV {
	return &MPV{}
}

// PlayStream launches the native MPV player pointing to the given HTTP stream URL
func (p *MPV) PlayStream(url string) error {
	log.Printf("Launching native MPV player with stream URL: %s\n", url)

	// In a real bundled app, we would look for "./bin/mpv.exe" first.
	// For this prototype, we assume `mpv` is in the system PATH.
	cmd := exec.Command("mpv", "--fs", url)
	
	err := cmd.Start()
	if err != nil {
		log.Printf("Failed to start MPV: %v\n", err)
		return err
	}

	// Wait for the player to close in a separate goroutine so we don't block the frontend
	go func() {
		err := cmd.Wait()
		if err != nil {
			log.Printf("MPV exited with error: %v\n", err)
		} else {
			log.Println("MPV exited successfully.")
		}
	}()

	return nil
}
