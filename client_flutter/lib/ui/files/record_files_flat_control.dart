import 'dart:async';

import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/files/record_item_widget.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:notee/config/language_manager.dart';

import 'package:notee/ui/common/breadcrumb_bar.dart';
import 'package:notee/utils/state_ext.dart';

class RecordFilesFlatControl extends StatefulWidget {
  final bool shrink;

  const RecordFilesFlatControl({super.key, required this.shrink});
  @override
  State<RecordFilesFlatControl> createState() => _RecordFilesFlatControlState();
}

class _RecordFilesFlatControlState extends BaseState<RecordFilesFlatControl> {
  final RecordTree recordTree = Repository.get().recordTree;

  @override
  void initState() {
    super.initState();
    subscribe(recordTree.onEvent, (_) => safeSetState());
    listen(RecordOpenedState.get().openedFileNotifier, safeSetState);
    listen(RecordOpenedState.get().openedFolderNotifier, safeSetState);
    listen(Repository.get().syncConfigs.notifier, safeSetState);
    listen(MultiSelectState.instance, safeSetState);
  }

  void onClickFolder(int index, TreeContentFolder folder) {
    RecordOpenedState.get().setOpenedFolder(folder.path);
  }

  void onClickFile(BuildContext context, RecordEntry record) {
    AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${record.uuid}');
  }

  @override
  Widget build(BuildContext context) {
    final folder = RecordOpenedState.get().openedFolder;
    final node = recordTree.findFolder(folder.path);
    final children = node?.children ?? [];
    final count = children.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: BreadcrumbBar(
            path: folder.path,
            onNavigate: RecordOpenedState.get().setOpenedFolder,
            shrink: widget.shrink,
          ),
        ),
        // AppConfig.listViewDivider(context),
        Expanded(
          child: ListView.builder(
            itemCount: count,
            itemBuilder: (BuildContext context, int index) {
              if (count <= index) {
                return Text("${l10n.outOfBounds}$index");
              }
              return buildItemWidget(context, index, children[index] as TreeNode);
            },
            // separatorBuilder: (_, i) => AppConfig.listViewDivider(context),
          ),
        ),
      ],
    );
  }

  Widget buildItemWidget(BuildContext context, int index, TreeNode node) {
    TreeContent file = node.content;
    if (file is TreeContentFile) {
      return FileWidget(
        showIcon: true,
        leftPadding: 14.0,
        rightPadding: 12.0,
        verticalPadding: widget.shrink ? 4.0 : 12.0,
        content: file,
        isSelected: RecordOpenedState.get().openedFile?.key == file.key,
        onClickCallback: (f) {
          Future.delayed(const Duration(milliseconds: 40), () {
            if (context.mounted) onClickFile(context, (f as TreeContentFile).record);
          });
        },
      );
    } else {
      return FolderWidget(
        leftPadding: 14.0,
        rightPadding: 12.0,
        verticalPadding: widget.shrink ? 4.0 : 12.0,
        node: node,
        isSelected: false,
        onClickCallback: (f) {
          Future.delayed(const Duration(milliseconds: 120), () {
            if (context.mounted) onClickFolder(index, f as TreeContentFolder);
          });
        },
        onCreateRecord: (r) {
          onClickFile(context, r);
        },
      );
    }
  }
}
