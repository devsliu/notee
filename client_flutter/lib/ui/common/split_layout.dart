import 'package:flutter/material.dart';

class SplitLayout extends StatefulWidget {
  final double leftWidth;
  final ValueChanged<double> onLeftWidthChanged;
  final double minLeftWidth;
  final double maxLeftWidth;
  final double draggerTopOffset;
  final Widget leftChild;
  final Widget rightChild;

  const SplitLayout({
    super.key,
    required this.leftWidth,
    required this.onLeftWidthChanged,
    required this.minLeftWidth,
    required this.maxLeftWidth,
    required this.leftChild,
    required this.rightChild,
    this.draggerTopOffset = 0,
  });

  @override
  State<SplitLayout> createState() => _SplitLayoutState();
}

class _SplitLayoutState extends State<SplitLayout> {
  late double _leftWidth;

  @override
  void initState() {
    super.initState();
    _leftWidth = widget.leftWidth;
  }

  @override
  void didUpdateWidget(covariant SplitLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leftWidth != widget.leftWidth) {
      _leftWidth = widget.leftWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _SplitLayoutDelegate(
        leftWidth: _leftWidth,
        draggerTopOffset: widget.draggerTopOffset,
      ),
      children: [
        LayoutId(id: 'left', child: widget.leftChild),
        LayoutId(id: 'right', child: widget.rightChild),
        LayoutId(id: 'dragger', child: _buildDragger()),
      ],
    );
  }

  Widget _buildDragger() {
    var theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _leftWidth += details.delta.dx;
          if (_leftWidth < widget.minLeftWidth) _leftWidth = widget.minLeftWidth;
          if (_leftWidth > widget.maxLeftWidth) _leftWidth = widget.maxLeftWidth;
        });
        widget.onLeftWidthChanged(_leftWidth);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Center(
          child: VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outline.withAlpha(80))),
      ),
    );
  }
}

class _SplitLayoutDelegate extends MultiChildLayoutDelegate {
  final double leftWidth;
  final double draggerTopOffset;

  _SplitLayoutDelegate({required this.leftWidth, required this.draggerTopOffset});

  @override
  void performLayout(Size size) {
    // 钳制 leftWidth，避免窗口过窄时右侧宽度为负导致 BoxConstraints 异常。
    final effectiveLeft = leftWidth.clamp(0.0, size.width);
    if (hasChild('left')) {
      layoutChild('left', BoxConstraints.tight(Size(effectiveLeft, size.height)));
      positionChild('left', Offset.zero);
    }
    if (hasChild('right')) {
      layoutChild('right', BoxConstraints.tight(Size(size.width - effectiveLeft, size.height)));
      positionChild('right', Offset(effectiveLeft, 0));
    }
    if (hasChild('dragger')) {
      const dragWidth = 16.0;
      final dragHeight = (size.height - draggerTopOffset).clamp(0.0, size.height);
      layoutChild('dragger', BoxConstraints.tight(Size(dragWidth, dragHeight)));
      positionChild('dragger', Offset(effectiveLeft - dragWidth / 2, draggerTopOffset));
    }
  }

  @override
  bool shouldRelayout(covariant _SplitLayoutDelegate oldDelegate) {
    return leftWidth != oldDelegate.leftWidth || draggerTopOffset != oldDelegate.draggerTopOffset;
  }
}
