import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// In-document find & replace bar, embedded below the editor toolbar.
/// Works on desktop and mobile (unlike the overlay-based FindReplaceMenu).
class EditorFindReplaceBar extends StatefulWidget {
  final EditorState editorState;
  final VoidCallback onClose;

  /// Whether the replace row is expanded initially (Ctrl+H vs Ctrl+F).
  final bool initialShowReplace;

  const EditorFindReplaceBar({
    super.key,
    required this.editorState,
    required this.onClose,
    this.initialShowReplace = false,
  });

  @override
  State<EditorFindReplaceBar> createState() => _EditorFindReplaceBarState();
}

class _EditorFindReplaceBarState extends State<EditorFindReplaceBar> {
  late SearchServiceV3 _searchService = _createSearchService();
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _findFocusNode = FocusNode();

  late bool _showReplace = widget.initialShowReplace;
  String _message = '';

  SearchServiceV3 _createSearchService() {
    // jumpInterceptor returning false → let the service jump-scroll to the block
    return SearchServiceV3(editorState: widget.editorState, jumpInterceptor: (_) => false);
  }

  @override
  void initState() {
    super.initState();
    _findController.addListener(_runSearch);
    _searchService.matchWrappers.addListener(_onMatchesChanged);
    _searchService.currentSelectedIndex.addListener(_onMatchesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant EditorFindReplaceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Document reload replaces the EditorState instance — rebind the service
    if (!identical(oldWidget.editorState, widget.editorState)) {
      _searchService.matchWrappers.removeListener(_onMatchesChanged);
      _searchService.currentSelectedIndex.removeListener(_onMatchesChanged);
      _searchService.dispose();
      _searchService = _createSearchService();
      _searchService.matchWrappers.addListener(_onMatchesChanged);
      _searchService.currentSelectedIndex.addListener(_onMatchesChanged);
      _runSearch();
    }
  }

  @override
  void dispose() {
    _findController.removeListener(_runSearch);
    _searchService.matchWrappers.removeListener(_onMatchesChanged);
    _searchService.currentSelectedIndex.removeListener(_onMatchesChanged);
    _searchService.findAndHighlight('');
    _searchService.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  void _onMatchesChanged() {
    if (mounted) setState(() {});
  }

  void _runSearch() {
    final error = _searchService.findAndHighlight(_findController.text);
    final message = switch (error) {
      'Regex' => AppFlowyEditorL10n.current.regexError,
      'Empty' => '',
      _ => _searchService.matchWrappers.value.isEmpty ? AppFlowyEditorL10n.current.noFindResult : '',
    };
    if (message != _message) {
      _message = message;
    }
    if (mounted) setState(() {});
  }

  void _keepFindFocus() {
    // Editor may grab focus after selection changes — give it back to the find field
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _findFocusNode.requestFocus();
    });
  }

  void _navigate(bool moveUp) {
    _runSearch(); // refresh stale matches before navigating
    _searchService.navigateToMatch(moveUp: moveUp);
    _keepFindFocus();
  }

  void _replaceSelected() {
    _runSearch();
    _searchService.replaceSelectedWord(_replaceController.text);
    _keepFindFocus();
  }

  Widget cell(IconData icon, double cellWidth, Color iconColor, VoidCallback onTap, [String? tooltip]) {
    Widget w = SizedBox(
      width: cellWidth,
      height: cellWidth,
      child: InkResponse(
        onTap: onTap,
        radius: cellWidth / 2,
        child: Center(
          child: Icon(icon, size: cellWidth / 2.0, color: iconColor),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: w) : w;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _searchService.matchWrappers.value;
    final countText = _findController.text.isEmpty
        ? ''
        : matches.isEmpty
        ? _message
        : '${_searchService.selectedIndex + 1}/${matches.length}';

    final iconColor = theme.colorScheme.onSurface;
    const cellWidth = 40.0; // one icon cell

    // Custom fixed-size icon cell — no IconButton, so no internal min-tap-target/padding
    // constraints can break the alignment between the two rows.

    const emptyCell = SizedBox(width: cellWidth, height: cellWidth);

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                cell(
                  _showReplace ? Icons.expand_less : Icons.expand_more,
                  cellWidth,
                  iconColor,
                  () => setState(() => _showReplace = !_showReplace),
                ),
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                      border: Border.all(color: theme.colorScheme.outline.withAlpha(120), width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _findController,
                      focusNode: _findFocusNode,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: AppFlowyEditorL10n.current.find,
                        hintStyle: TextStyle(fontSize: 14, color: iconColor.withAlpha(120)),
                      ),
                      onSubmitted: (_) => _navigate(false),
                    ),
                  ),
                ),
                cell(
                  Icons.arrow_upward,
                  cellWidth,
                  iconColor,
                  () => _navigate(true),
                  AppFlowyEditorL10n.current.previousMatch,
                ),
                cell(
                  Icons.arrow_downward,
                  cellWidth,
                  iconColor,
                  () => _navigate(false),
                  AppFlowyEditorL10n.current.nextMatch,
                ),
                cell(Icons.close, cellWidth, iconColor, widget.onClose, AppFlowyEditorL10n.current.closeFind),
                // Count text sits outside the input row so the input's right edge stays fixed
                Container(
                  alignment: Alignment.center,
                  width: cellWidth * 1.5,
                  height: cellWidth,
                  child: countText.isNotEmpty
                      ? Text(countText, style: TextStyle(fontSize: 12, color: iconColor.withAlpha(150)))
                      : null,
                ),
              ],
            ),
            if (_showReplace)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  emptyCell,
                  Expanded(
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                        border: Border.all(color: theme.colorScheme.outline.withAlpha(120), width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _replaceController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: AppFlowyEditorL10n.current.replace,
                          hintStyle: TextStyle(fontSize: 14, color: iconColor.withAlpha(120)),
                        ),
                        onSubmitted: (_) => _replaceSelected(),
                      ),
                    ),
                  ),
                  cell(Icons.find_replace, cellWidth, iconColor, _replaceSelected, AppFlowyEditorL10n.current.replace),
                  cell(Icons.change_circle_outlined, cellWidth, iconColor, () {
                    _runSearch();
                    _searchService.replaceAllMatches(_replaceController.text);
                    _keepFindFocus();
                  }, AppFlowyEditorL10n.current.replaceAll),
                  // Placeholder matching the close button cell, so both input boxes share the same right edge
                  const SizedBox(width: cellWidth * 2.5, height: cellWidth),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
