import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/utils/state_ext.dart';

/// A compact footer bar showing the last-modify time, version, and optional
/// conflict label for the record identified by [uuid]. Automatically
/// rebuilds on record tree events that touch this uuid.
class RecordModifyTimeBar extends StatefulWidget {
  final String uuid;
  const RecordModifyTimeBar({super.key, required this.uuid});

  @override
  State<RecordModifyTimeBar> createState() => _RecordModifyTimeBarState();
}

class _RecordModifyTimeBarState extends BaseState<RecordModifyTimeBar> {
  @override
  void initState() {
    super.initState();
    subscribe(Repository.get().recordTree.onEvent, _onEvent);
  }

  void _onEvent(RecordEvent event) {
    final isRebuild = event.rebuildRecords != null;
    final isMine =
        (event.deleteRecords?.contains(widget.uuid) ?? false) ||
        (event.upsertRecords?.any((r) => r.local.uuid == widget.uuid) ?? false);
    if (!isRebuild && !isMine) return;
    if (mounted) safeSetState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = Repository.get().recordTree.findRecord(widget.uuid);
    if (record == null) return const SizedBox.shrink();
    final local = record.local;
    final hasConflict = local.syncConflict;
    final color = hasConflict ? theme.colorScheme.error : theme.colorScheme.onSurface.withAlpha(150);
    final conflictLabel = hasConflict ? "  [${l10n.hasConflict}]" : "";
    final version = local.version != local.remoteVersion
        ? 'v${local.version}->v${local.remoteVersion}'
        : 'v${local.version}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        " $version $conflictLabel ${l10n.lastModify}: ${Utils.formatTime(local.editAt)}",
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}
