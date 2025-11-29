import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class ManageTransactionsScreen extends StatefulWidget {
  const ManageTransactionsScreen({super.key});

  @override
  State<ManageTransactionsScreen> createState() => _ManageTransactionsScreenState();
}

class _ManageTransactionsScreenState extends State<ManageTransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  bool _isProcessing = false;
  Map<String, int> _monthlyTransactionCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyStats();
  }

  Future<void> _loadMonthlyStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await _transactionService.getAllTransactions();
      final Map<String, int> counts = {};

      for (final transaction in transactions) {
        final monthKey = DateFormat('MMM yyyy').format(transaction.timestamp);
        counts[monthKey] = (counts[monthKey] ?? 0) + 1;
      }

      setState(() {
        _monthlyTransactionCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearSpecificMonth() async {
    if (_monthlyTransactionCounts.isEmpty) {
      _showSnackBar('No transactions to clear', isError: true);
      return;
    }

    final selectedMonth = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _monthlyTransactionCounts.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                subtitle: Text('${entry.value} transactions'),
                onTap: () => Navigator.pop(context, entry.key),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedMonth == null) return;

    final confirm = await _showConfirmDialog(
      'Clear Month',
      'Delete all transactions from $selectedMonth?',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() {
        _isProcessing = true;
      });

      try {
        // Parse the month string (e.g., "Jan 2024") to year and month
        final parts = selectedMonth.split(' ');
        final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = monthNames.indexOf(parts[0]) + 1;
        final year = int.parse(parts[1]);

        await _transactionService.deleteTransactionsByMonth(year, month);
        await _loadMonthlyStats();
        _showSnackBar('Cleared $selectedMonth transactions');
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _clearAllTransactions() async {
    final confirm = await _showConfirmDialog(
      'Clear All Transactions',
      'This will permanently delete ALL your transaction data. This action cannot be undone!',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() {
        _isProcessing = true;
      });

      try {
        await _transactionService.deleteAllTransactions();
        await _loadMonthlyStats();
        _showSnackBar('All transactions cleared');
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content, {bool isDestructive = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppTheme.errorRed : AppTheme.coral,
            ),
            child: Text(isDestructive ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.whiteBg,
      appBar: AppBar(
        title: const Text('Manage Transactions'),
        backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.whiteBg,
        foregroundColor: ThemeHelper.textPrimary(context),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.coral))
          : _isProcessing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.coral),
                      SizedBox(height: 16),
                      Text('Processing...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      _buildDataSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalTransactions = _monthlyTransactionCounts.values.fold(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.glassBlueGradient
            : const LinearGradient(
                colors: [AppTheme.purple, AppTheme.deepBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Transactions',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalTransactions.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Data',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.calendar_month_rounded,
          title: 'Clear Specific Month',
          subtitle: 'Delete transactions from a selected month',
          color: AppTheme.coral,
          onTap: _clearSpecificMonth,
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.delete_sweep_rounded,
          title: 'Clear All Transactions',
          subtitle: 'Permanently delete all transaction data',
          color: AppTheme.errorRed,
          onTap: _clearAllTransactions,
          isDangerous: true,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: isDangerous
            ? Border.all(color: AppTheme.errorRed.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: ThemeHelper.textSecondary(context),
        ),
        onTap: onTap,
      ),
    );
  }
}
