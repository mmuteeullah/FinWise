import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/budget.dart';
import '../services/recurring_service.dart';
import '../services/savings_goals_service.dart';
import '../services/budget_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import 'recurring_bills_screen.dart';
import 'savings_goals_screen.dart';

// Category emoji mapping
String getCategoryEmoji(String category) {
  const Map<String, String> categoryEmojis = {
    'Food & Dining': '🍔',
    'Shopping': '🛍️',
    'Entertainment': '🎬',
    'Transportation': '🚗',
    'Bills & Utilities': '📄',
    'Healthcare': '🏥',
    'Education': '🎓',
    'Travel': '✈️',
    'Groceries': '🛒',
    'Personal Care': '💅',
    'Investments': '📈',
    'Insurance': '🛡️',
    'Other': '📦',
    'Uncategorized': '❓',
  };
  return categoryEmojis[category] ?? '📦';
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final RecurringService _recurringService = RecurringService();
  final SavingsGoalsService _goalsService = SavingsGoalsService();
  final BudgetService _budgetService = BudgetService();
  final TransactionService _transactionService = TransactionService();

  List<RecurringTransaction> _upcomingBills = [];
  List<RecurringTransaction> _overdueBills = [];
  List<SavingsGoal> _activeGoals = [];
  List<Budget> _budgets = [];
  Map<String, double> _budgetProgress = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    try {
      // Load recurring bills
      final upcoming = await _recurringService.getUpcoming();
      final overdue = await _recurringService.getOverdue();

      // Load savings goals
      final goals = await _goalsService.getActiveGoals();

      // Load budgets
      final budgets = await _budgetService.getAllBudgets();

      // Calculate budget progress
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final Map<String, double> progress = {};
      for (final budget in budgets) {
        final spent = await _transactionService.getSpendingByCategory(
          budget.category,
          monthStart,
          monthEnd,
        );
        progress[budget.category] = spent;
      }

      setState(() {
        _upcomingBills = upcoming;
        _overdueBills = overdue;
        _activeGoals = goals;
        _budgets = budgets;
        _budgetProgress = progress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading insights: $e')),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : RefreshIndicator(
                  onRefresh: _loadInsights,
                  color: AppTheme.coral,
                  child: CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      // Header with gradient background
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _buildHeaderContent(),
                        ),
                      ),

                      // White content section
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
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Budget Alerts Section
                                if (_budgets.isNotEmpty) ...[
                                  _buildBudgetAlertsSection(),
                                  const SizedBox(height: 24),
                                ],

                                // Recurring Bills Section
                                _buildRecurringBillsSection(),
                                const SizedBox(height: 24),

                                // Savings Goals Section
                                _buildSavingsGoalsSection(),
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
      ),
    );
  }

  Widget _buildHeaderContent() {
    final totalBillsCount = _upcomingBills.length + _overdueBills.length;
    final totalGoalsCount = _activeGoals.length;
    final overdueCount = _overdueBills.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Insights',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your bills and goals',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildHeaderStat(
                icon: Icons.repeat,
                count: totalBillsCount,
                label: 'Recurring',
                color: AppTheme.coral,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHeaderStat(
                icon: Icons.savings_outlined,
                count: totalGoalsCount,
                label: 'Goals',
                color: AppTheme.successGreen,
              ),
            ),
            if (overdueCount > 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderStat(
                  icon: Icons.warning_rounded,
                  count: overdueCount,
                  label: 'Overdue',
                  color: AppTheme.warningOrange,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAlertsSection() {
    final alertBudgets = _budgets.where((budget) {
      final spent = _budgetProgress[budget.category] ?? 0.0;
      final percentage = (spent / budget.amount) * 100;
      return percentage >= 80; // Alert if 80% or more spent
    }).toList();

    if (alertBudgets.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = ThemeHelper.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Budget Alerts',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...alertBudgets.map((budget) => _buildBudgetAlertCard(budget)),
      ],
    );
  }

  Widget _buildBudgetAlertCard(Budget budget) {
    final isDark = ThemeHelper.isDark(context);
    final spent = _budgetProgress[budget.category] ?? 0.0;
    final percentage = (spent / budget.amount) * 100;
    final remaining = budget.amount - spent;
    final isExceeded = percentage >= 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded
              ? AppTheme.coral.withOpacity(0.5)
              : Colors.orange.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    getCategoryEmoji(budget.category),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    budget.category,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? AppTheme.coral.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExceeded ? 'Exceeded' : '${percentage.toInt()}% Used',
                  style: TextStyle(
                    color: isExceeded ? AppTheme.coral : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${spent.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isExceeded ? 'Over Budget' : 'Remaining',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${remaining.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isExceeded
                          ? AppTheme.coral
                          : (isDark ? Colors.white : AppTheme.textPrimary),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                isExceeded ? AppTheme.coral : Colors.orange,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringBillsSection() {
    final isDark = ThemeHelper.isDark(context);
    final hasOverdue = _overdueBills.isNotEmpty;
    final hasUpcoming = _upcomingBills.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.repeat, color: AppTheme.coral, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recurring Bills',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _showAllRecurringBills,
              child: Text(
                'View All',
                style: TextStyle(color: AppTheme.coral),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!hasOverdue && !hasUpcoming)
          _buildEmptyState(
            icon: Icons.check_circle_outline,
            message: 'No upcoming bills',
            color: Colors.green,
          )
        else ...[
          if (hasOverdue) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Overdue',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ..._overdueBills.map((bill) => _buildRecurringBillCard(bill, isOverdue: true)),
            if (hasUpcoming) const SizedBox(height: 16),
          ],
          if (hasUpcoming) ...[
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Upcoming (Next 7 Days)',
                style: TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ..._upcomingBills.map((bill) => _buildRecurringBillCard(bill)),
          ],
        ],
      ],
    );
  }

  Widget _buildRecurringBillCard(RecurringTransaction bill, {bool isOverdue = false}) {
    final isDark = ThemeHelper.isDark(context);
    final daysUntil = bill.nextExpectedDate?.difference(DateTime.now()).inDays ?? 0;
    final daysText = isOverdue
        ? '${daysUntil.abs()} day${daysUntil.abs() == 1 ? '' : 's'} overdue'
        : daysUntil == 0
            ? 'Today'
            : 'in $daysUntil day${daysUntil == 1 ? '' : 's'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? Colors.orange.withOpacity(0.5)
              : AppTheme.primaryPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBillDetails(bill),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOverdue
                          ? [Colors.orange, Colors.deepOrange]
                          : [AppTheme.primaryPurple, const Color(0xFF9D5EFF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.merchant,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? Colors.orange.withOpacity(0.2)
                                  : AppTheme.primaryPurple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              daysText,
                              style: TextStyle(
                                color: isOverdue ? Colors.orange : AppTheme.primaryPurple,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bill.frequencyLabel,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${bill.averageAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(bill.confidenceScore * 100).toInt()}% sure',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsGoalsSection() {
    final isDark = ThemeHelper.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, color: AppTheme.primaryPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Savings Goals',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _showManageGoals,
              child: Text(
                'Manage',
                style: TextStyle(color: AppTheme.primaryPurple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activeGoals.isEmpty)
          _buildEmptyState(
            icon: Icons.add_circle_outline,
            message: 'No active goals. Create one!',
            color: AppTheme.primaryPurple,
            onTap: _createNewGoal,
          )
        else
          ..._activeGoals.take(3).map((goal) => _buildSavingsGoalCard(goal)),
      ],
    );
  }

  Widget _buildSavingsGoalCard(SavingsGoal goal) {
    final isDark = ThemeHelper.isDark(context);
    final progress = goal.progressPercentage;
    final isOffTrack = !goal.isOnTrack && !goal.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goal.isOverdue
              ? AppTheme.coral.withOpacity(0.5)
              : isOffTrack
                  ? Colors.orange.withOpacity(0.5)
                  : AppTheme.primaryPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular Progress Indicator
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: progress / 100,
                      strokeWidth: 6,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goal.isOverdue
                            ? AppTheme.coral
                            : isOffTrack
                                ? Colors.orange
                                : AppTheme.primaryPurple,
                      ),
                    ),
                    Center(
                      child: Text(
                        goal.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.toInt()}% • ₹${goal.currentAmount.toStringAsFixed(0)} of ₹${goal.targetAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          goal.isOverdue
                              ? 'Overdue by ${goal.daysRemaining.abs()} days'
                              : '${goal.daysRemaining} days left',
                          style: TextStyle(
                            color: goal.isOverdue
                                ? AppTheme.coral
                                : (isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : AppTheme.textSecondary),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showAddFundsDialog(goal),
                icon: Icon(Icons.add_circle, color: AppTheme.primaryPurple),
                tooltip: 'Add Funds',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                goal.isOverdue
                    ? AppTheme.coral
                    : isOffTrack
                        ? Colors.orange
                        : AppTheme.primaryPurple,
              ),
              minHeight: 8,
            ),
          ),
          if (isOffTrack && !goal.isOverdue) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save ₹${goal.monthlyTarget.toStringAsFixed(0)}/month to stay on track',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = ThemeHelper.isDark(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: color.withOpacity(0.5), size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onTap != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Create Goal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllRecurringBills() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecurringBillsScreen(),
      ),
    ).then((_) => _loadInsights()); // Reload data when returning
  }

  void _showManageGoals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavingsGoalsScreen(),
      ),
    ).then((_) => _loadInsights()); // Reload data when returning
  }

  void _createNewGoal() {
    _showCreateGoalDialog();
  }

  void _showBillDetails(RecurringTransaction bill) {
    final isDark = ThemeHelper.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryPurple, const Color(0xFF9D5EFF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.merchant,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bill.category,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Average Amount', '₹${bill.averageAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Frequency', bill.frequencyLabel),
            _buildDetailRow('Occurrences', bill.occurrenceCount.toString()),
            _buildDetailRow(
              'First Occurrence',
              DateFormat('MMM dd, yyyy').format(bill.firstOccurrence),
            ),
            _buildDetailRow(
              'Last Occurrence',
              DateFormat('MMM dd, yyyy').format(bill.lastOccurrence),
            ),
            if (bill.nextExpectedDate != null)
              _buildDetailRow(
                'Next Expected',
                DateFormat('MMM dd, yyyy').format(bill.nextExpectedDate!),
              ),
            _buildDetailRow(
              'Confidence',
              '${(bill.confidenceScore * 100).toInt()}%',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _markBillAsInactive(bill);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.coral),
                      foregroundColor: AppTheme.coral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Mark Inactive'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isDark = ThemeHelper.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markBillAsInactive(RecurringTransaction bill) async {
    await _recurringService.markInactive(bill.id);
    await _loadInsights();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${bill.merchant} marked as inactive')),
      );
    }
  }

  void _showAddFundsDialog(SavingsGoal goal) {
    final isDark = ThemeHelper.isDark(context);
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.cardBackgroundDark
            : Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(goal.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add Funds',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.name,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : AppTheme.textSecondary,
                ),
                prefixText: '₹',
                prefixStyle: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.black.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                await _goalsService.updateProgress(goal.id, amount);
                await _loadInsights();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('₹${amount.toStringAsFixed(0)} added to ${goal.name}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCreateGoalDialog() {
    final isDark = ThemeHelper.isDark(context);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate;
    GoalCategory? selectedCategory;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark
              ? AppTheme.cardBackgroundDark
              : Theme.of(context).dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create Savings Goal',
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Goal Name',
                    labelStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.textSecondary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.textSecondary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Target Amount',
                    labelStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.textSecondary,
                    ),
                    prefixText: '₹',
                    prefixStyle: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GoalCategory>(
                  value: selectedCategory,
                  dropdownColor: isDark
                      ? AppTheme.cardBackgroundDark
                      : Theme.of(context).cardColor,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.6)
                          : AppTheme.textSecondary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple),
                    ),
                  ),
                  items: GoalCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        '${category.defaultEmoji} ${category.label}',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    selectedDate == null
                        ? 'Select Target Date'
                        : 'Target: ${DateFormat('MMM dd, yyyy').format(selectedDate!)}',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryPurple,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black.withOpacity(0.3),
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      builder: (context, child) {
                        return Theme(
                          data: isDark
                              ? ThemeData.dark().copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: AppTheme.primaryPurple,
                                    surface: AppTheme.cardBackgroundDark,
                                  ),
                                )
                              : ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppTheme.primaryPurple,
                                    surface: Colors.white,
                                  ),
                                ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    amountController.text.isNotEmpty &&
                    selectedDate != null &&
                    selectedCategory != null) {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0) {
                    await _goalsService.createGoal(
                      name: nameController.text,
                      description: descriptionController.text,
                      targetAmount: amount,
                      targetDate: selectedDate!,
                      category: selectedCategory,
                    );
                    await _loadInsights();
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Goal created successfully!')),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
