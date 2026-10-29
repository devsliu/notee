import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/calendar/calendar_page.dart';
import 'package:notee/ui/common/empty_detail_placeholder.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/common/split_layout.dart';
import 'package:notee/ui/files/record_recycler_page.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/app_env.dart';

import 'package:notee/ui/files/record_list_page.dart';
import 'package:notee/ui/phone/phone_app.dart';
import 'package:notee/ui/settings/settings_page.dart';

class PadApp extends BaseApp {
  const PadApp({super.key});

  @override
  State<PadApp> createState() => _PadAppState();
}

class _PadAppState extends BaseAppState<PadApp> {
  static const double minLeftWidth = 300;
  static const double maxLeftWidth = 500;
  static const String _rootRoute = '/';
  static const int _maxRoutes = 5;
  double leftWidth = minLeftWidth;
  final GlobalKey<NavigatorState> _rightNavKey = GlobalKey();
  final _RouteObserver _observer = _RouteObserver();
  bool _restored = false;

  Widget _buildEmptyDetail() {
    return Scaffold(
      appBar: createAppBar(),
      body: EmptyDetailPlaceholder(title: AppEnv.appTitle),
    );
  }

  @override
  void initState() {
    super.initState();
    leftWidth = AppEnv.prefs.getDouble(PrefKeys.windowLeftWidth) ?? 0;
    if (leftWidth == 0) {
      final w = WidgetsBinding.instance.platformDispatcher.views.first;
      leftWidth = (w.physicalSize.width / w.devicePixelRatio / 3).clamp(minLeftWidth, maxLeftWidth);
    }
    Repository.get().recordTree.countNotifier.addListener(_onRecordTreeCountChanged);
    _onRecordTreeCountChanged();
  }

  @override
  void dispose() {
    Repository.get().recordTree.countNotifier.removeListener(_onRecordTreeCountChanged);
    super.dispose();
  }

  @override
  void onAppTerminating() {
    _saveCurrentRoute();
    super.onAppTerminating();
  }

  void _onRecordTreeCountChanged() {
    if (_restored) return;
    if (AppEnv.appUptime.inSeconds > 10) {
      _restored = true;
      return;
    }
    if (Repository.get().recordTree.countNotifier.value <= 0) return;
    _restored = true;
    Timer.run(_restoreRoute);
  }

  void _restoreRoute() {
    final saved = AppEnv.getOpenedTabs();
    if (saved == null || saved.tabs.isEmpty) return;
    try {
      final uri = saved.tabs.first;
      final parsed = AppNavigatorUri.parse(uri);
      if (parsed.uri == AppNavigator.uriRecord) {
        final uuid = parsed.firstPath ?? '';
        if (Repository.get().recordTree.findRecord(uuid) == null) return;
      }
      navigate(uri);
    } catch (_) {}
  }

  void _saveCurrentRoute() {
    String? topUri;
    for (final r in _observer.history.reversed) {
      if (r.settings.name != null && r.settings.name != _rootRoute && r.settings.name!.isNotEmpty) {
        topUri = r.settings.name!;
        break;
      }
    }
    AppEnv.setOpenedTabs(0, topUri != null ? [topUri] : null);
  }

  Route? _generateRoute(RouteSettings settings) {
    if (settings.name == _rootRoute) {
      return MaterialPageRoute(builder: (_) => _buildEmptyDetail(), settings: settings);
    }
    final uri = settings.name!;
    final parsed = AppNavigatorUri.parse(uri);
    final key = settings.arguments as GlobalKey;
    Widget page;
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        final uuid = parsed.firstPath ?? '';
        final keyword = parsed.queryParam('keyword');
        page = PhoneRecordDetailPage(key: key, uuid: uuid, keyword: keyword);
        break;
      case AppNavigator.uriCalendar:
        page = CalendarPage(key: key, showAppBar: true);
        break;
      case AppNavigator.uriRecycler:
        page = RecordRecyclerPage(key: key, showAppBar: true);
        break;
      case AppNavigator.uriSettings:
        page = SettingsPage(key: key, showAppBar: true);
        break;
      default:
        return null;
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  @override
  void navigate(String uri) {
    final nav = _rightNavKey.currentState;
    if (nav == null) return;
    final parsed = AppNavigatorUri.parse(uri);
    final existing = _observer.findWhere((r) {
      final name = r.settings.name;
      if (name == null) return false;
      final p = AppNavigatorUri.parse(name);
      return p.uri == parsed.uri && p.firstPath == parsed.firstPath;
    });
    GlobalKey? reuseKey;
    if (existing != null) {
      reuseKey = existing.settings.arguments as GlobalKey?;
      nav.removeRoute(existing);
    }
    reuseKey ??= GlobalKey(); 
    while (_observer.history.length > _maxRoutes) {
      nav.removeRoute(_observer.history[1]);
    }
    nav.pushNamed(uri, arguments: reuseKey);
  }

  @override
  Widget buildHome(BuildContext context) {
    return SplitLayout(
      leftWidth: leftWidth,
      minLeftWidth: minLeftWidth,
      maxLeftWidth: maxLeftWidth,
      draggerTopOffset: AppEnv.getAppBarHeight(),
      onLeftWidthChanged: (w) {
        leftWidth = w;
        AppEnv.prefs.setDouble(PrefKeys.windowLeftWidth, w);
      },
      leftChild: RecordListPage(),
      rightChild: ScaffoldMessenger(
        child: Navigator(
          key: _rightNavKey,
          initialRoute: _rootRoute,
          onGenerateRoute: _generateRoute,
          observers: [_observer],
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  final List<Route> history = [];

  Route? findWhere(bool Function(Route) test) {
    for (final r in history.reversed) {
      if (test(r)) return r;
    }
    return null;
  }

  @override
  void didPush(Route route, Route? previousRoute) => history.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => history.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => history.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) history.remove(oldRoute);
    if (newRoute != null) history.add(newRoute);
  }
}
