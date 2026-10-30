import 'package:flutter/material.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/common/popup_menu.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/utils.dart';

import '../../config/language_manager.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<AppLogEntry> _allItems = [];
  bool _loading = true;
  String? _filterLevel; // null = all

  List<AppLogEntry> get _items =>
      _filterLevel == null ? _allItems : _allItems.where((e) => e.level == _filterLevel).toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _allItems = await AppLogger.queryAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.loadFailed}: $e')));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearLogs),
        content: Text(l10n.confirmClearLogs),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AppLogger.clear();
      if (mounted) {
        setState(() => _allItems = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.logsCleared)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.clearFailed}: $e')));
      }
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARN':
        return Colors.orange;
      case 'INFO':
        return Colors.blue.shade500;
      case 'DEBUG':
        return Colors.grey;
      default:
        return Colors.black87;
    }
  }

  Widget _filterItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(label, style: TextStyle(color: color)),
    );
  }

  void _showDetail(AppLogEntry item) {
    final color = _levelColor(item.level);
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text('${item.level} · ${item.tag}', style: TextStyle(color: color)),
        content: SingleChildScrollView(
          child: SelectableText(
            '${Utils.formatTime(item.time)}\n\n${item.content}',
            style: TextStyle(color: color, fontSize: 13, height: 1.4),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel))],
      ),
    );
  }

  Widget _buildTitle() {
    final filtered = _filterLevel != null;
    final count = filtered ? '${_items.length}/${_allItems.length}' : '${_allItems.length}';
    final color = filtered ? _levelColor(_filterLevel!) : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterButton(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            count,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton() {
    final color = _filterLevel != null ? _levelColor(_filterLevel!) : null;
    final label = _filterLevel ?? l10n.filterAll;
    return PopupMenuControl<String>(
      onSelected: (v) {
        if (v == null) return;
        final next = v.isEmpty ? null : v;
        if (next != _filterLevel) setState(() => _filterLevel = next);
      },
      items: [
        PopupItem.simple(title: l10n.filterAll, value: ''),
        PopupItem<String>(value: 'ERROR', child: _filterItem('ERROR', Colors.red)),
        PopupItem<String>(value: 'WARN', child: _filterItem('WARN', Colors.orange)),
        PopupItem<String>(value: 'INFO', child: _filterItem('INFO', Colors.blue.shade500)),
        PopupItem<String>(value: 'DEBUG', child: _filterItem('DEBUG', Colors.grey)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.arrow_drop_down, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: createAppBar(
        titleWidget: _buildTitle(),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: '清空', onPressed: _clearLogs),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allItems.isEmpty
          ? Center(child: Text(l10n.noData))
          : _items.isEmpty
          ? Center(child: Text(l10n.noData))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
              itemBuilder: (context, index) {
                final item = _items[index];
                final color = _levelColor(item.level);
                return InkWell(
                  onTap: () => _showDetail(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.level.padRight(5)} ${item.tag}  ${Utils.formatTime(item.time)}',
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
