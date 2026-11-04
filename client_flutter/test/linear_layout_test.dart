import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notee/ui/common/linear_layout.dart';

// ============================================================================
// Helpers
// ============================================================================

/// Build a LinearLayout inside a fixed-size Container and pump one frame.
/// Returns a list of (width, height) for each child widget in order.
Future<List<Size>> _measureChildren(
  WidgetTester tester, {
  required double parentWidth,
  required double parentHeight,
  required List<LinearLayoutChild> children,
  Axis axis = Axis.horizontal,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: parentWidth,
          height: parentHeight,
          child: LinearLayout(
            axis: axis,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    ),
  );
  final renderLL = tester.renderObject<RenderBox>(find.byType(LinearLayout));
  final sizes = <Size>[];
  renderLL.visitChildren((child) {
    final box = child as RenderBox;
    sizes.add(box.size);
  });
  return sizes;
}

/// Convenience: create a SizedBox child with known intrinsic size.
LinearLayoutChild _sized(double width, double height, {
  LinearLayoutRule rule = LinearLayoutRule.none,
  double? w,
  double? h,
  CrossAxisAlignment? crossAxisAlignment,
}) {
  return LinearLayoutChild(
    rule: rule,
    width: w,
    height: h,
    crossAxisAlignment: crossAxisAlignment,
    child: SizedBox(width: width, height: height),
  );
}

// ============================================================================
// None rule
// ============================================================================

