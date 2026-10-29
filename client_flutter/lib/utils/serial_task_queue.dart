import 'dart:async';

/// 队列满时的处理策略。
enum QueueOverflowStrategy {
  /// 丢弃新来的调用 —— 返回当前正在执行的 Future 让调用者等待它结束。
  /// 适合"任何一次执行结果都等价"的场景（如 sync、保存）。
  rejectNew,

  /// 丢弃最早排队的那个，新的顶上去。适合"只关心最新状态"的场景
  /// （如 UI 刷新、状态同步）—— 旧状态跑了也没用。
  dropOldest,

  /// 丢弃新来的调用 —— 返回一个立即完成的 Future（不 coalesce）。
  /// 适合"丢了也无所谓"的场景，比 [rejectNew] 更快返回。
  dropNewest,
}

/// 单 key 串行任务队列 — 所有 submit 严格 FIFO 串行。
///
/// 内部用真正的 List 做队列，submit 就是入队，执行完自动取下一个。
/// 比 Future 链式实现直观：任务在队列里看得见、数得清。
///
/// [maxPending] 队列最大等待长度（不含正在执行的那一个）。
/// 0 = 无限排队；>0 超出时按 [overflowStrategy] 处理。
/// 默认 [QueueOverflowStrategy.rejectNew]（coalesce 语义）。
class SingleSerialTaskQueue {
  final int maxPending; // 0 = unlimited
  final QueueOverflowStrategy overflowStrategy;

  final List<_PendingTask> _queue = [];
  bool _running = false;
  Future<void>? _currentFuture;

  SingleSerialTaskQueue({
    this.maxPending = 0,
    this.overflowStrategy = QueueOverflowStrategy.rejectNew,
  });

  /// 当前队尾；空闲时返回 null。
  Future<void>? get tail => _currentFuture;

  /// 等待当前在飞任务完成（空闲则立即返回）。
  Future<void> wait() async {
    final current = _currentFuture;
    if (current != null) await current;
  }

  /// 提交一个任务，排到队尾执行。返回这次任务的 Future。
  ///
  /// 当 [maxPending] 已达上限时按 [overflowStrategy] 处理。
  Future<void> submit(Future<void> Function() task) {
    final full = maxPending > 0 && _queue.length >= maxPending && _currentFuture != null;

    if (full) {
      switch (overflowStrategy) {
        case QueueOverflowStrategy.rejectNew:
          // 新来的不再入队，等正在执行的那个就行
          return _currentFuture!;
        case QueueOverflowStrategy.dropOldest:
          // 丢弃最早排队的，新的顶上去
          final dropped = _queue.removeAt(0);
          dropped.completer.complete(); // 让等待的调用者立即返回，不阻塞
          break; // 然后 fall through 到下面入队新的
        case QueueOverflowStrategy.dropNewest:
          // 新来的直接丢弃
          return Future.value();
      }
    }

    final completer = Completer<void>();
    _queue.add(_PendingTask(task, completer));
    _startNext();
    return completer.future;
  }

  void _startNext() {
    if (_running || _queue.isEmpty) return;
    _running = true;
    final item = _queue.removeAt(0);
    _currentFuture = item.completer.future;
    item.task().then((_) {
      item.completer.complete();
    }).catchError((e, st) {
      item.completer.completeError(e, st);
    }).whenComplete(() {
      _running = false;
      if (_queue.isEmpty) {
        _currentFuture = null;
      } else {
        _startNext();
      }
    });
  }
}

class _PendingTask {
  final Future<void> Function() task;
  final Completer<void> completer;
  _PendingTask(this.task, this.completer);
}

// ============================================================================

/// 通用多 key 串行任务队列。
///
/// 同一 [key] 的 submit 严格串行（后一个等前一个跑完再开始），不同 [key]
/// 之间并行互不干扰。每个 key 内部是一个独立的 [SingleSerialTaskQueue]。
class MultiSerialTaskQueue {
  final int maxPending; // 0 = unlimited
  final QueueOverflowStrategy overflowStrategy;
  final Map<String, SingleSerialTaskQueue> _queues = {};

  MultiSerialTaskQueue({
    this.maxPending = 0,
    this.overflowStrategy = QueueOverflowStrategy.rejectNew,
  });

  SingleSerialTaskQueue _getOrCreate(String key) {
    return _queues.putIfAbsent(key, () => SingleSerialTaskQueue(
      maxPending: maxPending,
      overflowStrategy: overflowStrategy,
    ));
  }

  /// 提交一次任务到 [key] 专属队列。返回这次任务的 Future。
  Future<void> submit(String key, Future<void> Function() task) {
    return _getOrCreate(key).submit(task);
  }

  /// 返回 [key] 的队列尾；空闲时返回 null。
  Future<void>? tailOf(String key) => _queues[key]?.tail;

  /// 等待 [key] 的在飞任务完成（无在飞则立即返回）。
  Future<void> wait(String key) async {
    final q = _queues[key];
    if (q != null) await q.wait();
  }

  /// 等待所有 key 的队列 drain。
  Future<void> drainAll() async {
    final futures = _queues.values.map((q) => q.tail).whereType<Future<void>>().toList();
    await Future.wait(futures);
  }
}
