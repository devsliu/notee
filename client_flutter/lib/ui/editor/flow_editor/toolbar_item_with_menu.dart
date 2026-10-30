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

Widget _wrapLabel(BuildContext ctx, String id, String msg, Widget child) =>
    _Labeled(message: msg, child: child);

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
      final menu = PopupMenuControl(
        highlightColor: highlightColor,
        itemsBuilder: () => children.map((c) {
          final built = c.builder?.call(context, editorState, highlightColor, iconColor, _wrapLabel) ??
              const SizedBox.shrink();
          final inner = _unwrapLabel(built);
          return PopupItem(
            icon: IgnorePointer(child: inner),
            label: _extractLabel(built, c),
            isHighlight: inner is SVGIconItemWidget ? inner.isHighlight : false,
            onTap: inner is SVGIconItemWidget ? inner.onPressed : null,
          );
        }).toList(),
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
