import 'package:path/path.dart' as p;

import 'package:notee/filesync/backends/http/http_sync_backend.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/kv_store.dart';

import 'sync_backend.dart';

/// 统一管理 backend 的持久化 + 启动恢复。
///
/// app 是单 root 单例（Repository 单例）：main 中先 [init] 绑定 appRootDir，
/// 之后 save/restore 都落在该 root 的 backend_store.json。只存 `{type, config}`，
/// 不关心具体类型、不关心 User、不关心本地目录。
/// 反序列化时由每个 backend 子类自己负责重建自己的状态。
class BackendManager {
  static const _kBackendType = 'backend_type';
  static const _kBackendConfig = 'backend_config';

  static KvStore? _store;

  /// app 启动时调用一次（main 中，Repository.init 之前）：绑定当前 root，
  /// 并注册所有内置 backend 工厂。测试需要切换 root 时重新调用即可。
  static void init(String appRootDir) {
    _store = KvStore(p.join(appRootDir, 'backend_store.json'));
    SyncBackend.registerFactory('http', HttpSyncBackend.fromMap);
  }

  static KvStore get _requireStore {
    final store = _store;
    if (store == null) {
      throw StateError('BackendManager.init(appRootDir) must be called first');
    }
    return store;
  }

  /// 持久化当前 backend（null = 游客模式，清空落盘配置）。
  /// backend 自身状态变化（autoRelogin 新 token / clearToken）时也可直接传 this 调用。
  static void save(SyncBackend? backend) {
    final store = _requireStore;
    if (backend == null) {
      store.remove(_kBackendType);
      store.remove(_kBackendConfig);
    } else {
      store.setString(_kBackendType, backend.backendType);
      store.setMap(_kBackendConfig, backend.toMap());
    }
    store.save();
    AppLogger.i('BackendManager', 'save type=${backend?.backendType ?? 'guest'}');
  }

  /// 启动时恢复上次 backend。没存过返回 null（游客模式）。
  /// 由 Repository.init 调用。
  static Future<SyncBackend?> restore() async {
    final store = _requireStore;
    final type = store.getString(_kBackendType);
    final config = store.getMap(_kBackendConfig);
    if (type == null || config == null) {
      AppLogger.i('BackendManager', 'restore guest (no saved backend)');
      return null;
    }
    try {
      final backend = SyncBackend.fromMap(type, config);
      AppLogger.i('BackendManager', 'restore type=$type name=${backend.name}');
      return backend;
    } catch (e) {
      AppLogger.e('BackendManager', 'restore failed: $e');
      return null;
    }
  }
}
