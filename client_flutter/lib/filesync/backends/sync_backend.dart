import 'package:notee/filesync/backends/types.dart';
import 'package:notee/filesync/remote_record.dart';
import 'package:http/http.dart' show BaseRequest;

/// 同步后端抽象接口 —— 所有同步实现（Go 服务端 / WebDAV / GitHub ...）
/// 都要实现这个接口。Repository 和 SyncEngine 只依赖这个接口，不关心底层是什么。
///
/// 游客模式 = backend 为 null，不是一个具体的 backend 实现。
abstract class SyncBackend {
  // 登录态等 UI 可见状态由各 backend 自己在认证动作里维护（如 HttpSyncBackend
  // 的 loginStateNotifier：构造成功 → true，clearToken → false）。
  // Repository 只负责切换同步目标，不驱动也不感知登录态。
  // 持久化同理由 backend 自助完成（BackendManager.save(this)），不注入回调。

  // =========================================================================
  // 后端类型标识（持久化用，每个子类返回固定字符串）
  String get backendType;

  /// 序列化成 Map（持久化 backend 配置）。appRootDir 不需要存，启动时注入。
  Map<String, dynamic> toMap();

  /// 反序列化 —— 每个 backend 子类在自己的文件里注册工厂。
  static final _factories = <String, SyncBackend Function(Map<String, dynamic>)>{};

  static void registerFactory(String type, SyncBackend Function(Map<String, dynamic>) factory) {
    _factories[type] = factory;
  }

  static SyncBackend fromMap(String type, Map<String, dynamic> map) {
    final factory = _factories[type];
    if (factory != null) return factory(map);
    throw UnsupportedError('Unknown backend type: $type');
  }

  // =========================================================================
  // 🎯 后端身份
  // =========================================================================

  /// 后端类型（调试/日志用）
  String get name;

  // =========================================================================
  // 🎯 记录同步
  // =========================================================================

  Future<ApiResult<FetchEntitesResult>> fetchRecords(
    int version,
    int limit, {
    bool fullSync = false,
  });

  Future<ApiResult<RemoteRecord>> upsertRecord(
    UpsertRecordItem item, {
    String? filePath,
    int? fileEditAt,
  });

  Future<ApiResult<List<RecordResult>>> upsertRecords(List<UpsertRecordItem> items);

  Future<ApiResult<List<RecordResult>>> deleteRecords(List<({String uuid, int version})> items);

  // =========================================================================
  // 🎯 内容文件
  // =========================================================================

  Future<ApiResult<DownloadFileMeta>> downloadFile(String uuid, String toFile);

  // =========================================================================
  // 🎯 Assets
  // =========================================================================

  Future<bool> headAsset(String recordUuid, String filename);

  Future<ApiResult<void>> uploadAsset(String recordUuid, String filename, String filePath);

  /// 拼接 asset 图片的下载 URL（供 FileStore.resolveRecordAsset 使用）
  String buildAssetUrl(String recordUuid, String filename);

  /// 给 HTTP 请求注入认证信息（token / PAT / Basic Auth 等）
  Future<void> setAuthToRequest(BaseRequest request);

  // =========================================================================
  // 🎯 用户配置同步
  // =========================================================================

  Future<ApiResult<Map<String, String>>> downloadConfigs();

  Future<ApiResult<void>> uploadConfigs(Map<String, String?> configs);

  // =========================================================================
  // 🎯 错误码常量（统一语义，具体值可以和 HTTP 不一样）
  // =========================================================================

  static const int codeSuccess = 200;
  static const int codeAuthError = 401;
  static const int codeRecordConflict = 531;
  static const int codeDatabase = 532;
  static const int codeRecordNotFound = 533;
  static const int codeParams = 534;
  static const int codeRecordSave = 535;
  static const int codeFileNotFound = 536;
  static const int codeNeedFullSync = 537;
  static const int codeUserPasswordError = 561;
  static const int codeTokenExpired = 562;

  static const int clientErrorNetwork = 600;
  static const int clientErrorTimeout = 601;
  static const int clientErrorNoBaseUrl = 602;
  static const int clientErrorDownloadFailed = 603;
}
