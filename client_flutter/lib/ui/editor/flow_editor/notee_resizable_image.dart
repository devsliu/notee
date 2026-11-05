import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class NoteeResizableImage extends StatefulWidget {
  const NoteeResizableImage({
    super.key,
    required this.image,
    required this.editable,
    required this.onResize,
    required this.width,
    this.alignment = Alignment.center,
    this.height,
    this.onLongPressStart,
    this.onSecondaryTapUp,
    this.dragSensitivity = 1.0,
  });

  final Widget image;
  final double width;
  final double? height;
  final Alignment alignment;
  final bool editable;
  final void Function(double width) onResize;

  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(TapUpDetails)? onSecondaryTapUp;

  /// 拖动灵敏度倍率，center 对齐时传 2.0（两边同时收/放）
  final double dragSensitivity;

  @override
  State<NoteeResizableImage> createState() => _NoteeResizableImageState();
}

const _kMinWidth = 30.0;
const _kRevealDuration = Duration(seconds: 3);
const _kEdgeHitWidth = 5.0;
const _kEdgeVisualWidth = 4.0;
const _kEdgeVisualHeight = 80.0;

bool get _isTouchMode {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

class _NoteeResizableImageState extends State<NoteeResizableImage> {
  late double imageWidth;

  double initialOffset = 0;
  double moveDistance = 0;

  /// 桌面端：hover 图片 → 显示边缘视觉条（参照 ResizableImage.onFocus）
  bool _onFocus = false;

  /// 触摸端：tap 激活边缘显示 3 秒
  bool _touchRevealed = false;
  Timer? _touchRevealTimer;

  final GlobalKey _boxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    imageWidth = widget.width;
  }

  @override
  void didUpdateWidget(covariant NoteeResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (moveDistance == 0 && oldWidget.width != widget.width) {
      imageWidth = widget.width;
    }
  }

  @override
  void dispose() {
    _touchRevealTimer?.cancel();
    super.dispose();
  }

  void _revealTouchEdge() {
    _touchRevealTimer?.cancel();
    setState(() => _touchRevealed = true);
    _touchRevealTimer = Timer(_kRevealDuration, () {
      if (mounted && moveDistance == 0) setState(() => _touchRevealed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool dragging = moveDistance != 0;
    // MouseRegion 在 Align 外层，撑满整行宽度：
    // 拖动缩小时鼠标会跑出图片，根 MouseRegion 必须覆盖整行才能保持 resizeLeftRight 光标不闪
    return MouseRegion(
      cursor: dragging ? SystemMouseCursors.resizeLeftRight : MouseCursor.defer,
      onEnter: (_) {
        if (!_onFocus) setState(() => _onFocus = true);
      },
      onExit: (_) {
        if (_onFocus && !dragging) setState(() => _onFocus = false);
      },
      child: Align(
        alignment: widget.alignment,
        child: SizedBox(
          key: _boxKey,
          width: max(_kMinWidth, imageWidth - moveDistance),
          height: widget.height,
          child: Stack(
            children: [
              // 底层图片：tap / longPress / secondaryTapUp + 触摸端 drag (half-side)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onTap: widget.editable && _isTouchMode ? _revealTouchEdge : null,
                onLongPressStart: widget.onLongPressStart,
                onSecondaryTapUp: widget.onSecondaryTapUp,
                onHorizontalDragStart:
                    widget.editable && _isTouchMode && _touchRevealed ? _handleTouchDragStart : null,
                onHorizontalDragUpdate:
                    widget.editable && _isTouchMode && _touchRevealed ? _handleTouchDragUpdate : null,
                onHorizontalDragEnd:
                    widget.editable && _isTouchMode && _touchRevealed ? _handleTouchDragEnd : null,
                child: widget.image,
              ),
              // 桌面端左右边缘 zone（一个函数 + onUpdate 回调，方向在调用处硬编码）
              if (widget.editable && !_isTouchMode) ...[
                _buildDesktopEdge(left: 0, right: null, onUpdate: (d) => setState(() => moveDistance = d)),
                _buildDesktopEdge(left: null, right: 0, onUpdate: (d) => setState(() => moveDistance = -d)),
              ],
              // 触摸端纯视觉条
              if (widget.editable && _isTouchMode && _touchRevealed) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  width: _kEdgeHitWidth,
                  child: IgnorePointer(child: Center(child: _buildEdgeBar())),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: _kEdgeHitWidth,
                  child: IgnorePointer(child: Center(child: _buildEdgeBar())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // === 桌面端 edge zone ===

  Widget _buildDesktopEdge({
    required double? left,
    required double? right,
    required void Function(double distance) onUpdate,
  }) {
    return Positioned(
      top: 0,
      left: left,
      right: right,
      bottom: 0,
      width: _kEdgeHitWidth,
      child: GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (d) {
          initialOffset = d.globalPosition.dx;
          moveDistance = 0;
        },
        onHorizontalDragUpdate: (d) {
          final offset = (d.globalPosition.dx - initialOffset) * widget.dragSensitivity;
          onUpdate(offset);
        },
        onHorizontalDragEnd: (_) {
          imageWidth = max(_kMinWidth, imageWidth - moveDistance);
          moveDistance = 0;
          widget.onResize(imageWidth);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: _onFocus ? Center(child: _buildEdgeBar()) : null,
        ),
      ),
    );
  }

  Widget _buildEdgeBar() {
    return Container(
      width: _kEdgeVisualWidth,
      height: _kEdgeVisualHeight.toDouble(),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(_kEdgeVisualWidth),
        border: Border.all(color: Colors.white),
      ),
    );
  }

  // === 触摸端 half-side drag ===

  bool _touchFromRight = false;

  void _handleTouchDragStart(DragStartDetails details) {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localX = box.globalToLocal(details.globalPosition).dx;
    _touchFromRight = localX > box.size.width / 2;
    _touchRevealTimer?.cancel();
    initialOffset = details.globalPosition.dx;
    moveDistance = 0;
  }

  void _handleTouchDragUpdate(DragUpdateDetails details) {
    final offset = (details.globalPosition.dx - initialOffset) * widget.dragSensitivity;
    setState(() => moveDistance = _touchFromRight ? -offset : offset);
  }

  void _handleTouchDragEnd(DragEndDetails details) {
    imageWidth = max(_kMinWidth, imageWidth - moveDistance);
    moveDistance = 0;
    _revealTouchEdge();
    widget.onResize(imageWidth);
  }
}
