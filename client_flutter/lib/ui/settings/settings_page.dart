import 'dart:async';
import 'dart:convert';

import 'package:notee/filesync/table_record.dart';
import 'package:notee/filesync/backends/http/http_sync_backend.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/settings/record_operates_page.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/settings/server_api_stats_page.dart';
import 'package:notee/ui/settings/linear_layout_test_page.dart';
import 'package:notee/ui/settings/record_database_page.dart';
import 'package:notee/ui/settings/read_only_folders_page.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/ui/settings/theme_selector_dialog.dart';
import 'package:notee/config/app_env.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'login_dialog.dart';
import 'change_password_dialog.dart';
import 'upgrade_manager.dart';
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

  // 升级状态
  bool? _hasUpdate;
  VersionInfo? _versionInfo;
  bool _checking = false;

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
    // 切后端后 syncConfigs 会重新 load，刷新只读文件夹等本地配置显示
    _loadReadOnlyFolders();
    setState(() {});
  }

  String _userSubtitle() {
    final u = Repository.get().backend as HttpSyncBackend?;
    if (u == null) return l10n.notLoggedIn;
    final name = u.name.isNotEmpty ? u.name : u.id.toString();
    final server = u.apiUrl.isEmpty ? l10n.needServer : u.apiUrl;
    return '$name\n$server';
  }

  void _onUserTap() async {
    if (!mounted) return;

    if (!HttpSyncBackend.loginStateNotifier.value) {
      LoginDialog.show(context);
      return;
    }

    // 已登录 → 弹对话框：修改密码 / 登出
    final backend = Repository.get().backend as HttpSyncBackend?;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(backend?.name ?? ''),
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.changePassword),
            onTap: () => Navigator.pop(ctx, 'password'),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(ctx).colorScheme.error),
            title: Text(l10n.logout, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () => Navigator.pop(ctx, 'logout'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == 'password') {
      ChangePasswordDialog.show(context);
    } else if (action == 'logout') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.logout),
          content: Text(l10n.confirmLogout),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.logout, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        // 登出不是独立操作：token 失效（清 token + 登录态 false）+ 变游客。
        // 认证归 backend，同步目标归 Repository，两者互不感知。
        final cur = Repository.get().backend;
        if (cur is HttpSyncBackend) await cur.clearToken(wipePassword: true);
        Repository.get().setBackend(null);
        if (mounted) setState(() {});
      }
    }
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

  Future<void> _checkUpgrade() async {
    if (_checking) return;
    setState(() => _checking = true);

    final info = await UpgradeManager.checkUpgrade();
    if (info != null && mounted) {
      _versionInfo = info;
      _hasUpdate = UpgradeManager.isNewerVersion(info.versionName, version);
      setState(() {});
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _onVersionTap() async {
    if (_checking) {
      return;
    }
    await _checkUpgrade();
    if (mounted) {
      UpgradeManager.showVersionDialog(context, currentVersion: version, versionInfo: _versionInfo);
    }
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
                ListTile(
                  onTap: _onUserTap,
                  title: Text(l10n.syncAccount),
                  subtitle: Text(
                    _userSubtitle(),
                    style: TextStyle(
                      color: HttpSyncBackend.loginStateNotifier.value ? null : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (HttpSyncBackend.loginStateNotifier.value) ...[
                  divider,
                ],
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
                ListTile(
                  onTap: _onVersionTap,
                  title: _buildVersionTitle(),
                  subtitle: subtitle,
                  trailing: _hasUpdate == true ? const Icon(Icons.new_releases, color: Colors.orange) : null,
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
                ListTile(
                  onTap: HttpSyncBackend.loginStateNotifier.value ? _onApiStatTap : null,
                  title: Text(l10n.apiCallStats),
                  enabled: HttpSyncBackend.loginStateNotifier.value,
                ),
                divider,
                ListTile(onTap: _onRecordsDbTap, title: Text(l10n.database)),
                divider,
                ListTile(onTap: _onOperatesDbTap, title: Text(l10n.operates)),
                divider,
                ListTile(
                  onTap: HttpSyncBackend.loginStateNotifier.value ? _onTombstoneTap : null,
                  title: Text(l10n.tombstoneManager),
                  subtitle: Text(l10n.tombstoneManagerDesc),
                  enabled: HttpSyncBackend.loginStateNotifier.value,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionTitle() {
    if (_checking) return Text('${l10n.version} · ${l10n.upgradeChecking}');
    if (_hasUpdate == true) {
      return Text(
        '${l10n.version} · ${l10n.upgradeAvailable(_versionInfo?.versionName ?? '')}',
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      );
    }
    if (_hasUpdate == false) return Text('${l10n.version} · ${l10n.upgradeUpToDate}');
    return Text(l10n.version);
  }

  Widget _buildVersionSubtitle() {
    var current = '$version ($_buildNumber)';
    if (AppEnv.buildGitCommit.isNotEmpty) current += ' · ${AppEnv.buildGitCommit}';
    if (AppEnv.buildTime.isNotEmpty) current += ' · ${AppEnv.buildTime}';
    return Text(current);
  }

  void _onLinearLayoutTestTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LinearLayoutTestPage()));
  }

  void _onApiStatTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ServerApiStatsPage()));
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

  Future<void> _onTombstoneTap() async {
    if (!HttpSyncBackend.loginStateNotifier.value) return;
    final result = await (Repository.get().backend as HttpSyncBackend).getTombstoneStats();
    if (!mounted) return;
    if (!result.isSuccess() || result.data == null) {
      Toast.show(context, l10n.syncErrServerDb);
      return;
    }
    final stats = result.data!;

    // Show stats dialog
    final theme = Theme.of(context);
    if (!mounted) return;
    final confirmDelete = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tombstoneTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tombstoneRow(theme, l10n.tombstoneTotalRecords, stats.activeRecords.toString()),
            _tombstoneRow(theme, l10n.tombstoneDeletedRecords, stats.tombstoneCount.toString()),
            _tombstoneRow(theme, l10n.tombstoneDeletedAssets, stats.tombstoneAssetCount.toString()),
            _tombstoneRow(theme, l10n.tombstoneMaxVersion, stats.maxVersion.toString()),
            _tombstoneRow(theme, l10n.tombstonePurgedVersion, stats.purgedVersion.toString()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.tombstonePurge)),
        ],
      ),
    );
    if (confirmDelete != true) return;

    // Confirm dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tombstonePurge),
        content: Text(l10n.tombstonePurgeConfirm(stats.tombstoneCount)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: Text(l10n.tombstonePurge),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Perform purge
    final purgeResult = await (Repository.get().backend as HttpSyncBackend).purgeTombstones();
    if (!mounted) return;
    if (purgeResult.isSuccess() && purgeResult.data != null) {
      Toast.show(context, l10n.tombstonePurgeDone(stats.tombstoneAssetCount, purgeResult.data!.purgedCount));
      // Trigger a sync to update local DB state after purgedVersion advanced
      unawaited(Repository.get().syncRecords(true));
    } else {
      Toast.show(context, l10n.syncErrServerDb);
    }
  }

  Widget _tombstoneRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.outline)),
          Text(value),
        ],
      ),
    );
  }
}
