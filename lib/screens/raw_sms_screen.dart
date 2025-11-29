import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/llm_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class RawSmsScreen extends StatefulWidget {
  final String? initialTransactionId;

  const RawSmsScreen({super.key, this.initialTransactionId});

  @override
  State<RawSmsScreen> createState() => _RawSmsScreenState();
}

class _RawSmsScreenState extends State<RawSmsScreen> {
  final TransactionService _transactionService = TransactionService();
  final LLMService _llmService = LLMService();
  final ScrollController _scrollController = ScrollController();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _llmEnabled = false;
  String? _expandedTransactionId;

  @override
  void initState() {
    super.initState();
    _expandedTransactionId = widget.initialTransactionId;
    _loadTransactions();
    _checkLLMStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLLMStatus() async {
    final enabled = await _llmService.isEnabled();
    setState(() => _llmEnabled = enabled);
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    final transactions = await _transactionService.getAllTransactions();

    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });

    // Auto-scroll to specific transaction if provided
    if (widget.initialTransactionId != null && transactions.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final index = transactions.indexWhere((t) => t.id == widget.initialTransactionId);
        if (index != -1 && _scrollController.hasClients) {
          // Calculate approximate position (each card is ~80px tall + 6px margin)
          final position = index * 86.0;

          // Scroll to the transaction
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );

          // Show indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Debugging: ${transactions[index].merchant}'),
              backgroundColor: AppTheme.primaryPurple,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: AppTheme.coral,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatFullTransactionData(Transaction transaction) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('TRANSACTION DEBUG DATA');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln();

    // Raw Message
    buffer.writeln('--- RAW MESSAGE ---');
    buffer.writeln(transaction.rawMessage);
    buffer.writeln();

    // Parser Metadata
    buffer.writeln('--- PARSER METADATA ---');
    buffer.writeln('Parser Type: ${_getParserDisplayName(transaction.parserType)}');
    buffer.writeln('Confidence: ${(transaction.parserConfidence * 100).toStringAsFixed(1)}%');
    if (transaction.parseTime != null) {
      buffer.writeln('Parse Time: ${transaction.parseTime!.toStringAsFixed(2)}s');
    }
    if (transaction.transactionId != null) {
      buffer.writeln('Transaction ID: ${transaction.transactionId}');
    }
    buffer.writeln();

    // Parsed Data
    if (transaction.isParsed) {
      buffer.writeln('--- PARSED DATA ---');
      buffer.writeln('Amount: ₹${_formatAmount(transaction.amount ?? 0)}');
      buffer.writeln('Type: ${transaction.type == TransactionType.debit ? 'Debit' : 'Credit'}');
      buffer.writeln('Merchant: ${transaction.merchant}');
      buffer.writeln('Category: ${transaction.category}');
      if (transaction.accountLastDigits != null) {
        buffer.writeln('Account: XX${transaction.accountLastDigits}');
      }
      if (transaction.balance != null) {
        buffer.writeln('Balance: ₹${_formatAmount(transaction.balance!)}');
      }
      buffer.writeln('Date: ${_formatDate(transaction.timestamp)}');
    }

    // Error (if any)
    if (transaction.parsingError != null) {
      buffer.writeln();
      buffer.writeln('--- PARSING ERROR ---');
      buffer.writeln(transaction.parsingError);
    }

    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }

  Color _getParserColor(String? parserType) {
    if (parserType == null) return Colors.grey;
    if (parserType == 'Email-LLM') return Colors.green; // Email = Green
    if (parserType.startsWith('LLM:')) {
      if (parserType.contains('Failed')) return Colors.red;
      return Colors.purple; // SMS LLM = Purple
    }
    return Colors.blue; // SMS Regex = Blue
  }

  IconData _getParserIcon(String? parserType) {
    if (parserType == null) return Icons.help_outline;
    if (parserType == 'Email-LLM') return Icons.email; // Email icon
    if (parserType.startsWith('LLM:')) {
      if (parserType.contains('Failed')) return Icons.error_outline;
      return Icons.sms; // SMS icon for SMS-LLM
    }
    return Icons.code;
  }

  String _getParserDisplayName(String? parserType) {
    if (parserType == null) return 'Unknown';
    if (parserType == 'Email-LLM') return 'Email (LLM)';
    if (parserType.startsWith('LLM:')) {
      if (parserType.contains('Failed')) return 'SMS (LLM Failed)';
      // Extract model name
      final modelName = parserType.substring(4);
      return 'SMS (LLM: $modelName)';
    }
    return 'SMS (Regex)';
  }

  Future<void> _reparse(Transaction transaction) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Re-parsing with LLM...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _llmService.parseSMS(transaction.rawMessage);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        final updatedTransaction = await _llmService.responseToTransaction(
          result,
          transaction.rawMessage,
        );

