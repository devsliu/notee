import 'dart:convert';

import 'package:notee/filesync/table_record.dart';
import 'package:notee/filesync/backends/http/http_sync_backend.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/settings/record_operates_page.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/settings/record_database_page.dart';
import 'package:notee/ui/settings/read_only_folders_page.dart';
import 'package:notee/ui/settings/sync_server_page.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/ui/settings/theme_selector_dialog.dart';
import 'package:notee/config/app_env.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/language_manager.dart';
import '../../utils/utils.dart';
import 'package:notee/ui/common/toast.dart';

class SettingsPage extends StatefulWidget {
  final bool showAppBar;
  const SettingsPage({super.key, this.showAppBar = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String version = "";
  int _buildNumber = 0;
  List<String> _readOnlyFolders = [];

  @override
  void initState() {
    super.initState();
    loadVersionInfo();
    _loadReadOnlyFolders();
    HttpSyncBackend.loginStateNotifier.addListener(_refreshState);
    Repository.get().syncConfigs.notifier.addListener(_refreshState);
  }

  @override
  void dispose() {
    HttpSyncBackend.loginStateNotifier.removeListener(_refreshState);
    Repository.get().syncConfigs.notifier.removeListener(_refreshState);
    super.dispose();
  }

  void _refreshState() {
    if (!mounted) return;
    // 切后端后 syncConfigs 会重新 load，刷新只读文件夹等本地配置、以及同步服务器入口副标题
    _loadReadOnlyFolders();
    setState(() {});
  }

  // ===========================================================================
  // 自部署同步入口：HTTP backend 专属功能（账号/url、版本升级、API 统计、墓碑）
  // 全部在 SyncServerPage 内，这里只做导航。
  // ===========================================================================

  String _syncServerSubtitle() {
    final u = Repository.get().backend as HttpSyncBackend?;
    if (u == null) return l10n.notLoggedIn;
    final name = u.name.isNotEmpty ? u.name : u.id.toString();
    final server = u.apiUrl.isEmpty ? l10n.needServer : u.apiUrl;
    return '$name\n$server';
  }

  void _onSyncServerTap() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const SyncServerPage()));
    if (mounted) setState(() {});
  }

  void _onThemeTap() async {
    await showThemeSelector(context);
    setState(() {});
  }

  Future<void> loadVersionInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      version = packageInfo.version;
      _buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    });
  }

  void _onLanguageTap() async {
    final currentLanguage = LanguageManager.getCurrentLanguage();

    LanguageOption? selected = await showDialog<LanguageOption>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.selectLanguage),
        children: [
          SimpleDialogOption(
            child: Row(
              children: [
                if (currentLanguage == LanguageOption.system) const Icon(Icons.check, size: 16),
                if (currentLanguage != LanguageOption.system) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(l10n.followSystem),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, LanguageOption.system),
          ),
          SimpleDialogOption(
            child: Row(
              children: [
                if (currentLanguage == LanguageOption.chinese) const Icon(Icons.check, size: 16),
                if (currentLanguage != LanguageOption.chinese) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(l10n.chinese),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, LanguageOption.chinese),
          ),
          SimpleDialogOption(
            child: Row(
              children: [
                if (currentLanguage == LanguageOption.english) const Icon(Icons.check, size: 16),
                if (currentLanguage != LanguageOption.english) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(l10n.english),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, LanguageOption.english),
          ),
        ],
      ),
    );

    if (selected != null && selected != currentLanguage) {
      await LanguageManager.setLanguage(selected);
    }
  }

  String _getLanguageDisplayName(BuildContext context) {
    final currentLanguage = LanguageManager.getCurrentLanguage();
    return LanguageManager.getLanguageDisplayName(currentLanguage, l10n.followSystem, l10n.chinese, l10n.english);
  }

  void _onLayoutModeTap() async {
    final current = AppEnv.getLayoutMode();
    final isDesktop = Utils.isDesktop();
    final options = isDesktop
        ? [LayoutMode.desktop, LayoutMode.pad, LayoutMode.phone]
        : [LayoutMode.pad, LayoutMode.phone];

    String? selected = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.layoutMode),
        children: options.map((mode) {
          return SimpleDialogOption(
            child: Row(
              children: [
                if (current == mode) const Icon(Icons.check, size: 16),
                if (current != mode) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(LayoutMode.getName(mode, l10n)),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, mode),
          );
        }).toList(),
      ),
    );

    if (selected != null && selected != current) {
      await AppEnv.setLayoutMode(selected);
    }
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);
    final cardColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline.withAlpha(80);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: cardColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildVersionSubtitle();
    final theme = Theme.of(context);
    final divider = Divider(height: 1, thickness: 1, color: theme.colorScheme.outline.withAlpha(80));
    return Scaffold(
      appBar: widget.showAppBar
          ? createAppBar(title: l10n.settings, onBack: () => Navigator.pop(context))
          : null,
      backgroundColor: theme.colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEnv.pageHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCard(
              context,
              children: [
                // 自部署同步（HTTP backend 专属能力）入口
                ListTile(
                  onTap: _onSyncServerTap,
                  title: Text(l10n.syncServer),
                  subtitle: Text(
                    _syncServerSubtitle(),
                    style: TextStyle(
                      color: HttpSyncBackend.loginStateNotifier.value ? null : theme.colorScheme.error,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
                divider,
                ListTile(
                  onTap: _onReadOnlyFoldersTap,
                  title: Text(l10n.readOnlyFolders),
                  subtitle: _readOnlyFolders.isEmpty ? null : Text(_readOnlyFolders.join(', ')),
                ),
                divider,
                ListTile(onTap: _onThemeTap, title: Text(l10n.theme), subtitle: Text(gAppTheme.getName(l10n))),
                divider,
                ListTile(
                  onTap: _onLanguageTap,
                  title: Text(l10n.language),
                  subtitle: Text(_getLanguageDisplayName(context)),
                ),
                divider,
                ListTile(
                  onTap: _onLayoutModeTap,
                  title: Text(l10n.layoutMode),
                  subtitle: Text(LayoutMode.getName(AppEnv.getLayoutMode(), l10n)),
                ),
                divider,
                ListTile(onTap: _onAppFolderTap, title: Text(l10n.dataDirectory), subtitle: Text(AppEnv.appRootDir)),
                if (AppEnv.getLayoutMode() == LayoutMode.desktop) ...[
                  divider,
                  SwitchListTile.adaptive(
                    value: AppEnv.prefs.getBool(PrefKeys.rememberOpenTabs) ?? true,
                    onChanged: (v) {
                      AppEnv.prefs.setBool(PrefKeys.rememberOpenTabs, v).save();
                      setState(() {});
                    },
                    title: Text(l10n.rememberOpenTabs),
                    subtitle: Text(l10n.rememberOpenTabsDesc),
                  ),
                ],
                divider,
                // 只读版本信息：升级检查已移至「同步服务器」页（仅 HTTP backend 有效）
                ListTile(
                  title: Text(l10n.version),
                  subtitle: subtitle,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                l10n.debugAndStats,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                ListTile(onTap: _onRecordsDbTap, title: Text(l10n.database)),
                divider,
                ListTile(onTap: _onOperatesDbTap, title: Text(l10n.operates)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionSubtitle() {
    var current = '$version ($_buildNumber)';
    if (AppEnv.buildGitCommit.isNotEmpty) current += ' · ${AppEnv.buildGitCommit}';
    if (AppEnv.buildTime.isNotEmpty) current += ' · ${AppEnv.buildTime}';
    return Text(current);
  }

  void _onAppFolderTap() {
    Clipboard.setData(ClipboardData(text: AppEnv.appRootDir));
    Toast.show(context, '${l10n.dataDirCopied}: ${AppEnv.appRootDir}', duration: const Duration(seconds: 2));
  }

  void _onRecordsDbTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordDatabasePage()));
  }

  void _onReadOnlyFoldersTap() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ReadOnlyFoldersPage()));
    if (mounted) _loadReadOnlyFolders();
  }

  void _loadReadOnlyFolders() {
    final raw = Repository.get().syncConfigs.get(KVConfigs.readOnlyFolders);
    if (raw == null || raw.isEmpty) {
      setState(() => _readOnlyFolders = []);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      setState(() {
        _readOnlyFolders = (decoded as List).whereType<String>().toList();
      });
    } catch (_) {
      setState(() => _readOnlyFolders = []);
    }
  }

  void _onOperatesDbTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LogsPage()));
  }
}
