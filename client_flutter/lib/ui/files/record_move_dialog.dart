import 'dart:math';

import 'package:notee/ui/files/record_folder_picker.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';

import '../../config/language_manager.dart';

class RecordMoveControl extends StatelessWidget {
  final String title;
  final String initFolder;
  final void Function(String folderPath) onConfirm;
  const RecordMoveControl({super.key, required this.title, required this.initFolder, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    GlobalKey<RecordFolderPickerState> folderPickerKey = GlobalKey<RecordFolderPickerState>();

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      width: min(600, width * 0.9),
      height: min(500, height * 0.7),
      child: Padding(
        padding: EdgeInsets.only(left: 0, top: 0, right: 0, bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppEnv.pagePadding,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(height: 8),
            // Record list where the file is located
            Expanded(
              child: RecordFolderPicker(initFolder: initFolder, key: folderPickerKey),
            ),
            Divider(color: Theme.of(context).colorScheme.outline, height: 1),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: Text(l10n.cancel),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                SizedBox(width: 8),
                TextButton(
                  child: Text(l10n.confirm),
                  onPressed: () {
                    var folder = folderPickerKey.currentState?.currentPath;
                    if (folder == null || folder.isEmpty) return;
                    onConfirm(folder);
                    Navigator.pop(context);
                  },
                ),
                SizedBox(width: AppEnv.pageHorizontalPadding),
              ],
            ),
            SizedBox(height: AppEnv.pageVerticalPadding),
          ],
        ),
      ),
    );
  }
}
