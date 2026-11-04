import 'dart:async';

/// A keyed task queue that:
///   1. Deduplicates — concurrent callers with the same [key] share one
///      execution and await the same result.
///   2. Limits concurrency — at most [concurrency] tasks run in parallel.
///   3. Is closeable — [dispose] releases all pending waiters so nothing
///      hangs during shutdown.
///
/// Generic over the task's return type [T]; `dispose` completes pending
/// waiters with [disposeValue] (defaults to `null`).
class DedupTaskQueue<T> {
  final int concurrency;
  final Map<String, Completer<T>> _pending = {};
  final List<Completer<void>> _semaWaiters = [];
  int _semaAvailable;
  bool _disposed = false;
  final T disposeValue;

  DedupTaskQueue({this.concurrency = 4, required this.disposeValue})
      : _semaAvailable = concurrency;

  Future<void> _acquire() async {
    if (_semaAvailable > 0) {
      _semaAvailable--;
      return;
    }
    final c = Completer<void>();
    _semaWaiters.add(c);
    await c.future;
  }

  void _release() {
    if (_semaWaiters.isNotEmpty) {
      _semaWaiters.removeAt(0).complete();
    } else {
      _semaAvailable++;
    }
  }

  /// Submit [task] under [key].  Returns [disposeValue] immediately after
  /// [dispose]; otherwise returns the task's result (shared with any
  /// concurrent callers that supplied the same [key]).
  Future<T> submit(String key, Future<T> Function() task) async {
    if (_disposed) return disposeValue;

    final existing = _pending[key];
    if (existing != null) return existing.future;

    final completer = Completer<T>();
    _pending[key] = completer;

    await _acquire();
    try {
      if (_disposed) return disposeValue;
      final result = await task();
      if (!completer.isCompleted) completer.complete(result);
      return result;
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
      rethrow;
    } finally {
      _release();
      if (identical(_pending[key], completer)) {
        _pending.remove(key);
      }
    }
  }

  /// Release all queued waiters.  Safe to call multiple times.
  void dispose() {
    _disposed = true;
    for (final c in _semaWaiters) {
      if (!c.isCompleted) c.complete();
    }
    _semaWaiters.clear();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(disposeValue);
    }
    _pending.clear();
  }
}
