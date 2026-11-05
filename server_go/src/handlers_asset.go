package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// splitAssetPath parses the URL path "/asset/{recordUuid}/{filename}" into its
// two components. It returns empty strings if the path is malformed.
func splitAssetPath(urlPath string) (recordUuid, filename string) {
	// urlPath is like "/asset/00000000-0000-0000-0000-000000000000/foo.png"
	trimmed := strings.TrimPrefix(urlPath, "/asset/")
	if trimmed == urlPath {
		return "", ""
	}
	if trimmed == "" || strings.HasPrefix(trimmed, "/") {
		return "", ""
	}
	parts := strings.SplitN(trimmed, "/", 2)
	if len(parts) != 2 {
		return "", ""
	}
	return parts[0], parts[1]
}

// sanitizeAssetFilename prevents path traversal by reducing the filename to its
// base component and rejecting names that look like directory references.
func sanitizeAssetFilename(name string) (string, bool) {
	if name == "" {
		return "", false
	}
	base := filepath.Base(name)
	if base == "." || base == string(filepath.Separator) || base == "/" {
		return "", false
	}
	if strings.ContainsAny(base, `/\`) {
		return "", false
	}
	return base, true
}

// assetHandler dispatches HEAD/GET/PUT for /asset/{recordUuid}/{filename}.
func (s *Server) assetHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	recordUuid, filename := splitAssetPath(r.URL.Path)
	if !isValidRecordUUID(recordUuid) {
		http.Error(w, "invalid record uuid", ResultErrorParams.Value)
		return
	}
	safeName, ok := sanitizeAssetFilename(filename)
	if !ok {
		http.Error(w, "invalid filename", ResultErrorParams.Value)
		return
	}

	switch r.Method {
	case http.MethodHead:
		s.headAssetHandler(w, user.UserID, recordUuid, safeName)
	case http.MethodGet:
		s.getAssetHandler(w, user.UserID, recordUuid, safeName)
	case http.MethodPut:
		s.putAssetHandler(w, r, user.UserID, recordUuid, safeName)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

// headAssetHandler returns 200 if the asset exists, 404 otherwise.
func (s *Server) headAssetHandler(w http.ResponseWriter, userId int64, recordUuid, filename string) {
	absPath := s.getAssetAbsPath(userId, recordUuid, filename)
	info, err := os.Stat(absPath)
	if err != nil || info.IsDir() {
		http.Error(w, ResultErrorFileNotFound.Message, ResultErrorFileNotFound.Value)
		return
	}
	w.Header().Set("Content-Length", strconv.FormatInt(info.Size(), 10))
	w.WriteHeader(http.StatusOK)
}

// getAssetHandler streams the asset file to the client.
func (s *Server) getAssetHandler(w http.ResponseWriter, userId int64, recordUuid, filename string) {
	absPath := s.getAssetAbsPath(userId, recordUuid, filename)
	f, err := os.Open(absPath)
	if err != nil {
		http.Error(w, ResultErrorFileNotFound.Message, ResultErrorFileNotFound.Value)
		return
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || info.IsDir() {
		http.Error(w, ResultErrorFileNotFound.Message, ResultErrorFileNotFound.Value)
		return
	}
	w.Header().Set("Content-Length", strconv.FormatInt(info.Size(), 10))
	w.Header().Set("Content-Type", "application/octet-stream")
	w.WriteHeader(http.StatusOK)
	io.Copy(w, f)
}

// putAssetHandler saves an uploaded asset file. The client uploads assets
// before upserting the record, so the file is written directly to its final
// location (orphan cleanup runs on record upsert).
func (s *Server) putAssetHandler(w http.ResponseWriter, r *http.Request, userId int64, recordUuid, filename string) {
	r.Body = http.MaxBytesReader(w, r.Body, s.maxFileSize)
	file, fileHeader, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "multipart parse failed or file exceeds size limit", ResultErrorParams.Value)
		return
	}
	defer file.Close()
	if fileHeader.Size > s.maxFileSize {
		http.Error(w, "file exceeds size limit", ResultErrorParams.Value)
		return
	}

	dir := s.getAssetAbsDir(userId, recordUuid)
	if err := os.MkdirAll(dir, 0755); err != nil {
		http.Error(w, "asset dir create failed", http.StatusInternalServerError)
		return
	}
	absPath := s.getAssetAbsPath(userId, recordUuid, filename)

	// Write to a temp file then rename for atomicity.
	tmp, err := os.CreateTemp(dir, ".asset-*")
	if err != nil {
		http.Error(w, "asset temp create failed", http.StatusInternalServerError)
		return
	}
	tmpName := tmp.Name()
	if _, err := io.Copy(tmp, file); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		http.Error(w, "asset write failed", http.StatusInternalServerError)
		return
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		http.Error(w, "asset close failed", http.StatusInternalServerError)
		return
	}
	if err := os.Rename(tmpName, absPath); err != nil {
		os.Remove(tmpName)
		http.Error(w, "asset commit failed", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"code": ResultSuccess.Value, "msg": "ok"})
}
