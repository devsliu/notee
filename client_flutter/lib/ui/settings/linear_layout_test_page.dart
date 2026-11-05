import 'package:flutter/material.dart';

import '../common/linear_layout.dart';

/// Visual test page for [LinearLayout].
///
/// Covers every rule path: infinite, has expanded (surplus / overflow),
/// no-expanded+tight (grow / shrink), no-expanded+loose (grow / shrink),
/// zero-size flexibles, all-zero flexibles, weightSum=0.
class LinearLayoutTestPage extends StatefulWidget {
  const LinearLayoutTestPage({super.key});

  @override
  State<LinearLayoutTestPage> createState() => _LinearLayoutTestPageState();
}

class _LinearLayoutTestPageState extends State<LinearLayoutTestPage> {
  bool _running = false;

  static const int N = 100;
  static const int WARMUP = 5;
  static const int RUNS = 20;

  static Widget _rowNone() => Row(
        mainAxisSize: MainAxisSize.max,
        children: List.generate(N, (_) => const SizedBox(width: 50, height: 50)),
      );
  static Widget _rowFlexible() => Row(
        mainAxisSize: MainAxisSize.max,
        children: List.generate(
            N, (_) => const Flexible(child: SizedBox(width: 50, height: 50))),
      );
  static Widget _rowExpanded() => Row(
        mainAxisSize: MainAxisSize.max,
        children: List.generate(
            N, (_) => const Expanded(child: SizedBox(width: 50, height: 50))),
      );
  static Widget _rowMixed() => Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          ...List.generate(
              50, (_) => const Expanded(child: SizedBox(width: 50, height: 50))),
          ...List.generate(
              50, (_) => const SizedBox(width: 50, height: 50)),
        ],
      );

  static Widget _llNone() => LinearLayout(
        axis: Axis.horizontal,
        children: List.generate(
            N, (_) => LinearLayoutChild(child: const SizedBox(width: 50, height: 50))),
      );
  static Widget _llFlexible() => LinearLayout(
        axis: Axis.horizontal,
        children: List.generate(
            N,
            (_) => LinearLayoutChild(
                rule: LinearLayoutRule.flexible,
                child: const SizedBox(width: 50, height: 50))),
      );
  static Widget _llExpanded() => LinearLayout(
        axis: Axis.horizontal,
        children: List.generate(
            N,
            (_) => LinearLayoutChild(
                rule: LinearLayoutRule.expanded(),
                child: const SizedBox(width: 50, height: 50))),
      );
  static Widget _llMixed() => LinearLayout(
        axis: Axis.horizontal,
        children: [
          ...List.generate(
              50,
              (_) => LinearLayoutChild(
                  rule: LinearLayoutRule.expanded(),
                  child: const SizedBox(width: 50, height: 50))),
          ...List.generate(
              50, (_) => LinearLayoutChild(child: const SizedBox(width: 50, height: 50))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LinearLayout Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ElevatedButton(
              onPressed: _running ? null : _benchmark,
              child: Text(_running ? 'Running...' : '▶ Benchmark Row vs LL'),
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Text('N=$N 每个场景 layout $RUNS 次取平均, 看控制台输出'),
            ),
          ),
          _section('① Infinite — loose all, rules ignored',
              UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 40,
                  child: LinearLayout(
                    axis: Axis.horizontal,
                    children: [
                      _box('A 80', w: 80),
                      _box('B flex 60', w: 60, rule: LinearLayoutRule.flexible),
                      _box('C exp 40', w: 40, rule: LinearLayoutRule.expanded()),
                      _box('D 50', w: 50),
                    ],
                  ),
                ),
              )),
          _spacer(),
          _section('② Tight 100 + Expanded — sumNonE=40, E w=1 gets 60',
              SizedBox(
                width: 100, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 40', w: 40),
                    _box('E w=1', w: 20, rule: LinearLayoutRule.expanded()),
                  ],
                ),
              )),
          _spacer(),
          _section('③ Tight 100 + Expanded overflow — sumNonE=120>100, E=0, F shrinks',
              SizedBox(
                width: 100, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 70', w: 70),
                    _box('F 30', w: 30, rule: LinearLayoutRule.flexible),
                    _box('F 20', w: 20, rule: LinearLayoutRule.flexible),
                    _box('E w=1', w: 10, rule: LinearLayoutRule.expanded()),
                  ],
                ),
              )),
          _spacer(),
          _section('④ Tight 100 + Expanded — weightSum=0, E 平分 remaining',
              SizedBox(
                width: 100, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 40', w: 40),
                    _box('E w=0', w: 10, rule: LinearLayoutRule.expanded(weight: 0)),
                    _box('E w=0', w: 10, rule: LinearLayoutRule.expanded(weight: 0)),
                  ],
                ),
              )),
          _spacer(),
          _section('⑤ Tight 100 + No Expanded — sum=90<100, F 等比放大 → 36+24',
              SizedBox(
                width: 100, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 40', w: 40),
                    _box('F 30', w: 30, rule: LinearLayoutRule.flexible),
                    _box('F 20', w: 20, rule: LinearLayoutRule.flexible),
                  ],
                ),
              )),
          _spacer(),
          _section('⑥ Tight 100 + No Expanded — sum=120>100, F 等比缩小 → 18+12',
              SizedBox(
                width: 100, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 70', w: 70),
                    _box('F 30', w: 30, rule: LinearLayoutRule.flexible),
                    _box('F 20', w: 20, rule: LinearLayoutRule.flexible),
                  ],
                ),
              )),
          _spacer(),
          _section('⑦ Tight 90 + No Expanded — N70+F0+F30=100>90, F 缩至 0+20',
              SizedBox(
                width: 90, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 70', w: 70),
                    _box('F 0', w: 0, rule: LinearLayoutRule.flexible),
                    _box('F 30', w: 30, rule: LinearLayoutRule.flexible),
                  ],
                ),
              )),
          _spacer(),
          _section('⑧ Tight 100 + No Expanded — N60+F0+F0=60<100, F 全0 平分 → 20+20',
              SizedBox(
                width: 100, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('N 60', w: 60),
                    _box('F 0', w: 0, rule: LinearLayoutRule.flexible),
                    _box('F 0', w: 0, rule: LinearLayoutRule.flexible),
                  ],
                ),
              )),
          _spacer(),
          _section('⑨ Vertical Tight 150 + Expanded — E w=2:1 分剩余',
              SizedBox(
                width: 200, height: 150,
                child: LinearLayout(
                  axis: Axis.vertical,
                  children: [
                    _boxH('N 30', h: 30),
                    _boxH('E w=2', h: 20, rule: LinearLayoutRule.expanded(weight: 2)),
                    _boxH('E w=1', h: 20, rule: LinearLayoutRule.expanded(weight: 1)),
                  ],
                ),
              )),
          _spacer(),
          _section('⑩ All none — 50+50+50=150>120, overflow 原样排列',
              SizedBox(
                width: 120, height: 40,
                child: LinearLayout(
                  axis: Axis.horizontal,
                  children: [
                    _box('A 50', w: 50),
                    _box('B 50', w: 50),
                    _box('C 50', w: 50),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _benchmark() async {
    setState(() => _running = true);

    final scenarios = <_Scenario>[
      _Scenario('All none, tight=5000', _rowNone, _llNone),
      _Scenario('All flexible, tight=5000', _rowFlexible, _llFlexible),
      _Scenario('All expanded, tight=5000', _rowExpanded, _llExpanded),
      _Scenario('Mixed 50exp+50none, tight=5000', _rowMixed, _llMixed),
    ];

    print('\n========== Row vs LinearLayout  (N=$N) ==========');
    for (final s in scenarios) {
      final rowUs = await _measure(s.row);
      final llUs = await _measure(s.ll);
      final ratio = llUs / rowUs;
      print('${s.name.padRight(30)}| Row: ${rowUs.toString().padLeft(6)}µs | LL: ${llUs.toString().padLeft(6)}µs | ${ratio.toStringAsFixed(2)}x');
    }
    print('=================================================\n');

    if (mounted) setState(() => _running = false);
  }

  Future<int> _measure(Widget Function() builder) async {
    for (var i = 0; i < WARMUP; i++) {
      await _pumpAndSettle(builder());
    }
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < RUNS; i++) {
      await _pumpAndSettle(builder());
    }
    stopwatch.stop();
    return (stopwatch.elapsedMicroseconds / RUNS).round();
  }

  Future<void> _pumpAndSettle(Widget child) async {
    final entry = OverlayEntry(
      builder: (_) => Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 5000,
            height: 100,
            child: child,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    await Future.delayed(const Duration(milliseconds: 16));
    entry.remove();
  }

  Widget _section(String title, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade200,
          ),
          child: ClipRect(child: body),
        ),
      ],
    );
  }

  Widget _spacer() => const SizedBox(height: 20);

  static LinearLayoutChild _box(String label,
      {double w = 40,
      LinearLayoutRule rule = LinearLayoutRule.none}) {
    return LinearLayoutChild(
      rule: rule,
      child: Container(
        width: w,
        height: 32,
        alignment: Alignment.center,
        color: _color(rule),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }

  static LinearLayoutChild _boxH(String label,
      {double h = 30,
      LinearLayoutRule rule = LinearLayoutRule.none}) {
    return LinearLayoutChild(
      rule: rule,
      child: Container(
        width: 180,
        height: h,
        alignment: Alignment.center,
        color: _color(rule),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }

  static Color _color(LinearLayoutRule rule) {
    return rule.when(
      none: () => Colors.blue,
      flexible: () => Colors.orange,
      expanded: (_) => Colors.green,
    );
  }
}

class _Scenario {
  _Scenario(this.name, this.row, this.ll);
  final String name;
  final Widget Function() row;
  final Widget Function() ll;
}
