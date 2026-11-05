import 'package:notee/filesync/record_tree.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/files/record_item_widget.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/utils/state_ext.dart';

class RecordFilesListControl extends StatefulWidget {
  final bool showDivider;
  final bool shrink;

  const RecordFilesListControl({
    super.key,
    required this.shrink,
    this.showDivider = false,
  });
  @override
  State<RecordFilesListControl> createState() => _RecordFilesListControlState();
}

class _RecordFilesListControlState extends BaseState<RecordFilesListControl> {
  final RecordTree recordTree = Repository.get().recordTree;
  @override
  void initState() {
    super.initState();
    subscribe(recordTree.onEvent, (_) => safeSetState());
    listen(RecordOpenedState.get().openedFileNotifier, safeSetState);
    listen(Repository.get().syncConfigs.notifier, safeSetState);
    listen(MultiSelectState.instance, safeSetState);
  }

  @override
  Widget build(BuildContext context) {
    final list = recordTree.sortedFiles;
    final count = list.length;

    return ListView.separated(
      itemCount: count,
      itemBuilder: (BuildContext context, int index) {
        if (count <= index) {
          return Text("${l10n.outOfBounds}$index");
        }
        TreeContentFile file = list[index];

        return FileWidget(
          showIcon: false,
          leftPadding: 14.0,
          rightPadding: 12.0,
          verticalPadding: widget.shrink ? 4.0 : 10.0,
          content: list[index],
          isSelected: RecordOpenedState.get().openedFile?.key == file.key,
          onClickCallback: (file) {
            AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${(file as TreeContentFile).uuid}');
          },
        );
      },
      separatorBuilder: (_, i) => widget.showDivider ? AppEnv.listViewDivider(context) : SizedBox.shrink(),
    );
  }
}
