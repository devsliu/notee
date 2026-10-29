import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/utils/reboot.dart';

import 'app_env.dart';
import '../l10n/app_localizations.dart';

// primary: primary color (e.g., buttons, AppBar background)
// secondary: secondary color (emphasis, floating buttons, etc.)
// background: main background color
// surface: surface color (background for cards, dialogs, etc.)
// primaryContainer: primary container (variant of primary, used for large-area backgrounds)
// secondaryContainer: secondary container
// onPrimary: content color on primary (e.g., text/icon color on primary buttons)
// onSecondary: content color on secondary
// onBackground: content color on background
// onSurface: content color on surface
// Generally, the recommended main background color for pages is surface, because surface
// represents the background of "surfaces" like cards and pages, suitable for most content areas.
// primaryContainer is usually used for containers that need a large area rendered with the primary
// color (e.g., emphasis blocks, button backgrounds), not for regular page backgrounds.
// Summary:
//   Page background color: use surface
//   Emphasis blocks / primary color large containers: use primaryContainer
// In Flutter's ColorScheme:
//
// primary represents the primary color, usually used as the background for components like
// buttons and AppBars.
// onPrimary represents the content color on the primary (primary), e.g., the text or icon
// color on primary buttons.
// Example explanation:
//
// If the button background uses primary, the button text color will be onPrimary.
// Your theme file comments also explain this.
// onPrimary: content color on primary (e.g., text/icon color on primary buttons)
//
// TextButton uses primary as text color by default; only "primary buttons" like ElevatedButton
// use onPrimary as text color.
// Theme color scheme list

class AppTheme {
  final String key;
  final String Function(AppLocalizations) nameBuilder;
  final ThemeData data;

  AppTheme({required this.key, required this.nameBuilder, required this.data});

  String getName(AppLocalizations l10n) => nameBuilder(l10n);
}

