import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:intl/intl.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/record_ext.dart';
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
      final (_, content) = RecordSections.splitContent(raw);
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
}
