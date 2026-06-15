package storage

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

type DB struct {
	conn *sql.DB
}

// InitDB initializes the SQLite database and creates tables if they don't exist.
func InitDB(dbPath string) (*DB, error) {
	if err := os.MkdirAll(filepath.Dir(dbPath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create db directory: %w", err)
	}

	conn, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	db := &DB{conn: conn}
	if err := db.migrate(); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	return db, nil
}

func (db *DB) Close() error {
	return db.conn.Close()
}

func (db *DB) migrate() error {
	queries := []string{
		// Profiles Table: Supports multi-profile and server-side login linkage
		`CREATE TABLE IF NOT EXISTS profiles (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			server_auth_token TEXT,
			is_active BOOLEAN DEFAULT 0,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		);`,

		// Installed Addons: Linked to a specific profile
		`CREATE TABLE IF NOT EXISTS installed_addons (
			id TEXT NOT NULL,
			profile_id TEXT NOT NULL,
			manifest_url TEXT NOT NULL,
			priority INTEGER DEFAULT 0,
			PRIMARY KEY (id, profile_id),
			FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
		);`,

		// Library Items: Bookmarked content, progress, linked to profile
		`CREATE TABLE IF NOT EXISTS library_items (
			meta_id TEXT NOT NULL,
			profile_id TEXT NOT NULL,
			type TEXT NOT NULL,
			name TEXT NOT NULL,
			poster TEXT,
			behavior_status TEXT DEFAULT 'none', -- e.g., 'watching', 'completed', 'planned'
			progress REAL DEFAULT 0, -- Percentage or milliseconds
			last_watched DATETIME,
			PRIMARY KEY (meta_id, profile_id),
			FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
		);`,
	}

	for _, query := range queries {
		if _, err := db.conn.Exec(query); err != nil {
			log.Printf("Migration failed on query: %s\nError: %v", query, err)
			return err
		}
	}

	return nil
}

// ── Profile Operations ────────────────────────────────────────────────────────

func (db *DB) CreateProfile(id, name string) error {
	_, err := db.conn.Exec(`INSERT INTO profiles (id, name) VALUES (?, ?)`, id, name)
	return err
}

func (db *DB) GetProfiles() ([]map[string]interface{}, error) {
	rows, err := db.conn.Query(`SELECT id, name, is_active FROM profiles`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var profiles []map[string]interface{}
	for rows.Next() {
		var id, name string
		var isActive bool
		if err := rows.Scan(&id, &name, &isActive); err != nil {
			return nil, err
		}
		profiles = append(profiles, map[string]interface{}{
			"id":        id,
			"name":      name,
			"is_active": isActive,
		})
	}
	return profiles, nil
}

// ── Addon Operations ──────────────────────────────────────────────────────────

func (db *DB) InstallAddon(profileID, addonID, manifestURL string, priority int) error {
	_, err := db.conn.Exec(`
		INSERT OR REPLACE INTO installed_addons (id, profile_id, manifest_url, priority)
		VALUES (?, ?, ?, ?)`,
		addonID, profileID, manifestURL, priority,
	)
	return err
}

func (db *DB) GetInstalledAddons(profileID string) ([]string, error) {
	rows, err := db.conn.Query(`SELECT manifest_url FROM installed_addons WHERE profile_id = ? ORDER BY priority ASC`, profileID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var urls []string
	for rows.Next() {
		var url string
		if err := rows.Scan(&url); err != nil {
			return nil, err
		}
		urls = append(urls, url)
	}
	return urls, nil
}
