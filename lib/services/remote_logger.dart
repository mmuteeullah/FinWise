import 'package:http/http.dart' as http;
import 'dart:convert';

/// Remote logger that sends logs to a local server for debugging
/// Server URL should be your laptop's IP address (find with: ipconfig getifaddr en0)
class RemoteLogger {
  // Toggle this to enable/disable remote logging
  static const bool _enabled = true;

  // IMPORTANT: Change this to your laptop's IP address!
  // Find it with: ipconfig getifaddr en0 (macOS) or ipconfig (Windows)
  static const String _serverUrl = 'http://192.168.0.212:8888/log';

  // Timeout for log requests (don't block app if server is down)
  static const Duration _timeout = Duration(milliseconds: 500);

  /// Log debug message
  static void debug(String message, {String? tag}) {
    _log('DEBUG', message, tag: tag);
  }

  /// Log info message
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// Log warning message
  static void warn(String message, {String? tag}) {
    _log('WARN', message, tag: tag);
  }

  /// Log error message with optional error object
  static void error(String message, {dynamic error, String? tag, StackTrace? stackTrace}) {
    final fullMessage = error != null
        ? '$message: $error'
        : message;

    final stackInfo = stackTrace != null
        ? '\n\nStack trace:\n$stackTrace'
        : '';

    _log('ERROR', fullMessage + stackInfo, tag: tag);
  }

  /// Internal method to send log to server
  static void _log(String level, String message, {String? tag}) async {
    // Always print to console as backup
    final tagPrefix = tag != null ? '[$tag] ' : '';
    print('[$level] $tagPrefix$message');

    if (!_enabled) return;

    try {
      await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'message': message,
          'tag': tag,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(_timeout);
    } catch (e) {
      // Silently fail - don't spam console with connection errors
      // The print() above ensures we still see logs in console
    }
  }

  /// Log a section divider for better readability
  static void divider(String title) {
    _log('INFO', '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('INFO', '  $title');
    _log('INFO', '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
