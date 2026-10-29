import 'package:flutter/material.dart';
import 'package:notee/ui/desktop/desktop_title_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:notee/utils/kv_store.dart';
import 'package:notee/utils/reboot.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/utils/utils.dart';
import 'package:notee/l10n/app_localizations.dart';

/// Global app configuration + directory initialization.
/// Project-specific constants/initialization, not generic.
class AppEnv {
  static const String appTitle = "Notee";

  static const String packageName = "com.lhg.notee";

  /// Build info injected at compile time via --dart-define (empty when not provided)
  static const String buildGitCommit = String.fromEnvironment('GIT_COMMIT');
  static const String buildTime = String.fromEnvironment('BUILD_TIME');

  // UI padding
  static const double pageHorizontalPadding = 12;
  static const double pageVerticalPadding = 12;
  static const double itemVerticalPadding = 4;
  static const double actionsPadding = 0;

  /// ApplicationSupport root directory, set by init() at startup.
  static late final String appRootDir;

  static final itemPadding = EdgeInsets.only(
    left: pageHorizontalPadding,
    right: pageHorizontalPadding,
    top: itemVerticalPadding,
    bottom: itemVerticalPadding,
  );

  static final pagePadding = EdgeInsets.only(
    left: pageHorizontalPadding,
    right: pageHorizontalPadding,
    top: pageVerticalPadding,
    bottom: pageVerticalPadding,
  );

  /// Persistent preferences store (prefs.json).
  static late final KvStore prefs;

  /// App 启动时间，用于限制 tabs 恢复的等待窗口。
  static final DateTime appStartTime = DateTime.now();

  /// App 已运行时长。
  static Duration get appUptime => DateTime.now().difference(appStartTime);

  /// 保存打开的 tabs：[index] 为当前选中 tab 下标，[tabs] 为 uri 列表。
  /// 当 [tabs] 为 null/空，或 rememberOpenTabs 关闭时清除已保存的 tabs。
  static void setOpenedTabs(int index, List<String>? tabs) {
    if (!(prefs.getBool(PrefKeys.rememberOpenTabs) ?? true) || tabs == null || tabs.isEmpty) {
      prefs.remove(PrefKeys.openedTabs);
    } else {
      prefs.setMap(PrefKeys.openedTabs, {'index': index, 'tabs': tabs});
    }
  }

  /// 读取打开的 tabs，返回 (当前选中下标, uri 列表)。
  /// rememberOpenTabs 关闭或无数据时返回 null。
  static ({int index, List<String> tabs})? getOpenedTabs() {
    if (!(prefs.getBool(PrefKeys.rememberOpenTabs) ?? true)) return null;
    final raw = prefs.getMap(PrefKeys.openedTabs);
    if (raw == null) return null;
    try {
      final index = (raw['index'] as int?) ?? 0;
      final tabs = (raw['tabs'] as List).cast<String>();
      return (index: index, tabs: tabs);
    } catch (_) {
      return null;
    }
  }

  /// List-page view state notifier (migrated from FilesPanelMode).
  static final ValueNotifier<FilesPanelMode> filesPanelModeNotifier = ValueNotifier(
    FilesPanelMode(FilesPanelMode.panelModeList, FilesPanelMode.filesTypeTree, ''),
  );
  static FilesPanelMode get listPageValue => filesPanelModeNotifier.value;

  /// Called at startup to initialize the application root directory.
  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    appRootDir = dir.path;
    prefs = KvStore('$appRootDir/prefs.json');
    prefs.save();

