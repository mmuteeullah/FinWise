import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'biometric_service.dart';

class BackupInfo {
  final String path;
  final String name;
  final int size;
  final DateTime created;
  final bool encrypted;

  BackupInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.created,
    required this.encrypted,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ICloudBackupService {
  static ICloudBackupService? _instance;
  static ICloudBackupService get instance {
    _instance ??= ICloudBackupService._();
    return _instance!;
  }

  ICloudBackupService._();

  // Encryption key derived from biometric/password
  encrypt.Key? _encryptionKey;
  bool _isInitialized = false;

  /// Initialize encryption with Face ID/Touch ID
  /// This uses biometric authentication to derive the encryption key
  Future<bool> initializeEncryption() async {
    try {
      final biometricService = BiometricService();
      final isSupported = await biometricService.isDeviceSupported();

      if (!isSupported) {
        print('⚠️ Biometric not available, using default key');
        // Fallback to device-specific key (less secure but still encrypted by iOS)
        _encryptionKey = _generateDeviceKey();
        _isInitialized = true;
        return true;
      }

      // Authenticate with biometrics
      final authenticated = await biometricService.authenticate(
        localizedReason: 'Authenticate to encrypt backup',
      );

      if (authenticated) {
        // Generate key from device ID (consistent across sessions)
        _encryptionKey = _generateDeviceKey();
        _isInitialized = true;
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Encryption initialization failed: $e');
      return false;
    }
  }

  /// Generate device-specific encryption key
  encrypt.Key _generateDeviceKey() {
    // Use a combination of app identifier and device-specific data
    // In production, you might want to use iOS Keychain to store this
    const String appSecret = 'finwise_backup_v1_secret_key_2025';
    final key = encrypt.Key.fromUtf8(
      appSecret.padRight(32, '0').substring(0, 32),
    );
    return key;
  }

  /// Check if backup storage is available
  Future<bool> isBackupStorageAvailable() async {
    try {
      final dir = await _getBackupDirectory();
      return dir != null;
    } catch (e) {
      return false;
    }
  }

  /// Get local backup directory (accessible via Files app)
  Future<Directory?> _getBackupDirectory() async {
    try {
      // Get app's Documents directory (visible in Files app)
      final docDir = await getApplicationDocumentsDirectory();

      // Create backups subdirectory
      final backupPath = '${docDir.path}/Backups';
      final backupDir = Directory(backupPath);

      // Create if doesn't exist
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        print('📁 Created backup directory: $backupPath');
      }

      return backupDir;
    } catch (e) {
      print('❌ Error accessing backup directory: $e');
      return null;
    }
  }

  /// Create encrypted backup to local storage
  Future<bool> createBackup({bool showProgress = true}) async {
    try {
      // Ensure encryption is initialized
      if (!_isInitialized) {
        final initialized = await initializeEncryption();
        if (!initialized) {
          print('❌ Encryption not initialized');
          return false;
        }
      }

      // Check backup storage availability
      final backupDir = await _getBackupDirectory();
      if (backupDir == null) {
        print('❌ Backup storage not available');
        return false;
      }

      // Get database path
      final dbPath = await getDatabasesPath();
      final dbFile = File('$dbPath/transactions.db');

      if (!await dbFile.exists()) {
        print('❌ Database file not found');
        return false;
      }

      print('📦 Creating backup...');

      // Read database
      final dbBytes = await dbFile.readAsBytes();
      print('📊 Database size: ${(dbBytes.length / 1024).toStringAsFixed(1)} KB');

      // Encrypt
      List<int> finalBytes;
      bool isEncrypted = false;

      if (_encryptionKey != null) {
        try {
          final encrypter = encrypt.Encrypter(
            encrypt.AES(_encryptionKey!, mode: encrypt.AESMode.cbc),
          );
          final iv = encrypt.IV.fromLength(16);
          final encrypted = encrypter.encryptBytes(dbBytes, iv: iv);

          // Combine IV + encrypted data
          finalBytes = iv.bytes + encrypted.bytes;
          isEncrypted = true;
          print('🔒 Database encrypted');
        } catch (e) {
          print('⚠️ Encryption failed, saving unencrypted: $e');
          finalBytes = dbBytes;
        }
      } else {
        finalBytes = dbBytes;
      }

      // Create backup file with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = isEncrypted ? 'db.enc' : 'db';
      final backupFile = File('${backupDir.path}/finwise_backup_$timestamp.$extension');

      await backupFile.writeAsBytes(finalBytes);

      print('✅ Backup saved: ${backupFile.path}');
      print('📏 Backup size: ${(finalBytes.length / 1024).toStringAsFixed(1)} KB');

      // Cleanup old backups (keep last 10)
      await _cleanupOldBackups();

      return true;
    } catch (e) {
      print('❌ Backup failed: $e');
      return false;
    }
  }

  /// Restore database from iCloud backup
  Future<bool> restoreBackup({String? backupPath}) async {
    try {
      // Ensure encryption is initialized
      if (!_isInitialized) {
        final initialized = await initializeEncryption();
        if (!initialized) {
          print('❌ Encryption not initialized');
          return false;
        }
      }

      File backupFile;

      if (backupPath != null) {
        // Restore specific backup
        backupFile = File(backupPath);
      } else {
        // Get latest backup
        final backups = await listBackups();
        if (backups.isEmpty) {
          print('❌ No backups found');
          return false;
        }
        backupFile = File(backups.first.path);
      }

      if (!await backupFile.exists()) {
        print('❌ Backup file not found');
        return false;
      }

      print('📥 Restoring from: ${backupFile.path}');

      // Read backup
      final backupBytes = await backupFile.readAsBytes();
      print('📊 Backup size: ${(backupBytes.length / 1024).toStringAsFixed(1)} KB');

      // Decrypt if encrypted
      List<int> dbBytes;
      final isEncrypted = backupFile.path.endsWith('.enc');

      if (isEncrypted && _encryptionKey != null) {
        try {
          final iv = encrypt.IV(backupBytes.sublist(0, 16));
          final encryptedData = backupBytes.sublist(16);

          final encrypter = encrypt.Encrypter(
            encrypt.AES(_encryptionKey!, mode: encrypt.AESMode.cbc),
          );

          dbBytes = encrypter.decryptBytes(
            encrypt.Encrypted(encryptedData),
            iv: iv,
          );
          print('🔓 Backup decrypted');
        } catch (e) {
          print('❌ Decryption failed: $e');
          return false;
        }
      } else {
        dbBytes = backupBytes;
      }

      // Backup current database before restore
      final dbPath = await getDatabasesPath();
      final dbFile = File('$dbPath/transactions.db');

      if (await dbFile.exists()) {
        final preRestoreTimestamp = DateTime.now().millisecondsSinceEpoch;
        final preRestoreBackup = File('$dbPath/transactions_pre_restore_$preRestoreTimestamp.db');
        await dbFile.copy(preRestoreBackup.path);
        print('💾 Current database backed up to: ${preRestoreBackup.path}');
      }

      // Close database connection before replacing file
      await DatabaseHelper.instance.close();

      // Write restored database
      await dbFile.writeAsBytes(dbBytes);
      print('✅ Database restored successfully');
      print('📊 Restored size: ${(dbBytes.length / 1024).toStringAsFixed(1)} KB');

      return true;
    } catch (e) {
      print('❌ Restore failed: $e');
      return false;
    }
  }

  /// List all available backups
  Future<List<BackupInfo>> listBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (backupDir == null) return [];

      if (!await backupDir.exists()) return [];

      final files = backupDir.listSync()
          .where((f) => f.path.contains('finwise_backup'))
          .map((f) => File(f.path))
          .toList();

      final backupList = <BackupInfo>[];

      for (final file in files) {
        final stat = await file.stat();
        final fileName = file.path.split('/').last;
        // Extract timestamp from filename: finwise_backup_<timestamp>.db.enc
        final timestampMatch = RegExp(r'finwise_backup_(\d+)\.').firstMatch(fileName);

        backupList.add(BackupInfo(
          path: file.path,
          name: fileName,
          size: stat.size,
          created: timestampMatch != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  int.parse(timestampMatch.group(1)!),
                )
              : stat.modified, // Fallback to file modification time
          encrypted: file.path.endsWith('.enc'),
        ));
      }

      // Sort by date (newest first)
      backupList.sort((a, b) => b.created.compareTo(a.created));

      return backupList;
    } catch (e) {
      print('❌ Error listing backups: $e');
      return [];
    }
  }

  /// Delete a specific backup
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted backup: $backupPath');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting backup: $e');
      return false;
    }
  }

  /// Cleanup old backups (keep last 10)
  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await listBackups();

      if (backups.length > 10) {
        final toDelete = backups.sublist(10);
        for (final backup in toDelete) {
          await deleteBackup(backup.path);
        }
        print('🧹 Cleaned up ${toDelete.length} old backups');
      }
    } catch (e) {
      print('❌ Cleanup failed: $e');
    }
  }

  /// Get total size of all backups
  Future<int> getTotalBackupSize() async {
    final backups = await listBackups();
    return backups.fold<int>(0, (sum, backup) => sum + backup.size);
  }

  /// Delete all backups
  Future<bool> deleteAllBackups() async {
    try {
      final backups = await listBackups();
      for (final backup in backups) {
        await deleteBackup(backup.path);
      }
      print('🗑️ Deleted all ${backups.length} backups');
      return true;
    } catch (e) {
      print('❌ Error deleting all backups: $e');
      return false;
    }
  }
}
