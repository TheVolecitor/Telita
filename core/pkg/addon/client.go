package addon

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Client struct {
	httpClient *http.Client
}

type userAgentTransport struct {
	rt http.RoundTripper
}

func (u *userAgentTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	// Some addons also check Accept
	req.Header.Set("Accept", "application/json, text/plain, */*")
	return u.rt.RoundTrip(req)
}

func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout:   15 * time.Second,
			Transport: &userAgentTransport{rt: http.DefaultTransport},
		},
	}
}

// FetchManifest retrieves and parses the manifest.json from the given addon URL.
func (c *Client) FetchManifest(manifestURL string) (*Manifest, error) {
	resp, err := c.httpClient.Get(manifestURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch manifest: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var manifest Manifest
	if err := json.NewDecoder(resp.Body).Decode(&manifest); err != nil {
		return nil, fmt.Errorf("failed to decode manifest: %w", err)
	}

	return &manifest, nil
}

// getBaseURL removes the /manifest.json part to get the base path.
func getBaseURL(manifestURL string) string {
	if strings.HasSuffix(manifestURL, "/manifest.json") {
		return strings.TrimSuffix(manifestURL, "/manifest.json")
	}
	return manifestURL
}

// FetchCatalog retrieves the catalog items from an addon.
func (c *Client) FetchCatalog(manifestURL, type_, id, extra string) (*CatalogResponse, error) {
	base := getBaseURL(manifestURL)
	u := fmt.Sprintf("%s/catalog/%s/%s", base, url.PathEscape(type_), url.PathEscape(id))
	if extra != "" {
		u = fmt.Sprintf("%s/%s", u, extra)
	}
	u += ".json"

	resp, err := c.httpClient.Get(u)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch catalog: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var result CatalogResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode catalog: %w", err)
	}

	return &result, nil
}

// FetchMeta retrieves detailed metadata for an item.
func (c *Client) FetchMeta(manifestURL, type_, id string) (*MetaResponse, error) {
	base := getBaseURL(manifestURL)
	u := fmt.Sprintf("%s/meta/%s/%s.json", base, url.PathEscape(type_), url.PathEscape(id))

	resp, err := c.httpClient.Get(u)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch meta: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var result MetaResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode meta: %w", err)
	}

	return &result, nil
}

// FetchStreams retrieves stream items for a video.
func (c *Client) FetchStreams(manifestURL, type_, id string) (*StreamResponse, error) {
	base := getBaseURL(manifestURL)
	u := fmt.Sprintf("%s/stream/%s/%s.json", base, url.PathEscape(type_), url.PathEscape(id))

	resp, err := c.httpClient.Get(u)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch streams: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var result StreamResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode streams: %w", err)
	}

	return &result, nil
}