    final saved = AppEnv.prefs.getString(PrefKeys.filesPanelMode);
    AppEnv.filesPanelModeNotifier.value = saved != null
        ? FilesPanelMode._parse(saved)
        : FilesPanelMode(
            FilesPanelMode.panelModeList,
            Utils.isDesktop() ? FilesPanelMode.filesTypeTree : FilesPanelMode.filesTypeFlat,
            '',
          );
  }

  /// Generic list divider (UI-related, placed here).
  static Widget listViewDivider(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).colorScheme.outline.withAlpha(80));
  }

  /// Unified menu animation.
  static AnimationStyle get menuAnimationStyle => AnimationStyle.noAnimation;

  /// 当前布局模式: 优先使用 pref 中手动设置的值,
  /// pref 为空时按屏幕短边宽度自动判断 (>=600 为 pad)
  static String getLayoutMode() {
    final saved = AppEnv.prefs.getString(PrefKeys.layoutMode);
    if (saved == LayoutMode.pad || saved == LayoutMode.phone || saved == LayoutMode.desktop) {
      return saved!;
    }
    if (Utils.isDesktop()) {
      return LayoutMode.desktop;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
    return shortest >= 600 ? LayoutMode.pad : LayoutMode.phone;
  }

  /// 设置布局模式并重启 app 使 PadApp/PhoneApp 切换生效
  static Future<void> setLayoutMode(String mode) async {
    AppEnv.prefs.setString(PrefKeys.layoutMode, mode).save();
    Reboot.trigger();
  }

  static void setFilesPanelMode(String panelMode) => _updateFilesPanelMode(
    FilesPanelMode(panelMode, AppEnv.listPageValue.listFilesType, AppEnv.listPageValue.tagFilesType),
  );
  static void setFilesPanelModeListType(String listType) => _updateFilesPanelMode(
    FilesPanelMode(AppEnv.listPageValue.panelMode, listType, AppEnv.listPageValue.tagFilesType),
  );

  static void _updateFilesPanelMode(FilesPanelMode next) {
    AppEnv.filesPanelModeNotifier.value = next;
    AppEnv.prefs.setString(PrefKeys.filesPanelMode, next.toString()).save();
  }

  static double getAppBarHeight() =>
      Utils.isDesktop() && getLayoutMode() == LayoutMode.desktop ? kWindowToolbarHeight : kToolbarHeight;
}

class PrefKeys {
  static const windowLeftWidth = 'desktop_left_width';
  static const windowWidth = 'window_width';
  static const windowHeight = 'window_height';
  static const windowPosX = 'window_pos_x';
  static const windowPosY = 'window_pos_y';
  static const windowMaximized = 'window_maximized';
  static const rememberOpenTabs = 'remember_open_tabs';
  static const openedTabs = 'opened_tabs';

  static const languageCode = 'language_code';
  static const filesPanelMode = 'files_panel_mode';
  static const layoutMode = 'layout_mode';
}

/// 布局模式常量与辅助方法
class LayoutMode {
  static const String pad = 'pad';
  static const String phone = 'phone';
  static const String desktop = 'desktop';

  static String getName(String mode, AppLocalizations l10n) {
    switch (mode) {
      case LayoutMode.desktop:
        return l10n.modeDesktop;
      case LayoutMode.pad:
        return l10n.modePad;
      default:
        return l10n.modePhone;
    }
  }
}

/// List-page view state: tab ([panelModeList] records / [panelModeTag] tags), records list type
/// ([filesTypeFlat]/[filesTypeTree]/[filesTypeName]/[filesTypeTime]), tag type reserved for the tags panel.
/// Serialized to prefs as `<tab>|<listType>|<tagType>`, e.g. "list|tree|".
class FilesPanelMode {
  static const String panelModeList = 'list';
  static const String panelModeTag = 'tag';

  static const String filesTypeFlat = 'flat';
  static const String filesTypeTree = 'tree';
  static const String filesTypeName = 'name';
  static const String filesTypeTime = 'time';

  final String panelMode;
  final String listFilesType;
  final String tagFilesType;

  FilesPanelMode(this.panelMode, this.listFilesType, this.tagFilesType);

  static FilesPanelMode _parse(String value) {
    final parts = value.split('|');
    return FilesPanelMode(parts[0], parts.length > 1 ? parts[1] : '', parts.length > 2 ? parts[2] : '');
  }

  @override
  String toString() => '$panelMode|$listFilesType|$tagFilesType';

  /// Sort type consumed by [RecordList]; folder views keep the default order.
  int get sortType {
    if (listFilesType == filesTypeName) return RecordList.sSortTypeName;
    if (listFilesType == filesTypeTime) return RecordList.sSortTypeByTime;
    return 0;
  }


}
