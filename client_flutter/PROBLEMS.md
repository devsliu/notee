# 项目问题解决记录

本文档记录开发过程中遇到的核心问题、根因分析、解决方案，以及对第三方依赖（AppFlowy Editor）的源码级修改原因。

---

## 1. Android 图片节点点击 ANR / Crash

### 现象

在 Android 真机或模拟器上，编辑页弹出软键盘后，点击图片 / 表格 / 分割线等 block 节点，应用主线程卡死，几秒后弹出"应用无响应"对话框（ANR）。如果不打开软键盘（直接进入编辑页不点击文本框），点击图片无 ANR。

### 根因

AppFlowy Editor 的桌面端 `_onSecondaryTapDown` 和 mobile 端 `_onTapUpAndroid` 在用户点击时会构造 `Selection` 对象写入 `editorState.selection`，无论目标节点是 text 还是 block。

`Selection` 携带 `start.path` / `end.path` 指向目标节点的索引位置。当目标是图片节点时，该节点的 `delta == null`（block 节点没有文本内容），所以 `startOffset` / `endOffset` 被设为 0 或 1。

此时 Flutter 引擎的文本输入系统（`TextInputConnection`）检测到 selection 变更后，尝试通过 `input_connection.cc` 的 `getTextBeforeCursor` / `getSurroundingText` 查询光标处的文本。问题在于：图片节点在引擎的文本模型中根本**不存在**——它不是一个字符，而是一个 widget block。引擎传入的字符偏移量在整个 document 的文本模型里是无效位置，导致 `input_connection.cc` 里的 `assert(offset <= composingEnd || offset <= contentEnd)` 触发或进入死循环，**阻塞 Android 主线程**。

### 链路回溯

```
用户点击图片
  → MobileSelectionService._onTapUpAndroid (或 DesktopSelectionService._onSecondaryTapDown)
    → editorState.selection = Selection.single(path: node.path, startOffset: 0, endOffset: 1)
      → EditorState.selection setter
        → selectionNotifier.value = value
          → Flutter TextInputConnection 收到 selection 变更
            → input_connection.cc::getSurroundingText(0, 0)
              → 尝试在 delta == null 的节点上查找字符位置
                → 死锁 / ANR
```

### 解决方案（双保险）

#### 第一层：editor_state.dart setter 兜底拦截（submodule 修改）

在 `EditorState.selection` setter 里加守卫，任何 `endNode.delta == null` 的 selection 直接 return，不写进 notifier：

```dart
// appflowy_editor/lib/src/editor_state.dart
set selection(Selection? value) {
  if (value != null) {
    final endNode = getNodeAtPath(value.end.path);
    if (endNode != null && endNode.delta == null) {
      return; // block 节点不允许设置 selection
    }
  }
  // ... 原始逻辑
}
```

这是最小侵入的 choke point——无论 selection 从哪里来（桌面右键、mobile 点击、代码调用），全平台拦截。

#### 第二层：图片节点 AbsorbPointer 前置拦截

在自定义的 `NoteeImageBlockWidget` 里用 `AbsorbPointer` 包裹图片，使 editor 的 selection gesture detector **根本收不到事件**。然后在 AbsorbPointer 外再包一层独立的 `GestureDetector(onSecondaryTapUp / onLongPressStart)` 处理右键 / 长按菜单。

这样 editor 的 `MobileSelectionService` / `DesktopSelectionService` 完全不会在 block 节点上触发 selection 更新，从源头避免问题。

### 独立通道

图片的保存 / 删除菜单**不通过 selection**。之前 AppFlowy 自带的 `contextMenuBuilder` 会校验 `currentSelectedNodes.every((n) => n.delta != null)`，block 节点被 filter 掉。现在图片右键 / 长按走自己的 OverlayEntry + ContextMenu，直接用 `widget.node` 做 transaction，不依赖任何 selection 状态。

---

## 2. ContextMenu 分组 Divider 间隙过大

### 现象

ContextMenu 支持二维 items：`[[group0item1, group0item2], [group1item1]]`。组与组之间自动插入 `const Divider()`。Flutter `Divider` 默认 `height: 16, thickness: 0`，上下各有 7.5px 空白，加上外层 Container 的 padding，视觉上是一个巨大间隙。

### 背景补充

AppFlowy 自带的 cut/copy/paste 菜单用的是**单 group** `[[cut, copy, paste]]`，所以 `if (j == 0 && i != 0)` 这个 Divider 插入条件**永远不触发**（i 始终为 0）。自带菜单 item 之间的"细分割线"其实是多个独立 `Material(child: InkWell(borderRadius: 6))` 圆角矩形贴在一起的视觉边界，不是真正的 Divider。

### 解决方案

不改 ContextMenu（用户要求）。图片菜单用**单 group** `[[save, delete]]`，跟 cut/copy/paste 结构一致，item 之间只有 InkWell 圆角缝，没有真正的 Divider。

---

## 3. 图片保存 Android 无反应

### 现象

`FilePicker.platform.saveFile()` 在 Android 上经常返回 null，原因是 Android 11+ 的 SAF（Storage Access Framework）权限限制——saveFile 走的是 OpenDocument 意图，某些设备 / API level 不支持写入。

### 解决方案

改用 `FilePicker.platform.getDirectoryPath()` 先选文件夹，再用 `File.copy` 把图片以原文件名拷进去。跟项目里导出 Markdown 的流程完全一致（见 `record_io.dart` 里的 `exportSelectFolder`），在 Android 上稳定可靠。