final appThemes = [
  // Light theme
  AppTheme(
    key: 'light',
    nameBuilder: (l10n) => l10n.themeLight,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFF5F5F5),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF8E24AA),
        secondary: Color(0xFFE7E7E7),
        surface: Color(0xFFFFFFFF),
        surfaceContainer: Color(0xFFE7E7E7),
        surfaceContainerHigh: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFFD5D5D5),
        surfaceContainerLowest: Color(0xFFF3F3F3),
        primaryContainer: Color(0xFFE7E7E7),
        secondaryContainer: Color(0xFFc7c7c7),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF333333),
        onSurface: Color(0xFF333333),
        onSurfaceVariant: Color(0xFF555555),
        outline: Color(0xFFD1D1D1),
        error: Color(0xFFFF0000),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFF9DEDC),
        onErrorContainer: Color(0xFF410E0B),
      ),
      iconTheme: IconThemeData(color: Color(0xFF222222)), // Use dark icons
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFF5F5F5), // scaffoldBackgroundColor
        foregroundColor: Color(0xFF222222),
        iconTheme: IconThemeData(color: Color(0xFF666666)),
        actionsIconTheme: IconThemeData(color: Color(0xFF333333)), // Action buttons slightly darker
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFF222222)),
      ),
      // Ensure all IconButtons use the correct color
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFF333333), // Changed to a darker color for visibility on white background
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF999999)), // Use gray consistently
        labelStyle: TextStyle(color: Color(0xFF666666)),
        floatingLabelStyle: TextStyle(color: Color(0xFF8E24AA)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF333333)), // Changed to a darker color
        bodyMedium: TextStyle(color: Color(0xFF333333)), // Changed to a darker color
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF333333), iconColor: Color(0xFF222222)),
      dialogTheme: DialogThemeData(backgroundColor: Colors.white),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFD1D1D1).withAlpha(80), width: 1),
        ),
      ),
    ),
  ),
  // Solarized Light (Ethan Schoonover's Solarized palette) - light
  AppTheme(
    key: 'solarized',
    nameBuilder: (l10n) => l10n.themeSolarized,
    data: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Color(0xFFEEE8D5), // base2 (sidebar/chrome, matches Trae)
      colorScheme: ColorScheme.light(
        primary: Color(0xFF268BD2), // blue
        secondary: Color(0xFF2AA198), // cyan
        surface: Color(0xFFFDF6E3), // base3 (editor/content bg)
        surfaceContainer: Color(0xFFEEE8D5), // base2
        surfaceContainerHigh: Color(0xFFFDF6E3), // base3
        surfaceContainerLowest: Color(0xFFEEE8D5), // base2
        primaryContainer: Color(0xFF268BD2), // blue
        secondaryContainer: Color(0xFF2AA198), // cyan
        onPrimary: Color(0xFFFDF6E3), // base3
        onSecondary: Color(0xFFFDF6E3), // base3
        onSurface: Color(0xFF657B83), // base00 (Solarized body text, darker)
        onSurfaceVariant: Color(0xFF93A1A1), // base1 (secondary)
        outline: Color(0xFF93A1A1), // base1
        error: Color(0xFFFF0000), // 正红
        onError: Color(0xFFFDF6E3),
        errorContainer: Color(0xFFF4D9D6),
        onErrorContainer: Color(0xFF601410),
      ),
      iconTheme: IconThemeData(color: Color(0xFF657B83)), // base00
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFEEE8D5), // base2 (title bar, matches Trae)
        foregroundColor: Color(0xFF586E75), // base01 (darkest)
        iconTheme: IconThemeData(color: Color(0xFF586E75)), // base01
        actionsIconTheme: IconThemeData(color: Color(0xFF586E75)), // base01
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFF586E75)), // base01 (darkest)
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF586E75))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF93A1A1)), // base1
        labelStyle: TextStyle(color: Color(0xFF586E75)), // base01
        floatingLabelStyle: TextStyle(color: Color(0xFF268BD2)), // blue
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF657B83)), // base00
        bodyMedium: TextStyle(color: Color(0xFF657B83)), // base00
      ),
      listTileTheme: ListTileThemeData(
        textColor: Color(0xFF657B83),
        iconColor: Color(0xFF586E75),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFFFDF6E3), // base3
        titleTextStyle: TextStyle(color: Color(0xFF586E75)), // base01 (darkest)
        contentTextStyle: TextStyle(color: Color(0xFF657B83)), // base00
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFDF6E3), // base3
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF93A1A1).withAlpha(80), width: 1), // base1
        ),
      ),
    ),
  ),
  // Classic elegant (sepia) - light
  AppTheme(
    key: 'classic',
    nameBuilder: (l10n) => l10n.themeClassic,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFFFF8DC), // Warm ivory background
      colorScheme: ColorScheme.light(
        primary: Color(0xFF8B4513),
        secondary: Color(0xFFD2B48C),
        surface: Color(0xFFFFF8DC),
        surfaceContainer: Color(0xFFDEB887),
        surfaceContainerHigh: Color(0xFFF0DFC0),
        surfaceContainerHighest: Color(0xFFE5CEA5),
        surfaceContainerLowest: Color(0xFFFAF8F3),
        primaryContainer: Color(0xFFD2B48C),
        secondaryContainer: Color(0xFFF5DEB3),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF654321),
        onSurface: Color(0xFF4E2222),
        onSurfaceVariant: Color(0xFF6B4423),
        outline: Color(0xFFaB6563),
        error: Color(0xFFFF0000), // 正红
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFF5D0CF),
        onErrorContainer: Color(0xFF410E0B),
      ),
      iconTheme: IconThemeData(
        color: Color(0xFF4E2222)), // Dark red-brown icons for visibility on light background
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFF0DFC0), // Warm tan AppBar
        foregroundColor: Color(0xFF4E2222),
        iconTheme: IconThemeData(color: Color(0xFF4E2222)), // Dark red-brown icons
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFF4E2222)),
        actionsIconTheme: IconThemeData(
          color: Color(0xFF4E2222)), // Dark red-brown action buttons to match title text
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF999999)), // Use gray consistently
        labelStyle: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF4E2222)),
        bodyMedium: TextStyle(color: Color(0xFF4E2222)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF4E2222), iconColor: Color(0xFF4E2222)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFFFFF8DC)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFFF8DC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF8B4513).withAlpha(80), width: 1),
        ),
      ),
      // Ensure sufficient contrast for icons in popups/dialogs
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFF4E2222), // Dark red-brown icon buttons
        ),
      ),
    ),
  ),
  // Rose Gold (elegant warm cream with rose-gold accents) - light
  AppTheme(
    key: 'roseGold',
    nameBuilder: (l10n) => l10n.themeRoseGold,
    data: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Color(0xFFFBF5EC),
      colorScheme: ColorScheme.light(
        primary: Color(0xFFB76E79),
        secondary: Color(0xFFC9A96E),
        surface: Color(0xFFFBF5EC),
        surfaceContainer: Color(0xFFF0E6D6),
        surfaceContainerHigh: Color(0xFFE8DDC8),
        surfaceContainerHighest: Color(0xFFDFD2B8),
        surfaceContainerLowest: Color(0xFFFDF8F0),
        primaryContainer: Color(0xFFE8C9CC),
        secondaryContainer: Color(0xFFF0E0C0),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF4A3728),
        onSurface: Color(0xFF4A3728),
        onSurfaceVariant: Color(0xFF8B7355),
        outline: Color(0xFFC9B89A),
        error: Color(0xFFFF0000), // 正红
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFF5D0D2),
        onErrorContainer: Color(0xFF410E0B),
      ),
      iconTheme: IconThemeData(color: Color(0xFFB76E79)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFF5E6D3),
        foregroundColor: Color(0xFFB76E79),
        iconTheme: IconThemeData(color: Color(0xFFB76E79)),
        actionsIconTheme: IconThemeData(color: Color(0xFFB76E79)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFB76E79)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFFB76E79))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFFB8A888)),
        labelStyle: TextStyle(color: Color(0xFF8B7355)),
        floatingLabelStyle: TextStyle(color: Color(0xFFB76E79)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF4A3728)),
        bodyMedium: TextStyle(color: Color(0xFF4A3728)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF4A3728), iconColor: Color(0xFFB76E79)),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFFFBF5EC),
        titleTextStyle: TextStyle(color: Color(0xFFB76E79)),
        contentTextStyle: TextStyle(color: Color(0xFF4A3728)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFBF5EC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFB76E79).withAlpha(80), width: 1),
        ),
      ),
    ),
  ),
  // Lavender purple - light
  AppTheme(
    key: 'lavender',
    nameBuilder: (l10n) => l10n.themeLavender,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFF4EEFF),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF8E6BC8),
        secondary: Color(0xFFD4A5DC),
        surface: Colors.white,
        surfaceContainer: Color(0xFFEFD9F2),
        surfaceContainerHigh: Color(0xFFE5CFF0),
        surfaceContainerHighest: Color(0xFFD9BEEA),
        surfaceContainerLowest: Color(0xFFF8F4FF),
        primaryContainer: Color(0xFF8E6BC8),
        secondaryContainer: Color(0xFFEFD9F2),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF552EAB),
        onSurface: Color(0xFF552EAB),
        onSurfaceVariant: Color(0xFF7A4FC0),
        outline: Color(0xFFC486D0),
        error: Color(0xFFFF0000), // 正红
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFF8D7DA),
        onErrorContainer: Color(0xFF410E0B),
      ),
      iconTheme: IconThemeData(color: Color(0xFF552EAB)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFE8DFF5),
        foregroundColor: Color(0xFF552EAB),
        iconTheme: IconThemeData(color: Color(0xFF552EAB)),
        actionsIconTheme: IconThemeData(color: Color(0xFF552EAB)),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFF552EAB)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFFB39DDB)),
        labelStyle: TextStyle(color: Color(0xFF7A4FC0)),
        floatingLabelStyle: TextStyle(color: Color(0xFF8E6BC8)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF552EAB)),
        bodyMedium: TextStyle(color: Color(0xFF552EAB)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF552EAB), iconColor: Color(0xFF552EAB)),
      dialogTheme: DialogThemeData(backgroundColor: Colors.white),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFC486D0).withAlpha(80), width: 1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF552EAB))),
    ),
  ),
  // Sky blue - light
  AppTheme(
    key: 'sky',
    nameBuilder: (l10n) => l10n.themeSky,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFC9E4FA),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF0277BD),
        secondary: Color(0xFF4FC3F7),
        surface: Colors.white,
        surfaceContainer: Color(0xFFB5DBF8),
        surfaceContainerHigh: Color(0xFFA2D0F6),
        surfaceContainerHighest: Color(0xFF8AC4F2),
        surfaceContainerLowest: Color(0xFFE0F0FD),
        primaryContainer: Color(0xFF81D4FA),
        secondaryContainer: Color(0xFFB3E5FC),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF0D47A1),
        onSurface: Color(0xFF08304F),
        onSurfaceVariant: Color(0xFF2D6A99),
        outline: Color(0xFF4FA3D8),
        error: Color(0xFFFF0000), // 正红
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFF8D7DA),
        onErrorContainer: Color(0xFF410E0B),
      ),
      iconTheme: IconThemeData(color: Color(0xFF08304F)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF039BE5), // Saturated sky AppBar
        foregroundColor: Color(0xFFFFFFFF),
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        actionsIconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF6E9BBC)),
        labelStyle: TextStyle(color: Color(0xFF0277BD), fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF08304F)),
        bodyMedium: TextStyle(color: Color(0xFF08304F)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF08304F), iconColor: Color(0xFF08304F)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFFE8F4FE)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFE8F4FE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF0277BD).withAlpha(80), width: 1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF08304F))),
    ),
  ),
  // Sakura (rose pink) - light
  AppTheme(
    key: 'sakura',
    nameBuilder: (l10n) => l10n.themeSakura,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFFDEEF3),
      colorScheme: ColorScheme.light(
        primary: Color(0xFFC2185B),
        secondary: Color(0xFFF8BBD0),
        surface: Colors.white,
        surfaceContainer: Color(0xFFFAD9E4),
        surfaceContainerHigh: Color(0xFFF6C6D7),
        surfaceContainerHighest: Color(0xFFF0AFC6),
        surfaceContainerLowest: Color(0xFFFFF5F8),
        primaryContainer: Color(0xFFF8BBD0),
        secondaryContainer: Color(0xFFFCE4EC),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF880E4F),
        onSurface: Color(0xFF4A1526),
        onSurfaceVariant: Color(0xFF8A4260),
        outline: Color(0xFFE590B5),
        error: Color(0xFFFF9800), // Material Orange 500 警示橙 黄多红少
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFBE9E7),
        onErrorContainer: Color(0xFF3E2723),
      ),
      iconTheme: IconThemeData(color: Color(0xFF4A1526)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFD6336C), // Saturated rose AppBar
        foregroundColor: Color(0xFFFFFFFF),
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        actionsIconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFFB0708A)),
        labelStyle: TextStyle(color: Color(0xFFAD1457), fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: Color(0xFF880E4F), fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF4A1526)),
        bodyMedium: TextStyle(color: Color(0xFF4A1526)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF4A1526), iconColor: Color(0xFF4A1526)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFFFFF5F8)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFFF5F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFC2185B).withAlpha(80), width: 1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF4A1526))),
    ),
  ),
  // Dark theme
  AppTheme(
    key: 'dark',
    nameBuilder: (l10n) => l10n.themeDark,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF222222),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF64B5F6), // 浅蓝 — 跟 error 红色拉开
        secondary: Color(0xFF2C2C32),
        surface: Color(0xFF191919),
        surfaceContainer: Color(0xFF323232),
        surfaceContainerHigh: Color(0xFF323232),
        surfaceContainerLowest: Color(0xFF353535),
        primaryContainer: Color(0xFF2C2C32),
        secondaryContainer: Color(0xFF333333),
        onPrimary: Color(0xFFD4D4D4),
        onSecondary: Color(0xFFD4D4D4),
        onSurface: Color(0xFFD4D4D4),
        onSurfaceVariant: Color(0xFF666666),
        outline: Color(0xFF666666),
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF601410),
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFF9DEDC),
      ),
      iconTheme: IconThemeData(color: Color(0xFFD4D4D4)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF222222), // scaffoldBackgroundColor
        foregroundColor: Color(0xFFD4D4D4),
        iconTheme: IconThemeData(color: Color(0xFFB0B5BD)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFD4D4D4)),
      ),
      // Ensure all IconButtons use the correct color
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFFB0B5BD), // Restored to a color suitable for dark backgrounds
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF666666)), // Use dark gray consistently
        labelStyle: TextStyle(color: Color(0xFF999999)),
        floatingLabelStyle: TextStyle(color: Color(0xFF64B5F6)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFD4D4D4)), // Input text color set to light
        bodyMedium: TextStyle(color: Color(0xFFD4D4D4)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFD4D4D4), iconColor: Color(0xFFD4D4D4)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFF232323)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF232323),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF333337).withAlpha(80), width: 1),
        ),
      ),
    ),
  ),
  // Midnight (deep navy with cyan accents) - dark
  AppTheme(
    key: 'midnight',
    nameBuilder: (l10n) => l10n.themeMidnight,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF14142B),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF4FC3F7),
        secondary: Color(0xFF81D4FA),
        surface: Color(0xFF1E1E3A),
        surfaceContainer: Color(0xFF262645),
        surfaceContainerHigh: Color(0xFF30304F),
        surfaceContainerLowest: Color(0xFF14142B),
        primaryContainer: Color(0xFF30304F),
        secondaryContainer: Color(0xFF1E3A5F),
        onPrimary: Color(0xFF14142B),
        onSecondary: Color(0xFF14142B),
        onSurface: Color(0xFF4FC3F7),
        onSurfaceVariant: Color(0xFF5C5280),
        outline: Color(0xFF4A4270),
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF601410),
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFF9DEDC),
      ),
      iconTheme: IconThemeData(color: Color(0xFF4FC3F7)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF14142B),
        foregroundColor: Color(0xFF4FC3F7),
        iconTheme: IconThemeData(color: Color(0xFF4FC3F7)),
        actionsIconTheme: IconThemeData(color: Color(0xFF4FC3F7)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFF4FC3F7)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF4FC3F7))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF5C5280)),
        labelStyle: TextStyle(color: Color(0xFF4FC3F7)),
        floatingLabelStyle: TextStyle(color: Color(0xFF4FC3F7)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF4FC3F7)),
        bodyMedium: TextStyle(color: Color(0xFF4FC3F7)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF4FC3F7), iconColor: Color(0xFF4FC3F7)),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFF262645),
        titleTextStyle: TextStyle(color: Color(0xFF4FC3F7)),
        contentTextStyle: TextStyle(color: Color(0xFF4FC3F7)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF262645),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF4FC3F7).withAlpha(80), width: 1),
        ),
      ),
    ),
  ),
  // AMOLED pure black - dark
  AppTheme(
    key: 'amoled',
    nameBuilder: (l10n) => l10n.themeAmoled,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF000000),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFFB0BEC5),
        secondary: Color(0xFF37474F),
        surface: Color(0xFF0A0A0A),
        surfaceContainer: Color(0xFF121212),
        surfaceContainerHigh: Color(0xFF1A1A1A),
        surfaceContainerHighest: Color(0xFF242424),
        surfaceContainerLowest: Color(0xFF000000),
        primaryContainer: Color(0xFF263238),
        secondaryContainer: Color(0xFF1C2529),
        onPrimary: Color(0xFF000000),
        onSecondary: Color(0xFFECEFF1),
        onSurface: Color(0xFFECEFF1),
        onSurfaceVariant: Color(0xFF78909C),
        outline: Color(0xFF455A64),
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF601410),
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFF9DEDC),
      ),
      iconTheme: IconThemeData(color: Color(0xFFECEFF1)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Color(0xFFECEFF1),
        iconTheme: IconThemeData(color: Color(0xFFB0BEC5)),
        actionsIconTheme: IconThemeData(color: Color(0xFFB0BEC5)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFECEFF1)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFFB0BEC5))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF78909C)),
        labelStyle: TextStyle(color: Color(0xFFB0BEC5)),
        floatingLabelStyle: TextStyle(color: Color(0xFFCFD8DC)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFECEFF1)),
        bodyMedium: TextStyle(color: Color(0xFFECEFF1)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFECEFF1), iconColor: Color(0xFFECEFF1)),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFF121212),
        titleTextStyle: TextStyle(color: Color(0xFFECEFF1)),
        contentTextStyle: TextStyle(color: Color(0xFFECEFF1)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF455A64).withAlpha(80), width: 1),
        ),
      ),
    ),
  ),
];
// Persistence of theme key
const String _kThemeKey = 'theme_key';

