package main

import (
	"crypto/md5"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
)

// tokenTTL: token validity period is 30 days; client auto-re-logs in after expiry
const tokenTTL = 30 * 24 * time.Hour

// isValidRecordUUID validates a record uuid: must be a standard UUID to prevent ../ path traversal and arbitrary file access
func isValidRecordUUID(s string) bool {
	_, err := uuid.Parse(s)
	return err == nil
}

// TokenSession represents one active login session (one device / one token).
type TokenSession struct {
	Token     string
	ExpireAt  time.Time // token expiry time
	CreatedAt time.Time // login time (used for kicking the oldest device when over limit)
}

// CacheUser holds user-level data plus all active token sessions across devices.
type CacheUser struct {
	mu            sync.Mutex // protects Sessions
	UserID        int64
	UserName      string
	PurgedVersion atomic.Int64 // atomic for lock-free read/write (handlers access it directly)
	Sessions      []TokenSession
}

type Server struct {
	db            *DB
	userLock      sync.RWMutex
	users         map[int64]*CacheUser // userId -> CacheUser (one per user, with nested sessions)
	maxDevices    int                  // keep at most N active sessions per account; kick oldest when exceeded
	maxFileSize   int64                // max upload size per record file, in bytes
	dirRoot       string               // file storage root directory
	versionDir    string               // version/updates directory (独立挂载点, 避免 Docker 子路径覆盖)
	recordsFolder string               // record file storage root directory
	adminUser     string
	adminPass     string
}

func NewServer(db *DB, fileRoot, versionRoot, adminUser, adminPass string, maxDevices int, maxFileSize int64) *Server {
	recordDir := fileRoot
	os.MkdirAll(recordDir, 0755)
	os.MkdirAll(versionRoot, 0755)
	if maxDevices <= 0 {
		maxDevices = 5
	}
	if maxFileSize <= 0 {
		maxFileSize = 100 << 20
	}
	return &Server{
		db:            db,
		users:         make(map[int64]*CacheUser),
		maxDevices:    maxDevices,
		maxFileSize:   maxFileSize,
		dirRoot:       fileRoot,
		versionDir:    versionRoot,
		recordsFolder: recordDir,
		adminUser:     adminUser,
		adminPass:     adminPass,
	}
}

// generateToken: crypto-secure random 32 bytes → 64-char hex
func generateToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(fmt.Sprintf("crypto/rand failed: %v", err))
	}
	return hex.EncodeToString(b)
}

// ---- CacheUser map helpers (userLock internal, call these instead of touching s.users directly) ----

// getCacheUser returns the CacheUser for userId, or nil if no session exists.
// The returned pointer is valid even if the map entry is later deleted by another goroutine.
func (s *Server) getCacheUser(userId int64) *CacheUser {
	s.userLock.RLock()
	defer s.userLock.RUnlock()
	return s.users[userId]
}

// getOrCreateCacheUser returns the existing CacheUser, or creates a new one and stores it in the map.
// memUser.mu should be used by the caller for any Sessions/PurgedVersion operations.
func (s *Server) getOrCreateCacheUser(userId int64, userName string, purgedVersion int64) *CacheUser {
	s.userLock.Lock()
	defer s.userLock.Unlock()
	if u, ok := s.users[userId]; ok {
		return u
	}
	u := &CacheUser{UserID: userId, UserName: userName}
	u.PurgedVersion.Store(purgedVersion)
	s.users[userId] = u
	return u
}

// deleteCacheUser removes the entire cache entry (all sessions) for userId.
func (s *Server) deleteCacheUser(userId int64) {
	s.userLock.Lock()
	defer s.userLock.Unlock()
	delete(s.users, userId)
}

// removeSessionAndMaybeDelete removes the session with the given token from memUser.
// If it was the last session, the entire map entry is also removed.
// memUser.mu must NOT be held by the caller — this function acquires both locks internally.
func (s *Server) removeSessionAndMaybeDelete(memUser *CacheUser, token string) {
	empty := memUser.removeSession(token)
	if empty {
		s.deleteCacheUser(memUser.UserID)
	}
}

