import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/filesync/file_store.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/reminder_tree.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/calendar/reminder_task_editor.dart';
import 'package:notee/model/record_utils.dart';
import 'package:notee/ui/editor/flow_editor/flow_fixed_toolbar.dart';
import 'package:notee/ui/editor/base_record_edit_page.dart';
import 'package:notee/ui/files/record_io.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/ui/editor/flow_editor/code_block_component.dart';
import 'package:notee/ui/editor/flow_editor/code_block_toolbar_item.dart';
import 'package:notee/ui/editor/flow_editor/code_block_newline.dart';
import 'package:notee/ui/editor/flow_editor/find_replace_bar.dart';
import 'package:notee/ui/editor/notee_image_block.dart';
import 'package:notee/ui/editor/record_outline_panel.dart';
import 'package:notee/ui/editor/record_info_dialog.dart';
import 'package:notee/ui/editor/share_record_dialog.dart';
import 'package:notee/ui/editor/record_modify_time_bar.dart';
import 'package:notee/ui/editor/record_reminder_bar.dart';
import 'package:notee/ui/editor/record_tags_bar.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';


/// Shared text style configuration (edit page + diff page).
TextStyleConfiguration buildEditorTextStyle(ThemeData theme) {
  return TextStyleConfiguration(
    text: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
    lineHeight: 1,
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
    leadingDistribution: TextLeadingDistribution.proportional,
  );
}

/// Shared block component builders — paragraph padding zeroed, todo with custom icon, code block.
Map<String, BlockComponentBuilder> buildEditorBlockBuilders(
  ThemeData theme, {
  required String recordUuid,
  required FileStore fileStore,
}) {
  return <String, BlockComponentBuilder>{
    ...standardBlockComponentBuilderMap,
    ImageBlockKeys.type: NoteeImageBlockBuilder(
      fileStore: fileStore,
      srcResolver: (src) => fileStore.resolveRecordAsset(src, recordUuid),
    ),
    TodoListBlockKeys.type: TodoListBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        placeholderText: (_) => AppFlowyEditorL10n.current.toDoPlaceholder,
      ),
      toggleChildrenTriggers: [LogicalKeyboardKey.shift, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight],
    ),
    ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
      configuration: BlockComponentConfiguration(padding: (_) => EdgeInsets.zero),
    ),
    DividerBlockKeys.type: DividerBlockComponentBuilder(
      height: 6,
      configuration: standardBlockComponentConfiguration.copyWith(
        padding: (node) => const EdgeInsets.symmetric(vertical: 4.0),
      ),
    ),
    CodeBlockKeys.type: CodeBlockComponentBuilder(),
  };
}

/// Custom text span decorator that intercepts `record://<uuid>` links and
/// navigates to the corresponding note; all other hrefs fall through to the
/// platform default decorator (which opens external URLs).
TextSpan _recordLinkAwareDecorator(
  BuildContext context,
  Node node,
  int index,
  TextInsert text,
  TextSpan before,
  TextSpan after,
) {
  final href = text.attributes?[AppFlowyRichTextKeys.href] as String?;
  final uuid = href != null ? extractRecordUuid(href) : null;
  if (uuid != null) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => AppNavigator.of(context).navigate('${AppNavigator.uriRecord}$uuid');
    return before.copyWith(recognizer: recognizer);
  }
  return Utils.isDesktop()
      ? defaultTextSpanDecoratorForAttribute(context, node, index, text, before, after)
      : mobileTextSpanDecoratorForAttribute(context, node, index, text, before, after);
}

/// Shared editor style (desktop/mobile switch + dark-mode-aware selection color).
EditorStyle buildEditorStyle(ThemeData theme, TextStyleConfiguration textStyleConfiguration) {
  final isDesktop = Utils.isDesktop();
  final isDark = theme.brightness == Brightness.dark;
  final selectionColor = isDark
      ? theme.colorScheme.onSurfaceVariant.withAlpha(200)
      : theme.colorScheme.primary.withAlpha(100);
  return isDesktop
      ? EditorStyle.desktop(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          cursorColor: theme.colorScheme.primary,
          selectionColor: selectionColor,
          textStyleConfiguration: textStyleConfiguration,
          textSpanDecorator: _recordLinkAwareDecorator,
        )
      : EditorStyle.mobile(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          cursorColor: theme.colorScheme.primary,
          selectionColor: selectionColor,
          textStyleConfiguration: textStyleConfiguration,
          textSpanDecorator: _recordLinkAwareDecorator,
        );
}

