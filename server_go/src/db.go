package main

import (
	"database/sql"
	"errors"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type DB struct {
	conn *sql.DB
}

func NewDB(dbPath string) (*DB, error) {
	conn, err := sql.Open("sqlite", buildSQLiteDSN(dbPath))
	if err != nil {
		return nil, err
	}
	maxConn := runtime.NumCPU()
	if maxConn < 4 {
		maxConn = 4
	}
	conn.SetMaxOpenConns(maxConn)
	// Keep only 1 idle connection so the others are closed, releasing their
	// SQLite page caches. Otherwise every connection holds a grown page cache
	// forever and RSS climbs with write load and never comes back down.
	conn.SetMaxIdleConns(1)
	// Recycle connections periodically so any driver-level cached memory is freed.
	conn.SetConnMaxIdleTime(5 * time.Minute)
	conn.SetConnMaxLifetime(30 * time.Minute)
	db := &DB{conn: conn}
	if err := db.initUserTable(); err != nil {
		return nil, err
	}
	return db, nil
}

// buildSQLiteDSN converts a DB path to a SQLite file URI with pragmas
func buildSQLiteDSN(dbPath string) string {
	p := filepath.ToSlash(dbPath)
	var uri string
	if filepath.IsAbs(dbPath) {
		uri = "file:///" + strings.TrimPrefix(p, "/")
	} else {
		uri = "file:" + p
	}
	return uri +
		"?_pragma=busy_timeout(5000)" +
		"&_pragma=journal_mode(WAL)" +
		"&_pragma=synchronous(NORMAL)" +
		// Cap each connection's page cache at ~2 MB. Without this, modernc.org/sqlite
		// lets the cache grow unbounded under write load and the memory is never
		// released while the connection stays in the pool.
		"&_pragma=cache_size(-2000)"
}

func (db *DB) initUserTable() error {
	userTable := `
    CREATE TABLE IF NOT EXISTS user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        salt TEXT NOT NULL DEFAULT '',
        createAt INTEGER NOT NULL DEFAULT 0,
		version INTEGER NOT NULL DEFAULT 0,
		purgedVersion INTEGER NOT NULL DEFAULT 0
    );`
	_, err := db.conn.Exec(userTable)
	return err
}

func (db *DB) Close() error {
	return db.conn.Close()
}

// txMaxAttempts max retries on write-transaction conflict
const txMaxAttempts = 5

// ExecInTransaction executes fn within a transaction and commits. WAL + SQLite_BUSY_SNAPSHOT optimistic retry
func (db *DB) ExecInTransaction(fn func(tx *sql.Tx) error) error {
	var err error
	for attempt := 0; attempt < txMaxAttempts; attempt++ {
		err = db.runTransaction(fn)
		if err == nil || !isSQLiteBusy(err) {
			return err
		}
		if attempt < txMaxAttempts-1 {
			time.Sleep(time.Duration(1<<attempt) * 10 * time.Millisecond)
		}
	}
	return err
}

func (db *DB) runTransaction(fn func(tx *sql.Tx) error) (err error) {
	tx, err := db.conn.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		} else {
			err = tx.Commit()
		}
	}()
	err = fn(tx)
	return err
}

// isSQLiteBusy checks whether err is SQLITE_BUSY (including extended codes BUSY_SNAPSHOT/BUSY_TIMEOUT)
func isSQLiteBusy(err error) bool {
	var coder interface{ Code() int }
	if errors.As(err, &coder) {
		return coder.Code()&0xff == 5
	}
	return false
}
