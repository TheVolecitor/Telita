package addon

import (
	"encoding/json"
)

// Manifest represents a Stremio addon manifest.json
type Manifest struct {
	ID          string     `json:"id"`
	Version     string     `json:"version"`
	Name        string     `json:"name"`
	Description string     `json:"description,omitempty"`
	Logo        string     `json:"logo,omitempty"`
	Resources   []Resource `json:"resources"`
	Types       []string   `json:"types"`
	Catalogs    []Catalog  `json:"catalogs"`
}

type Resource struct {
	Name       string   `json:"name"`
	Types      []string `json:"types"`
	IDPrefixes []string `json:"idPrefixes,omitempty"`
}

// UnmarshalJSON handles both string resources ("stream") and object resources.
func (r *Resource) UnmarshalJSON(data []byte) error {
	var str string
	if err := json.Unmarshal(data, &str); err == nil {
		r.Name = str
		return nil
	}
	type Alias Resource
	aux := &struct {
		*Alias
	}{
		Alias: (*Alias)(r),
	}
	return json.Unmarshal(data, &aux)
}

type Catalog struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	Name string `json:"name,omitempty"`
}

// CatalogResponse represents the response from /catalog/...
type CatalogResponse struct {
	Metas []MetaPreview `json:"metas"`
}

type MetaPreview struct {
	ID          string `json:"id"`
	Type        string `json:"type"`
	Name        string `json:"name"`
	Poster      string `json:"poster,omitempty"`
	Description string `json:"description,omitempty"`
	IMDBRating  string `json:"imdbRating,omitempty"`
	ReleaseInfo string `json:"releaseInfo,omitempty"`
}

// MetaResponse represents the response from /meta/...
type MetaResponse struct {
	Meta MetaDetail `json:"meta"`
}

type MetaDetail struct {
	ID          string      `json:"id"`
	Type        string      `json:"type"`
	Name        string      `json:"name"`
	Poster      string      `json:"poster,omitempty"`
	Background  string      `json:"background,omitempty"`
	Description string      `json:"description,omitempty"`
	IMDBRating  string      `json:"imdbRating,omitempty"`
	ReleaseInfo string      `json:"releaseInfo,omitempty"`
	Runtime     string      `json:"runtime,omitempty"`
	Genres      []string    `json:"genres,omitempty"`
	Director    []string    `json:"director,omitempty"`
	Cast        []string    `json:"cast,omitempty"`
	Videos      []MetaVideo `json:"videos,omitempty"`
}

type MetaVideo struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Season    int    `json:"season,omitempty"`
	Episode   int    `json:"episode,omitempty"`
	Released  string `json:"released,omitempty"`
	Overview  string `json:"overview,omitempty"`
	Thumbnail string `json:"thumbnail,omitempty"`
}

// StreamResponse represents the response from /stream/...
type StreamResponse struct {
	Streams []Stream `json:"streams"`
}

type Stream struct {
	Name        string               `json:"name,omitempty"`
	Title       string               `json:"title,omitempty"`
	URL         string               `json:"url,omitempty"`
	InfoHash    string               `json:"infoHash,omitempty"`
	FileIdx     *int                 `json:"fileIdx,omitempty"`
	Behavior    *StreamBehaviorHints `json:"behaviorHints,omitempty"`
}

type StreamBehaviorHints struct {
	NotWebReady      bool              `json:"notWebReady,omitempty"`
	BingeGroup       string            `json:"bingeGroup,omitempty"`
	ProxyHeaders     map[string]string `json:"proxyHeaders,omitempty"`
}
