import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/files/record_folder_picker.dart';
import 'package:notee/utils/utils.dart';

import '../../config/language_manager.dart';

class ReadOnlyFoldersPage extends StatefulWidget {
  const ReadOnlyFoldersPage({super.key});

  @override
  State<ReadOnlyFoldersPage> createState() => _ReadOnlyFoldersPageState();
}

class _ReadOnlyFoldersPageState extends State<ReadOnlyFoldersPage> {
  List<String> _folders = [];
  /// True when the folder list has been modified (added/removed) so we can
  /// trigger an immediate config sync when the page is disposed.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    // Show the local cache immediately, then sync from the server in the
    // background and refresh the UI if anything changed.
    _init();
  }

  Future<void> _init() async {
    await Repository.get().syncConfigs.syncNow();
    if (!mounted) return;
    _loadFolders();
  }

  @override
  void dispose() {
    if (_dirty) {
      // Config-only sync: does not touch syncStateNotifier, so the sync-status
      // banner UI won't rebuild during page disposal.
      Repository.get().syncConfigs.syncNow();
    }
    super.dispose();
  }

  void _loadFolders() {
    final raw = Repository.get().syncConfigs.get(KVConfigs.readOnlyFolders);
    if (raw == null || raw.isEmpty) {
      setState(() => _folders = []);
      return;
    }
    final decoded = jsonDecode(raw);
    setState(() {
      _folders = (decoded as List).whereType<String>().toList();
    });
  }

  Future<void> _saveFolders() async {
    final value = jsonEncode(_folders);
    await Repository.get().syncConfigs.set(KVConfigs.readOnlyFolders, value);
    _dirty = true;
  }

  Future<void> _addFolder() async {
    final folderPickerKey = GlobalKey<RecordFolderPickerState>();
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.9,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: AppEnv.pagePadding,
                child: Text(l10n.readOnlyFolders, style: Theme.of(ctx).textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RecordFolderPicker(initFolder: '/', canCreateFolder: false, key: folderPickerKey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              final path = folderPickerKey.currentState?.currentPath;
              if (path == null || path.isEmpty) return;
              Navigator.pop(ctx, path);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (result == null || _folders.contains(result)) return;

    // If the folder or any ancestor is already read-only, skip adding.
    if (Repository.get().syncConfigs.isPathReadOnly(result)) return;

    setState(() => _folders.add(result));
    await _saveFolders();
  }

  Future<void> _removeFolder(String folder) async {
    setState(() => _folders.remove(folder));
    await _saveFolders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: createAppBar(
        title: l10n.readOnlyFolders,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addFolder),
          SizedBox(width: Utils.isDesktop() ? 4 : AppEnv.pageHorizontalPadding),
        ],
      ),
      body: _folders.isEmpty
          ? Center(child: Text(l10n.noData, style: TextStyle(color: Theme.of(context).colorScheme.outline)))
          : ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (ctx, idx) {
                final folder = _folders[idx];
                return ListTile(
                  contentPadding: EdgeInsets.only(
                    left: AppEnv.pageHorizontalPadding,
                    right: Utils.isDesktop() ? 4 : AppEnv.pageHorizontalPadding,
                  ),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder),
                  
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeFolder(folder),
                  ),
                );
              },
            ),
    );
  }
}
