import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../services/transaction_service.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../models/category.dart';
import '../models/budget.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  State<BudgetScreen> createState() => BudgetScreenState();
}

class BudgetScreenState extends State<BudgetScreen> {
  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();
  final CategoryService _categoryService = CategoryService.instance;
  bool _isLoading = true;
  Map<String, double> _categorySpending = {};
  double _totalSpending = 0.0;
  List<Budget> _budgets = [];
  List<Category> _categories = [];

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
      // Initialize budgets if empty
      await _budgetService.initializeBudgetsIfEmpty();

      final spending = await _transactionService.getMonthlyTotalSpending();
      final categorySpending = await _transactionService.getMonthlySpending();
      final budgets = await _budgetService.getAllBudgets();
      final categories = await _categoryService.getActiveCategories();

      setState(() {
        _totalSpending = spending;
        _categorySpending = categorySpending;
        _budgets = budgets;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading budget data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Public method to refresh budget data (called when tab is switched)
  void refresh() {
    _loadData();
  }

  Budget? _getBudgetForCategory(String category) {
    try {
      return _budgets.firstWhere((b) => b.category == category);
    } catch (e) {
      return null;
    }
  }

  double _getSpendingPercentage(String category) {
    final spent = _categorySpending[category] ?? 0;
    final budget = _getBudgetForCategory(category);
    if (budget == null) return 0;
    return (spent / budget.totalBudget * 100).clamp(0, 100);
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
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Budget & Goals',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Refreshed budget data'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your monthly spending',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
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
                  child: _isLoading
                      ? const SizedBox(
                          height: 400,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMonthlyOverview(),
                              const SizedBox(height: 32),
                              Text(
                                'Category Budgets',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeHelper.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._budgets.map((budget) =>
                                _buildBudgetItem(budget)
                              ).toList(),
                              const SizedBox(height: 24),
                              _buildAddBudgetButton(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyOverview() {
    final totalBudget = _budgets.fold(0.0, (sum, budget) => sum + budget.totalBudget);
    final percentage = (totalBudget > 0 ? (_totalSpending / totalBudget) * 100 : 0).clamp(0, 100);
    final remaining = totalBudget - _totalSpending;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ThemeHelper.backgroundGradient(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Budget',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_formatAmount(_totalSpending)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'of ₹${_formatAmount(totalBudget)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 90 ? AppTheme.coral : AppTheme.successGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                remaining >= 0 ? 'Remaining' : 'Over budget',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${_formatAmount(remaining.abs())}',
                style: TextStyle(
                  color: remaining >= 0 ? Colors.white : AppTheme.coral,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(Budget budget) {
    // Find category from dynamic list
    final category = _categories.firstWhere(
      (cat) => cat.name == budget.category,
      orElse: () => Category(
        id: 'fallback',
        name: budget.category,
        iconEmoji: '📦',
        colorHex: '9E9E9E',
        createdAt: DateTime.now(),
      ),
    );
    final spent = _categorySpending[budget.category] ?? 0;
    final percentage = _getSpendingPercentage(budget.category);
    final remaining = budget.totalBudget - spent;

    return InkWell(
      onTap: () => _showEditBudgetDialog(budget),
      onLongPress: () => _showBudgetOptions(budget),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: ThemeHelper.cardDecoration(context),
        child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          budget.category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ThemeHelper.textPrimary(context),
                          ),
                        ),
                        if (budget.rolloverEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ROLLOVER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.purple,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (budget.rolloverEnabled && budget.rolledOverAmount > 0) ...[
                      Text(
                        '₹${_formatAmount(spent)} of ₹${_formatAmount(budget.amount)} + ₹${_formatAmount(budget.rolledOverAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '₹${_formatAmount(spent)} of ₹${_formatAmount(budget.totalBudget)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: percentage > 90 ? AppTheme.coral : ThemeHelper.textPrimary(context),
                    ),
                  ),
                  Text(
                    remaining >= 0 ? 'left' : 'over',
                    style: TextStyle(
                      fontSize: 11,
                      color: ThemeHelper.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: ThemeHelper.surfaceColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 90
                    ? AppTheme.coral
                    : percentage > 75
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showBudgetOptions(Budget budget) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.purple),
              title: const Text('Edit Budget'),
              onTap: () {
                Navigator.pop(context);
                _showEditBudgetDialog(budget);
              },
            ),
            ListTile(
              leading: Icon(
                budget.rolloverEnabled ? Icons.toggle_on : Icons.toggle_off,
                color: budget.rolloverEnabled ? AppTheme.successGreen : Colors.grey,
              ),
              title: const Text('Enable Rollover'),
              subtitle: const Text('Carry unused budget to next month'),
              trailing: Switch(
                value: budget.rolloverEnabled,
                onChanged: (value) async {
                  Navigator.pop(context);
                  await _budgetService.toggleRollover(budget.id, value);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Rollover enabled for ${budget.category}'
                              : 'Rollover disabled for ${budget.category}',
                        ),
                        backgroundColor: value ? AppTheme.successGreen : AppTheme.coral,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                activeColor: AppTheme.successGreen,
              ),
            ),
            if (budget.rolledOverAmount > 0)
              ListTile(
                leading: const Icon(Icons.clear, color: AppTheme.warningOrange),
                title: const Text('Clear Rollover'),
                subtitle: Text('Remove ₹${_formatAmount(budget.rolledOverAmount)} rollover'),
                onTap: () async {
                  Navigator.pop(context);
                  await _budgetService.clearRollover(budget.id);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rollover cleared for ${budget.category}'),
                        backgroundColor: AppTheme.warningOrange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.coral),
              title: const Text('Delete Budget'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteBudget(budget.category);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBudget(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete the budget for $category?'),
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
      await _budgetService.deleteBudgetByCategory(category);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$category budget deleted'),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showEditBudgetDialog(Budget budget) async {
    final TextEditingController controller = TextEditingController(
      text: budget.amount.toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit ${budget.category} Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter monthly budget amount:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                prefixText: '₹',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.coral, width: 2),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _budgetService.updateBudgetAmount(budget.category, result);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${budget.category} budget updated to ₹${result.toStringAsFixed(0)}'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildAddBudgetButton() {
    // Find categories without budgets (from dynamic categories)
    final categoriesWithBudgets = _budgets.map((b) => b.category).toSet();
    final availableCategories = _categories
        .where((cat) => !categoriesWithBudgets.contains(cat.name))
        .toList();

    return Column(
      children: [
        if (availableCategories.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddBudgetDialog(availableCategories),
              icon: const Icon(Icons.add),
              label: const Text('Add Budget for Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to Category Management screen
              Navigator.pushNamed(context, '/manage-categories').then((_) => _loadData());
            },
            icon: const Icon(Icons.category),
            label: const Text('Manage Categories'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.purple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: AppTheme.purple.withOpacity(0.3)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showResetDialog,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset to Defaults'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.coral,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: AppTheme.coral.withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddBudgetDialog(List<Category> availableCategories) async {
    final selected = await showDialog<Category>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Budget'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableCategories.length,
            itemBuilder: (context, index) {
              final category = availableCategories[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                title: Text(category.name),
                onTap: () => Navigator.pop(context, category),
              );
            },
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

    if (selected != null) {
      // Create a temporary budget object for adding new budget
      final tempBudget = Budget(
        id: '',
        category: selected.name,
        amount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _showEditBudgetDialog(tempBudget);
    }
  }

  Future<void> _showResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Budgets'),
        content: const Text('This will delete all your current budgets and restore the default budget values. Are you sure?'),
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _budgetService.resetToDefaults();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budgets reset to defaults'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
