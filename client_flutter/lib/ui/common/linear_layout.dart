/// Android ViewGroup-like layout with none/flexible/expanded rules.
///
/// A child with [LinearLayoutRule.none] is measured at its intrinsic size.
/// [LinearLayoutRule.flexible] shrinks proportionally on overflow and grows
/// proportionally to fill remaining space when the parent gives extra room.
/// [LinearLayoutRule.expanded] shares remaining space by [weight] (ignored if
/// there is overflow).
///
/// Implemented via [GroupLayoutDelegate] with a two-pass layout: Pass 1
/// measures every child loose (collecting intrinsic sizes + sums + rule
/// buckets), Pass 2 tight-measures changed children and positions them.
library;

import 'package:flutter/material.dart';

import 'group_layout.dart';

// =============================================================================
// Rule
// =============================================================================

sealed class LinearLayoutRule {
  const LinearLayoutRule();

  static const LinearLayoutRule none = _None();
  static const LinearLayoutRule flexible = _Flexible();

  factory LinearLayoutRule.expanded({double weight = 1.0}) => _Expanded(weight: weight);

  /// Match over the three rule kinds. Useful for UI code that needs to
  /// distinguish them (e.g. color coding in a test page).
  R when<R>({required R Function() none, required R Function() flexible, required R Function(double weight) expanded}) {
    return switch (this) {
      _None() => none(),
      _Flexible() => flexible(),
      _Expanded(:final weight) => expanded(weight),
    };
  }
}

final class _None extends LinearLayoutRule {
  const _None();
}

final class _Flexible extends LinearLayoutRule {
  const _Flexible();
}

final class _Expanded extends LinearLayoutRule {
  final double weight;
  const _Expanded({required this.weight});
}

// =============================================================================
// Child
// =============================================================================

class LinearLayoutChild {
  LinearLayoutChild({
    required this.child,
    this.rule = LinearLayoutRule.none,
    this.width,
    this.height,
    this.crossAxisAlignment,
  });

  final Widget child;
  final LinearLayoutRule rule;

  /// Fixed main/cross size for this child (Android-style layout_width/height).
  ///
  /// A non-null value on the main axis pins the child to that exact main size
  /// and forces [rule] to behave as [LinearLayoutRule.none] (no flex
  /// distribution). A non-null value on the cross axis applies a tight cross
  /// constraint. When null the child sizes itself naturally.
  final double? width;
  final double? height;

  /// Per-child cross-axis alignment. When non-null, overrides the
  /// [LinearLayout]'s `crossAxisAlignment` for this child only.
  /// [CrossAxisAlignment.stretch] forces the child to fill the cross axis
  /// (tight cross constraint); an explicit [width]/[height] on the cross axis
  /// takes precedence over stretch.
  final CrossAxisAlignment? crossAxisAlignment;

  // ---- Layout-time temporary state (set during performLayout) ----
  double looseMain = 0;
  Size? measuredSize;
  double finalMain = 0;
}

// =============================================================================
// Widget
// =============================================================================

class LinearLayout extends GroupLayout {
  LinearLayout({
    super.key,
    required Axis axis,
    required List<LinearLayoutChild> children,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) : _axis = axis,
       _padding = padding,
       _crossAxisAlignment = crossAxisAlignment,
       _children = children,
       super(
         delegate: _LinearLayoutDelegate(
           axis: axis,
           padding: padding,
           crossAxisAlignment: crossAxisAlignment,
           children: children,
         ),
         children: children.map((c) => c.child).toList(),
       );

  final Axis _axis;
  final EdgeInsetsGeometry _padding;
  final CrossAxisAlignment _crossAxisAlignment;
  final List<LinearLayoutChild> _children;

  @override
  void updateRenderObject(BuildContext context, RenderGroupLayout renderObject) {
    renderObject.delegate = _LinearLayoutDelegate(
      axis: _axis,
      padding: _padding,
      crossAxisAlignment: _crossAxisAlignment,
      children: _children,
    );
  }
}

// =============================================================================
// Delegate
// =============================================================================

class _LinearLayoutDelegate extends GroupLayoutDelegate {
  _LinearLayoutDelegate({
    required this._axis,
    required EdgeInsetsGeometry padding,
    required this._crossAxisAlignment,
    required this._children,
  }) : _pad = padding.resolve(TextDirection.ltr);

