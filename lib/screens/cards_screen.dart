import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import 'package:intl/intl.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => CardsScreenState();
}

class CardsScreenState extends State<CardsScreen> {
  final TransactionService _transactionService = TransactionService();
  bool _isLoading = true;
  Map<String, int> _uniqueAccounts = {};
  String? _selectedCard;
  List<Transaction> _cardTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _transactionService.getUniqueAccounts();
      setState(() {
        _uniqueAccounts = accounts;
        _isLoading = false;
        // Auto-select first card if available
        if (_uniqueAccounts.isNotEmpty) {
          _selectedCard = _uniqueAccounts.keys.first;
          _loadCardTransactions(_selectedCard!);
        }
      });
    } catch (e) {
      print('Error loading cards: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCardTransactions(String cardNumber) async {
    final allTransactions = await _transactionService.getAllTransactions();
    setState(() {
      _cardTransactions = allTransactions
          .where((t) => t.accountLastDigits == cardNumber)
          .toList();
    });
  }

  void refresh() {
    _loadCards();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: isDark
            ? BoxDecoration(
                gradient: ThemeHelper.isOled(context)
                    ? AppTheme.oledBackgroundGradient
                    : AppTheme.darkBackgroundGradient,
              )
            : BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(isDark),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (_uniqueAccounts.isEmpty)
                          _buildEmptyState(isDark)
                        else ...[
                          _buildCardsGrid(isDark),
                          const SizedBox(height: AppSpacing.lg),
                          if (_selectedCard != null) ...[
                            _buildSectionHeader('Transactions', isDark),
                            const SizedBox(height: AppSpacing.md),
                            _buildTransactionsList(isDark),
                          ],
                        ],
                        const SizedBox(height: AppSpacing.xl),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'My Cards',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: isDark
          ? AppDecorations.darkGlassmorphicCard()
          : AppDecorations.elevatedCard(isDark: isDark),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.credit_card_off_rounded,
              size: 64,
              color: isDark ? AppTheme.textSecondaryDark : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Cards Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transactions with card numbers will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: _uniqueAccounts.length,
      itemBuilder: (context, index) {
        final entry = _uniqueAccounts.entries.elementAt(index);
        final cardNumber = entry.key;
        final count = entry.value;
        final isSelected = _selectedCard == cardNumber;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCard = cardNumber;
            });
            _loadCardTransactions(cardNumber);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? AppTheme.primaryGradient
                  : LinearGradient(
                      colors: [
                        AppTheme.cardBackgroundDark.withAlpha((0.3 * 255).toInt()),
                        AppTheme.cardBackgroundDark.withAlpha((0.15 * 255).toInt()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryPurple
                    : Colors.white.withAlpha((0.08 * 255).toInt()),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.3 * 255).toInt()),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      color: isSelected ? Colors.white : AppTheme.textSecondaryDark,
                      size: 24,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withAlpha((0.2 * 255).toInt())
                            : Colors.white.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count txns',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '****  $cardNumber',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Card',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withAlpha((0.7 * 255).toInt())
                            : AppTheme.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTransactionsList(bool isDark) {
    if (_cardTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: isDark
            ? AppDecorations.darkGlassmorphicCard()
            : AppDecorations.elevatedCard(isDark: isDark),
        child: Center(
          child: Text(
            'No transactions for this card',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: isDark
          ? AppDecorations.darkGlassmorphicCard()
          : AppDecorations.elevatedCard(isDark: isDark),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _cardTransactions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 68,
          color: isDark
              ? Colors.white.withAlpha((0.1 * 255).toInt())
              : Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final transaction = _cardTransactions[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            title: Text(
              transaction.merchant,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              _formatDate(transaction.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              ),
            ),
            trailing: Text(
              '${transaction.type == TransactionType.debit ? '-' : '+'}₹${_formatAmount(transaction.amount ?? 0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: transaction.type == TransactionType.debit
                    ? AppTheme.errorRed
                    : AppTheme.successGreen,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.decimalPattern('en_IN').format(amount);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today, ${DateFormat('HH:mm').format(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday, ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}
