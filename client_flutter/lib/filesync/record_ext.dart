// Path utilities for the record tree's "slash-prefixed and slash-suffixed"
// folder path convention. These are pure functions with no dependency on
// RecordTree state.

import 'dart:convert';
import 'dart:io';

import 'database.dart';
import 'remote_record.dart';
import 'table_record.dart';

export 'path_utils.dart';

// ============================================================================
// Record model helpers (tag extraction, DB convenience extensions)
// ============================================================================

/// Wrapper that groups LocalRecord (DB row) with a lazily-constructed RemoteRecord.
/// Use [local] for DB column access, [remote] for server-authoritative values.
/// [remoteJson] stores the full server snapshot (all 11 RemoteRecord fields).
/// The 3 columns remoteVersion/remoteMd5/remoteFileVersion are redundant indexed copies
/// kept only for SQL WHERE/ORDER BY; [remote] is decoded straight from [remoteJson].
class RecordEntry {
  final LocalRecord local;
  late final RemoteRecord remote = _decodeRemote();
  late final List<String> tags = local.tags.isEmpty ? [] : TagFormat.parse(local.tags);
  RecordEntry(this.local);

  String get uuid => local.uuid;

  RemoteRecord _decodeRemote() {
    if (local.remoteJson.isEmpty) {
      return RemoteRecord(
        uuid: local.uuid,
        path: '',
        name: '',
        version: 0,
        createAt: 0,
        editAt: 0,
        fileEditAt: 0,
        fileVersion: 0,
        deleteAt: 0,
        md5: '',
        locked: 0,
        tags: '',
      );
    }
    return RemoteRecord.fromJson(jsonDecode(local.remoteJson) as Map<String, dynamic>);
  }
}

// LocalRecord convenience extensions.
// Only keep status-derived getters. Field values are read directly:
//   Local-edit related: name/path/editAt/fileEditAt/version/editType
//   Remote authoritative: remoteVersion/remoteMd5/remoteFileVersion (columns),
//                          createAt/editAt/fileEditAt/locked/name/path/reminder (via RecordEntry.remote from remoteJson)

extension LocalRecordExt on LocalRecord {
  // ========= Status queries (derived, not direct field reads) =========

  /// Local file/metadata edit status (edit only, not delete)
  bool get isLocalEdit => editType == LocalEditType.edit;

  /// Local deletion status
  bool get isLocallyDeleted => editType == LocalEditType.delete;

  /// Conflict detection: local has edit (non-delete) && local baseline version != server version
  /// Local deletion is not considered a conflict (deletion is an independent push flow)
  bool get syncConflict => editType == LocalEditType.edit && version != remoteVersion;

  /// Whether synced (no pending upload changes)
  bool get isSynced => editType == LocalEditType.none;
}

class TagFormat {
  /// Parse a stored tag string into a list of tag names.
  static List<String> parse(String raw) {
    if (raw.isEmpty) return [];
    return raw.split('|').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  /// Serialize a list of tag names into the stored format `|a|b|`.
  static String serialize(List<String> tags) {
    final cleaned = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
    if (cleaned.isEmpty) return '';
    return '|${cleaned.join('|')}|';
  }
}

// ============================================================================
// Section data classes (public, shared with Go server's headerSection struct)
// ============================================================================

/// Section-kind strings for the file-level header `[[image:27,content:15234]]`.
/// Called "kind" (not "tag") to avoid colliding with Record.tags.
const String kImageSection = 'image';
const String kContentSection = 'content';

/// A single section described by the file-level header `[[kind:len,...]]`.
/// [offset] is the absolute byte offset from the file start where this
/// section's body begins; [len] is the UTF-8 byte count of the body.
class NoteSection {
  final String kind;
  final int offset;
  final int len;
  const NoteSection(this.kind, this.offset, this.len);

  bool get isImage => kind == kImageSection;
  bool get isContent => kind == kContentSection;
}

/// The result of peeking and parsing a file-level header: the ordered
/// section table plus the byte offset right after the closing "]]".
class HeaderParse {
  final List<NoteSection> sections;
  final int headerEnd;
  const HeaderParse(this.sections, this.headerEnd);
}

// ============================================================================
// NoteSections — unified entry point for reading/writing note file sections
// ============================================================================

/// All logic around the file-level section header `[[kind:len,...]]`.
///
/// A note file is laid out as:
///   [[image:27,content:15234]]<27 bytes image JSON><15234 bytes content body>
///
/// The header always fits within the first 4KB of the file, so path-based
/// readers only peek 4KB to resolve offsets before reading full sections.
class RecordSections {
  // --- Low-level header parsing (private) ---

