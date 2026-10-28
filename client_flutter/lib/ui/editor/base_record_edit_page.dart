import 'dart:async';
import 'dart:io';

import 'package:notee/filesync/file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:notee/model/record_utils.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/utils/object_ref.dart';
import 'package:notee/ui/desktop/desktop_tabs_page.dart';

import 'editor_save_registry.dart';
import '../../utils/state_ext.dart';

/// Unified page state: mode + payload + buildCount.
/// buildCount is reset to 0 by setStateMode on every state transition, then incremented
/// by build() on each frame. Subclasses use buildCount == 0 to detect "first build after
/// state change" — the signal to (re)initialize document content.
class PageState {
  static const modeLoad = 1;
  static const modePass = 2;
  static const modeNormal = 3;

  final int mode;
  final Object? payload; // pass=encrypted String, normal=plaintext String, load=null
  int buildCount; // 0 = first build for this state; incremented by build()

  PageState(this.mode, [this.payload, this.buildCount = 0]);

  bool get isLoad => mode == modeLoad;
  bool get isPass => mode == modePass;
  bool get isNormal => mode == modeNormal;

  String? get encryptedContent => mode == modePass ? payload as String? : null;
  String? get plaintextContent => mode == modeNormal ? payload as String? : null;
}

abstract class BaseRecordEditPage extends StatefulWidget {
  final String uuid;
  // Callback when record is deleted remotely; desktop uses it to close tab, mobile defaults to Navigator.pop
  final ValueCallback<BuildContext>? closePageCallback;

  const BaseRecordEditPage({super.key, required this.uuid, this.closePageCallback});
}

