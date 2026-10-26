import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/filesync/file_store.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/editor/base_record_edit_page.dart';
import 'package:notee/ui/editor/record_flow_editor_page.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/object_ref.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/ui/calendar/reminder_panel.dart';

/// Single-side editor panel
/// - Receives file path, auto reads from disk + unlocks (if locked != 0)
/// - After unlock succeeds, wraps AppFlowyEditor
/// - editable=false means read-only (remote version)
/// - editable=true includes Ctrl+S save shortcut; save logic lives inside panel
/// Shared title bar for diff panels and meta-only mode.
class _ConflictTitleBar extends StatelessWidget {
  final String title;
  final Color color;
  final int version;
  final String name;
  final String path;
  final int editTime;
  final String uuid;
  final bool editable;

  const _ConflictTitleBar({
    required this.title,
    required this.color,
    required this.version,
    required this.name,
    required this.path,
    required this.editTime,
    required this.uuid,
    this.editable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      color: color.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$title  v$version  ${editTime > 0 ? Utils.formatTime(editTime) : "-"}",
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
            Text(
              "$path$name",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            ReminderPanel(uuid: uuid, editable: editable, maxLines: 5),
          ],
        ),
      ),
    );
  }
}

class DiffEditorPanel extends StatefulWidget {
  final String uuid;
  final String filePath;
  final bool editable;
  final bool isLocked;
  final String name;
  final String path;
  final Widget titleBar;

  const DiffEditorPanel({
    super.key,
    required this.uuid,
    required this.filePath,
    required this.editable,
    required this.isLocked,
    this.name = '',
    this.path = '',
    required this.titleBar,
  });

  @override
  State<DiffEditorPanel> createState() => _DiffEditorPanelState();
}

class _DiffEditorPanelState extends State<DiffEditorPanel> {
  PageState pageState = PageState(PageState.modeLoad);
  EditorState? _editorState;
  EditorScrollController? _scrollController;
  FocusNode? _focusNode; // Only for editable panels
  String? _password; // Set after successful unlock; used for encrypt-save
  final ObjectRef<String> _contentMd5 = ObjectRef("");
  List<String> _originalAssets = []; // Preserve asset list from the loaded file
  bool isContentChanged = false;
  StreamSubscription<EditorTransactionValue>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.editable) _focusNode = FocusNode();
    _loadContent();
  }

  void _listenContentChange() {
    _subscription?.cancel();
    _subscription = _editorState!.transactionStream.listen((event) {
      final (time, transaction, _) = event;
      if (time != TransactionTime.after) return;
      if (transaction.operations.isEmpty) return;
      isContentChanged = true;
    });
  }

  Future<void> _loadContent() async {
    final rawContent = await _readContent();
    if (!mounted) return;
    _contentMd5.value = Utils.generateMd5(rawContent);
    // Strip the [[image]]/[[content]] tagged header so the editor sees the body.
    final (assets, body) = RecordSections.splitContent(rawContent);
    _originalAssets = assets;
    if (widget.isLocked) {
      setState(() => pageState = PageState(PageState.modePass, body));
    } else {
      setState(() => pageState = PageState(PageState.modeNormal, body));
    }
  }

  Future<String> _readContent() async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return '';
    final file = File(widget.filePath);
    if (!await file.exists()) return '';
    return await file.readAsString();
  }

  Document _parseDocument(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return Document.blank(withInitialText: true);
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final doc = Document.fromJson(jsonDecode(trimmed) as Map<String, dynamic>);
        if (doc.root.children.isEmpty) return Document.blank(withInitialText: true);
        return doc;
      } catch (e) {
        AppLogger.e('Conflict', "Failed to parse note JSON: $e");
      }
    }
    return Document.blank()..root.insert(paragraphNode(delta: Delta()..insert(content)), index: 0);
  }

  Future<void> save() async {
    if (!pageState.isNormal) return;
    if (!widget.editable || _editorState == null || !isContentChanged) return;
    isContentChanged = false;
    final jsonString = jsonEncode(_editorState!.document.toJson());
    // Pass body + original asset list separately so saveWorkFile can build the header.
    await BaseRecordEditPageState.saveWorkFile(
      uuid: widget.uuid,
      path: widget.path,
      name: widget.name,
      body: jsonString,
      assetNames: _originalAssets,
      locked: widget.isLocked ? 1 : 0,
      password: _password,
      md5Ref: _contentMd5,
    );
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    _subscription?.cancel();
    _scrollController?.dispose();
    _editorState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // First build for this state → reload content; subsequent rebuilds don't.
    final reload = pageState.buildCount == 0;
    pageState.buildCount++;

    if (pageState.isLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pageState.isPass) {
      return UnlockContentWidget(
        encryptedContent: pageState.encryptedContent!,
        onUnlocked: (context, password, plaintext) {
          _password = password;
          setState(() => pageState = PageState(PageState.modeNormal, plaintext));
        },
      );
    }
    return _buildEditor(reload);
  }

  Widget _buildEditor(bool reload) {
    if (reload) {
      // Dispose previous editor state if any, then create fresh one
      _subscription?.cancel();
      _scrollController?.dispose();
      _editorState?.dispose();
      final plaintext = pageState.plaintextContent!;
      _editorState = EditorState(document: _parseDocument(plaintext));
      _editorState!.editable = widget.editable;
      _scrollController = EditorScrollController(editorState: _editorState!);
      if (widget.editable) {
        _listenContentChange();
      }
    }

    final theme = Theme.of(context);
    final fileStore = Repository.get().fileStore!;
    final blockBuilders = buildEditorBlockBuilders(theme, recordUuid: widget.uuid, fileStore: fileStore);
    if (!widget.editable) {
      blockBuilders[ParagraphBlockKeys.type] = ParagraphBlockComponentBuilder(
        configuration: BlockComponentConfiguration(padding: (_) => EdgeInsets.zero),
        showPlaceholder: (editorState, node) => false,
      );
    }

    final textStyleConfiguration = buildEditorTextStyle(theme);
    final editorStyle = buildEditorStyle(theme, textStyleConfiguration);

    Widget child = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.titleBar,
        Expanded(
          child: AppFlowyEditor(
            editorState: _editorState!,
            editable: widget.editable,
            focusNode: _focusNode,
            editorScrollController: _scrollController,
            blockComponentBuilders: blockBuilders,
            characterShortcutEvents: standardCharacterShortcutEvents,
            header: const SizedBox(height: 16),
            editorStyle: editorStyle,
          ),
        ),
      ],
    );

    if (widget.editable) {
      child = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            save();
          },
        },
        child: Focus(autofocus: true, child: child),
      );
    }

    return child;
  }
}