  final Axis _axis;
  final CrossAxisAlignment _crossAxisAlignment;
  final List<LinearLayoutChild> _children;
  final EdgeInsets _pad; // resolved once (always LTR)

  // Reusable buckets to avoid allocation during layout.
  final List<LinearLayoutChild> _flexibleBucket = [];
  final List<LinearLayoutChild> _expandedBucket = [];

  @override
  Size performLayout(BoxConstraints constraints) {
    final children = _children;
    final count = children.length;
    if (count == 0) {
      return Size(constraints.minWidth, constraints.minHeight);
    }

    final horizontal = _axis == Axis.horizontal;
    final pad = _pad;
    final innerConstraints = constraints.deflate(_pad);

    final parentMax = horizontal ? innerConstraints.maxWidth : innerConstraints.maxHeight;
    final parentMin = horizontal ? innerConstraints.minWidth : innerConstraints.minHeight;
    final mainTight = horizontal ? innerConstraints.hasTightWidth : innerConstraints.hasTightHeight;
    final crossLimit = horizontal ? innerConstraints.maxHeight : innerConstraints.maxWidth;
    final mainInfinite = parentMax.isInfinite;

    // ---- Pass 1: loose layout + collect sums + fill buckets (single pass) ----
    // Measure non-expanded children at their intrinsic (content) size by using
    // an unbounded main axis — mirrors Flutter Row's non-flex constraints, so
    // greedy children (e.g. a nested Row with mainAxisSize.max) size to content
    // instead of swallowing the whole parent width.
    final baseLoose = horizontal
        ? BoxConstraints(maxHeight: innerConstraints.maxHeight)
        : BoxConstraints(maxWidth: innerConstraints.maxWidth);
    final flexBucket = _flexibleBucket..clear();
    final expBucket = _expandedBucket..clear();
    double sumN = 0, sumF = 0, sumEW = 0;
    bool hasExpanded = false;

    var index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final lc = children[index++];
      final rule = lc.rule;
      final fixedMain = horizontal ? lc.width : lc.height;
      final fixedCross = horizontal ? lc.height : lc.width;
      final hasFixedMain = fixedMain != null;

      // Build child-specific loose constraints, applying any fixed dimensions.
      var childLoose = baseLoose;
      if (hasFixedMain) {
        childLoose = horizontal
            ? childLoose.copyWith(minWidth: fixedMain, maxWidth: fixedMain)
            : childLoose.copyWith(minHeight: fixedMain, maxHeight: fixedMain);
      }
      if (fixedCross != null) {
        childLoose = horizontal
            ? childLoose.copyWith(minHeight: fixedCross, maxHeight: fixedCross)
            : childLoose.copyWith(minWidth: fixedCross, maxWidth: fixedCross);
      }

      // Expanded with finite main axis gets its size from remaining space,
      // so skip the loose measurement. Fixed-main children always measure.
      if (rule is _Expanded && !mainInfinite && !hasFixedMain) {
        lc.looseMain = 0;
        lc.measuredSize = null;
      } else {
        final size = layoutChild(child, childLoose);
        lc.looseMain = hasFixedMain ? fixedMain : (horizontal ? size.width : size.height);
        lc.measuredSize = size;
      }

      // A fixed main dimension forces none-like behaviour regardless of rule.
      if (hasFixedMain) {
        lc.finalMain = fixedMain;
        sumN += fixedMain;
      } else if (rule is _Expanded) {
        hasExpanded = true;
        sumEW += rule.weight;
        expBucket.add(lc);
      } else if (rule is _Flexible) {
        sumF += lc.looseMain;
        flexBucket.add(lc);
      } else {
        // _None
        lc.finalMain = lc.looseMain; // none keeps loose
        sumN += lc.looseMain;
      }
    }

