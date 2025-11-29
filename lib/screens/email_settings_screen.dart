import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../models/email_account.dart';
import '../services/email_service.dart';
import '../services/email_parser.dart';
import '../services/background_email_service.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({Key? key}) : super(key: key);

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final EmailService _emailService = EmailService();
  final EmailParser _emailParser = EmailParser();

  List<EmailAccount> _accounts = [];
  Map<String, int> _unprocessedCounts = {}; // accountId -> unprocessed count
  bool _isLoading = true;
  bool _isSyncing = false;

  // Sync progress tracking
  int _syncCurrent = 0;
  int? _syncTotal;
  String _syncStatus = '';

  // Parse progress tracking
  bool _isParsing = false;
  int _parseCurrent = 0;
  int _parseTotal = 0;
  String _parseStatus = '';

  // Polling configuration
  bool _autoSyncEnabled = false;
  int _syncIntervalMinutes = 0;

  // Background sync status
  int _backgroundSyncStatus = 0; // 0 = unavailable, 1 = available, 2 = restricted
  DateTime? _lastBackgroundSync;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadPollingSettings();
    _loadBackgroundSyncStatus();
  }

  Future<void> _loadPollingSettings() async {
    final enabled = await _emailService.isAutoSyncEnabled();
    final interval = await _emailService.getSyncIntervalMinutes();
    setState(() {
      _autoSyncEnabled = enabled;
      _syncIntervalMinutes = interval;
    });
  }

  Future<void> _loadBackgroundSyncStatus() async {
    try {
      final status = await BackgroundEmailService.getStatus();
      final lastSync = await BackgroundEmailService.getLastBackgroundSync();
      setState(() {
        _backgroundSyncStatus = status;
        _lastBackgroundSync = lastSync;
      });
    } catch (e) {
      print('Error loading background sync status: $e');
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _emailService.getConnectedAccounts();

      // Load unprocessed counts for each account (limit to 100 to match parsing limit)
      final counts = <String, int>{};
      for (final account in accounts) {
        final unprocessedEmails = await _emailService.getUnprocessedEmails(
          accountId: account.id,
          limit: 100, // Match the parsing limit
        );
        counts[account.id] = unprocessedEmails.length;
      }

      setState(() {
        _accounts = accounts;
        _unprocessedCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading accounts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectGmailAccount() async {
    try {
      final account = await _emailService.connectGmailAccount();

      if (account != null) {
        await _loadAccounts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected ${account.email}'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // Ask if user wants to sync now
          _promptInitialSync(account);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect account: $e'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _promptInitialSync(EmailAccount account) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sync Emails?'),
        content: const Text(
          'Would you like to sync your recent transactional emails now? This will fetch emails containing payment and transaction information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _syncAccount(account);
    }
  }

  Future<void> _syncAccount(EmailAccount account) async {
    setState(() {
      _isSyncing = true;
      _syncCurrent = 0;
      _syncTotal = null;
      _syncStatus = 'Starting sync...';
    });

    try {
      print('🔄 Starting sync from UI...');
      final count = await _emailService.syncEmails(
        account,
        maxResults: 10, // Fetch 10 emails per batch
        maxTotalEmails: null, // Fetch all emails
        onProgress: (current, total, status) {
          setState(() {
            _syncCurrent = current;
            _syncTotal = total;
            _syncStatus = status;
          });
        },
      );
      print('✅ Sync completed: $count emails');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
              ? 'Synced $count new emails'
              : 'No new emails found (check Gmail for transaction emails)'),
            backgroundColor: count > 0 ? AppTheme.successGreen : AppTheme.warningOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: count > 0 ? 3 : 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Prompt to parse emails
        if (count > 0) {
          _promptParseEmails(count);
        }
      }

      await _loadAccounts();
    } catch (e) {
      print('❌ Sync error in UI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _clearAllEmails(EmailAccount account) async {
    // Confirm with user
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Emails?'),
        content: const Text(
          'This will:\n'
          '• Delete all synced emails from local storage\n'
          '• Reset sync timestamp\n'
          '• Next sync will fetch ALL emails again\n\n'
          'Use this for testing or to re-sync from scratch.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final count = await _emailService.clearAllEmails(account.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared $count emails. You can now sync fresh emails.'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      await _loadAccounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear emails: $e'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _promptParseEmails(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Parse Emails?'),
        content: Text(
          'Found $count new transactional emails. Would you like to process them now to extract transactions?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Process Now'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _parseUnprocessedEmails();
    }
  }

  Future<void> _parseUnprocessedEmails() async {
    setState(() {
      _isParsing = true;
      _parseCurrent = 0;
      _parseTotal = 0;
      _parseStatus = 'Starting parsing...';
    });

    try {
      print('🔄 Starting email parsing from UI...');
      final results = await _emailParser.parseUnprocessedEmails(
        limit: 100, // Parse up to 100 emails
        rateLimit: 0, // No rate limiting (handled per email in parseEmail)
        onProgress: (current, total, status) {
          setState(() {
            _parseCurrent = current;
            _parseTotal = total;
            _parseStatus = status;
          });
        },
      );

      print('✅ Parsing completed: ${results.length} transactions');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processed ${results.length} transactions from emails'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isParsing = false;
      });
      await _loadAccounts();
    }
  }

  Future<void> _parseAccountEmails(EmailAccount account) async {
    // Check if there are unprocessed emails
    final unprocessedCount = _unprocessedCounts[account.id] ?? 0;
    if (unprocessedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No unprocessed emails to parse'),
          backgroundColor: AppTheme.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Confirm with user
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Parse Unprocessed Emails?'),
        content: Text(
          'Found $unprocessedCount unprocessed email${unprocessedCount > 1 ? 's' : ''}. Would you like to process them now to extract transactions?\n\nThis will use LLM API calls (0.5 sec delay between emails).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Parse Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isParsing = true;
      _parseCurrent = 0;
      _parseTotal = 0;
      _parseStatus = 'Starting parsing...';
    });

    try {
      print('🔄 Starting email parsing for account: ${account.email}');

      // Get unprocessed emails for this account
      final unprocessedEmails = await _emailService.getUnprocessedEmails(
        accountId: account.id,
        limit: 100,
      );

      if (unprocessedEmails.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No unprocessed emails found'),
              backgroundColor: AppTheme.warningOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      final total = unprocessedEmails.length;
      setState(() {
        _parseTotal = total;
      });

      // Parse each email with rate limiting
      int successCount = 0;
      for (int i = 0; i < unprocessedEmails.length; i++) {
        final email = unprocessedEmails[i];
        final current = i + 1;

        setState(() {
          _parseCurrent = current;
          _parseStatus = 'Parsing email $current/$total...';
        });

        print('📧 Parsing email $current/$total: ${email.subject}');

        final result = await _emailParser.parseEmail(email);

        if (result != null && result.success) {
          successCount++;
          print('✅ Successfully parsed email $current/$total');
        } else {
          print('❌ Failed to parse email $current/$total');
        }

        // Rate limiting: wait before parsing next email (except for last one)
        if (current < total) {
          setState(() {
            _parseStatus = 'Rate limiting (0.5 sec)...';
          });
          print('⏱️ Rate limiting: waiting 0.5 seconds...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      print('✅ Parsing completed: $successCount succeeded out of $total');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processed $successCount transactions from $total emails'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Parsing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isParsing = false;
      });
      await _loadAccounts();
    }
  }

  Future<void> _disconnectAccount(EmailAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect Account'),
        content: Text('Are you sure you want to disconnect ${account.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _emailService.disconnectAccount(account.id);
      await _loadAccounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected ${account.email}'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email Integration',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect your email accounts',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // White content section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? scaffoldBg : AppTheme.whiteBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.purple.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connect your Gmail to automatically import transactional emails and extract transactions.',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Auto-Polling Settings
        if (_accounts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _buildPollingSettings(),
          ),
        ],

        // Connected accounts
        Expanded(
          child: _accounts.isEmpty ? _buildEmptyState() : _buildAccountsList(),
        ),

        // Add account button
        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton.icon(
            onPressed: _isSyncing ? null : _connectGmailAccount,
            icon: const Icon(Icons.add),
            label: const Text('Connect Gmail Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.email_outlined,
            size: 80,
            color: ThemeHelper.textSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No accounts connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your Gmail to get started',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _accounts.length,
      itemBuilder: (context, index) {
        final account = _accounts[index];
        return _buildAccountCard(account);
      },
    );
  }

  Widget _buildAccountCard(EmailAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: ThemeHelper.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Gmail icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.email, color: AppTheme.coral),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeHelper.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showAccountOptions(account),
                icon: Icon(
                  Icons.more_vert,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  'Processed',
                  account.emailsProcessed.toString(),
                  Icons.check_circle_outline,
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Unprocessed',
                  (_unprocessedCounts[account.id] ?? 0).toString(),
                  Icons.pending_actions,
                  color: (_unprocessedCounts[account.id] ?? 0) > 0
                      ? AppTheme.warningOrange
                      : null,
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Last Sync',
                  account.lastSyncedAt != null
                      ? _formatDate(account.lastSyncedAt!)
                      : 'Never',
                  Icons.sync,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sync progress or button
          if (_isSyncing) ...[
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.purple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _syncStatus,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.purple,
                              ),
                            ),
                            Text(
                              _syncTotal != null
                                  ? '${_syncCurrent}/${_syncTotal} emails'
                                  : '${_syncCurrent} emails fetched',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.purple.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show indeterminate progress bar (no total available)
                  const LinearProgressIndicator(
                    backgroundColor: Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Sync button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _syncAccount(account),
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.purple,
                  side: BorderSide(color: AppTheme.purple.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Parse unprocessed emails button
          if ((_unprocessedCounts[account.id] ?? 0) > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing || _isParsing ? null : () => _parseAccountEmails(account),
                icon: const Icon(Icons.auto_fix_high),
                label: Text('Parse ${_unprocessedCounts[account.id]} Unprocessed Email${(_unprocessedCounts[account.id] ?? 0) > 1 ? 's' : ''}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Clear all emails button (for testing)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSyncing || _isParsing ? null : () => _clearAllEmails(account),
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All Emails'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.coral,
                side: BorderSide(color: AppTheme.coral.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Parsing progress indicator
          if (_isParsing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.coral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _parseStatus,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.coral,
                              ),
                            ),
                            if (_parseTotal > 0)
                              Text(
                                '${_parseCurrent}/${_parseTotal} emails parsed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.coral.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_parseTotal > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _parseTotal > 0 ? _parseCurrent / _parseTotal : 0,
                      backgroundColor: AppTheme.coral.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.coral),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPollingSettings() {
    final options = EmailService.getPollingIntervalOptions();
    final selectedOption = options.firstWhere(
      (opt) => opt['minutes'] == _syncIntervalMinutes,
      orElse: () => options[0],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeHelper.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Auto-Sync Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
              ),
              Switch(
                value: _autoSyncEnabled,
                onChanged: (value) async {
                  await _emailService.setAutoSyncEnabled(value);

                  // Start or stop background sync service
                  if (value) {
                    await BackgroundEmailService.start();
                  } else {
                    await BackgroundEmailService.stop();
                  }

                  await _loadPollingSettings();
                  await _loadBackgroundSyncStatus();
                },
                activeColor: AppTheme.purple,
              ),
            ],
          ),
          if (_autoSyncEnabled) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Sync Interval',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _syncIntervalMinutes,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: options.map<DropdownMenuItem<int>>((option) {
                return DropdownMenuItem<int>(
                  value: option['minutes'],
                  child: Text(
                    option['label'],
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeHelper.textPrimary(context),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  await _emailService.setSyncIntervalMinutes(value);
                  await _loadPollingSettings();
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              _syncIntervalMinutes == 0
                  ? 'Emails will only sync when you tap "Sync Now"'
                  : 'Emails will automatically sync every ${selectedOption['label']?.toString().toLowerCase().replaceAll('every ', '')}',
              style: TextStyle(
                fontSize: 11,
                color: ThemeHelper.textSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
            // Background sync status
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildBackgroundSyncStatus(),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, {Color? color}) {
    final displayColor = color ?? ThemeHelper.textPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: color ?? ThemeHelper.textSecondary(context),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeHelper.textSecondary(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: displayColor,
          ),
        ),
      ],
    );
  }

  void _showAccountOptions(EmailAccount account) {
    final unprocessedCount = _unprocessedCounts[account.id] ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync, color: AppTheme.purple),
              title: const Text('Sync Emails'),
              onTap: () {
                Navigator.pop(context);
                _syncAccount(account);
              },
            ),
            if (unprocessedCount > 0)
              ListTile(
                leading: const Icon(Icons.auto_fix_high, color: AppTheme.coral),
                title: Text('Parse $unprocessedCount Unprocessed Email${unprocessedCount > 1 ? 's' : ''}'),
                onTap: () {
                  Navigator.pop(context);
                  _parseAccountEmails(account);
                },
              ),
            ListTile(
              leading: const Icon(Icons.link_off, color: AppTheme.coral),
              title: const Text('Disconnect Account'),
              onTap: () {
                Navigator.pop(context);
                _disconnectAccount(account);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildBackgroundSyncStatus() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    // Status codes from BackgroundFetch:
    // 0 = unavailable, 1 = available, 2 = restricted
    switch (_backgroundSyncStatus) {
      case 1:
        statusText = 'Background sync is active';
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 2:
        statusText = 'Background sync is restricted by iOS';
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.warning;
        break;
      default:
        statusText = 'Background sync unavailable';
        statusColor = AppTheme.coral;
        statusIcon = Icons.error_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Background Sync Status',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ThemeHelper.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (_lastBackgroundSync != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: ThemeHelper.textSecondary(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Last background sync: ${_formatDate(_lastBackgroundSync!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: ThemeHelper.textSecondary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'iOS controls when background tasks run. Sync may not happen at exact intervals.',
                  style: TextStyle(
                    fontSize: 10,
                    color: ThemeHelper.textSecondary(context),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