void main() {
  group('LinearLayout — none rule', () {
    testWidgets('single none child fits', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [_sized(100, 30)],
      );
      expect(sizes, hasLength(1));
      expect(sizes[0], const Size(100, 30));
    });

    testWidgets('none children sum exactly parent width', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 300,
        parentHeight: 40,
        children: [_sized(100, 30), _sized(100, 30), _sized(100, 30)],
      );
      expect(sizes[0].width, 100);
      expect(sizes[1].width, 100);
      expect(sizes[2].width, 100);
    });

    testWidgets('none children overflow parent — sizes unchanged', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 200,
        parentHeight: 40,
        children: [_sized(150, 30), _sized(150, 30)],
      );
      // none children keep intrinsic size even on overflow.
      expect(sizes[0].width, 150);
      expect(sizes[1].width, 150);
    });

    testWidgets('empty children — does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 40,
              child: LinearLayout(
                axis: Axis.horizontal,
                children: const [],
              ),
            ),
          ),
        ),
      );
      // No exception → pass.
    });

    testWidgets('column — none children stack vertically', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 100,
        parentHeight: 200,
        children: [_sized(80, 50), _sized(80, 50), _sized(80, 50)],
        axis: Axis.vertical,
      );
      expect(sizes[0].height, 50);
      expect(sizes[1].height, 50);
      expect(sizes[2].height, 50);
      // Cross (width) not forced to parent width for none.
      expect(sizes[0].width, 80);
    });
  });

  // ==========================================================================
  // Expanded rule
  // ==========================================================================

  group('LinearLayout — expanded rule', () {
    testWidgets('single expanded fills remaining', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      expect(sizes[0].width, 100);
      expect(sizes[1].width, 400); // 500 - 100
    });

    testWidgets('two equal expanded share equally', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      expect(sizes[0].width, 100);
      expect(sizes[1].width, 200);
      expect(sizes[2].width, 200);
    });

    testWidgets('expanded with weights', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 600,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(10, 30, rule: LinearLayoutRule.expanded(weight: 1)),
          _sized(10, 30, rule: LinearLayoutRule.expanded(weight: 3)),
        ],
      );
      expect(sizes[0].width, 100);
      // remaining = 500, split 1:3 → 125 and 375
      expect(sizes[1].width, closeTo(125, 0.5));
      expect(sizes[2].width, closeTo(375, 0.5));
    });

    testWidgets('expanded gets 0 when none overflow', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 200,
        parentHeight: 40,
        children: [
          _sized(150, 30),
          _sized(150, 30),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      // none keep their size; expanded = 0 because overflow.
      expect(sizes[0].width, 150);
      expect(sizes[1].width, 150);
      expect(sizes[2].width, 0);
    });

    testWidgets('all expanded — equal share', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 300,
        parentHeight: 40,
        children: [
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      expect(sizes[0].width, closeTo(100, 0.5));
      expect(sizes[1].width, closeTo(100, 0.5));
      expect(sizes[2].width, closeTo(100, 0.5));
    });
  });

  // ==========================================================================
  // Flexible rule
  // ==========================================================================

  group('LinearLayout — flexible rule', () {
    testWidgets('flexible grows to fill when no expanded and sum < parent', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(150, 30, rule: LinearLayoutRule.flexible),
        ],
      );
      // no expanded, sum=250 < 500 → flexible grows proportionally to fill.
      expect(sizes[0].width, 100);
      expect(sizes[1].width, 400); // 500 - 100
    });

    testWidgets('flexible keeps loose when expanded present and no overflow', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(150, 30, rule: LinearLayoutRule.flexible),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      // hasExpanded → flexible keeps loose, expanded gets rest.
      expect(sizes[0].width, 100);
      expect(sizes[1].width, 150); // flexible keeps content
      expect(sizes[2].width, 250); // 500 - 100 - 150
    });

    testWidgets('flexible shrinks proportionally on overflow', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 300,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(300, 30, rule: LinearLayoutRule.flexible),
          _sized(150, 30, rule: LinearLayoutRule.flexible),
        ],
      );
      // none = 100; 2 flexible total loose = 450. overflow: must fit in 300 - 100 = 200.
      // ratio 300:150 = 2:1 → 133.3 and 66.7
      expect(sizes[0].width, 100);
      expect(sizes[1].width, closeTo(133.3, 0.5));
      expect(sizes[2].width, closeTo(66.7, 0.5));
    });

    testWidgets('flexible + expanded: flexible keeps loose, expanded gets rest', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(150, 30, rule: LinearLayoutRule.flexible),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      expect(sizes[0].width, 100);
      expect(sizes[1].width, 150); // flexible keeps content
      expect(sizes[2].width, 250); // 500 - 100 - 150
    });

    testWidgets('flexible + expanded overflow: expanded=0, flexible shrink', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 200,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(300, 30, rule: LinearLayoutRule.flexible),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      // overflow: sumNonE = 100 + 300 = 400 > 200. expanded = 0.
      // flexible shrink to 200 - 100 = 100 (only one flexible).
      expect(sizes[0].width, 100);
      expect(sizes[1].width, closeTo(100, 0.5));
      expect(sizes[2].width, 0);
    });

    testWidgets('flexible all alone, sum < parent — grow proportionally', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30, rule: LinearLayoutRule.flexible),
          _sized(200, 30, rule: LinearLayoutRule.flexible),
        ],
      );
      // sum loose = 300 < 500. grow to fill 500 by ratio 1:2.
      expect(sizes[0].width, closeTo(166.7, 0.5));
      expect(sizes[1].width, closeTo(333.3, 0.5));
    });
  });

  // ==========================================================================
  // Fixed width/height
  // ==========================================================================

  group('LinearLayout — fixed width/height', () {
    testWidgets('fixed main axis width pins child', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30, w: 50),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      expect(sizes[0].width, 50); // fixed, not 100
      expect(sizes[1].width, 450);
    });

    testWidgets('fixed main axis width forces none behaviour over expanded', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(10, 30, rule: LinearLayoutRule.expanded(), w: 80),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      // First has fixed main → treated as none (80). Second expanded gets rest.
      expect(sizes[0].width, 80);
      expect(sizes[1].width, 420);
    });

    testWidgets('fixed cross axis height applies tight constraint', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 100,
        children: [
          _sized(100, 30, h: 50),
          _sized(100, 40),
        ],
        crossAxisAlignment: CrossAxisAlignment.stretch,
      );
      // stretch normally would push both to 100 tall, but fixed height wins.
      expect(sizes[0].height, 50); // fixed, not stretched
      expect(sizes[1].height, 100); // stretched
    });

    testWidgets('column: fixed width is cross axis, fixed height is main', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 200,
        parentHeight: 500,
        children: [
          _sized(80, 100, h: 60), // main axis fixed to 60
          _sized(80, 100),
        ],
        axis: Axis.vertical,
      );
      expect(sizes[0].height, 60);
      expect(sizes[1].height, 100);
    });
  });

  // ==========================================================================
  // CrossAxisAlignment
  // ==========================================================================

  group('LinearLayout — crossAxisAlignment', () {
    testWidgets('center aligns children vertically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 100,
              child: LinearLayout(
                axis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _sized(100, 30),
                  _sized(100, 50),
                ],
              ),
            ),
          ),
        ),
      );
      // Visit children and check offset dy.
      final ll = tester.renderObject<RenderBox>(find.byType(LinearLayout));
      final offsets = <double>[];
      ll.visitChildren((child) {
        final pb = child.parentData as ContainerBoxParentData<RenderBox>;
        offsets.add(pb.offset.dy);
      });
      // crossMax = max(30, 50) = 50. parent height = 100.
      // For center: crossOffset = (100 - size) / 2... wait no,
      // our delegate uses crossMax (not parent height). Let me check.
      // Actually our implementation positions relative to crossMax.
      // So offsets should both center within 50:
      // child1 (30): (50-30)/2 = 10
      // child2 (50): (50-50)/2 = 0
      expect(offsets[0], 10);
      expect(offsets[1], 0);
    });

    testWidgets('stretch fills cross axis', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 100,
        children: [
          _sized(100, 30),
          _sized(100, 40),
        ],
        crossAxisAlignment: CrossAxisAlignment.stretch,
      );
      expect(sizes[0].height, 100);
      expect(sizes[1].height, 100);
    });

    testWidgets('per-child crossAxisAlignment overrides global', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 100,
        children: [
          _sized(100, 30, crossAxisAlignment: CrossAxisAlignment.start),
          _sized(100, 30), // global = stretch
        ],
        crossAxisAlignment: CrossAxisAlignment.stretch,
      );
      // First has explicit start → keeps 30. Second uses global stretch → 100.
      expect(sizes[0].height, 30);
      expect(sizes[1].height, 100);
    });

    testWidgets('end aligns to bottom', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 100,
              child: LinearLayout(
                axis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _sized(100, 30),
                  _sized(100, 50),
                ],
              ),
            ),
          ),
        ),
      );
      final ll = tester.renderObject<RenderBox>(find.byType(LinearLayout));
      final offsets = <double>[];
      ll.visitChildren((child) {
        final pb = child.parentData as ContainerBoxParentData<RenderBox>;
        offsets.add(pb.offset.dy);
      });
      // crossMax = 50. end = crossMax - size.
      // child1 (30): 50 - 30 = 20
      // child2 (50): 50 - 50 = 0
      expect(offsets[0], 20);
      expect(offsets[1], 0);
    });
  });

  // ==========================================================================
  // Axis: vertical (Column equivalent)
  // ==========================================================================

  group('LinearLayout — vertical axis', () {
    testWidgets('expanded fills vertical space', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 100,
        parentHeight: 500,
        children: [
          _sized(80, 100),
          _sized(80, 10, rule: LinearLayoutRule.expanded()),
        ],
        axis: Axis.vertical,
      );
      expect(sizes[0].height, 100);
      expect(sizes[1].height, 400);
    });

    testWidgets('flexible shrinks vertically on overflow', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 100,
        parentHeight: 200,
        children: [
          _sized(80, 100),
          _sized(80, 300, rule: LinearLayoutRule.flexible),
        ],
        axis: Axis.vertical,
      );
      // overflow: none=100, flexible=300. must fit 200. flexible → 100.
      expect(sizes[0].height, 100);
      expect(sizes[1].height, closeTo(100, 0.5));
    });
  });

  // ==========================================================================
  // Regression: flexible finalMain with expanded present
  // ==========================================================================

  group('LinearLayout — regression: flexible finalMain', () {
    testWidgets('flexible gets finalMain = looseMain when expanded present', (tester) async {
      // This was the bug: flexible finalMain defaulted to 0 when hasExpanded=true
      // and no overflow, causing the tab bar to have width 0.
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          _sized(100, 30, rule: LinearLayoutRule.flexible),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      expect(sizes[0].width, 100); // flexible keeps loose
      expect(sizes[1].width, 400); // expanded gets rest
    });

    testWidgets('flexible + expanded overflow: flexible shrink, expanded=0', (tester) async {
      final sizes = await _measureChildren(
        tester,
        parentWidth: 200,
        parentHeight: 40,
        children: [
          _sized(100, 30),
          _sized(300, 30, rule: LinearLayoutRule.flexible),
          _sized(10, 30, rule: LinearLayoutRule.expanded()),
        ],
      );
      // sumNonE = 100 + 300 = 400 > 200. overflow.
      expect(sizes[2].width, 0); // expanded = 0
      expect(sizes[1].width, closeTo(100, 0.5)); // flexible shrink to 200 - 100
    });
  });

  // ==========================================================================
  // Mixed comprehensive
  // ==========================================================================

  group('LinearLayout — mixed rules', () {
    testWidgets('desktop_tabs_page scenario: flexible + expanded spacer + none', (tester) async {
      // tab bar (flexible, content 200) + spacer (expanded, SizedBox.shrink) + actions (none, 50)
      final sizes = await _measureChildren(
        tester,
        parentWidth: 500,
        parentHeight: 40,
        children: [
          LinearLayoutChild(
            rule: LinearLayoutRule.flexible,
            height: 30,
            child: const SizedBox(width: 200, height: 30),
          ),
          LinearLayoutChild(
            rule: LinearLayoutRule.expanded(),
            child: const SizedBox.shrink(),
          ),
          LinearLayoutChild(
            child: const SizedBox(width: 50, height: 30),
          ),
        ],
      );
      // flexible keeps 200, none=50, expanded = 500 - 200 - 50 = 250
      expect(sizes[0].width, 200);
      expect(sizes[1].width, 250);
      expect(sizes[2].width, 50);
      // fixed cross height applies tight constraint.
      expect(sizes[0].height, 30);
    });
  });
}