    // ---- Assign finalMain (no full-list traversals, only buckets) ----
    _assignFinals(
      parentMax,
      parentMin,
      mainTight,
      mainInfinite,
      hasExpanded,
      sumN,
      sumF,
      sumEW,
      flexBucket,
      expBucket,
      children,
    );

    // ---- Pass 2: layout changed children + position ----
    final crossAxisAlignment = _crossAxisAlignment;

    double mainOffset = 0;
    double crossMax = 0;
    index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final lc = children[index++];
      var finalMain = lc.finalMain;
      if (finalMain < 0) finalMain = 0;

      final align = lc.crossAxisAlignment ?? crossAxisAlignment;
      final isStretch = align == CrossAxisAlignment.stretch;
      final fixedCross = horizontal ? lc.height : lc.width;

      final Size size;
      // Stretch forces a tight cross constraint, so the Pass 1 loose
      // measurement is stale unless the child also has a fixed cross size
      // (which overrides stretch).
      final canReuse =
          lc.measuredSize != null && (finalMain - lc.looseMain).abs() < 1e-9 && !(isStretch && fixedCross == null);
      if (canReuse) {
        size = lc.measuredSize!;
      } else {
        final double cMin;
        final double cMax;
        if (fixedCross != null) {
          cMin = fixedCross;
          cMax = fixedCross;
        } else if (isStretch && crossLimit.isFinite) {
          cMin = crossLimit;
          cMax = crossLimit;
        } else {
          cMin = 0;
          cMax = crossLimit;
        }
        size = layoutChild(
          child,
          horizontal
              ? BoxConstraints(minWidth: finalMain, maxWidth: finalMain, minHeight: cMin, maxHeight: cMax)
              : BoxConstraints(minWidth: cMin, maxWidth: cMax, minHeight: finalMain, maxHeight: finalMain),
        );
        lc.measuredSize = size;
      }
      final crossSize = horizontal ? size.height : size.width;
      if (crossSize > crossMax) crossMax = crossSize;
      mainOffset += finalMain;
    }

