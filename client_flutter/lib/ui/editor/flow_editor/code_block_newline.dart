import 'package:appflowy_editor/appflowy_editor.dart';

import 'code_block_component.dart';

final CharacterShortcutEvent codeBlockInsertNewLine = CharacterShortcutEvent(
  key: 'insert newline in code block',
  character: '\n',
  handler: (editorState) async {
    final selection = editorState.selection?.normalized;
    if (selection == null || !selection.isCollapsed) {
      return false;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null || node.type != CodeBlockKeys.type || node.delta == null) {
      return false;
    }

    final transaction = editorState.transaction
      ..insertText(node, selection.startIndex, '\n')
      ..afterSelection = Selection.collapsed(Position(path: selection.start.path, offset: selection.startIndex + 1));
    editorState.apply(transaction);

    return true;
  },
);
