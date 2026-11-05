// Global l10n access through LanguageManager
import 'package:notee/utils/reboot.dart';

import '../l10n/app_localizations.dart';

import 'package:flutter/material.dart';

import 'app_env.dart';

enum LanguageOption {
  system('system', null), // Follow system
  chinese('zh', Locale('zh', 'CN')),
  english('en', Locale('en', 'US'));

  final String code;
  final Locale? forcedLocale; // null = follow system
  const LanguageOption(this.code, this.forcedLocale);

  static LanguageOption fromCode(String? code) => values.firstWhere((o) => o.code == code, orElse: () => system);
}

class LanguageManager {
  static LanguageOption _languageOption = LanguageOption.system;
  static Locale? _locale;

  // Global l10n instance
  static AppLocalizations? _l10n;

  // Initialize the global l10n instance
  static void initializeL10n(BuildContext context) {
    _l10n = AppLocalizations.of(context);
  }

  static void init() {
    final option = LanguageOption.fromCode(AppEnv.prefs.getString(PrefKeys.languageCode));
    _languageOption = option;
    _locale = option.forcedLocale;
  }

  static Future<void> setLanguage(LanguageOption option) async {
    _languageOption = option;
    _locale = option.forcedLocale;
    _l10n = null;
    AppEnv.prefs.setString(PrefKeys.languageCode, option.code).save();
    Reboot.trigger();
  }

  static String getLanguageDisplayName(LanguageOption option, String followSystem, String chinese, String english) {
    return switch (option) {
      LanguageOption.system => followSystem,
      LanguageOption.chinese => chinese,
      LanguageOption.english => english,
    };
  }

  static LanguageOption getCurrentLanguage() => _languageOption;
  static Locale? getCurrentLocale() => _locale;
}

// Global variable for easy access to localization
AppLocalizations get l10n {
  if (LanguageManager._l10n == null) {
    throw StateError('L10n not initialized. Make sure to call LanguageManager.initializeL10n first.');
  }
  return LanguageManager._l10n!;
}