        if (updatedTransaction != null) {
          await _transactionService.updateTransaction(
            updatedTransaction.copyWith(id: transaction.id),
          );
          _loadTransactions();
          _showSnackBar('Transaction re-parsed successfully');
        } else {
          _showSnackBar('Failed to convert LLM response', isError: true);
        }
      } else {
        _showSnackBar('LLM parsing failed: ${result['error']}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppTheme.coral,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Debug Log'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_llmEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.smart_toy, size: 16),
                label: const Text('LLM', style: TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.purple.withAlpha(51),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadTransactions();
              _checkLLMStatus();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No SMS messages yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Parsed transactions (SMS & Email) will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTransactions,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _transactions.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      final shouldExpand = transaction.id == _expandedTransactionId;

                      return Card(
                        key: ValueKey('card_${transaction.id}'),
                        color: ThemeHelper.cardColor(context),
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: ExpansionTile(
                          key: PageStorageKey<String>('expansion_${transaction.id}'),
                          backgroundColor: ThemeHelper.cardColor(context),
                          collapsedBackgroundColor: ThemeHelper.cardColor(context),
                          initiallyExpanded: shouldExpand,
                          onExpansionChanged: (expanded) {
                            if (expanded && transaction.id == _expandedTransactionId) {
                              // Clear the expanded flag after first expansion
                              setState(() {
                                _expandedTransactionId = null;
                              });
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: transaction.isParsed
                                ? Colors.green.withAlpha((0.2 * 255).toInt())
                                : Colors.orange.withAlpha((0.2 * 255).toInt()),
                            child: Icon(
                              transaction.isParsed
                                  ? Icons.check_circle
                                  : Icons.warning_amber,
                              color: transaction.isParsed ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            transaction.isParsed
                                ? '${transaction.merchant} - ₹${_formatAmount(transaction.amount ?? 0)}'
                                : 'SMS Message',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(transaction.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: transaction.isParsed
                                          ? Colors.green.withAlpha((0.2 * 255).toInt())
                                          : Colors.orange.withAlpha((0.2 * 255).toInt()),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      transaction.isParsed ? 'Parsed' : 'Failed',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: transaction.isParsed ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (transaction.parserType != null) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getParserColor(transaction.parserType)
                                            .withAlpha((0.2 * 255).toInt()),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getParserIcon(transaction.parserType),
                                            size: 10,
                                            color: _getParserColor(transaction.parserType),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            transaction.parserType!.startsWith('LLM:')
                                                ? 'LLM'
                                                : 'Regex',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _getParserColor(transaction.parserType),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ThemeHelper.isDark(context)
                                    ? ThemeHelper.surfaceColor(context)
                                    : Colors.white,
                                border: Border(
                                  top: BorderSide(
                                    color: ThemeHelper.isDark(context)
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Raw Message Section
                                  Row(
                                    children: [
                                      Text(
                                        'Raw Message:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: ThemeHelper.textPrimary(context),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.copy_all, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _copyToClipboard(_formatFullTransactionData(transaction)),
                                        tooltip: 'Copy All Data',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.cardColor(context),
                                      border: Border.all(
                                        color: ThemeHelper.isDark(context)
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      transaction.rawMessage,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: ThemeHelper.textPrimary(context),
                                      ),
                                    ),
                                  ),

                                  // Parser Metadata Section
                                  const SizedBox(height: 16),
                                  Text(
                                    'Parser Metadata:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: ThemeHelper.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.isDark(context)
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.blue.withAlpha(13),
                                      border: Border.all(
                                        color: ThemeHelper.isDark(context)
                                            ? Colors.blue.withOpacity(0.3)
                                            : Colors.blue.withAlpha(51),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildMetadataRow(
                                          'Parser Type',
                                          _getParserDisplayName(transaction.parserType),
                                          _getParserIcon(transaction.parserType),
                                          _getParserColor(transaction.parserType),
                                        ),
                                        _buildMetadataRow(
                                          'Confidence',
                                          '${(transaction.parserConfidence * 100).toStringAsFixed(1)}%',
                                          Icons.analytics,
                                          transaction.parserConfidence > 0.7
                                              ? Colors.green
                                              : transaction.parserConfidence > 0.4
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                        if (transaction.parseTime != null)
                                          _buildMetadataRow(
                                            'Parse Time',
                                            '${transaction.parseTime!.toStringAsFixed(2)}s',
                                            Icons.timer,
                                            Colors.blue,
                                          ),
                                        if (transaction.transactionId != null)
                                          _buildMetadataRow(
                                            'Transaction ID',
                                            transaction.transactionId!,
                                            Icons.tag,
                                            Colors.purple,
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Error Section (if any)
                                  if (transaction.parsingError != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Parsing Error:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: ThemeHelper.isDark(context)
                                            ? Colors.red[300]!
                                            : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withAlpha(13),
                                        border: Border.all(color: Colors.red.withAlpha(51)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: SelectableText(
                                              transaction.parsingError!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.red,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy_all, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _copyToClipboard(_formatFullTransactionData(transaction)),
                                            tooltip: 'Copy All Data',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Parsed Data Section
                                  if (transaction.isParsed) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Parsed Data:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: ThemeHelper.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: ThemeHelper.isDark(context)
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.green.withAlpha(13),
                                        border: Border.all(
                                          color: ThemeHelper.isDark(context)
                                              ? Colors.green.withOpacity(0.3)
                                              : Colors.green.withAlpha(51),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildParseInfo('Amount', '₹${_formatAmount(transaction.amount ?? 0)}'),
                                          _buildParseInfo('Type', transaction.type == TransactionType.debit ? 'Debit' : 'Credit'),
                                          _buildParseInfo('Merchant', transaction.merchant),
                                          _buildParseInfo('Category', transaction.category),
                                          if (transaction.accountLastDigits != null)
                                            _buildParseInfo('Account', 'XX${transaction.accountLastDigits}'),
                                          if (transaction.balance != null)
                                            _buildParseInfo('Balance', '₹${_formatAmount(transaction.balance!)}'),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Re-parse button (if LLM is enabled)
                                  if (_llmEnabled) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _reparse(transaction),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Re-parse with LLM'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.purple,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildMetadataRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ThemeHelper.textPrimary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: ThemeHelper.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParseInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ThemeHelper.textPrimary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: ThemeHelper.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.decimalPattern('en_IN').format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }
}
