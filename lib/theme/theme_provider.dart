import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  oledBlack,
}

class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark; // Default to dark mode
  AppThemeMode get themeMode => _themeMode;

  // Backward compatibility
  bool get isDarkMode => _themeMode != AppThemeMode.light;
  bool get isOledBlack => _themeMode == AppThemeMode.oledBlack;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('themeMode') ?? 'dark';

    switch (savedMode) {
      case 'light':
        _themeMode = AppThemeMode.light;
        break;
      case 'dark':
        _themeMode = AppThemeMode.dark;
        break;
      case 'oledBlack':
        _themeMode = AppThemeMode.oledBlack;
        break;
      default:
        _themeMode = AppThemeMode.dark;
    }

    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString().split('.').last);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    // Cycle through: light -> dark -> oledBlack -> light
    switch (_themeMode) {
      case AppThemeMode.light:
        await setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        await setThemeMode(AppThemeMode.oledBlack);
        break;
      case AppThemeMode.oledBlack:
        await setThemeMode(AppThemeMode.light);
        break;
    }
  }

  // Backward compatibility
  Future<void> setDarkMode(bool value) async {
    await setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
  }
}
