import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/llm_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  final LLMService _llmService = LLMService();
  final TransactionService _transactionService = TransactionService();

  String? _lastError;
  List<Map<String, dynamic>> _transactionErrors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadErrors();
  }

  Future<void> _loadErrors() async {
    setState(() => _isLoading = true);

    // Get last LLM error
    final lastError = await _llmService.getLastError();

    // Get all transactions with parsing errors
    final allTransactions = await _transactionService.getAllTransactions();
    final transactionsWithErrors = allTransactions
        .where((t) => t.parsingError != null && t.parsingError!.isNotEmpty)
        .map((t) => {
              'id': t.id,
              'rawMessage': t.rawMessage,
              'error': t.parsingError!,
              'timestamp': t.timestamp,
              'parserType': t.parserType ?? 'Unknown',
            })
        .toList();

    // Sort by timestamp (most recent first)
    transactionsWithErrors.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    setState(() {
      _lastError = lastError;
      _transactionErrors = transactionsWithErrors;
      _isLoading = false;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: AppTheme.coral,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearErrors() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear LLM Error?'),
        content: const Text('This will clear the cached LLM error. Transaction parsing errors will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: TextStyle(color: AppTheme.coral)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _llmService.clearLastError();
      await _loadErrors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LLM error cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFullError(Map<String, dynamic> errorData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Transaction ID:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(errorData['id']),
              const SizedBox(height: 12),
              const Text(
                'Raw SMS:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(errorData['rawMessage']),
              const SizedBox(height: 12),
              const Text(
                'Parser Type:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(errorData['parserType']),
              const SizedBox(height: 12),
              Text(
                'Error:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.coral,
                ),
              ),
              SelectableText(
                errorData['error'],
                style: TextStyle(color: AppTheme.coral),
              ),
              const SizedBox(height: 12),
              const Text(
                'Timestamp:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                _formatDate(errorData['timestamp'] as DateTime),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final fullText = '''
Transaction ID: ${errorData['id']}
Raw SMS: ${errorData['rawMessage']}
Parser Type: ${errorData['parserType']}
Error: ${errorData['error']}
Timestamp: ${_formatDate(errorData['timestamp'] as DateTime)}
              '''.trim();
              _copyToClipboard(fullText);
            },
            child: const Text('Copy All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Log'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearErrors,
            tooltip: 'Clear LLM Error',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadErrors,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadErrors,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Last LLM Error Section
                  if (_lastError != null) ...[
                    Card(
                      color: isDark
                          ? AppTheme.coral.withOpacity(0.1)
                          : AppTheme.coral.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error, color: AppTheme.coral),
                                const SizedBox(width: 8),
                                const Text(
                                  'Latest LLM Error',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              _lastError!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _copyToClipboard(_lastError!),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Transaction Errors Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list_alt),
                              const SizedBox(width: 8),
                              const Text(
                                'Transaction Parsing Errors',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Chip(
                                label: Text('${_transactionErrors.length}'),
                                backgroundColor: _transactionErrors.isEmpty
                                    ? (isDark
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.1))
                                    : (isDark
                                        ? Colors.orange.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Error List
                  if (_transactionErrors.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: isDark
                                  ? Colors.green.withOpacity(0.6)
                                  : Colors.green,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No parsing errors!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All transactions were parsed successfully.',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._transactionErrors.map((errorData) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? AppTheme.coral.withOpacity(0.2)
                                : AppTheme.coral.withOpacity(0.1),
                            child: Icon(
                              Icons.error_outline,
                              color: AppTheme.coral,
                            ),
                          ),
                          title: Text(
                            errorData['rawMessage'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Error: ${errorData['error']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppTheme.coral),
                              ),
                              Text(
                                _formatDate(errorData['timestamp'] as DateTime),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () => _copyToClipboard(errorData['error']),
                                tooltip: 'Copy error',
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 20),
                                onPressed: () => _showFullError(errorData),
                                tooltip: 'View details',
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Info Card
                  Card(
                    color: AppTheme.purple.withAlpha(25),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.purple),
                              SizedBox(width: 8),
                              Text(
                                'About Errors',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Errors are logged when parsing fails\n'
                            '• LLM errors show API/connection issues\n'
                            '• Transaction errors show SMS parsing failures\n'
                            '• Tap any error to view full details\n'
                            '• Use copy button to share error messages',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
