import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:notee/model/record_utils.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/common/input_dialog.dart';
import 'package:notee/ui/common/popup_menu.dart';
import 'package:notee/ui/files/record_io.dart';
import 'package:notee/ui/settings/theme_selector_dialog.dart';

import '../../utils/utils.dart';

/// Static action helpers shared by the record list page.
/// Actions are distributed between the top app bar (title, new note/folder,
/// parent, collapse) and the left side rail (sort, import/export).
class RecordListActions {
  static List<PopupItem<String>> _noteListMenuItems() => [
    PopupItem.simple(
      icon: const Icon(Icons.folder_outlined),
      title: l10n.sortTypeFlatFolder,
      value: FilesPanelMode.filesTypeFlat,
    ),
    PopupItem.simple(
      icon: const Icon(Icons.account_tree_outlined),
      title: l10n.sortTypeTreeFolder,
      value: FilesPanelMode.filesTypeTree,
    ),
    PopupItem.simple(
      icon: const Icon(Icons.sort_by_alpha_outlined),
      title: l10n.sortTypeName,
      value: FilesPanelMode.filesTypeName,
    ),
    PopupItem.simple(
      icon: const Icon(Icons.timer_outlined),
      title: l10n.sortTypeTime,
      value: FilesPanelMode.filesTypeTime,
    ),
  ];

