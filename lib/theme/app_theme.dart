import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - Bank UI Palette (Purple-Blue Gradient)
  static const Color purple = Color(0xFF432148); // Dark purple for gradient start
  static const Color deepBlue = Color(0xFF213048); // Deep blue for gradient end
  static const Color coral = Color(0xFFEB5757); // Coral accent for CTAs
  static const Color whiteBg = Color(0xFFF0F2F4); // White background for bottom section

  // Legacy colors (kept for compatibility)
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color secondaryBlue = Color(0xFF4834DF);
  static const Color accentPink = Color(0xFFE84393);
  static const Color successGreen = Color(0xFF00B894);
  static const Color warningOrange = Color(0xFFFFB142);
  static const Color errorRed = Color(0xFFFF3838);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardBackground = Colors.white;
  static const Color surfaceColor = Color(0xFFF5F6FA);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textLight = Color(0xFFB2BEC3);

  // Bank UI Gradient (Purple to Blue)
  static const LinearGradient bankGradient = LinearGradient(
    colors: [purple, deepBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gradient rotation constant (from Bank UI reference)
  static const double gradientRotation = 0.785398; // 45 degrees in radians

  // Legacy Gradients (kept for compatibility)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, secondaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB142), Color(0xFFFF9F43)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFE84393), Color(0xFFFD79A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Mode Colors (Behance-inspired Deep Navy Blue)
  static const Color backgroundDark = Color(0xFF0D1B2A); // Deep navy background
  static const Color cardBackgroundDark = Color(0xFF1B263B); // Slightly lighter card bg
  static const Color surfaceColorDark = Color(0xFF415A77); // Surface elements
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // Pure white for headings
  static const Color textSecondaryDark = Color(0xFF8BA3C7); // Muted blue-gray
  static const Color glassmorphicOverlay = Color(0xFF1B263B); // For glass effects

  // OLED Black Mode Colors (Pure black for OLED displays)
  static const Color backgroundOled = Color(0xFF000000); // Pure black (#000000)
  static const Color cardBackgroundOled = Color(0xFF0A0A0A); // Near black for cards
  static const Color surfaceColorOled = Color(0xFF1A1A1A); // Slightly lighter for surfaces
  static const Color textPrimaryOled = Color(0xFFFFFFFF); // Pure white for maximum contrast
  static const Color textSecondaryOled = Color(0xFFB0B0B0); // Light gray for secondary text
  static const Color borderOled = Color(0xFF2A2A2A); // Subtle borders

  // Dark Mode Gradients
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassBlueGradient = LinearGradient(
    colors: [
      Color(0xFF415A77),
      Color(0xFF1B263B),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [
      Color(0xFF5B7FDB),
      Color(0xFF3A5A8C),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // OLED Mode Gradients (darker, more contrast)
  static const LinearGradient oledBackgroundGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF0A0A0A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient oledCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oledPurpleGradient = LinearGradient(
    colors: [Color(0xFF2D1B2E), Color(0xFF1A0F1B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(gradientRotation),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryPurple,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primaryPurple,
      secondary: secondaryBlue,
      surface: cardBackground,
      error: errorRed,
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: cardBackground,
      shadowColor: Colors.black.withAlpha((0.05 * 255).toInt()),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -1,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textLight,
      ),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: textSecondary,
      size: 24,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: textLight.withAlpha((0.2 * 255).toInt()),
      thickness: 1,
      space: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryPurple,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryPurple,
      secondary: secondaryBlue,
      surface: cardBackgroundDark,
      error: errorRed,
      background: backgroundDark,
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimaryDark,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
        letterSpacing: -0.5,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: cardBackgroundDark,
      shadowColor: Colors.black.withAlpha((0.3 * 255).toInt()),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
        letterSpacing: -1,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimaryDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimaryDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textSecondaryDark,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textSecondaryDark,
      ),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: textSecondaryDark,
      size: 24,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: textSecondaryDark.withAlpha((0.2 * 255).toInt()),
      thickness: 1,
      space: 1,
    ),
  );

  static ThemeData oledBlackTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryPurple,
    scaffoldBackgroundColor: backgroundOled,
    colorScheme: const ColorScheme.dark(
      primary: primaryPurple,
      secondary: secondaryBlue,
      surface: cardBackgroundOled,
      error: errorRed,
      background: backgroundOled,
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimaryOled,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimaryOled,
        letterSpacing: -0.5,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: cardBackgroundOled,
      shadowColor: Colors.transparent, // No shadows for OLED
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimaryOled,
        letterSpacing: -1,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimaryOled,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimaryOled,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryOled,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimaryOled,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimaryOled,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimaryOled,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textSecondaryOled,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textSecondaryOled,
      ),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(
      color: textSecondaryOled,
      size: 24,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: borderOled,
      thickness: 1,
      space: 1,
    ),
  );
}

// Custom Decorations
class AppDecorations {
  // Bank UI Glassmorphic Card (with BackdropFilter blur)
  static BoxDecoration bankGlassmorphicCard({double radius = 16}) => BoxDecoration(
    color: Colors.white.withAlpha((0.06 * 255).toInt()), // 15 alpha as per Bank UI
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withAlpha((0.12 * 255).toInt()), // 30 alpha border
      width: 1,
    ),
  );

  // Enhanced Glassmorphism Card (Behance-style) - Legacy
  static BoxDecoration glassmorphismCard({Color? color, bool isDark = false}) => BoxDecoration(
    color: (color ?? (isDark ? AppTheme.cardBackgroundDark : Colors.white)).withAlpha((isDark ? 0.15 * 255 : 0.7 * 255).toInt()),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: (isDark ? Colors.white : Colors.white).withAlpha((isDark ? 0.1 * 255 : 0.5 * 255).toInt()),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(((isDark ? 0.4 : 0.05) * 255).toInt()),
        blurRadius: isDark ? 30 : 20,
        offset: Offset(0, isDark ? 15 : 10),
      ),
      if (isDark)
        BoxShadow(
          color: AppTheme.primaryPurple.withAlpha((0.05 * 255).toInt()),
          blurRadius: 40,
          offset: const Offset(0, 5),
        ),
    ],
  );

  // Dark Gradient Glassmorphic Card (for Income/Spend cards)
  static BoxDecoration darkGlassmorphicCard() => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppTheme.cardBackgroundDark.withAlpha((0.3 * 255).toInt()),
        AppTheme.cardBackgroundDark.withAlpha((0.15 * 255).toInt()),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withAlpha((0.08 * 255).toInt()),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha((0.3 * 255).toInt()),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // Elevated Card (theme-aware)
  static BoxDecoration elevatedCard({
    Color? color,
    double radius = 20,
    bool isDark = false,
  }) => BoxDecoration(
    color: color ?? (isDark ? AppTheme.cardBackgroundDark : Colors.white),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(((isDark ? 0.3 : 0.08) * 255).toInt()),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withAlpha(((isDark ? 0.2 : 0.04) * 255).toInt()),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Gradient Container
  static BoxDecoration gradientContainer({
    required Gradient gradient,
    double radius = 20,
  }) => BoxDecoration(
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha((0.2 * 255).toInt()),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

// Spacing Constants
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