  /// Returns the index of the second ']' in the first occurrence of "]]" in bytes,
  /// or -1 if not found. Only scans up to the first 4KB — caller guarantees the
  /// file-level header always fits within that range.
  static int _indexOfDoubleClose(List<int> bytes) {
    const int limit = 4096;
    final int n = bytes.length < limit ? bytes.length : limit;
    for (int i = 1; i < n; i++) {
      if (bytes[i - 1] == 0x5D && bytes[i] == 0x5D) return i;
    }
    return -1;
  }

  /// Parse the header content between "[[" and "]]" into [(kind, len), ...].
  /// Format: "kind:len,kind:len,..."
  static List<(String kind, int len)> _parseHeader(String header) {
    final result = <(String, int)>[];
    if (header.isEmpty) return result;
    for (final part in header.split(',')) {
      final colon = part.indexOf(':');
      if (colon <= 0 || colon == part.length - 1) continue;
      final kind = part.substring(0, colon).trim();
      final lenStr = part.substring(colon + 1).trim();
      final len = int.tryParse(lenStr);
      if (kind.isEmpty || len == null || len < 0) continue;
      result.add((kind, len));
    }
    return result;
  }

  /// Read the first 4KB of [filePath] and parse the file-level header.
  /// Returns null when the header is missing/malformed or the file can't be read.
  /// This function ONLY parses the header — it does NOT extract section bodies.
  static HeaderParse? _peekHeaderFile(String filePath) {
    try {
      final f = File(filePath);
      if (!f.existsSync()) return null;
      final raf = f.openSync(mode: FileMode.read);
      final totalLen = raf.lengthSync();
      final peekLen = totalLen < 4096 ? totalLen : 4096;
      final peek = raf.readSync(peekLen);
      raf.closeSync();
      if (peek.length < 2 || peek[0] != 0x5B || peek[1] != 0x5B) return null;
      final closeIdx = _indexOfDoubleClose(peek);
      if (closeIdx <= 1) return null;
      final headerEnd = closeIdx + 1;
      final headerStr = utf8.decode(peek.sublist(2, closeIdx - 1));
      final parsed = _parseHeader(headerStr);
      if (parsed.isEmpty) return null;
      final sections = <NoteSection>[];
      int cur = headerEnd;
      for (final (kind, len) in parsed) {
        sections.add(NoteSection(kind, cur, len));
        cur += len;
      }
      return HeaderParse(sections, headerEnd);
    } catch (_) {
      return null;
    }
  }

  /// Same as [_peekHeaderFile] but operates on an already-in-memory byte array.
  static HeaderParse? _peekHeaderBytes(List<int> bytes) {
    if (bytes.length < 2 || bytes[0] != 0x5B || bytes[1] != 0x5B) return null;
    final closeIdx = _indexOfDoubleClose(bytes);
    if (closeIdx <= 1) return null;
    final headerEnd = closeIdx + 1;
    final headerStr = utf8.decode(bytes.sublist(2, closeIdx - 1));
    final parsed = _parseHeader(headerStr);
    if (parsed.isEmpty) return null;
    final sections = <NoteSection>[];
    int cur = headerEnd;
    for (final (kind, len) in parsed) {
      sections.add(NoteSection(kind, cur, len));
      cur += len;
    }
    return HeaderParse(sections, headerEnd);
  }

  static List<String> _parseAssetJson(String json) {
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const <String>[];
    }
  }

  // --- Read a file fully (shared between path-based readers) ---

  static List<int> _readFileBytes(String filePath) {
    try {
      return File(filePath).readAsBytesSync();
    } catch (_) {
      return const <int>[];
    }
  }

  // ==========================================================================
  // Public API: path-based (disk I/O, minimal reads)
  // ==========================================================================

  /// Extract asset filenames from a record file on disk.  Only reads the full
  /// file if the image section straddles the 4KB header peek — otherwise the
  /// peek alone is enough.  Returns [] for legacy or plain-body files.
  static List<String> extractAssetNamesFromPath(String filePath) {
    final peek = _peekHeaderFile(filePath);
    if (peek == null) return const <String>[];
    for (final s in peek.sections) {
      if (s.isImage && s.len > 0) {
        final allBytes = _readFileBytes(filePath);
        if (s.offset + s.len <= allBytes.length) {
          return _parseAssetJson(utf8.decode(allBytes.sublist(s.offset, s.offset + s.len)));
        }
        break;
      }
    }
    return const <String>[];
  }