// findSession returns a COPY of the TokenSession matching token, or false if not found.
// A copy is returned (not a pointer) because Sessions slice can be reallocated by concurrent login.
func (u *CacheUser) findSession(token string) (TokenSession, bool) {
	u.mu.Lock()
	defer u.mu.Unlock()
	for _, s := range u.Sessions {
		if s.Token == token {
			return s, true
		}
	}
	return TokenSession{}, false
}

// removeSession removes the session matching token. Returns true if Sessions is now empty.
// Safe for concurrent use — acquires u.mu internally.
func (u *CacheUser) removeSession(token string) bool {
	u.mu.Lock()
	defer u.mu.Unlock()
	out := u.Sessions[:0]
	for _, s := range u.Sessions {
		if s.Token != token {
			out = append(out, s)
		}
	}
	u.Sessions = out
	return len(u.Sessions) == 0
}

// addSession appends a new TokenSession and enforces maxDevices by evicting the oldest.
// Safe for concurrent use — acquires u.mu internally.
func (u *CacheUser) addSession(sess TokenSession, maxDevices int) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.Sessions = append(u.Sessions, sess)
	if maxDevices > 0 && len(u.Sessions) > maxDevices {
		sort.Slice(u.Sessions, func(i, j int) bool {
			return u.Sessions[i].CreatedAt.Before(u.Sessions[j].CreatedAt)
		})
		u.Sessions = u.Sessions[len(u.Sessions)-maxDevices:]
	}
}

func md5OfText(data string) string {
	h := md5.New()
	h.Write([]byte(data))
	return strings.ToUpper(hex.EncodeToString(h.Sum(nil)))
}

func generateMd5Pass(name, pass string) string {
	return md5OfText(fmt.Sprintf("%s_%s", name, pass))
}

func getFormInt64(r *http.Request, key string) (int64, error) {
	valStr := r.FormValue(key)
	return strconv.ParseInt(valStr, 10, 64)
}

// getFormString returns the form value for key and whether the key was present.
// Unlike r.FormValue, it distinguishes "field absent" from "field present but empty".
func getFormString(r *http.Request, key string) (string, bool) {
	if r.MultipartForm == nil {
		_ = r.ParseMultipartForm(0)
	}
	vals, ok := r.Form[key]
	if !ok || len(vals) == 0 {
		return "", false
	}
	return vals[0], true
}

// getFormInt64Opt parses an optional int64 form field.
// Returns (value, present, error); present=false means the field was not sent.
func getFormInt64Opt(r *http.Request, key string) (int64, bool, error) {
	s, ok := getFormString(r, key)
	if !ok {
		return 0, false, nil
	}
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 0, true, err
	}
	return v, true, nil
}

// authAndStatWrapper unifies method validation, login validation, API statistics, and passes userId/token
func (s *Server) authAndStatWrapper(apiName string, method string, handler func(http.ResponseWriter, *http.Request, *CacheUser, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if method != "" && r.Method != method {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}
		userIdStr := r.Header.Get("x-user-id")
		token := r.Header.Get("x-token")
		userId, err := strconv.ParseInt(userIdStr, 10, 64)
		if err != nil {
			http.Error(w, "Unauthorized", ResultErrorAuth.Value)
			return
		}
		memUser := s.getCacheUser(userId)
		if memUser == nil {
			http.Error(w, "Unauthorized: token not found", ResultErrorAuth.Value)
			return
		}
		memSession, found := memUser.findSession(token)
		if !found {
			http.Error(w, "Unauthorized: token not found", ResultErrorAuth.Value)
			return
		}
		// Token genuinely expired: remove it and return 401 so the client logs in manually
		if !memSession.ExpireAt.IsZero() && time.Now().After(memSession.ExpireAt) {
			s.removeSessionAndMaybeDelete(memUser, token)
			http.Error(w, "Unauthorized: token not found", ResultErrorAuth.Value)
			return
		}
		// More than half of TTL consumed: don't remove token; return 562 so client auto-relogin renews
		if !memSession.ExpireAt.IsZero() {
			halfLifeCutoff := memSession.CreatedAt.Add(tokenTTL / 2)
			if time.Now().After(halfLifeCutoff) {
				w.WriteHeader(ResultErrorTokenExpired.Value)
				w.Write([]byte(ResultErrorTokenExpired.Message))
				return
			}
		}
		s.db.UpdateAPIStat(userId, apiName)
		handler(w, r, memUser, token)
	}
}