---

## 4. 保存流程重构

### 历史版本（问题链）

1. **直接 async/await saveRecord**：快速打字时每次 edit 都 await save，阻塞 UI
2. **递归 .then() 链 coalescing**：
   ```dart
   if (_saveFuture != null) {
     final current = _saveFuture!;
     _saveFuture = current.then((_) async {
       if (isContentChanged) await saveRecord();
     });
     return _saveFuture;
   }
   ```
   能工作但逻辑复杂，容易误解为死循环（实际不会——`isContentChanged` 在进入保存时已置 false）
3. **DedupTaskQueue**（否决）：dedup 是同一个 key 多次 submit 共享一次执行，会丢中间态内容

### 最终方案

引入 `KeysSerialTaskQueue`（`lib/utils/keys_serial_task_queue.dart`），通用多 key 串行队列：

```dart
class KeysSerialTaskQueue {
  final Map<String, Future<void>> _tailByKey = {};

  Future<void> submit(String key, Future<void> Function() task) {
    final prev = _tailByKey[key] ?? Future.value();
    final future = prev.then((_) => task());
    _tailByKey[key] = future;
    future.whenComplete(() {
      if (_tailByKey[key] == future) _tailByKey.remove(key);
    });
    return future;
  }
}
```

特性：
- 同 uuid 严格串行（后一个等前一个跑完）
- 不同 uuid 天然并行（两个编辑页互不干扰）
- tail 完成自动从 map 移除，无内存泄漏

上层 `EditorSaveRegistry`（`lib/ui/editor/editor_save_registry.dart`）继承它，单例持有：

```dart
class EditorSaveRegistry extends KeysSerialTaskQueue {
  static final EditorSaveRegistry instance = EditorSaveRegistry._();
  final Set<BaseRecordEditPageState> _liveEditors = {}; // 私有
  void register(BaseRecordEditPageState editor) => ...;
  void unregister(BaseRecordEditPageState editor) => ...;
  Future<void> flushAll() async { // 退出/关窗时触发
    for (final e in _liveEditors.toList()) e.saveRecord();
    await drainAll();
  }
}
```

保存调用：

```dart
Future<void>? saveRecord() {
  if (!isContentChanged) return EditorSaveRegistry.instance.tailOf(mRecord.uuid);

  isContentChanged = false;
  _saveCount++;

  // formatContent 在 submit 上方执行 — 快照时刻对齐 isContentChanged = false，
  // 捕获的就是用户这次保存意图的状态
  var (content, name, assetNames) = formatContent();
  if (name.isEmpty) name = RecordUtils.generateRecordName();
  _lastAssetNames = assetNames.toSet(); // dispose prune 用

  EditorSaveRegistry.instance.submit(mRecord.uuid, () async {
    await saveWorkFile(...);
  });
  return EditorSaveRegistry.instance.tailOf(mRecord.uuid);
}
```

### pruneAssetsKeepOnly 时机

删除孤儿图片（record 不再引用的物理文件）**只在 dispose 里的最后一次保存完成后调用**，中间态自动保存绝对不能 prune——因为用户删了图又 undo 回来，中间那次 prune 会把刚删的图物理删除，undo 回来就找不到文件了。

`_lastAssetNames` 是 nullable `Set<String>?`，首次打开页面未保存就 dispose 时为 null，跳过 prune。

---

## 依赖修改清单

### Submodule: `appflowy_editor`（branch: `devsliu`）

| 文件 | 修改 | 原因 |
|---|---|---|
| `lib/src/editor_state.dart` | `selection` setter 加 guard，endNode.delta == null 时 return | Android block 节点 selection 导致 InputConnection ANR |

### 主仓库

| 文件 | 修改 | 原因 |
|---|---|---|
| `client_flutter/lib/ui/editor/notee_image_block.dart` | 重写图片 block；AbsorbPointer + 独立 GestureDetector；自定义 ContextMenu | 1. AbsorbPointer 阻止 editor selection gesture 触发 block 节点 selection<br>2. 独立通道支持桌面右键 + Android 长按<br>3. ContextMenuItem.onPressed 直接操作 widget.node，不走 selection |
| `client_flutter/lib/ui/editor/base_record_edit_page.dart` | saveRecord 通过 EditorSaveRegistry.instance.submit 串行提交 | 替换递归 .then() 链，逻辑更直白 |
| `client_flutter/lib/ui/editor/editor_save_registry.dart` | 新建 | 全局单例，继承 KeysSerialTaskQueue，持有 liveEditors + flushAll |
| `client_flutter/lib/utils/keys_serial_task_queue.dart` | 新建 | 通用多 key 串行队列工具 |
| `client_flutter/lib/ui/base_app.dart` | flushAll 退出前等待所有队列 drain | 防止进程退出丢失最后一次编辑 |
| `client_flutter/lib/ui/desktop/desktop_title_bar.dart` | 关窗前 flushAll | 同上 |

### 删除的文件

| 文件 | 原因 |
|---|---|
| `client_flutter/lib/ui/editor/editor_save_coordinator.dart` | 被 EditorSaveRegistry 取代 |
| `client_flutter/lib/utils/serial_task_queue.dart` | 被 KeysSerialTaskQueue 取代（单 key → 多 key） |
