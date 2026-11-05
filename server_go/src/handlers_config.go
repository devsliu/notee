package main

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
)

// userConfigPath returns the per-user config.json path:
// recordsFolder/user_{userId}/config.json
func (s *Server) userConfigPath(userId int64) string {
	return filepath.Join(s.recordsFolder, "user_"+strconv.FormatInt(userId, 10), "config.json")
}

// readUserConfig loads the user's config.json into a map. Returns an empty
// map if the file does not exist yet.
func (s *Server) readUserConfig(userId int64) (map[string]string, error) {
	path := s.userConfigPath(userId)
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]string{}, nil
		}
		return nil, err
	}
	var m map[string]string
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	if m == nil {
		m = map[string]string{}
	}
	return m, nil
}

// writeUserConfig atomically writes the config map to the user's config.json.
func (s *Server) writeUserConfig(userId int64, m map[string]string) error {
	path := s.userConfigPath(userId)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

// downloadConfigHandler returns all configs for the current user as a JSON
// object: {"key1":"value1","key2":"value2"}.
func (s *Server) downloadConfigHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	configs, err := s.readUserConfig(user.UserID)
	if err != nil {
		http.Error(w, "Read config error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(configs)
}

// uploadConfigHandler applies a batch of config updates.
// Request body: JSON object {"key1":"value1","key2":"","key3":null}.
//   - value == ""      : set value to "" (key is kept, meaning "deleted")
//   - value == null    : skip (no change)
//   - value == string  : upsert
// The server never removes keys — an empty string means "deleted".
func (s *Server) uploadConfigHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	var body map[string]*string
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	configs, err := s.readUserConfig(user.UserID)
	if err != nil {
		http.Error(w, "Read config error", http.StatusInternalServerError)
		return
	}

	changed := false
	for k, v := range body {
		if v == nil {
			continue // null -> skip
		}
		if configs[k] != *v {
			configs[k] = *v
			changed = true
		}
	}

	if changed {
		if err := s.writeUserConfig(user.UserID, configs); err != nil {
			http.Error(w, "Write config error", http.StatusInternalServerError)
			return
		}
	}
	w.WriteHeader(http.StatusOK)
}
