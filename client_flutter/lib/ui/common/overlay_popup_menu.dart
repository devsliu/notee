import 'package:flutter/material.dart';

const double _kMenuScreenPadding = 8.0;

/// Show a non-modal popup overlay. Positioning algorithm is identical to
/// Flutter's native [PopupMenuButton] (see `_PopupMenuRouteLayout`).
/// Taps outside dismiss AND continue propagating to widgets below
/// (translucent behavior). Returns the [OverlayEntry] so caller can remove
/// it explicitly.
OverlayEntry showOverlayPopup({
  required BuildContext context,
  required Offset position,
  required List<OverlayPopupMenuItem> items,
  Size anchorSize = const Size(0, 0),
  Color? highlightColor,
  Color? backgroundColor,
  TextStyle? labelStyle,
  double minWidth = 140,
  VoidCallback? onDismiss,
}) {
  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  // Build RelativeRect exactly like PopupMenuButton does.
  final relativeRect = RelativeRect.fromRect(
    Rect.fromPoints(position, position + Offset(anchorSize.width, anchorSize.height)),
    Offset.zero & overlayBox.size,
  );

  late final OverlayEntry entry;

  Widget buildMenu() {
    return ConstrainedBox(
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
    );
  }

  entry = OverlayEntry(
    builder: (_) {
      return Stack(
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
          CustomSingleChildLayout(
            delegate: _PopupMenuRouteLayout(position: relativeRect),
            child: buildMenu(),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return entry;
}

// Positioning of the menu on the screen — cloned from Flutter's
// _PopupMenuRouteLayout (popup_menu.dart).
class _PopupMenuRouteLayout extends SingleChildLayoutDelegate {
  _PopupMenuRouteLayout({required this.position});

  // Rectangle of underlying button, relative to the overlay's dimensions.
  final RelativeRect position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The menu can be at most the size of the overlay minus 8.0 pixels in each
    // direction.
    return BoxConstraints.loose(constraints.biggest).deflate(const EdgeInsets.all(_kMenuScreenPadding));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Horizontal algorithm: grow to the side with more room (identical to
    // Flutter's _PopupMenuRouteLayout).
    double x;
    if (position.left > position.right) {
      // Menu button is closer to the right edge, so grow to the left, aligned to the right edge.
      x = size.width - position.right - childSize.width;
    } else if (position.left < position.right) {
      // Menu button is closer to the left edge, so grow to the right, aligned to the left edge.
      x = position.left;
    } else {
      x = position.left;
    }

    // Vertical: prefer below anchor, flip above when below overflows and
    // above has enough space (this is the extension beyond the system
    // PopupMenuButton, which always places below).
    final anchorRect = position.toRect(Offset.zero & size);
    double y = anchorRect.bottom;
    if (y + childSize.height > size.height - _kMenuScreenPadding &&
        anchorRect.top - childSize.height >= _kMenuScreenPadding) {
      y = anchorRect.top - childSize.height;
    }

    final wantedPosition = Offset(x, y);
    final screen = Offset.zero & size;
    return _fitInsideScreen(screen, childSize, wantedPosition);
  }

  Offset _fitInsideScreen(Rect screen, Size childSize, Offset wantedPosition) {
    double x = wantedPosition.dx;
    double y = wantedPosition.dy;
    // Avoid going outside an area defined as the rectangle 8.0 pixels from the
    // edge of the screen in every direction.
    if (x < screen.left + _kMenuScreenPadding) {
      x = screen.left + _kMenuScreenPadding;
    } else if (x + childSize.width > screen.right - _kMenuScreenPadding) {
      x = screen.right - childSize.width - _kMenuScreenPadding;
    }
    if (y < screen.top + _kMenuScreenPadding) {
      y = _kMenuScreenPadding;
    } else if (y + childSize.height > screen.bottom - _kMenuScreenPadding) {
      y = screen.bottom - childSize.height - _kMenuScreenPadding;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _PopupMenuRouteLayout oldDelegate) {
    return position != oldDelegate.position;
  }
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
    // Compute button rect in overlay coordinates, shifted down like
    // PopupMenuPosition.under does in PopupMenuButton.
    final buttonTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final anchor = buttonTopLeft + Offset(widget.offset.dx, renderBox.size.height + widget.offset.dy);

    _entry = showOverlayPopup(
      context: context,
      position: anchor,
      anchorSize: renderBox.size,
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
