import 'dart:async';

import 'package:notee/filesync/backends/http/http_sync_backend.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/settings/server_api_stats_page.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'login_dialog.dart';
import 'change_password_dialog.dart';
import 'upgrade_manager.dart';
import '../../config/language_manager.dart';
import 'package:notee/ui/common/toast.dart';

/// 自部署同步（HTTP backend 专属）页面。
///
/// 收拢所有只对 HTTP 同步后端有意义的功能：同步账号（服务器 url / 登录 / 改密 / 登出）、
/// 版本升级检查、API 调用统计、墓碑管理。游客（backend == null）时这些能力不可用，
/// 对应 Tile 置灰。纯本地/通用功能仍留在 SettingsPage。
class SyncServerPage extends StatefulWidget {
  const SyncServerPage({super.key});

  @override
  State<SyncServerPage> createState() => _SyncServerPageState();
}

class _SyncServerPageState extends State<SyncServerPage> {
  String version = "";
  int _buildNumber = 0;

  // 升级状态
  bool? _hasUpdate;
  VersionInfo? _versionInfo;
  bool _checking = false;

  bool get _loggedIn => HttpSyncBackend.loginStateNotifier.value;

  @override
  void initState() {
    super.initState();
    loadVersionInfo();
    HttpSyncBackend.loginStateNotifier.addListener(_onLoginState);
  }

  @override
  void dispose() {
    HttpSyncBackend.loginStateNotifier.removeListener(_onLoginState);
    super.dispose();
  }

  void _onLoginState() {
    if (!mounted) return;
    setState(() {});
  }

  String _userSubtitle() {
    final u = Repository.get().backend as HttpSyncBackend?;
    if (u == null) return l10n.notLoggedIn;
    final name = u.name.isNotEmpty ? u.name : u.id.toString();
    final server = u.apiUrl.isEmpty ? l10n.needServer : u.apiUrl;
    return '$name\n$server';
  }

  // ===========================================================================
  // 同步账号：游客 → 登录对话框；已登录 → 改密 / 登出
  // ===========================================================================

  void _onUserTap() async {
    if (!mounted) return;

    if (!_loggedIn) {
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

  // ===========================================================================
  // 版本升级（仅 HTTP backend 有效，游客置灰）
  // ===========================================================================

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

  // ===========================================================================
  // API 统计 / 墓碑（仅 HTTP backend 有效）
  // ===========================================================================

  void _onApiStatTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ServerApiStatsPage()));
  }

  Future<void> _onTombstoneTap() async {
    if (!_loggedIn) return;
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

  // ===========================================================================
  // UI
  // ===========================================================================

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
    final theme = Theme.of(context);
    final divider = Divider(height: 1, thickness: 1, color: theme.colorScheme.outline.withAlpha(80));
    return Scaffold(
      appBar: createAppBar(title: l10n.syncServer, onBack: () => Navigator.pop(context)),
      backgroundColor: theme.colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEnv.pageHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 同步账号（含服务器 url / 登录 / 改密 / 登出）
            _buildCard(
              context,
              children: [
                ListTile(
                  onTap: _onUserTap,
                  title: Text(l10n.syncAccount),
                  subtitle: Text(
                    _userSubtitle(),
                    style: TextStyle(color: _loggedIn ? null : theme.colorScheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 以下功能均只对 HTTP backend 有效，游客置灰
            _buildCard(
              context,
              children: [
                ListTile(
                  onTap: _loggedIn ? _onVersionTap : null,
                  title: _buildVersionTitle(),
                  subtitle: _buildVersionSubtitle(),
                  enabled: _loggedIn,
                  trailing: _hasUpdate == true ? const Icon(Icons.new_releases, color: Colors.orange) : null,
                ),
                divider,
                ListTile(
                  onTap: _loggedIn ? _onApiStatTap : null,
                  title: Text(l10n.apiCallStats),
                  enabled: _loggedIn,
                ),
                divider,
                ListTile(
                  onTap: _loggedIn ? _onTombstoneTap : null,
                  title: Text(l10n.tombstoneManager),
                  subtitle: Text(l10n.tombstoneManagerDesc),
                  enabled: _loggedIn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
