package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// ---- Upgrade / version.ini + vX.Y.Z/version.json ----

// versionPlatform is a single platform entry in {version}/version.json
// (written by pack/publish_release.ps1)
type versionPlatform struct {
	Md5  string `json:"md5"`
	File string `json:"file"`
}

type upgradeResponse struct {
	Platform    string `json:"platform"`
	VersionName string `json:"versionName"`
	Changelog   string `json:"changelog"`
	Md5         string `json:"md5"`
	DownloadUrl string `json:"downloadUrl"`
}

var allowedPlatforms = map[string]bool{
	"windows": true,
	"android": true,
	"linux":   true,
	"macos":   true,
	"ios":     true,
}

// readLatestVersion 从 version.ini 读取最新版本名 (格式: latest=1.0.4)
func (s *Server) readLatestVersion() (string, error) {
	data, err := os.ReadFile(filepath.Join(s.versionDir, "version.ini"))
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "latest=") {
			return strings.TrimSpace(strings.TrimPrefix(line, "latest=")), nil
		}
	}
	return "", fmt.Errorf("latest= not found in version.ini")
}

func (s *Server) upgradeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	platform := r.URL.Query().Get("platform")
	if !allowedPlatforms[platform] {
		http.Error(w, "invalid or missing 'platform' (valid: windows, android, linux, macos, ios)", http.StatusBadRequest)
		return
	}

	writeEmpty := func(changelog string) {
		w.Header().Set("content-type", "application/json; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(upgradeResponse{Platform: platform, Changelog: changelog})
	}

	latest, err := s.readLatestVersion()
	if err != nil {
		log.Printf("[upgrade] read version.ini FAILED: %v", err)
		writeEmpty("server version.ini not found")
		return
	}

	jsonPath := filepath.Join(s.versionDir, latest, "version.json")
	data, err := os.ReadFile(jsonPath)
	if err != nil {
		log.Printf("[upgrade] ReadFile %s FAILED: %v", jsonPath, err)
		writeEmpty("server version.json not found")
		return
	}

	var all map[string]interface{}
	if err := json.Unmarshal(data, &all); err != nil {
		http.Error(w, "version.json parse error", http.StatusInternalServerError)
		return
	}

	platRaw, ok := all[platform]
	if !ok {
		writeEmpty("no releases for this platform")
		return
	}

	platBytes, _ := json.Marshal(platRaw)
	var plat versionPlatform
	if err := json.Unmarshal(platBytes, &plat); err != nil {
		http.Error(w, "version.json platform parse error", http.StatusInternalServerError)
		return
	}

	changelog := ""
	if cdata, err := os.ReadFile(filepath.Join(s.versionDir, latest, "changelog.txt")); err == nil {
		changelog = strings.TrimSpace(string(cdata))
	}

	resp := upgradeResponse{
		Platform:    platform,
		VersionName: latest,
		Changelog:   changelog,
		Md5:         plat.Md5,
		DownloadUrl: "/upgrade/download/" + latest + "/" + plat.File,
	}

	w.Header().Set("content-type", "application/json; charset=utf-8")
	json.NewEncoder(w).Encode(resp)
}
