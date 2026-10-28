import 'dart:async';

/// 通用多 key 串行任务队列。
///
/// 同一 [key] 的 submit 严格串行（后一个等前一个跑完再开始），不同 [key]
/// 之间并行互不干扰。tailOf / waitPending / drainAll 可用于等待队列 drain。
class KeysSerialTaskQueue {
  final Map<String, Future<void>> _tailByKey = {};

  /// 提交一次任务到 [key] 专属队列。返回这次任务的 Future。
  /// 相同 [key] 的多次 submit 严格 FIFO 串行，不同 [key] 并行。
  Future<void> submit(String key, Future<void> Function() task) {
    final prev = _tailByKey[key] ?? Future.value();
    final future = prev.then((_) => task());
    _tailByKey[key] = future;
    future.whenComplete(() {
      if (_tailByKey[key] == future) _tailByKey.remove(key);
    });
    return future;
  }

  /// 返回 [key] 的队列尾；空闲时返回 null。
  Future<void>? tailOf(String key) => _tailByKey[key];

  /// 等待 [key] 的在飞任务完成（无在飞则立即返回）。
  Future<void> wait(String key) async {
    final future = _tailByKey[key];
    if (future != null) await future;
  }

  /// 等待所有 key 的队列 drain。
  Future<void> drainAll() async {
    while (_tailByKey.isNotEmpty) {
      await Future.wait(_tailByKey.values.toList());
    }
  }
}
