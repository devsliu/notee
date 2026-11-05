import 'dart:async';

import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/files/record_item_widget.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:notee/utils/state_ext.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class RecordFilesTreeControl extends StatefulWidget {
  final bool shrink;

  const RecordFilesTreeControl({super.key, required this.shrink});

  @override
  State<RecordFilesTreeControl> createState() => _RecordFilesTreeControlState();

  double get verticalPadding2 => shrink ? 2.00 : 8.0;
}

class _RecordFilesTreeControlState extends BaseState<RecordFilesTreeControl> {
  final RecordTree recordTree = Repository.get().recordTree;

  final TreeViewController _treeController = TreeViewController();

  /// Convert RecordTree to recursive TreeViewNode structure

  void onFolderChanged() {
    Timer.run(() {
      final folder = RecordOpenedState.get().openedFolder;
      var treeViewNode = _treeController.getNodeFor(folder);
      if (treeViewNode == null) return;
      while (treeViewNode != null) {
        if (!_treeController.isExpanded(treeViewNode) && _treeController.isActive(treeViewNode)) {
          _treeController.expandNode(treeViewNode);
        }
        treeViewNode = treeViewNode.parent;
      }
    });
  }

  void onCollapseAll() {
    _treeController.collapseAll();
  }

  @override
  void initState() {
    super.initState();
    subscribe(recordTree.onEvent, (_) => safeSetState());
    listen(RecordOpenedState.get().openedFolderNotifier, onFolderChanged);
    listen(RecordOpenedState.get().openedFileNotifier, safeSetState);
    listen(Repository.get().syncConfigs.notifier, safeSetState);
    listen(MultiSelectState.instance, safeSetState);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TreeView<TreeContent>(
          tree: recordTree.children,
          controller: _treeController,
          indentation: TreeViewIndentationType.none,
          diagonalDragBehavior: DiagonalDragBehavior.none,
          horizontalDetails: const ScrollableDetails.horizontal(physics: NeverScrollableScrollPhysics()),
          onNodeToggle: (TreeViewNode<TreeContent> node) {
            if (node.content is TreeContentFolder) {
              // _treeController.toggleNode(node);
              // node.isExpanded = node.isExpanded;
            }
          },
          treeNodeBuilder: (context, node, animationStyle) {
            return buildItemWidget(context, node, constraints.maxWidth);
          },
          treeRowBuilder: (node) => TreeRow(extent: FixedTreeRowExtent(24.0 + widget.verticalPadding2 * 2)),
        );
      },
    );
  }

  void onClickFolder(TreeContentFolder folder) {
    final treeViewNode = _treeController.getNodeFor(folder);
    if (treeViewNode != null) {
      _treeController.toggleNode(treeViewNode);
      if (!treeViewNode.isExpanded) {
        RecordOpenedState.get().setOpenedFolder(folder.dir);
      } else {
        RecordOpenedState.get().setOpenedFolder(folder.path);
      }
    }
  }

  void onClickFile(RecordEntry record) {
    AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${record.uuid}');
  }

  Widget buildItemWidget(BuildContext context, TreeViewNode<TreeContent> node, double width) {
    final TreeContent file = node.content;
    final isSelected = RecordOpenedState.get().openedFile?.key == file.key;
    Widget child = (file is TreeContentFile)
        ? TreeFileWidget(
            node: node,
            leftPadding: 8.0,
            rightPadding: 12.0,
            verticalPadding: widget.verticalPadding2,
            showIcon: true,
            isSelected: isSelected,
            onClickCallback: (f) => onClickFile((f as TreeContentFile).record),
          )
        : TreeFolderWidget(
            node: node,
            leftPadding: 8.0,
            rightPadding: 12.0,
            verticalPadding: widget.verticalPadding2,
            isSelected: isSelected,
            onClickCallback: (f) => onClickFolder(f as TreeContentFolder),
            onCreateRecord: (r) => onClickFile(r),
          ); // 👈 Don't forget to add semicolon at the end!

    return SizedBox(
      key: file is TreeContentFile ? ValueKey("file:${file.key}${file.editAt}") : ValueKey("folder:${file.key}"),
      width: width,
      child: child,
    );
  }
}
