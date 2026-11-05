import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';

/// 单行输入框的配置
class InputLine {
  const InputLine({
    this.placeholder,
    this.initialText = '',
    this.obscure = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    // 校验器：返回 null 表示通过，否则返回错误文案。
    // [allValues] 为当前所有输入行的值快照（按 lines 顺序）。
    // [index] 为当前行索引，方便跨行比对（如两次密码一致校验）。
    this.validator,
  });

  final String? placeholder;
  final String initialText;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final String? Function(String value, List<String> allValues, int index)? validator;
}

/// 多行输入对话框。返回 [lines.length] 长度的字符串列表，取消返回 null。
Future<List<String>?> showInputDialogs(
  BuildContext context, {
  required String title,
  required List<InputLine> lines,
}) async {
  return showDialog<List<String>>(
    context: context,
    useRootNavigator: false,
    builder: (context) => _MultiInputDialog(title: title, lines: lines),
  );
}

/// 单行输入对话框（便捷封装，返回一个 String）
Future<String?> showInputDialog(
  BuildContext context,
  String title,
  String text,
  bool pass, {
  String? placeholder,
}) async {
  final result = await showInputDialogs(
    context,
    title: title,
    lines: [
      InputLine(
        initialText: text,
        obscure: pass,
        autofocus: true,
        placeholder: placeholder,
        textInputAction: TextInputAction.done,
      ),
    ],
  );
  return result?.first;
}

class _MultiInputDialog extends StatefulWidget {
  const _MultiInputDialog({required this.title, required this.lines});

  final String title;
  final List<InputLine> lines;

  @override
  State<_MultiInputDialog> createState() => _MultiInputDialogState();
}

class _MultiInputDialogState extends State<_MultiInputDialog> {
  late final List<TextEditingController> _controllers;
  late final List<String?> _errors;

  @override
  void initState() {
    super.initState();
    _controllers = widget.lines.map((l) => TextEditingController(text: l.initialText)).toList();
    _errors = List.filled(widget.lines.length, null);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = _controllers.map((c) => c.text.trim()).toList();
    bool hasError = false;
    for (var i = 0; i < widget.lines.length; i++) {
      final err = widget.lines[i].validator?.call(values[i], values, i);
      _errors[i] = err;
      if (err != null) hasError = true;
    }
    // 第一行非空是基本要求（兼容旧调用）
    if (values.first.isEmpty) {
      _errors[0] = _errors[0] ?? l10n.cancel; // 只是标记，UI 上没 label 也不会太明显
      hasError = true;
    }
    setState(() {});
    if (!hasError) Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            TextField(
              controller: _controllers[i],
              autofocus: widget.lines[i].autofocus,
              obscureText: widget.lines[i].obscure,
              keyboardType: widget.lines[i].keyboardType,
              textInputAction: widget.lines[i].textInputAction ??
                  (i < widget.lines.length - 1 ? TextInputAction.next : TextInputAction.done),
              maxLines: widget.lines[i].maxLines,
              decoration: InputDecoration(
                labelText: widget.lines[i].placeholder,
                errorText: _errors[i],
              ),
              onSubmitted: (_) {
                if (i == widget.lines.length - 1) _submit();
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}
