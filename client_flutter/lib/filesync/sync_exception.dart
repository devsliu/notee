/// SyncException: sync engine internal error
///
/// code values:
///   - HTTP standard codes (2xx/4xx/5xx) — directly forwarded from ApiResult.code
///   - Server business codes (531-561)    — directly forwarded
///   - -1                        — unknown (non-HTTP exceptions, e.g. format parsing errors)
class SyncException implements Exception {
  static const int unknown = -1;

  final int code;
  final String message;
  final StackTrace? stackTrace;

  SyncException(this.message, [this.stackTrace, this.code = unknown]);

  @override
  String toString() => 'SyncException(code=$code, message=$message)';
}
