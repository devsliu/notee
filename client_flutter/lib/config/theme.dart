import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notee/utils/reboot.dart';

import 'app_env.dart';
import '../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Minimal semantic theme model.
//
// 3 required anchors  →  derivation algorithm  →  fully populated ThemeData
//
// New themes need just: surface, onSurface, primary, key, nameBuilder.
// Every other color is derived automatically; only the unusual bits (surface
// containers that don't follow the blend formula, a custom error color, an
// AppBar that uses the accent primary, ...) need explicit overrides.
// ---------------------------------------------------------------------------

Color _blend(Color from, Color to, double ratio) {
  final r = (from.r + ((to.r - from.r) * ratio)).round().clamp(0, 255);
  final g = (from.g + ((to.g - from.g) * ratio)).round().clamp(0, 255);
  final b = (from.b + ((to.b - from.b) * ratio)).round().clamp(0, 255);
  return Color.fromRGBO(r, g, b, from.a);
}

Color _contrastBW(Color c) => c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

class ThemeSpec {
  const ThemeSpec({
    // ---- Identity ----
    required this.key,
    required this.nameBuilder,

    // ---- Brightness hint (auto-derived from surface if null) ----
    this.brightness,

    // ---- 3 core semantic anchors (required) ----
    required this.surface,
    required this.onSurface,
    required this.primary,

    // ---- Surface family ----
    this.surfaceContainers,
    this.onSurfaceVariant,

    // ---- Primary family ----
    this.primaryContainer,

    // ---- Secondary family ----
    this.secondary,
    this.secondaryContainer,

    // ---- Error family ----
    this.error,

    // ---- Outline ----
    this.outline,

    // ---- AppBar ----
    this.appBarBg,
    this.appBarFg,

    // ---- Scaffold background (default = surface) ----
    this.scaffoldBg,

    // ---- Icon color (default = onSurface) ----
    this.iconColor,

    // ---- Interaction polish ----
    this.selectionColor,
  });

  // ---- Identity ----
  final String key;
  final String Function(AppLocalizations) nameBuilder;

  // ---- Brightness ----
  final Brightness? brightness;

  // ---- 3 core anchors ----
  final Color surface;
  final Color onSurface;
  final Color primary;

  // ---- Surface family ----
  /// 4 values: Lowest, Container, High, Highest. Null = auto-blend.
  final List<Color>? surfaceContainers;
  final Color? onSurfaceVariant;

  // ---- Primary family ----
  final Color? primaryContainer;

  // ---- Secondary family ----
  final Color? secondary;
  final Color? secondaryContainer;

  // ---- Error family ----
  final Color? error;

  // ---- Outline ----
  final Color? outline;

  // ---- AppBar ----
  final Color? appBarBg;
  final Color? appBarFg;

  // ---- Scaffold ----
  final Color? scaffoldBg;

  // ---- Icon color ----
  final Color? iconColor;

  // ---- Interaction polish ----
  final Color? selectionColor;

