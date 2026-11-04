// Global l10n access through LanguageManager
import 'package:notee/utils/reboot.dart';

import '../l10n/app_localizations.dart';

import 'package:flutter/material.dart';

import 'app_env.dart';
enum LanguageOption {
  system, // Follow system
  chinese, // Chinese
  english, // English
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
    // Read language setting from preferences
    final languageCode = AppEnv.prefs.getString(PrefKeys.languageCode);
    if (languageCode != null) {
      switch (languageCode) {
        case 'system':
          _languageOption = LanguageOption.system;
          _locale = null; // null means follow system
          break;
        case 'zh':
          _languageOption = LanguageOption.chinese;
          _locale = const Locale('zh', 'CN');
          break;
        case 'en':
          _languageOption = LanguageOption.english;
          _locale = const Locale('en', 'US');
          break;
        default:
          _languageOption = LanguageOption.system;
          _locale = null;
      }
    } else {
      // Default: follow system
      _languageOption = LanguageOption.system;
      _locale = null;
    }
  }

  static Future<void> setLanguage(LanguageOption option) async {
    _languageOption = option;

    String languageCode;
    Locale? locale;

    switch (option) {
      case LanguageOption.system:
        languageCode = 'system';
        locale = null;
        break;
      case LanguageOption.chinese:
        languageCode = 'zh';
        locale = const Locale('zh', 'CN');
        break;
      case LanguageOption.english:
        languageCode = 'en';
        locale = const Locale('en', 'US');
        break;
    }

    _locale = locale;
    _l10n = null;
    // Save to preferences
    AppEnv.prefs.setString(PrefKeys.languageCode, languageCode).save();

    Reboot.trigger();
  }

  static String getLanguageDisplayName(LanguageOption option, String followSystem, String chinese, String english) {
    switch (option) {
      case LanguageOption.system:
        return followSystem;
      case LanguageOption.chinese:
        return chinese;
      case LanguageOption.english:
        return english;
    }
  }

  static LanguageOption getCurrentLanguage() {
    return _languageOption;
  }

  static Locale? getCurrentLocale() {
    return _locale;
  }
}

// Global variable for easy access to localization
AppLocalizations get l10n {
  if (LanguageManager._l10n == null) {
    throw StateError('L10n not initialized. Make sure to call LanguageManager.initializel10n first.');
  }
  return LanguageManager._l10n!;
}
