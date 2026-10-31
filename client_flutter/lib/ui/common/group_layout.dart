import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A multi-child layout that can size itself based on its children.
///
/// Unlike [CustomMultiChildLayout] (whose [MultiChildLayoutDelegate.getSize]
/// runs *before* children are laid out and therefore cannot depend on child
/// sizes), [GroupLayout] gives you a single [GroupLayoutDelegate.performLayout]
/// callback in which you lay out children, read their sizes, position them,
/// and **return** the widget's final size — much like Android's `ViewGroup`
/// where you measure children first, then set your own size.
///
/// Each child must be wrapped in [LayoutId]. The delegate must call
/// [GroupLayoutChildren.layoutChild] on **every** child exactly once; calling
/// it twice or skipping a child triggers an assertion in debug mode.
class GroupLayout extends MultiChildRenderObjectWidget {
  const GroupLayout({
    super.key,
    required this.delegate,
    required super.children,
  });

  final GroupLayoutDelegate delegate;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderGroupLayout(delegate: delegate);
  }

  @override
  void updateRenderObject(BuildContext context, RenderGroupLayout renderObject) {
    renderObject.delegate = delegate;
  }
}

/// Delegate for [GroupLayout]. Implement [performLayout] to lay out children,
/// position them, and return the computed size.
///
/// You **must** call [GroupLayoutChildren.layoutChild] on every child exactly
/// once during [performLayout]. In debug mode, calling it twice or skipping a
/// child will assert.
abstract class GroupLayoutDelegate {
  const GroupLayoutDelegate();

  /// Lay out children via [children], position them, and return this widget's
  /// final size. The returned size is clamped to [constraints].
  Size performLayout(BoxConstraints constraints, GroupLayoutChildren children);

  /// Whether relayout is needed when [oldDelegate] is replaced by this one.
  bool shouldRelayout(covariant GroupLayoutDelegate oldDelegate) => true;

  /// Compute the minimum intrinsic width for [height]. Return 0 if your layout
  /// does not use intrinsic widths. Override this so ancestors (e.g. [Row])
  /// can properly size this widget.
  double computeMinIntrinsicWidth(double height) => 0;

  /// Compute the maximum intrinsic width for [height]. Return 0 if your layout
  /// does not use intrinsic widths.
  double computeMaxIntrinsicWidth(double height) => 0;

  /// Compute the minimum intrinsic height for [width]. Return 0 if your layout
  /// does not use intrinsic heights.
  double computeMinIntrinsicHeight(double width) => 0;

  /// Compute the maximum intrinsic height for [width]. Return 0 if your layout
  /// does not use intrinsic heights.
  double computeMaxIntrinsicHeight(double width) => 0;
}

/// Accessor passed to [GroupLayoutDelegate.performLayout]. Use it to lay out
/// and position children by their [LayoutId].
class GroupLayoutChildren {
  GroupLayoutChildren._(this._render);

  final RenderGroupLayout _render;
  final Map<Object, RenderBox> _byId = {};
  final Set<Object> _laidOut = {};

  void _index() {
    _byId.clear();
    _laidOut.clear();
    RenderBox? child = _render.firstChild;
    while (child != null) {
      final pd = child.parentData as _GroupLayoutParentData;
      final id = pd.id;
      if (id != null) {
        assert(
          !_byId.containsKey(id),
          'GroupLayout: duplicate LayoutId "$id". Each child must have a unique id.',
        );
        _byId[id] = child;
      }
      child = _render.childAfter(child);
    }
  }

  void _assertAllLaidOut() {
    for (final id in _byId.keys) {
      assert(
        _laidOut.contains(id),
        'GroupLayout: child "$id" was never laid out. You must call layoutChild() for every child.',
      );
    }
  }

  /// Whether a child with [id] exists.
  bool hasChild(Object id) => _byId.containsKey(id);

  /// Lay out the child with [id] under [constraints] and return its size.
  /// May be called more than once (useful for a two-pass approach: layout
  /// loose to measure natural size, then layout tight for final placement).
  Size layoutChild(Object id, BoxConstraints constraints) {
    final child = _byId[id];
    assert(child != null, 'GroupLayout: no child with id "$id"');
    _laidOut.add(id);
    child!.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  /// Position the child with [id] at [offset] (relative to this widget's
  /// top-left corner). Call after [layoutChild].
  void positionChild(Object id, Offset offset) {
    final child = _byId[id];
    assert(child != null, 'GroupLayout: no child with id "$id"');
    (child!.parentData as _GroupLayoutParentData).offset = offset;
  }
}

class _GroupLayoutParentData extends MultiChildLayoutParentData {}

class RenderGroupLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GroupLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GroupLayoutParentData> {
  RenderGroupLayout({required this._delegate});

  GroupLayoutDelegate _delegate;

  set delegate(GroupLayoutDelegate value) {
    if (_delegate == value) return;
    final old = _delegate;
    _delegate = value;
    if (value.runtimeType != old.runtimeType || value.shouldRelayout(old)) {
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _GroupLayoutParentData) {
      child.parentData = _GroupLayoutParentData();
    }
  }

  @override
  void performLayout() {
    final accessor = GroupLayoutChildren._(this);
    accessor._index();
    final computed = _delegate.performLayout(constraints, accessor);
    size = constraints.constrain(computed);
    accessor._assertAllLaidOut();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _delegate.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _delegate.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _delegate.computeMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _delegate.computeMaxIntrinsicHeight(width);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }
}
