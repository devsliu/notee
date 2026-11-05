import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';

class RecordOutlinePanel extends StatefulWidget {
  final EditorState editorState;
  final EditorScrollController? editorScrollController;
  final VoidCallback onClose;

  const RecordOutlinePanel({super.key, required this.editorState, this.editorScrollController, required this.onClose});

  @override
  State<RecordOutlinePanel> createState() => _RecordOutlinePanelState();
}

class _HeadingEntry {
  final String text;
  final int level;
  final Path path;

  const _HeadingEntry(this.text, this.level, this.path);
}

class _RecordOutlinePanelState extends State<RecordOutlinePanel> {
  StreamSubscription<EditorTransactionValue>? _subscription;
  Path? _anchorPath;

  /// When non-null, visible-range listener is suppressed until this timer fires.
  Timer? _scrollSuppressTimer;

  @override
  void initState() {
    super.initState();
    _subscription = widget.editorState.transactionStream.listen((_) {
      if (mounted) setState(() {});
    });
    widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    widget.editorScrollController?.visibleRangeNotifier.addListener(_onVisibleRangeChanged);
  }

  void _onSelectionChanged() {
    _anchorPath = widget.editorState.selection?.start.path;
    // Selection updated from a programmatic jump — suppress scroll listener
    // for 500ms so it doesn't overwrite the precise anchor with [firstVisible].
    _scrollSuppressTimer?.cancel();
    _scrollSuppressTimer = Timer(const Duration(milliseconds: 500), () {
      _scrollSuppressTimer = null;
      _anchorPath = null;
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  void _onVisibleRangeChanged() {
    if (_scrollSuppressTimer != null) return;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RecordOutlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.editorState, widget.editorState)) {
      _subscription?.cancel();
      oldWidget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
      _anchorPath = null;
      _subscription = widget.editorState.transactionStream.listen((_) {
        if (mounted) setState(() {});
      });
      widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
    if (!identical(oldWidget.editorScrollController, widget.editorScrollController)) {
      oldWidget.editorScrollController?.visibleRangeNotifier.removeListener(_onVisibleRangeChanged);
      widget.editorScrollController?.visibleRangeNotifier.addListener(_onVisibleRangeChanged);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollSuppressTimer?.cancel();
    widget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorScrollController?.visibleRangeNotifier.removeListener(_onVisibleRangeChanged);
    super.dispose();
  }

  List<_HeadingEntry> _collectHeadings() {
    final entries = <_HeadingEntry>[];
    void visit(Node node) {
      if (node.type == HeadingBlockKeys.type) {
        final text = node.delta?.toPlainText().trim() ?? '';
        if (text.isNotEmpty) {
          entries.add(_HeadingEntry(text, node.attributes[HeadingBlockKeys.level] as int? ?? 1, node.path));
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(widget.editorState.document.root);
    return entries;
  }

  void _jumpTo(Path path) {
    widget.editorState.updateSelectionWithReason(Selection.collapsed(Position(path: path, offset: 0)));
    widget.editorState.scrollService?.jumpTo(path.first);
  }

  int _comparePath(Path a, Path b) {
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  /// Selection-derived path takes priority (precise cursor position).
  /// Falls back to visible-range first block otherwise.
  int _activeHeadingIndex(List<_HeadingEntry> headings) {
    final Path anchor;
    if (_anchorPath != null) {
      anchor = _anchorPath!;
    } else {
      final controller = widget.editorScrollController;
      if (controller == null) return -1;
      final (first, _) = controller.visibleRangeNotifier.value;
      if (first < 0) return -1;
      anchor = [first];
    }
    var active = -1;
    for (var i = 0; i < headings.length; i++) {
      if (_comparePath(headings[i].path, anchor) <= 0) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  TextStyle? _levelStyle(ThemeData theme, int level) {
    final base = theme.textTheme.bodyMedium;
    return switch (level) {
      1 => base?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      2 => base?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      3 => base?.copyWith(fontSize: 14),
      _ => base?.copyWith(fontSize: 13),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headings = _collectHeadings();
    final activeIndex = _activeHeadingIndex(headings);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.outline, style: theme.textTheme.titleSmall)),
            IconButton(
              onPressed: widget.onClose,
              icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 2),
          ],
        ),
        Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
        Flexible(
          child: headings.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.noHeadings,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: headings.length,
                  itemBuilder: (context, index) {
                    final h = headings[index];
                    final isActive = index == activeIndex;
                    return Material(
                      color: isActive ? theme.colorScheme.primary.withAlpha(20) : Colors.transparent,
                      child: InkWell(
                        onTap: () => _jumpTo(h.path),
                        child: Container(
                          padding: EdgeInsets.only(left: 12.0 + (h.level - 1) * 8, right: 8, top: 6, bottom: 6),
                          child: Text(
                            h.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _levelStyle(
                              theme,
                              h.level,
                            )?.copyWith(color: isActive ? theme.colorScheme.primary : null),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
