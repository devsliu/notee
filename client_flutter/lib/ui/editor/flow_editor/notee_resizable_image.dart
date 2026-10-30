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
    this.height,
    this.onLongPressStart,
    this.onSecondaryTapUp,
    this.dragSensitivity = 1.0,
  });

  final Widget image;
  final double width;
  final double? height;
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
const _kEdgeHitWidth = 8.0;
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

enum _DragSide { none, left, right }

class _NoteeResizableImageState extends State<NoteeResizableImage> {
  late double imageWidth;
  final GlobalKey _boxKey = GlobalKey();

  double initialOffset = 0;
  double moveDistance = 0;

  /// 是否显示视觉提示 + 允许拖拽（两端统一用这个字段）
  bool _dragEnabled = false;
  Timer? _dragEnabledTimer; // 仅触摸端用

  _DragSide _dragSide = _DragSide.none; // none 同时表示 "未在拖动"

  @override
  void initState() {
    super.initState();
    imageWidth = widget.width;
  }

  @override
  void didUpdateWidget(covariant NoteeResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragSide == _DragSide.none && oldWidget.width != widget.width) {
      imageWidth = widget.width;
    }
  }

  @override
  void dispose() {
    _dragEnabledTimer?.cancel();
    super.dispose();
  }

  /// 启用 drag，[timeLimited] 为 true 时 3 秒后自动关闭（触摸端用）
  void _enableDrag({bool timeLimited = false}) {
    _dragEnabledTimer?.cancel();
    setState(() => _dragEnabled = true);
    if (timeLimited && _dragSide == _DragSide.none) {
      _dragEnabledTimer = Timer(_kRevealDuration, () {
        if (mounted && _dragSide == _DragSide.none) setState(() => _dragEnabled = false);
      });
    }
  }

  void _disableDrag() {
    if (_dragSide != _DragSide.none) return;
    _dragEnabledTimer?.cancel();
    setState(() => _dragEnabled = false);
  }

  void _startDrag() {
    _dragEnabledTimer?.cancel();
  }

  void _endDrag() {
    _dragSide = _DragSide.none;
    // 触摸端拖拽结束后重开 3 秒计时器
    if (_isTouchMode) _enableDrag(timeLimited: true);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _boxKey,
      width: max(_kMinWidth, imageWidth - moveDistance),
      height: widget.height,
      child: MouseRegion(
        cursor: _dragEnabled && widget.editable ? SystemMouseCursors.resizeLeftRight : MouseCursor.defer,
        onEnter: (_) => _enableDrag(),
        onExit: (_) => _disableDrag(),
        child: _buildResizableImage(),
      ),
    );
  }

  Widget _buildResizableImage() {
    final editable = widget.editable;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: editable && _isTouchMode ? () => _enableDrag(timeLimited: true) : null,
          onLongPressStart: widget.onLongPressStart,
          onSecondaryTapUp: widget.onSecondaryTapUp,
          onHorizontalDragStart: editable ? _handleDragStart : null,
          onHorizontalDragUpdate: editable ? _handleDragUpdate : null,
          onHorizontalDragEnd: editable ? _handleDragEnd : null,
          child: widget.image,
        ),
        // visual edge handles — 两端统一：只有 _dragEnabled 时显示
        if (editable && _dragEnabled) ...[
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            width: _kEdgeHitWidth,
            child: IgnorePointer(child: _buildEdgeBar()),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: _kEdgeHitWidth,
            child: IgnorePointer(child: _buildEdgeBar()),
          ),
        ],
      ],
    );
  }

  Widget _buildEdgeBar() {
    return Center(
      child: Container(
        width: _kEdgeVisualWidth,
        height: _kEdgeVisualHeight.toDouble(),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(_kEdgeVisualWidth),
          border: Border.all(color: Colors.white),
        ),
      ),
    );
  }

  // === 统一的 drag（桌面 edge + 移动 half-side） ===

  void _handleDragStart(DragStartDetails details) {
    if (!_dragEnabled) {
      _dragSide = _DragSide.none;
      return;
    }

    final box = _boxKey.currentContext!.findRenderObject() as RenderBox;
    final localX = box.globalToLocal(details.globalPosition).dx;
    final w = box.size.width;

    if (_isTouchMode) {
      _dragSide = localX > w / 2 ? _DragSide.right : _DragSide.left;
    } else {
      if (localX <= _kEdgeHitWidth) {
        _dragSide = _DragSide.left;
      } else if (localX >= w - _kEdgeHitWidth) {
        _dragSide = _DragSide.right;
      } else {
        _dragSide = _DragSide.none;
        return;
      }
    }

    _startDrag();
    initialOffset = details.globalPosition.dx;
    moveDistance = 0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragSide == _DragSide.none) return;
    final offset = (details.globalPosition.dx - initialOffset) * widget.dragSensitivity;
    setState(() {
      moveDistance = _dragSide == _DragSide.right ? -offset : offset;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragSide == _DragSide.none) return;
    imageWidth = max(_kMinWidth, imageWidth - moveDistance);
    moveDistance = 0;
    _endDrag();
    widget.onResize(imageWidth);
  }
}
