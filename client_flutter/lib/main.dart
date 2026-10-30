import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/model/record_opened_state.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:notee/utils/reboot.dart';
import 'package:notee/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/desktop/desktop_app.dart';
import 'ui/phone/phone_app.dart';
import 'ui/pad/pad_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep only the latest 10000 log entries across sessions.
  await AppLogger.prune();

  // Global crash handlers — set up before any async work so nothing slips through
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e('Crash', "FlutterError: ${details.exception}\n${details.stack}");
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Crash', "PlatformError: $error\n$stack");
    return true;
  };

  AppLogger.i('Main', '=== app start ===');
  AppLogger.i('Main', 'platform: $defaultTargetPlatform');

  await AppEnv.init();
  LanguageManager.init();
  await Repository.init(AppEnv.appRootDir);
  Repository.get().recordTree.setSortListType(AppEnv.listPageValue.sortType);
  RecordOpenedState.get().setOpenedFolder("/");

  if (Utils.isDesktop()) {
    await _initWindows();
  }
  AppLogger.i('Main', 'init complete, runApp');

  // 根节点监听 Reboot, 切换布局模式后可在 PadApp/PhoneApp 之间重建
  runApp(ValueListenableBuilder<int>(valueListenable: Reboot.notifier, builder: (_, _, _) => _buildApp()));
}

Future<void> _initWindows() async {
  await windowManager.ensureInitialized();
  final p = AppEnv.prefs;
  final width = p.getDouble(PrefKeys.windowWidth);
  final height = p.getDouble(PrefKeys.windowHeight);
  final posX = p.getDouble(PrefKeys.windowPosX);
  final posY = p.getDouble(PrefKeys.windowPosY);
  final maximized = p.getBool(PrefKeys.windowMaximized) ?? false;
  Size? size = (width != null && height != null) ? Size(width, height) : null;
  Offset? pos = (posX != null && posY != null) ? Offset(posX, posY) : null;
  WindowOptions windowOptions = WindowOptions(
    size: size ?? const Size(900, 600),
    center: size == null && pos == null,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(300, 300));
    await windowManager.setTitle(AppEnv.appTitle);
    if (pos != null && !maximized) {
      await windowManager.setPosition(pos);
    }
    await windowManager.show();
    await windowManager.focus();
    if (maximized) {
      await windowManager.maximize();
    }
  });
}

Widget _buildApp() {
  switch (AppEnv.getLayoutMode()) {
    case LayoutMode.desktop:
      return DesktopApp();
    case LayoutMode.pad:
      return PadApp();
    case LayoutMode.phone:
      return PhoneApp();
    default:
      return PhoneApp();
  }
}
