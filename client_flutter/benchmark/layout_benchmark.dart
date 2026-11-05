import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notee/ui/common/linear_layout.dart';

/// Benchmark: LinearLayout vs Row with 100 children.
///
/// Run: `flutter test benchmark/layout_benchmark.dart`
///
/// Uses pumpWidget to drive full build+layout+paint.

void main() {
  const int N = 100;
  const int ITERATIONS = 500;

  Widget withDir(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child,
      );

  testWidgets('Benchmark LinearLayout vs Row', (tester) async {
    // 放大测试视图, 避免外层 UnconstrainedBox 溢出
    tester.view.physicalSize = const Size(6000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // ignore: avoid_print
    print('\n=== Benchmark: $N children × $ITERATIONS iterations ===\n');
    // ignore: avoid_print
    print('Scenario                      Row(ms)   LL(ms)   Ratio');
    // ignore: avoid_print
    print('-----------------------------+----------+---------+--------');

    Future<void> report({
      required String name,
      required Widget Function() rowBuilder,
      required Widget Function() llBuilder,
      required double tightWidth,
    }) async {
      final rowWidget = () =>
          withDir(UnconstrainedBox(child: SizedBox(width: tightWidth, height: 100, child: rowBuilder())));
      final llWidget = () =>
          withDir(UnconstrainedBox(child: SizedBox(width: tightWidth, height: 100, child: llBuilder())));

      // ---- Row: build once, measure layout-only ----
      await tester.pumpWidget(rowWidget());
      final rowRender = tester.renderObject(find.byType(Row)) as RenderBox;
      for (int i = 0; i < 10; i++) {
        rowRender.markNeedsLayout();
        await tester.pump();
      }
      final swRow = Stopwatch();
      for (int i = 0; i < ITERATIONS; i++) {
        rowRender.markNeedsLayout();
        swRow.start();
        await tester.pump();
        swRow.stop();
      }

      // ---- LL: build once, measure layout-only ----
      await tester.pumpWidget(llWidget());
      final llRender = tester.renderObject(find.byType(LinearLayout)) as RenderBox;
      for (int i = 0; i < 10; i++) {
        llRender.markNeedsLayout();
        await tester.pump();
      }
      final swLL = Stopwatch();
      for (int i = 0; i < ITERATIONS; i++) {
        llRender.markNeedsLayout();
        swLL.start();
        await tester.pump();
        swLL.stop();
      }

      final rowMs = swRow.elapsedMilliseconds / ITERATIONS;
      final llMs = swLL.elapsedMilliseconds / ITERATIONS;
      final ratio = llMs / rowMs;
      // ignore: avoid_print
      print('${name.padRight(31)}'
          '${rowMs.toStringAsFixed(3).padLeft(9)}'
          '${llMs.toStringAsFixed(3).padLeft(9)}'
          '${ratio.toStringAsFixed(2)}x');
    }

    await report(
      name: 'All none  tight=5000',
      rowBuilder: () => Row(children: _list(N)),
      llBuilder: () =>
          LinearLayout(axis: Axis.horizontal, children: _llNone(N)),
      tightWidth: 5000,
    );

    await report(
      name: 'All flex  shrink tight=3000',
      rowBuilder: () => Row(children: _flex(N)),
      llBuilder: () =>
          LinearLayout(axis: Axis.horizontal, children: _llFlex(N)),
      tightWidth: 3000,
    );

    await report(
      name: 'All exp   equal tight=5000',
      rowBuilder: () => Row(children: _exp(N)),
      llBuilder: () =>
          LinearLayout(axis: Axis.horizontal, children: _llExp(N)),
      tightWidth: 5000,
    );
  });
}

List<Widget> _list(int n) => List.generate(n, (i) => _Box(i));
List<Widget> _flex(int n) => List.generate(n, (i) => Flexible(child: _Box(i)));
List<Widget> _exp(int n) => List.generate(n, (i) => Expanded(child: _Box(i)));

List<LinearLayoutChild> _llNone(int n) =>
    List.generate(n, (i) => LinearLayoutChild(child: _Box(i)));
List<LinearLayoutChild> _llFlex(int n) => List.generate(
    n, (i) => LinearLayoutChild(rule: LinearLayoutRule.flexible, child: _Box(i)));
List<LinearLayoutChild> _llExp(int n) => List.generate(
    n, (i) => LinearLayoutChild(rule: LinearLayoutRule.expanded(), child: _Box(i)));

class _Box extends StatelessWidget {
  const _Box(this.index);
  final int index;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 40,
      color: Color(0xFF000000 + (index * 7919) & 0xFFFFFF),
    );
  }
}
