import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';

/// Dialog for editing the tags of a single record. Tags are stored in the
/// pipe-separated format `|a|b|`.
class TagEditor extends StatefulWidget {
  final String uuid;
  final String? subtitle;

  const TagEditor({super.key, required this.uuid, this.subtitle});

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final TextEditingController _controller = TextEditingController();
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadTags() {
    final record = Repository.get().recordTree.findRecord(widget.uuid);
    if (record == null || !mounted) return;
    setState(() {
      _tags = List<String>.from(record.tags);
    });
  }

  Future<void> _save() async {
    final serialized = TagFormat.serialize(_tags);
    await Repository.get().editRecord(widget.uuid, false, DateTime.now().millisecondsSinceEpoch, tags: serialized);
  }

  void _addTag() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_tags.contains(text)) {
      _controller.clear();
      return;
    }
    setState(() {
      _tags.add(text);
      _controller.clear();
    });
    _save();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = math.min(400.0, screenWidth * 0.85);
    final title = Text(l10n.editTags);
    return AlertDialog(
      title: widget.subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const SizedBox(height: 2),
                Text(widget.subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
              ],
            )
          : title,
      content: SizedBox(
        width: maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _tags.map((tag) {
                final chipFg = theme.colorScheme.primary;
                final hoverColor = theme.colorScheme.primary.withAlpha(40);
                return _TagChip(
                  tag: tag,
                  textStyle: TextStyle(fontSize: 12, color: chipFg),
                  hoverColor: hoverColor,
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.tagName,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.add), onPressed: _addTag, tooltip: l10n.addTag),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _addTag();
            Navigator.of(context).pop();
          },
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

class _TagChip extends StatefulWidget {
  final String tag;
  final TextStyle textStyle;
  final Color hoverColor;
  final VoidCallback onDeleted;

  const _TagChip({required this.tag, required this.textStyle, required this.hoverColor, required this.onDeleted});

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onDeleted,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _hover ? widget.hoverColor : Colors.transparent,
            border: Border.all(color: widget.textStyle.color ?? Colors.transparent, width: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.tag, style: widget.textStyle),
              Icon(Icons.close, size: 12, color: widget.textStyle.color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show the tag editor dialog for the record with [uuid].
Future<void> showTagEditor(BuildContext context, {required String uuid}) {
  return showDialog(
    context: context,
    useRootNavigator: false,
    builder: (context) => TagEditor(uuid: uuid),
  );
}
