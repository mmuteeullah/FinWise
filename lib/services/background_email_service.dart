import 'dart:async';
import 'package:background_fetch/background_fetch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_service.dart';
import 'database_helper.dart';
import '../models/email_account.dart';

/// Background email sync service for iOS
/// Uses BackgroundFetch to periodically sync emails when app is in background
class BackgroundEmailService {
  static const String _taskId = 'com.finwise.email_sync';
  static const String _lastBackgroundSyncKey = 'last_background_sync';

  /// Configure and initialize background fetch
  static Future<void> initialize() async {
    print('🔄 Initializing background email service...');

    try {
      // Configure BackgroundFetch
      final status = await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15, // 15 minutes (iOS minimum)
          stopOnTerminate: false, // Continue after app termination
          startOnBoot: false, // Don't start on device boot
          enableHeadless: true, // Enable headless execution
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.ANY,
        ),
        _onBackgroundFetch,
        _onBackgroundFetchTimeout,
      );

      print('✅ Background fetch configured with status: $status');

      // Schedule the task
      await BackgroundFetch.scheduleTask(
        TaskConfig(
          taskId: _taskId,
          delay: 0, // Start immediately
          periodic: true, // Repeat periodically
          stopOnTerminate: false,
          enableHeadless: true,
        ),
      );

      print('✅ Background email sync task scheduled');
    } catch (e, stackTrace) {
      print('❌ Failed to initialize background fetch: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  /// Background fetch event handler
  static Future<void> _onBackgroundFetch(String taskId) async {
    print('📧 [Background] Email sync task started: $taskId');

    try {
      // Check if auto-sync is enabled
      final emailService = EmailService();
      final autoSyncEnabled = await emailService.isAutoSyncEnabled();

      if (!autoSyncEnabled) {
        print('⏸️ [Background] Auto-sync is disabled, skipping');
        BackgroundFetch.finish(taskId);
        return;
      }

      // Get active email accounts
      final db = DatabaseHelper.instance;
      final database = await db.database;
      final accounts = await database.query(
        'email_accounts',
        where: 'is_active = ?',
        whereArgs: [1],
      );

      if (accounts.isEmpty) {
        print('⏸️ [Background] No active email accounts, skipping');
        BackgroundFetch.finish(taskId);
        return;
      }

      print('📧 [Background] Found ${accounts.length} active account(s)');

      // Sync each account (with timeout to avoid exceeding 30 seconds)
      for (final accountData in accounts) {
        try {
          final account = EmailAccount.fromMap(accountData);
          print('📧 [Background] Syncing account: ${account.email}');

          // Sync emails (limited batch to complete within time limit)
          final count = await emailService.syncEmails(
            account,
            maxResults: 10, // Small batch for background
            maxTotalEmails: 50, // Max 50 emails in background
          );

          print('✅ [Background] Synced $count emails for ${account.email}');
        } catch (e) {
          print('❌ [Background] Failed to sync account: $e');
        }
      }

      // Update last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastBackgroundSyncKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      print('✅ [Background] Email sync task completed');
      BackgroundFetch.finish(taskId);
    } catch (e, stackTrace) {
      print('❌ [Background] Email sync failed: $e');
      print('❌ Stack trace: $stackTrace');
      BackgroundFetch.finish(taskId);
    }
  }

  /// Background fetch timeout handler
  static Future<void> _onBackgroundFetchTimeout(String taskId) async {
    print('⏱️ [Background] Email sync task timeout: $taskId');
    BackgroundFetch.finish(taskId);
  }

  /// Start background email sync
  static Future<void> start() async {
    print('▶️ Starting background email sync...');
    await BackgroundFetch.start();
    print('✅ Background email sync started');
  }

  /// Stop background email sync
  static Future<void> stop() async {
    print('⏸️ Stopping background email sync...');
    await BackgroundFetch.stop();
    print('✅ Background email sync stopped');
  }

  /// Get status of background fetch
  static Future<int> getStatus() async {
    return await BackgroundFetch.status;
  }

  /// Get last background sync timestamp
  static Future<DateTime?> getLastBackgroundSync() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastBackgroundSyncKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}

/// Headless task entry point (called when app is terminated)
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  print('📧 [Headless] Background fetch task started: ${task.taskId}');

  try {
    await BackgroundEmailService._onBackgroundFetch(task.taskId);
  } catch (e) {
    print('❌ [Headless] Background fetch failed: $e');
    BackgroundFetch.finish(task.taskId);
  }
}
