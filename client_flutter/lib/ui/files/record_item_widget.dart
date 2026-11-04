import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/table_record.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/files/record_context_menu.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:flutter/material.dart';
import 'package:notee/utils/utils.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

abstract class _BaseItemWidget extends StatelessWidget {
  final TreeContent content;
  final bool isSelected;
  final double leftPadding;
  final double rightPadding;
  final double verticalPadding;
  final ValueCallback<TreeContent> onClickCallback;

  const _BaseItemWidget({
    super.key,
    required this.onClickCallback,
    required this.content,
    required this.isSelected,
    required this.leftPadding,
    required this.rightPadding,
    required this.verticalPadding,
  });

  void onLongClick(BuildContext context, TreeContent file, Offset position) {}

  void onClick(BuildContext context, TreeContent file) {
    onClickCallback(file);
  }

  final arrowSize = 12.0;
  final iconSize = 16.0;
  final nameSize = 16.0;
  final infoSize = 12.0;

  Widget buildContentWidget(BuildContext context);

  String get name => content.name;

  @override
  Widget build(BuildContext context) {
    final TreeContent file = content;
    Offset? lastTapPosition;
    var theme = Theme.of(context);
    final multi = MultiSelectState.instance;
    // Read-only files cannot be multi-selected.
    final selectable = multi.active &&
        file is TreeContentFile &&
        !Repository.get().syncConfigs.isPathReadOnly(file.path);
    final checked = selectable && multi.selected.contains(file.key);
    return InkWell(
      onTapDown: (details) {
        lastTapPosition = details.globalPosition;
      },
      onTap: () {
        if (selectable) {
          multi.toggle(file.key);
        } else {
          onClick(context, file);
        }
      },
      onSecondaryTapDown: (details) {
        if (selectable) {
          multi.toggle(file.key);
        } else {
          onLongClick(context, file, details.globalPosition);
        }
      },
      onLongPress: () {
        if (selectable) {
          multi.toggle(file.key);
        } else {
          onLongClick(context, file, lastTapPosition ?? Offset.zero);
        }
      },
      hoverColor: theme.colorScheme.primary.withAlpha(50),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(
          left: leftPadding,
          right: rightPadding,
          top: verticalPadding,
          bottom: verticalPadding,
        ),
        color: checked || isSelected ? theme.colorScheme.primary.withAlpha(70) : Colors.transparent,
        child: !selectable
            ? buildContentWidget(context)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: buildContentWidget(context)),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      checked ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                      color: checked ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class FolderWidget extends _BaseItemWidget {
  final TreeViewNode<TreeContent> node;

  final ValueCallback<RecordEntry> onCreateRecord;

  /// Override the folder icon with a fixed widget. When null, uses the
  /// default folder_open/folder_outlined pair that reacts to expand state.
  final Widget? folderIcon;

  FolderWidget({
    super.key,
    required super.isSelected,
    required this.node,
    required super.onClickCallback,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    required this.onCreateRecord,
    this.folderIcon,
  }) : super(content: node.content);

  @override
  void onLongClick(BuildContext context, TreeContent file, Offset position) async {
    showRecordContextMenu(context, file, position, onCreateRecord);
  }

  @override
  Widget buildContentWidget(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: buildFolderWidgets(node),
    );
  }

  List<Widget> buildFolderWidgets(TreeViewNode<TreeContent> node) {
    final readOnly = Repository.get().syncConfigs.isPathReadOnly(node.content.path);
    return [
      folderIcon ??
          Icon(
            readOnly
                ? Icons.folder_off_outlined
                : (node.isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined),
            size: iconSize,
          ),
      const SizedBox(width: 3.0),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: nameSize, textBaseline: TextBaseline.ideographic),
        ),
      ),
      const SizedBox(width: 2.0),

      Opacity(
        opacity: 0.6, // Set 60% opacity
        child: Text("${node.children.length}", style: TextStyle(fontSize: infoSize)),
      ),
    ];
  }
}

class TreeFolderWidget extends FolderWidget {
  TreeFolderWidget({
    super.key,
    required super.isSelected,
    required super.node,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    super.folderIcon,
    required super.onClickCallback,
    required super.onCreateRecord,
  });

  double get intent {
    int depth = node.depth ?? 0;
    double intent = depth * iconSize;
    return intent;
  }

  @override
  Widget buildContentWidget(BuildContext context) {
    final folderWidgets = buildFolderWidgets(node);
    folderWidgets.insert(
      0,
      AnimatedRotation(
        turns: node.isExpanded ? 0.25 : 0.0,
        // Rotate clockwise 90 degrees when expanded (0.25 turns), back to 0 when collapsed
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Icon(
          Icons.chevron_right, // Pure Windows-style right-pointing arrow
          size: arrowSize,
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: intent),
        ...folderWidgets,
      ],
    );
  }
}

class FileWidget extends _BaseItemWidget {
  final bool showIcon;

  const FileWidget({
    super.key,
    required this.showIcon,
    required super.isSelected,
    required super.onClickCallback,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    required super.content,
  });

  @override
  void onLongClick(BuildContext context, TreeContent file, Offset position) {
    showRecordContextMenu(context, file, position, (_) => {});
  }

  @override
  Widget buildContentWidget(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: buildFileWidgets(content as TreeContentFile, showIcon),
    );
  }

  List<Widget> buildFileWidgets(TreeContentFile file, bool showIcon) {
    final locked = file.locked != 0;
    return [
      if (showIcon)
        Icon(
          locked ? Icons.lock : Icons.text_snippet_outlined,
          size: iconSize,
        ),
      if (showIcon) const SizedBox(width: 2.0),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: nameSize, textBaseline: TextBaseline.ideographic),
        ),
      ),
      if (file.record.local.reminder.isNotEmpty) ...[
        const SizedBox(width: 2.0),
        Icon(Icons.notifications, size: 12, color: Colors.blueAccent),
      ],
      if (file.record.local.syncConflict) ...[
        const SizedBox(width: 2.0),
        Icon(Icons.warning, size: 12, color: Colors.red),
      ],
      if (file.record.local.editType == LocalEditType.edit && !file.record.local.syncConflict) ...[
        const SizedBox(width: 2.0),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        ),
      ],
      const SizedBox(width: 1.0),
      Opacity(
        opacity: 0.4,
        child: Text(Utils.formatShortTime(file.editAt), style: TextStyle(fontSize: infoSize)),
      ),
    ];
  }
}

class TreeFileWidget extends FileWidget {
  final TreeViewNode<TreeContent> node;

  TreeFileWidget({
    super.key,
    required super.isSelected,
    required super.onClickCallback,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    required this.node,
    required super.showIcon,
  }) : super(content: node.content);

  double get intent {
    int depth = node.depth ?? 0;
    double intent = depth * iconSize + arrowSize;
    return intent;
  }

  @override
  Widget buildContentWidget(BuildContext context) {
    final widgets = buildFileWidgets(content as TreeContentFile, showIcon);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: intent),
        ...widgets,
      ],
    );
  }
}
