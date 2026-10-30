import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'group_layout.dart';

const double _kMenuScreenPadding = 8.0;

/// Controller for a popup shown by [showPopup]. Lets the caller dismiss the
/// menu or rebuild its items (e.g. after closing a tab, refresh the list
/// without closing & re-opening the popup).
class PopupMenuController<T> {
  void Function([T? result])? _dismiss;
  void Function(List<PopupItem<T>>)? _rebuild;

  /// Close the popup, completing the future with [result].
  void dismiss([T? result]) => _dismiss?.call(result);

  /// Replace the menu items with [items] and repaint.
  void rebuild(List<PopupItem<T>> items) => _rebuild?.call(items);
}

/// Show a popup overlay. Positioning algorithm matches Flutter's native
/// [PopupMenuButton]. [modal] = true → blocks all events below until dismissed
/// (tap outside or tap an item). Returns a [Future] that resolves to the
/// tapped item's value, or null if dismissed by outside tap.
///
/// Pass [controller] to dismiss or rebuild the popup from outside (e.g. a
/// close button inside an item).
Future<T?> showPopup<T>({
  required BuildContext context,
  required Offset position,
  required List<PopupItem<T>> items,
  PopupMenuController<T>? controller,
  Widget? title,
  Size anchorSize = const Size(0, 0),
  bool modal = false,
  Color? backgroundColor,
  double minWidth = 140,
  double maxWidth = double.infinity,
  int columns = 1,
}) {
  assert(columns >= 1);
  final completer = Completer<T?>();
  late final OverlayEntry entry;
  bool isShowning = true;

  List<PopupItem<T>> currentItems = items;

  void dismiss([T? result]) {
    if (!completer.isCompleted) completer.complete(result);
    if (isShowning) {
      entry.remove();
    }
    isShowning = false;
  }

  void rebuild(List<PopupItem<T>> items) {
    currentItems = items;
    entry.markNeedsBuild();
  }

  controller?._dismiss = dismiss;
  controller?._rebuild = rebuild;

  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final overlaySize = overlayBox.size;
  final relativeRect = RelativeRect.fromRect(
    Rect.fromPoints(position, position + Offset(anchorSize.width, anchorSize.height)),
    Offset.zero & overlaySize,
  );

  entry = OverlayEntry(
    builder: (_) {
      return CustomMultiChildLayout(
        delegate: _FullMenuLayoutDelegate(
          position: relativeRect,
          columns: columns,
          minWidth: minWidth,
          maxWidth: maxWidth,
          itemCount: currentItems.length,
          overlaySize: overlaySize,
        ),
        children: [
          // 全屏透明拦截层
          LayoutId(
            id: _FullMenuLayoutDelegate._kHitLayer,
            child: Listener(
              onPointerDown: (_) => dismiss(null),
              behavior: modal ? HitTestBehavior.opaque : HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          // 菜单整体：内层 CustomMultiChildLayout 自己处理 Material 背景 + 列布局
          LayoutId(
            id: _FullMenuLayoutDelegate._kMenuContent,
            child: _MenuContent<T>(
              columns: columns,
              minWidth: minWidth,
              maxWidth: maxWidth,
              title: title,
              items: currentItems,
              onItemTap: dismiss,
              backgroundColor: backgroundColor,
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

// 外层全屏定位：hit layer + menu content（Material 包着内层布局）
class _FullMenuLayoutDelegate extends MultiChildLayoutDelegate {
  _FullMenuLayoutDelegate({
    required this.position,
    required this.columns,
    required this.minWidth,
    required this.maxWidth,
    required this.itemCount,
    required this.overlaySize,
  });

  final RelativeRect position;
  final int columns;
  final double minWidth;
  final double maxWidth;
  final int itemCount;
  final Size overlaySize;

  static const int _kHitLayer = 0;
  static const int _kMenuContent = 1;
  static const double _kMenuScreenPadding = 8.0;

  @override
  void performLayout(Size size) {
    // 1. hit layer
    if (hasChild(_kHitLayer)) {
      layoutChild(_kHitLayer, BoxConstraints.tight(overlaySize));
      positionChild(_kHitLayer, Offset.zero);
    }

    // 2. menu content：loose [0, overlaySize.width - 2*padding] 让 Material shrink-wrap
    if (hasChild(_kMenuContent)) {
      final availWidth = overlaySize.width - 2 * _kMenuScreenPadding;
      final maxInnerWidth = maxWidth == double.infinity ? availWidth : math.min(maxWidth * columns, availWidth);
      final c = BoxConstraints(
        minWidth: 0,
        maxWidth: maxInnerWidth,
        minHeight: 0,
        maxHeight: overlaySize.height,
      );
      final menuSize = layoutChild(_kMenuContent, c);
      final offset = _computeMenuOffset(overlaySize, menuSize);
      positionChild(_kMenuContent, offset);
    }
  }

  Offset _computeMenuOffset(Size screenSize, Size childSize) {
    double x;
    if (position.left > position.right) {
      x = screenSize.width - position.right - childSize.width;
    } else if (position.left < position.right) {
      x = position.left;
    } else {
      x = position.left;
    }
    final anchorRect = position.toRect(Offset.zero & screenSize);
    double y = anchorRect.bottom;
    final below = y + childSize.height > screenSize.height - _kMenuScreenPadding;
    final aboveOk = anchorRect.top - childSize.height >= _kMenuScreenPadding;
    if (below && aboveOk) {
      y = anchorRect.top - childSize.height;
    }
    final originalY = y;
    // 先算上下限，避免 childSize ≥ screenSize 时 upper < lower 导致 clamp 炸
    final double xLower = _kMenuScreenPadding;
    final double xUpper = math.max(xLower, screenSize.width - childSize.width - _kMenuScreenPadding);
    final double yLower = _kMenuScreenPadding;
    final double yUpper = math.max(yLower, screenSize.height - childSize.height - _kMenuScreenPadding);
    x = x.clamp(xLower, xUpper);
    y = y.clamp(yLower, yUpper);
    debugPrint('[MenuOffset] anchorTop=${anchorRect.top.toStringAsFixed(0)} anchorBot=${anchorRect.bottom.toStringAsFixed(0)} '
        'menuH=${childSize.height.toStringAsFixed(0)} menuW=${childSize.width.toStringAsFixed(0)} '
        'screenH=${screenSize.height.toStringAsFixed(0)} screenW=${screenSize.width.toStringAsFixed(0)} '
        'below=$below aboveOk=$aboveOk origY=${originalY.toStringAsFixed(0)} finalY=${y.toStringAsFixed(0)}');
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _FullMenuLayoutDelegate oldDelegate) {
    return position != oldDelegate.position ||
        columns != oldDelegate.columns ||
        minWidth != oldDelegate.minWidth ||
        maxWidth != oldDelegate.maxWidth ||
        itemCount != oldDelegate.itemCount ||
        overlaySize != oldDelegate.overlaySize;
  }
}

// 菜单整体：Material 包着 CustomMultiChildLayout（title/divider/items）
// Material 拿到外层约束 [0, maxWidth*columns]，shrink-wrap 内部尺寸 → 圆角裁剪生效
// delegate 手动算位置：title 跨全宽、items 行列排布、同行等高、等列宽
class _MenuContent<T> extends StatelessWidget {
  const _MenuContent({
    required this.columns,
    required this.minWidth,
    required this.maxWidth,
    required this.title,
    required this.items,
    required this.onItemTap,
    required this.backgroundColor,
  });

  final int columns;
  final double minWidth;
  final double maxWidth;
  final Widget? title;
  final List<PopupItem<T>> items;
  final ValueChanged<T?> onItemTap;
  final Color? backgroundColor;

  Widget _wrapItem(PopupItem<T> item) {
    // 外层 Material 已提供 ink splash 所需的 Material ancestor
    return InkWell(
      onTap: () {
        item.onTap?.call();
        onItemTap(item.value);
      },
      child: item.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(4);
    return Material(
      color: backgroundColor ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.dividerColor.withAlpha(200), width: 1),
      ),
      elevation: 4,
      clipBehavior: Clip.antiAlias, // 圆角裁剪 items
      child: GroupLayout(
        delegate: _MenuLayoutDelegate(
          columns: columns,
          minWidth: minWidth,
          maxWidth: maxWidth,
          itemCount: items.length,
          hasTitle: title != null,
        ),
        children: [
          if (title != null)
            LayoutId(
              id: _kTitleId,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DefaultTextStyle(
                  style: theme.textTheme.labelLarge ?? const TextStyle(),
                  child: title!,
                ),
              ),
            ),
          if (title != null)
            LayoutId(
              id: _kDividerId,
              child: Divider(height: 1, thickness: 1, color: theme.dividerColor.withAlpha(80)),
            ),
          for (var i = 0; i < items.length; i++)
            LayoutId(id: i, child: _wrapItem(items[i])),
        ],
      ),
    );
  }
}

const int _kTitleId = -1;
const int _kDividerId = -2;

// 菜单布局 delegate：title 跨全宽、items 等列宽网格、同行等高
class _MenuLayoutDelegate extends GroupLayoutDelegate {
  _MenuLayoutDelegate({
    required this.columns,
    required this.minWidth,
    required this.maxWidth,
    required this.itemCount,
    required this.hasTitle,
  });

  final int columns;
  final double minWidth;
  final double maxWidth;
  final int itemCount;
  final bool hasTitle;

  @override
  Size performLayout(BoxConstraints constraints, GroupLayoutChildren c) {
    final outerMaxW = constraints.maxWidth;
    final rowCount = (itemCount / columns).ceil();
    debugPrint('[MenuInner] START outerMaxW=$outerMaxW cols=$columns min=$minWidth max=$maxWidth items=$itemCount hasTitle=$hasTitle');

    // === Pass 1: 全部 loose 测量 ===
    double titleWidth = 0, titleHeight = 0;
    if (hasTitle && c.hasChild(_kTitleId)) {
      final ts = c.layoutChild(_kTitleId, BoxConstraints(
        minWidth: 0, maxWidth: outerMaxW,
        minHeight: 0, maxHeight: double.infinity,
      ));
      titleWidth = ts.width;
      titleHeight = ts.height;
      debugPrint('[MenuInner] title w=$titleWidth h=$titleHeight');
    }

    final itemHeights = <double>[];
    double maxItemWidth = 0;
    for (var i = 0; i < itemCount; i++) {
      final s = c.layoutChild(i, BoxConstraints(
        minWidth: 0, maxWidth: outerMaxW / columns,
        minHeight: 0, maxHeight: double.infinity,
      ));
      maxItemWidth = math.max(maxItemWidth, s.width);
      itemHeights.add(s.height);
    }
    debugPrint('[MenuInner] maxItemWidth=$maxItemWidth itemPass1ConstraintMax=${outerMaxW / columns}');

    // 列宽 = max(title 均摊, 最宽 item)，先撑满 minWidth，再限制 maxWidth（有限时）
    double colWidth = math.max(
      columns <= 1 ? titleWidth : titleWidth / columns,
      maxItemWidth,
    );
    debugPrint('[MenuInner] colWidth before clamp=$colWidth titlePerCol=${columns <= 1 ? titleWidth : titleWidth / columns}');
    colWidth = math.max(colWidth, minWidth);
    if (maxWidth != double.infinity) {
      colWidth = math.min(colWidth, maxWidth);
    }
    debugPrint('[MenuInner] colWidth after clamp=$colWidth');

    // 总宽 = max(列宽总和, title)，硬限制在 outerMaxW（外层给的最大宽度）内
    double totalWidth = columns <= 1 ? colWidth : colWidth * columns;
    debugPrint('[MenuInner] totalWidth before title merge=$totalWidth colWidth*cols=${colWidth * columns} titleWidth=$titleWidth');
    totalWidth = math.max(totalWidth, titleWidth);
    debugPrint('[MenuInner] totalWidth after title merge=$totalWidth');
    totalWidth = math.min(totalWidth, outerMaxW);
    debugPrint('[MenuInner] totalWidth after outerMaxW clamp=$totalWidth outerMaxW=$outerMaxW');
    colWidth = totalWidth / columns;

    // divider
    double dividerHeight = 0;
    if (hasTitle && c.hasChild(_kDividerId)) {
      dividerHeight = c.layoutChild(_kDividerId, BoxConstraints.tightFor(width: totalWidth)).height;
    }

    // 每行高度 = 该行最高 item
    final rowHeights = List<double>.filled(rowCount, 0);
    for (var r = 0; r < rowCount; r++) {
      double rh = 0;
      for (var col = 0; col < columns; col++) {
        final idx = r * columns + col;
        if (idx < itemHeights.length) rh = math.max(rh, itemHeights[idx]);
      }
      rowHeights[r] = rh;
    }

    // === Pass 2: item 最终宽高（填满整行，解决 InkWell 半按效果）===
    final double effectiveColWidth = colWidth;
    for (var r = 0; r < rowCount; r++) {
      for (var col = 0; col < columns; col++) {
        final idx = r * columns + col;
        if (idx < itemCount) {
          c.layoutChild(idx, BoxConstraints.tightFor(width: effectiveColWidth, height: rowHeights[r]));
        }
      }
    }

    // 自身尺寸
    double menuHeight = titleHeight + dividerHeight;
    for (final rh in rowHeights) {
      menuHeight += rh;
    }

    // 定位 children
    double curY = 0;
    if (hasTitle && c.hasChild(_kTitleId)) {
      c.positionChild(_kTitleId, Offset(0, curY));
      curY += titleHeight;
    }
    if (hasTitle && c.hasChild(_kDividerId)) {
      c.positionChild(_kDividerId, Offset(0, curY));
      curY += dividerHeight;
    }
    for (var r = 0; r < rowCount; r++) {
      for (var col = 0; col < columns; col++) {
        final idx = r * columns + col;
        if (idx < itemCount) c.positionChild(idx, Offset(col * colWidth, curY));
      }
      curY += rowHeights[r];
    }

    return Size(totalWidth, menuHeight);
  }

  @override
  bool shouldRelayout(covariant _MenuLayoutDelegate oldDelegate) {
    return columns != oldDelegate.columns ||
        minWidth != oldDelegate.minWidth ||
        maxWidth != oldDelegate.maxWidth ||
        itemCount != oldDelegate.itemCount ||
        hasTitle != oldDelegate.hasTitle;
  }
}

/// A menu row item consumed by [PopupMenuControl].
/// Only stores [child] — all layout details are owned by the caller or the
/// [simple] factory for the common icon + label case.
class PopupItem<T> {
  const PopupItem({required this.child, this.value, this.onTap});

  /// Shortcut factory: icon + title. For custom layouts (e.g. trailing
  /// buttons) pass a fully-built child directly to the main constructor.
  factory PopupItem.simple({Widget? icon, required String title, T? value, VoidCallback? onTap}) {
    return PopupItem.simple2(
      icon: icon,
      title: Text(title, overflow: TextOverflow.ellipsis),
      value: value,
      onTap: onTap,
    );
  }

  /// Like [simple], but the label is a [Widget] (e.g. a styled [Text]).
  factory PopupItem.simple2({Widget? icon, required Widget title, T? value, VoidCallback? onTap}) {
    return PopupItem(
      value: value,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 8)],
            Flexible(child: title),
          ],
        ),
      ),
    );
  }

  final Widget child;
  final T? value;
  final VoidCallback? onTap;
}

class PopupMenuControl<T> extends StatefulWidget {
  const PopupMenuControl({
    super.key,
    this.items,
    this.itemsBuilder,
    required this.child,
    this.title,
    this.onSelected,
    this.modal = false,
    this.backgroundColor,
    this.offset = const Offset(0, 2),
    this.minWidth = 140,
    this.maxWidth = double.infinity,
    this.columns = 1,
  }) : assert(items != null || itemsBuilder != null);

  final List<PopupItem<T>>? items;
  final List<PopupItem<T>> Function()? itemsBuilder;
  final Widget child;
  final Widget? title;
  final ValueChanged<T?>? onSelected;
  final bool modal;
  final Color? backgroundColor;
  final Offset offset;
  final double minWidth;
  final double maxWidth;
  final int columns;

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
      modal: widget.modal,
      backgroundColor: widget.backgroundColor,
      minWidth: widget.minWidth,
      maxWidth: widget.maxWidth,
      columns: widget.columns,
    );
    _future!
        .then((value) {
          widget.onSelected?.call(value);
        })
        .whenComplete(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _openMenu, behavior: HitTestBehavior.opaque, child: widget.child);
  }
}
