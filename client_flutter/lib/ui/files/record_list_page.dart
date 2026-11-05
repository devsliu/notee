import 'package:flutter/material.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/files/record_files_flat_control.dart';
import 'package:notee/ui/files/record_files_list_control.dart';
import 'package:notee/ui/files/record_files_tree_control.dart';
import 'package:notee/ui/files/record_multi_select.dart';
import 'package:notee/ui/files/tag_files_control.dart';
import 'package:notee/ui/files/record_search_page.dart';
import 'package:notee/ui/files/record_list_actions.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/config/app_env.dart';

import 'sync_button.dart';

/// App bar that swaps to the multi-select action bar while selection mode is active.
class _AppBarSwitcher extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget Function(BuildContext context) buildTitleBar;

  const _AppBarSwitcher({required this.buildTitleBar});

  @override
  Size get preferredSize => Size.fromHeight(AppEnv.getAppBarHeight());

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MultiSelectState.instance,
      builder: (context, _) {
        return MultiSelectState.instance.active ? buildMultiSelectAppBar(context) : buildTitleBar(context);
      },
    );
  }
}

class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key});

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  bool _showSearch = false;

  String _getFolder() {
    if (AppEnv.listPageValue.listFilesType == FilesPanelMode.filesTypeTree) {
      return "/";
    }
    return RecordOpenedState.get().openedFolder.path;
  }

  PreferredSizeWidget _buildTitleBar(BuildContext context) {
    final bool desktop = Utils.isDesktop();
    return createAppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: AppEnv.appTitle,
      actions: [
        const SyncButton(),
        IconButton(
          onPressed: () => setState(() => _showSearch = true),
          icon: const Icon(Icons.search),
          tooltip: l10n.searchRecords,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.settings,
          onPressed: () => AppNavigator.of(context).navigate(AppNavigator.uriSettings),
        ),
        SizedBox(width: desktop ? 4 : AppEnv.pageHorizontalPadding),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(0),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(child: RecordListActions.allRecordsButton(context)),
            Expanded(child: RecordListActions.tagsButton(context)),
            Expanded(child: RecordListActions.calendarButton(context)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final bool desktop = Utils.isDesktop();
    return Container(
      color: theme.appBarBackgroundColor,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 4 : AppEnv.pageHorizontalPadding, vertical: 2.0),
      child: IconButtonTheme(
        data: theme.appBarIconButtonTheme,
        child: Row(
          spacing: 4,
          children: [
            RecordListActions.themeButton(context),
            RecordListActions.importExportButton(context, _getFolder),
            RecordListActions.recyclerButton(context),
            RecordListActions.viewToggleButton(context),
            const Spacer(),
            RecordListActions.newRecordButton(
              context,
              _getFolder,
              (record) => AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${record.uuid}'),
            ),
            RecordListActions.newFolderButton(context, _getFolder),
          ],
        ),
      ),
    );
  }

  /// Empty library: replace the list control with a create-hint state.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_alt_outlined, size: 48, color: theme.colorScheme.onSurface.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            l10n.emptyRecordsHint,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => RecordListActions.clickOnCreateRecordButton(
              context,
              '/',
              (record) => AppNavigator.of(context).navigate('${AppNavigator.uriRecord}${record.uuid}'),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.newRecord),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bool desktop = Utils.isDesktop();
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppEnv.filesPanelModeNotifier,
        Repository.get().userSwitchingNotifier,
        Repository.get().recordTree.countNotifier,
      ]),
      builder: (context, _) {
        if (Repository.get().userSwitchingNotifier.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (Repository.get().recordTree.countNotifier.value == 0) {
          return _buildEmptyState(context);
        }
        FilesPanelMode typeValue = AppEnv.filesPanelModeNotifier.value;
        if (typeValue.panelMode == FilesPanelMode.panelModeTag) {
          return TagFilesControl(shrink: desktop);
        }

        if (typeValue.listFilesType == FilesPanelMode.filesTypeTree) {
          return RecordFilesTreeControl(shrink: desktop);
        } else if (typeValue.listFilesType == FilesPanelMode.filesTypeFlat) {
          return RecordFilesFlatControl(shrink: desktop);
        } else {
          return RecordFilesListControl(showDivider: true, shrink: desktop);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (MultiSelectState.instance.active) {
          MultiSelectState.instance.exit();
          return;
        }
        if (_showSearch) {
          setState(() => _showSearch = false);
          return;
        }
        final state = RecordOpenedState.get();
        final bool onTagsTab = AppEnv.listPageValue.panelMode == FilesPanelMode.panelModeTag;
        if (onTagsTab ||
            state.openedFolder.path == "/" ||
            AppEnv.listPageValue.listFilesType != FilesPanelMode.filesTypeFlat) {
          if (!Navigator.canPop(context)) {
            Utils.moveTaskToBack();
          } else {
            Navigator.pop(context);
          }
        } else {
          state.setOpenedFolder(state.openedFolder.dir);
        }
      },
      child: _showSearch
          ? RecordSearchPage(shrink: Utils.isDesktop(), onBack: () => setState(() => _showSearch = false))
          : Scaffold(
              appBar: _AppBarSwitcher(buildTitleBar: _buildTitleBar),
              body: Column(
                children: [
                  const Divider(height: 1, color: Colors.transparent),
                  _buildTabBar(context),
                  const SizedBox(height: 4),
                  Expanded(child: _buildContent(context)),
                  const SyncStateWidget(),
                  _buildBottomBar(context),
                ],
              ),
            ),
    );
  }
}
