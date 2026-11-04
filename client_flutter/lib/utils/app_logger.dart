// lib/utils/app_logger.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppLogEntry {
  final int id;
  final int time;
  final String level;
  final String tag;
  final String content;
  AppLogEntry({required this.id, required this.time, required this.level, required this.tag, required this.content});
}

class _AppLoggerUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

class AppLogger {
  static const _maxEntries = 5000;
  static QueryExecutor? _db;
  static Completer<void>? _opening;

  static const String levelDebug = 'DEBUG';
  static const String levelInfo = 'INFO';
  static const String levelWarn = 'WARN';
  static const String levelError = 'ERROR';

  static Future<void> _ensureOpen() async {
    if (_db != null) return;
    if (_opening != null) return _opening!.future;
    _opening = Completer<void>();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, 'app_logs.db');
      _db = NativeDatabase.createInBackground(
        File(dbPath),
        setup: (rawDb) {
          rawDb.execute('PRAGMA journal_mode=WAL;');
          rawDb.execute('PRAGMA synchronous=NORMAL;');
          rawDb.execute('''
            CREATE TABLE IF NOT EXISTS app_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              time INTEGER NOT NULL,
              level TEXT NOT NULL,
              tag TEXT NOT NULL,
              content TEXT NOT NULL
            );
          ''');
        },
      );
      await _db!.ensureOpen(_AppLoggerUser());
    } finally {
      _opening!.complete();
      _opening = null;
    }
  }

  static Future<List<AppLogEntry>> queryAll() async {
    await _ensureOpen();
    final rows = await _db!.runSelect(
      'SELECT id, time, level, tag, content FROM app_logs ORDER BY id DESC LIMIT $_maxEntries',
      const <Object?>[],
    );
    return rows
        .map(
          (r) => AppLogEntry(
            id: r['id'] as int,
            time: r['time'] as int,
            level: r['level'] as String,
            tag: r['tag'] as String,
            content: r['content'] as String,
          ),
        )
        .toList();
  }

  static Future<void> clear() async {
    await _ensureOpen();
    await _db!.runCustom('DELETE FROM app_logs');
  }

  static String _nowStr() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}."
        "${now.millisecond.toString().padLeft(3, '0')}";
  }

  static void log(String level, String tag, String content) {
    developer.log('[${_nowStr()}][$tag] $content');
    _insert(level, tag, content);
  }

  static Future<void> _insert(String level, String tag, String content) async {
    try {
      await _ensureOpen();
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db!.runCustom('INSERT INTO app_logs (time, level, tag, content) VALUES (?, ?, ?, ?)', [
        now,
        level,
        tag,
        content,
      ]);
    } catch (_) {}
  }

  /// Keep only the latest [_maxEntries] rows.
  static Future<void> prune() async {
    await _ensureOpen();
    await _db!.runCustom(
      'DELETE FROM app_logs WHERE id <= ('
      'SELECT id FROM app_logs ORDER BY id DESC LIMIT 1 OFFSET $_maxEntries'
      ')',
    );
  }

  static void d(String tag, String message) => log(levelDebug, tag, message);
  static void i(String tag, String message) => log(levelInfo, tag, message);
  static void w(String tag, String message) => log(levelWarn, tag, message);
  static void e(String tag, String message) => log(levelError, tag, message);
}
