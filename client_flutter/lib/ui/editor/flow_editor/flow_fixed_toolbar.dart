import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/utils/app_logger.dart';

class FixedToolbar extends StatefulWidget {
  const FixedToolbar({
    super.key,
    required this.items,
    required this.editorState,
    this.scrollable = false,
    this.toolbarHeight = 40,
    this.iconSize = 18,
    this.iconColor,
    this.activeColor,
    this.backgroundColor,
    this.padding,
    this.decoration,
    this.tooltipBuilder,
    this.placeHolderBuilder,
  });

  final List<ToolbarItem> items;
  final EditorState editorState;
  final bool scrollable;
  final double toolbarHeight;
  final double iconSize;
  final Color? iconColor;
  final Color? activeColor;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final Decoration? decoration;
  final ToolbarTooltipBuilder? tooltipBuilder;
  final PlaceHolderItemBuilder? placeHolderBuilder;

  @override
  State<FixedToolbar> createState() => _FixedToolbarState();
}

class _FixedToolbarState extends State<FixedToolbar> {
  StreamSubscription? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _bindEditorState();
  }

  @override
  void didUpdateWidget(covariant FixedToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      oldWidget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
      _transactionSubscription?.cancel();
      _bindEditorState();
    }
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
    _transactionSubscription?.cancel();
    super.dispose();
  }

  void _bindEditorState() {
    widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    _transactionSubscription = widget.editorState.transactionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.onSurface;
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    final children = widget.items.map((item) => _buildItem(item, iconColor, activeColor)).toList();

    return Container(
      color: backgroundColor,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8),
      decoration: widget.decoration,
      child: widget.scrollable
          ? SizedBox(
              height: widget.toolbarHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1) const SizedBox(width: 2),
                    ],
                  ],
                ),
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.toolbarHeight),
              child: Wrap(spacing: 2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: children),
            ),
    );
  }

  /// Items that stay enabled even when there is no selection (they don't
  /// operate on the current selection).
  static const _selectionFreeItems = {
    'editor.undo',
    'editor.redo',
    'editor.reminder',
    'editor.info',
    'editor.find',
    'editor.outline',
  };

  Widget _buildItem(ToolbarItem item, Color iconColor, Color activeColor) {
    // Items are null-selection-safe; keep the toolbar visible at all times.
    // tooltipBuilder is forwarded so each item can wrap its own tooltip message.
    var w = item.builder?.call(context, widget.editorState, activeColor, iconColor, widget.tooltipBuilder);
    // Builder may have wrapped the icon in a Tooltip — unwrap before the type check
    final icon = w is Tooltip ? w.child : w;
    if (icon is! SVGIconItemWidget) return const SizedBox.shrink();
    // No selection → gray out items that operate on the selection. Opacity is
    // used instead of a gray iconColor because iconBuilder closures capture the
    // original color. Their onPressed callbacks are all null-selection-safe.
    if (widget.editorState.selection == null && !_selectionFreeItems.contains(item.id)) {
      w = Opacity(opacity: 0.4, child: w);
    }
    return w!;
  }
}

final ToolbarItem timeToolbarItem = ToolbarItem(
  id: 'editor.time',
  group: 0,
  isActive: (_) => true,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.timer_outlined, color: iconColor, size: 18),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () {
        final now = DateTime.now();
        final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(now);
        final selection = editorState.selection;
        if (selection == null) return;
        final node = editorState.document.nodeAtPath(selection.end.path);
        if (node == null) return;
        final transaction = editorState.transaction
          ..insertTextDelta(node, selection.endIndex, Delta()..insert('$formattedTime '));
        editorState.apply(transaction);
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.time', l10n.insertTime, child);
    }
    return child;
  },
);

final ToolbarItem todoListItem = ToolbarItem(
  id: 'editor.todo_list',
  group: 3,
  isActive: (editorState) => editorState.selection != null,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final node = selection != null ? editorState.getNodeAtPath(selection.start.path) : null;
    final isHighlight = node?.type == TodoListBlockKeys.type;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.check_box_outlined, size: 18, color: isHighlight ? highlightColor : iconColor),
      isHighlight: isHighlight,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () {
        final selection = editorState.selection;
        if (selection == null) return;
        final node = editorState.getNodeAtPath(selection.start.path);
        if (node == null) return;
        if (node.type == TodoListBlockKeys.type) {
          editorState.formatNode(
            selection,
            (node) => node.copyWith(
              type: ParagraphBlockKeys.type,
              attributes: {ParagraphBlockKeys.delta: (node.delta ?? Delta()).toJson()},
            ),
          );
        } else {
          editorState.formatNode(
            selection,
            (node) => node.copyWith(
              type: TodoListBlockKeys.type,
              attributes: {TodoListBlockKeys.checked: false, blockComponentDelta: (node.delta ?? Delta()).toJson()},
            ),
          );
        }
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.todo_list', l10n.todoList, child);
    }
    return child;
  },
);

