import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService.instance;
  late TabController _tabController;
  bool _isLoading = true;

  // Data
  Map<String, double> _monthlySpending = {};
  Map<String, double> _monthlyIncome = {};
  Map<String, double> _categoryTotals = {};
  Map<String, double> _merchantTotals = {};
  Map<String, double> _paymentMethodTotals = {};
  List<Transaction> _allTransactions = [];
  Map<String, Category> _categoryMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      final transactions = await _transactionService.getAllTransactions();
      _allTransactions = transactions;

      // Get data for last 6 months
      final now = DateTime.now();
      Map<String, double> monthlySpending = {};
      Map<String, double> monthlyIncome = {};

      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = DateFormat('MMM yy').format(month);

        final spending = await _transactionService.getMonthlyTotalSpending(
          month.year,
          month.month,
        );
        final income = await _transactionService.getMonthlyIncome(
          month.year,
          month.month,
        );

        monthlySpending[monthKey] = spending;
        monthlyIncome[monthKey] = income;
      }

      // Get category totals (current month)
      final categoryTotals = await _transactionService.getMonthlySpending();

      // Get top merchants
      final merchantTotals = <String, double>{};
      for (var transaction in transactions) {
        if (transaction.type == TransactionType.debit && transaction.merchant.isNotEmpty) {
          merchantTotals[transaction.merchant] =
              (merchantTotals[transaction.merchant] ?? 0) + (transaction.amount ?? 0);
        }
      }

      // Sort and take top 10
      final sortedMerchants = merchantTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top10Merchants = Map.fromEntries(sortedMerchants.take(10));

      // Get payment method totals
      final paymentMethodTotals = <String, double>{};
      final paymentMethodMonthly = <String, Map<String, double>>{};

      for (var transaction in transactions) {
        if (transaction.type == TransactionType.debit && transaction.accountLastDigits != null) {
          final method = transaction.accountLastDigits!;
          paymentMethodTotals[method] = (paymentMethodTotals[method] ?? 0) + (transaction.amount ?? 0);

          // Monthly breakdown
          final monthKey = DateFormat('MMM yy').format(transaction.timestamp);
          if (!paymentMethodMonthly.containsKey(method)) {
            paymentMethodMonthly[method] = {};
          }
          paymentMethodMonthly[method]![monthKey] =
              (paymentMethodMonthly[method]![monthKey] ?? 0) + (transaction.amount ?? 0);
        }
      }

      setState(() {
        _categoryMap = categoryMap;
        _monthlySpending = monthlySpending;
        _monthlyIncome = monthlyIncome;
        _categoryTotals = categoryTotals;
        _merchantTotals = top10Merchants;
        _paymentMethodTotals = paymentMethodTotals;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics data: $e');
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.coral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  tabs: const [
                    Tab(text: 'Trends'),
                    Tab(text: 'Categories'),
                    Tab(text: 'Income'),
                    Tab(text: 'Merchants'),
                    Tab(text: 'Payment'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
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
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.coral))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTrendsTab(),
                            _buildCategoriesTab(),
                            _buildIncomeTab(),
                            _buildMerchantsTab(),
                            _buildPaymentMethodsTab(),
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

  Widget _buildTrendsTab() {
    if (_monthlySpending.isEmpty) {
      return _buildEmptyState('No spending data yet');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Trends',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 6 months',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          _buildSpendingLineChart(),
          const SizedBox(height: 32),
          _buildMonthlyStats(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    if (_categoryTotals.isEmpty) {
      return _buildEmptyState('No category data yet');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This month',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          _buildCategoryBarChart(),
          const SizedBox(height: 24),
          _buildCategoryList(),
        ],
      ),
    );
  }

  Widget _buildIncomeTab() {
    if (_monthlyIncome.isEmpty) {
      return _buildEmptyState('No income data yet');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Income vs Expense',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 6 months',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          _buildIncomeExpenseChart(),
          const SizedBox(height: 32),
          _buildIncomeExpenseStats(),
        ],
      ),
    );
  }

  Widget _buildMerchantsTab() {
    if (_merchantTotals.isEmpty) {
      return _buildEmptyState('No merchant data yet');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Merchants',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Where you spend most',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          _buildMerchantBarChart(),
          const SizedBox(height: 24),
          _buildMerchantList(),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsTab() {
    if (_paymentMethodTotals.isEmpty) {
      return _buildEmptyState('No payment method data yet');
    }

    // Separate UPI and Cards
    double upiTotal = _paymentMethodTotals['XUPI'] ?? 0;
    double cardsTotal = _paymentMethodTotals.entries
        .where((e) => e.key != 'XUPI')
        .fold(0.0, (sum, entry) => sum + entry.value);
    final cardMethods = Map.fromEntries(
        _paymentMethodTotals.entries.where((e) => e.key != 'XUPI'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How you spend your money',
            style: TextStyle(
              fontSize: 14,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),

          // UPI vs Cards Overview
          _buildPaymentMethodStats(upiTotal, cardsTotal),
          const SizedBox(height: 24),

          // UPI vs Cards Pie Chart
          if (upiTotal > 0 || cardsTotal > 0) ...[
            _buildPaymentMethodPieChart(upiTotal, cardsTotal),
            const SizedBox(height: 32),
          ],

          // Individual Cards Breakdown
          if (cardMethods.isNotEmpty) ...[
            Text(
              'Card Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ThemeHelper.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            _buildCardBreakdownChart(cardMethods),
            const SizedBox(height: 24),
          ],

          // Category breakdown per payment method
          Text(
            'Spending by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodCategoryBreakdown(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: ThemeHelper.textSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: ThemeHelper.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingLineChart() {
    final isDark = ThemeHelper.isDark(context);
    final spots = _monthlySpending.entries.toList().asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final maxY = _monthlySpending.values.isEmpty
        ? 100.0
        : _monthlySpending.values.reduce((a, b) => a > b ? a : b);

    // Ensure horizontal interval is never 0
    final horizontalInterval = maxY > 0 ? maxY / 5 : 20.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: horizontalInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: ThemeHelper.surfaceColor(context),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _monthlySpending.length) {
                    final month = _monthlySpending.keys.toList()[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        month.split(' ')[0],
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: horizontalInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatShortAmount(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: ThemeHelper.textSecondary(context),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_monthlySpending.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppTheme.coral, AppTheme.purple],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: ThemeHelper.cardColor(context),
                    strokeWidth: 2,
                    strokeColor: AppTheme.coral,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.coral.withOpacity(0.3),
                    AppTheme.coral.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final totalSpending = _monthlySpending.values.reduce((a, b) => a + b);
    final avgSpending = totalSpending / _monthlySpending.length;
    final currentMonth = _monthlySpending.values.last;
    final previousMonth = _monthlySpending.values.toList()[_monthlySpending.length - 2];
    final change = previousMonth > 0 ? ((currentMonth - previousMonth) / previousMonth) * 100 : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Average',
            '₹${_formatAmount(avgSpending)}',
            Icons.show_chart,
            AppTheme.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Month',
            '₹${_formatAmount(currentMonth)}',
            change >= 0 ? Icons.trending_up : Icons.trending_down,
            change >= 0 ? AppTheme.coral : AppTheme.successGreen,
            subtitle: '${change.abs().toStringAsFixed(1)}% ${change >= 0 ? 'up' : 'down'}',
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBarChart() {
    final isDark = ThemeHelper.isDark(context);
    final sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: sortedCategories.first.value * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedCategories.length) {
                    final categoryName = sortedCategories[index].key;
                    final category = _getCategoryByName(categoryName);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Icon(
                        category.icon,
                        size: 16,
                        color: category.color,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: sortedCategories.asMap().entries.map((entry) {
            final category = _getCategoryByName(entry.value.key);
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  gradient: LinearGradient(
                    colors: [category.color, category.color.withOpacity(0.7)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final isDark = ThemeHelper.isDark(context);
    final sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = _categoryTotals.values.reduce((a, b) => a + b);

    return Column(
      children: sortedCategories.map((entry) {
        final category = _getCategoryByName(entry.key);
        final percentage = (entry.value / total) * 100;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThemeHelper.cardColor(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}% of spending',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeHelper.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${_formatAmount(entry.value)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIncomeExpenseChart() {
    final isDark = ThemeHelper.isDark(context);
    final months = _monthlyIncome.keys.toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxIncomeExpense() * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < months.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        months[index].split(' ')[0],
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: months.asMap().entries.map((entry) {
            final month = entry.value;
            final income = _monthlyIncome[month] ?? 0;
            final spending = _monthlySpending[month] ?? 0;

            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: income,
                  color: AppTheme.successGreen,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: spending,
                  color: AppTheme.coral,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              barsSpace: 4,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseStats() {
    final totalIncome = _monthlyIncome.values.reduce((a, b) => a + b);
    final totalSpending = _monthlySpending.values.reduce((a, b) => a + b);
    final savings = totalIncome - totalSpending;
    final savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Income',
                '₹${_formatAmount(totalIncome)}',
                Icons.arrow_downward,
                AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Spending',
                '₹${_formatAmount(totalSpending)}',
                Icons.arrow_upward,
                AppTheme.coral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Net Savings',
          '₹${_formatAmount(savings)}',
          Icons.savings,
          savings >= 0 ? AppTheme.successGreen : AppTheme.coral,
          subtitle: '${savingsRate.toStringAsFixed(1)}% savings rate',
        ),
      ],
    );
  }

  Widget _buildMerchantBarChart() {
    final isDark = ThemeHelper.isDark(context);
    final sortedMerchants = _merchantTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: sortedMerchants.first.value * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedMerchants.length) {
                    final merchant = sortedMerchants[index].key;
                    final words = merchant.split(' ');
                    final displayText = words.length > 1 ? words[0] : merchant;

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          displayText.length > 8 ? '${displayText.substring(0, 8)}...' : displayText,
                          style: TextStyle(
                            fontSize: 9,
                            color: ThemeHelper.textSecondary(context),
                          ),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: sortedMerchants.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  gradient: const LinearGradient(
                    colors: [AppTheme.purple, AppTheme.deepBlue],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMerchantList() {
    final isDark = ThemeHelper.isDark(context);
    final sortedMerchants = _merchantTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = _merchantTotals.values.reduce((a, b) => a + b);

    return Column(
      children: sortedMerchants.asMap().entries.map((entry) {
        final index = entry.key;
        final merchant = entry.value;
        final percentage = (merchant.value / total) * 100;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThemeHelper.cardColor(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.purple.withOpacity(0.8),
                      AppTheme.deepBlue.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: ThemeHelper.textPrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}% of spending',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeHelper.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${_formatAmount(merchant.value)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final isDark = ThemeHelper.isDark(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.textPrimary(context),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: ThemeHelper.textSecondary(context),
              ),
            ),
          ] else ...[
            const SizedBox(height: 19),
          ],
        ],
      ),
    );
  }

  double _getMaxIncomeExpense() {
    double max = 0;
    _monthlyIncome.forEach((key, value) {
      if (value > max) max = value;
    });
    _monthlySpending.forEach((key, value) {
      if (value > max) max = value;
    });
    return max;
  }

  Widget _buildPaymentMethodStats(double upiTotal, double cardsTotal) {
    final total = upiTotal + cardsTotal;
    final upiPercentage = total > 0 ? (upiTotal / total) * 100 : 0;
    final cardsPercentage = total > 0 ? (cardsTotal / total) * 100 : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'UPI',
            '₹${_formatAmount(upiTotal)}',
            Icons.account_balance_wallet,
            AppTheme.coral,
            subtitle: '${upiPercentage.toStringAsFixed(1)}% of total',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Cards',
            '₹${_formatAmount(cardsTotal)}',
            Icons.credit_card,
            Colors.blue,
            subtitle: '${cardsPercentage.toStringAsFixed(1)}% of total',
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodPieChart(double upiTotal, double cardsTotal) {
    final isDark = ThemeHelper.isDark(context);
    final total = upiTotal + cardsTotal;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          sections: [
            if (upiTotal > 0)
              PieChartSectionData(
                color: AppTheme.coral,
                value: upiTotal,
                title: '${((upiTotal / total) * 100).toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            if (cardsTotal > 0)
              PieChartSectionData(
                color: Colors.blue,
                value: cardsTotal,
                title: '${((cardsTotal / total) * 100).toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBreakdownChart(Map<String, double> cardMethods) {
    final isDark = ThemeHelper.isDark(context);
    final sortedCards = cardMethods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: sortedCards.map((entry) {
          final cardNumber = entry.key;
          final amount = entry.value;
          final total = cardMethods.values.reduce((a, b) => a + b);
          final percentage = (amount / total) * 100;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.credit_card, size: 20, color: AppTheme.coral),
                const SizedBox(width: 12),
                Text(
                  '****$cardNumber',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${_formatAmount(amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${percentage.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeHelper.textSecondary(context),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentMethodCategoryBreakdown() {
    final isDark = ThemeHelper.isDark(context);

    // Calculate category totals per payment method
    final Map<String, Map<String, double>> methodCategoryTotals = {};

    for (var transaction in _allTransactions) {
      if (transaction.type == TransactionType.debit && transaction.accountLastDigits != null) {
        final method = transaction.accountLastDigits!;
        final category = transaction.category;
        final amount = transaction.amount ?? 0;

        if (!methodCategoryTotals.containsKey(method)) {
          methodCategoryTotals[method] = {};
        }

        methodCategoryTotals[method]![category] =
            (methodCategoryTotals[method]![category] ?? 0) + amount;
      }
    }

    // Get UPI and top 2 cards
    final displayMethods = <String>[];
    if (methodCategoryTotals.containsKey('XUPI')) {
      displayMethods.add('XUPI');
    }

    final cardMethods = methodCategoryTotals.entries
        .where((e) => e.key != 'XUPI')
        .toList()
      ..sort((a, b) => b.value.values.reduce((x, y) => x + y)
          .compareTo(a.value.values.reduce((x, y) => x + y)));

    displayMethods.addAll(cardMethods.take(2).map((e) => e.key));

    return Column(
      children: displayMethods.map((method) {
        final categoryTotals = methodCategoryTotals[method]!;
        final sortedCategories = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCategories = sortedCategories.take(5).toList();
        final total = categoryTotals.values.reduce((a, b) => a + b);

        final methodLabel = method == 'XUPI' ? 'UPI' : 'Card ****$method';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    method == 'XUPI' ? Icons.account_balance_wallet : Icons.credit_card,
                    size: 20,
                    color: method == 'XUPI' ? AppTheme.coral : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    methodLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.textPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${_formatAmount(total)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...topCategories.map((entry) {
                final categoryName = entry.key;
                final amount = entry.value;
                final percentage = (amount / total) * 100;
                final category = _getCategoryByName(categoryName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(category.icon, size: 16, color: category.color),
                      const SizedBox(width: 8),
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 13,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${_formatAmount(amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${percentage.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatShortAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(0)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
