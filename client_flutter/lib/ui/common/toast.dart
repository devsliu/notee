import 'package:flutter/material.dart';

/// A lightweight, non-interactive toast shown at the top of the screen,
/// horizontally centered with a small top margin. It never captures pointer
/// events (tap-through) and auto-dismisses after [duration].
class Toast {
  static const Duration _defaultDuration = Duration(seconds: 2);

  /// Show a toast at the top-center of the screen.
  /// [context] is used to find the nearest [Overlay].
  static void show(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => _ToastView(message: message),
    );

    overlay.insert(entry);
    Future.delayed(duration, () {
      if (entry.mounted) entry.remove();
    });
  }
}

class _ToastView extends StatelessWidget {
  final String message;
  const _ToastView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
