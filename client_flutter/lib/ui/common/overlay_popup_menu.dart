import 'package:flutter/material.dart';

/// Show a non-modal popup overlay at [position]. Taps outside dismiss
/// AND continue propagating to widgets below (translucent behavior).
/// Returns the [OverlayEntry] so caller can remove it explicitly.
OverlayEntry showOverlayPopup({
  required BuildContext context,
  required Offset position,
  required List<OverlayPopupMenuItem> items,
  Color? highlightColor,
  Color? backgroundColor,
  TextStyle? labelStyle,
  double minWidth = 140,
  VoidCallback? onDismiss,
}) {
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) {
              onDismiss?.call();
              entry.remove();
            },
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: _MenuCard(
              items: items,
              highlightColor: highlightColor,
              backgroundColor: backgroundColor,
              labelStyle: labelStyle,
              onClose: () {
                onDismiss?.call();
                entry.remove();
              },
            ),
          ),
        ),
      ],
    ),
  );
  Overlay.of(context).insert(entry);
  return entry;
}

/// A menu row item consumed by [OverlayPopupMenu].
class OverlayPopupMenuItem {
  const OverlayPopupMenuItem({
    required this.icon,
    required this.label,
    this.isHighlight = false,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool isHighlight;
  final VoidCallback? onTap;
}

class OverlayPopupMenu extends StatefulWidget {
  const OverlayPopupMenu({
    super.key,
    this.items,
    this.itemsBuilder,
    required this.child,
    this.highlightColor,
    this.backgroundColor,
    this.labelStyle,
    this.offset = const Offset(0, 2),
    this.minWidth = 140,
  }) : assert(items != null || itemsBuilder != null);

  final List<OverlayPopupMenuItem>? items;
  final List<OverlayPopupMenuItem> Function()? itemsBuilder;
  final Widget child;
  final Color? highlightColor;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final Offset offset;
  final double minWidth;

  @override
  State<OverlayPopupMenu> createState() => _OverlayPopupMenuState();
}

class _OverlayPopupMenuState extends State<OverlayPopupMenu> {
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    final items = widget.items ?? widget.itemsBuilder?.call() ?? const [];
    final renderBox = context.findRenderObject() as RenderBox;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchor = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final position = anchor + Offset(widget.offset.dx, renderBox.size.height + widget.offset.dy);

    _entry = showOverlayPopup(
      context: context,
      position: position,
      items: items,
      highlightColor: widget.highlightColor,
      backgroundColor: widget.backgroundColor,
      labelStyle: widget.labelStyle,
      minWidth: widget.minWidth,
      onDismiss: () => _entry = null,
    );
  }

  void _close() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.items,
    required this.highlightColor,
    required this.backgroundColor,
    required this.labelStyle,
    required this.onClose,
  });

  final List<OverlayPopupMenuItem> items;
  final Color? highlightColor;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;
    return Material(
      color: bg,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: theme.dividerColor.withAlpha(200), strokeAlign: BorderSide.strokeAlignCenter),
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              _MenuItem(
                item: item,
                highlightColor: highlightColor,
                labelStyle: labelStyle,
                onClose: onClose,
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.item,
    required this.highlightColor,
    required this.labelStyle,
    required this.onClose,
  });

  final OverlayPopupMenuItem item;
  final Color? highlightColor;
  final TextStyle? labelStyle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        item.onTap?.call();
        onClose();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item.icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                item.label,
                style: labelStyle?.copyWith(
                      color: item.isHighlight ? highlightColor : labelStyle?.color,
                    ) ??
                    TextStyle(color: item.isHighlight ? highlightColor : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