/// Universally override "color-independent" common properties across all themes
/// — executed once each during load and switch.
/// Corresponding redundant lines can be removed from individual theme definitions,
/// keeping only color-related fields.
AppTheme _applyUniversalThemePatch(AppTheme theme) {
  final data = theme.data;
  final cs = data.colorScheme;
  // Unified derivations (brightness-agnostic) — source fields are required in each theme;
  // these derived fields are auto-filled here so they needn't appear in every theme.
  final patchedScheme = cs.copyWith(
    background: data.scaffoldBackgroundColor,
    onBackground: cs.onSurface,
    surfaceVariant: cs.surfaceContainer,
    onPrimaryContainer: cs.onPrimary,
    onSecondaryContainer: cs.onSecondary,
    tertiary: cs.primary,
    onTertiary: cs.onPrimary,
    tertiaryContainer: cs.primaryContainer,
    onTertiaryContainer: cs.onPrimary,
    outlineVariant: cs.outline,
  );
  return AppTheme(
    key: theme.key,
    nameBuilder: theme.nameBuilder,
    data: data.copyWith(
      colorScheme: patchedScheme,
      dialogTheme: data.dialogTheme.copyWith(
        insetPadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2.0))),
      ),
      popupMenuTheme: data.popupMenuTheme.copyWith(menuPadding: EdgeInsets.zero),
      appBarTheme: data.appBarTheme.copyWith(elevation: 0, scrolledUnderElevation: 0),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _SlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _SlidePageTransitionsBuilder(),
          TargetPlatform.windows: _SlidePageTransitionsBuilder(),
          TargetPlatform.linux: _SlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SlidePageTransitionsBuilder(),
        },
      ),
    ),
  );
}

