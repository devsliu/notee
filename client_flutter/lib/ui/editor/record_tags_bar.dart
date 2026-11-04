
import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/tag_tree.dart';
import 'package:notee/ui/editor/record_tags_editor.dart';
import 'package:notee/utils/state_ext.dart';

/// Show the tag editor dialog with a title bar (same pattern as [showReminderDialog]).
void showTagDialog(BuildContext context, String uuid) {
  final record = Repository.get().recordTree.findRecord(uuid);
  if (record == null) return;
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (_) => TagEditor(uuid: uuid, subtitle: '${record.local.path}/${record.local.name}'),
  );
}

/// Compact one-line tag summary bar — same style as [ReminderBar].
/// Shows a `#` icon followed by comma-separated tag names.
/// Tapping opens the tag editor dialog.
class TagBar extends StatefulWidget {
  final String uuid;
  const TagBar({super.key, required this.uuid});

  @override
  State<TagBar> createState() => _TagBarState();
}

class _TagBarState extends BaseState<TagBar> {
  @override
  void initState() {
    super.initState();
    subscribe(Repository.get().tagTree.onEvent, (event) {
      if (event.type == TagTreeEvent.typeRebuild || event.uuid == widget.uuid) {
        if (mounted) safeSetState();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = Repository.get().recordTree.findRecord(widget.uuid);
    final theme = Theme.of(context);
    final tags = record?.tags ?? const <String>[];
    final hasTags = tags.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showTagDialog(context, widget.uuid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.tag_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hasTags ? tags.join(' · ') : l10n.addTag,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasTags ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(120),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
