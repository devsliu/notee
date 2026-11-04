import 'dart:convert';
import 'dart:io';

/// 同步 key-value JSON 文件存储。
///
/// set 系列方法只改内存缓存，不自动落盘（返回 this 支持链式）。
/// 调用 [save] 才真正写文件。所有操作真·同步，关闭窗口时调用不会丢数据。
class KvStore {
  final String _filePath;
  Map<String, dynamic> _cache = {};
  bool _loaded = false;
  bool _dirty = false;

  KvStore(this._filePath);

  void _load() {
    if (_loaded) return;
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        _cache = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
    } catch (_) {
      _cache = {};
    }
    _loaded = true;
  }

  /// 强制把当前缓存写回磁盘。
  KvStore save() {
    _load();
    if (!_dirty) return this;
    final file = File(_filePath);
    try {
      file.writeAsStringSync(jsonEncode(_cache));
      _dirty = false;
    } catch (_) {}
    return this;
  }

  // ---- getters ----

  double? getDouble(String key) {
    _load();
    final v = _cache[key];
    return v is double ? v : (v is int ? v.toDouble() : null);
  }

  int? getInt(String key) {
    _load();
    final v = _cache[key];
    return v is int ? v : null;
  }

  bool? getBool(String key) {
    _load();
    final v = _cache[key];
    return v is bool ? v : null;
  }

  String? getString(String key) {
    _load();
    final v = _cache[key];
    return v is String ? v : null;
  }

  Map<String, dynamic>? getMap(String key) {
    _load();
    final v = _cache[key];
    return v is Map<String, dynamic> ? v : null;
  }

  List<dynamic>? getList(String key) {
    _load();
    final v = _cache[key];
    return v is List<dynamic> ? v : null;
  }

  bool get isDirty => _dirty;

  // ---- setters (只改缓存, 返回 this 支持链式, 不自动落盘) ----

  KvStore setDouble(String key, double value) {
    _load();
    _cache[key] = value;
    _dirty = true;
    return this;
  }

  KvStore setInt(String key, int value) {
    _load();
    _cache[key] = value;
    _dirty = true;
    return this;
  }

  KvStore setBool(String key, bool value) {
    _load();
    _cache[key] = value;
    _dirty = true;
    return this;
  }

  KvStore setString(String key, String value) {
    _load();
    _cache[key] = value;
    _dirty = true;
    return this;
  }

  KvStore setMap(String key, Map<String, dynamic> value) {
    _load();
    _cache[key] = value;
    _dirty = true;
    return this;
  }

  KvStore setList(String key, List<dynamic> value) {
    _load();
    _cache[key] = value;
    _dirty = true;
    return this;
  }

  KvStore remove(String key) {
    _load();
    _cache.remove(key);
    _dirty = true;
    return this;
  }

  KvStore clear() {
    _cache = {};
    _loaded = true;
    _dirty = true;
    return this;
  }
}