  AppTheme toAppTheme() {
    final br = brightness ?? (surface.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark);
    final isLight = br == Brightness.light;

    // --- surface container hierarchy ---
    final List<Color> sc;
    if (surfaceContainers != null && surfaceContainers!.length == 4) {
      sc = surfaceContainers!;
    } else {
      sc = [
        _blend(surface, onSurface, 0.01), // Lowest
        _blend(surface, onSurface, 0.04), // Container
        _blend(surface, onSurface, 0.07), // High
        _blend(surface, onSurface, 0.10), // Highest
      ];
    }
    final scLowest = sc[0];
    final scMid = sc[1];
    final scHigh = sc[2];
    final scHighest = sc[3];

    // --- ColorScheme derivations ---
    final sec = secondary ?? scMid;
    final pContainer = primaryContainer ?? _blend(surface, primary, 0.18);
    final secContainer = secondaryContainer ?? _blend(scMid, sec, 0.15);
    final onP = _contrastBW(primary);
    final onSVariant = onSurfaceVariant ?? _blend(onSurface, surface, 0.55);
    final out = outline ?? _blend(onSurface, surface, 0.70);
    final onSec = _contrastBW(sec);
    final err = error ?? (isLight ? const Color(0xFFFF0000) : const Color(0xFFFF6B6B));
    final onErr = _contrastBW(err);
    final errContainer = _blend(surface, err, 0.15);
    final onErrContainer = _contrastBW(errContainer);

    // --- AppBar ---
    final abBg = appBarBg ?? scMid;
    final abFg = appBarFg ?? onSurface;

    // --- Icon / cursor colors ---
    final ic = iconColor ?? onSurface;
    final hint = out.withAlpha(180);
    final fl = primary;
    final cursor = primary;
    final sel = selectionColor ?? primary.withAlpha(100);
    final selHandle = cursor;

    // inverseSurface = whichever of surface/onSurface is the dark one.
    final invSurface = surface.computeLuminance() > 0.5 ? onSurface : surface;

    // --- Build ColorScheme ---
    final csBase = ColorScheme(
      brightness: br,
      primary: primary,
      onPrimary: onP,
      primaryContainer: pContainer,
      onPrimaryContainer: onP,
      secondary: sec,
      onSecondary: onSec,
      secondaryContainer: secContainer,
      onSecondaryContainer: onSec,
      tertiary: primary,
      onTertiary: onP,
      tertiaryContainer: pContainer,
      onTertiaryContainer: onP,
      error: err,
      onError: onErr,
      errorContainer: errContainer,
      onErrorContainer: onErrContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: scLowest,
      surfaceContainerLow: _blend(scLowest, scMid, 0.5),
      surfaceContainer: scMid,
      surfaceContainerHigh: scHigh,
      surfaceContainerHighest: scHighest,
      onSurfaceVariant: onSVariant,
      outline: out,
      outlineVariant: out,
      inverseSurface: invSurface,
      onInverseSurface: _contrastBW(invSurface),
      inversePrimary: primary,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return AppTheme(
      key: key,
      nameBuilder: nameBuilder,
      data: ThemeData(
        brightness: br,
        scaffoldBackgroundColor: scaffoldBg ?? surface,
        colorScheme: csBase,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: abBg,
          foregroundColor: abFg,
          iconTheme: IconThemeData(color: abFg),
          actionsIconTheme: IconThemeData(color: abFg),
          systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(fontSize: 18, color: abFg),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        iconTheme: IconThemeData(color: ic),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: ic)),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: hint),
          labelStyle: TextStyle(color: onSVariant),
          floatingLabelStyle: TextStyle(color: fl),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: onSurface),
          bodyMedium: TextStyle(color: onSurface),
        ),
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: sel,
          selectionHandleColor: selHandle,
          cursorColor: cursor,
        ),
        listTileTheme: ListTileThemeData(textColor: onSurface, iconColor: ic),
        dividerColor: out.withAlpha(80),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(color: out.withAlpha(80), width: 1),
          ),
        ),
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
}

class AppTheme {
  final String key;
  final String Function(AppLocalizations) nameBuilder;
  final ThemeData data;
  AppTheme({required this.key, required this.nameBuilder, required this.data});
  String getName(AppLocalizations l10n) => nameBuilder(l10n);
}

// ---------------------------------------------------------------------------
// Theme definitions — the 11 built-in themes.
// Now each theme is 5 required fields + a few targeted overrides.
// ---------------------------------------------------------------------------

