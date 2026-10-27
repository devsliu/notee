import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:path/path.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';

typedef ReturnCallback<T> = T Function();
typedef ValueCallback<T> = void Function(T value);
typedef ValueCallback2<T, T1> = void Function(T value, T1 t1);

/// Conflict resolution when a destination file already exists during [Utils.moveFolder].
enum MoveConflictPolicy {
  /// Delete the destination, then move the source in place.
  overwrite,

  /// Keep the destination and delete the source.
  skip,
}

class Utils {
  /// Atomically write to [target] by first writing to a `.creating` temp file in
  /// the same directory, then swapping it into place via rename. On Windows
  /// rename does not overwrite, so the existing target is first moved to `.bak`
  /// and restored on failure — this guarantees the caller never observes a
  /// missing/corrupt file even if the process is interrupted mid-write.
  ///
  /// [writeToTemp] receives the temp file and is responsible for producing its
  /// content (writeAsBytes, writeAsString, stream.pipe, etc.). The temp file is
  /// created before [writeToTemp] is invoked; cleanup is handled here.
  static Future<void> atomicWriteFile(
    File target,
    Future<void> Function(File tmp) writeToTemp, {
    void Function(Object error)? onBackupFailed,
  }) async {
    final tmp = File('${target.path}.creating');
    final bak = File('${target.path}.bak');
    await tmp.create(recursive: true);
    try {
      await writeToTemp(tmp);
    } catch (_) {
      await tmp.delete().catchError((_) {});
      rethrow;
    }

    if (await target.exists()) {
      try {
        await target.rename(bak.path);
      } catch (e) {
        // Old file cannot be moved (locked/permission). Best-effort direct delete.
        try {
          await target.delete();
        } catch (_) {
          if (onBackupFailed != null) onBackupFailed(e);
        }
      }
    }

    try {
      await tmp.rename(target.path);
    } catch (e) {
      // Rename failed — restore .bak so the user still has the previous version.
      if (!await target.exists() && await bak.exists()) {
        try {
          await bak.rename(target.path);
        } catch (restoreErr) {
          if (onBackupFailed != null) onBackupFailed(restoreErr);
        }
      }
      await tmp.delete().catchError((_) {});
      rethrow;
    }

    if (await bak.exists()) {
      await bak.delete().catchError((_) {});
    }
  }

  /// Move [src] to [dst]. On Windows rename does not overwrite, so the target
  /// is deleted first; cross-filesystem rename failures fall back to copy+delete.
  static void moveFile(File src, File dst) {
    try {
      if (dst.existsSync()) {
        dst.deleteSync();
      }
      src.renameSync(dst.absolute.path);
    } on FileSystemException {
      src.copySync(dst.absolute.path);
      src.deleteSync();
    }
  }

  /// Recursively move every entry from [src] into [dst].
  ///
  /// - Destination directories are always created and merged — [policy] does not
  ///   apply to directories.
  /// - File collisions are resolved according to [policy].
  static Future<void> moveFolder(Directory src, Directory dst, MoveConflictPolicy policy) async {
    if (!await src.exists()) return;
    await dst.create(recursive: true);
    await for (final entity in src.list()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (entity is File) {
        final target = File(join(dst.path, name));
        if (await target.exists()) {
          if (policy == MoveConflictPolicy.overwrite) {
            moveFile(entity, target);
          } else {
            await entity.delete();
          }
        } else {
          moveFile(entity, target);
        }
      } else if (entity is Directory) {
        await moveFolder(entity, Directory(join(dst.path, name)), policy);
      }
    }
  }