// RegisterRoutes registers public routes
func (s *Server) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/user/register", s.registerHandler)
	mux.HandleFunc("/user/login", s.loginHandler)
	mux.HandleFunc("/record/update", s.authAndStatWrapper("updateRecord", http.MethodPost, s.updateRecordHandler))
	mux.HandleFunc("/record/updates", s.authAndStatWrapper("updateRecords", http.MethodPost, s.updateRecordsHandler))
	mux.HandleFunc("/record/deletes", s.authAndStatWrapper("deleteRecords", http.MethodPost, s.deleteRecordsHandler))
	mux.HandleFunc("/record/list", s.authAndStatWrapper("queryRecords", http.MethodGet, s.queryRecordsHandler))
	mux.HandleFunc("/record/download", s.authAndStatWrapper("downloadRecord", http.MethodGet, s.downloadRecordFileHandler))
	mux.HandleFunc("/record/clear", s.authAndStatWrapper("clearRecords", http.MethodPost, s.clearRecordsHandler))
	mux.HandleFunc("/record/tombstone_stats", s.authAndStatWrapper("tombstoneStats", http.MethodGet, s.tombstoneStatsHandler))
	mux.HandleFunc("/record/tombstone_purge", s.authAndStatWrapper("purgeTombstones", http.MethodPost, s.purgeTombstonesHandler))
	// Assets: HEAD/GET/PUT on /asset/{recordUuid}/{filename}. Method dispatch is
	// handled inside assetHandler, so the wrapper is registered with any method.
	mux.HandleFunc("/asset/", s.authAndStatWrapper("asset", "", s.assetHandler))
	mux.HandleFunc("/user/change_password", s.authAndStatWrapper("changePassword", http.MethodPost, s.changePasswordHandler))
	mux.HandleFunc("/api_stat/list", s.authAndStatWrapper("queryAPIStat", http.MethodGet, s.queryAPIStatHandler))

	// Public: version upgrade check + static file serve
	mux.HandleFunc("/upgrade/check", s.upgradeHandler)
	mux.Handle("/upgrade/download/", http.StripPrefix("/upgrade/download/", http.FileServer(http.Dir(s.versionDir))))

	// Share: upload requires auth, download is public (AES-GCM token in query string)
	mux.HandleFunc("/note/upload", s.authAndStatWrapper("shareUpload", http.MethodPost, s.shareUploadHandler))
	mux.HandleFunc("/note/d/", s.shareDownloadHandler)
}

// RegisterAdminRoutes registers admin routes
func (s *Server) RegisterAdminRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/admin/login", s.adminLoginHandler)
	mux.HandleFunc("/admin/create_user", s.adminAuth(s.adminCreateUserHandler))
	mux.HandleFunc("/admin/list_users", s.adminAuth(s.adminListUsersHandler))
	mux.HandleFunc("/admin/delete_user", s.adminAuth(s.adminDeleteUserHandler))
	mux.HandleFunc("/admin/update_user", s.adminAuth(s.adminUpdateUserHandler))
	adminPage := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("content-type", "text/html; charset=utf-8")
		w.Write(adminHTML)
	}
	mux.HandleFunc("/admin", adminPage)
	mux.HandleFunc("/", adminPage)
}

// StartHTTPServer starts the HTTP server
func StartHTTPServer(db *DB, fileRoot, versionRoot, addr, adminUser, adminPass string, maxDevices int, maxFileSize int64) error {
	server := NewServer(db, fileRoot, versionRoot, adminUser, adminPass, maxDevices, maxFileSize)
	mux := http.NewServeMux()
	server.RegisterRoutes(mux)
	server.RegisterAdminRoutes(mux)

	fmt.Println("HTTP server started at", addr)
	return http.ListenAndServe(addr, mux)
}
