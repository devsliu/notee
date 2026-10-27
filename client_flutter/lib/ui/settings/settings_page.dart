import 'dart:async';

import 'package:notee/filesync/http_api.dart';
import 'package:notee/filesync/user.dart';
import 'package:notee/ui/settings/record_operates_page.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/settings/server_api_stats_page.dart';
import 'package:notee/ui/settings/record_database_page.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/ui/settings/theme_selector_dialog.dart';
import 'package:notee/config/app_env.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'login_dialog.dart';
import 'change_password_dialog.dart';
import 'upgrade_manager.dart';
import 'login_users_control.dart';
import '../../config/language_manager.dart';
import '../../utils/utils.dart';
import '../../filesync/repository.dart';

class SettingsPage extends StatefulWidget {
  final bool showAppBar;
  const SettingsPage({super.key, this.showAppBar = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String version = "";
  int _buildNumber = 0;

  // 升级状态
  bool? _hasUpdate;
  VersionInfo? _versionInfo;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    loadVersionInfo();
    UserManager.stateNotifier.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    UserManager.stateNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _onUserTap() async {
    final savedList = UserManager.getUsers();
    if (!mounted) return;

    // Nothing to show: no users at all → login dialog
    if (savedList.isEmpty) {
      LoginDialog.show(context);
      return;
    }

    await showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => LoginUsersControl(
        savedList: savedList,
        onChanged: () {
          if (mounted) setState(() {});
        },
      ),
    );
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
                    getUserInfo(context, UserManager.current),
                    style: TextStyle(
                      color: UserManager.current.isLoggedIn ? null : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (UserManager.current.isLoggedIn) ...[
                  divider,
                  ListTile(
                    onTap: () => ChangePasswordDialog.show(context),
                    title: Text(l10n.changePassword),
                    trailing: const Icon(Icons.lock_outline),
                  ),
                ],
                divider,
                ListTile(onTap: _onAppFolderTap, title: Text(l10n.dataDirectory), subtitle: Text(AppEnv.appRootDir)),
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
                ListTile(onTap: _onApiStatTap, title: Text(l10n.apiCallStats)),
                divider,
                ListTile(onTap: _onRecordsDbTap, title: Text(l10n.database)),
                divider,
                ListTile(onTap: _onOperatesDbTap, title: Text(l10n.operates)),
                divider,
                ListTile(
                  onTap: UserManager.current.isLoggedIn ? _onTombstoneTap : null,
                  title: Text(l10n.tombstoneManager),
                  subtitle: Text(l10n.tombstoneManagerDesc),
                  enabled: UserManager.current.isLoggedIn,
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

  void _onApiStatTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ServerApiStatsPage()));
  }

  void _onAppFolderTap() {
    Clipboard.setData(ClipboardData(text: AppEnv.appRootDir));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.dataDirCopied}: ${AppEnv.appRootDir}'), duration: const Duration(seconds: 2)),
    );
  }

  void _onRecordsDbTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecordDatabasePage()));
  }

  void _onOperatesDbTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LogsPage()));
  }

  Future<void> _onTombstoneTap() async {
    if (!UserManager.current.isLoggedIn) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await HttpApi.getTombstoneStats();
    if (!mounted) return;
    if (!result.isSuccess() || result.data == null) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.syncErrServerDb)));
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
    final scaffold = ScaffoldMessenger.of(context);
    final purgeResult = await HttpApi.purgeTombstones();
    if (!mounted) return;
    if (purgeResult.isSuccess() && purgeResult.data != null) {
      scaffold.showSnackBar(
        SnackBar(content: Text(l10n.tombstonePurgeDone(stats.tombstoneAssetCount, purgeResult.data!.purgedCount))),
      );
      // Trigger a sync to update local DB state after purgedVersion advanced
      unawaited(Repository.get().syncRecords(true));
    } else {
      scaffold.showSnackBar(SnackBar(content: Text(l10n.syncErrServerDb)));
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
