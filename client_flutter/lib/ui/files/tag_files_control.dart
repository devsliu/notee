import 'package:flutter/material.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/tag_tree.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/files/record_item_widget.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:notee/utils/state_ext.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Displays tags as expandable tiles, each revealing the records that carry
/// the tag. All tiles are expanded by default.
class TagFilesControl extends StatefulWidget {
  final bool shrink;

  const TagFilesControl({super.key, required this.shrink});

  @override
  State<TagFilesControl> createState() => _TagFilesControlState();
}

/// Tag folder row — same as TreeFolderWidget but suppresses right-click and
/// long-press context menus, since tags are virtual grouping nodes.
class _TagFolderWidget extends TreeFolderWidget {
  _TagFolderWidget({
    required super.node,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    required super.isSelected,
    required super.onClickCallback,
    required super.onCreateRecord,
    super.folderIcon,
  });

  @override
  void onLongClick(BuildContext context, TreeContent file, Offset position) {}
}

/// Tag file row — same as TreeFileWidget but indent matches TreeFolderWidget
/// (no extra arrowSize, since TagFolderWidget uses its own # icon).
class _TagFileWidget extends TreeFileWidget {
  _TagFileWidget({
    super.key,
    required super.node,
    required super.showIcon,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    required super.isSelected,
    required super.onClickCallback,
  });

  @override
  double get intent => (arrowSize + 4.0);
}

class _TagFilesControlState extends BaseState<TagFilesControl> {
  final recordTree = Repository.get().recordTree;
  final TreeViewController _treeController = TreeViewController();

  /// Stable tree nodes. Created once in initState with all tags expanded.
  /// Subsequent refreshes only update children (records), never replace nodes,
  /// so expanded state is preserved.
  List<TreeViewNode<TreeContent>> _tagNodes = const [];

  /// Map of tag name → TreeViewNode, used to find the right node when
  /// refreshing so we can update children in place.
  final Map<String, TreeViewNode<TreeContent>> _nodeByName = {};

  @override
  void initState() {
    super.initState();
    _buildInitialTree();
    subscribe(Repository.get().tagTree.onEvent, _onTagEvent);
    listen(RecordOpenedState.get().openedFileNotifier, safeSetState);
    listen(Repository.get().syncConfigs.notifier, safeSetState);
    listen(MultiSelectState.instance, safeSetState);
  }

  void _onTagEvent(TagTreeEvent event) {
    switch (event.type) {
      case TagTreeEvent.typeRebuild:
        _buildInitialTree();
        break;
      case TagTreeEvent.typeUpsert:
      case TagTreeEvent.typeRemove:
        _syncChildren();
        break;
    }
    if (mounted) safeSetState();
  }

  /// Build the tag tree once. Each tag starts at the expanded state stored on
  /// the Tag object, so state survives State recreation (tab switches etc.).
  void _buildInitialTree() {
    final tags = Repository.get().tagTree.tags;
    final nodes = <TreeViewNode<TreeContent>>[];
    for (final tag in tags) {
      final node = _buildTagNode(tag, expanded: tag.expanded);
      _nodeByName[tag.name] = node;
      nodes.add(node);
    }
    _tagNodes = nodes;
  }

  /// Build a single tag node. Children are freshly created from each RecordEntry
  /// so TagFilesControl doesn't depend on RecordTree's internal TreeContentFile instances.
  TreeViewNode<TreeContent> _buildTagNode(Tag tag, {required bool expanded}) {
    final tagChildren = <TreeViewNode<TreeContent>>[];
    for (final entry in tag.records) {
      tagChildren.add(TreeNode(TreeContentFile(entry)));
    }
    tagChildren.sort((a, b) => a.content.name.compareTo(b.content.name));
    return TreeViewNode<TreeContent>(
      TreeContentFolder('tag:${tag.name}/', tag.name),
      children: tagChildren,
      expanded: expanded,
    );
  }

