import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/config/language_manager.dart';

class ThemeSelectorDialog extends StatefulWidget {
  const ThemeSelectorDialog({super.key});

  @override
  State<ThemeSelectorDialog> createState() => _ThemeSelectorDialogState();
}

class _ThemeSelectorDialogState extends State<ThemeSelectorDialog> {
  AppTheme? _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = gAppTheme;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Define spacing variables
    const double crossAxisSpacing = 8.0; // Column spacing
    const double mainAxisSpacing = 8.0; // Row spacing
    const double childAspectRatio = 1.2; // Grid item aspect ratio (taller to fit rich preview)

    // Calculate dialog dimensions, set min and max limits
    final dialogWidth = min(screenWidth * 0.85, screenHeight * 0.85);

    // Adjust themes per row based on screen width
    final crossAxisCount = dialogWidth > 600 ? 4 : (dialogWidth > 450 ? 3 : 2);

    // Calculate number of rows needed based on theme count and columns
    final rowCount = (appThemes.length / crossAxisCount).ceil();

    // Calculate ideal grid height
    final gridItemWidth = (dialogWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    final gridItemHeight = gridItemWidth / childAspectRatio;
    final idealGridHeight = rowCount * gridItemHeight + (rowCount - 1) * mainAxisSpacing;

    // Limit max height, prevent dialog from being too tall
    final dialogHeight = min(idealGridHeight, screenHeight * 0.9);

    return AlertDialog(
      insetPadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.fromLTRB(16, 8, 0, 0), // Reduce top title padding
      title: Row(
        children: [
          Expanded(child: Text(l10n.selectTheme)),
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: l10n.close,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, // Adjust columns based on screen width
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio, // Adjust grid aspect ratio
          ),
          itemCount: appThemes.length,
          itemBuilder: (context, index) {
            final theme = appThemes[index];
            final isSelected = _selectedTheme?.key == theme.key;

            return _buildThemePreview(theme.toAppTheme(), isSelected);
          },
        ),
      ),
    );
  }

  Widget _buildThemePreview(AppTheme theme, bool isSelected) {
    final themeData = theme.data;
    final cs = themeData.colorScheme;
    final appBar = themeData.appBarTheme;
    const circular = 2.0;

    // Collect all relevant colors with safe fallbacks
    final appBarBg = appBar.backgroundColor ?? cs.primary;
    final appBarFg = appBar.foregroundColor ?? cs.onPrimary;
    final appBarIcon = appBar.iconTheme?.color ?? appBarFg;
    final appBarActionsIcon = appBar.actionsIconTheme?.color ?? appBarFg;
    final iconColor = themeData.iconTheme.color ?? cs.onSurface;
    final listIconColor = themeData.listTileTheme.iconColor ?? iconColor;
    final listTextColor = themeData.listTileTheme.textColor ?? cs.onSurface;
    final bodyColor = themeData.textTheme.bodyLarge?.color ?? cs.onSurface;
    final bodyMediumColor = themeData.textTheme.bodyMedium?.color ?? cs.onSurfaceVariant;
    final iconButtonFg = themeData.iconButtonTheme.style?.foregroundColor?.resolve(const {}) ?? iconColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = theme;
        });
        // Switch theme directly
        switchAppTheme(theme);
        Navigator.of(context).pop(); // Close dialog after selection
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? cs.primary : Colors.grey.shade300, width: isSelected ? 3 : 1),
          borderRadius: BorderRadius.circular(circular),
        ),
        child: Column(
          children: [
            // --- AppBar preview ---
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: appBarBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(circular),
                  topRight: Radius.circular(circular),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.menu, size: 14, color: appBarIcon),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        theme.getName(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: appBarFg, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.search, size: 14, color: appBarActionsIcon),
                    const SizedBox(width: 4),
                    Icon(Icons.more_vert, size: 14, color: appBarActionsIcon),
                  ],
                ),
              ),
            ),
            // --- Content area preview ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(circular),
                    bottomRight: Radius.circular(circular),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Button row: primary + secondary
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text('Primary', style: TextStyle(color: cs.onPrimary, fontSize: 9)),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.secondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text('Secondary', style: TextStyle(color: cs.onSecondary, fontSize: 9)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Icon row: global icon, list icon, error, icon-button
                      Row(
                        children: [
                          Icon(Icons.folder, size: 14, color: iconColor),
                          const SizedBox(width: 6),
                          Icon(Icons.star, size: 14, color: listIconColor),
                          const SizedBox(width: 6),
                          Icon(Icons.warning, size: 14, color: cs.error),
                          const SizedBox(width: 6),
                          Icon(Icons.settings, size: 14, color: iconButtonFg),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Body text
                      Text('Body text sample', style: TextStyle(color: bodyColor, fontSize: 10)),
                      const SizedBox(height: 1),
                      // Secondary text
                      Text('Secondary text line', style: TextStyle(color: bodyMediumColor, fontSize: 9)),
                      const SizedBox(height: 1),
                      // List tile line (icon + text)
                      Row(
                        children: [
                          Icon(Icons.note, size: 11, color: listIconColor),
                          const SizedBox(width: 4),
                          Text('List item', style: TextStyle(color: listTextColor, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // --- Bottom border accent (outline color) ---
            Container(height: 2, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

// Convenience method to show theme selector dialog
Future<void> showThemeSelector(BuildContext context) async {
  await showDialog(context: context, useRootNavigator: false, builder: (context) => const ThemeSelectorDialog());
}
