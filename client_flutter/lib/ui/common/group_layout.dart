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
/// Each child must be wrapped in [LayoutId]. The delegate walks children via
/// its own [children] / [hasChild] / [layoutChild] / [positionChild] helpers.
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

/// A child entry exposed by [GroupLayoutDelegate.children].
class LayoutEntry {
  const LayoutEntry(this.id, this._child);

  final Object id;
  final RenderBox _child;

  /// Lay out this child under [constraints] and return its size.
  Size layout(BoxConstraints constraints) {
    _child.layout(constraints, parentUsesSize: true);
    return _child.size;
  }

  /// Position this child at [offset] (relative to the widget's top-left).
  void position(Offset offset) {
    (_child.parentData as MultiChildLayoutParentData).offset = offset;
  }
}

/// Delegate for [GroupLayout]. Implement [performLayout] to lay out children,
/// position them, and return the computed size.
///
/// Walk children via [children], or use [hasChild] / [layoutChild] /
/// [positionChild] when you already know the id. These helpers are inherited
/// from this base class and use the render object bound by [RenderGroupLayout].
abstract class GroupLayoutDelegate {
  GroupLayoutDelegate();

  late RenderGroupLayout _render;

  /// Called by [RenderGroupLayout] when the delegate is first attached.
  /// Do not override.
  void bindRender(RenderGroupLayout render) {
    _render = render;
  }

  /// Lay out children, position them, and return this widget's final size.
  /// The returned size is clamped to [constraints].
  ///
  /// Inside this method you may call [children], [layoutChild],
  /// [positionChild], and [hasChild] — all inherited from this base class.
  Size performLayout(BoxConstraints constraints);

  /// Whether relayout is needed when [oldDelegate] is replaced by this one.
  bool shouldRelayout(covariant GroupLayoutDelegate oldDelegate) => true;

  // === 便利 API ===

  /// Iterate every child with its [LayoutId].
  Iterable<LayoutEntry> get children sync* {
    RenderBox? child = _render.firstChild;
    while (child != null) {
      final pd = child.parentData as MultiChildLayoutParentData;
      final id = pd.id;
      if (id != null) yield LayoutEntry(id, child);
      child = _render.childAfter(child);
    }
  }

  bool hasChild(Object id) {
    for (final e in children) {
      if (e.id == id) return true;
    }
    return false;
  }

  Size layoutChild(Object id, BoxConstraints constraints) {
    for (final e in children) {
      if (e.id == id) return e.layout(constraints);
    }
    throw StateError('GroupLayout: no child with id "$id"');
  }

  void positionChild(Object id, Offset offset) {
    for (final e in children) {
      if (e.id == id) {
        e.position(offset);
        return;
      }
    }
    throw StateError('GroupLayout: no child with id "$id"');
  }

  // === intrinsics（子类按需 override）===

  double computeMinIntrinsicWidth(double height) => 0;
  double computeMaxIntrinsicWidth(double height) => 0;
  double computeMinIntrinsicHeight(double width) => 0;
  double computeMaxIntrinsicHeight(double width) => 0;
}

class RenderGroupLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
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
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
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
  double computeMinIntrinsicWidth(double height) => _delegate.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) => _delegate.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _delegate.computeMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _delegate.computeMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }
}
