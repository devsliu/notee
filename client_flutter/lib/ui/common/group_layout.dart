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
/// Children are laid out in **source order**; the delegate walks the child
/// chain directly via [firstChild] / [childAfter] — no [LayoutId] wrapping
/// needed. Zero-allocation iteration, matching [RenderFlex] performance.
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
/// Inside [performLayout], walk the child render-box chain directly
/// (zero-allocation, same pattern as [RenderFlex]):
/// ```dart
/// for (var child = firstChild; child != null; child = childAfter(child)) {
///   final size = layoutChild(child, constraints);
///   positionChild(child, offset);
/// }
/// ```
abstract class GroupLayoutDelegate {
  GroupLayoutDelegate();

  late RenderGroupLayout _render;

  /// Called by [RenderGroupLayout] when the delegate is first attached.
  /// Do not override.
  void bindRender(RenderGroupLayout render) {
    _render = render;
  }

  /// Lay out children, position them, and return this widget's final size.
  /// The returned size is clamped to [constraints] by the render object.
  Size performLayout(BoxConstraints constraints);

  /// Whether relayout is needed when [oldDelegate] is replaced by this one.
  bool shouldRelayout(covariant GroupLayoutDelegate oldDelegate) => true;

  // === Child chain access (zero-allocation) ===

  RenderBox? get firstChild => _render.firstChild;
  RenderBox? childAfter(RenderBox child) => _render.childAfter(child);

  // === Layout helpers ===

  Size layoutChild(RenderBox child, BoxConstraints constraints) {
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  void positionChild(RenderBox child, Offset offset) {
    (child.parentData as ContainerBoxParentData<RenderBox>).offset = offset;
  }

  // === intrinsics (子类按需 override) ===

  double computeMinIntrinsicWidth(double height) => 0;
  double computeMaxIntrinsicWidth(double height) => 0;
  double computeMinIntrinsicHeight(double width) => 0;
  double computeMaxIntrinsicHeight(double width) => 0;
}

class _GroupParentData extends ContainerBoxParentData<RenderBox> {}

class RenderGroupLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GroupParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GroupParentData> {
  RenderGroupLayout({required this._delegate}) {
    _delegate.bindRender(this);
  }

  GroupLayoutDelegate _delegate;

  set delegate(GroupLayoutDelegate value) {
    if (_delegate == value) return;
    final old = _delegate;
    _delegate = value;
    _delegate.bindRender(this);
    if (value.runtimeType != old.runtimeType || value.shouldRelayout(old)) {
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _GroupParentData) {
      child.parentData = _GroupParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.constrain(_delegate.performLayout(constraints));
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
  double computeMinIntrinsicWidth(double height) =>
      _delegate.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _delegate.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _delegate.computeMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _delegate.computeMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }
}
