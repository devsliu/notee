import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/app_env.dart';
import 'package:flutter/material.dart';

class RecordFolderPicker extends StatefulWidget {
  final String initFolder;

  const RecordFolderPicker({super.key, required this.initFolder});

  @override
  State<RecordFolderPicker> createState() => RecordFolderPickerState();
}

class RecordFolderPickerState extends State<RecordFolderPicker> {
  late TextEditingController _pathController;
  late FocusNode _pathFocusNode;
  final RecordTree recordTree = Repository.get().recordTree;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: widget.initFolder);
    _pathFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocusNode.dispose();
    super.dispose();
  }

  String get currentPath {
    return RecordPath.normalizePath(_pathController.text.trim());
  }

  List<String> get _currentFolderNames {
    final folder = recordTree.findFolder(currentPath);
    if (folder == null) return [];
    return folder.children.where((f) => f.content is TreeContentFolder).map((f) => f.content.name).toList();
  }

  void _goUp() {
    String path = currentPath;
    if (path == '/' || path.isEmpty) return;
    final parts = path.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      parts.removeLast();
      setState(() {
        _pathController.text = parts.isEmpty ? '/' : '/${parts.join('/')}/';
      });
    }
  }

  void _enterFolder(String folderName) {
    String path = currentPath;
    if (path == '/') path = '';
    setState(() {
      _pathController.text = '/${(path + folderName).replaceAll(RegExp(r'^/+'), '')}/';
    });
  }

  void _createFolder() {
    String path = currentPath;
    setState(() {
      _pathController.text = '$path${l10n.newFolder}/';
    });
    // Focus path input and select the "New folder" part
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pathFocusNode.requestFocus();
      final text = _pathController.text;
      final newFolderText = l10n.newFolder;
      final idx = text.lastIndexOf(newFolderText);
      if (idx != -1) {
        _pathController.selection = TextSelection(baseOffset: idx, extentOffset: idx + newFolderText.length);
      }
    });
  }

  Widget _buildFolderEdit() {
    return IconButtonTheme(
      data: Theme.of(context).iconButtonTheme,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward_outlined),
            tooltip: l10n.upperLevel,
            onPressed: currentPath == '/' ? null : _goUp,
          ),
          Expanded(
            child: TextField(
              controller: _pathController,
              focusNode: _pathFocusNode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newFolder,
            onPressed: _createFolder,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    final folderNames = _currentFolderNames;
    return ListView.builder(
      itemCount: folderNames.length,
      itemBuilder: (ctx, idx) {
        final name = folderNames[idx];
        return ListTile(
          horizontalTitleGap: 8,
          minLeadingWidth: 0,
          contentPadding: EdgeInsets.only(
            left: AppEnv.pageHorizontalPadding, right: AppEnv.pageHorizontalPadding,
          ),
          leading: const Icon(Icons.folder_outlined, size: 20),
          title: Text(name),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _enterFolder(name),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top action bar
        _buildFolderEdit(),
        Divider(color: Theme.of(context).colorScheme.outline),
        // Folder list
        Expanded(child: _buildFolderList()),
      ],
    );
  }
}
