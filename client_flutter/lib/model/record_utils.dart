import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:intl/intl.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/app_logger.dart';

class RecordUtils {
  static String generateRecordName() {
    final dt = DateTime.now();
    final time = DateFormat('yyyy-MM-dd HH:mm').format(dt);
    return "${l10n.record} $time";
  }

  static int getDocumentCharCount(Document document) {
    var count = 0;
    void visit(Node node) {
      final text = node.delta?.toPlainText();
      if (text != null) count += text.replaceAll(RegExp(r'\s'), '').length;
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(document.root);
    return count;
  }

  static String getDocumentTitle(Document doc) {
    // Traverse child nodes (Blocks) of the document root
    for (final node in doc.root.children) {
      // Check whether the node contains text content
      // In AppFlowy, text node data is typically stored in delta
      final delta = node.delta;
      if (delta != null && delta.isNotEmpty) {
        // Convert delta to plain text
        final text = delta.toPlainText().trim();

        if (text.isNotEmpty) {
          // Use the first line as the title
          final title = text.split('\n').first.trim();
          if (title.isNotEmpty) {
            return title;
          }
        }
      }
    }
    return "";
  }

  static String? getTitleFromText(String text, String? defaultValue) {
    if (text.isNotEmpty) {
      // Only take the first line; if it contains newlines, truncate to before the first newline
      String title = text.split('\n').first.trim();
      if (title.length > 20) {
        title = title.substring(0, 20);
      }
      if (title.isNotEmpty) {
        return title;
      }
    }
    return defaultValue;
  }

  /// Read a content file (work or base) and extract plain text.
  /// AppFlowy JSON → block plain text joined by newlines; legacy plaintext → raw.
  /// Returns null on failure.
  static String? extractTextFromFile(String path) {
    try {
      final raw = File(path).readAsStringSync();
      // Strip the [[image]]/[[content]] tagged header to get the body.
      final content = _stripTaggedHeader(raw);
      final trimmed = content.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          final doc = Document.fromJson(map);
          final buf = StringBuffer();
          void visit(Node node) {
            final text = node.delta?.toPlainText();
            if (text != null && text.isNotEmpty) buf.writeln(text);
            for (final child in node.children) {
              visit(child);
            }
          }

          visit(doc.root);
          final text = buf.toString().trim();
          if (text.isNotEmpty) return text;
        } catch (_) {
          // fall through to raw
        }
      }
      return '';
    } catch (e) {
      AppLogger.e('RecordUtils', "[RecordUtils] extractTextFromFile path=$path: $e");
      return null;
    }
  }

  /// Extract the content body from a note file content that has a file-level
  /// header [[tag:len,...]]. Returns the original content unchanged if it is not
  /// in tagged format. Lengths are UTF-8 byte counts.
  static String _stripTaggedHeader(String content) {
    final bytes = utf8.encode(content);
    if (bytes.length < 2 || bytes[0] != 0x5B || bytes[1] != 0x5B) {
      return content;
    }
    int closeIdx = -1;
    const int limit = 4096;
    final int n = bytes.length < limit ? bytes.length : limit;
    for (int i = 1; i < n; i++) {
      if (bytes[i - 1] == 0x5D && bytes[i] == 0x5D) {
        closeIdx = i;
        break;
      }
    }
    if (closeIdx <= 1) return content;
    final headerEnd = closeIdx + 1;
    final headerStr = utf8.decode(bytes.sublist(2, closeIdx));
    int cur = headerEnd;
    for (final part in headerStr.split(',')) {
      final colon = part.indexOf(':');
      if (colon <= 0 || colon == part.length - 1) continue;
      final tag = part.substring(0, colon).trim();
      final lenStr = part.substring(colon + 1).trim();
      final len = int.tryParse(lenStr);
      if (tag.isEmpty || len == null || len < 0) continue;
      if (tag == 'content') {
        if (cur + len <= bytes.length) {
          return utf8.decode(bytes.sublist(cur, cur + len), allowMalformed: true);
        }
        return content;
      }
      cur += len;
    }
    return content;
  }
}