class RecordFlowEditorPage extends BaseRecordEditPage {
  /// 搜索关键字：打开笔记后自动跳转并选中首次匹配位置。
  final String? keyword;

  const RecordFlowEditorPage({super.key, required super.uuid, this.keyword, super.closePageCallback});

  @override
  State<RecordFlowEditorPage> createState() => RecordFlowEditorPageState();
}

class RecordFlowEditorPageState<T extends RecordFlowEditorPage> extends BaseRecordEditPageState<T> {
  EditorState editorState = EditorState.blank();
  final FocusNode _focusNode = FocusNode();
  EditorScrollController? editorScrollController;
  Selection? _savedSelection;
  final recordTree = Repository.get().recordTree;

  StreamSubscription<EditorTransactionValue>? _subscription;

  // Find & replace bar state
  bool _showFindBar = false;
  bool _findBarWithReplace = false;

  bool _showOutline = false;

  // 是否已执行过搜索关键字跳转（防止重载时重复跳转）
  bool _keywordJumped = false;

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Desktop 重开同 uuid tab 但关键字变化时：重置跳转标志，重新定位
    if (widget.keyword != oldWidget.keyword && widget.keyword != null && widget.keyword!.isNotEmpty) {
      _keywordJumped = false;
      Timer.run(() {
        if (!mounted) return;
        final kw = widget.keyword;
        if (kw == null || kw.isEmpty || _keywordJumped) return;
        _keywordJumped = true;
        final service = SearchServiceV3(editorState: editorState, jumpInterceptor: (_) => false);
        service.findAndHighlight(kw);
        service.dispose();
      });
    }
  }

  /// 公开动作：查找替换栏（[withReplace] = true 则打开替换模式）。
  void openFindBar({bool withReplace = false}) {
    setState(() {
      _showFindBar = true;
      _findBarWithReplace = withReplace;
    });
  }

  void toggleOutline() {
    setState(() => _showOutline = !_showOutline);
  }

  /// 公开动作：添加提醒。
  Future<void> addReminder() => _addReminder();

  /// 公开动作：显示笔记信息对话框。
  Future<void> showRecordInfo() async {
    await showRecordInfoDialog(
      context,
      mRecord.uuid,
      wordCount: RecordUtils.getDocumentCharCount(editorState.document),
    );
  }

  /// 公开动作：分享当前笔记。
  void shareRecord() {
    ShareRecordDialog.show(
      context,
      uuid: mRecord.uuid,
      markdown: documentToMarkdown(editorState.document),
      title: mRecord.local.name,
      pathName: '${mRecord.local.path}${mRecord.local.name}',
    );
  }

  /// 公开动作：撤销。
  void undo() {
    editorState.undoManager.undo();
  }

  /// 公开动作：重做。
  void redo() {
    editorState.undoManager.redo();
  }

  /// 是否可以撤销/重做（供外部菜单判断按钮启用状态）。
  bool get canUndo => editorState.undoManager.undoStack.isNonEmpty;
  bool get canRedo => editorState.undoManager.redoStack.isNonEmpty;

  /// 大纲面板是否打开（供外部菜单显示勾选态）。
  bool get showOutline => _showOutline;

  /// 页面级溢出菜单项（查找 / 大纲 / 提醒 / 分享 / 信息），三端共用。
  List<PopupMenuEntry<int>> buildOverflowMenuItems(BuildContext context) {
    return [
        PopupMenuItem(
          value: 0,
          child: ListTile(leading: Icon(Icons.search), title: Text(AppFlowyEditorL10n.current.find)),
        ),
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: Icon(Icons.format_list_bulleted, color: _showOutline ? Colors.blue : null),
            title: Text(l10n.outline),
          ),
        ),
      PopupMenuItem(
        value: 3,
        child: ListTile(leading: Icon(Icons.share_outlined), title: Text(l10n.share)),
      ),
      PopupMenuItem(
          value: 2,
          child: ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text(l10n.addReminder)),
        ),
      PopupMenuItem(
          value: 4,
          child: ListTile(leading: Icon(Icons.info_outlined), title: Text(l10n.recordInfo)),
        ),
    ];
  }

  void onOverflowMenuSelect(int value) {
    switch (value) {
      case 0:
        openFindBar();
        break;
      case 1:
        toggleOutline();
        break;
      case 2:
        addReminder();
        break;
      case 3:
        shareRecord();
        break;
      case 4:
        showRecordInfo();
        break;
    }
  }

  @override
  Map<ShortcutActivator, VoidCallback> shortcutBindings() => {
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => openFindBar(),
    const SingleActivator(LogicalKeyboardKey.keyH, control: true): () => openFindBar(withReplace: true),
    const SingleActivator(LogicalKeyboardKey.keyR, control: true): () => openFindBar(withReplace: true),
  };

  // Style caches (theme-dependent; rebuilt when theme changes via didChangeDependencies)
  late TextStyleConfiguration _textStyleConfiguration;
  late Map<String, BlockComponentBuilder> _blockComponentBuilders;

  void _rebuildStyleCache() {
    final theme = Theme.of(context);
    _textStyleConfiguration = buildEditorTextStyle(theme);
    final fileStore = Repository.get().fileStore;
    _blockComponentBuilders = buildEditorBlockBuilders(theme, recordUuid: mRecord.uuid, fileStore: fileStore!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildStyleCache();
  }

  List<ToolbarItem> get _toolbarItems => [
    undoToolbarItem,
    redoToolbarItem,
    todoListItem,
    codeBlockItem,
    quoteItem,
    tableToolbarItem,
    bulletedListItem,
    numberedListItem,
    buildTextColorItem(),
    ...markdownFormatItems,
    ...headingItems,
    linkItem,
    buildImageToolbarItem(buildAsset: _buildAsset),
  ];

  /// Returns pre-assembled (destPath, insertUrl) for an image source path.
  /// Network URLs or missing fileStore fall back to src itself for both.
  ({String destPath, String insertUrl}) _buildAsset(String src) {
    final fs = Repository.get().fileStore;
    if (isRemoteUrl(src) || fs == null) return (destPath: src, insertUrl: src);
    final ext = p.extension(src);
    final filename = '${const Uuid().v4()}${ext.isEmpty ? '.png' : ext}';
    return (destPath: fs.getAssetPath(mRecord.uuid, filename), insertUrl: buildAssetUrl(filename));
  }

  Future<void> _addReminder() async {
    final task = ReminderTask(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    final updated = await showReminderTaskEditor(context, task: task);
    if (updated == null) return;
    final recordEntry = Repository.get().recordTree.findRecord(mRecord.uuid);
    if (recordEntry == null) return;
    final tasks = ReminderTask.fromJsonString(recordEntry.local.reminder)..add(updated);
    await Repository.get().editRecord(
      mRecord.uuid,
      false,
      DateTime.now().millisecondsSinceEpoch,
      reminder: ReminderTask.toJsonString(tasks),
    );
  }

  void listenContentChange() {
    _subscription?.cancel();
    _subscription = editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time != TransactionTime.after) return;
      if (transaction.operations.isEmpty) return;
      if (options.resolvedSource == TransactionSource.none) return;
      isContentChanged = true;
    });
  }

  void _initDocumentFromContent(String plaintext) {
    Document? document;

    bool isNewRecord = plaintext.isEmpty;
    if (isNewRecord) {
      final title = mRecord.local.name.isNotEmpty ? mRecord.local.name : RecordUtils.generateRecordName();

      document = Document.blank()
        ..root.insert(headingNode(level: 1, delta: Delta()..insert(title)), index: 0)
        ..root.insert(dividerNode(), index: 1)
        ..root.insert(paragraphNode(), index: 3);
    } else {
      final trimmed = plaintext.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          document = Document.fromJson(map);
        } catch (e) {
          AppLogger.e('Editor', "Failed to parse JSON: $e");
        }
      }

      document ??= Document.blank()..root.insert(paragraphNode(delta: Delta()..insert(plaintext)), index: 0);
    }

    final newNodes = document.root.children.toList();

    // Collapsed selection at the end of a given node's text.
    Selection selectionAtNodeEnd(Node node) => Selection(
      start: Position(path: node.path, offset: node.delta?.toPlainText().length ?? 0),
      end: Position(path: node.path, offset: node.delta?.toPlainText().length ?? 0),
    );
    final newRecordSelection = newNodes.isNotEmpty ? selectionAtNodeEnd(newNodes.first) : null;

    // First load (no scroll controller yet): create fresh state.
    if (editorScrollController == null) {
      editorState.dispose();
      editorState = EditorState(document: document);
      editorScrollController = EditorScrollController(editorState: editorState);
      listenContentChange();

      if (isNewRecord) {
        editorState.updateSelectionWithReason(newRecordSelection);
      }
      _focusNode.requestFocus();
      _handleKeywordJump();
      return;
    }

    final savedSelection = editorState.selection;
    final existingCount = editorState.document.root.children.length;
    const noHistory = ApplyOptions(recordUndo: false);

    // Clamp the saved selection to the new document. If the new document is
    // shorter, the old path may be out of range → reset to the end of the last node.
    Selection? validSelection;
    if (isNewRecord) {
      validSelection = newRecordSelection;
    } else if (savedSelection != null) {
      final node = document.nodeAtPath(savedSelection.start.path);
      if (node != null) {
        final maxOffset = node.delta?.toPlainText().length ?? 0;
        validSelection = Selection(
          start: Position(path: savedSelection.start.path, offset: savedSelection.start.offset.clamp(0, maxOffset)),
          end: Position(path: savedSelection.end.path, offset: savedSelection.end.offset.clamp(0, maxOffset),
          ),
        );
      } else if (newNodes.isNotEmpty) {
        validSelection = selectionAtNodeEnd(newNodes.last);
      }
    }

    if (existingCount > 0) {
      final deleteTxn = editorState.transaction;
      deleteTxn.deleteNodesAtPath([0], existingCount);
      editorState.apply(deleteTxn, options: noHistory, withUpdateSelection: false);
    }
    if (newNodes.isNotEmpty) {
      final insertTxn = editorState.transaction;
      insertTxn.insertNodes([0], newNodes);
      insertTxn.afterSelection = validSelection;
      editorState.apply(insertTxn, options: noHistory);
    }

    if (Utils.isDesktop()) {
      _focusNode.requestFocus();
    }
    _handleKeywordJump();
  }

  void _handleKeywordJump() {
    final keyword = widget.keyword;
    if (keyword != null && keyword.isNotEmpty && !_keywordJumped) {
      _keywordJumped = true;
      Timer.run(() {
        if (!mounted) return;
        final service = SearchServiceV3(editorState: editorState, jumpInterceptor: (_) => false);
        service.findAndHighlight(keyword);
        service.dispose();
      });
    }
  }

  @override
  void onPageFocusChanged(bool hasFocus) {
    super.onPageFocusChanged(hasFocus);
    if (hasFocus) {
      // Mobile: don't auto-focus when document has content (user taps to edit); empty doc or desktop focuses.
      final hasContent = editorState.document.root.children.any((node) => (node.delta?.toPlainText().length ?? 0) > 0);
      if (Utils.isDesktop() || !hasContent) {
        _focusNode.requestFocus();
      }
      _restoreSelection();
    } else {
      _saveSelection();
    }
  }

  void _saveSelection() {
    final selection = editorState.selection;
    if (selection != null) {
      _savedSelection = selection;
    }
  }

  void _restoreSelection() {
    if (_savedSelection == null) return;
    Timer.run(() {
      if (!mounted) return;
      if (editorState.selection == null) {
        editorState.updateSelectionWithReason(_savedSelection!);
      }
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _restoreSelection();
    } else {
      _saveSelection();
    }
  }

  @override
  (String content, String name, List<String> assetNames) formatContent() {
    final docJson = editorState.document.toJson();
    final String jsonString = jsonEncode(docJson);
    String name = RecordUtils.getDocumentTitle(editorState.document);
    if (name.isEmpty) {
      name = RecordUtils.generateRecordName();
    }
    // Collect asset filenames referenced by image nodes (relative
    // assets/{recordUuid}/{filename} → strip prefix to {filename}).
    final assetNames = DocumentImage.collectAssetNames(editorState.document);
    final content = jsonString; // body only; assetNames passed separately to saveWorkFile
    return (content, name, assetNames);
  }

  /// 统一的大纲面板外形：240 宽 + 圆角 4 + 边框。
  /// 两端调用方只负责决定摆放位置（桌面 Row 并排 / 手机 Stack 浮层）。
  Widget _buildOutlinePanelWrapper(ThemeData theme) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: RecordOutlinePanel(
        editorState: editorState,
        editorScrollController: editorScrollController,
        onClose: () => setState(() => _showOutline = false),
      ),
    );
  }

  @override
  Widget buildContentWidget(String plaintext, bool reload) {
    // First build after state change → (re)initialize document with fresh plaintext
    if (reload) {
      _initDocumentFromContent(plaintext);
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FixedToolbar(
          scrollable: true,
          items: _toolbarItems,
          editorState: editorState,
          toolbarHeight: 30,
          iconColor: theme.colorScheme.onSurface,
          activeColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface,
          tooltipBuilder: (context, id, message, child) => Tooltip(message: message, child: child),
        ),
        if (_showFindBar)
          EditorFindReplaceBar(
            key: ValueKey(_findBarWithReplace),
            editorState: editorState,
            initialShowReplace: _findBarWithReplace,
            onClose: () => setState(() => _showFindBar = false),
          ),
        Expanded(
          child: Utils.isDesktop()
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showOutline)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildOutlinePanelWrapper(theme),
                      ),
                    Expanded(child: _buildEditorWidget(theme, _blockComponentBuilders, _textStyleConfiguration)),
                  ],
                )
              : Stack(
                  children: [
                    _buildEditorWidget(theme, _blockComponentBuilders, _textStyleConfiguration),
                    if (_showOutline)
                      Positioned(
                        top: 8,
                        right: 8,
                        bottom: 8,
                        child: _buildOutlinePanelWrapper(theme),
                      ),
                  ],
                ),
        ),
        TagBar(uuid: mRecord.uuid),
        ReminderBar(uuid: mRecord.uuid),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _subscription?.cancel();
    editorScrollController?.dispose();
    super.dispose();
    editorState.dispose();
  }

  Widget _buildEditorWidget(
    ThemeData theme,
    Map<String, BlockComponentBuilder> blockComponentBuilders,
    TextStyleConfiguration textStyleConfiguration,
  ) {
    final editor = AppFlowyEditor(
      editorState: editorState,
      focusNode: _focusNode,
      blockComponentBuilders: blockComponentBuilders,
      characterShortcutEvents: [codeBlockInsertNewLine, ...standardCharacterShortcutEvents],
      editorScrollController: editorScrollController,
      // Mobile: disable autoScrollEdgeOffset (set 0). Default 220 is too large on phone screens;
      // non-drag-selection scenarios (tap/keyboard pop-up) also trigger autoScroll → poor UX.
      // When actually dragging selection handles, user's finger is already at the edge and can scroll.
      autoScrollEdgeOffset: Utils.isDesktop() ? 220 : 40,
      header: RecordModifyTimeBar(uuid: mRecord.uuid),
      editorStyle: buildEditorStyle(theme, textStyleConfiguration),
      contextMenuBuilder: (context, position, editorState, onPressed) {
        final selection = editorState.selection;
        final nodes = selection != null ? editorState.getNodesInSelection(selection) : const <Node>[];
        final isImage = nodes.isNotEmpty && nodes.every((n) => n.type == ImageBlockKeys.type);
        return ContextMenu(
          position: position,
          editorState: editorState,
          items: isImage ? imageContextMenuItems : standardContextMenuItems,
          onPressed: onPressed,
        );
      },
    );

    if (Utils.isDesktop()) {
      return editor;
    }

    final scrollController = editorScrollController;
    if (scrollController == null) {
      return editor;
    }

    return MobileFloatingToolbar(
      editorState: editorState,
      editorScrollController: scrollController,
      floatingToolbarHeight: 48,
      toolbarBuilder: (context, anchor, closeToolbar) {
        final selection = editorState.selection;
        final nodes = selection != null ? editorState.getNodesInSelection(selection) : const <Node>[];
        final isImage = nodes.isNotEmpty && nodes.every((n) => n.type == ImageBlockKeys.type);
        if (isImage) {
          return ContextMenu(
            position: anchor,
            editorState: editorState,
            items: imageContextMenuItems,
            onPressed: closeToolbar,
          );
        }
        return AdaptiveTextSelectionToolbar.editable(
          clipboardStatus: ClipboardStatus.pasteable,
          onCopy: () {
            copyCommand.execute(editorState);
            closeToolbar();
          },
          onCut: () {
            cutCommand.execute(editorState);
            closeToolbar();
          },
          onPaste: () {
            pasteCommand.execute(editorState);
            closeToolbar();
          },
          onSelectAll: () {
            selectAllCommand.execute(editorState);
            closeToolbar();
          },
          onLiveTextInput: null,
          onLookUp: null,
          onSearchWeb: null,
          onShare: null,
          anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
        );
      },
      child: editor,
    );
  }
}

