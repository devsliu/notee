import 'dart:async';

import 'package:flutter/material.dart';

const double _kMenuScreenPadding = 8.0;

/// Show a popup overlay. Positioning algorithm matches Flutter's native
/// [PopupMenuButton]. [modal] = true → blocks all events below until dismissed
/// (tap outside or tap an item). Returns a [Future] that resolves to the
/// tapped item's value, or null if dismissed by outside tap.
Future<T?> showPopup<T>({
  required BuildContext context,
  required Offset position,
  required List<PopupItem<T>> items,
  Widget? title,
  Size anchorSize = const Size(0, 0),
  bool modal = false,
  Color? highlightColor,
  Color? backgroundColor,
  TextStyle? labelStyle,
  double minWidth = 140,
  double maxWidth = double.infinity,
}) {
  final completer = Completer<T?>();
  late final OverlayEntry entry;
  bool isShowning = true;

  void dismiss([T? result]) {
    if (!completer.isCompleted) completer.complete(result);
    if (isShowning) {
      entry.remove();
    }
    isShowning = false;
  }

  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final relativeRect = RelativeRect.fromRect(
    Rect.fromPoints(position, position + Offset(anchorSize.width, anchorSize.height)),
    Offset.zero & overlayBox.size,
  );

  entry = OverlayEntry(
    builder: (_) {
      return Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => dismiss(null),
              behavior: modal ? HitTestBehavior.opaque : HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          CustomSingleChildLayout(
            delegate: _PopupMenuLayout(position: relativeRect),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
              child: _MenuCard<T>(
                title: title,
                items: items,
                highlightColor: highlightColor,
                backgroundColor: backgroundColor,
                labelStyle: labelStyle,
                onItemTap: dismiss,
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

// Positioning of the menu on the screen — cloned from Flutter's
// _PopupMenuRouteLayout (popup_menu.dart).
class _PopupMenuLayout extends SingleChildLayoutDelegate {
  _PopupMenuLayout({required this.position});

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
  bool shouldRelayout(covariant _PopupMenuLayout oldDelegate) {
    return position != oldDelegate.position;
  }
}

/// A menu row item consumed by [PopupMenuControl].
class PopupItem<T> {
  const PopupItem({
    required this.icon,
    required this.label,
    this.value,
    this.isHighlight = false,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final T? value;
  final bool isHighlight;
  final VoidCallback? onTap;
}

class PopupMenuControl<T> extends StatefulWidget {
  const PopupMenuControl({
    super.key,
    this.items,
    this.itemsBuilder,
    required this.child,
    this.title,
    this.highlightColor,
    this.backgroundColor,
    this.labelStyle,
    this.offset = const Offset(0, 2),
    this.minWidth = 140,
  }) : assert(items != null || itemsBuilder != null);

  final List<PopupItem<T>>? items;
  final List<PopupItem<T>> Function()? itemsBuilder;
  final Widget child;
  final Widget? title;
  final Color? highlightColor;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final Offset offset;
  final double minWidth;

  @override
  State<PopupMenuControl<T>> createState() => _PopupMenuControlState<T>();
}

class _PopupMenuControlState<T> extends State<PopupMenuControl<T>> {
  Future<T?>? _future;
  bool _open = false;

  void _openMenu() {
    if (_open) return;
    _open = true;
    final items = widget.items ?? widget.itemsBuilder?.call() ?? const [];
    final renderBox = context.findRenderObject() as RenderBox;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final position = buttonTopLeft + widget.offset;

    _future = showPopup<T>(
      context: context,
      position: position,
      anchorSize: renderBox.size,
      items: items,
      title: widget.title,
      highlightColor: widget.highlightColor,
      backgroundColor: widget.backgroundColor,
      labelStyle: widget.labelStyle,
      minWidth: widget.minWidth,
    );
    _future!.whenComplete(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMenu,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

class _MenuCard<T> extends StatelessWidget {
  const _MenuCard({
    required this.items,
    this.title,
    required this.highlightColor,
    required this.backgroundColor,
    required this.labelStyle,
    required this.onItemTap,
  });

  final List<PopupItem<T>> items;
  final Widget? title;
  final Color? highlightColor;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final ValueChanged<T?> onItemTap;

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
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DefaultTextStyle(
                  style: theme.textTheme.labelLarge ?? const TextStyle(),
                  child: title!,
                ),
              ),
              Divider(height: 1, thickness: 1, color: theme.dividerColor.withAlpha(80)),
            ],
            for (final item in items)
              _MenuItem<T>(
                item: item,
                highlightColor: highlightColor,
                labelStyle: labelStyle,
                onItemTap: onItemTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem<T> extends StatelessWidget {
  const _MenuItem({
    required this.item,
    required this.highlightColor,
    required this.labelStyle,
    required this.onItemTap,
  });

  final PopupItem<T> item;
  final Color? highlightColor;
  final TextStyle? labelStyle;
  final ValueChanged<T?> onItemTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        item.onTap?.call();
        onItemTap(item.value);
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
