import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email_account.dart';
import '../models/email_message.dart';
import 'database_helper.dart';
import 'dart:convert';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  // Gmail OAuth configuration
  static const String _clientId = '622822118718-s39oturl0bre6ta56e24m0cciabsmhk2.apps.googleusercontent.com';
  static const List<String> _scopes = [
    gmail.GmailApi.gmailReadonlyScope,
  ];

  GoogleSignIn? _googleSignIn;

  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: _scopes,
      clientId: _clientId,
    );
    return _googleSignIn!;
  }

  /// Sign in with Google and connect Gmail account
  Future<EmailAccount?> connectGmailAccount() async {
    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled sign in
        return null;
      }

      // Check if account already exists
      final db = await _db.database;
      final existing = await db.query(
        'email_accounts',
        where: 'email = ? AND provider = ?',
        whereArgs: [googleUser.email, 'gmail'],
        limit: 1,
      );

      EmailAccount account;

      if (existing.isNotEmpty) {
        // Update existing account
        account = EmailAccount.fromMap(existing.first).copyWith(
          displayName: googleUser.displayName ?? googleUser.email,
          photoUrl: googleUser.photoUrl,
          isActive: true,
        );

        await db.update(
          'email_accounts',
          account.toMap(),
          where: 'id = ?',
          whereArgs: [account.id],
        );
      } else {
        // Create new account
        account = EmailAccount(
          id: _uuid.v4(),
          provider: 'gmail',
          email: googleUser.email,
          displayName: googleUser.displayName ?? googleUser.email,
          photoUrl: googleUser.photoUrl,
          connectedAt: DateTime.now(),
          isActive: true,
        );

        await db.insert('email_accounts', account.toMap());
      }

      return account;
    } catch (e) {
      print('Error connecting Gmail account: $e');
      return null;
    }
  }

  /// Disconnect Gmail account
  Future<void> disconnectAccount(String accountId) async {
    try {
      final db = await _db.database;

      // Mark account as inactive
      await db.update(
        'email_accounts',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [accountId],
      );

      // Sign out from Google
      await googleSignIn.signOut();
    } catch (e) {
      print('Error disconnecting account: $e');
    }
  }

  /// Get all connected email accounts
  Future<List<EmailAccount>> getConnectedAccounts() async {
    final db = await _db.database;
    final result = await db.query(
      'email_accounts',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'connected_at DESC',
    );

    return result.map((map) => EmailAccount.fromMap(map)).toList();
  }

  /// Fetch emails from Gmail for a specific account
  /// [onProgress] callback receives (current, total, status) updates
  /// [maxResults] max emails per API call (default 10 for rate limiting)
  /// [maxTotalEmails] max total emails to fetch (null = fetch all)
  Future<int> syncEmails(
    EmailAccount account, {
    int maxResults = 10,
    int? maxTotalEmails,
    Function(int current, int? total, String status)? onProgress,
  }) async {
    try {
      print('📧 Starting email sync for ${account.email}...');

      // Get current Google Sign In user
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();

      if (googleUser == null) {
        print('❌ Not signed in silently, trying interactive sign in...');
        googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          print('❌ User cancelled sign in');
          throw Exception('User cancelled sign in');
        }
      }

      print('✅ User signed in: ${googleUser.email}');

      // Get authentication
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('✅ Got authentication token');

      // Create authenticated client
      final authClient = _GoogleAuthClient(googleAuth.accessToken!);
      final gmailApi = gmail.GmailApi(authClient);
      print('✅ Created Gmail API client');

      // Search for transactional emails with keywords
      String query = _buildSearchQuery();

      // Add date filter to only fetch emails since last sync
      if (account.lastSyncedAt != null) {
        // Format date as YYYY/MM/DD for Gmail search
        final lastSync = account.lastSyncedAt!;
        final dateStr = '${lastSync.year}/${lastSync.month.toString().padLeft(2, '0')}/${lastSync.day.toString().padLeft(2, '0')}';
        query = '$query after:$dateStr';
        print('📅 Only fetching emails after: $dateStr');
      } else {
        print('📅 First sync - fetching all emails');
      }

      print('📝 Search query: $query');

      onProgress?.call(0, null, 'Searching for emails...');

      // Paginated email fetching
      int newEmailsCount = 0;
      int totalProcessed = 0;
      String? pageToken;
      final db = await _db.database;

      do {
        print('🔍 Fetching page ${pageToken == null ? "1" : "..."}');

        // Fetch one page of message IDs
        final gmail.ListMessagesResponse listResponse;
        try {
          listResponse = await gmailApi.users.messages.list(
            'me',
            q: query,
            maxResults: maxResults,
            pageToken: pageToken,
          );

          print('📬 Page has ${listResponse.messages?.length ?? 0} messages');
          if (pageToken == null) {
            // Only log estimate on first page
            print('📊 Estimated total: ${listResponse.resultSizeEstimate}');
          }

          if (listResponse.messages == null || listResponse.messages!.isEmpty) {
            print('✅ No more messages on this page');
            break;
          }

          // Process messages in this batch
          for (final message in listResponse.messages!) {
            if (message.id == null) continue;

            // Check if email already exists
            final existing = await db.query(
              'email_messages',
              where: 'id = ?',
              whereArgs: [message.id!],
              limit: 1,
            );

            if (existing.isNotEmpty) {
              totalProcessed++;
              continue;
            }

            // Fetch full message
            final fullMessage = await gmailApi.users.messages.get(
              'me',
              message.id!,
              format: 'full',
            );

            // Parse email data
            final emailMessage = _parseGmailMessage(fullMessage, account.id);

            if (emailMessage != null) {
              await db.insert('email_messages', emailMessage.toMap());
              newEmailsCount++;
            }

            totalProcessed++;

            // Update progress after each email (no total since estimate is unreliable)
            onProgress?.call(
              totalProcessed,
              null, // Don't show total - Gmail estimate is unreliable
              'Fetching emails ($totalProcessed fetched)...',
            );
          }

          pageToken = listResponse.nextPageToken;

          // Rate limiting: wait 2 seconds between batches
          if (pageToken != null) {
            print('⏱️ Rate limiting: waiting 2 seconds before next batch...');
            onProgress?.call(totalProcessed, null, 'Rate limiting (2s)...');
            await Future.delayed(const Duration(seconds: 2));
          }

          // Stop if we've reached maxTotalEmails
          if (maxTotalEmails != null && totalProcessed >= maxTotalEmails) {
            print('🛑 Reached maxTotalEmails limit: $maxTotalEmails');
            break;
          }
        } catch (apiError) {
          print('❌ Gmail API error: $apiError');
          print('❌ Error type: ${apiError.runtimeType}');
          throw Exception('Gmail API error: $apiError');
        }
      } while (pageToken != null);

      print('✅ Sync complete: $newEmailsCount new emails, $totalProcessed total processed');

      // Update last synced timestamp
      await db.update(
        'email_accounts',
        {
          'last_synced_at': DateTime.now().toIso8601String(),
          'emails_processed': account.emailsProcessed + newEmailsCount,
        },
        where: 'id = ?',
        whereArgs: [account.id],
      );

      return newEmailsCount;
    } catch (e) {
      print('Error syncing emails: $e');
      return 0;
    }
  }

  /// Build search query for transactional emails
  String _buildSearchQuery() {
    // Search for emails containing financial keywords
    // Includes Indian banking terms
    final keywords = [
      'transaction',
      'payment',
      'receipt',
      'invoice',
      'purchase',
      'order',
      'bank',
      'credit card',
      'debit',
      'debited',
      'credit',
      'credited',
      'spend',
      'spent',
      'transfer',
      'withdrawal',
      'deposit',
    ];

    final query = keywords.map((k) => '$k').join(' OR ');
    print('🔍 Using keyword query: $query');
    return query;
  }

  /// Parse Gmail message to EmailMessage model
  EmailMessage? _parseGmailMessage(gmail.Message message, String accountId) {
    try {
      final headers = message.payload?.headers ?? [];

      String from = '';
      String fromName = '';
      String subject = '';

      for (final header in headers) {
        if (header.name == 'From') {
          final fromValue = header.value ?? '';
          // Parse "Name <email@example.com>" format
          final regex = RegExp(r'(.*?)\s*<(.+?)>');
          final match = regex.firstMatch(fromValue);
          if (match != null) {
            fromName = match.group(1)?.trim() ?? '';
            from = match.group(2)?.trim() ?? '';
          } else {
            from = fromValue.trim();
            fromName = from;
          }
        } else if (header.name == 'Subject') {
          subject = header.value ?? '';
        }
      }

      final receivedAt = message.internalDate != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.parse(message.internalDate!))
          : DateTime.now();

      String? textBody;
      String? htmlBody;
      final snippet = message.snippet;

      // Extract body from payload
      if (message.payload?.body?.data != null) {
        final bodyData = message.payload!.body!.data!;
        textBody = _decodeBase64(bodyData);
      } else if (message.payload?.parts != null) {
        for (final part in message.payload!.parts!) {
          if (part.mimeType == 'text/plain' && part.body?.data != null) {
            textBody = _decodeBase64(part.body!.data!);
          } else if (part.mimeType == 'text/html' && part.body?.data != null) {
            htmlBody = _decodeBase64(part.body!.data!);
          }
        }
      }

      // Convert labels to JSON
      String? labelsJson;
      if (message.labelIds != null && message.labelIds!.isNotEmpty) {
        labelsJson = jsonEncode(message.labelIds);
      }

      return EmailMessage(
        id: message.id!,
        accountId: accountId,
        from: from,
        fromName: fromName,
        subject: subject,
        snippet: snippet,
        textBody: textBody,
        htmlBody: htmlBody,
        receivedAt: receivedAt,
        isTransactional: true, // All filtered emails are considered transactional
        labels: labelsJson,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Gmail message: $e');
      return null;
    }
  }

  /// Decode Base64 URL-safe string
  String _decodeBase64(String encoded) {
    try {
      // Replace URL-safe characters
      String normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');

      // Add padding if needed
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }

      return utf8.decode(base64.decode(normalized));
    } catch (e) {
      return '';
    }
  }

  /// Get all emails
  Future<List<EmailMessage>> getAllEmails({int? limit}) async {
    final db = await _db.database;
    final result = await db.query(
      'email_messages',
      orderBy: 'received_at DESC',
      limit: limit,
    );

    return result.map((map) => EmailMessage.fromMap(map)).toList();
  }

  /// Get unprocessed emails
  Future<List<EmailMessage>> getUnprocessedEmails({
    String? accountId,
    int limit = 50,
  }) async {
    final db = await _db.database;

    String whereClause = 'is_processed = ?';
    List<dynamic> whereArgs = [0];

    if (accountId != null) {
      whereClause = 'is_processed = ? AND account_id = ?';
      whereArgs = [0, accountId];
    }

    final result = await db.query(
      'email_messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'received_at DESC',
      limit: limit,
    );

    return result.map((map) => EmailMessage.fromMap(map)).toList();
  }

  /// Mark email as processed
  Future<void> markEmailAsProcessed(String emailId, {String? transactionId}) async {
    final db = await _db.database;
    await db.update(
      'email_messages',
      {
        'is_processed': 1,
        'transaction_id': transactionId,
      },
      where: 'id = ?',
      whereArgs: [emailId],
    );
  }

  /// Get email by ID
  Future<EmailMessage?> getEmailById(String id) async {
    final db = await _db.database;
    final result = await db.query(
      'email_messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return EmailMessage.fromMap(result.first);
  }

  /// Delete email
  Future<void> deleteEmail(String id) async {
    final db = await _db.database;
    await db.delete(
      'email_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all emails for an account (for testing)
  Future<int> clearAllEmails(String accountId) async {
    final db = await _db.database;

    // Delete all emails for this account
    final count = await db.delete(
      'email_messages',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );

    // Reset last synced timestamp
    await db.update(
      'email_accounts',
      {
        'last_synced_at': null,
        'emails_processed': 0,
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );

    return count;
  }

  /// Get email statistics
  Future<Map<String, int>> getEmailStats(String accountId) async {
    final db = await _db.database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM email_messages WHERE account_id = ?',
      [accountId],
    );

    final processedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM email_messages WHERE account_id = ? AND is_processed = 1',
      [accountId],
    );

    return {
      'total': (totalResult.first['count'] as int?) ?? 0,
      'processed': (processedResult.first['count'] as int?) ?? 0,
    };
  }

  // ========== Auto-Polling Configuration ==========

  static const String _autoSyncEnabledKey = 'email_auto_sync_enabled';
  static const String _syncIntervalKey = 'email_sync_interval_minutes';

  /// Check if auto-sync is enabled
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncEnabledKey) ?? false;
  }

  /// Enable/disable auto-sync
  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, enabled);
    print('📧 Auto-sync ${enabled ? "enabled" : "disabled"}');
  }

  /// Get sync interval in minutes (0 = manual only)
  Future<int> getSyncIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncIntervalKey) ?? 0; // Default: manual only
  }

  /// Set sync interval in minutes (0 = manual only)
  Future<void> setSyncIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalKey, minutes);
    print('📧 Sync interval set to: ${minutes > 0 ? "$minutes minutes" : "manual only"}');
  }

  /// Get available polling interval options
  static List<Map<String, dynamic>> getPollingIntervalOptions() {
    return [
      {'label': 'Manual Only', 'minutes': 0},
      {'label': 'Every 15 minutes', 'minutes': 15},
      {'label': 'Every 30 minutes', 'minutes': 30},
      {'label': 'Every 1 hour', 'minutes': 60},
      {'label': 'Every 2 hours', 'minutes': 120},
      {'label': 'Every 4 hours', 'minutes': 240},
    ];
  }
}

/// Custom HTTP client for Gmail API authentication
class _GoogleAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
