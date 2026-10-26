import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:notee/filesync/remote_record.dart';
import 'package:notee/filesync/user.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:http/io_client.dart';

import 'sync_exception.dart';

class HttpApi {
  static int kResultSuccess = 200; //, "Operation succeeded"}
  static int kResultErrorAuth = 401; //, "Unauthorized (generic, session kicked / server restarted)"}
  static int kResultErrorRecordConflict = 531; //, "Record conflict"}
  static int kResultErrorDatabase = 532; //, "Database error"}
  static int kResultErrorRecordNotFound = 533; //, "Record not found"}
  static int kResultErrorParams = 534; //, "Parameter error"}
  static int kResultErrorRecordSave = 535; //, "Record save error"}
  static int kResultErrorFileNotFound = 536; //, "File not found"}
  static int kResultErrorNeedFullSync = 537; //, "Need full sync"} // client version < purgedVersion, must do a full pull
  static int kResultErrorUserPasswordError = 561; //, "User or password error"}
  static int kResultErrorTokenExpired = 562; //, "Token near expiry, auto-relogin possible"}

  // Client-side internal error codes (6xx range, avoid HTTP standard codes and server 531-561)
  static const int kClientErrorNetwork = 600;
  static const int kClientErrorTimeout = 601;
  static const int kClientErrorNoBaseUrl = 602;
  static const int kClientErrorDownloadFailed = 603;

  static String _baseUrl = "";
  static String get baseUrl => _baseUrl;

  /// Inject baseUrl, called by Repository.init / LoginDialog.
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  // =========================================================================
  // 🎯 Global HttpClient — unified timeout, auto-attached to all http_api requests
  // =========================================================================
  // Duration constants
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _sendTimeout = Duration(seconds: 30);

  /// Singleton client, all API requests go through here
  static final Client _client = _createClient();

  static Client _createClient() {
    final ioClient = HttpClient()
      ..connectionTimeout = _connectTimeout
      ..idleTimeout = const Duration(seconds: 10)
      ..maxConnectionsPerHost = 8;
    return IOClient(ioClient);
  }

  // =========================================================================
  // 🎯 Request wrapper — exponential backoff retry
  // =========================================================================