  /// Open a URL using the system default handler (e.g., browser)
  static Future<void> openUrlWithSystem(String url) async {
    if (Platform.isWindows) {
      await Process.run('start', [url], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // ---------------------------------------------------------------
  // Encryption/decryption (password-based, PBKDF2 + AES)
  // ---------------------------------------------------------------

  /// Encrypt based on password. Output format: salt:iv:encryptedContent (Base64)
  static String? encryptContent(String content, String password) {
    try {
      final salt = encrypt.IV.fromSecureRandom(16);
      final key = encrypt.Key.fromBase64(_generateKeyFromPassword(password, salt.base64));
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(content, iv: iv);
      return '${salt.base64}:${iv.base64}:${encrypted.base64}';
    } catch (e) {
      return null;
    }
  }

  /// Decrypt based on password. Input format: salt:iv:encryptedContent (Base64)
  static String? decryptContent(String encryptedContent, String password) {
    try {
      final parts = encryptedContent.split(':');
      if (parts.length != 3) return null;
      final salt = parts[0];
      final iv = encrypt.IV.fromBase64(parts[1]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[2]);
      final key = encrypt.Key.fromBase64(_generateKeyFromPassword(password, salt));
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return null;
    }
  }

  static String _generateKeyFromPassword(String password, String saltBase64) {
    final salt = base64.decode(saltBase64);
    final derivator = PBKDF2KeyDerivator(Mac("SHA-256/HMAC"))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), 1000, 32));
    final keyBytes = derivator.process(Uint8List.fromList(utf8.encode(password)));
    return base64.encode(keyBytes);
  }

  // ---------------------------------------------------------------
  // MD5 hashing
  // ---------------------------------------------------------------

  static String generateMd5(String s) {
    return md5.convert(utf8.encode(s)).toString().toUpperCase();
  }

  static Future<String> generateFileMd5({String? filePath, File? file}) async {
    var f = file ?? File(filePath!);
    if (!await f.exists()) return '';
    // Stream-based chunked computation to avoid loading entire large files into memory
    final digest = await md5.bind(f.openRead()).first;
    return digest.toString().toUpperCase();
  }

  /// Top-level wrapper for [compute]: compute a file's MD5 in a background
  /// isolate so the streaming hash does not occupy the main isolate's event
  /// loop during bulk downloads.
  static Future<String> _fileMd5InIsolate(String path) async {
    final f = File(path);
    if (!await f.exists()) return '';
    final digest = await md5.bind(f.openRead()).first;
    return digest.toString().toUpperCase();
  }

  /// Compute file MD5 in a background isolate. Prefer this over
  /// [generateFileMd5] on the hot path (e.g. post-download integrity check).
  static Future<String> computeFileMd5(String filePath) {
    return compute(_fileMd5InIsolate, filePath);
  }

  // ---------------------------------------------------------------
  // Platform detection
  // ---------------------------------------------------------------

  static bool isDesktop() {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  // ---------------------------------------------------------------
  // Time formatting
  // ---------------------------------------------------------------

  static String formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  static String formatShortTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    String _pad(int v) => v.toString().padLeft(2, '0');
    final h = _pad(dt.hour);
    final m = _pad(dt.minute);
    final mo = _pad(dt.month);
    final d = _pad(dt.day);
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$h:$m';
    }
    if (dt.year == now.year) {
      return '$mo-$d $h:$m';
    }
    return '${dt.year}-$mo-$d $h:$m';
  }

  /// Format a reminder task's time according to its repeat mode.
  static String reminderTimeStr(ReminderTask task) {
    if (task.time <= 0) return l10n.notSet;
    final hour = task.hour;
    final minute = task.minute;
    String pad(int v) => v.toString().padLeft(2, '0');
    final hm = '${pad(hour)}:${pad(minute)}';
    switch (task.repeat) {
      case ReminderTask.repeatWeekly:
        final days = task.weekdaySet.toList()..sort();
        if (days.isEmpty) return hm;
        final names = l10n.weekdays.split('|');
        return '${days.map((d) => names[d - 1]).join('、')} $hm';
      case ReminderTask.repeatMonthly:
        final lunar = task.isLunar ? l10n.lunar : '';
        return '$lunar${l10n.repeatMonthlyTime(task.monthlyDay, hm)}';
      case ReminderTask.repeatYearly:
        final md = task.yearlyMonthDay;
        final lunar = task.isLunar ? l10n.lunar : '';
        return '$lunar${l10n.repeatYearlyTime(md.$1, md.$2, hm)}';
      default:
        // once: show full date + time (no seconds)
        final d = task.onceDate;
        final dt = DateTime(d.$1, d.$2, d.$3, hour, minute);
        return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }
  }

  static String formatTimeNow() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  }
}
