package addon

import (
	"testing"
)

func TestCinemetaManifest(t *testing.T) {
	client := NewClient()
	manifest, err := client.FetchManifest("https://v3-cinemeta.strem.io/manifest.json")
	if err != nil {
		t.Fatalf("Failed to fetch Cinemeta manifest: %v", err)
	}

	if manifest.ID != "com.linvo.cinemeta" {
		t.Errorf("Expected ID 'com.linvo.cinemeta', got '%s'", manifest.ID)
	}

	if len(manifest.Catalogs) == 0 {
		t.Error("Expected catalogs to be present, got 0")
	}
}

func TestCinemetaCatalog(t *testing.T) {
	client := NewClient()
	catalog, err := client.FetchCatalog("https://v3-cinemeta.strem.io/manifest.json", "movie", "top", "")
	if err != nil {
		t.Fatalf("Failed to fetch Cinemeta catalog: %v", err)
	}

	if len(catalog.Metas) == 0 {
		t.Error("Expected metas in catalog, got 0")
	}

	if catalog.Metas[0].Name == "" {
		t.Error("Expected first meta to have a name")
	}
}

func TestCinemetaMeta(t *testing.T) {
	client := NewClient()
	// Fetching meta for "The Matrix" (tt0133093)
	metaResp, err := client.FetchMeta("https://v3-cinemeta.strem.io/manifest.json", "movie", "tt0133093")
	if err != nil {
		t.Fatalf("Failed to fetch Cinemeta meta: %v", err)
	}

	if metaResp.Meta.Name != "The Matrix" {
		t.Errorf("Expected 'The Matrix', got '%s'", metaResp.Meta.Name)
	}

	if metaResp.Meta.IMDBRating == "" {
		t.Error("Expected IMDB rating to be present")
	}
}

