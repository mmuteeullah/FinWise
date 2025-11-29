import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'theme_provider.dart';

/// Helper class for theme-aware UI components
class ThemeHelper {
  /// Check if OLED mode
  static bool isOled(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return themeProvider.isOledBlack;
  }

  /// Get card background color based on theme
  static Color cardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return Colors.white;

    return isOled(context) ? AppTheme.cardBackgroundOled : AppTheme.cardBackgroundDark;
  }

  /// Get scaffold background color based on theme
  static Color scaffoldColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Get surface color based on theme
  static Color surfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return AppTheme.surfaceColor;

    return isOled(context) ? AppTheme.surfaceColorOled : AppTheme.surfaceColorDark;
  }

  /// Get primary text color based on theme
  static Color textPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return AppTheme.textPrimary;

    return isOled(context) ? AppTheme.textPrimaryOled : AppTheme.textPrimaryDark;
  }

  /// Get secondary text color based on theme
  static Color textSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return AppTheme.textSecondary;

    return isOled(context) ? AppTheme.textSecondaryOled : AppTheme.textSecondaryDark;
  }

  /// Get card shadow for theme
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    // OLED: no shadows for battery optimization
    if (isOled(context)) {
      return [];
    }

    // Dark mode: subtle shadows
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Get box decoration for cards
  static BoxDecoration cardDecoration(BuildContext context, {double radius = 16}) {
    return BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: cardShadow(context),
    );
  }

  /// Get input decoration border color
  static Color inputBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return Colors.grey[300]!;

    return isOled(context) ? AppTheme.borderOled : AppTheme.surfaceColorDark;
  }

  /// Check if dark mode (includes both dark and OLED)
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get background gradient based on theme
  static LinearGradient backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.purple, AppTheme.deepBlue],
        transform: GradientRotation(AppTheme.gradientRotation),
      );
    }

    return isOled(context)
        ? AppTheme.oledPurpleGradient
        : AppTheme.darkBackgroundGradient;
  }

  /// Get divider color based on theme
  static Color dividerColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return Colors.grey[300]!;

    return isOled(context)
        ? AppTheme.borderOled
        : AppTheme.textSecondaryDark.withOpacity(0.2);
  }

  /// Get OLED-safe card decoration with subtle borders
  static BoxDecoration oledCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: AppTheme.cardBackgroundOled,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppTheme.borderOled,
        width: 1,
      ),
    );
  }
}
