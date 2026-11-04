import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:notee/filesync/file_store.dart';
import 'package:notee/model/record_utils.dart';
import 'package:notee/utils/app_logger.dart';

class _SearchIndexUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// FTS5 full-text search index for note content.
///
/// Two virtual tables:
///   - [records_idx]       : trigram tokenizer, ≥3 char exact substring match.
///   - [records_idx_cjk]   : unicode61 tokenizer, stores pre-tokenized **unigram**
///                         CJK — every Chinese character gets a space so
///                         unicode61 indexes each individually. "笔记本" →
///                         "笔 记 本". Enables 1- and 2-char Chinese queries.
///
/// Query routing:
///   ≥3 char             → records_idx MATCH (phrase) + snippet()
///   1-2 char all-CJK    → records_idx_cjk MATCH (phrase) + snippet() + stripSpaces
///   1-2 char Latin/mix  → LIKE scan on records_idx.content
///
/// Why phrase query with quotes? unigram table stores "你 好 啊". Plain
/// `MATCH '你 啊'` is implicit AND — any doc containing both chars returns
/// (even non-adjacent like "你好天气啊"). But `MATCH '"你 啊"'` is a **phrase
/// query** — FTS5 requires the two tokens to be physically adjacent in the
/// stored string, with no other token between them. This gives exact
/// contiguous substring matching without LIKE or any second query.
///
/// Why query also per-char spaced? unicode61 treats contiguous CJK as one
/// token (CJK chars are Unicode Lo-letter class). So both sides must match:
/// index "笔 记" ↔ query "笔 记" — otherwise zero hits.
class SearchIndex {
  final File file;
  final FileStore fileStore;
  late final QueryExecutor _db;

  final _pendingByUuid = <String, Future<void>>{};
  bool _closed = false;

  final _worker = _WorkerIsolate();

  SearchIndex(this.file, this.fileStore);

  Future<void> refresh(String uuid) async {
    try {
      final prev = _pendingByUuid[uuid] ?? Future.value();
      final next = prev.then((_) => _refreshInternal(uuid));
      _pendingByUuid[uuid] = next;
      await next.whenComplete(() {
        if (identical(_pendingByUuid[uuid], next)) {
          _pendingByUuid.remove(uuid);
        }
      });
    } catch (e) {
      if (!_closed) {
        AppLogger.e('SearchIndex', "[SearchIndex] refresh failed uuid=$uuid: $e");
      }
    }
  }

  Future<void> _refreshInternal(String uuid) async {
    if (_closed) return;
    final contentPath = _resolveContentPath(uuid);
    if (contentPath == null) {
      if (!_closed) await _remove(uuid);
      return;
    }
    final String? text;
    try {
      text = await _worker.extractText(contentPath);
    } catch (e) {
      AppLogger.e('SearchIndex', "[SearchIndex] worker extract failed uuid=$uuid: $e");
      return;
    }
    if (_closed) return;
    if (text == null || text.isEmpty) {
      await _remove(uuid);
      return;
    }
    AppLogger.d('SearchIndex', "[SearchIndex] refresh uuid=$uuid len=${text.length}");
    if (!_closed) await _upsert(uuid, text);
  }

