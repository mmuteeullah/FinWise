import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService.instance;
  bool _isLoading = true;
  double _totalSpending = 0.0;
  double _totalIncome = 0.0;
  double? _balance;
  Map<String, double> _categoryTotals = {};
  List<Transaction> _recentTransactions = [];
  Map<String, Category> _categoryMap = {};

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
      // Load dynamic categories first
      final categories = await _categoryService.getActiveCategories();
      final categoryMap = <String, Category>{};
      for (var category in categories) {
        categoryMap[category.name] = category;
      }

      final spending = await _transactionService.getMonthlyTotalSpending();
      final income = await _transactionService.getMonthlyIncome();
      final balance = await _transactionService.getLatestBalance();
      final categoryTotals = await _transactionService.getMonthlySpending();
      final transactions = await _transactionService.getAllTransactions();

      setState(() {
        _categoryMap = categoryMap;
        _totalSpending = spending;
        _totalIncome = income;
        _balance = balance;
        _categoryTotals = categoryTotals;
        _recentTransactions = transactions.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to get category by name from dynamic categories
  Category _getCategoryByName(String name) {
    if (_categoryMap.containsKey(name)) {
      return _categoryMap[name]!;
    }
    // Fallback for edge cases
    final oldCategory = Categories.getByName(name);
    return Category(
      id: name,
      name: name,
      isDefault: false,
      isActive: true,
      iconEmoji: null,
      colorHex: oldCategory.color.value.toRadixString(16).padLeft(8, '0').substring(2),
      createdAt: DateTime.now(),
    );
  }

  /// Public method to refresh dashboard data (called from main screen when tab changes)
  void refresh() {
    _loadData();
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
            : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildBalanceHeader(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildIncomeSpendCards(),
                          const SizedBox(height: AppSpacing.lg),
                          if (_categoryTotals.isNotEmpty) ...[
                            _buildCategoryBreakdown(),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _buildSectionHeader('Recent Transactions'),
                          const SizedBox(height: AppSpacing.md),
                          _buildRecentTransactions(),
                          const SizedBox(height: AppSpacing.xl),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Analytics',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = _balance ?? (_totalIncome - _totalSpending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Balance',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '₹${_formatAmount(balance)}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimary,
            letterSpacing: -1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeSpendCards() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Income Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.darkGlassmorphicCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha((0.1 * 255).toInt())
                        : AppTheme.backgroundLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Income',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatAmount(_totalIncome)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Spend Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.darkGlassmorphicCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha((0.1 * 255).toInt())
                        : AppTheme.backgroundLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Spend',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatAmount(_totalSpending)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: isDark
          ? AppDecorations.darkGlassmorphicCard()
          : AppDecorations.elevatedCard(isDark: isDark),
      child: Column(
        children: [
          // Donut Chart
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 70,
                    sections: _categoryTotals.entries.map((entry) {
                      final category = _getCategoryByName(entry.key);

                      return PieChartSectionData(
                        color: category.color,
                        value: entry.value,
                        title: '',
                        radius: 35,
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.backgroundDark : Colors.white,
                          width: 2,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Center text
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_totalSpending > 0 ? 100 : 0).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Spend',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category Legend
          ..._categoryTotals.entries.map((entry) {
            final category = _getCategoryByName(entry.key);
            final percentage = (_totalSpending > 0 ? (entry.value / _totalSpending) * 100 : 0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Color indicator dot
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category name
                  Expanded(
                    child: Text(
                      category.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Amount and percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_formatAmount(entry.value)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: AppDecorations.elevatedCard(isDark: isDark),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: AppDecorations.elevatedCard(isDark: isDark),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentTransactions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 68,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final transaction = _recentTransactions[index];
          final category = _getCategoryByName(transaction.category);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: category.color.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 24,
              ),
            ),
            title: Text(
              transaction.merchant,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _formatDate(transaction.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
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
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