/// 全局左右滑动转场：新页面从右侧滑入，退出时向右侧滑出。
class _SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}

AppTheme _getSavedTheme() {
  final keyStr = AppEnv.prefs.getString(_kThemeKey) ?? 'light';
  final theme = appThemes.firstWhere((t) => t.key == keyStr, orElse: () => appThemes[0]);
  return _applyUniversalThemePatch(theme);
}

AppTheme _currentTheme = _getSavedTheme();
AppTheme get gAppTheme => _currentTheme;
ThemeData get gAppThemeData => _currentTheme.data;

Future<void> switchAppTheme(AppTheme theme) async {
  if (_currentTheme != theme) {
    AppEnv.prefs.setString(_kThemeKey, theme.key).save();
    _currentTheme = _applyUniversalThemePatch(theme);
    // Trigger app reboot
    Reboot.trigger();
  }
}

// Extension for AppTheme - similar to Kotlin extension functions
extension AppThemeExtensions on ThemeData {
  ButtonStyle get appBarIconButtonStyle {
    var color = appBarIconColor;
    return IconButton.styleFrom(
      foregroundColor: color,
      disabledForegroundColor: color.withAlpha(100), // Icon color when disabled
    );
  }

  Color get appBarIconColor =>
      appBarTheme.iconTheme?.color ?? iconTheme.color ?? appBarTheme.foregroundColor ?? colorScheme.onPrimary;

  Color get appBarBackgroundColor => appBarTheme.backgroundColor ?? colorScheme.primary;

  Color get appBarForegroundColor => appBarTheme.foregroundColor ?? colorScheme.onPrimary;

  /// Get IconButton theme data for the AppBar area
  IconButtonThemeData get appBarIconButtonTheme {
    return IconButtonThemeData(style: appBarIconButtonStyle);
  }

  IconButtonThemeData get appBarIconButtonThemeShrink {
    return IconButtonThemeData(
      // 1. Extract and copy the original style from the theme (since it supports copyWith)
      style:
          appBarIconButtonTheme.style?.copyWith(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Fix spacing issues on mobile
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ) ??
          // 2. If the original style is null, create a new one directly
          IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: EdgeInsets.zero),
    );
  }
}
