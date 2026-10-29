import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/app_env.dart';

import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/desktop/desktop_title_bar.dart';
import 'package:notee/ui/desktop/window_state.dart';
import 'package:notee/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

import 'package:notee/ui/files/record_list_page.dart';

import '../../filesync/repository.dart';
import 'desktop_tabs_page.dart';
import '../../model/record_opened_state.dart';
import '../calendar/calendar_page.dart';
import '../common/split_layout.dart';
import '../files/record_recycler_page.dart';
import '../editor/record_flow_editor_page.dart';
import '../settings/settings_page.dart';

class EditorTab extends DesktopTab {
  final String uuid;
  String? keyword;
  @override
  final String title;
  EditorTab({required this.uuid, this.keyword})
    : title = Repository.get().recordTree.findRecord(uuid)?.local.name ?? '',
      super(uri: '${AppNavigator.uriRecord}$uuid');

  @override
  void select() {
    RecordOpenedState.get().openFile(uuid);
  }

  @override
  void close() {
    RecordOpenedState.get().closeFile(uuid);
  }

  @override
  bool refresh(DesktopTab newTab) {
    if (newTab is EditorTab && newTab.keyword != keyword) {
      keyword = newTab.keyword;
      return true;
    }
    return false;
  }

  @override
  Widget buildPage(GlobalKey key, ValueCallback<BuildContext> closeCB) {
    return RecordFlowEditorPage(uuid: uuid, keyword: keyword, key: key, closePageCallback: closeCB);
  }

  @override
  List<Widget>? buildActions(GlobalKey key) {
    final state = key.currentState as RecordFlowEditorPageState?;
    if (state == null) return null;
    return [_buildOverflowButton(state)];
  }

  Widget _buildOverflowButton(RecordFlowEditorPageState state) {
    return Builder(
      builder: (context) => IconButton(
        icon: Icon(Icons.more_vert, size: 20),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints.tight(Size(40, 40)),
        onPressed: () async {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          final result = await showMenu<int>(
            popUpAnimationStyle: AnimationStyle.noAnimation,
            context: context,
            position: RelativeRect.fromRect(
              renderBox.localToGlobal(Offset.zero) & renderBox.size,
              Offset.zero & MediaQuery.of(context).size,
            ),
            items: state.buildOverflowMenuItems(context),
          );
          if (result != null) state.onOverflowMenuSelect(result);
        },
      ),
    );
  }
}

class DesktopApp extends BaseApp {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends BaseAppState<DesktopApp> {
  static const double minLeftWidth = 300;
  static const double maxLeftWidth = 500;
  double leftWidth = minLeftWidth;
  final GlobalKey<DesktopTabsPageState> detailKey = GlobalKey<DesktopTabsPageState>();
  bool _tabsRestored = false;

  @override
  void initState() {
    super.initState();
    leftWidth = loadLeftWidth();
    Repository.get().recordTree.countNotifier.addListener(_onRecordTreeCountChanged);
    _onRecordTreeCountChanged(); // 立即检查一次
  }

  @override
  void dispose() {
    Repository.get().recordTree.countNotifier.removeListener(_onRecordTreeCountChanged);
    super.dispose();
  }

  void _onRecordTreeCountChanged() {
    if (_tabsRestored) return;
    if (AppEnv.appUptime.inSeconds > 10) {
      _tabsRestored = true;
      return;
    }
    if (Repository.get().recordTree.countNotifier.value <= 0) return;
    _tabsRestored = true;
    Timer.run(_restoreTabs);
  }

  void _saveTabs() {
    final state = detailKey.currentState;
    AppEnv.setOpenedTabs(state?.currentIndex ?? 0, state?.tabs.map((t) => t.uri).toList());
  }

  void _restoreTabs() {
    final saved = AppEnv.getOpenedTabs();
    if (saved == null) return;
    final state = detailKey.currentState;
    if (state == null || !state.mounted) return;
    try {
      for (final uri in saved.tabs) {
        final tab = _createTab(uri);
        if (tab == null) continue;
        if (tab is EditorTab && Repository.get().recordTree.findRecord(tab.uuid) == null) {
          continue;
        }
        state.openTab(tab);
      }
      if (state.tabCount > 0) {
        state.selectTab(saved.index.clamp(0, state.tabCount - 1));
      }
    } catch (_) {}
  }

  /// 初始化桌面窗口（大小、标题栏、显示等），仅执行一次。

  double loadLeftWidth() {
    double saved = AppEnv.prefs.getDouble(PrefKeys.windowLeftWidth) ?? 0;
    if (saved == 0) saved = minLeftWidth;
    return saved;
  }

  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
    _startWindowAnimation();
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
    _startWindowAnimation();
  }

  void _startWindowAnimation() {
    isWindowAnimatingNotifier.value = true;
    Future.delayed(const Duration(milliseconds: 600), () {
      isWindowAnimatingNotifier.value = false;
    });
  }

  @override
  void onAppTerminating() {
    _saveTabs();
    AppEnv.prefs
      .setBool(PrefKeys.windowMaximized, isMaximizedNotifier.value).save();
    super.onAppTerminating();
  }



  @override
  Widget buildAppWrapper(BuildContext context, Widget child) {
    final virtualWindowFrameBuilder = VirtualWindowFrameInit();
    return virtualWindowFrameBuilder(context, child);
  }

  @override
  void navigate(String uri) {
    final tab = _createTab(uri);
    if (tab != null) {
      detailKey.currentState?.openTab(tab);
    }
  }

  DesktopTab? _createTab(String uri) {
    final parsed = AppNavigatorUri.parse(uri);
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        return EditorTab(uuid: parsed.firstPath ?? '', keyword: parsed.queryParam('keyword'));
      case AppNavigator.uriCalendar:
        return DesktopTab.create(
          AppNavigator.uriCalendar,
          l10n.calendar,
          (key, closeCB) => CalendarPage(key: key, showAppBar: false, closeCallback: closeCB),
        );
      case AppNavigator.uriRecycler:
        return DesktopTab.create(
          AppNavigator.uriRecycler,
          l10n.recycler,
          (key, closeCB) => RecordRecyclerPage(key: key, showAppBar: false, closeCallback: closeCB),
        );
      case AppNavigator.uriSettings:
        return DesktopTab.create(
          AppNavigator.uriSettings,
          l10n.settings,
          (key, closeCB) => Navigator(
            pages: [MaterialPage(child: SettingsPage(key: key, showAppBar: false))],
            onDidRemovePage: (page) {},
          ),
        );
    }
    return null;
  }

  @override
  Widget buildHome(BuildContext context) {
    return SplitLayout(
      leftWidth: leftWidth,
      minLeftWidth: minLeftWidth,
      maxLeftWidth: maxLeftWidth,
      draggerTopOffset: kWindowToolbarHeight,
      onLeftWidthChanged: (w) {
        leftWidth = w;
        AppEnv.prefs.setDouble(PrefKeys.windowLeftWidth, w);
      },
      leftChild: RecordListPage(),
      rightChild: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: DesktopTabsPage(key: detailKey),
        ),
      ),
    );
  }
}
