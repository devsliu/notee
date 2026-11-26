import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:notee/filesync/remote_record.dart';
import 'package:notee/filesync/backends/types.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:http/io_client.dart';

import 'package:notee/filesync/sync_exception.dart';

import 'http_sync_backend.dart';

export 'package:notee/filesync/backends/types.dart';

// =============================================================================
// 错误码常量（纯值，和实例无关）
// =============================================================================

class HttpApi {
  static const int kResultSuccess = 200;
  static const int kResultErrorAuth = 401;
  static const int kResultErrorRecordConflict = 531;
  static const int kResultErrorDatabase = 532;
  static const int kResultErrorRecordNotFound = 533;
  static const int kResultErrorParams = 534;
  static const int kResultErrorRecordSave = 535;
  static const int kResultErrorFileNotFound = 536;
  static const int kResultErrorNeedFullSync = 537;
  static const int kResultErrorUserPasswordError = 561;
  static const int kResultErrorTokenExpired = 562;

  static const int kClientErrorNetwork = 600;
  static const int kClientErrorTimeout = 601;
  static const int kClientErrorNoBaseUrl = 602;
  static const int kClientErrorDownloadFailed = 603;

  // =========================================================================
  // 共享 HttpClient 池
  // =========================================================================

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _sendTimeout = Duration(seconds: 30);

  static final Client _client = () {
    final ioClient = HttpClient()
      ..connectionTimeout = _connectTimeout
      ..idleTimeout = const Duration(seconds: 10)
      ..maxConnectionsPerHost = 8;
    return IOClient(ioClient);
  }();

  // =========================================================================
  // 实例 —— 持有一个 backend，所有操作都走它的 apiUrl/token
  // =========================================================================

  /// HttpApi 只在 HttpSyncBackend 内部创建，直接依赖具体类型（不走共享接口）。
  /// [_backend] 提供 baseUrl / token / autoRelogin / clearToken。
  final HttpSyncBackend _backend;

  HttpApi(this._backend);

  // =========================================================================
  // 请求封装 —— 指数退避 + token 过期自动重登
  // =========================================================================

  /// 已认证请求：走 [_backend] 的 autoRelogin / clearToken 处理认证失效。
  Future<ApiResult<T>> _apiWrapper<T>(
    String name,
    Future<ApiResult<T>> Function(Client client, String baseUrl) func,
  ) async {
    return _runWithRetries(
      name,
      _backend.apiUrl,
      func,
      onTokenExpired: _backend.autoRelogin,
      onAuthFailed: _backend.clearToken,
    );
  }

  /// 无认证请求（login / checkUpgrade）：只重试网络错误，不触发 relogin/clearToken。
  static Future<ApiResult<T>> _noAuthWrapper<T>(
    String name,
    String baseUrl,
    Future<ApiResult<T>> Function(Client client, String baseUrl) func,
  ) async {
    return _runWithRetries(name, baseUrl, func);
  }

