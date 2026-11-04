import 'package:notee/filesync/http_api.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class ServerApiStatsPage extends StatefulWidget {
  const ServerApiStatsPage({super.key});

  @override
  State<ServerApiStatsPage> createState() => _ServerApiStatsPageState();
}

class _ServerApiStatsPageState extends State<ServerApiStatsPage> {
  static const double _indexColWidth = 35;
  static const double _rowHeight = 26;
  static const _cellPadding = EdgeInsets.symmetric(horizontal: 8);
  static const _cellStyle = TextStyle(fontSize: 11, height: 1.2);

  late Future<List<APIStat>> _futureStats;
  double? _viewportWidth;

  late final List<({String label, double width, String Function(APIStat) get})> _columns = [
    (label: 'apiName', width: 120, get: (r) => r.apiName),
    (label: 'callCount', width: 90, get: (r) => '${r.count}'),
    (label: 'lastCallTime', width: 150, get: (r) => Utils.formatTime(r.lastCallTime)),
  ];

  @override
  void initState() {
    super.initState();
    _futureStats = _loadStats();
  }

  Future<List<APIStat>> _loadStats() async {
    final result = await HttpApi.fetchAPIStats();
    if (result.isSuccess() && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.message);
    }
  }

  void _showCell(String label, String value) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 13)),
        content: SingleChildScrollView(child: SelectableText(value, style: _cellStyle)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel))],
      ),
    );
  }

  Widget _cell(String label, String text, {Color? bgColor, bool bold = false}) {
    return InkWell(
      onTap: () => _showCell(label, text),
      child: Container(
        padding: _cellPadding,
        alignment: Alignment.centerLeft,
        color: bgColor,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: bold ? _cellStyle.copyWith(fontWeight: FontWeight.w600) : _cellStyle,
        ),
      ),
    );
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity, List<APIStat> stats) {
    final headerBg = Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120);

    if (vicinity.row == 0) {
      final label = vicinity.column == 0 ? '#' : _columns[vicinity.column - 1].label;
      return TableViewCell(child: _cell(label, label, bgColor: headerBg, bold: true));
    }
    final item = stats[vicinity.row - 1];
    if (vicinity.column == 0) {
      return TableViewCell(child: _cell('#', '${vicinity.row}'));
    }
    final col = _columns[vicinity.column - 1];
    return TableViewCell(child: _cell(col.label, col.get(item)));
  }

  TableSpan _buildColumnSpan(int index) {
    final fixedWidth = _indexColWidth + _columns.take(_columns.length - 1).fold(0.0, (sum, c) => sum + c.width);
    final lastIndex = _columns.length;
    final extent = (index == lastIndex && _viewportWidth != null)
        ? FixedTableSpanExtent((_viewportWidth! - fixedWidth).clamp(_columns.last.width, double.infinity))
        : FixedTableSpanExtent(index == 0 ? _indexColWidth : _columns[index - 1].width);
    return TableSpan(
      extent: extent,
      foregroundDecoration: TableSpanDecoration(
        border: TableSpanBorder(trailing: BorderSide(color: Theme.of(context).dividerColor.withAlpha(40), width: 0.5)),
      ),
    );
  }

  TableSpan _buildRowSpan(int index) {
    return TableSpan(
      extent: const FixedTableSpanExtent(_rowHeight),
      foregroundDecoration: TableSpanDecoration(
        border: TableSpanBorder(trailing: BorderSide(color: Theme.of(context).dividerColor.withAlpha(40), width: 0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: createAppBar(title: l10n.apiCallStats),
      body: FutureBuilder<List<APIStat>>(
        future: _futureStats,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('${l10n.loadFailed}: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noData));
          }
          final stats = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              _viewportWidth = constraints.maxWidth;
              return TableView.builder(
                pinnedRowCount: 1,
                pinnedColumnCount: 1,
                columnCount: _columns.length + 1,
                rowCount: stats.length + 1,
                columnBuilder: _buildColumnSpan,
                rowBuilder: _buildRowSpan,
                cellBuilder: (context, vicinity) => _buildCell(context, vicinity, stats),
              );
            },
          );
        },
      ),
    );
  }
}
