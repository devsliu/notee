import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/ui/common/popup_menu.dart';

final ToolbarItem tableToolbarItem = ToolbarItem(
  id: 'editor.table',
  group: 20,
  isActive: (_) => false,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    // 查找光标所在的表格节点（若存在）以及当前 cell 的行/列索引
    final selection = editorState.selection;
    Node? tableNode;
    int? colIdx;
    int? rowIdx;
    if (selection != null && selection.isCollapsed) {
      final currentNode = editorState.getNodeAtPath(selection.end.path);
      if (currentNode != null) {
        var n = currentNode;
        while (n.parent != null) {
          if (n.parent!.type == TableBlockKeys.type) {
            tableNode = n.parent;
            colIdx = n.attributes[TableCellBlockKeys.colPosition];
            rowIdx = n.attributes[TableCellBlockKeys.rowPosition];
            break;
          }
          n = n.parent!;
        }
      }
    }

    final child = PopupMenuControl<String>(
      child: SVGIconItemWidget(
        iconBuilder: (_) => Icon(Icons.table_chart_outlined, size: 18, color: iconColor),
        isHighlight: false,
        highlightColor: highlightColor,
        iconColor: iconColor,
      ),
      itemsBuilder: () => _buildTableMenuItems(tableNode),
      onSelected: (value) {
        if (value == null) return;
        _handleTableAction(value, editorState, tableNode, colIdx, rowIdx, selection);
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.table', l10n.table, child);
    }
    return child;
  },
);

List<PopupItem<String>> _buildTableMenuItems(Node? tableNode) {
  if (tableNode == null) {
    return [
      PopupItem.simple(icon: const Icon(Icons.add, size: 18), title: l10n.insertTable, value: 'insert'),
    ];
  }

  final colsLen = tableNode.attributes[TableBlockKeys.colsLen] as int? ?? 1;
  final rowsLen = tableNode.attributes[TableBlockKeys.rowsLen] as int? ?? 1;

  return [
    PopupItem.simple(icon: const Icon(Icons.add, size: 18), title: l10n.rowAdd, value: 'row_add'),
    if (rowsLen > 1) PopupItem.simple(icon: const Icon(Icons.remove, size: 18), title: l10n.rowDelete, value: 'row_del'),
    PopupItem.simple(icon: const Icon(Icons.addchart, size: 18), title: l10n.colAdd, value: 'col_add'),
    if (colsLen > 1) PopupItem.simple(icon: const Icon(Icons.view_column_outlined, size: 18), title: l10n.colDelete, value: 'col_del'),
    PopupItem.simple(icon: const Icon(Icons.delete_forever, size: 18), title: l10n.deleteTable, value: 'table_del'),
  ];
}

Future<void> _handleTableAction(
  String value,
  EditorState editorState,
  Node? tableNode,
  int? colIdx,
  int? rowIdx,
  Selection? selection,
) async {
  switch (value) {
    case 'insert':
      await _insertTable(editorState, selection);
    case 'row_add':
      if (tableNode != null) {
        TableActions.add(tableNode, (rowIdx ?? 0) + 1, editorState, TableDirection.row);
      }
    case 'row_del':
      if (tableNode != null && rowIdx != null) {
        TableActions.delete(tableNode, rowIdx, editorState, TableDirection.row);
      }
    case 'col_add':
      if (tableNode != null) {
        TableActions.add(tableNode, (colIdx ?? 0) + 1, editorState, TableDirection.col);
      }
    case 'col_del':
      if (tableNode != null && colIdx != null) {
        TableActions.delete(tableNode, colIdx, editorState, TableDirection.col);
      }
    case 'table_del':
      if (tableNode != null) {
        final transaction = editorState.transaction..deleteNode(tableNode);
        await editorState.apply(transaction);
      }
  }
}

Future<void> _insertTable(EditorState editorState, Selection? selection) async {
  if (selection == null || !selection.isCollapsed) return;
  final currentNode = editorState.getNodeAtPath(selection.end.path);
  if (currentNode == null) return;

  final tableNode = TableNode.fromList([
    ['', ''],
    ['', ''],
  ]);

  final transaction = editorState.transaction;
  final delta = currentNode.delta;
  if (delta != null && delta.isEmpty) {
    transaction
      ..insertNode(selection.end.path, tableNode.node)
      ..deleteNode(currentNode);
    transaction.afterSelection = Selection.collapsed(Position(path: selection.end.path + [0, 0]));
  } else {
    transaction.insertNode(selection.end.path.next, tableNode.node);
    transaction.afterSelection = Selection.collapsed(Position(path: selection.end.path.next + [0, 0]));
  }
  await editorState.apply(transaction);
}
