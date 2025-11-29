import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../widgets/credit_card_carousel.dart';
import '../widgets/floating_decorations.dart';
import '../widgets/category_transactions_bottom_sheet.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../main.dart';
import 'transactions_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService.instance;
  double _scrollOffset = 0.0;
  List<Transaction> _recentTransactions = [];
  List<Transaction> _allMonthTransactions = []; // All transactions for selected month
  Map<String, double> _categoryTotals = {};
  Map<String, Category> _categoryMap = {}; // Dynamic categories by name
  double _totalSpending = 0.0;
  double _totalIncome = 0.0;
  bool _isLoading = true;
  int _touchedIndex = -1;
  DateTime _selectedMonth = DateTime.now(); // Selected month for filtering

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load categories first
      final categories = await _categoryService.getActiveCategories();
      final categoryMap = <String, Category>{};
      for (var category in categories) {
        categoryMap[category.name] = category;
      }

      // Start SMS sync in background (non-blocking)
      _transactionService.syncFromiOS().then((syncStats) {
        // Show toast notification if there were duplicates
        if (mounted && syncStats['duplicates']! > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${syncStats['new']} new transaction(s), ${syncStats['duplicates']} duplicate(s) skipped',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: syncStats['duplicates']! > 0 ? Colors.orange : Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh data after sync
          _refreshDataQuietly();
        }
      }).catchError((e) {
        print('Background sync error: $e');
      });

      // Load cached data immediately (parallel queries)
      final results = await Future.wait([
        _transactionService.getAllTransactions(skipSync: true),
        _transactionService.getMonthlyTotalSpending(_selectedMonth.year, _selectedMonth.month),
        _transactionService.getMonthlyIncome(_selectedMonth.year, _selectedMonth.month),
        _transactionService.getMonthlySpending(_selectedMonth.year, _selectedMonth.month),
      ]);

      // Filter transactions for selected month
      final allTransactions = results[0] as List<Transaction>;
      final monthTransactions = allTransactions.where((t) =>
        t.timestamp.year == _selectedMonth.year &&
        t.timestamp.month == _selectedMonth.month
      ).toList();

      setState(() {
        _categoryMap = categoryMap;
        _allMonthTransactions = monthTransactions; // Store all month transactions
        _recentTransactions = monthTransactions.take(3).toList(); // Only 3 for recent activity
        _totalSpending = results[1] as double;
        _totalIncome = results[2] as double;
        _categoryTotals = results[3] as Map<String, double>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDataQuietly() async {
    // Refresh data without showing loading state
    try {
      // Reload categories in case new ones were added
      final categories = await _categoryService.getActiveCategories();
      final categoryMap = <String, Category>{};
      for (var category in categories) {
        categoryMap[category.name] = category;
      }

      final results = await Future.wait([
        _transactionService.getAllTransactions(skipSync: true),
        _transactionService.getMonthlyTotalSpending(_selectedMonth.year, _selectedMonth.month),
        _transactionService.getMonthlyIncome(_selectedMonth.year, _selectedMonth.month),
        _transactionService.getMonthlySpending(_selectedMonth.year, _selectedMonth.month),
      ]);

      // Filter transactions for selected month
      final allTransactions = results[0] as List<Transaction>;
      final monthTransactions = allTransactions.where((t) =>
        t.timestamp.year == _selectedMonth.year &&
        t.timestamp.month == _selectedMonth.month
      ).toList();

      setState(() {
        _categoryMap = categoryMap;
        _allMonthTransactions = monthTransactions; // Store all month transactions
        _recentTransactions = monthTransactions.take(3).toList(); // Only 3 for recent activity
        _totalSpending = results[1] as double;
        _totalIncome = results[2] as double;
        _categoryTotals = results[3] as Map<String, double>;
      });
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  void refresh() {
    _loadData();
  }

  /// Get category by name from dynamic categories, fallback to create temp category if not found
  Category _getCategoryByName(String name) {
    if (_categoryMap.containsKey(name)) {
      return _categoryMap[name]!;
    }

    // Create a temporary Category object for unknown categories
    // This handles edge cases where category hasn't been loaded yet
    final oldCategory = Categories.getByName(name);
    return Category(
      id: name,
      name: name,
      isDefault: false,
      isActive: true,
      iconEmoji: null, // Old categories don't have emojis
      colorHex: oldCategory.color.value.toRadixString(16).padLeft(8, '0').substring(2),
      createdAt: DateTime.now(),
    );
  }

  Future<void> _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Month',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.purple,
              onPrimary: Colors.white,
              surface: AppTheme.cardBackgroundDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadData();
    }
  }

  double _getScale() {
    // Scale effect based on scroll (similar to Bank UI)
    return 1 - (_scrollOffset / 5000).clamp(0.0, 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ThemeHelper.backgroundGradient(context),
        ),
        child: Stack(
          children: [
            // Floating decorative circles
            FloatingDecorations(scrollOffset: _scrollOffset),

            // Main content
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.coral,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
              // Card Section with SliverAppBar
              SliverAppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                expandedHeight: 540,
                pinned: false,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.none,
                  background: Transform.scale(
                    scale: _getScale(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernHeader(),
                          const SizedBox(height: 24),
                          const CreditCardCarousel(),
                          const SizedBox(height: 16),
                          _buildModernIncomeSpendCards(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Spacer between cards and content
              SliverToBoxAdapter(
                child: const SizedBox(height: 8),
              ),

              // Bottom Section
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? scaffoldBg : AppTheme.whiteBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        if (_categoryTotals.isNotEmpty) ...[
                          _buildCategoryDonutChart(),
                          const SizedBox(height: 32),
                        ],
                        // Quick Insights Cards
                        _buildQuickInsights(),
                        const SizedBox(height: 24),

                        // Weekly Trend Chart
                        _buildWeeklyTrend(),
                        const SizedBox(height: 24),

                        // Quick Actions
                        _buildQuickActions(),
                        const SizedBox(height: 24),

                        // Mini Recent Activity
                        _buildMiniRecentActivity(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildModernHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nightlight_round;
    }

    final monthYear = DateFormat('MMMM yyyy').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
                          _selectedMonth.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  greetingIcon,
                  color: Colors.amber[300],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Financial Overview',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showMonthPicker,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrentMonth
                  ? Colors.white.withOpacity(0.15)
                  : AppTheme.coral.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCurrentMonth
                    ? Colors.white.withOpacity(0.3)
                    : AppTheme.coral.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: isCurrentMonth
                      ? Colors.white.withOpacity(0.9)
                      : AppTheme.coral,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    monthYear,
                    style: TextStyle(
                      color: isCurrentMonth
                        ? Colors.white.withOpacity(0.9)
                        : AppTheme.coral,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: isCurrentMonth
                      ? Colors.white.withOpacity(0.7)
                      : AppTheme.coral,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernIncomeSpendCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Income Card with Gradient
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.successGreen.withOpacity(0.2),
                    AppTheme.successGreen.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successGreen.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.trending_down_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Income',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1200),
                    tween: Tween(begin: 0.0, end: _totalIncome),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '₹${_formatAmount(value)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Spend Card with Gradient
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.coral.withOpacity(0.2),
                    AppTheme.coral.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.coral.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.coral.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.coral.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spending',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1200),
                    tween: Tween(begin: 0.0, end: _totalSpending),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '₹${_formatAmount(value)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDonutChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled = ThemeHelper.isOled(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ThemeHelper.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                size: 20,
                color: AppTheme.purple,
              ),
              const SizedBox(width: 8),
              Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Donut Chart
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 70,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;

                          if (event is FlTapUpEvent && _touchedIndex >= 0) {
                            HapticFeedback.lightImpact();
                            final category = _categoryTotals.keys.elementAt(_touchedIndex);
                            _navigateToTransactionsWithFilter(category);
                          }
                        });
                      },
                    ),
                    sections: _categoryTotals.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final categoryEntry = entry.value;
                      final category = _getCategoryByName(categoryEntry.key);
                      final isTouched = index == _touchedIndex;
                      final radius = isTouched ? 48.0 : 42.0;
                      final percentage = (_totalSpending > 0 ? (categoryEntry.value / _totalSpending) * 100 : 0);

                      return PieChartSectionData(
                        color: category.color,
                        value: categoryEntry.value,
                        title: isTouched ? '${percentage.toStringAsFixed(0)}%' : '',
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        radius: radius,
                        borderSide: BorderSide(
                          color: isDark
                              ? (isOled ? Colors.black : AppTheme.cardBackgroundDark)
                              : Colors.white,
                          width: isTouched ? 3 : 2,
                        ),
                        badgeWidget: isTouched ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: category.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: category.color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            category.icon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ) : null,
                        badgePositionPercentageOffset: 1.2,
                      );
                    }).toList(),
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 300),
                  swapAnimationCurve: Curves.easeInOutCubic,
                ),
                // Center content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${_formatAmount(_totalSpending)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color: ThemeHelper.textPrimary(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.purple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Total Spending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.purple,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Category Legend with improved design
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? (isOled ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.05))
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? (isOled ? AppTheme.borderOled : Colors.white.withOpacity(0.1))
                    : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Column(
              children: _categoryTotals.entries.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final categoryEntry = entry.value;
                final category = _getCategoryByName(categoryEntry.key);
                final percentage = (_totalSpending > 0 ? (categoryEntry.value / _totalSpending) * 100 : 0);
                final isLast = index == _categoryTotals.length - 1;

                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _navigateToTransactionsWithFilter(categoryEntry.key);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            // Category icon with color
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: category.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: category.color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                category.icon,
                                color: category.color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Category name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeHelper.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(category.color),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Percentage and amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: category.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: category.color,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_formatAmount(categoryEntry.value)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeHelper.textPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? (isOled ? AppTheme.borderOled : Colors.white.withOpacity(0.05))
                            : Colors.grey[200],
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    final isExpense = transaction.type == TransactionType.debit;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to transaction details or transactions screen
        final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
        if (mainScreenState != null) {
          mainScreenState.switchToTab(1); // Switch to Transactions tab
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: ThemeHelper.cardDecoration(context),
        child: Row(
          children: [
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
                      fontSize: 14,
                      color: isDark ? AppTheme.textPrimaryDark : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(transaction.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textSecondaryDark : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'} ${formatter.format(transaction.amount ?? 0.0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isExpense ? AppTheme.coral : AppTheme.successGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInsights() {
    if (_recentTransactions.isEmpty) return const SizedBox.shrink();

    final biggestExpense = _recentTransactions
        .where((t) => t.type == TransactionType.debit)
        .reduce((a, b) => (a.amount ?? 0) > (b.amount ?? 0) ? a : b);

    final mostFrequentCategory = _categoryTotals.entries.isNotEmpty
        ? _categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'N/A';

    final avgDaily = _totalSpending / DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Insights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              _buildInsightCard(
                icon: Icons.trending_up,
                title: 'Biggest Expense',
                value: '₹${_formatAmount(biggestExpense.amount ?? 0)}',
                subtitle: biggestExpense.merchant,
                color: AppTheme.coral,
              ),
              _buildInsightCard(
                icon: Icons.category,
                title: 'Most Frequent',
                value: mostFrequentCategory,
                subtitle: '${_categoryTotals[mostFrequentCategory]?.toStringAsFixed(0) ?? 0} spent',
                color: AppTheme.primaryPurple,
              ),
              _buildInsightCard(
                icon: Icons.calendar_today,
                title: 'Daily Average',
                value: '₹${_formatAmount(avgDaily)}',
                subtitle: 'This month',
                color: AppTheme.secondaryBlue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final isDark = ThemeHelper.isDark(context);
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.15 : 0.12),
            color.withOpacity(isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.4 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.textSecondary(context),
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: ThemeHelper.textSecondary(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrend() {
    // Determine the reference date for the 7-day period
    // For current month: use today
    // For past months: use last day of that month
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final referenceDate = isCurrentMonth
      ? now
      : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0); // Last day of selected month

    // Calculate spending for last 7 days from reference date
    final weeklyData = List.generate(7, (index) {
      final date = referenceDate.subtract(Duration(days: 6 - index));
      final dayTransactions = _allMonthTransactions.where((t) =>
        t.type == TransactionType.debit &&
        t.timestamp.year == date.year &&
        t.timestamp.month == date.month &&
        t.timestamp.day == date.day
      );
      return dayTransactions.fold(0.0, (sum, t) => sum + (t.amount ?? 0));
    });

    final maxSpending = weeklyData.isNotEmpty ? weeklyData.reduce((a, b) => a > b ? a : b) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Spending',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: ThemeHelper.cardDecoration(context),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCurrentMonth ? 'Last 7 Days' : 'Week of ${DateFormat('MMM d').format(referenceDate.subtract(const Duration(days: 6)))}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.textSecondary(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${_formatAmount(weeklyData.reduce((a, b) => a + b))}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.coral,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final date = referenceDate.subtract(Duration(days: 6 - index));
                    final height = maxSpending > 0 ? (weeklyData[index] / maxSpending) * 100 : 5.0;
                    final isToday = isCurrentMonth && date.day == now.day && date.month == now.month;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (height > 30)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '₹${(weeklyData[index] / 1000).toStringAsFixed(0)}k',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.coral,
                                  ),
                                ),
                              ),
                            Container(
                              width: double.infinity,
                              height: height < 10 ? 10 : height,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppTheme.coral,
                                    AppTheme.coral.withOpacity(0.5),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.coral.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              DateFormat('E').format(date).substring(0, 1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                color: isToday
                                    ? AppTheme.coral
                                    : ThemeHelper.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionButton(
              icon: Icons.list_alt_rounded,
              label: 'Transactions',
              onTap: () {
                final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                if (mainScreenState != null) {
                  mainScreenState.switchToTab(1);
                }
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Budget',
              onTap: () {
                final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                if (mainScreenState != null) {
                  mainScreenState.switchToTab(2);
                }
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Insights',
              onTap: () {
                final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                if (mainScreenState != null) {
                  mainScreenState.switchToTab(3);
                }
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              onTap: () {
                final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                if (mainScreenState != null) {
                  mainScreenState.switchToTab(4);
                }
              },
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.purple.withOpacity(0.15),
              AppTheme.deepBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.purple.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.purple.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.purple,
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.textPrimary(context),
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniRecentActivity() {
    final recentThree = _recentTransactions.take(3).toList();
    final isDark = ThemeHelper.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                if (mainScreenState != null) {
                  mainScreenState.switchToTab(1);
                }
              },
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: AppTheme.coral,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.coral,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (recentThree.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
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
          ...recentThree.asMap().entries.map((entry) {
            final index = entry.key;
            final transaction = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: _buildTransactionItem(transaction),
            );
          }).toList(),
      ],
    );
  }

  void _navigateToTransactionsWithFilter(String category) async {
    HapticFeedback.lightImpact();

    // Get transactions for this category
    final categoryTransactions = _allMonthTransactions
        .where((t) => t.category == category)
        .toList();

    // Show bottom sheet with category transactions
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryTransactionsBottomSheet(
        categoryName: category,
        transactions: categoryTransactions,
        onTransactionUpdated: () {
          // Refresh Dashboard data when transactions are updated
          _loadData();
        },
      ),
    );

    // If user tapped "View All in Transactions", navigate to Transactions screen with filter
    if (result == true) {
      final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
      if (mainScreenState != null) {
        mainScreenState.switchToTab(1); // Switch to Transactions tab

        // Wait for tab switch animation to complete, then apply filter
        Future.delayed(const Duration(milliseconds: 100), () {
          final transactionsKey = (mainScreenState as dynamic)._transactionsKey as GlobalKey<TransactionsScreenState>;
          transactionsKey.currentState?.setCategoryFilter(category);
        });
      }
    }
  }
}
