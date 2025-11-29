import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for securely storing sensitive data using iOS Keychain
///
/// This service provides a secure way to store API keys and other sensitive
/// information using platform-specific secure storage (iOS Keychain).
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  // Initialize secure storage with iOS-specific options
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Key constants for stored values
  static const String _keyOpenRouterApiKey = 'openrouter_api_key';
  static const String _keyNvidiaApiKey = 'nvidia_api_key';
  static const String _keyMigrationCompleted = 'migration_completed';

  /// Migrates API keys from SharedPreferences to secure storage
  ///
  /// This should be called once when the app starts to migrate existing
  /// API keys from plain text storage to secure storage.
  Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if migration has already been completed
    final migrationCompleted = await _storage.read(key: _keyMigrationCompleted);
    if (migrationCompleted == 'true') {
      print('✓ API key migration already completed');
      return;
    }

    print('⚠️ Starting API key migration to secure storage...');
    int migratedCount = 0;

    // Migrate OpenRouter API key
    final openRouterKey = prefs.getString('openrouter_api_key');
    if (openRouterKey != null && openRouterKey.isNotEmpty) {
      await _storage.write(key: _keyOpenRouterApiKey, value: openRouterKey);
      await prefs.remove('openrouter_api_key');
      migratedCount++;
      print('✓ Migrated OpenRouter API key');
    }

    // Migrate NVIDIA API key
    final nvidiaKey = prefs.getString('nvidia_api_key');
    if (nvidiaKey != null && nvidiaKey.isNotEmpty) {
      await _storage.write(key: _keyNvidiaApiKey, value: nvidiaKey);
      await prefs.remove('nvidia_api_key');
      migratedCount++;
      print('✓ Migrated NVIDIA API key');
    }

    // Mark migration as completed
    await _storage.write(key: _keyMigrationCompleted, value: 'true');
    print('✓ API key migration completed ($migratedCount keys migrated)');
  }

  /// Saves the OpenRouter API key securely
  Future<void> saveOpenRouterApiKey(String apiKey) async {
    await _storage.write(key: _keyOpenRouterApiKey, value: apiKey);
    print('✓ OpenRouter API key saved securely');
  }

  /// Retrieves the OpenRouter API key
  Future<String?> getOpenRouterApiKey() async {
    return await _storage.read(key: _keyOpenRouterApiKey);
  }

  /// Saves the NVIDIA API key securely
  Future<void> saveNvidiaApiKey(String apiKey) async {
    await _storage.write(key: _keyNvidiaApiKey, value: apiKey);
    print('✓ NVIDIA API key saved securely');
  }

  /// Retrieves the NVIDIA API key
  Future<String?> getNvidiaApiKey() async {
    return await _storage.read(key: _keyNvidiaApiKey);
  }

  /// Deletes the OpenRouter API key
  Future<void> deleteOpenRouterApiKey() async {
    await _storage.delete(key: _keyOpenRouterApiKey);
    print('✓ OpenRouter API key deleted');
  }

  /// Deletes the NVIDIA API key
  Future<void> deleteNvidiaApiKey() async {
    await _storage.delete(key: _keyNvidiaApiKey);
    print('✓ NVIDIA API key deleted');
  }

  /// Deletes all stored data (use with caution)
  Future<void> deleteAll() async {
    await _storage.deleteAll();
    print('✓ All secure storage data deleted');
  }

  /// Checks if OpenRouter API key exists
  Future<bool> hasOpenRouterApiKey() async {
    final key = await getOpenRouterApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Checks if NVIDIA API key exists
  Future<bool> hasNvidiaApiKey() async {
    final key = await getNvidiaApiKey();
    return key != null && key.isNotEmpty;
  }
}
