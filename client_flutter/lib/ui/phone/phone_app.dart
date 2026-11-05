import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/record_ext.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/common/app_bar.dart';
import 'package:notee/ui/common/popup_menu.dart';
import 'package:notee/ui/editor/record_flow_editor_page.dart';
import 'package:notee/ui/files/record_list_page.dart';
import 'package:notee/ui/calendar/calendar_page.dart';
import 'package:notee/ui/files/record_recycler_page.dart';
import 'package:notee/ui/settings/settings_page.dart';
import 'package:notee/utils/utils.dart';

class PhoneApp extends BaseApp {
  const PhoneApp({super.key});

  @override
  State<PhoneApp> createState() => _PhoneAppState();
}

class _PhoneAppState extends BaseAppState<PhoneApp> {
  final _RouteObserver _observer = _RouteObserver();

  @override
  List<NavigatorObserver> get navigatorObservers => [_observer];

  @override
  void navigate(String uri) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final parsed = AppNavigatorUri.parse(uri);
    final existing = _observer.findWhere((r) => r.settings.name == parsed.urlWithPath);
    if (existing != null) {
      // 已有该 URL，pop 出它之上的所有路由回到它
      nav.popUntil((route) => route == existing);
      return;
    }
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        final uuid = parsed.firstPath ?? '';
        final keyword = parsed.queryParam('keyword');
        nav.push(
          MaterialPageRoute(
            settings: RouteSettings(name: parsed.urlWithPath),
            builder: (context) => PhoneRecordDetailPage(uuid: uuid, keyword: keyword),
          ),
        );
        break;
      case AppNavigator.uriCalendar:
        nav.push(
          MaterialPageRoute(
            settings: RouteSettings(name: parsed.urlWithPath),
            builder: (_) => const CalendarPage(showAppBar: true, closeCallback: Navigator.pop),
          ),
        );
        break;
      case AppNavigator.uriRecycler:
        nav.push(MaterialPageRoute(
          settings: RouteSettings(name: parsed.urlWithPath),
          builder: (_) => const RecordRecyclerPage(),
        ));
        break;
      case AppNavigator.uriSettings:
        nav.push(MaterialPageRoute(
          settings: RouteSettings(name: parsed.urlWithPath),
          builder: (_) => const SettingsPage(),
        ));
        break;
      default:
        break;
    }
  }

  @override
  Widget buildHome(BuildContext context) {
    return const RecordListPage();
  }
}

class PhoneRecordDetailPage extends RecordFlowEditorPage {
  final ValueCallback<BuildContext> closeCallback;
  const PhoneRecordDetailPage({super.key, required super.uuid, super.keyword, this.closeCallback = Navigator.pop});

  @override
  State<PhoneRecordDetailPage> createState() => PhoneRecordDetailPageState();
}

class PhoneRecordDetailPageState<T extends PhoneRecordDetailPage> extends RecordFlowEditorPageState<T> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: buildAppBar(context, mRecord), body: super.build(context));
  }

  PreferredSizeWidget buildAppBar(BuildContext context, RecordEntry record) {
    final readOnly = Repository.get().syncConfigs.isPathReadOnly(record.local.path);
    final titleText = readOnly ? '${l10n.readOnlyLabel} ${record.local.path}${record.local.name}' : '${record.local.path}${record.local.name}';
    return createAppBar(
      onBack: () => widget.closeCallback(context),
      titleSpacing: 0,
      titleWidget: StreamBuilder<RecordEvent>(
        stream: recordTree.onEvent,
        builder: (context, snapshot) =>
            Text(titleText, overflow: TextOverflow.fade, style: const TextStyle(fontSize: 16.0)),
      ),
      actions: [
        if (pageState.isNormal) IconButton(onPressed: saveRecord, icon: const Icon(Icons.done_outlined)),
        if (pageState.isNormal)
          PopupMenuControl<int>(
            itemsBuilder: () => buildOverflowMenuItems(context),
            onSelected: (v) {
              if (v != null) onOverflowMenuSelect(v);
            },
            child: const Icon(Icons.more_vert),
          ),
        const SizedBox(width: 8),
      ],
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
