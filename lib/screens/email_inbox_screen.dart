import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../services/email_service.dart';
import '../services/email_parser.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import 'email_parser_tester_screen.dart';

class EmailInboxScreen extends StatefulWidget {
  const EmailInboxScreen({Key? key}) : super(key: key);

  @override
  State<EmailInboxScreen> createState() => _EmailInboxScreenState();
}

class _EmailInboxScreenState extends State<EmailInboxScreen> {
  final EmailService _emailService = EmailService();
  final EmailParser _emailParser = EmailParser();

  List<EmailMessage> _emails = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _filterStatus = 'all'; // all, processed, unprocessed

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allEmails = await _emailService.getAllEmails();

      setState(() {
        _emails = allEmails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading emails: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<EmailMessage> get _filteredEmails {
    if (_filterStatus == 'processed') {
      return _emails.where((e) => e.isProcessed).toList();
    } else if (_filterStatus == 'unprocessed') {
      return _emails.where((e) => !e.isProcessed).toList();
    }
    return _emails;
  }

  Future<void> _parseEmail(EmailMessage email) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _emailParser.parseEmail(email);

      if (result != null && result.success) {
        _showSnackBar('Successfully parsed email and created transaction');
        await _loadData();
      } else {
        _showSnackBar('Failed to parse email', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error parsing email: $e', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _deleteEmail(EmailMessage email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Email'),
        content: const Text('Are you sure you want to delete this email?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _emailService.deleteEmail(email.id);
      await _loadData();
      _showSnackBar('Email deleted');
    }
  }

  void _showEmailDetails(EmailMessage email) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Email Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.textPrimary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final content = _prepareEmailContent(email);
                        Clipboard.setData(ClipboardData(text: content));
                        Navigator.pop(context);
                        _showSnackBar('Copied to clipboard');
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Email content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailRow('From', '${email.fromName} <${email.from}>'),
                      _buildDetailRow('Subject', email.subject),
                      _buildDetailRow('Date', _formatDate(email.receivedAt)),
                      _buildDetailRow(
                        'Status',
                        email.isProcessed ? 'Processed' : 'Unprocessed',
                        valueColor: email.isProcessed ? AppTheme.successGreen : AppTheme.warningOrange,
                      ),
                      if (email.transactionId != null)
                        _buildDetailRow('Transaction ID', email.transactionId!),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      Text(
                        'Content',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeHelper.surfaceColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          email.textBody ?? email.snippet ?? 'No content',
                          style: TextStyle(
                            fontSize: 13,
                            color: ThemeHelper.textPrimary(context),
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!email.isProcessed)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _parseEmail(email);
                                },
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('Parse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (!email.isProcessed) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteEmail(email);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.coral,
                          side: const BorderSide(color: AppTheme.coral),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ThemeHelper.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? ThemeHelper.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _prepareEmailContent(EmailMessage email) {
    final buffer = StringBuffer();
    buffer.writeln('From: ${email.fromName} <${email.from}>');
    buffer.writeln('Subject: ${email.subject}');
    buffer.writeln('Date: ${_formatDate(email.receivedAt)}');
    buffer.writeln();
    buffer.writeln(email.textBody ?? email.snippet ?? 'No content');
    return buffer.toString();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.coral : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
                            'Email Inbox',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_filteredEmails.length} emails',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmailParserTesterScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.science, color: Colors.white),
                      tooltip: 'Parser Tester',
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, color: Colors.white),
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
                  child: Column(
                    children: [
                      // Filter chips
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Processed', 'processed'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Unprocessed', 'unprocessed'),
                          ],
                        ),
                      ),

                      // Email list
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredEmails.isEmpty
                                ? _buildEmptyState()
                                : _buildEmailList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: ThemeHelper.surfaceColor(context),
      selectedColor: AppTheme.purple.withOpacity(0.2),
      checkmarkColor: AppTheme.purple,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.purple : ThemeHelper.textPrimary(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: ThemeHelper.textSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No emails found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your email and sync to see emails here',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredEmails.length,
      itemBuilder: (context, index) {
        final email = _filteredEmails[index];
        return _buildEmailCard(email);
      },
    );
  }

  Widget _buildEmailCard(EmailMessage email) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ThemeHelper.cardDecoration(context),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: email.isProcessed
                ? AppTheme.successGreen.withOpacity(0.1)
                : AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            email.isProcessed ? Icons.check_circle : Icons.email,
            color: email.isProcessed ? AppTheme.successGreen : AppTheme.warningOrange,
          ),
        ),
        title: Text(
          email.subject,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: ThemeHelper.textPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              email.fromName,
              style: TextStyle(
                fontSize: 13,
                color: ThemeHelper.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(email.receivedAt),
              style: TextStyle(
                fontSize: 12,
                color: ThemeHelper.textSecondary(context),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: ThemeHelper.textSecondary(context),
        ),
        onTap: () => _showEmailDetails(email),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
