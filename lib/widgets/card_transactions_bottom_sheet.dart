import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class CardTransactionsBottomSheet extends StatefulWidget {
  final String cardIdentifier; // e.g., "1234", "XUPI", "Others"
  final String cardDisplayName; // e.g., "HDFC XX1234", "UPI", "Others"
  final List<Transaction> transactions;
  final VoidCallback onTransactionUpdated;

  const CardTransactionsBottomSheet({
    Key? key,
    required this.cardIdentifier,
    required this.cardDisplayName,
    required this.transactions,
    required this.onTransactionUpdated,
  }) : super(key: key);

  @override
  State<CardTransactionsBottomSheet> createState() => _CardTransactionsBottomSheetState();
}

class _CardTransactionsBottomSheetState extends State<CardTransactionsBottomSheet> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService.instance;
  late List<Transaction> _transactions;
  List<Category> _allCategories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _transactions = widget.transactions;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryService.getActiveCategories();
    setState(() {
      _allCategories = categories;
    });
  }

  Future<void> _refreshTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload all transactions and filter by card
      final allTransactions = await _transactionService.getAllTransactions(skipSync: true);
      final filteredTransactions = allTransactions.where((t) {
        // Handle different card types
        if (widget.cardIdentifier == 'XUPI') {
          return t.accountLastDigits == 'XUPI';
        } else if (widget.cardIdentifier == 'Others') {
          return t.accountLastDigits == null || t.accountLastDigits!.isEmpty;
        } else {
          return t.accountLastDigits == widget.cardIdentifier;
        }
      }).toList();

      setState(() {
        _transactions = filteredTransactions;
        _isLoading = false;
      });

      // Notify parent to refresh
      widget.onTransactionUpdated();
    } catch (e) {
      print('Error refreshing card transactions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editTransactionCategory(Transaction transaction) async {
    HapticFeedback.mediumImpact();

    final selectedCategory = await showDialog<Category>(
      context: context,
      builder: (context) {
        final isDark = ThemeHelper.isDark(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.category, color: AppTheme.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Change Category',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  transaction.merchant,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeHelper.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _allCategories.map((category) {
                        final isSelected = category.name == transaction.category;
                        return InkWell(
                          onTap: () => Navigator.pop(context, category),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? category.color.withOpacity(0.15)
                                  : (isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? category.color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: category.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: category.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? category.color
                                          : ThemeHelper.textPrimary(context),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: category.color,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedCategory != null && selectedCategory.name != transaction.category) {
      // Update the transaction's category
      final updatedTransaction = transaction.copyWith(category: selectedCategory.name);

      try {
        await _transactionService.updateTransaction(updatedTransaction, learnCategory: true);

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Changed to ${selectedCategory.name}'),
              backgroundColor: selectedCategory.color,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Refresh the list
        await Future.delayed(const Duration(milliseconds: 100));
        await _refreshTransactions();
      } catch (e) {
        print('Error updating transaction: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update category'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Color _getCardColor() {
    if (widget.cardIdentifier == 'XUPI') {
      return AppTheme.purple;
    } else if (widget.cardIdentifier == 'Others') {
      return AppTheme.textSecondary;
    } else {
      // Use different colors for different cards
      final colors = [AppTheme.coral, AppTheme.primaryPurple, AppTheme.successGreen, AppTheme.warningOrange];
      final index = widget.cardIdentifier.hashCode % colors.length;
      return colors[index.abs()];
    }
  }

  IconData _getCardIcon() {
    if (widget.cardIdentifier == 'XUPI') {
      return Icons.account_balance_wallet_rounded;
    } else if (widget.cardIdentifier == 'Others') {
      return Icons.payments_outlined;
    } else {
      return Icons.credit_card_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final isOled = ThemeHelper.isOled(context);
    final cardColor = _getCardColor();

    final totalAmount = _transactions.fold<double>(
      0.0,
      (sum, t) => sum + (t.amount ?? 0.0),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark
            ? (isOled ? AppTheme.backgroundOled : AppTheme.cardBackgroundDark)
            : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cardColor.withOpacity(0.15),
                  cardColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Card icon and name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCardIcon(),
                        color: cardColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cardDisplayName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: ThemeHelper.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_transactions.length} transaction${_transactions.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeHelper.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Total amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeHelper.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${NumberFormat('#,##,##0.00', 'en_IN').format(totalAmount)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cardColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transactions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.coral))
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: ThemeHelper.textSecondary(context),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions for this card',
                              style: TextStyle(
                                fontSize: 16,
                                color: ThemeHelper.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return _buildTransactionCard(transaction, cardColor);
                        },
                      ),
          ),

          // Footer with close button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? (isOled ? Colors.black : AppTheme.cardBackgroundDark)
                  : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? (isOled ? AppTheme.borderOled : Colors.white.withOpacity(0.1))
                      : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cardColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction, Color cardColor) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final isExpense = transaction.type == TransactionType.debit;

    return InkWell(
      onTap: () => _editTransactionCategory(transaction),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: ThemeHelper.cardDecoration(context),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isExpense ? AppTheme.coral : AppTheme.successGreen)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isExpense ? AppTheme.coral : AppTheme.successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchant.isEmpty
                        ? transaction.category
                        : transaction.merchant,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: ThemeHelper.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: ThemeHelper.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy • HH:mm').format(transaction.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.category,
                        size: 12,
                        color: ThemeHelper.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        transaction.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount and edit icon
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'} ${formatter.format(transaction.amount ?? 0.0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isExpense ? AppTheme.coral : AppTheme.successGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: AppTheme.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
