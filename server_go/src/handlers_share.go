package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Share files are stored under {recordsFolder}/user_{id}/share/ named {uuid}.{unixTime}.{lifeSeconds}.
// The download URL is /note/d/{userId}/{title}.md?token={base64}, where the token is AES-GCM(uuid).
// Each share overwrites any previous share of the same record (same uuid → delete old before create).
// Expiry is stored server-side in the filename and checked at download time.
// Expired files are also swept lazily: each new share by the same user sweeps the folder.

const (
	shareMinLife = int64(60)             // 1 minute
	shareMaxLife = int64(30 * 24 * 3600) // 30 days
)

func (s *Server) getShareFolder(userId int64) string {
	return filepath.Join(s.recordsFolder, "user_"+strconv.FormatInt(userId, 10), "share")
}

// shareKey derives a 32-byte AES key from the user's stored password hash.
// Using the per-user password means changing the password revokes all of that user's share links.
func shareKey(passwordHash string) []byte {
	k := sha256.Sum256([]byte(passwordHash))
	return k[:]
}

// encryptShareUUID encrypts only the record uuid with AES-256-GCM and returns a URL-safe base64 token.
func encryptShareUUID(uuid string, key []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	ct := gcm.Seal(nonce, nonce, []byte(uuid), nil)
	return base64.RawURLEncoding.EncodeToString(ct), nil
}

// decryptShareUUID reverses encryptShareUUID.
func decryptShareUUID(token string, key []byte) (string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(raw) < gcm.NonceSize() {
		return "", io.ErrUnexpectedEOF
	}
	nonce, ct := raw[:gcm.NonceSize()], raw[gcm.NonceSize():]
	pt, err := gcm.Open(nil, nonce, ct, nil)
	if err != nil {
		return "", err
	}
	return string(pt), nil
}

// parseShareName splits {uuid}.{unixTime}.{lifeSeconds}; returns ok=false on malformed names.
func parseShareName(name string) (uuid string, unixTime int64, life int64, ok bool) {
	parts := strings.Split(name, ".")
	if len(parts) != 3 || !isValidRecordUUID(parts[0]) {
		return "", 0, 0, false
	}
	t, err1 := strconv.ParseInt(parts[1], 10, 64)
	l, err2 := strconv.ParseInt(parts[2], 10, 64)
	if err1 != nil || err2 != nil || t <= 0 || l <= 0 {
		return "", 0, 0, false
	}
	return parts[0], t, l, true
}

// deleteSharesByRecord removes every share file that belongs to the given record uuid.
func (s *Server) deleteSharesByRecord(userId int64, uuid string) {
	folder := s.getShareFolder(userId)
	matches, err := filepath.Glob(filepath.Join(folder, uuid+".*"))
	if err != nil {
		return
	}
	for _, m := range matches {
		os.Remove(m)
	}
}

// sweepExpiredShares deletes expired share files in the user's share folder.
func (s *Server) sweepExpiredShares(userId int64) {
	folder := s.getShareFolder(userId)
	entries, err := os.ReadDir(folder)
	if err != nil {
		return
	}
	now := time.Now().Unix()
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		_, unixTime, life, ok := parseShareName(e.Name())
		if ok && unixTime+life <= now {
			os.Remove(filepath.Join(folder, e.Name()))
		}
	}
}