    mainOffset = 0;
    index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final lc = children[index++];
      var finalMain = lc.finalMain;
      if (finalMain < 0) finalMain = 0;
      final crossSize = horizontal ? lc.measuredSize!.height : lc.measuredSize!.width;
      // Per-child alignment overrides the layout-level one when set.
      final align = lc.crossAxisAlignment ?? crossAxisAlignment;
      final double crossOffset;
      switch (align) {
        case CrossAxisAlignment.center:
          crossOffset = (crossMax - crossSize) / 2;
          break;
        case CrossAxisAlignment.end:
          crossOffset = crossMax - crossSize;
          break;
        case CrossAxisAlignment.start:
        case CrossAxisAlignment.stretch:
        case CrossAxisAlignment.baseline:
          crossOffset = 0;
          break;
      }
      positionChild(
        child,
        Offset(
          horizontal ? mainOffset + pad.left : crossOffset + pad.left,
          horizontal ? crossOffset + pad.top : mainOffset + pad.top,
        ),
      );
      mainOffset += finalMain;
    }

    final innerMain = mainOffset < parentMin ? parentMin : (mainOffset > parentMax ? parentMax : mainOffset);
    final crossMin = horizontal ? innerConstraints.minHeight : innerConstraints.minWidth;
    final crossMaxLimit = horizontal ? innerConstraints.maxHeight : innerConstraints.maxWidth;
    var innerCross = crossMax < crossMin ? crossMin : crossMax;
    if (innerCross > crossMaxLimit) innerCross = crossMaxLimit;

    return Size(
      horizontal ? innerMain + pad.horizontal : innerCross + pad.horizontal,
      horizontal ? innerCross + pad.vertical : innerMain + pad.vertical,
    );
  }

  /// Assign finalMain. Operates only on pre-collected buckets + sums — never
  /// traverses the full [children] list.
  void _assignFinals(
    double parentMax,
    double parentMin,
    bool mainTight,
    bool mainInfinite,
    bool hasExpanded,
    double sumN,
    double sumF,
    double sumEW,
    List<LinearLayoutChild> flexBucket,
    List<LinearLayoutChild> expBucket,
    List<LinearLayoutChild> children,
  ) {
    // ---- Branch 1: infinite main axis → all loose ----
    if (mainInfinite) {
      for (final c in children) {
        c.finalMain = c.looseMain;
      }
      return;
    }

    // ---- Branch 2: finite + has expanded ----
    if (hasExpanded) {
      final target = parentMax;
      final sumNonE = sumN + sumF;

      if (sumNonE <= target) {
        final remaining = target - sumNonE;
        if (remaining <= 0) {
          for (final c in expBucket) {
            c.finalMain = 0;
          }
        } else {
          final weightSum = sumEW == 0 ? expBucket.length.toDouble() : sumEW;
          for (final c in expBucket) {
            final w = (c.rule as _Expanded).weight;
            final effW = sumEW == 0 ? 1.0 : w;
            c.finalMain = remaining * (effW / weightSum);
          }
        }
        // flexible keep their loose (content) size
        for (final c in flexBucket) {
          c.finalMain = c.looseMain;
        }
      } else {
        // overflow: expanded=0, flexible shrink to fill target-sumN
        for (final c in expBucket) {
          c.finalMain = 0;
        }
        if (sumN >= target) {
          // even none overflows, flexible keep their loose size
          for (final c in flexBucket) {
            c.finalMain = c.looseMain;
          }
        } else {
          _splitProportional(flexBucket, target - sumN, sumF);
        }
      }
      return;
    }

    // ---- Branch 3: finite + no expanded ----
    if (flexBucket.isEmpty) { 
      // all none — already set finalMain=looseMain in Pass 1
      return;
    }

    final sum = sumN + sumF;
    final double target;
    final bool grow;
    final bool shrink;
    if (mainTight) {
      target = parentMax;
      grow = sum < target;
      shrink = sum > target;
    } else if (sum < parentMin) {
      target = parentMin;
      grow = true;
      shrink = false;
    } else if (sum > parentMax) {
      target = parentMax;
      grow = false;
      shrink = true;
    } else {
      target = sum;
      grow = false;
      shrink = false;
    }

    if (grow) {
      _splitProportional(flexBucket, sumF + (target - sum), sumF);
    } else if (shrink) {
      if (sumN >= target) {
        // none alone overflows, flexible stay loose
      } else {
        _splitProportional(flexBucket, target - sumN, sumF);
      }
    }
    // else: flexible stay loose (already... no, Pass 1 didn't set them)
    if (!grow && !shrink) {
      for (final f in flexBucket) {
        f.finalMain = f.looseMain;
      }
    }
  }

  /// Proportionally distribute [available] across flexible children by their
  /// looseMain. [sumF] is the pre-computed sum of looseMain (from Pass 1).
  /// If some children have zero looseMain, recomputes the non-zero sum.
  void _splitProportional(List<LinearLayoutChild> fChildren, double available, double sumF) {
    if (fChildren.isEmpty) return;
    // Fast path: all positive → sumF is the divisor, single assign loop
    double divisor = sumF;
    if (divisor == 0) {
      final per = available / fChildren.length;
      for (final f in fChildren) {
        f.finalMain = per;
      }
      return;
    }
    for (final f in fChildren) {
      f.finalMain = f.looseMain <= 0 ? 0 : available * (f.looseMain / divisor);
    }
  }
}