  /// Calendar button: opens the calendar page, shows today's reminder count.
  static Widget calendarButton(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().reminderTree.countNotifier,
      builder: (context, count, _) {
        return _TabButton(
          label: l10n.calendar,
          count: count,
          onTap: () => AppNavigator.of(context).navigate(AppNavigator.uriCalendar),
        );
      },
    );
  }

  /// AllRecords tab button: click to switch to the records panel. Shows the total
  /// note count.
  static Widget allRecordsButton(BuildContext context) {
    final recordTree = Repository.get().recordTree;
    return ListenableBuilder(
      listenable: Listenable.merge([recordTree.countNotifier, AppEnv.filesPanelModeNotifier]),
      builder: (context, _) {
        return _TabButton(
          label: l10n.allRecords,
          active: AppEnv.listPageValue.panelMode == FilesPanelMode.panelModeList,
          count: max(0, recordTree.countNotifier.value),
          onTap: () => AppEnv.setFilesPanelMode(FilesPanelMode.panelModeList),
        );
      },
    );
  }

  /// Tags tab button: click to switch to the tags panel. Shows the total tag
  /// count.
  static Widget tagsButton(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Repository.get().tagTree.tagCountNotifier, AppEnv.filesPanelModeNotifier]),
      builder: (context, _) {
        return _TabButton(
          label: l10n.tags,
          active: AppEnv.listPageValue.panelMode == FilesPanelMode.panelModeTag,
          count: Repository.get().tagTree.tagCountNotifier.value,
          onTap: () => AppEnv.setFilesPanelMode(FilesPanelMode.panelModeTag),
        );
      },
    );
  }

  /// View toggle button on the bottom bar. Shows the records list view/sort
  /// options when the AllRecords tab is active, or the tags tree/flat toggle
  /// when the Tags tab is active.
  static Widget viewToggleButton(BuildContext context) {
    return ValueListenableBuilder<FilesPanelMode>(
      valueListenable: AppEnv.filesPanelModeNotifier,
      builder: (context, _, _) {
        if (AppEnv.listPageValue.panelMode == FilesPanelMode.panelModeTag) return SizedBox.shrink();
        return PopupMenuControl<String>(
          itemsBuilder: _noteListMenuItems,
          onSelected: (value) {
            if (value == null) return;
            AppEnv.setFilesPanelModeListType(value);
            Repository.get().recordTree.setSortListType(AppEnv.listPageValue.sortType);
            RecordOpenedState.get().setOpenedFolder("/");
          },
          child: Icon(_listTypeIcon(AppEnv.listPageValue.listFilesType), color: Theme.of(context).appBarIconColor),
        );
      },
    );
  }

  static IconData _listTypeIcon(String type) {
    if (type == FilesPanelMode.filesTypeFlat) return Icons.folder_outlined;
    if (type == FilesPanelMode.filesTypeName) return Icons.sort_by_alpha_outlined;
    if (type == FilesPanelMode.filesTypeTime) return Icons.timer_outlined;
    return Icons.account_tree_outlined;
  }

  static Widget importExportButton(BuildContext context, ReturnCallback<String> getFolder) {
    return PopupMenuControl<String>(
      onSelected: (value) {
        if (value == 'import') {
          RecordImport.pickAndImportDocuments(context, getFolder());
        } else if (value == 'importFolder') {
          RecordImport.pickAndImportFolder(context, getFolder());
        } else if (value == 'export') {
          RecordExport.start(context, getFolder());
        }
      },
      items: [
        PopupItem.simple(icon: const Icon(Icons.download_outlined), title: l10n.exportMd, value: 'export'),
        PopupItem.simple(icon: const Icon(Icons.upload_outlined), title: l10n.importDocument, value: 'import'),
        PopupItem.simple(icon: const Icon(Icons.folder_open_outlined), title: l10n.importFolder, value: 'importFolder'),
      ],
      child: Icon(Icons.import_export_outlined, color: Theme.of(context).appBarIconColor),
    );
  }

  static Future<void> clickOnCreateRecordButton(
    BuildContext context,
    String folder,
    ValueCallback<RecordEntry> onRecordCreate,
  ) async {
    RecordEntry? record = await Repository.get().createRecord(folder, RecordUtils.generateRecordName(), true, 0);
    if (record == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveRecordFailed)));
      }
      return;
    }

    if (context.mounted) onRecordCreate(record);
  }

  static void clickOnCreateFolderButton(BuildContext context, String path) async {
    if (!context.mounted) return;
    String? folder = await showInputDialog(context, l10n.newFolder, "", false);
    if (folder == null) return;

    Repository.get().recordTree.createFolder(path + folder);
  }

  static Widget newRecordButton(
    BuildContext context,
    ReturnCallback<String> getFolder,
    ValueCallback<RecordEntry> onContentPressed,
  ) {
    return IconButton(
      onPressed: () async {
        await clickOnCreateRecordButton(context, getFolder(), onContentPressed);
      },
      icon: const Icon(Icons.edit_note_outlined),
      tooltip: l10n.newRecord,
    );
  }

  static Widget newFolderButton(BuildContext context, ReturnCallback<String> getFolder) {
    return ValueListenableBuilder<FilesPanelMode>(
      valueListenable: AppEnv.filesPanelModeNotifier,
      builder: (context, _, _) {
        final type = AppEnv.listPageValue.listFilesType;
        if (type == FilesPanelMode.filesTypeFlat || type == FilesPanelMode.filesTypeTree) {
          return IconButton(
            onPressed: () {
              clickOnCreateFolderButton(context, getFolder());
            },
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newFolder,
          );
        }
        return SizedBox.shrink();
      },
    );
  }

  static Widget themeButton(BuildContext context) {
    return IconButton(
      onPressed: () => showThemeSelector(context),
      icon: const Icon(Icons.brightness_6_outlined),
      tooltip: l10n.theme,
    );
  }

  static Widget languageButton(BuildContext context) {
    return PopupMenuControl<LanguageOption>(
      onSelected: (option) async {
        if (option == null) return;
        if (option != LanguageManager.getCurrentLanguage()) {
          await LanguageManager.setLanguage(option);
        }
      },
      items: [
        PopupItem.simple(title: l10n.followSystem, value: LanguageOption.system),
        PopupItem.simple(title: l10n.chinese, value: LanguageOption.chinese),
        PopupItem.simple(title: l10n.english, value: LanguageOption.english),
      ],
      child: Icon(Icons.language_outlined, color: Theme.of(context).appBarIconColor),
    );
  }

  static Widget recyclerButton(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().recyclerCountNotifier,
      builder: (context, count, _) {
        final icon = Icon(Icons.delete_outline);
        return IconButton(
          onPressed: () => AppNavigator.of(context).navigate(AppNavigator.uriRecycler),
          tooltip: l10n.recycler,
          icon: _wrapCountBadge(icon, count),
        );
      },
    );
  }

  static Widget _wrapCountBadge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      alignment: Alignment.bottomRight,
      offset: const Offset(0, -12),
      largeSize: 12,
      textStyle: const TextStyle(fontSize: 10, height: 1.0),
      label: Text('$count'),
      child: icon,
    );
  }
}

/// Tab segment used inside the combined capsule tab bar. Tapping triggers
/// [onTap]; the active segment is highlighted in the primary color and bold.
/// An optional [count] is appended to the label when > 0.
class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _TabButton({required this.label, this.active = false, this.count = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    final bgColor = active ? theme.colorScheme.primary.withAlpha(70) : null;
    final isDesktop = Utils.isDesktop();
    return InkWell(
      onTap: onTap,
      hoverColor: theme.colorScheme.primary.withAlpha(25),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 10),
        decoration: BoxDecoration(color: bgColor),
        child: Text(
          '$label${count > 0 ? ' ($count)' : ''}',
          style: TextStyle(fontSize: 14, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal),
        ),
      ),
    );
  }
}
