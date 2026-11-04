import 'package:flutter/material.dart';

/// Shared empty-state widget shown on the right side when no record/tab is selected.
class EmptyDetailPlaceholder extends StatelessWidget {
  final String title;
  final String? subtitle;

  const EmptyDetailPlaceholder({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 72, color: theme.colorScheme.onSurface.withAlpha(80)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180))),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(120))),
            ],
          ],
        ),
      ),
    );
  }
}
