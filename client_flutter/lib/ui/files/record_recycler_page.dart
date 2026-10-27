import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/utils/state_ext.dart';
import 'package:notee/ui/desktop/desktop_tabs_page.dart';

typedef _FolderGroup = ({String folderPath, int deleteAt, int count, String groupId});

class RecordRecyclerPage extends StatefulWidget {
  final bool showAppBar;
  final ValueCallback<BuildContext>? closeCallback;
  const RecordRecyclerPage({super.key, this.showAppBar = true, this.closeCallback});

  @override
  State<RecordRecyclerPage> createState() => _RecordRecyclerPageState();
}

class _RecordRecyclerPageState extends BaseState<RecordRecyclerPage> implements DesktopTabPageState {
  List<_FolderGroup> _folders = [];
  List<RecycleRecord> _singles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    listen(Repository.get().recyclerCountNotifier, _load);
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Repository.get().getRecycleFolderGroups(),
      Repository.get().getRecycleSingleRecords(),
    ]);
    if (!mounted) return;
    setState(() {
      _folders = results[0] as List<_FolderGroup>;
      _singles = results[1] as List<RecycleRecord>;
      _loading = false;
    });
  }

  @override
  void setInForeground(bool value) {
    if (value) _load();
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- folder card actions ----

  void _folderActions(_FolderGroup folder) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text('📁 ${folder.folderPath}'),
        content: Text('${folder.count} items'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await Repository.get().restoreRecycleGroup(folder.groupId);
              _snack(ok ? l10n.recyclerRestored(folder.folderPath) : l10n.recyclerRestoreFailed);
            },
            icon: const Icon(Icons.restore_outlined),
            label: Text(l10n.restore),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              if (await _confirm(l10n.confirmPurgeRecycler)) {
                await Repository.get().purgeRecycleGroup(folder.groupId);
                _snack(l10n.recyclerPurged);
              }
            },
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            label: Text(l10n.purgeRecyclerItem, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---- single record actions ----

  Future<void> _restoreSingle(RecycleRecord record) async {
    final ok = await Repository.get().restoreRecycleRecord(record.uuid);
    _snack(ok ? l10n.recyclerRestored(record.name) : l10n.recyclerRestoreFailed);
  }

  Future<void> _purgeSingle(RecycleRecord record) async {
    if (!await _confirm(l10n.confirmPurgeRecycler)) return;
    await Repository.get().purgeRecycleRecord(record.uuid);
    _snack(l10n.recyclerPurged);
  }

  void _showActions(RecycleRecord record) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(record.path + record.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreSingle(record);
            },
            icon: const Icon(Icons.restore_outlined),
            label: Text(l10n.restore),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _purgeSingle(record);
            },
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            label: Text(l10n.purgeRecyclerItem, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---- clear all ----

  Future<void> _clear() async {
    if (!await _confirm(l10n.confirmClearRecycler)) return;
    await Repository.get().clearRecycleRecords();
    _snack(l10n.recyclerCleared);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.showAppBar) {
      return SizedBox.expand(
        child: Material(
          color: theme.colorScheme.surface,
          child: Stack(
            children: [
              _buildBody(context),
              if (_folders.isNotEmpty || _singles.isNotEmpty)
                Positioned(
                  right: AppEnv.pageHorizontalPadding,
                  bottom: AppEnv.pageHorizontalPadding,
                  child: FloatingActionButton(
                    onPressed: _clear,
                    tooltip: l10n.clearRecycler,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.delete_sweep_outlined),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: createAppBar(
        onBack: widget.closeCallback != null ? () => widget.closeCallback!(context) : null,
        titleSpacing: 0,
        title: l10n.recycler,
        actions: [
          IconButton(
            onPressed: (_folders.isNotEmpty || _singles.isNotEmpty) ? _clear : null,
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: l10n.clearRecycler,
          ),
          SizedBox(width: AppEnv.pageHorizontalPadding),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_folders.isEmpty && _singles.isEmpty) {
      return Center(
        child: Text(l10n.noData, style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120))),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _folders.length + _singles.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
            itemBuilder: (context, index) {
              if (index < _folders.length) {
                return _buildFolderItem(context, _folders[index]);
              }
              return _buildSingleItem(context, _singles[index - _folders.length]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.recyclerAutoClearHint(Repository.recyclerExpireDays),
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline.withAlpha(180)),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderItem(BuildContext context, _FolderGroup folder) {
    final shrink = Utils.isDesktop();
    return ListTile(
      dense: shrink,
      visualDensity: shrink ? const VisualDensity(vertical: -4) : null,
      onTap: () => _folderActions(folder),
      leading: Icon(Icons.folder_delete_outlined, color: Theme.of(context).colorScheme.primary),
      title: Text(folder.folderPath, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${folder.count} items',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
      ),
      trailing: Text(Utils.formatShortTime(folder.deleteAt)),
    );
  }

  Widget _buildSingleItem(BuildContext context, RecycleRecord record) {
    final shrink = Utils.isDesktop();
    return ListTile(
      dense: shrink,
      visualDensity: shrink ? const VisualDensity(vertical: -4) : null,
      onTap: () => _showActions(record),
      title: Text(record.path + record.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(Utils.formatShortTime(record.deleteAt)),
    );
  }
}

/// Clickable half-row entry shown next to [CalendarTaskItem] on record list pages,
/// with the recycle bin entry count badge.
class RecyclerEntryItem extends StatefulWidget {
  final ValueCallback<BuildContext> onTap;
  const RecyclerEntryItem({super.key, required this.onTap});

  @override
  State<RecyclerEntryItem> createState() => _RecyclerEntryItemState();
}

class _RecyclerEntryItemState extends BaseState<RecyclerEntryItem> {
  @override
  void initState() {
    super.initState();
    listen(Repository.get().recyclerCountNotifier, _onCountChanged);
  }

  void _onCountChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = Repository.get().recyclerCountNotifier.value;
    return InkWell(
      onTap: () => widget.onTap(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(150)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(l10n.recycler, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            if (count > 0) Text('$count', style: TextStyle(fontSize: 14, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