  /// Split a record file on disk into `(assets, body)` using the file-level header.
  /// Falls back to the legacy first-line-JSON-array format, then plain body.
  static (List<String> assets, String body) splitNoteContentFromPath(String filePath) {
    final bytes = _readFileBytes(filePath);
    if (bytes.isEmpty) return (const <String>[], '');

    final peek = _peekHeaderFile(filePath);
    if (peek != null) {
      List<String> assets = const <String>[];
      String body = '';
      for (final s in peek.sections) {
        if (s.isImage && s.len > 0 && s.offset + s.len <= bytes.length) {
          assets = _parseAssetJson(utf8.decode(bytes.sublist(s.offset, s.offset + s.len)));
        } else if (s.isContent && s.offset < bytes.length) {
          // Content is always the last section — take everything from offset
          // to EOF, even if the declared len is beyond the file (truncated
          // or tampered file).  Better to return partial body than none.
          body = utf8.decode(bytes.sublist(s.offset), allowMalformed: true);
        }
      }
      return (assets, body);
    }

    // Legacy / plain: decode as String and handle first-line JSON-array fallback.
    final content = utf8.decode(bytes, allowMalformed: true);
    final idx = content.indexOf('\n');
    if (idx < 0) return (const <String>[], content);
    final firstLine = content.substring(0, idx);
    if (firstLine.trimLeft().startsWith('[')) {
      try {
        final list = jsonDecode(firstLine) as List;
        return (list.map((e) => e.toString()).toList(), content.substring(idx + 1));
      } catch (_) {
        return (const <String>[], content);
      }
    }
    return (const <String>[], content);
  }

  // ==========================================================================
  // Public API: String-based (in-memory, editor-side)
  // ==========================================================================

  /// Asset-name extraction from an in-memory note content string.
  static List<String> extractAssetNames(String content) {
    final (assets, _) = splitContent(content);
    return assets;
  }

  /// Split an in-memory note content string into (assets, body).
  static (List<String> assets, String body) splitContent(String content) {
    final bytes = utf8.encode(content);
    if (bytes.length >= 2 && bytes[0] == 0x5B && bytes[1] == 0x5B) {
      final peek = _peekHeaderBytes(bytes);
      if (peek != null) {
        List<String> assets = const <String>[];
        String body = '';
        for (final s in peek.sections) {
          if (s.isImage && s.len > 0 && s.offset + s.len <= bytes.length) {
            assets = _parseAssetJson(utf8.decode(bytes.sublist(s.offset, s.offset + s.len)));
          } else if (s.isContent && s.offset < bytes.length) {
            body = utf8.decode(bytes.sublist(s.offset), allowMalformed: true);
          }
        }
        return (assets, body);
      }
    }
    final idx = content.indexOf('\n');
    if (idx < 0) return (const <String>[], content);
    final firstLine = content.substring(0, idx);
    if (firstLine.trimLeft().startsWith('[')) {
      try {
        final list = jsonDecode(firstLine) as List;
        return (list.map((e) => e.toString()).toList(), content.substring(idx + 1));
      } catch (_) {
        return (const <String>[], content);
      }
    }
    return (const <String>[], content);
  }

  // ==========================================================================
  // Public API: write-side
  // ==========================================================================

  /// Build file content. All section lengths are UTF-8 byte counts (cross-language safe).
  /// When [assets] is empty, returns [body] verbatim — no header written.
  static String buildNoteContent(List<String> assets, String body) {
    if (assets.isEmpty) return body;
    final assetJson = jsonEncode(assets);
    final assetBytes = utf8.encode(assetJson);
    final bodyBytes = utf8.encode(body);
    final header = '[[$kImageSection:${assetBytes.length},$kContentSection:${bodyBytes.length}]]';
    final allBytes = <int>[...utf8.encode(header), ...assetBytes, ...bodyBytes];
    return utf8.decode(allBytes);
  }
}

// ============================================================================
// Generic URL helpers — pure string predicates, no dependencies.
// ============================================================================

/// Returns true when [url] points at a remote resource over http(s) / ftp(s).
/// Case-insensitive; trims whitespace before checking.
bool isRemoteUrl(String url) {
  final lower = url.trim().toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('ftp://') ||
      lower.startsWith('ftps://');
}

/// Returns true when [url] is a managed notee asset reference of the form
/// `assets://{filename}`.
bool isNoteeAssetUrl(String url) => url.trim().startsWith('assets://');

/// Build a full managed asset URL: `assets://{filename}`.
String buildAssetUrl(String filename) => 'assets://$filename';

/// Extract the bare filename from a managed asset URL like `assets://foo.png`.
/// Returns null when [url] isn't a notee asset URL.
String? extractAssetFilename(String url) {
  const prefix = 'assets://';
  return url.startsWith(prefix) ? url.substring(prefix.length) : null;
}

// ============================================================================