  Future<void> open() async {
    _db = NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL;');
        rawDb.execute('PRAGMA synchronous=NORMAL;');
        rawDb.execute('PRAGMA busy_timeout = 5000;');
        rawDb.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS records_idx USING fts5(
            content,
            uuid UNINDEXED,
            tokenize='trigram'
          );
        ''');
        rawDb.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS records_idx_cjk USING fts5(
            tokens,
            uuid UNINDEXED,
            tokenize='unicode61'
          );
        ''');
      },
    );
    await _db.ensureOpen(_SearchIndexUser());
    AppLogger.i('SearchIndex', "[SearchIndex] opened ${file.path}");
  }

  Future<void> close() async {
    _closed = true;
    // Don't await waitForIdle — _refreshInternal's _closed guards below make
    // in-flight refresh bail out before touching _db. We still close _db and
    // dispose the worker; pending refresh futures in _pendingByUuid will
    // complete via the _closed early returns, but we don't wait.
    try {
      await _db.close();
    } catch (_) {}
    _worker.dispose();
    _pendingByUuid.clear();
  }

  Future<void> _upsert(String uuid, String content) async {
    await _db.runCustom('DELETE FROM records_idx WHERE uuid = ?;', [uuid]);
    await _db.runCustom(
      'INSERT INTO records_idx(content, uuid) VALUES (?, ?);', [content, uuid],
    );
    await _db.runCustom('DELETE FROM records_idx_cjk WHERE uuid = ?;', [uuid]);
    if (_cjkCharRegex.hasMatch(content)) {
      await _db.runCustom('INSERT INTO records_idx_cjk(tokens, uuid) VALUES (?, ?);', [
        _tokenizeCjkUnigram(content),
        uuid,
      ]);
    }
  }

  Future<void> _remove(String uuid) async {
    await _db.runCustom('DELETE FROM records_idx WHERE uuid = ?;', [uuid]);
    await _db.runCustom('DELETE FROM records_idx_cjk WHERE uuid = ?;', [uuid]);
  }

  Future<List<List<String>>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      if (q.length >= 3) {
        return await _searchTrigram(q);
      }
      if (_isAllCjk(q)) {
        return await _searchCjkUnigram(q);
      }
      return await _searchLike(q);
    } catch (e) {
      AppLogger.e('SearchIndex', '[SearchIndex] search failed query=$query: $e');
      return [];
    }
  }

  Future<List<List<String>>> _searchTrigram(String q) async {
    final rows = await _db.runSelect(
      '''
      SELECT uuid,
             snippet(records_idx, 0, ?, ?, '...', 120) AS snippet
      FROM records_idx
      WHERE records_idx MATCH ?
      ORDER BY bm25(records_idx);
      ''',
      ['\u0001', '\u0002', _normalizeQuery(q)],
    );
    return rows.map((row) {
      return [row['uuid'] as String, _windowSnippet(row['snippet'] as String)];
    }).toList();
  }

  Future<List<List<String>>> _searchLike(String q) async {
    final escaped = q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
    final rows = await _db.runSelect("SELECT uuid, content FROM records_idx WHERE content LIKE ? ESCAPE '\\';", [
      '%$escaped%',
    ]);
    return rows.map((row) {
      return [row['uuid'] as String, _likeSnippet(row['content'] as String, q)];
    }).toList();
  }

  /// 1-2 char all-CJK query. Single table + phrase query + single snippet().
  /// The key insight: phrase query with quotes ("你 啊") forces FTS5 to
  /// require the unigram tokens to be physically adjacent in the stored
  /// string — i.e., the two CJK chars must be contiguous in the original text.
  /// No LIKE, no JOIN, no content substring. Snippet spaces stripped below.
  Future<List<List<String>>> _searchCjkUnigram(String q) async {
    final phrase = '"${_spaceCjk(q)}"';
    final rows = await _db.runSelect(
      '''
      SELECT uuid,
             snippet(records_idx_cjk, 0, ?, ?, '...', 120) AS snippet
      FROM records_idx_cjk
      WHERE records_idx_cjk MATCH ?
      ORDER BY bm25(records_idx_cjk);
      ''',
      ['\u0001', '\u0002', phrase],
    );
    return rows.map((row) {
      final stripped = _stripCjkSpaces(row['snippet'] as String);
      return [row['uuid'] as String, _windowSnippet(stripped)];
    }).toList();
  }

  String _likeSnippet(String content, String q) {
    final lower = content.toLowerCase();
    final idx = lower.indexOf(q.toLowerCase());
    if (idx < 0) return content;
    final end = idx + q.length;
    final marked = '${content.substring(0, idx)}\u0001${content.substring(idx, end)}\u0002${content.substring(end)}';
    return _windowSnippet(marked);
  }

  String? _resolveContentPath(String uuid) {
    if (fileStore.isWorkFileExist(uuid)) return fileStore.getWorkFile(uuid);
    if (fileStore.isBaseFileExist(uuid)) return fileStore.getBaseFile(uuid);
    return null;
  }

  String _windowSnippet(String input, {int before = 40, int after = 80}) {
    final ftsPrefix = input.startsWith('...');
    final ftsSuffix = input.endsWith('...');
    var body = input;
    if (ftsPrefix) body = body.substring(3);
    if (ftsSuffix) body = body.substring(0, body.length - 3);

    final plain = StringBuffer();
    final hits = <_Range>[];
    int? markStart;
    for (final cu in body.codeUnits) {
      if (cu == 0x01) {
        markStart = plain.length;
      } else if (cu == 0x02) {
        if (markStart != null) {
          hits.add(_Range(markStart, plain.length));
          markStart = null;
        }
      } else {
        plain.writeCharCode(cu);
      }
    }
    final text = plain.toString();
    if (hits.isEmpty) return text;

    final first = hits.first;
    final start = (first.start - before).clamp(0, text.length);
    final end = (first.end + after).clamp(start, text.length);

    final opens = <int>{};
    final closes = <int>{};
    for (final h in hits) {
      if (h.start < end && h.end > start) {
        final s = h.start < start ? start : h.start;
        final e = h.end > end ? end : h.end;
        if (s < e) {
          opens.add(s);
          closes.add(e);
        }
      }
    }

    final out = StringBuffer();
    if (ftsPrefix || start > 0) out.write('...');
    for (int i = start; i < end; i++) {
      if (opens.contains(i)) out.write('\u0001');
      if (closes.contains(i)) out.write('\u0002');
      out.write(text[i]);
    }
    if (closes.contains(end)) out.write('\u0002');
    if (ftsSuffix || end < text.length) out.write('...');
    return out.toString();
  }

  String _normalizeQuery(String input) {
    final q = input.trim();
    if (q.isEmpty) return q;
    return '"${q.replaceAll('"', '""')}"';
  }

  // --- CJK unigram helpers ---

  static final _cjkCharRegex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]');

  /// Every CJK character becomes its own token by surrounding with spaces.
  /// "te你好sts" → "te 你 好 sts"   (not "te你 好sts"!)
  /// "笔记本"    → "笔 记 本"
  String _tokenizeCjkUnigram(String input) =>
      input.replaceAllMapped(_cjkCharRegex, (m) => ' ${m[0]} ').replaceAll(RegExp(r'\s+'), ' ').trim();

  bool _isAllCjk(String input) => input.isNotEmpty && _cjkCharRegex.allMatches(input).length == input.length;

  /// Space-separate all CJK chars for the unicode61 phrase query.
  /// "你啊" → "你 啊". Single char passes through.
  String _spaceCjk(String input) {
    if (input.length <= 1) return input;
    final buf = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      if (i > 0) buf.write(' ');
      buf.write(input[i]);
    }
    return buf.toString();
  }

  /// Strip tokenizer-added spaces from CJK bigram/unigram snippets,
  /// but preserve original Latin/number spaces. A space is stripped only
  /// when both surrounding chars are CJK or highlight markers (U+0001/U+0002).
  ///   "你 [好 啊] world 很 好" → "你[好啊] world 很好"
  ///   "hello world 你 好"   → "hello world 你好"
  static final _cjkSpaceRegex = RegExp(
    r'(?<=[\u4e00-\u9fff\u3400-\u4dbf\u0001\u0002])\s+(?=[\u4e00-\u9fff\u3400-\u4dbf\u0001\u0002])',
  );
  String _stripCjkSpaces(String snippet) => snippet.replaceAll(_cjkSpaceRegex, '');
}

