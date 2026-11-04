import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';

Future<String?> showInputDialog(BuildContext context, String title, String text, bool pass) async {
  return showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (context) => _InputDialog(title: title, initialText: text, obscure: pass),
  );
}

class _InputDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final bool obscure;

  const _InputDialog({required this.title, required this.initialText, required this.obscure});

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    // Owned by this State, so Flutter disposes it only after the dialog route
    // is fully removed from the tree (exit animation finished) — no race.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: Text(l10n.confirm)),
      ],
    );
  }
}
