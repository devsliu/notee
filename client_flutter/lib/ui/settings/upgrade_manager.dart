import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:notee/config/app_env.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:notee/ui/common/toast.dart';

/// 从当前平台推断服务器 platform 参数
/// 和 version.json 的 key 对应：windows / linux / macos / android / ios
String detectPlatform() {
  return Platform.operatingSystem;
}

/// 升级下载 + 各平台安装入口
class UpgradeManager {
  /// 比较版本名 (如 "v1.0.4" vs "1.0.3"), remote 更新则返回 true
  static bool isNewerVersion(String remote, String current) {
    List<int> parse(String v) => v.replaceFirst(RegExp(r'^v'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final r = parse(remote);
    final c = parse(current);
    for (var i = 0; i < r.length || i < c.length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv != cv) return rv > cv;
    }
    return false;
  }

  /// 检查升级, 返回 VersionInfo (可能为 null)
  static Future<VersionInfo?> checkUpgrade() async {
    final platform = detectPlatform();
    final baseUrl = HttpApi.baseUrl;
    if (baseUrl.isEmpty) return null;

    final result = await HttpApi.checkUpgrade(platform);
    if (result.isSuccess() && result.data != null) {
      return result.data!;
    }
    return null;
  }

  /// 显示版本对话框
  static Future<void> showVersionDialog(
    BuildContext context, {
    required String currentVersion,
    required VersionInfo? versionInfo,
  }) async {
    final platform = detectPlatform();
    final baseUrl = HttpApi.baseUrl;
    final isIOS = platform == 'ios';

    if (versionInfo == null) {
      final subtitle = baseUrl.isEmpty
          ? l10n.upgradeCheckFailed
          : '${l10n.upgradeCheckFailed} · ${l10n.upgradeServerUrl(baseUrl)}';
      _showDialog(context, title: Text('${AppEnv.appTitle} $currentVersion'), content: Text(subtitle));
      return;
    }

    final hasUpdate = isNewerVersion(versionInfo.versionName, currentVersion);

    if (hasUpdate) {
      final downloadUrl = versionInfo.downloadUrl;
      final fullUrl = downloadUrl.startsWith('http') ? downloadUrl : '$baseUrl$downloadUrl';
      final actions = <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel))];
      if (!isIOS) {
        actions.add(
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullUrl));
              Navigator.pop(context);
              Toast.show(context, l10n.upgradeDownloadCopied(fullUrl));
            },
            child: Text(l10n.upgradeCopyDownloadUrl),
          ),
        );
        actions.add(
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              startUpgradeDownload(context, fullUrl);
            },
            child: Text(l10n.upgradeDownloadAndInstall),
          ),
        );
      }
      _showDialog(
        context,
        title: Text(l10n.upgradeAvailable(versionInfo.versionName)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.upgradeCurrentVersion(currentVersion, versionInfo.versionName),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(l10n.upgradeChangelog, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(versionInfo.changelog.isEmpty ? l10n.upgradeNoChangelog : versionInfo.changelog),
              if (isIOS) ...[
                const SizedBox(height: 12),
                Text(l10n.upgradeIOS, style: const TextStyle(color: Colors.grey)),
              ],
            ],
          ),
        ),
        actions: actions,
      );
    } else {
      // 当前已是最新, 仍提供重新下载
      final downloadUrl = versionInfo.downloadUrl;
      final fullUrl = downloadUrl.isNotEmpty && downloadUrl.startsWith('http')
          ? downloadUrl
          : (downloadUrl.isNotEmpty ? '$baseUrl$downloadUrl' : '');
      final actions = <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel))];
      if (!isIOS && fullUrl.isNotEmpty) {
        actions.add(
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              startUpgradeDownload(context, fullUrl);
            },
            child: Text(l10n.upgradeReinstall),
          ),
        );
      }
      _showDialog(
        context,
        title: Text('${AppEnv.appTitle} $currentVersion'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text(l10n.upgradeUpToDate)],
        ),
        actions: actions,
      );
    }
  }

  static void _showDialog(
    BuildContext context, {
    required Widget title,
    required Widget content,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: title,
        content: content,
        actions: actions ?? [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel))],
      ),
    );
  }

  /// 开始升级下载, 显示进度对话框
  static Future<void> startUpgradeDownload(BuildContext context, String url) async {
    final progressNotifier = ValueNotifier<double>(0);

    // 显示不可关闭的进度 dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.upgradeDownloading),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              final pct = (progress * 100).toStringAsFixed(0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress > 0 && progress < 1 ? progress : null),
                  const SizedBox(height: 8),
                  Text('$pct%'),
                ],
              );
            },
          ),
        ),
      ),
    );

    bool ok = false;
    try {
      if (Platform.isAndroid) {
        ok = await downloadAndInstallAndroid(url, onProgress: (p) => progressNotifier.value = p);
      } else if (Platform.isWindows) {
        // downloadAndInstallWindows 会 exit, 理论上走不到下面
        ok = await downloadAndInstallWindows(url, onProgress: (p) => progressNotifier.value = p);
      } else {
        // 其他平台: 只下载
        final path = await download(url, onProgress: (p) => progressNotifier.value = p);
        ok = path != null;
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.of(context).pop(); // 关闭进度 dialog

    if (ok) {
      if (!Platform.isWindows) {
        Toast.show(context, l10n.upgradeDownloadSuccess);
      }
    } else {
      Toast.show(context, l10n.upgradeDownloadFailed);
    }
  }

  /// 下载文件, 返回本地路径; 进度 [0.0 ~ 1.0]
  /// [outputPath] 指定下载完整文件路径, 默认为系统临时目录下的 notee_update{ext}
  static Future<String?> download(String url, {void Function(double progress)? onProgress, String? outputPath}) async {
    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        client.close();
        return null;
      }

      final filePath = outputPath ?? '${(await getTemporaryDirectory()).path}/notee_update${_extFromUrl(url)}';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      final totalBytes = resp.contentLength ?? -1;
      int received = 0;
      final sink = file.openWrite(mode: FileMode.write);
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress(received / totalBytes);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      onProgress?.call(1.0);
      AppLogger.i('Upgrade', 'Upgrade download OK: ${file.path}');
      return file.path;
    } catch (e) {
      AppLogger.e('Upgrade', 'Upgrade download failed: $e');
      return null;
    }
  }

  static String _extFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final dot = path.lastIndexOf('.');
    if (dot >= 0) return path.substring(dot);
    return '';
  }

  // ============================================================
  //  Android —— 下载 APK 后调起系统安装界面
  // ============================================================

  static Future<bool> downloadAndInstallAndroid(String url, {void Function(double progress)? onProgress}) async {
    if (!Platform.isAndroid) return false;
    final path = await download(url, onProgress: onProgress);
    if (path == null) return false;
    final result = await OpenFilex.open(path);
    return result.type == ResultType.done;
  }

  // ============================================================
  //  Windows —— 下载 zip → 解压 → 生成 update.bat → 退出重启
  // ============================================================

  static Future<bool> downloadAndInstallWindows(String url, {void Function(double progress)? onProgress}) async {
    if (!Platform.isWindows) return false;

    // 在 exe 同级目录下创建 upgrade 目录, 所有升级相关文件都放在这里
    final exePath = Platform.resolvedExecutable;
    final appDir = File(exePath).parent.path;
    final upgradeDir = Directory('$appDir\\upgrade');
    if (await upgradeDir.exists()) await upgradeDir.delete(recursive: true);
    await upgradeDir.create();

    // 1. 下载到 upgrade 目录下的 notee_update.zip
    final zipPath = await download(url, onProgress: onProgress, outputPath: '${upgradeDir.path}\\notee_update.zip');
    if (zipPath == null) return false;

    // 2. 解压到 upgrade\notee_update
    final updateDir = Directory('${upgradeDir.path}\\notee_update');
    try {
      final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
      await extractArchiveToDisk(archive, updateDir.path);
    } catch (e) {
      AppLogger.e('Upgrade', 'Upgrade unzip failed: $e');
      return false;
    }

    // 3. 生成 update.bat (也放在 upgrade 目录), 用 systemEncoding 写入
    final batPath = '${upgradeDir.path}\\update_notee.bat';

    final batContent =
        '''
@echo off
setlocal

set "EXE=$exePath"
set "APPDIR=$appDir"
set "UPDATE=${updateDir.path}"
set "ZIP=$zipPath"

rem --- wait for main process to exit ---
:wait
tasklist /fi "imagename eq notee.exe" 2>nul | find /i "notee.exe" >nul
if errorlevel 1 goto replace
timeout /t 1 /nobreak >nul
goto wait

:replace
rem --- overwrite ---
xcopy "%UPDATE%\\*" "%APPDIR%" /E /Y /I /Q

rem --- cleanup ---
del "%ZIP%" /q
rd "%UPDATE%" /s /q

rem --- launch ---
cd /d "%APPDIR%"
start "" "%EXE%"

rem --- self delete ---
(goto) 2>nul & del "%~f0"
''';

    await File(batPath).writeAsString(batContent, encoding: systemEncoding);
    // 4. 启动 bat (完全独立的新窗口), 退出主进程
    // 使用 start 命令启动新窗口, 显式 cmd /c 使 bat 执行完后窗口自动关闭
    await Process.start('cmd.exe', ['/c', 'start', '""', 'cmd', '/c', batPath], mode: ProcessStartMode.detached);
    await Future.delayed(const Duration(seconds: 1));
    exit(0);
  }
}