  static Future<ApiResult<T>> _apiWrapper<T>(
    String name,
    Future<ApiResult<T>> Function(Client client, String baseUrl) func,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final baseUrl = HttpApi.baseUrl;
      if (baseUrl.isEmpty) {
        return ApiResult(kClientErrorNoBaseUrl, "Sync server URL not configured", null);
      }

      final client = _LoggingClient(_client, name);

      // Auto-retry on network exceptions (disconnect/timeout), exponential backoff 1s/2s/4s, max 3 retries.
      // Only retry network-layer exceptions, HTTP business error codes (like 531) do not retry
      const maxRetries = 3; // Total attempts = maxRetries + 1 (first + 3 retries)
      const retryDelays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
      // Auto-relogin retry flag after 401, only allowed once (prevent infinite loop)
      bool triedRelogin = false;

      late ApiResult<T> result;
      for (;;) {
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
          try {
            result = await func(client, baseUrl);
            break;
          } on SocketException catch (e) {
            if (attempt >= maxRetries) rethrow;
            AppLogger.w('HttpApi', "ApiService.$name network error, retry ${attempt + 1}: $e");
            await Future.delayed(retryDelays[attempt]);
          } on TimeoutException catch (e) {
            if (attempt >= maxRetries) rethrow;
            AppLogger.w('HttpApi', "ApiService.$name request timeout, retry ${attempt + 1}: $e");
            await Future.delayed(retryDelays[attempt]);
          }
        }

        final elapsed = stopwatch.elapsedMilliseconds;
        final raw = result.rawData ?? '';
        final truncated = raw.length > 102400 ? '${raw.substring(0, 102400)}... [truncated]' : raw;
        final bodyTag = truncated.isNotEmpty ? '\n  body: $truncated' : '';
        if (result.code == 200) {
          AppLogger.i('HttpApi', "ApiService.$name done 200 ${elapsed}ms$bodyTag");
        } else {
          AppLogger.w(
            'HttpApi',
            "ApiService.$name done ${result.code} ${elapsed}ms${result.message != raw ? ' msg: ${result.message}' : ''}$bodyTag",
          );
        }

        // Token specifically expired (code 402): auto-relogin with cached password, once max.
        if (result.code == kResultErrorTokenExpired && !triedRelogin) {
          triedRelogin = true;
          AppLogger.w('HttpApi', "ApiService.$name token expired, attempting auto relogin...");
          final ok = await UserManager.current.autoRelogin();
          if (ok) {
            AppLogger.i('HttpApi', "ApiService.$name relogin succeeded, retrying original request");
            continue; // Re-run for loop
          }
          AppLogger.w('HttpApi', "ApiService.$name relogin failed, switching to manual login flow");
          await UserManager.current.clearToken();
          return ApiResult(kResultErrorAuth, "Auth failed, please login again", null);
        }

        // Generic 401 (kicked / server restarted / bad params): no auto-retry.
        if (result.code == kResultErrorAuth) {
          AppLogger.w('HttpApi', "ApiService.$name received 401, clearing token");
          await UserManager.current.clearToken();
        }

        return result;
      }
    } catch (e) {
      final elapsed = stopwatch.elapsedMilliseconds;
      AppLogger.e('HttpApi', "ApiService.$name error ${elapsed}ms: $e");
      if (e is SocketException) {
        return ApiResult(kClientErrorNetwork, "Network error, check your connection", null);
      } else if (e is TimeoutException) {
        return ApiResult(kClientErrorTimeout, "Request timeout, please retry", null);
      }
      return ApiResult(SyncException.unknown, e.toString(), null);
    }
  }

  // =========================================================================
  // 🎯 All API Endpoints
  // =========================================================================

  static Future<ApiResult<LoginResult>> login(String name, String password) async {
    return _apiWrapper("login $name", (client, baseUrl) async {
      final resp = await client
          .post(
            Uri.parse('$baseUrl/user/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'password': password}),
          )
          .timeout(_receiveTimeout);
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        var res = jsonDecode(rawBody);
        return ApiResult.success(LoginResult(res['userId'], res['token']), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  static Future<ApiResult<void>> changePassword(String oldPassword, String newPassword) async {
    return _apiWrapper("changePassword", (client, baseUrl) async {
      var req = http.Request('POST', Uri.parse('$baseUrl/user/change_password'));
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword});
      setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        return ApiResult.success(null, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  static Future<ApiResult<FetchEntitesResult>> fetchRecords(
    int version, // Start version number, exclusive
    int limit, {
    bool fullSync = false,
  }) async {
    return _apiWrapper("fetchRecords $version", (client, baseUrl) async {
      var url = '$baseUrl/record/list?version=$version&limit=$limit';
      if (fullSync) url += '&full=1';
      var req = http.Request('GET', Uri.parse(url));
      setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        var res = jsonDecode(rawBody) as Map<String, dynamic>;
        final List<RemoteRecord> data =
            (res['records'] as List?)?.map((e) => RemoteRecord.fromJson(e)).toList().cast<RemoteRecord>() ?? [];
        // Server abnormal responses may be missing fields, must have fallback, otherwise assigning to int directly throws TypeError
        final int purgedVersion = (res['purgedVersion'] as int?) ?? 0;
        return ApiResult.success(FetchEntitesResult(data, purgedVersion), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  static Future<ApiResult<DownloadFileMeta>> downloadFile(String uuid, String toFile) async {
    return _apiWrapper("downloadFile $uuid $toFile", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/record/download?uuid=$uuid'));
      await setTokenToRequest(req);
      var response = await client.send(req).timeout(_receiveTimeout);
      if (response.statusCode == 200) {
        // Extract server-side record's fileVersion and md5 from response header,
        // used to verify file integrity and version correctness after download completes
        final headerFileVersion = int.tryParse(response.headers['x-record-fileversion'] ?? '') ?? 0;
        final headerMd5 = response.headers['x-record-md5'] ?? '';
        // Write to temp file first then rename: network interruption/response truncation won't leave corrupted file at the final path
        final file = File(toFile);
        try {
          await Utils.atomicWriteFile(
            file,
            (tmp) async {
              final sink = tmp.openWrite();
              try {
                await response.stream.pipe(sink).timeout(Duration(seconds: 120));
              } finally {
                await sink.close();
            }
            },
            onBackupFailed: (e) {
              AppLogger.e('HttpApi', "[downloadFile] backup/restore failed: $e");
            },
          );
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

  static Future<void> setTokenToRequest(http.BaseRequest req) async {
    req.headers['x-user-id'] = '${UserManager.current.id}';
    req.headers['x-token'] = UserManager.current.token ?? "";
  }

  // =========================================================================
  // 🎯 Asset (per-record image) APIs
  // =========================================================================

  /// Upload a single asset file to the server (PUT /asset/{recordUuid}/{filename}).
  static Future<ApiResult<void>> uploadAsset(String recordUuid, String filename, String filePath) async {
    return _apiWrapper("uploadAsset $recordUuid/$filename", (client, baseUrl) async {
      final url = '$baseUrl/asset/$recordUuid/${Uri.encodeComponent(filename)}';
      final req = http.MultipartRequest('PUT', Uri.parse(url));
      await setTokenToRequest(req);
      req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await client.send(req).timeout(_sendTimeout + Duration(seconds: 30)));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        return ApiResult.success(null, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  /// Upsert a record. Fields that are null in [item] are omitted from the request so
  /// the server leaves them unchanged (partial update). editAt/version are always sent.
  /// Metadata is sent as a JSON string in the multipart "data" field; an optional
  /// content file is sent in the "file" field. [fileEditAt] is only sent when a
  /// file is uploaded.
  static Future<ApiResult<RemoteRecord>> upsertRecord(
    UpsertRecordItem item, {
    String? filePath,
    int? fileEditAt,
  }) async {
    return _apiWrapper("updateRecord ${item.uuid} ${item.path ?? ''}${item.name ?? ''} ${filePath ?? ''}", (
      client,
      baseUrl,
    ) async {
      final data = item.toJson();
      if (fileEditAt != null) data['fileEditAt'] = fileEditAt;
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/record/update'));
      await setTokenToRequest(req);
      req.fields['data'] = jsonEncode(data);
      if (filePath != null && filePath.isNotEmpty) {
        req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: item.uuid));
      }
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await client.send(req).timeout(_sendTimeout + Duration(seconds: 30)));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        RemoteRecord record = RemoteRecord.fromJson(jsonDecode(rawBody));
        return ApiResult.success(record, rawData: rawBody);
      }
      // Conflict (531): server returns current record JSON, client marks conflict accordingly
      if (resp.statusCode == kResultErrorRecordConflict) {
        try {
          RemoteRecord record = RemoteRecord.fromJson(jsonDecode(rawBody));
          return ApiResult(kResultErrorRecordConflict, "Note conflict", record, rawData: rawBody);
        } catch (_) {
          // fallthrough
        }
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  /// Upload a markdown snapshot for sharing; returns the public download URL.
  /// [lifeSeconds] is validated server-side (1 minute .. 30 days).
  static Future<ApiResult<String>> shareUpload(String uuid, String title, String filePath, int lifeSeconds) async {
    return _apiWrapper("shareUpload $uuid life=$lifeSeconds", (client, baseUrl) async {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/note/upload?uuid=$uuid'));
      await setTokenToRequest(req);
      req.fields['life'] = lifeSeconds.toString();
      req.fields['title'] = title;
      req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: uuid));
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await client.send(req).timeout(_sendTimeout + Duration(seconds: 30)));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final map = jsonDecode(rawBody);
        return ApiResult.success('$baseUrl${map['url']}', rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  /// Batch delete records. Returns one result per requested uuid (same order).
  /// Each result carries [code] and [data]; [data] is the current server record
  /// on success (tombstone) or conflict (531).
  static Future<ApiResult<List<RecordResult>>> deleteRecords(List<({String uuid, int version})> items) async {
    return _apiWrapper<List<RecordResult>>("deleteRecords", (client, baseUrl) async {
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
          if (e['data'] != null) {
            record = RemoteRecord.fromJson(e['data'] as Map<String, dynamic>);
          }
          return RecordResult(uuid, code, record);
        }).toList();
        return ApiResult.success(list, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  /// Batch upsert file-less records (metadata only, no file upload).
  /// Each item carries the fields to update (null/0 means "not provided", same semantics as upsertRecord).
  /// Returns one result per requested uuid (same order); [data] is the updated record on success
  /// or the current server record on conflict (531).
  static Future<ApiResult<List<RecordResult>>> upsertRecords(List<UpsertRecordItem> items) async {
    return _apiWrapper<List<RecordResult>>("upsertRecords", (client, baseUrl) async {
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
          if (e['data'] != null) {
            record = RemoteRecord.fromJson(e['data'] as Map<String, dynamic>);
          }
          return RecordResult(uuid, code, record);
        }).toList();
        return ApiResult.success(list, rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  static Future<ApiResult<List<APIStat>>> fetchAPIStats() async {
    return _apiWrapper("fetchAPIStats", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/api_stat/list'));
      setTokenToRequest(req);
      final resp = await Response.fromStream(await client.send(req).timeout(_receiveTimeout));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final List data = jsonDecode(rawBody);
        return ApiResult.success(data.map((e) => APIStat.fromJson(e)).toList(), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }

  /// GET /upgrade/check —— 公开接口, 不需要登录 token
  /// 只传 platform, 服务端永远返回最新版本; 客户端自行对比判断是否有更新
  static Future<ApiResult<VersionInfo>> checkUpgrade(String platform) async {
    return _apiWrapper("checkUpgrade $platform", (client, baseUrl) async {
      final resp = await client
          .get(Uri.parse('$baseUrl/upgrade/check?platform=$platform'))
          .timeout(const Duration(seconds: 10));
      final rawBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final json = jsonDecode(rawBody);
        return ApiResult.success(VersionInfo.fromJson(json), rawData: rawBody);
      }
      return ApiResult(resp.statusCode, rawBody, null, rawData: rawBody);
    });
  }
}

class LoginResult {
  final int userId;
  final String token;

  LoginResult(this.userId, this.token);
}

class FetchEntitesResult {
  final List<RemoteRecord> records;
  final int purgedVersion; // The maximum purged value (inclusive). In other words, it is the lower bound of your safe history data.
  // As long as your data version number yourVersion < purgedVersion, that data has been physically deleted from the server.
  // You need to perform a full data pull; otherwise, data deleted on the server in the range (yourVersion, purgedVersion] will
  // never be known to you.

  FetchEntitesResult(this.records, this.purgedVersion);
}

/// Record metadata carried in download file response, used to verify file integrity and version
class DownloadFileMeta {
  final int fileVersion;
  final String md5;
  DownloadFileMeta(this.fileVersion, this.md5);
}

/// Upgrade check response from /upgrade/check?platform=xxx
class VersionInfo {
  final String platform;
  final String versionName;
  final String changelog;
  final String md5;
  final String downloadUrl;

  VersionInfo({
    required this.platform,
    required this.versionName,
    required this.changelog,
    required this.md5,
    required this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      platform: json['platform'] ?? '',
      versionName: json['versionName'] ?? '',
      changelog: json['changelog'] ?? '',
      md5: json['md5'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }
}

class ApiResult<T> {
  final int code;
  final String message;
  final T? data;
  final String? rawData; // Raw HTTP response body string (from server); null for client-side errors

  ApiResult(this.code, this.message, this.data, {this.rawData});

  bool isSuccess() {
    return code == 200;
  }

  static ApiResult<T> success<T>(T data, {String? rawData}) {
    return ApiResult(200, "OK", data, rawData: rawData);
  }
}

/// Per-uuid result of a batch record operation (delete or upsert).
/// [data] carries the current server record on success or conflict (531).
class RecordResult {
  final String uuid;
  final int code;
  final RemoteRecord? data;

  RecordResult(this.uuid, this.code, this.data);

  bool isSuccess() => code == 200;
}

/// A single file-less upsert item for [HttpApi.upsertRecords].
/// Null / 0 / empty fields mean "not provided" (server leaves them untouched),
/// matching the semantics of [HttpApi.upsertRecord].
class UpsertRecordItem {
  final String uuid;
  final int editAt;
  final int version;
  final String? path;
  final String? name;
  final int? createAt;
  final int? fileEditAt;
  final int? locked;
  final String? reminder;
  final String? tags;

  UpsertRecordItem({
    required this.uuid,
    required this.editAt,
    required this.version,
    this.path,
    this.name,
    this.createAt,
    this.fileEditAt,
    this.locked,
    this.reminder,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'uuid': uuid, 'editAt': editAt, 'version': version};
    if (path != null) map['path'] = path;
    if (name != null) map['name'] = name;
    if (createAt != null) map['createAt'] = createAt;
    if (fileEditAt != null) map['fileEditAt'] = fileEditAt;
    if (locked != null) map['locked'] = locked;
    if (reminder != null) map['reminder'] = reminder;
    if (tags != null) map['tags'] = tags;
    return map;
  }
}

class APIStat {
  final String apiName;
  final int count;
  final int lastCallTime;

  APIStat(this.apiName, this.count, this.lastCallTime);

  factory APIStat.fromJson(Map<String, dynamic> json) {
    return APIStat(json['apiName'], json['count'], json['lastCallTime']);
  }
}

/// Wrapper Client that logs every outgoing request before delegating to the real client.
/// Logs method / url / headers (token masked) / body (skipped for file uploads/downloads).
class _LoggingClient extends BaseClient {
  final Client _inner;
  final String _apiName;

  _LoggingClient(this._inner, this._apiName);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final isMultipart = request is MultipartRequest;

    // Redact sensitive headers
    final safeHeaders = <String, String>{};
    request.headers.forEach((k, v) {
      final key = k.toLowerCase();
      if (key == 'x-token' || key == 'authorization' || key == 'cookie') {
        safeHeaders[k] = '***';
      } else {
        safeHeaders[k] = v;
      }
    });

    var bodyPreview = '';
    if (isMultipart) {
      bodyPreview = '(multipart fields=${request.fields.length} files=${request.files.length})';
    } else if (request is Request) {
      final raw = request.body;
      if (raw.isNotEmpty) {
        bodyPreview = raw.length > 102400 ? '${raw.substring(0, 102400)}... [truncated]' : raw;
      }
    }

    AppLogger.i(
      'HttpApi',
      "[$_apiName] ${request.method} ${request.url}\n  headers: $safeHeaders${bodyPreview.isNotEmpty ? '\n  body: $bodyPreview' : ''}",
    );

    return await _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
