import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'database.dart';
import 'http_api.dart';
import 'sync_exception.dart';
import 'table_record.dart';
import '../utils/app_logger.dart';

/// Manages sync-type KV configs for the current user.
///
/// Owns an in-memory cache (key => value) that is loaded from the DB on
/// [Repository] open and kept in sync with every [set]/[markDeleted] call.
/// UI reads configs from the cache (O(1)) and listens to [notifier] to rebuild
/// when values change. Callers never touch the DB directly — all access goes
/// through this class so cache + DB stay consistent.
///
/// Sync semantics (mirrors server behaviour):
/// - set(key, value)  → upsert, state=unsynced (will be uploaded next sync)
/// - markDeleted(key) → sets value="" + state=unsynced; the server deletes the
///                      key on next upload. The row is physically removed only
///                      after the server confirms (handled by SyncEngine).
class SyncConfigs {
  AppDatabase? _db;

  /// In-memory cache of all sync-type configs (key => value).
  final Map<String, String> _cache = {};

  /// Ticks whenever [_cache] changes (set / delete / reload).
  /// UI components listen to this to rebuild (e.g. read-only folder icons).
  final ValueNotifier<int> notifier = ValueNotifier(0);

  /// Whether this instance is bound to an open DB.
  bool get isBound => _db != null;

  /// (Re)load the cache from the DB. Called on open and after a successful
  /// config download (so the cache reflects server-side changes).
  Future<void> load(AppDatabase db) async {
    _db = db;
    _cache
      ..clear()
      ..addAll(await db.getAllSyncConfigs());
    notifier.value++;
  }

  /// Drop the DB reference and clear the cache. Called on close.
  void dispose() {
    _db = null;
    _cache.clear();
    notifier.value++;
  }

  static const Duration _configSyncInterval = Duration(hours: 12);

  /// Config sync (upload + download) throttled to once per 12 hours.
  /// Called from [Repository.syncRecords] after record sync completes.
  Future<void> sync() async {
    final db = _db;
    if (db == null) return;
    final lastSyncMs = await db.getConfigInt(KVConfigs.lastConfigSyncTime, 0);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lastSyncMs > 0 && nowMs - lastSyncMs < _configSyncInterval.inMilliseconds) {
      return;
    }
    await _doSync(db);
  }

  /// Force a config-only sync (upload + download), bypassing the 12h throttle.
  /// Does NOT touch any sync-state notifier, so the sync-status UI is not
  /// affected. Use this after local config changes (e.g. read-only folders).
  Future<void> syncNow() async {
    final db = _db;
    if (db == null) return;
    await _doSync(db);
  }

  Future<void> _doSync(AppDatabase db) async {
    try {
      // 1. Upload: all sync-type configs with state == unsynced
      final unsynced = await db.getUnsyncedSyncConfigs();
      if (unsynced.isNotEmpty) {
        final uploadPayload = unsynced.map((k, v) => MapEntry(k, v as String?));
        final result = await HttpApi.uploadConfigs(uploadPayload);
        if (!result.isSuccess()) {
          throw SyncException(result.message, null, result.code);
        }
        // All unsynced configs were accepted by the server (empty values are
        // stored as "" server-side). On the next download they come back as
        // "" and overwrite the local rows.
        await db.markSyncConfigsSynced(unsynced.keys.toList());
      }

      // 2. Download: all server configs, merge into local
      final download = await HttpApi.downloadConfigs();
      if (!download.isSuccess()) {
        throw SyncException(download.message, null, download.code);
      }
      final serverConfigs = download.data ?? {};
      for (final entry in serverConfigs.entries) {
        // Empty string from server means "cleared" → store as "".
        final value = entry.value.isEmpty ? '' : entry.value;
        await db.upsertServerConfig(entry.key, value);
      }
      // The server never removes keys (empty string means "deleted"), so every
      // synced local key is always present in the download — no cleanup needed.

      // 3. Update last sync time + refresh cache from DB
      await db.setIntValue(KVConfigs.lastConfigSyncTime, DateTime.now().millisecondsSinceEpoch);
      await load(db);
      AppLogger.i('SyncConfigs', "sync done, uploaded=${unsynced.length}, downloaded=${serverConfigs.length}");
    } catch (e) {
      AppLogger.w('SyncConfigs', "sync failed: $e");
    }
  }

  /// Read a sync-type config from the in-memory cache (O(1), no DB hit).
  /// Returns null if the key is absent.
  String? get(String key) => _cache[key];

  /// Set a sync-type config: updates the cache immediately (so UI reads reflect
  /// the change on the next frame) AND persists to the DB with state=unsynced
  /// so it will be uploaded on the next sync.
  Future<void> set(String key, String value) async {
    final db = _db;
    _cache[key] = value;
    notifier.value++;
    if (db != null) await db.setSyncConfig(key, value);
  }

  /// Locally delete a sync-type config: sets value="" and state=unsynced in the
  /// DB (so the server removes the key on next upload) and updates the cache
  /// to "" (callers treat empty as "deleted").
  Future<void> markDeleted(String key) async {
    final db = _db;
    _cache[key] = '';
    notifier.value++;
    if (db != null) await db.markSyncConfigDeleted(key);
  }

  // ---------------------------------------------------------------------------
  // Read-only folder helpers (convenience over the read_only_folders config)
  // ---------------------------------------------------------------------------

  /// The list of read-only folder paths (each ends with '/').
  /// Returns an empty list if the config is unset or empty.
  List<String> getReadOnlyFolders() {
    final raw = get(KVConfigs.readOnlyFolders);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// True if [path] is a read-only folder or lives inside one.
  /// [path] must end with '/' for folders; for files pass the parent folder path.
  bool isPathReadOnly(String path) {
    final folders = getReadOnlyFolders();
    if (folders.isEmpty) return false;
    for (final f in folders) {
      if (path == f || path.startsWith(f)) return true;
    }
    return false;
  }
}
