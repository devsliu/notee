import '../../utils/serial_task_queue.dart';
import 'base_record_edit_page.dart';

/// 全局保存注册中心 — 继承 [MultiSerialTaskQueue] 直接作为全局队列实例 + 活动编辑页集合。
///
/// BaseRecordEditPageState 在 initState/dispose 时通过 [register]/[unregister] 登记/注销自己；
/// 退出 / 关窗前调 [flushAll] 触发所有活动编辑页保存并等队列 drain。
class EditorSaveRegistry extends MultiSerialTaskQueue {
  EditorSaveRegistry._()
      : super(
          maxPending: 1,
          overflowStrategy: QueueOverflowStrategy.dropOldest,
        );

  static final EditorSaveRegistry instance = EditorSaveRegistry._();

  final Set<BaseRecordEditPageState> _liveEditors = {};

  void register(BaseRecordEditPageState editor) => _liveEditors.add(editor);
  void unregister(BaseRecordEditPageState editor) => _liveEditors.remove(editor);

  /// 触发所有活动编辑页保存，等全局队列 drain。
  Future<void> flushAll() async {
    for (final editor in _liveEditors.toList()) {
      editor.saveRecord();
    }
    await drainAll();
  }
}