  /// 核心：指数退避重试 + 日志。认证回调可选，未传则遇到 401/562 直接返回结果。
  static Future<ApiResult<T>> _runWithRetries<T>(
    String name,
    String baseUrl,
    Future<ApiResult<T>> Function(Client client, String baseUrl) func, {
    Future<bool> Function()? onTokenExpired,
    Future<void> Function()? onAuthFailed,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (baseUrl.isEmpty) {
        return ApiResult(kClientErrorNoBaseUrl, "Sync server URL not configured", null);
      }

      final client = _LoggingClient(_client, name);
      const maxRetries = 3;
      const retryDelays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
      bool triedRelogin = false;

      late ApiResult<T> result;
      for (;;) {
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
          try {
            result = await func(client, baseUrl);
            break;
          } on SocketException catch (e) {
            if (attempt >= maxRetries) rethrow;
            AppLogger.w('HttpApi', "$name network error, retry ${attempt + 1}: $e");
            await Future.delayed(retryDelays[attempt]);
          } on TimeoutException catch (e) {
            if (attempt >= maxRetries) rethrow;
            AppLogger.w('HttpApi', "$name request timeout, retry ${attempt + 1}: $e");
            await Future.delayed(retryDelays[attempt]);
          }
        }

        final elapsed = stopwatch.elapsedMilliseconds;
        final raw = result.rawData ?? '';
        final truncated = raw.length > 102400 ? '${raw.substring(0, 102400)}... [truncated]' : raw;
        final bodyTag = truncated.isNotEmpty ? '\n  body: $truncated' : '';
        if (result.code == 200) {
          AppLogger.i('HttpApi', "$name done 200 ${elapsed}ms$bodyTag");
        } else {
          AppLogger.w('HttpApi', "$name done ${result.code} ${elapsed}ms${result.message != raw ? ' msg: ${result.message}' : ''}$bodyTag");
        }

        if (result.code == kResultErrorTokenExpired && !triedRelogin && onTokenExpired != null) {
          triedRelogin = true;
          AppLogger.w('HttpApi', "$name token expired, attempting auto relogin...");
          final ok = await onTokenExpired();
          if (ok) {
            AppLogger.i('HttpApi', "$name relogin succeeded, retrying");
            continue;
          }
          AppLogger.w('HttpApi', "$name relogin failed, clearing token");
          await onAuthFailed?.call();
          return ApiResult(kResultErrorAuth, "Auth failed, please login again", null);
        }

        if (result.code == kResultErrorAuth && onAuthFailed != null) {
          AppLogger.w('HttpApi', "$name received 401, clearing token");
          await onAuthFailed();
        }

        return result;
      }
    } catch (e) {
      final elapsed = stopwatch.elapsedMilliseconds;
      AppLogger.e('HttpApi', "$name error ${elapsed}ms: $e");
      if (e is SocketException) return ApiResult(kClientErrorNetwork, "Network error, check your connection", null);
      if (e is TimeoutException) return ApiResult(kClientErrorTimeout, "Request timeout, please retry", null);
      return ApiResult(SyncException.unknown, e.toString(), null);
    }
  }

  // =========================================================================
  // token 注入 —— 用构造时的 backend
  // =========================================================================

  Future<void> setTokenToRequest(http.BaseRequest req) async {
    req.headers['x-user-id'] = '${_backend.id}';
    req.headers['x-token'] = _backend.token;
  }

  // =========================================================================
  // 所有 API endpoints（login / checkUpgrade 为静态无认证，其余为实例方法）
  // =========================================================================

  /// 登录 —— 公开接口，不需要 token。无认证调用，不触发 relogin/clearToken。
  static Future<ApiResult<LoginResult>> login(String apiUrl, String name, String password) async {
    return _noAuthWrapper("login $name", apiUrl, (client, baseUrl) async {
      final resp = await client.post(
        Uri.parse('$baseUrl/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'password': password}),
      ).timeout(_receiveTimeout);
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        var res = jsonDecode(rawBody);
        return ApiResult.success(LoginResult(res['userId'], res['token']), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<void>> changePassword(String oldPassword, String newPassword) async {
    return _apiWrapper("changePassword", (client, baseUrl) async {
      var req = http.Request('POST', Uri.parse('$baseUrl/user/change_password'));
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword});
      await setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        return ApiResult.success(null, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<FetchEntitesResult>> fetchRecords(int version, int limit, {bool fullSync = false}) async {
    return _apiWrapper("fetchRecords $version", (client, baseUrl) async {
      var url = '$baseUrl/record/list?version=$version&limit=$limit';
      if (fullSync) url += '&full=1';
      var req = http.Request('GET', Uri.parse(url));
      await setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        var res = jsonDecode(rawBody) as Map<String, dynamic>;
        final List<RemoteRecord> data = (res['records'] as List?)?.map((e) => RemoteRecord.fromJson(e)).toList().cast<RemoteRecord>() ?? [];
        final int purgedVersion = (res['purgedVersion'] as int?) ?? 0;
        return ApiResult.success(FetchEntitesResult(data, purgedVersion), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<RemoteRecord>> upsertRecord(UpsertRecordItem item, {String? filePath, int? fileEditAt}) async {
    return _apiWrapper("upsertRecord ${item.uuid}", (client, baseUrl) async {
      final data = item.toJson();
      if (fileEditAt != null) data['fileEditAt'] = fileEditAt;
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/record/update'));
      await setTokenToRequest(req);
      req.fields['data'] = jsonEncode(data);
      if (filePath != null && filePath.isNotEmpty) {
        req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: item.uuid));
      }
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await client.send(req).timeout(_sendTimeout + const Duration(seconds: 30)));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        RemoteRecord record = RemoteRecord.fromJson(jsonDecode(rawBody));
        return ApiResult.success(record, rawData: rawBody);
      }
      if (resp.statusCode == kResultErrorRecordConflict) {
        try {
          RemoteRecord record = RemoteRecord.fromJson(jsonDecode(rawBody));
          return ApiResult(kResultErrorRecordConflict, "Note conflict", record, rawData: rawBody);
        } catch (_) {}
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<List<RecordResult>>> upsertRecords(List<UpsertRecordItem> items) async {
    return _apiWrapper("upsertRecords", (client, baseUrl) async {
      final body = jsonEncode(items.map((e) => e.toJson()).toList());
      var req = http.Request('POST', Uri.parse('$baseUrl/record/updates'));
      await setTokenToRequest(req);
      req.headers['Content-Type'] = 'application/json';
      req.body = body;
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final List data = jsonDecode(rawBody);
        final list = data.map((e) {
          final uuid = e['uuid'] as String;
          final code = e['code'] as int;
          RemoteRecord? record;
          if (e['data'] != null) record = RemoteRecord.fromJson(e['data'] as Map<String, dynamic>);
          return RecordResult(uuid, code, record);
        }).toList();
        return ApiResult.success(list, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<List<RecordResult>>> deleteRecords(List<({String uuid, int version})> items) async {
    return _apiWrapper("deleteRecords", (client, baseUrl) async {
      final body = jsonEncode(items.map((e) => {'uuid': e.uuid, 'version': e.version}).toList());
      var req = http.Request('POST', Uri.parse('$baseUrl/record/deletes'));
      await setTokenToRequest(req);
      req.headers['Content-Type'] = 'application/json';
      req.body = body;
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final List data = jsonDecode(rawBody);
        final list = data.map((e) {
          final uuid = e['uuid'] as String;
          final code = e['code'] as int;
          RemoteRecord? record;
          if (e['data'] != null) record = RemoteRecord.fromJson(e['data'] as Map<String, dynamic>);
          return RecordResult(uuid, code, record);
        }).toList();
        return ApiResult.success(list, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<DownloadFileMeta>> downloadFile(String uuid, String toFile) async {
    return _apiWrapper("downloadFile", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/record/download?uuid=$uuid'));
      await setTokenToRequest(req);
      var response = await client.send(req).timeout(_receiveTimeout);
      if (response.statusCode == 200) {
        final headerFileVersion = int.tryParse(response.headers['x-record-fileversion'] ?? '') ?? 0;
        final headerMd5 = response.headers['x-record-md5'] ?? '';
        final file = File(toFile);
        try {
          await Utils.atomicWriteFile(file, (tmp) async {
            final sink = tmp.openWrite();
            try {
              await response.stream.pipe(sink).timeout(const Duration(seconds: 120));
            } finally {
              await sink.close();
            }
          }, onBackupFailed: (e) {
            AppLogger.e('HttpApi', "[downloadFile] backup/restore failed: $e");
          });
        } catch (e) {
          AppLogger.e('HttpApi', "[downloadFile] write failed: $e");
          rethrow;
        }
        return ApiResult.success(DownloadFileMeta(headerFileVersion, headerMd5));
      } else {
        final resp = await Response.fromStream(response);
        final rawBody = utf8.decode(resp.bodyBytes);
        return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
      }
    });
  }

  Future<bool> headAsset(String recordUuid, String filename) async {
    final result = await _apiWrapper<void>("headAsset $recordUuid/$filename", (client, baseUrl) async {
      final url = '$baseUrl/asset/$recordUuid/${Uri.encodeComponent(filename)}';
      final req = http.Request('HEAD', Uri.parse(url));
      await setTokenToRequest(req);
      final resp = await client.send(req).timeout(_sendTimeout);
      await resp.stream.drain();
      if (resp.statusCode == 200) return ApiResult.success(null);
      return ApiResult(resp.statusCode, '', null);
    });
    return result.isSuccess();
  }

  Future<ApiResult<void>> uploadAsset(String recordUuid, String filename, String filePath) async {
    return _apiWrapper("uploadAsset $recordUuid/$filename", (client, baseUrl) async {
      final url = '$baseUrl/asset/$recordUuid/${Uri.encodeComponent(filename)}';
      final req = http.MultipartRequest('PUT', Uri.parse(url));
      await setTokenToRequest(req);
      req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await client.send(req).timeout(_sendTimeout + const Duration(seconds: 30)));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) return ApiResult.success(null, rawData: rawBody);
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<String>> shareUpload(String uuid, String title, String filePath, int lifeSeconds) async {
    return _apiWrapper("shareUpload $uuid", (client, baseUrl) async {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/note/upload?uuid=$uuid'));
      await setTokenToRequest(req);
      req.fields['life'] = lifeSeconds.toString();
      req.fields['title'] = title;
      req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: uuid));
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await client.send(req).timeout(_sendTimeout + const Duration(seconds: 30)));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final map = jsonDecode(rawBody);
        return ApiResult.success('$baseUrl${map['url']}', rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<List<APIStat>>> fetchAPIStats() async {
    return _apiWrapper("fetchAPIStats", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/api_stat/list'));
      await setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final List data = jsonDecode(rawBody);
        return ApiResult.success(data.map((e) => APIStat.fromJson(e)).toList(), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<TombstoneStats>> getTombstoneStats() async {
    return _apiWrapper("tombstoneStats", (client, baseUrl) async {
      final req = http.Request('GET', Uri.parse('$baseUrl/record/tombstone_stats'));
      await setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) return ApiResult.success(TombstoneStats.fromJson(jsonDecode(rawBody)), rawData: rawBody);
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<TombstonePurgeResult>> purgeTombstones() async {
    return _apiWrapper("purgeTombstones", (client, baseUrl) async {
      final req = http.Request('POST', Uri.parse('$baseUrl/record/tombstone_purge'));
      await setTokenToRequest(req);
      req.headers['Content-Type'] = 'application/json';
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) return ApiResult.success(TombstonePurgeResult.fromJson(jsonDecode(rawBody)), rawData: rawBody);
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<Map<String, String>>> downloadConfigs() async {
    return _apiWrapper("downloadConfigs", (client, baseUrl) async {
      final req = http.Request('GET', Uri.parse('$baseUrl/config/download'));
      await setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
        final map = decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        return ApiResult.success(map, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  Future<ApiResult<void>> uploadConfigs(Map<String, String?> configs) async {
    return _apiWrapper("uploadConfigs", (client, baseUrl) async {
      final req = http.Request('POST', Uri.parse('$baseUrl/config/upload'));
      await setTokenToRequest(req);
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(configs);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) return ApiResult.success(null, rawData: rawBody);
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  /// 公开接口，不需要 token —— 升级检查
  static Future<ApiResult<VersionInfo>> checkUpgrade(String apiUrl, String platform) async {
    return _noAuthWrapper("checkUpgrade", apiUrl, (client, baseUrl) async {
      final resp = await client.get(Uri.parse('$baseUrl/upgrade/check?platform=$platform')).timeout(const Duration(seconds: 10));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) return ApiResult.success(VersionInfo.fromJson(jsonDecode(rawBody)), rawData: rawBody);
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }
}

// =============================================================================
// 辅助数据类 + _LoggingClient
// =============================================================================

class LoginResult {
  final int userId;
  final String token;
  LoginResult(this.userId, this.token);
}

class VersionInfo {
  final String platform;
  final String versionName;
  final String changelog;
  final String md5;
  final String downloadUrl;
  VersionInfo({required this.platform, required this.versionName, required this.changelog, required this.md5, required this.downloadUrl});
  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
        platform: json['platform'] ?? '',
        versionName: json['versionName'] ?? '',
        changelog: json['changelog'] ?? '',
        md5: json['md5'] ?? '',
        downloadUrl: json['downloadUrl'] ?? '',
      );
}

class APIStat {
  final String apiName;
  final int count;
  final int lastCallTime;
  const APIStat(this.apiName, this.count, this.lastCallTime);
  factory APIStat.fromJson(Map<String, dynamic> json) => APIStat(json['apiName'], json['count'], json['lastCallTime']);
}

class TombstoneStats {
  final int tombstoneCount;
  final int tombstoneAssetCount;
  final int maxVersion;
  final int purgedVersion;
  final int activeRecords;
  TombstoneStats({required this.tombstoneCount, required this.tombstoneAssetCount, required this.maxVersion, required this.purgedVersion, required this.activeRecords});
  factory TombstoneStats.fromJson(Map<String, dynamic> json) => TombstoneStats(
        tombstoneCount: json['tombstoneCount'] as int? ?? 0,
        tombstoneAssetCount: json['tombstoneAssetCount'] as int? ?? 0,
        maxVersion: json['maxVersion'] as int? ?? 0,
        purgedVersion: json['purgedVersion'] as int? ?? 0,
        activeRecords: json['activeRecords'] as int? ?? 0,
      );
}

class TombstonePurgeResult {
  final int purgedCount;
  final int purgedVersion;
  TombstonePurgeResult({required this.purgedCount, required this.purgedVersion});
  factory TombstonePurgeResult.fromJson(Map<String, dynamic> json) => TombstonePurgeResult(
        purgedCount: json['purgedCount'] as int? ?? 0,
        purgedVersion: json['purgedVersion'] as int? ?? 0,
      );
}

class _LoggingClient extends BaseClient {
  final Client _inner;
  final String _apiName;
  _LoggingClient(this._inner, this._apiName);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final safeHeaders = <String, String>{};
    request.headers.forEach((k, v) {
      final key = k.toLowerCase();
      safeHeaders[key] = (key == 'x-token' || key == 'authorization' || key == 'cookie') ? '***' : v;
    });
    var bodyPreview = '';
    if (request is MultipartRequest) {
      bodyPreview = '(multipart fields=${request.fields.length} files=${request.files.length})';
    } else if (request is Request) {
      final raw = request.body;
      if (raw.isNotEmpty) bodyPreview = raw.length > 102400 ? '${raw.substring(0, 102400)}... [truncated]' : raw;
    }
    AppLogger.i('HttpApi', "[$_apiName] ${request.method} ${request.url}\n  headers: $safeHeaders${bodyPreview.isNotEmpty ? '\n  body: $bodyPreview' : ''}");
    return await _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