class _Range {
  final int start;
  final int end;
  _Range(this.start, this.end);
}

// --- Background worker isolate ---

class _WorkerMessage {
  final int id;
  final String path;
  _WorkerMessage(this.id, this.path);
}

class _WorkerResult {
  final int id;
  final String? value;
  _WorkerResult(this.id, this.value);
}

class _WorkerIsolate {
  SendPort? _send;
  ReceivePort? _receive;
  final _pending = <int, Completer<String?>>{};
  int _nextId = 0;
  Completer<void>? _init;

  Future<void> _ensure() async {
    if (_send != null) return;
    if (_init == null) {
      _init = Completer<void>();
      _receive = ReceivePort();
      _receive!.listen((message) {
        if (message is SendPort) {
          _send = message;
          final c = _init;
          _init = null;
          c?.complete();
        } else if (message is _WorkerResult) {
          _pending.remove(message.id)?.complete(message.value);
        }
      });
      await Isolate.spawn(_workerMain, _receive!.sendPort, debugName: 'notee-worker');
    }
    final c = _init;
    if (c != null) await c.future;
  }

  Future<String?> extractText(String path) async {
    await _ensure();
    final id = _nextId++;
    final c = Completer<String?>();
    _pending[id] = c;
    _send!.send(_WorkerMessage(id, path));
    return c.future;
  }

  void dispose() {
    _send = null;
    _init = null;
    _pending.clear();
    _receive?.close();
    _receive = null;
  }
}

void _workerMain(SendPort mainSend) {
  final receive = ReceivePort();
  mainSend.send(receive.sendPort);

  receive.listen((message) {
    if (message is _WorkerMessage) {
      String? result;
      try {
        final text = RecordUtils.extractTextFromFile(message.path);
        if (text != null && text.isNotEmpty) {
          result = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
        }
      } catch (e, st) {
        AppLogger.e('SearchIndex', 'extract failed path=${message.path} error=$e\n$st');
      }
      mainSend.send(_WorkerResult(message.id, result));
    }
  });
}
