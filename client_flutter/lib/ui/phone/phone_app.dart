import 'package:flutter/material.dart';
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
  @override
  void navigate(String uri) {
    final parsed = AppNavigatorUri.parse(uri);
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        final uuid = parsed.firstPath ?? '';
        final keyword = parsed.queryParam('keyword');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PhoneRecordDetailPage(uuid: uuid, keyword: keyword),
          ),
        );
        break;
      case AppNavigator.uriCalendar:
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => CalendarPage(showAppBar: true, closeCallback: Navigator.pop)),
        );
        break;
      case AppNavigator.uriRecycler:
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => RecordRecyclerPage()));
        break;
      case AppNavigator.uriSettings:
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => SettingsPage()));
        break;
      default:
        break;
    }
  }

  @override
  Widget buildHome(BuildContext context) {
    return RecordListPage();
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
    return createAppBar(
      onBack: () => widget.closeCallback(context),
      titleSpacing: 0,
      titleWidget: StreamBuilder<RecordEvent>(
        stream: recordTree.onEvent,
        builder: (context, snapshot) =>
            Text(record.local.path + record.local.name, overflow: TextOverflow.fade, style: TextStyle(fontSize: 16.0)),
      ),
      actions: [
        if (pageState.isNormal) IconButton(onPressed: saveRecord, icon: Icon(Icons.done_outlined)),
        if (pageState.isNormal)
          PopupMenuControl<int>(
            itemsBuilder: () => buildOverflowMenuItems(context),
            onSelected: (v) {
              if (v != null) onOverflowMenuSelect(v);
            },
            child: const Icon(Icons.more_vert),
          ),
        SizedBox(width: 8),
      ],
    );
  }
}
