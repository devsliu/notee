import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';

import 'code_block_component.dart';

const _kCodeBlockItemId = 'editor.code_block';

bool _showInCodeBlockOrTextType(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isSingle) {
    return false;
  }
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.delta == null) {
    return false;
  }
  if (node.type == CodeBlockKeys.type) {
    return true;
  }
  return onlyShowInSingleSelectionAndTextType(editorState);
}

Future<void> _convertToCodeBlock(EditorState editorState) async {
  final selection = editorState.selection;
  if (selection == null) return;

  final nodes = editorState.getNodesInSelection(selection)
    ..sort((a, b) {
      final len = a.path.length < b.path.length ? a.path.length : b.path.length;
      for (var i = 0; i < len; i++) {
        if (a.path[i] != b.path[i]) return a.path[i].compareTo(b.path[i]);
      }
      return a.path.length.compareTo(b.path.length);
    });
  if (nodes.isEmpty) return;

  if (nodes.length == 1) {
    final node = nodes.first;
    final deltaJson = (node.delta ?? Delta()).toJson();
    await editorState.formatNode(
      selection,
      (n) => n.copyWith(type: CodeBlockKeys.type, attributes: {blockComponentDelta: deltaJson}),
    );
    return;
  }

  final buffer = StringBuffer();
  for (var i = 0; i < nodes.length; i++) {
    final text = nodes[i].delta?.toPlainText() ?? '';
    buffer.write(text);
    if (i < nodes.length - 1) {
      buffer.writeln();
    }
  }

  final firstNode = nodes.first;
  final mergedDelta = Delta()..insert(buffer.toString());

  final transaction = editorState.transaction;
  transaction.insertNode(
    firstNode.path,
    Node(type: CodeBlockKeys.type, attributes: {blockComponentDelta: mergedDelta.toJson()}),
  );

  for (var i = nodes.length - 1; i >= 0; i--) {
    transaction.deleteNode(nodes[i]);
  }

  transaction.afterSelection = Selection.collapsed(Position(path: firstNode.path, offset: mergedDelta.length));

  await editorState.apply(transaction);
}

Future<void> _convertFromCodeBlock(EditorState editorState) async {
  final selection = editorState.selection;
  if (selection == null) return;

  final nodes = editorState.getNodesInSelection(selection);
  if (nodes.isEmpty) return;

  final firstNode = nodes.first;
  final text = firstNode.delta?.toPlainText() ?? '';
  final lines = text.split('\n');

  final transaction = editorState.transaction;
  final newNodes = lines.map((line) {
    return Node(type: ParagraphBlockKeys.type, attributes: {blockComponentDelta: (Delta()..insert(line)).toJson()});
  }).toList();

  transaction.insertNodes(firstNode.path, newNodes);
  transaction.deleteNode(firstNode);

  transaction.afterSelection = Selection.collapsed(
    Position(path: firstNode.path, offset: newNodes.last.delta?.length ?? 0),
  );

  await editorState.apply(transaction);
}

final ToolbarItem codeBlockItem = ToolbarItem(
  id: _kCodeBlockItemId,
  group: 3,
  isActive: _showInCodeBlockOrTextType,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final node = selection != null ? editorState.getNodeAtPath(selection.start.path) : null;
    final isHighlight = node?.type == CodeBlockKeys.type;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.terminal, size: 18, color: isHighlight ? highlightColor : iconColor),
      isHighlight: isHighlight,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () => isHighlight ? _convertFromCodeBlock(editorState) : _convertToCodeBlock(editorState),
    );

    if (tooltipBuilder != null) {
      return tooltipBuilder(context, _kCodeBlockItemId, l10n.codeBlock, child);
    }

    return child;
  },
);
