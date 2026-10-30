import 'package:flutter/material.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/ui/common/popup_menu.dart';

import '../../config/language_manager.dart';

class DesktopTabBar extends StatefulWidget {
  final List<dynamic> tabs;
  final int currentIndex;
  final Function(int) onSelectTab;
  final Function(int) onCloseTab;
  final Function(int)? onCloseOtherTabs;
  final Function()? onCloseAllTabs;
  final Function(int)? onCloseTabsToRight;
  final Function(int)? onCloseTabsToLeft;

  const DesktopTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onCloseTab,
    this.onCloseOtherTabs,
    this.onCloseAllTabs,
    this.onCloseTabsToRight,
    this.onCloseTabsToLeft,
  });

  static final minTabWidth = 70.0;
  static final maxTabWidth = 180.0;

  @override
  State<DesktopTabBar> createState() => _DesktopTabBarState();
}

class _DesktopTabBarState extends State<DesktopTabBar> {
  final _scrollController = ScrollController();
  final Map<dynamic, GlobalKey> _tabKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant DesktopTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToSelected();
      });
    }
  }

  /// Keep a persistent GlobalKey per tab so state survives rebuilds and the
  /// parent can look up a tab's build context for scroll-into-view.
  void _syncKeys() {
    for (final tab in widget.tabs) {
      _tabKeys.putIfAbsent(tab, GlobalKey.new);
    }
    _tabKeys.removeWhere((tab, _) => !widget.tabs.contains(tab));
  }

  void _scrollToSelected() {
    final idx = widget.currentIndex;
    if (idx < 0 || idx >= widget.tabs.length) return;
    final key = _tabKeys[widget.tabs[idx]];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), curve: Curves.ease, alignment: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    var tabHeight = 32.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        tabHeight = constraints.minHeight;
        return _buildTabBar(context, tabHeight);
      },
    );
  }

  Widget _buildTabBar(BuildContext context, double tabHeight) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 0.8,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.tabs.length, (i) {
          final tab = widget.tabs[i];
          final selected = i == widget.currentIndex;
          return _TabItem(
            key: _tabKeys[tab],
            title: tab.toString(),
            selected: selected,
            onTap: () => widget.onSelectTab(i),
            onClose: () => widget.onCloseTab(i),
            height: selected ? tabHeight : tabHeight - 1,
            index: i,
            totalCount: widget.tabs.length,
            onCloseOtherTabs: widget.onCloseOtherTabs,
            onCloseAllTabs: widget.onCloseAllTabs,
            onCloseTabsToRight: widget.onCloseTabsToRight,
            onCloseTabsToLeft: widget.onCloseTabsToLeft,
          );
        }),
      ),
    );
  }
}

// Obsidian-style TabItem, supports hover color change and x button
class _TabItem extends StatefulWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final double height;
  final int index;
  final int totalCount;
  final Function(int)? onCloseOtherTabs;
  final Function()? onCloseAllTabs;
  final Function(int)? onCloseTabsToRight;
  final Function(int)? onCloseTabsToLeft;

  const _TabItem({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.onClose,
    required this.height,
    required this.index,
    required this.totalCount,
    this.onCloseOtherTabs,
    this.onCloseAllTabs,
    this.onCloseTabsToRight,
    this.onCloseTabsToLeft,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  Future<void> _showContextMenu(TapUpDetails details) async {
    final items = <PopupItem<int>>[];

    // Close other tabs
    if (widget.onCloseOtherTabs != null && widget.totalCount > 1) {
      items.add(PopupItem.simple(title: l10n.closeOtherTabs, value: 0));
    }

    // Close all tabs
    if (widget.onCloseAllTabs != null && widget.totalCount > 0) {
      items.add(PopupItem.simple(title: l10n.closeAllTabs, value: 1));
    }

    // Close tabs to the right
    if (widget.onCloseTabsToRight != null && widget.index < widget.totalCount - 1) {
      items.add(PopupItem.simple(title: l10n.closeTabsToRight, value: 2));
    }

    // Close tabs to the left
    if (widget.onCloseTabsToLeft != null && widget.index > 0) {
      items.add(PopupItem.simple(title: l10n.closeTabsToLeft, value: 3));
    }

    if (items.isEmpty) return;

    final value = await showPopup<int>(context: context, position: details.globalPosition, items: items, modal: true);

    switch (value) {
      case 0:
        widget.onCloseOtherTabs?.call(widget.index);
        break;
      case 1:
        widget.onCloseAllTabs?.call();
        break;
      case 2:
        widget.onCloseTabsToRight?.call(widget.index);
        break;
      case 3:
        widget.onCloseTabsToLeft?.call(widget.index);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final baseColor = selected
        ? theme.colorScheme.surface
        : Color.lerp(theme.appBarBackgroundColor, theme.colorScheme.onSurface, 0.2);

    // Improved hover color calculation, ensure consistent effect across all themes
    final hoverColor = selected
        ? baseColor
        : theme.brightness == Brightness.dark
        ? Colors.white.withAlpha(80) // Dark theme uses white transparent
        : Colors.black.withAlpha(80); // Light theme uses black transparent

    final textColor = selected
        ? theme.colorScheme.onSurface
        : theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final showCloseButton = selected || _hover;
    final borderColor = selected ? theme.colorScheme.outline : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(details),
        child: Container(
          decoration: BoxDecoration(
            color: _hover ? hoverColor : baseColor,
            border: Border(
              left: BorderSide(width: 1, color: borderColor),
              top: BorderSide(width: 1, color: borderColor),
              right: BorderSide(width: 1, color: borderColor),
              bottom: BorderSide.none,
            ),
          ),
          constraints: BoxConstraints(minWidth: DesktopTabBar.minTabWidth, maxWidth: DesktopTabBar.maxTabWidth),
          height: widget.height,
          padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(color: textColor),
                ),
              ),
              // Always show close button position, just make transparent when not selected/not hovered
              Opacity(
                opacity: showCloseButton ? 1.0 : 0.0,
                child: IconButton(
                  icon: Icon(Icons.close, size: 16),
                  padding: EdgeInsets.all(3),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: showCloseButton ? l10n.close : null,
                  color: textColor,
                  onPressed: showCloseButton ? widget.onClose : null,
                  mouseCursor: showCloseButton ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  highlightColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