final ToolbarItem copyToolbarItem = ToolbarItem(
  id: 'editor.copy',
  group: 10,
  isActive: (editorState) {
    final selection = editorState.selection;
    return selection != null && !selection.isCollapsed;
  },
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final canCopy = selection != null && !selection.isCollapsed;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.content_copy, size: 18, color: canCopy ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canCopy ? () => copyCommand.handler(editorState) : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.copy', l10n.copy, child);
    }
    return child;
  },
);

final ToolbarItem cutToolbarItem = ToolbarItem(
  id: 'editor.cut',
  group: 10,
  isActive: (editorState) {
    final selection = editorState.selection;
    return selection != null && !selection.isCollapsed;
  },
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final canCut = selection != null && !selection.isCollapsed;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.content_cut, size: 18, color: canCut ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canCut ? () => cutCommand.handler(editorState) : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.cut', l10n.cut, child);
    }
    return child;
  },
);

final ToolbarItem pasteToolbarItem = ToolbarItem(
  id: 'editor.paste',
  group: 10,
  isActive: (editorState) => editorState.selection != null,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final canPaste = editorState.selection != null;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.content_paste, size: 18, color: canPaste ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canPaste ? () => pasteCommand.handler(editorState) : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.paste', l10n.paste, child);
    }
    return child;
  },
);

final ToolbarItem undoToolbarItem = ToolbarItem(
  id: 'editor.undo',
  group: 10,
  isActive: (_) => true,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final canUndo = editorState.undoManager.undoStack.isNonEmpty;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.undo, size: 18, color: canUndo ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canUndo ? () => editorState.undoManager.undo() : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.undo', l10n.undo, child);
    }
    return child;
  },
);

final ToolbarItem redoToolbarItem = ToolbarItem(
  id: 'editor.redo',
  group: 10,
  isActive: (_) => true,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final canRedo = editorState.undoManager.redoStack.isNonEmpty;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.redo, size: 18, color: canRedo ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canRedo ? () => editorState.undoManager.redo() : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.redo', l10n.redo, child);
    }
    return child;
  },
);

final ToolbarItem tableToolbarItem = ToolbarItem(
  id: 'editor.table',
  group: 20,
  isActive: (_) => false,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.table_chart_outlined, size: 18, color: iconColor),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () async {
        final selection = editorState.selection;
        if (selection == null || !selection.isCollapsed) return;
        final currentNode = editorState.getNodeAtPath(selection.end.path);
        if (currentNode == null) return;

        final tableNode = TableNode.fromList([
          ['', ''],
          ['', ''],
        ]);

        final transaction = editorState.transaction;
        final delta = currentNode.delta;
        if (delta != null && delta.isEmpty) {
          transaction
            ..insertNode(selection.end.path, tableNode.node)
            ..deleteNode(currentNode);
          transaction.afterSelection = Selection.collapsed(Position(path: selection.end.path + [0, 0]));
        } else {
          transaction.insertNode(selection.end.path.next, tableNode.node);
          transaction.afterSelection = Selection.collapsed(Position(path: selection.end.path.next + [0, 0]));
        }
        await editorState.apply(transaction);
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.table', l10n.table, child);
    }
    return child;
  },
);

typedef ImageAssetBuilder = ({String destPath, String insertUrl}) Function(String src);

ToolbarItem buildImageToolbarItem({required ImageAssetBuilder buildAsset}) => ToolbarItem(
  id: 'editor.image',
  group: 3,
  isActive: (_) => false,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.image_outlined, size: 18, color: iconColor),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () async {
        final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
        if (result == null || result.files.single.path == null) return;
        final src = result.files.single.path!;
        final (:destPath, :insertUrl) = buildAsset(src);
        handleInsertImage(editorState: editorState, src: src, destPath: destPath, relativeUrl: insertUrl);
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.image', 'Image', child);
    }
    return child;
  },
);

/// Insert an image node into [editorState].
///
/// - If [src] is a network URL, insert it as-is (no asset copy, no sync).
/// - Otherwise, copy [src] to [destPath] first, then insert [relativeUrl]
///   into the document so the image renders immediately.
///
/// All three strings are expected to be pre-assembled by the caller.
void handleInsertImage({
  required EditorState editorState,
  required String src,
  required String destPath,
  required String relativeUrl,
}) {
  Future.microtask(() async {
    if (isRemoteUrl(src)) {
      await editorState.insertImageNode(src);
      return;
    }

    try {
      final destDir = Directory(destPath).parent;
      if (!destDir.existsSync()) destDir.createSync(recursive: true);
      File(src).copySync(destPath);
    } catch (e) {
      AppLogger.e('Editor', "[handleInsertImage] copy asset failed: $e");
      return;
    }

    await editorState.insertImageNode(relativeUrl);
  });
}
