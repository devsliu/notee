package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	_ "embed"
)

//go:embed static/admin.html
var adminHTML []byte

var adminSession = struct {
	sync.Map
}{}

// newAdminSessionID generates a random session ID.
// Must NOT use a fixed value; otherwise anyone carrying an "admin_session=<fixed>" Cookie could impersonate an admin
func newAdminSessionID() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		// Crypto-secure random source unavailable — a critical environment failure. Fall back to an unguessable nanosecond timestamp,
		// but never to a fixed constant
		return fmt.Sprintf("admin-%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

// ---- user handlers ----

// register user
func (s *Server) registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Name     string `json:"name"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	// Protocol convention: the client sends md5(name_password) hash for both register and login;
	// the server re-hashes it with a per-user random salt before storage, and verifies with the same salt at login
	userId, err := s.db.CreateUser(req.Name, req.Password)
	if err != nil {
		http.Error(w, "User exists or DB error", http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"userId": userId})
}

// user login
func (s *Server) loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Name     string `json:"name"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	// Look up user
	user, err := s.db.GetUserByNamePass(req.Name, req.Password)
	if err != nil {
		http.Error(w, ResultErrorUserPasswordError.Message, ResultErrorUserPasswordError.Value)
		return
	}
	token := generateToken()
	now := time.Now()
	expireAt := now.Add(tokenTTL)
	// Store in memory (multi-device: append session; kick oldest when cap exceeded)
	memUser := s.getOrCreateCacheUser(user.ID, req.Name, user.PurgedVersion)
	memUser.addSession(TokenSession{
		Token:     token,
		ExpireAt:  expireAt,
		CreatedAt: now,
	}, s.maxDevices)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"userId":   user.ID,
		"token":    token,
		"expireAt": expireAt.Unix(),
	})
}

// changePassword changes the current user's password.
// oldPassword / newPassword are both client-side md5(name_password) hashes.
// On success all sessions are cleared so every device must log in with the new password.
func (s *Server) changePasswordHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	var req struct {
		OldPassword string `json:"oldPassword"`
		NewPassword string `json:"newPassword"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	if req.OldPassword == "" || req.NewPassword == "" {
		http.Error(w, ResultErrorParams.Message, ResultErrorParams.Value)
		return
	}
	// Verify old password against the stored salted hash
	if _, err := s.db.GetUserByNamePass(user.UserName, req.OldPassword); err != nil {
		http.Error(w, ResultErrorUserPasswordError.Message, ResultErrorUserPasswordError.Value)
		return
	}
	// UpdateUser generates a fresh salt and stores md5(newPassword + salt)
	if err := s.db.UpdateUser(user.UserID, user.UserName, req.NewPassword); err != nil {
		http.Error(w, ResultErrorDatabase.Message, ResultErrorDatabase.Value)
		return
	}
	// Invalidate all sessions: password changed, every device must re-login
	s.deleteCacheUser(user.UserID)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"ok": true})
}

// queryAPIStat queries API call statistics for the current user
func (s *Server) queryAPIStatHandler(w http.ResponseWriter, r *http.Request, user *CacheUser, token string) {
	stats, err := s.db.QueryAPIStats(user.UserID)
	if err != nil {
		http.Error(w, "DB error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(stats)
}

// ---- admin handlers ----

// adminLogin admin login
func (s *Server) adminLoginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct{ Username, Password string }
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	if req.Username == s.adminUser && req.Password == s.adminPass {
		sessionID := newAdminSessionID()
		adminSession.Store(sessionID, true)
		http.SetCookie(w, &http.Cookie{
			Name:     "admin_session",
			Value:    sessionID,
			Path:     "/",
			HttpOnly: true,
			SameSite: http.SameSiteStrictMode,
		})
		w.Write([]byte(`{"ok":true}`))
	} else {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
	}
}

// adminAuth admin authentication middleware
func (s *Server) adminAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("admin_session")
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		if _, ok := adminSession.Load(cookie.Value); !ok {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

// adminCreateUser creates a user
func (s *Server) adminCreateUserHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct{ Name, Password string }
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	// Admin page and client share the same protocol: the browser has already computed md5(name_password);
	// the server re-hashes it with a per-user salt before storage
	_, err := s.db.CreateUser(req.Name, req.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Write([]byte(`{"ok":true}`))
}

// adminUpdateUser lets admin update user info (name, password) and clears tokens
func (s *Server) adminUpdateUserHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		UserID   int64  `json:"UserID"`
		Name     string `json:"Name"`
		Password string `json:"Password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	// The admin-page browser has already computed md5(name_password); the server re-hashes it with a fresh salt.
	// Empty Password means keep the original password and only update the name.
	if err := s.db.UpdateUser(req.UserID, req.Name, req.Password); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	// Clear all tokens for this user
	s.deleteCacheUser(req.UserID)
	w.Write([]byte(`{"ok":true}`))
}

// adminListUsers lists all users
func (s *Server) adminListUsersHandler(w http.ResponseWriter, r *http.Request) {
	users, err := s.db.ListUsers()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(users)
}

// adminDeleteUser deletes a user
func (s *Server) adminDeleteUserHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct{ UserID int64 }
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	err := s.db.DeleteUser(req.UserID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.deleteCacheUser(req.UserID)
	s.deleteRecordFilesByUser(req.UserID)
	w.Write([]byte(`{"ok":true}`))
}
