import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NoteeResizableImage extends StatefulWidget {
  const NoteeResizableImage({
    super.key,
    required this.image,
    required this.alignment,
    required this.editable,
    required this.onResize,
    required this.width,
    this.height,
    this.onLongPressStart,
    this.onSecondaryTapUp,
  });

  /// Pre-built image widget (Image.file / Image.network / Image.memory).
  final Widget image;
  final double width;
  final double? height;
  final Alignment alignment;
  final bool editable;
  final void Function(double width) onResize;

  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(TapUpDetails)? onSecondaryTapUp;

  @override
  State<NoteeResizableImage> createState() => _NoteeResizableImageState();
}

const _kMinWidth = 30.0;
const _kRevealDuration = Duration(seconds: 3);

bool get _isMobile {
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

  bool _reveal = false;
  Timer? _revealTimer;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    imageWidth = widget.width;
  }

  @override
  void didUpdateWidget(covariant NoteeResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部更新了 node width（同步、undo/redo 等），同步回 state。
    // 拖拽中不动，避免覆盖 resize 过程中的临时 imageWidth。
    if (!_isDragging && oldWidget.width != widget.width) {
      imageWidth = widget.width;
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _scheduleReveal() {
    _revealTimer?.cancel();
    setState(() => _reveal = true);
    if (_isDragging) return;
    if (_isMobile) {
      // 移动端无 hover，靠 timer 超时隐藏。
      _revealTimer = Timer(_kRevealDuration, () {
        if (mounted && !_isDragging) {
          setState(() => _reveal = false);
        }
      });
    }
    // 桌面端：鼠标在图片上手柄就保持显示，MouseRegion.onExit 负责隐藏。
  }

  void _startDrag() {
    _isDragging = true;
    _revealTimer?.cancel();
  }

  void _endDrag() {
    _isDragging = false;
    _scheduleReveal();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: SizedBox(
        width: max(_kMinWidth, imageWidth - moveDistance),
        height: widget.height,
        child: MouseRegion(
          onEnter: (_) => _scheduleReveal(),
          onExit: (_) {
            if (!_isDragging) setState(() => _reveal = false);
          },
          child: _buildResizableImage(),
        ),
      ),
    );
  }

  Widget _buildResizableImage() {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.editable ? _scheduleReveal : null,
          onLongPressStart: widget.onLongPressStart,
          onSecondaryTapUp: widget.onSecondaryTapUp,
          child: AbsorbPointer(child: widget.image),
        ),
        if (widget.editable) ...[
          _buildEdgeGesture(
            left: 15,
            onUpdate: (d) => setState(() => moveDistance = d),
          ),
          _buildEdgeGesture(
            right: 15,
            onUpdate: (d) => setState(() => moveDistance = -d),
          ),
        ],
      ],
    );
  }

  Widget _buildEdgeGesture({
    double? left,
    double? right,
    required void Function(double distance) onUpdate,
  }) {
    final width = _isMobile ? 24.0 : 5.0;
    return Positioned(
      top: 0,
      left: left,
      right: right,
      bottom: 0,
      width: width,
      child: GestureDetector(
        onHorizontalDragStart: (DragStartDetails details) {
          _startDrag();
          initialOffset = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          var offset = details.globalPosition.dx - initialOffset;
          if (widget.alignment == Alignment.center) offset *= 2.0;
          onUpdate(offset);
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          imageWidth = max(_kMinWidth, imageWidth - moveDistance);
          initialOffset = 0;
          moveDistance = 0;
          _endDrag();
          widget.onResize(imageWidth);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: _reveal
              ? Center(
                  child: Container(
                    width: _isMobile ? 4 : 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