final appThemes = [
  ThemeSpec(
    key: 'light',
    nameBuilder: (l10n) => l10n.themeLight,
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF333333),
    primary: const Color(0xFF8E24AA),
    scaffoldBg: const Color(0xFFF5F5F5),
    surfaceContainers: const [Color(0xFFF3F3F3), Color(0xFFE7E7E7), Color(0xFFE0E0E0), Color(0xFFD5D5D5)],
    primaryContainer: const Color(0xFFE7E7E7),
    secondaryContainer: const Color(0xFFC7C7C7),
  ),

  ThemeSpec(
    key: 'solarized',
    nameBuilder: (l10n) => l10n.themeSolarized,
    surface: const Color(0xFFFDF6E3),
    onSurface: const Color(0xFF657B83),
    primary: const Color(0xFF268BD2),
    scaffoldBg: const Color(0xFFEEE8D5),
    appBarBg: const Color(0xFFEEE8D5),
    appBarFg: const Color(0xFF586E75),
    surfaceContainers: const [Color(0xFFFDF6E3), Color(0xFFEEE8D5), Color(0xFFE5DCC5), Color(0xFFDCD3B5)],
    primaryContainer: const Color(0xFF268BD2),
    secondaryContainer: const Color(0xFF2AA198),
    outline: const Color(0xFF93A1A1),
    onSurfaceVariant: const Color(0xFF93A1A1),
    iconColor: const Color(0xFF586E75),
  ),

  ThemeSpec(
    key: 'classic',
    nameBuilder: (l10n) => l10n.themeClassic,
    surface: const Color(0xFFFFF8DC),
    onSurface: const Color(0xFF4E2222),
    primary: const Color(0xFF8B4513),
    appBarBg: const Color(0xFFF0DFC0),
    surfaceContainers: const [Color(0xFFFAF8F3), Color(0xFFDEB887), Color(0xFFF0DFC0), Color(0xFFE5CEA5)],
    primaryContainer: const Color(0xFFD2B48C),
    secondaryContainer: const Color(0xFFF5DEB3),
    outline: const Color(0xFFAB6563),
  ),

  ThemeSpec(
    key: 'roseGold',
    nameBuilder: (l10n) => l10n.themeRoseGold,
    surface: const Color(0xFFFBF5EC),
    onSurface: const Color(0xFF4A3728),
    primary: const Color(0xFFB76E79),
    appBarBg: const Color(0xFFF5E6D3),
    appBarFg: const Color(0xFFB76E79),
    surfaceContainers: const [Color(0xFFFDF8F0), Color(0xFFF0E6D6), Color(0xFFE8DDC8), Color(0xFFDFD2B8)],
    primaryContainer: const Color(0xFFE8C9CC),
    secondaryContainer: const Color(0xFFF0E0C0),
    outline: const Color(0xFFC9B89A),
    iconColor: const Color(0xFFB76E79),
  ),

  ThemeSpec(
    key: 'lavender',
    nameBuilder: (l10n) => l10n.themeLavender,
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF552EAB),
    primary: const Color(0xFF8E6BC8),
    scaffoldBg: const Color(0xFFF4EEFF),
    appBarBg: const Color(0xFFE8DFF5),
    surfaceContainers: const [Color(0xFFF8F4FF), Color(0xFFEFD9F2), Color(0xFFE5CFF0), Color(0xFFD9BEEA)],
    primaryContainer: const Color(0xFF8E6BC8),
    secondaryContainer: const Color(0xFFEFD9F2),
    outline: const Color(0xFFC486D0),
    onSurfaceVariant: const Color(0xFF7A4FC0),
  ),

  ThemeSpec(
    key: 'sky',
    nameBuilder: (l10n) => l10n.themeSky,
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF08304F),
    primary: const Color(0xFF0277BD),
    appBarBg: const Color(0xFF039BE5),
    appBarFg: const Color(0xFFFFFFFF),
    surfaceContainers: const [Color(0xFFE0F0FD), Color(0xFFB5DBF8), Color(0xFFA2D0F6), Color(0xFF8AC4F2)],
    primaryContainer: const Color(0xFF81D4FA),
    secondaryContainer: const Color(0xFFB3E5FC),
    outline: const Color(0xFF4FA3D8),
    onSurfaceVariant: const Color(0xFF2D6A99),
  ),

  ThemeSpec(
    key: 'sakura',
    nameBuilder: (l10n) => l10n.themeSakura,
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF4A1526),
    primary: const Color(0xFFC2185B),
    appBarBg: const Color(0xFFD6336C),
    appBarFg: const Color(0xFFFFFFFF),
    error: const Color(0xFFFF9800),
    surfaceContainers: const [Color(0xFFFFF5F8), Color(0xFFFAD9E4), Color(0xFFF6C6D7), Color(0xFFF0AFC6)],
    primaryContainer: const Color(0xFFF8BBD0),
    secondaryContainer: const Color(0xFFFCE4EC),
    outline: const Color(0xFFE590B5),
    onSurfaceVariant: const Color(0xFF8A4260),
  ),

  ThemeSpec(
    key: 'dark',
    nameBuilder: (l10n) => l10n.themeDark,
    surface: const Color(0xFF191919),
    onSurface: const Color(0xFFD4D4D4),
    primary: const Color(0xFF64B5F6),
    brightness: Brightness.dark,
    scaffoldBg: const Color(0xFF222222),
    appBarBg: const Color(0xFF252525),
    surfaceContainers: const [Color(0xFF353535), Color(0xFF323232), Color(0xFF323232), Color(0xFF353535)],
    primaryContainer: const Color(0xFF2C2C32),
    secondaryContainer: const Color(0xFF333333),
    outline: const Color(0xFF666666),
    onSurfaceVariant: const Color(0xFF666666),
    error: const Color(0xFFFF6B6B),
    iconColor: const Color(0xFFB0B5BD),
    selectionColor: const Color(0xC8666666),
  ),

  ThemeSpec(
    key: 'midnight',
    nameBuilder: (l10n) => l10n.themeMidnight,
    surface: const Color(0xFF1E1E3A),
    onSurface: const Color(0xFF4FC3F7),
    primary: const Color(0xFF4FC3F7),
    brightness: Brightness.dark,
    scaffoldBg: const Color(0xFF14142B),
    appBarBg: const Color(0xFF14142B),
    surfaceContainers: const [Color(0xFF14142B), Color(0xFF262645), Color(0xFF30304F), Color(0xFF38385C)],
    primaryContainer: const Color(0xFF30304F),
    secondaryContainer: const Color(0xFF1E3A5F),
    outline: const Color(0xFF4A4270),
    onSurfaceVariant: const Color(0xFF5C5280),
    error: const Color(0xFFFF6B6B),
    selectionColor: const Color(0xC85C5280),
  ),

  ThemeSpec(
    key: 'amoled',
    nameBuilder: (l10n) => l10n.themeAmoled,
    surface: const Color(0xFF0A0A0A),
    onSurface: const Color(0xFFECEFF1),
    primary: const Color(0xFFB0BEC5),
    brightness: Brightness.dark,
    scaffoldBg: const Color(0xFF000000),
    appBarBg: const Color(0xFF000000),
    surfaceContainers: const [Color(0xFF000000), Color(0xFF121212), Color(0xFF1A1A1A), Color(0xFF242424)],
    primaryContainer: const Color(0xFF263238),
    secondaryContainer: const Color(0xFF1C2529),
    outline: const Color(0xFF455A64),
    onSurfaceVariant: const Color(0xFF78909C),
    error: const Color(0xFFFF6B6B),
    iconColor: const Color(0xFFB0BEC5),
    selectionColor: const Color(0xC878909C),
  ),

  // Aurora — multi-hued, every color intentionally different.
  ThemeSpec(
    key: 'aurora',
    nameBuilder: (l10n) => l10n.themeAurora,
    surface: const Color(0xFF11183D),
    onSurface: const Color(0xFFFFB74D),
    primary: const Color(0xFF00E676),
    brightness: Brightness.dark,
    scaffoldBg: const Color(0xFF0A0F2E),
    appBarBg: const Color(0xFF0D1538),
    appBarFg: const Color(0xFFFF5252),
    secondary: const Color(0xFFFF5252),
    surfaceContainers: const [Color(0xFF070B20), Color(0xFF1A2350), Color(0xFF222C66), Color(0xFF2B3680)],
    primaryContainer: const Color(0xFF0B3D2E),
    secondaryContainer: const Color(0xFF4A1020),
    outline: const Color(0xFFFFB300),
    onSurfaceVariant: const Color(0xFFFFE0B2),
    error: const Color(0xFFFF6E40),
    iconColor: const Color(0xFF69F0AE),
    selectionColor: const Color(0x8CFFEB3B),
  ),
];

// ---------------------------------------------------------------------------
// Page transition
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Persistence / access
// ---------------------------------------------------------------------------

const String _kThemeKey = 'theme_key';

AppTheme _currentTheme = () {
  final keyStr = AppEnv.prefs.getString(_kThemeKey) ?? 'light';
  return appThemes.firstWhere((t) => t.key == keyStr, orElse: () => appThemes[0]).toAppTheme();
}();

AppTheme get gAppTheme => _currentTheme;

Future<void> switchAppTheme(AppTheme theme) async {
  if (_currentTheme != theme) {
    AppEnv.prefs.setString(_kThemeKey, theme.key).save();
    _currentTheme = theme;
    Reboot.trigger();
  }
}

// ---------------------------------------------------------------------------
// Convenience extension
// ---------------------------------------------------------------------------

extension AppThemeExtensions on ThemeData {
  Color get appBarBackgroundColor => appBarTheme.backgroundColor ?? colorScheme.primary;

  IconButtonThemeData get appBarIconButtonTheme => IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: appBarTheme.iconTheme!.color,
      disabledForegroundColor: appBarTheme.iconTheme!.color!.withAlpha(100),
    ),
  );

}
