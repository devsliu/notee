import 'package:flutter/material.dart';
import 'package:notee/config/app_env.dart';
import 'package:notee/ui/desktop/desktop_title_bar.dart';

import '../../utils/utils.dart';

PreferredSizeWidget createAppBar({
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  VoidCallback? onBack,
  bool automaticallyImplyLeading = true,
  Color? backgroundColor,
  Color? foregroundColor,
  double? titleSpacing,
}) {
  final isDesktop = Utils.isDesktop();
  final useDesktopBar = isDesktop && AppEnv.getLayoutMode() == LayoutMode.desktop;
  final appBarHeight = AppEnv.getAppBarHeight();

  Widget effectiveTitle = titleWidget ?? Text(title ?? '');
  if (isDesktop) {
    effectiveTitle = WindowMoveBar(titleBarHeight: appBarHeight, child: effectiveTitle);
  }

  final effectiveLeading =
      leading ?? (onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack) : null);
  final resolvedSpacing = titleSpacing ?? AppEnv.pageHorizontalPadding;

  return AppBar(
    title: effectiveTitle,
    leading: effectiveLeading,
    automaticallyImplyLeading: automaticallyImplyLeading && effectiveLeading == null,
    actions: [
      ...?actions, //if (isDesktop && showWindowButtons) const WindowManagerButtons()
    ],
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    titleSpacing: resolvedSpacing,
    toolbarHeight: appBarHeight,
    elevation: useDesktopBar ? 0 : null,
    scrolledUnderElevation: useDesktopBar ? 0 : null,
    leadingWidth: appBarHeight,
    flexibleSpace: useDesktopBar ? const WindowMoveBar() : null,
  );
}
