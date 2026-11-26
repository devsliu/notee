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

  /// 当前正在执行的任务体。dispose 时会等它们全部收尾，避免旧任务在调用方
  /// 已切换/关闭之后还继续产生副作用。
  final Set<Future<void>> _inflight = <Future<void>>{};

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
    // 命中这里说明本任务是被 dispose() 从 _semaWaiters 叫醒的：它从未递减
    // 信号量（拿许可时已满，只是排队），所以没有 permit 需要 _release()；
    // 此时调用 _release() 反而会让 _semaAvailable 凭空 +1。直接返回即可。
    if (_disposed) return disposeValue;

    final taskFuture = task();
    _inflight.add(taskFuture);
    try {
      final result = await taskFuture;
      if (!completer.isCompleted) completer.complete(result);
      return result;
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
      rethrow;
    } finally {
      _inflight.remove(taskFuture);
      _release();
      if (identical(_pending[key], completer)) {
        _pending.remove(key);
      }
    }
  }

  /// 释放所有排队等待者（以 [disposeValue] 完成），并等待在飞任务全部收尾后返回。
  /// 首次调用的 awaiter 可据此保证：返回后不会再有任何任务体继续执行、产生副作用。
  /// 可重复调用；重复调用立即返回（不重复等待，排空以首次调用为准）。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final c in _semaWaiters) {
      if (!c.isCompleted) c.complete();
    }
    _semaWaiters.clear();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(disposeValue);
    }
    _pending.clear();
    final running = _inflight.toList();
    if (running.isNotEmpty) {
      // 不向上抛任务异常：任务自身的 submit 调用方已通过 completer 收到结果/错误，
      // dispose 的契约只是"排空后返回"，这里抛错会中断调用方的关闭/后端切换流程。
      await Future.wait(running.map((f) => f.catchError((Object _) {})));
    }
  }
}
