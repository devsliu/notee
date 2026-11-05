import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:notee/ui/common/popup_menu.dart';

class _Labeled extends StatelessWidget {
  const _Labeled({required this.message, required this.child});
  final String message;
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

Widget _wrapLabel(BuildContext ctx, String id, String msg, Widget child) => _Labeled(message: msg, child: child);

ToolbarItem buildToolbarItemWithMenu({
  required String id,
  required int group,
  required Widget icon,
  required List<ToolbarItem> children,
  String tooltip = '',
}) {
  return ToolbarItem(
    id: id,
    group: group,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final menu = _ToolbarMenuAnchor(
        itemsBuilder: () => children
            .map((c) {
              final built =
                  c.builder?.call(context, editorState, highlightColor, iconColor, _wrapLabel) ??
                  const SizedBox.shrink();
              final inner = _unwrapLabel(built);
              // builder 返回 SizedBox 表示条件不满足，跳过该项
              if (inner is SizedBox) return null;
              final isHighlight = inner is SVGIconItemWidget ? inner.isHighlight : false;
              final label = _extractLabel(built, c);
              final Color? color = isHighlight ? highlightColor : null;
              return PopupItem<dynamic>.simple2(
                icon: IconTheme.merge(
                  data: IconThemeData(color: color),
                  child: IgnorePointer(child: inner),
                ),
                title: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color),
                ),
                onTap: inner is SVGIconItemWidget ? inner.onPressed : null,
              );
            })
            .whereType<PopupItem<dynamic>>()
            .toList(),
        child: IconTheme(
          data: IconThemeData(color: iconColor, size: 18),
          child: SizedBox(width: 30, height: 30, child: icon),
        ),
      );

      if (tooltipBuilder != null && tooltip.isNotEmpty) {
        return tooltipBuilder(context, id, tooltip, menu);
      }
      return menu;
    },
  );
}

class _ToolbarMenuAnchor extends StatefulWidget {
  const _ToolbarMenuAnchor({required this.itemsBuilder, required this.child});

  final List<PopupItem<dynamic>> Function() itemsBuilder;
  final Widget child;

  @override
  State<_ToolbarMenuAnchor> createState() => _ToolbarMenuAnchorState();
}

class _ToolbarMenuAnchorState extends State<_ToolbarMenuAnchor> {
  bool _open = false;

  void _openMenu() {
    if (_open) return;
    _open = true;
    final items = widget.itemsBuilder();

    showPopup<dynamic>(context: context, items: items).whenComplete(() {
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: _openMenu, child: widget.child);
  }
}

Widget _unwrapLabel(Widget w) {
  Widget cur = w;
  while (cur is _Labeled) {
    cur = cur.child;
  }
  return cur;
}

String _extractLabel(Widget built, ToolbarItem item) {
  if (item.tooltipsMessage.isNotEmpty) return item.tooltipsMessage;
  Widget cur = built;
  while (cur is _Labeled) {
    if (cur.message.isNotEmpty) return cur.message;
    cur = cur.child;
  }
  return item.id;
}
