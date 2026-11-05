// Global reboot notifier for app-wide rebuilds
import 'package:flutter/material.dart';

class Reboot {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// Triggers a global rebuild by incrementing the notifier value.
  static void trigger() {
    notifier.value++;
  }
}