abstract class BaseRecordEditPageState<T extends BaseRecordEditPage> extends BaseState<T>
    with WidgetsBindingObserver
    implements DesktopTabPageState {
  PageState pageState = PageState(PageState.modeLoad);
  String? _password; // Save unlock password
  int _saveCount = 0; // Track save count
  bool isContentChanged = false; // Whether content has been modified
  bool _isInForeground = true; // Whether currently in foreground
  final ObjectRef<String> _contentMd5 = ObjectRef(""); // Track content md5 for diff comparison
  Set<String>? _lastAssetNames; // Asset names from the latest saveRecord, used by dispose

  /// Current record — non-final, replaced in _onTreeChanged when sync delivers a new one.
  late RecordEntry mRecord;

  /// Transition to a new page state; buildCount resets to 0 so the next build
  /// signals a fresh state transition.
  void setStateMode(int mode, [Object? payload]) {
    setState(() {
      pageState = PageState(mode, mode == PageState.modeLoad ? null : payload)..buildCount = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EditorSaveRegistry.instance.register(this);

    mRecord = Repository.get().recordTree.findRecord(widget.uuid)!;
    subscribe(Repository.get().recordTree.onEvent, _onTreeChanged);

    // loadContent() routes locked records to password mode (sPageModePass)
    loadContent();
    RecordOpenedState.get().openFile(mRecord.uuid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    EditorSaveRegistry.instance.unregister(this);
    RecordOpenedState.get().closeFile(mRecord.uuid);
    // Kick off final save through the global per-uuid queue, then prune orphaned
    // assets ONLY after the last flush completes — intermediate auto-saves must
    // NOT delete images that might still be re-added by undo/redo.
    saveRecord()?.whenComplete(() {
      final assetNames = _lastAssetNames;
      if (assetNames != null) {
        Repository.get().fileStore?.pruneAssetsKeepOnly(mRecord.uuid, assetNames);
      }
    });
    super.dispose();
  }

  /// Listen to recordTree changes, compare before/after LocalRecord for this record:
  /// - Deleted remotely → close page (only when no unsaved edits)
  /// - File content change (md5) → re-download and refresh UI (only when no unsaved edits)
  /// - Title change → update title bar
  Future<void> _onTreeChanged(RecordEvent event) async {
    if (!mounted) return;
    final myUuid = widget.uuid;
    // rebuild = 全量刷新，强制命中后再查 findFile 判断是否存在
    final isRebuild = event.rebuildRecords != null;
    final isDeleteOfMe = event.deleteRecords?.contains(myUuid) ?? false;
    final isUpsertOfMe = event.upsertRecords?.any((r) => r.local.uuid == myUuid) ?? false;
    final hit = isRebuild || isDeleteOfMe || isUpsertOfMe;
    if (!hit) return;

    final fileStore = Repository.get().fileStore;
    if (fileStore == null) return;
    final tree = Repository.get().recordTree;
    final newRecord = tree.findRecord(myUuid);

    // Record has been deleted
    if (newRecord == null) {
      if (isContentChanged) return; // Has unsaved edits, don't close
      if (widget.closePageCallback != null) {
        widget.closePageCallback!(context);
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final oldRecord = mRecord;
    mRecord = newRecord;

    // Title change: always update (doesn't affect editing content)
    if (oldRecord.local.name != newRecord.local.name) {
      if (mounted) safeSetState();
    }

    if (isContentChanged) return;
    if (newRecord.local.syncConflict) return;
    if (_contentMd5.value != "" && _contentMd5.value == newRecord.local.md5) return;

    await loadContent();
  }

  void onPageFocusChanged(bool hasFocus) {
    if (!hasFocus) {
      saveRecord();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // When app goes to background or loses focus, save edits and sync
      onPageFocusChanged(false);
    } else if (state == AppLifecycleState.resumed && isInForeground) {
      onPageFocusChanged(true);
    }
  }

  @override
  void setInForeground(bool value) {
    bool wasInForeground = _isInForeground;
    _isInForeground = value;
    if (!value && wasInForeground) {
      onPageFocusChanged(false);
    }
    if (value && !wasInForeground) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        onPageFocusChanged(true);
      }
    }
  }

  bool get isInForeground => _isInForeground;
  /// Extra keyboard shortcuts contributed by subclasses (merged into the base map).
  Map<ShortcutActivator, VoidCallback> shortcutBindings() => {};

  @override
  Widget build(BuildContext context) {
    // First build for this state → reload content; subsequent rebuilds don't.
    final reload = pageState.buildCount == 0;
    pageState.buildCount++;

    Widget body = ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: pageState.isPass
          ? buildModePasswordWidget(pageState.encryptedContent!, reload)
          : pageState.isLoad
          ? buildModeLoadingWidget()
          : buildContentWidget(pageState.plaintextContent!, reload),
    );
    if (!pageState.isNormal) {
      return body;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          saveRecord(); // Execute function directly
        },
        ...shortcutBindings(),
      },
      // Focus wraps to provide focus scope for Shortcuts (Ctrl+Z etc).
      // Mobile doesn't need auto-focus — let logic in initState/onPageFocusChanged decide when to pop keyboard.
      child: Focus(autofocus: Utils.isDesktop(), child: body),
    );
  }

  Widget buildModeLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text(l10n.loading)],
      ),
    );
  }

  Widget buildModePasswordWidget(String encryptedContent, bool reload) {
    return UnlockContentWidget(
      encryptedContent: encryptedContent,
      onUnlocked: (context, password, plaintext) {
        _password = password;
        setStateMode(PageState.modeNormal, plaintext);
      },
    );
  }

  Future<void> loadContent() async {
    // 先等该 uuid 的在飞保存链写完: 关闭后快速重开同一笔记时, 旧页面的 dispose
    // 已发起保存但尚未落盘, 新页面实例的 _saveFuture 是 null, 必须按 uuid 全局等待
    await EditorSaveRegistry.instance.wait(mRecord.uuid);
    if (!pageState.isNormal) {
      //如果后续重新加载新的内容, 则不显示加载中
      setStateMode(PageState.modeLoad);
    }

    RecordEntry entry = mRecord;
    FileStore? fileStore = Repository.get().fileStore;
    if (fileStore == null) {
      return;
    }

    File file = File(fileStore.getWorkFile(entry.uuid));
    if (entry.local.remoteFileVersion > 0 && !file.existsSync()) {
      file = File(fileStore.getBaseFile(entry.uuid));
      if (!file.existsSync() || entry.local.remoteFileVersion > entry.local.baseFileVersion) {
        await fileStore.downloadBaseFile(entry.uuid);
      }
    }
    if (!file.existsSync()) {
      file = File(fileStore.getWorkFile(entry.uuid));
    }
    String content = "";
    if (file.existsSync()) {
      try {
        content = file.readAsStringSync();
        _contentMd5.value = Utils.generateMd5(content);
      } catch (e) {
        AppLogger.e('Editor', "Failed to read file: $e");
      }
    }

    // Extract the body from the tagged note file (asset section is never encrypted).
    final (_, body) = RecordSections.splitContent(content);
    content = body;

    // If record is locked, unlock via UnlockContentWidget (password input + errors inside widget)
    if (entry.local.locked == 1 && content.isNotEmpty) {
      // Try saved password first (auto re-unlock after remote refresh)
      if (_password != null) {
        final decrypted = Utils.decryptContent(content, _password!);
        if (decrypted != null) {
          setStateMode(PageState.modeNormal, decrypted);
          return;
        }
        _password = null;
        if (mounted) {
          // Unlock failed, re-show password input screen
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordIncorrect)));
        }
      }
      // Widget decrypts and calls back with plaintext
      setStateMode(PageState.modePass, content);
      return;
    } else if (entry.local.locked != 1) {
      _password = null; // Password becomes plaintext after version upgrade
    }

    setStateMode(PageState.modeNormal, content);
  }

  (String content, String name, List<String> assetNames) formatContent();

  /// File-level header: [[tag1:len1,tag2:len2,...]]
  /// - All section headers are collected here at the top of the file.
  /// - The length after each tag is the section's UTF-8 byte length.
  /// - Sections immediately follow "]]" in the order tags appear in the header.
  // ================================================================
  //  File-level header parsing (moved to record_ext.dart)
  // ================================================================

  /// Save edit through the global per-uuid queue — same uuid serial, different
  /// uuid parallel. No save is dropped; rapid edits are simply queued after the
  /// in-flight one finishes.
  Future<void>? saveRecord() {
    if (!isContentChanged) return EditorSaveRegistry.instance.tailOf(mRecord.uuid);

    isContentChanged = false;
    _saveCount++;

    var (content, name, assetNames) = formatContent();
    if (name.isEmpty) {
      name = RecordUtils.generateRecordName();
    }
    _lastAssetNames = assetNames.toSet();

    EditorSaveRegistry.instance.submit(mRecord.uuid, () async {
      await saveWorkFile(
        uuid: mRecord.uuid,
        path: mRecord.local.path,
        name: name,
        body: content,
        assetNames: assetNames,
        locked: mRecord.local.locked,
        password: _password,
        md5Ref: _contentMd5,
      ).catchError((e) {
        AppLogger.e('Editor', "[BaseEditPage] save failed: $e");
        isContentChanged = true;
      });
    });
    return EditorSaveRegistry.instance.tailOf(mRecord.uuid);
  }

  /// Write [body] + [assetNames] to work file (with header built here), update
  /// DB metadata.  Handles encryption of body (asset section is NEVER encrypted).
  /// Compares computed md5 against [md5Ref.value] — if equal (no change), skips write.
  /// Otherwise updates [md5Ref.value] with the new md5 so caller stays in sync.
  static Future<void> saveWorkFile({
    required String uuid,
    required String path,
    required String name,
    required String body,
    required List<String> assetNames,
    required ObjectRef<String> md5Ref,
    int locked = 0,
    String? password,
  }) async {
    final fileStore = Repository.get().fileStore;
    if (fileStore == null) {
      AppLogger.w('Editor', "[BaseEditPage] fileStore unavailable, uuid=$uuid save dropped");
      return;
    }
    int effLocked = locked;
    String effectiveBody = body;
    if (password != null) {
      final enc = Utils.encryptContent(body, password);
      if (enc != null) {
        effectiveBody = enc;
      } else {
        effLocked = 0;
      }
    } else {
      effLocked = 0;
    }
    final writeContent = RecordSections.buildRecordContent(assetNames, effectiveBody);
    // md5 is synchronous — compare before any await
    final md5 = Utils.generateMd5(writeContent);
    if (md5 == md5Ref.value) {
      return;
    }
    await fileStore.createWorkFile(uuid, writeContent);
    md5Ref.value = md5;
    await Repository.get().editRecord(
      uuid,
      true,
      DateTime.now().millisecondsSinceEpoch,
      name: name,
      locked: effLocked,
      md5: md5,
    );
  }

  Widget buildContentWidget(String plaintext, bool reload);
}

