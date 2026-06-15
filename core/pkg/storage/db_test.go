package storage

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDBProfilesAndAddons(t *testing.T) {
	dbPath := filepath.Join(os.TempDir(), "cinekernel_test.db")
	defer os.Remove(dbPath)

	db, err := InitDB(dbPath)
	if err != nil {
		t.Fatalf("Failed to init DB: %v", err)
	}
	defer db.Close()

	// 1. Create Profile
	err = db.CreateProfile("profile_1", "Test User")
	if err != nil {
		t.Fatalf("Failed to create profile: %v", err)
	}

	// 2. Fetch Profiles
	profiles, err := db.GetProfiles()
	if err != nil {
		t.Fatalf("Failed to get profiles: %v", err)
	}
	if len(profiles) != 1 {
		t.Fatalf("Expected 1 profile, got %d", len(profiles))
	}
	if profiles[0]["name"] != "Test User" {
		t.Errorf("Expected profile name 'Test User', got '%v'", profiles[0]["name"])
	}

	// 3. Install Addon
	err = db.InstallAddon("profile_1", "com.linvo.cinemeta", "https://v3-cinemeta.strem.io/manifest.json", 0)
	if err != nil {
		t.Fatalf("Failed to install addon: %v", err)
	}

	// 4. Fetch Installed Addons
	addons, err := db.GetInstalledAddons("profile_1")
	if err != nil {
		t.Fatalf("Failed to get installed addons: %v", err)
	}
	if len(addons) != 1 {
		t.Fatalf("Expected 1 addon, got %d", len(addons))
	}
	if addons[0] != "https://v3-cinemeta.strem.io/manifest.json" {
		t.Errorf("Expected Cinemeta URL, got %s", addons[0])
	}
}
