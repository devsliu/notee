import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/utils/utils.dart';

/// Show an AlertDialog with metadata (uuid, path, version, timestamps...)
/// for the record identified by [recordUuid]. Returns without showing if
/// the record can't be found or the widget is unmounted.
Future<void> showRecordInfoDialog(BuildContext context, String recordUuid, {int? wordCount}) async {
  final record = Repository.get().recordTree.findRecord(recordUuid);
  if (record == null || !context.mounted) return;
  final buffer = StringBuffer()
    ..writeln(record.uuid)
    ..writeln('createAt: ${Utils.formatTime(record.remote.createAt)}')
    ..writeln('editAt: ${Utils.formatTime(record.local.editAt)}')
    ..writeln('version: ${record.local.version}')
    ..writeln('fileEditAt: ${Utils.formatTime(record.local.fileEditAt)}')
    ..writeln('fileVersion: ${record.local.fileVersion}')
    ..writeln('locked: ${record.local.locked}')
    ..writeln('reminder: ${record.local.reminder}')
    ..writeln('tags: ${record.local.tags}')
  //
  ;
  if (wordCount != null) buffer.writeln('${l10n.wordCount}: $wordCount');
  final screenWidth = MediaQuery.of(context).size.width;
  showDialog(
    context: context,
    useRootNavigator: false,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: SizedBox(
          width: math.min(400.0, screenWidth * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${record.local.path}${record.local.name}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(buffer.toString()),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done))],
      );
    },
  );
}
