import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/ui/editor/flow_editor/toolbar_item_with_menu.dart';

ToolbarItem get tableToolbarItem => buildToolbarItemWithMenu(
  id: 'editor.table',
  group: 20,
  icon: const Icon(Icons.table_chart_outlined),
  tooltip: l10n.table,
  children: _tableChildren,
);

List<ToolbarItem> get _tableChildren => [
  _tableActionItem(
    id: 'table.insert',
    label: l10n.insertTable,
    icon: Icons.add,
    showWhenNoTable: true,
    onAction: (es, info) => _insertTable(es, es.selection),
  ),
  _tableActionItem(
    id: 'table.row_add',
    label: l10n.rowAdd,
    icon: Icons.add,
    onAction: (es, info) async {
      if (info.tableNode != null) {
        TableActions.add(info.tableNode!, (info.rowIdx ?? 0) + 1, es, TableDirection.row);
      }
    },
  ),
  _tableActionItem(
    id: 'table.row_del',
    label: l10n.rowDelete,
    icon: Icons.remove,
    minRows: 2,
    onAction: (es, info) async {
      if (info.tableNode != null && info.rowIdx != null) {
        TableActions.delete(info.tableNode!, info.rowIdx!, es, TableDirection.row);
      }
    },
  ),
  _tableActionItem(
    id: 'table.col_add',
    label: l10n.colAdd,
    icon: Icons.addchart,
    onAction: (es, info) async {
      if (info.tableNode != null) {
        TableActions.add(info.tableNode!, (info.colIdx ?? 0) + 1, es, TableDirection.col);
      }
    },
  ),
  _tableActionItem(
    id: 'table.col_del',
    label: l10n.colDelete,
    icon: Icons.view_column_outlined,
    minCols: 2,
    onAction: (es, info) async {
      if (info.tableNode != null && info.colIdx != null) {
        TableActions.delete(info.tableNode!, info.colIdx!, es, TableDirection.col);
      }
    },
  ),
  _tableActionItem(
    id: 'table.table_del',
    label: l10n.deleteTable,
    icon: Icons.delete_forever,
    onAction: (es, info) async {
      if (info.tableNode != null) {
        final transaction = es.transaction..deleteNode(info.tableNode!);
        await es.apply(transaction);
      }
    },
  ),
];

/// Table 菜单项的上下文信息，由 builder 从当前 editorState 提取
class _TableInfo {
  _TableInfo({this.tableNode, this.colIdx, this.rowIdx});
  final Node? tableNode;
  final int? colIdx;
  final int? rowIdx;
}

_TableInfo _findTableInfo(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) return _TableInfo();
  final currentNode = editorState.getNodeAtPath(selection.end.path);
  if (currentNode == null) return _TableInfo();
  var n = currentNode;
  while (n.parent != null) {
    if (n.parent!.type == TableBlockKeys.type) {
      return _TableInfo(
        tableNode: n.parent,
        colIdx: n.attributes[TableCellBlockKeys.colPosition],
        rowIdx: n.attributes[TableCellBlockKeys.rowPosition],
      );
    }
    n = n.parent!;
  }
  return _TableInfo();
}

/// 构建一个表格菜单项。popup 打开时动态计算可见性：
/// - 默认只在光标位于表格内时显示（tableNode != null）
/// - [showWhenNoTable] 为 true 时，无表格时才显示（如「插入表格」）
/// - [minRows]/[minCols] 要求表格行/列数达到阈值才显示
ToolbarItem _tableActionItem({
  required String id,
  required String label,
  required IconData icon,
  required Future<void> Function(EditorState es, _TableInfo info) onAction,
  bool showWhenNoTable = false,
  int? minRows,
  int? minCols,
}) {
  return ToolbarItem(
    id: id,
    group: 0,
    tooltipsMessage: label,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final info = _findTableInfo(editorState);
      final hasTable = info.tableNode != null;

      // 可见性判断
      if (showWhenNoTable) {
        if (hasTable) return const SizedBox.shrink();
      } else {
        if (!hasTable) return const SizedBox.shrink();
        if (minRows != null) {
          final rowsLen = info.tableNode!.attributes[TableBlockKeys.rowsLen] as int? ?? 1;
          if (rowsLen < minRows) return const SizedBox.shrink();
        }
        if (minCols != null) {
          final colsLen = info.tableNode!.attributes[TableBlockKeys.colsLen] as int? ?? 1;
          if (colsLen < minCols) return const SizedBox.shrink();
        }
      }

      return SVGIconItemWidget(
        iconBuilder: (_) => Icon(icon, size: 18, color: iconColor),
        isHighlight: false,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () async => onAction(editorState, info),
      );
    },
  );
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