// shareUploadHandler accepts a markdown file plus life (seconds) and returns the download URL.
// Each share overwrites any previous share of the same record by this user.
func (s *Server) shareUploadHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	uuid := r.URL.Query().Get("uuid")
	if !isValidRecordUUID(uuid) {
		http.Error(w, "invalid uuid", ResultErrorParams.Value)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, s.maxFileSize)

	file, _, formFileErr := r.FormFile("file")
	if formFileErr != nil {
		http.Error(w, "file required or exceeds "+strconv.FormatInt(s.maxFileSize>>20, 10)+"MB limit", ResultErrorParams.Value)
		return
	}
	defer file.Close()

	life, err := getFormInt64(r, "life")
	if err != nil || life < shareMinLife || life > shareMaxLife {
		http.Error(w, "invalid life", ResultErrorParams.Value)
		return
	}

	// Lazy cleanup: piggyback expired-share removal on this user's share request
	s.sweepExpiredShares(user.UserID)

	dbUser, err := s.db.GetUserByID(user.UserID)
	if err != nil {
		http.Error(w, "user not found", ResultErrorParams.Value)
		return
	}

	// Overwrite any previous share of this record
	s.deleteSharesByRecord(user.UserID, uuid)

	// Filename: {uuid}.{time}.{life} — uuid prefix enables overwrite + record-delete cleanup,
	// time+life enable server-side expiry check
	name := uuid + "." + strconv.FormatInt(time.Now().Unix(), 10) + "." + strconv.FormatInt(life, 10)
	absPath := filepath.Join(s.getShareFolder(user.UserID), name)
	if err := os.MkdirAll(filepath.Dir(absPath), 0755); err != nil {
		http.Error(w, err.Error(), ResultErrorRecordSave.Value)
		return
	}
	tmp, err := os.CreateTemp(filepath.Dir(absPath), name+".*.tmp")
	if err != nil {
		http.Error(w, err.Error(), ResultErrorRecordSave.Value)
		return
	}
	tmpPath := tmp.Name()
	if _, err := io.Copy(tmp, file); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		http.Error(w, err.Error(), ResultErrorRecordSave.Value)
		return
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		http.Error(w, err.Error(), ResultErrorRecordSave.Value)
		return
	}
	if err := os.Rename(tmpPath, absPath); err != nil {
		os.Remove(tmpPath)
		http.Error(w, err.Error(), ResultErrorRecordSave.Value)
		return
	}

	// Token only encrypts the uuid — time and life are server-side only
	encToken, err := encryptShareUUID(uuid, shareKey(dbUser.Password))
	if err != nil {
		http.Error(w, err.Error(), ResultErrorRecordSave.Value)
		return
	}

	// Path segment after userId is purely cosmetic (the note title shown to viewers);
	// the real on-disk filename is recovered from the decrypted uuid + glob.
	display := strings.TrimSpace(r.FormValue("title"))
	display = strings.Map(func(r rune) rune {
		switch r {
		case '/', '\\', '?', '#', '&', '=', ' ', '\t', '\n', '\r', ':':
			return '_'
		}
		return r
	}, display)
	if display == "" {
		display = "note"
	}

	w.Header().Set("content-type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"url": "/note/d/" + strconv.FormatInt(user.UserID, 10) + "/" + display + ".md?token=" + encToken,
	})
}

// shareDownloadHandler serves a shared file when the token decrypts and the file is not expired.
// Route: /note/d/{userId}/{anyName}.md?token={base64}, no login required.
// The {anyName} path segment is cosmetic; the uuid is recovered by decrypting the token,
// then the on-disk file is found via glob and checked for expiry.
func (s *Server) shareDownloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/note/d/")
	slash := strings.Index(rest, "/")
	if slash <= 0 {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	userId, err := strconv.ParseInt(rest[:slash], 10, 64)
	if err != nil {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}

	dbUser, err := s.db.GetUserByID(userId)
	if err != nil {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	uuid, err := decryptShareUUID(token, shareKey(dbUser.Password))
	if err != nil {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	if !isValidRecordUUID(uuid) {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}

	// Glob to find the actual file (may have .time.life suffix)
	folder := s.getShareFolder(userId)
	matches, _ := filepath.Glob(filepath.Join(folder, uuid+".*"))
	if len(matches) == 0 {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	absPath := matches[0]
	baseName := filepath.Base(absPath)
	_, unixTime, life, ok := parseShareName(baseName)
	if !ok {
		http.Error(w, "invalid link", ResultErrorParams.Value)
		return
	}
	if unixTime+life <= time.Now().Unix() {
		http.Error(w, "link expired", http.StatusGone)
		return
	}

	f, err := os.Open(absPath)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	defer f.Close()

	w.Header().Set("content-type", "text/markdown; charset=utf-8")
	w.Header().Set("content-disposition", "inline; filename=\""+uuid+".md\"")
	http.ServeContent(w, r, uuid+".md", time.Now(), f)
}