  /// Refresh children in place for existing tags, add new tags, remove deleted tags.
  void _syncChildren() {
    final tags = Repository.get().tagTree.tags;
    final newNames = <String>{};
    for (final tag in tags) {
      newNames.add(tag.name);
      final existing = _nodeByName[tag.name];
      if (existing != null) {
        // Update children in place; pull expanded state from the live TreeView
        // node so in-flight toggle animations aren't clobbered, and sync it
        // back to Tag for consistency.
        final expanded = existing.isExpanded;
        Repository.get().tagTree.setExpanded(tag.name, expanded);
        // Incremental sync: reuse existing child nodes by uuid, create new ones,
        // drop removed ones.
        final childByUuid = <String, TreeViewNode<TreeContent>>{};
        for (final child in existing.children) {
          final content = child.content;
          if (content is TreeContentFile) {
            childByUuid[content.uuid] = child;
          }
        }
        final newChildren = <TreeViewNode<TreeContent>>[];
        for (final entry in tag.records) {
          final uuid = entry.local.uuid;
          final existingChild = childByUuid.remove(uuid);
          if (existingChild != null) {
            (existingChild.content as TreeContentFile).setLocalRecord(entry);
            newChildren.add(existingChild);
          } else {
            newChildren.add(TreeNode(TreeContentFile(entry)));
          }
        }
        newChildren.sort((a, b) => a.content.name.compareTo(b.content.name));
        existing.children
          ..clear()
          ..addAll(newChildren);
      } else {
        final node = _buildTagNode(tag, expanded: tag.expanded);
        _nodeByName[tag.name] = node;
        _tagNodes.add(node);
      }
    }
    // Remove tags that no longer exist.
    _nodeByName.removeWhere((name, node) {
      if (!newNames.contains(name)) {
        _tagNodes.remove(node);
        return true;
      }
      return false;
    });
  }

  void onClickFile(RecordEntry record) {
    AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${record.uuid}');
  }

  void onClickFolder(TreeContent tag) {
    final node = _treeController.getNodeFor(tag);
    if (node != null) {
      _treeController.toggleNode(node);
      Repository.get().tagTree.setExpanded(tag.name, node.isExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verticalPadding = widget.shrink ? 2.0 : 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return TreeView<TreeContent>(
          tree: _tagNodes,
          controller: _treeController,
          indentation: TreeViewIndentationType.none,
          diagonalDragBehavior: DiagonalDragBehavior.none,
          horizontalDetails: const ScrollableDetails.horizontal(physics: NeverScrollableScrollPhysics()),
          treeNodeBuilder: (context, node, animationStyle) {
            final content = node.content;
            final isFile = content is TreeContentFile;
            final isSelected = RecordOpenedState.get().openedFile?.key == content.key;
            Widget child;
            if (isFile) {
              final tagName = (node.parent?.content as TreeContentFolder?)?.name ?? '';
              child = _TagFileWidget(
                key: ValueKey('tag:$tagName:${content.key}'),
                node: node,
                showIcon: false,
                leftPadding: 8.0,
                rightPadding: 12.0,
                verticalPadding: verticalPadding,
                isSelected: isSelected,
                onClickCallback: (f) => onClickFile((f as TreeContentFile).record),
              );
            } else {
              child = _TagFolderWidget(
                node: node,
                leftPadding: 12.0,
                rightPadding: 12.0,
                verticalPadding: verticalPadding,
                isSelected: false,
                onClickCallback: (t) => onClickFolder(t),
                onCreateRecord: (record) => onClickFile(record),
                folderIcon: Text('#', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              );
            }
            return SizedBox(
              key: ValueKey('${isFile ? 'file' : 'tag'}:${content.key}'),
              width: constraints.maxWidth,
              child: child,
            );
          },
          treeRowBuilder: (node) => TreeRow(extent: FixedTreeRowExtent(24.0 + verticalPadding * 2)),
        );
      },
    );
  }
}