// =========================================================================
// ConflictDiffPage: unified conflict resolution page
//   - isFileConflict=true:  dual editor (remote read-only + local editable)
//   - isFileConflict=false: file unmodified notice + metadata conflict resolution
// Common: top simplified name/path meta bar + keep buttons
// =========================================================================

bool isFileConflict(RecordEntry record) {
  final fs = Repository.get().fileStore;
  if (fs == null) return false;
  final workFile = File(fs.getWorkFile(record.uuid));
  return record.local.remoteFileVersion > record.local.fileVersion && workFile.existsSync();
}

class ConflictDiffPage extends StatefulWidget {
  final RecordEntry record;
  const ConflictDiffPage({super.key, required this.record});

  @override
  State<ConflictDiffPage> createState() => _ConflictDiffPageState();
}

class _ConflictDiffPageState extends State<ConflictDiffPage> {
  late final bool _isFileConflict;
  bool _isVertical = false;
  final GlobalKey<_DiffEditorPanelState> _localPanelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isFileConflict = isFileConflict(widget.record);
  }

  Future<void> _resolve(bool keepLocal) async {
    if (_isFileConflict && keepLocal) {
      await _localPanelKey.currentState?.save();
    }
    await Repository.get().resolveConflict(widget.record.uuid, keepLocal);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: createAppBar(
        title: "",
        actions: [
          if (_isFileConflict)
            IconButton(
              icon: Icon(_isVertical ? Icons.swap_horiz : Icons.swap_vert, size: 20),
              tooltip: _isVertical ? l10n.orientationHorizontal : l10n.orientationVertical,
              onPressed: () => setState(() => _isVertical = !_isVertical),
            ),
          TextButton.icon(
            onPressed: () => _resolve(false),
            icon: const Icon(Icons.cloud_download, size: 18),
            label: Text(l10n.keepRemote),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          TextButton.icon(
            onPressed: () => _resolve(true),
            icon: const Icon(Icons.edit, size: 18),
            label: Text(l10n.keepLocal),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
        ],
      ),
      body: _isFileConflict ? _buildEditors(record) : _buildMetaOnly(record, theme),
    );
  }

  /// File non-conflict mode, same layout as _buildEditors: two title bars + center notice
  Widget _buildMetaOnly(RecordEntry record, ThemeData theme) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withAlpha(15),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.recordContentUnchangedMetaConflict,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );

    final remoteBar = _ConflictTitleBar(
      title: l10n.conflictRemoteVersion,
      color: Colors.green,
      version: record.local.remoteVersion,
      name: record.remote.name,
      path: record.remote.path,
      editTime: record.remote.editAt,
      uuid: record.uuid,
      editable: false,
    );
    final localBar = _ConflictTitleBar(
      title: l10n.conflictLocalModified,
      color: Colors.blue,
      version: record.local.version,
      name: record.local.name,
      path: record.local.path,
      editTime: record.local.editAt,
      uuid: record.uuid,
      editable: true,
    );

    if (_isVertical) {
      return Column(children: [remoteBar, content, localBar]);
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              remoteBar,
              Expanded(child: content),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              localBar,
              Expanded(child: content),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditors(RecordEntry record) {
    final isLocked = record.local.locked != 0;
    FileStore? fileStore = Repository.get().fileStore;
    if (fileStore == null) return Container();

    final remotePanel = DiffEditorPanel(
      uuid: record.uuid,
      filePath: fileStore.getBaseFile(record.uuid),
      editable: false,
      isLocked: isLocked,
      name: record.remote.name,
      path: record.remote.path,
      titleBar: _ConflictTitleBar(
        title: l10n.conflictRemoteVersion,
        color: Colors.green,
        version: record.local.remoteVersion,
        name: record.remote.name,
        path: record.remote.path,
        editTime: record.remote.editAt,
        uuid: record.uuid,
        editable: false,
      ),
    );
    final localPanel = DiffEditorPanel(
      key: _localPanelKey,
      uuid: record.uuid,
      filePath: fileStore.getWorkFile(record.uuid),
      editable: true,
      isLocked: isLocked,
      name: record.local.name,
      path: record.local.path,
      titleBar: _ConflictTitleBar(
        title: l10n.conflictLocalModified,
        color: Colors.blue,
        version: record.local.version,
        name: record.local.name,
        path: record.local.path,
        editTime: record.local.editAt,
        uuid: record.uuid,
        editable: true,
      ),
    );

    if (_isVertical) {
      return Column(
        children: [
          Expanded(child: remotePanel),
          const Divider(height: 1),
          Expanded(child: localPanel),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: remotePanel),
        const VerticalDivider(width: 1),
        Expanded(child: localPanel),
      ],
    );
  }
}