/// Password unlock widget for encrypted content (shared by edit page and diff panel).
/// Inputs: encrypted content + [onUnlocked] callback(context, password, plaintext).
/// Password input, decryption and error handling all happen inside this widget.
class UnlockContentWidget extends StatefulWidget {
  final String encryptedContent;
  final void Function(BuildContext context, String password, String decryptedContent) onUnlocked;

  const UnlockContentWidget({super.key, required this.encryptedContent, required this.onUnlocked});

  @override
  State<UnlockContentWidget> createState() => _UnlockContentWidgetState();
}

class _UnlockContentWidgetState extends State<UnlockContentWidget> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // autofocus:true sometimes fails on page transition — force focus after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enterPassword)));
      return;
    }
    final decrypted = Utils.decryptContent(widget.encryptedContent, password);
    if (decrypted == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordIncorrect)));
      return;
    }
    widget.onUnlocked(context, password, decrypted);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      // x axis 0 (center), y axis -0.3 (slightly above center)
      alignment: const Alignment(0.0, -0.2),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 48, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 16),
            Text(l10n.recordLocked, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Text(
              l10n.enterPasswordToUnlock,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            ),
            SizedBox(height: 24),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _passwordController,
                    focusNode: _focusNode,
                    autofocus: true,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: l10n.enterPassword,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                    onSubmitted: (value) => _onSubmit(),
                  ),
                  SizedBox(height: 16),
                  FilledButton(
                    onPressed: _onSubmit,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                    child: Text(l10n.unlock),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
