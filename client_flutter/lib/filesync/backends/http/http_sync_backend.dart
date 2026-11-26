import 'package:flutter/material.dart';
import 'package:http/http.dart' show BaseRequest;
import 'package:notee/filesync/backends/backend_manager.dart';
import 'package:notee/filesync/backends/sync_backend.dart';
import 'package:notee/filesync/remote_record.dart';

import 'http_api.dart';
// re-export 数据类（UI 层需要这些类型但不应该直接 import http_api.dart）
export 'http_api.dart' show LoginResult, VersionInfo, APIStat, TombstoneStats, TombstonePurgeResult, HttpApi;

// =============================================================================
// HttpSyncBackend —— 持有 HttpApi 实例，HttpApi 直接回调本类的 autoRelogin/clearToken
//
// 完全不依赖 Repository，不关心本地目录。
// login 由 UI 层负责（UI 层调 HttpApi.login → 构造 backend → Repository.setBackend）。
// 内部持久化调 BackendManager.save（autoRelogin/clearToken 时用）。
// =============================================================================

class HttpSyncBackend extends SyncBackend {
  // =========================================================================
  // 登录状态（HTTP 专属：token 非空即已登录）
  //   构造（登录成功）→ true；clearToken（401 / 登出）→ false。
  //   只由认证动作驱动，Repository 切后端/变游客不碰它。
  // =========================================================================
  static final loginStateNotifier = ValueNotifier<bool>(false);

  // =========================================================================
  // 实例字段
  // =========================================================================

  final int id;

  @override
  String name;

  String token;

  String? password;

  String apiUrl;

  bool get isReady => token.isNotEmpty && apiUrl.isNotEmpty;

  /// HttpApi 实例，构造时传入 this 供它回调 autoRelogin/clearToken 等
  late final HttpApi api = HttpApi(this);

  // =========================================================================
  // 构造 / 序列化
  // =========================================================================

  HttpSyncBackend({
    required this.id,
    required this.name,
    required this.token,
    this.password,
    required this.apiUrl,
  }) {
    // 构造即代表登录成功（有有效 token）→ 登录态 true，与仓库是否使用本 backend 无关
    if (token.isNotEmpty) loginStateNotifier.value = true;
  }

  factory HttpSyncBackend.fromMap(Map<String, dynamic> map) {
    return HttpSyncBackend(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? '',
      token: map['token'] as String? ?? '',
      password: map['password'] as String?,
      apiUrl: map['apiUrl'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'token': token,
        if (password != null && password!.isNotEmpty) 'password': password,
        'apiUrl': apiUrl,
      };

  // =========================================================================
  // SyncBackend 抽象接口
  // =========================================================================

  @override
  String get backendType => 'http';

  @override
  Future<ApiResult<FetchEntitesResult>> fetchRecords(int version, int limit, {bool fullSync = false}) =>
      api.fetchRecords(version, limit, fullSync: fullSync);

  @override
  Future<ApiResult<RemoteRecord>> upsertRecord(UpsertRecordItem item, {String? filePath, int? fileEditAt}) =>
      api.upsertRecord(item, filePath: filePath, fileEditAt: fileEditAt);

  @override
  Future<ApiResult<List<RecordResult>>> upsertRecords(List<UpsertRecordItem> items) => api.upsertRecords(items);

  @override
  Future<ApiResult<List<RecordResult>>> deleteRecords(List<({String uuid, int version})> items) => api.deleteRecords(items);

  @override
  Future<ApiResult<DownloadFileMeta>> downloadFile(String uuid, String toFile) => api.downloadFile(uuid, toFile);

  @override
  Future<bool> headAsset(String recordUuid, String filename) => api.headAsset(recordUuid, filename);

  @override
  Future<ApiResult<void>> uploadAsset(String recordUuid, String filename, String filePath) =>
      api.uploadAsset(recordUuid, filename, filePath);

  @override
  String buildAssetUrl(String recordUuid, String filename) =>
      '$apiUrl/asset/$recordUuid/${Uri.encodeComponent(filename)}';

  @override
  Future<void> setAuthToRequest(BaseRequest request) => api.setTokenToRequest(request);

  @override
  Future<ApiResult<Map<String, String>>> downloadConfigs() => api.downloadConfigs();

  @override
  Future<ApiResult<void>> uploadConfigs(Map<String, String?> configs) => api.uploadConfigs(configs);

  // =========================================================================
  // HttpApi 回调 —— token 过期自动重登/清空
  //   状态变化后自助落盘 BackendManager.save（root 已在 main 的 BackendManager.init 绑定），
  //   backend 不需要知道 appRootDir，也不需要 Repository 注入回调。
  // =========================================================================

  Future<bool> autoRelogin() async {
    final pwd = password;
    if (pwd == null || pwd.isEmpty || apiUrl.isEmpty || name.isEmpty) return false;
    try {
      final result = await HttpApi.login(apiUrl, name, pwd);
      if (result.code == 200 && result.data != null) {
        token = result.data!.token;
        // 落盘新 token，避免重启后旧 token 复活 → 反复 401
        BackendManager.save(this);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // token 失效 —— 认证动作，直接维护登录态 notifier，与仓库是否使用无关
  //   构造（登录成功）→ notifier true；clearToken（401 / 登出）→ notifier false
  //   不存在独立的 "登出" 操作：登出 = clearToken + 变游客（setBackend(null)）
  //   [wipePassword] 显式登出传 true：连 password 一起清，防止崩溃在持久化之后、
  //   setBackend(null) 之前时，重启被 autoRelogin 凭保存的 password 静默复活。
  //   401 自动失效保持默认 false，保留 password 供 autoRelogin 重试。
  // =========================================================================

  Future<void> clearToken({bool wipePassword = false}) async {
    token = '';
    if (wipePassword) password = null;
    // 落盘空 token，并通知 UI 登录失效（弹登录框）。不清本地数据，
    // 重新登录后继续同步 —— 与旧 User.clearToken 行为一致。
    BackendManager.save(this);
    loginStateNotifier.value = false;
  }

  // =========================================================================
  // 对外暴露 —— UI 层拿到 current backend 后调这些
  // =========================================================================

  Future<ApiResult<void>> changePassword(String oldHash, String newHash) => api.changePassword(oldHash, newHash);

  Future<ApiResult<String>> shareUpload(String uuid, String title, String filePath, int lifeSeconds) =>
      api.shareUpload(uuid, title, filePath, lifeSeconds);

  Future<ApiResult<List<APIStat>>> fetchAPIStats() => api.fetchAPIStats();

  Future<ApiResult<TombstoneStats>> getTombstoneStats() => api.getTombstoneStats();

  Future<ApiResult<TombstonePurgeResult>> purgeTombstones() => api.purgeTombstones();

  /// GET /upgrade/check —— 升级检查（公开接口，不需要 token）
  static Future<ApiResult<VersionInfo>> checkUpgrade(String platform, {required String apiUrl}) async {
    return HttpApi.checkUpgrade(apiUrl, platform);
  }
}
