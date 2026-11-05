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

import 'ui/desktop/desktop_app.dart';
import 'ui/phone/phone_app.dart';
import 'ui/pad/pad_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Keep only the latest 10000 log entries across sessions.
  await AppLogger.prune();

  await AppEnv.init();
  LanguageManager.init();
  await Repository.init(AppEnv.appRootDir);
  Repository.get().recordTree.setSortListType(AppEnv.listPageValue.sortType);
  RecordOpenedState.get().setOpenedFolder("/");

  if (Utils.isDesktop()) {
    await DesktopApp.initWindows();
  }
  AppLogger.i('Main', 'init complete, runApp');

  // 根节点监听 Reboot, 切换布局模式后可在 PadApp/PhoneApp 之间重建
  runApp(ValueListenableBuilder<int>(valueListenable: Reboot.notifier, builder: (_, _, _) => _buildApp()));
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
