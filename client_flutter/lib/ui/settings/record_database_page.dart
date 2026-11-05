import 'package:flutter/material.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../config/language_manager.dart';
import 'package:notee/ui/common/toast.dart';

/// Excel-like grid over the raw local_records table: first column (index) and
/// first row (field names) are pinned, body scrolls both directions. Columns
/// use fixed estimated widths; overflow is ellipsized and tapping a cell
/// shows the full value in a dialog.
class RecordDatabasePage extends StatefulWidget {
  const RecordDatabasePage({super.key});

  @override
  State<RecordDatabasePage> createState() => _RecordDatabasePageState();
}

class _RecordDatabasePageState extends State<RecordDatabasePage> {
  static const double _indexColWidth = 44;
  static const double _rowHeight = 26;
  static const _cellPadding = EdgeInsets.symmetric(horizontal: 8);
  static const _cellStyle = TextStyle(fontSize: 11, height: 1.2);

  List<RecordEntry> _items = [];
  bool _loading = true;

  late final List<({String label, double width, String Function(RecordEntry) get})> _columns = [
    (label: 'uuid', width: 125, get: (r) => r.local.uuid),
    (label: 'name', width: 160, get: (r) => r.local.name),
    (label: 'path', width: 80, get: (r) => r.local.path),
    (label: 'createAt', width: 103, get: (r) => '${r.local.createAt}'),
    (label: 'editAt', width: 103, get: (r) => '${r.local.editAt}'),
    (label: 'fileEditAt', width: 103, get: (r) => '${r.local.fileEditAt}'),
    (label: 'fileDirty', width: 65, get: (r) => '${r.local.fileDirty}'),
    (label: 'batchNo', width: 70, get: (r) => '${r.local.batchNo}'),
    (label: 'editType', width: 65, get: (r) => '${r.local.editType}'),
    (label: 'version/remote', width: 95, get: (r) => '${r.local.version}/${r.local.remoteVersion}'),
    (label: 'file/remote/base', width: 110, get: (r) => '${r.local.fileVersion}/${r.remote.fileVersion}/${r.local.baseFileVersion}'),
    (label: 'locked', width: 55, get: (r) => '${r.local.locked}'),
    (label: 'tags', width: 140, get: (r) => r.local.tags),
    (label: 'reminder', width: 140, get: (r) => r.local.reminder),
    (label: 'md5', width: 110, get: (r) => r.local.md5),
    (label: 'remoteJson', width: 220, get: (r) => r.local.remoteJson),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _items = await Repository.get().db?.getAllRecords() ?? [];
    } catch (e) {
      if (mounted) {
        Toast.show(context, '${l10n.loadFailed}: $e');
      }
    }
    setState(() => _loading = false);
  }

  Color _getRowColor(RecordEntry item) {
    if (item.local.editType == LocalEditType.delete) return Colors.red;
    if (item.local.locked != 0) return Colors.orange;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  Color? _mismatchBgColor(RecordEntry item, String label) {
    final l = item.local;
    final mismatch = switch (label) {
      'md5' => l.md5.isNotEmpty && item.remote.md5.isNotEmpty && l.md5.toLowerCase() != item.remote.md5.toLowerCase(),
      'version/remote' => l.version != 0 && l.remoteVersion != 0 && l.version != l.remoteVersion,
      'file/remote/base' =>
        (l.fileVersion != 0 && item.remote.fileVersion != 0 && l.fileVersion != item.remote.fileVersion) ||
        (l.fileVersion != 0 && l.baseFileVersion != 0 && l.fileVersion != l.baseFileVersion),
      _ => false,
    };
    return mismatch ? Theme.of(context).colorScheme.errorContainer.withAlpha(140) : null;
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

  Widget _cell(String label, String text, {Color? color, Color? bgColor, bool bold = false}) {
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
          style: bold ? _cellStyle.copyWith(fontWeight: FontWeight.w600) : _cellStyle.copyWith(color: color),
        ),
      ),
    );
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    final theme = Theme.of(context);
    final headerBg = theme.colorScheme.surfaceContainerHighest.withAlpha(120);

    if (vicinity.row == 0) {
      final label = vicinity.column == 0 ? '#' : _columns[vicinity.column - 1].label;
      return TableViewCell(child: _cell(label, label, bgColor: headerBg, bold: true));
    }
    final item = _items[vicinity.row - 1];
    if (vicinity.column == 0) {
      return TableViewCell(child: _cell('#', '${vicinity.row}'));
    }
    final col = _columns[vicinity.column - 1];
    return TableViewCell(
      child: _cell(col.label, col.get(item), color: _getRowColor(item), bgColor: _mismatchBgColor(item, col.label)),
    );
  }

  TableSpan _buildColumnSpan(int index) {
    return TableSpan(
      extent: FixedTableSpanExtent(index == 0 ? _indexColWidth : _columns[index - 1].width),
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
      appBar: createAppBar(title: '${l10n.database} ${_items.length}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text(l10n.noData))
          : TableView.builder(
              pinnedRowCount: 1,
              pinnedColumnCount: 1,
              columnCount: _columns.length + 1,
              rowCount: _items.length + 1,
              columnBuilder: _buildColumnSpan,
              rowBuilder: _buildRowSpan,
              cellBuilder: _buildCell,
            ),
    );
  }
}
