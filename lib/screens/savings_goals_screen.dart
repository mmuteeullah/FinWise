import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/savings_goal.dart';
import '../services/savings_goals_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final SavingsGoalsService _goalsService = SavingsGoalsService();
  final TextEditingController _searchController = TextEditingController();

  List<SavingsGoal> _allGoals = [];
  List<SavingsGoal> _filteredGoals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  GoalFilter _currentFilter = GoalFilter.active;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);

    final goals = await _goalsService.getAllGoals();

    setState(() {
      _allGoals = goals;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<SavingsGoal> filtered = List.from(_allGoals);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((goal) {
        return goal.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               goal.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               goal.category.label.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    switch (_currentFilter) {
      case GoalFilter.active:
        filtered = filtered.where((g) => !g.isCompleted).toList();
        break;
      case GoalFilter.completed:
        filtered = filtered.where((g) => g.isCompleted).toList();
        break;
      case GoalFilter.onTrack:
        filtered = filtered.where((g) => !g.isCompleted && g.isOnTrack).toList();
        break;
      case GoalFilter.offTrack:
        filtered = filtered.where((g) => !g.isCompleted && !g.isOnTrack).toList();
        break;
      case GoalFilter.all:
        // No filtering
        break;
    }

    // Sort by progress (active goals) or completion date (completed goals)
    filtered.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      if (a.isCompleted && b.isCompleted) {
        return b.updatedAt.compareTo(a.updatedAt);
      }
      return b.progress.compareTo(a.progress);
    });

    setState(() {
      _filteredGoals = filtered;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilters();
    });
  }

  Future<void> _showAddGoalDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _AddEditGoalDialog(
        onSave: _loadGoals,
      ),
    );
  }

  Future<void> _showEditGoalDialog(SavingsGoal goal) async {
    await showDialog(
      context: context,
      builder: (context) => _AddEditGoalDialog(
        goal: goal,
        onSave: _loadGoals,
      ),
    );
  }

  Future<void> _deleteGoal(SavingsGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('This will permanently delete "${goal.name}". This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _goalsService.deleteGoal(goal.id);
      _showSnackBar('Goal deleted');
      _loadGoals();
    }
  }

  Future<void> _markCompleted(SavingsGoal goal) async {
    await _goalsService.markCompleted(goal.id);
    _showSnackBar('🎉 Congratulations! Goal completed!');
    _loadGoals();
  }

  Future<void> _updateProgress(SavingsGoal goal) async {
    final controller = TextEditingController(
      text: goal.currentAmount.toStringAsFixed(0),
    );

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Progress'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ₹${goal.currentAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
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
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (amount != null) {
      await _goalsService.setProgress(goal.id, amount);
      _showSnackBar('Progress updated');
      _loadGoals();
    }

    controller.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.whiteBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 20),
                _buildStatsSummary(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
          _buildGoalsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalDialog,
        backgroundColor: AppTheme.coral,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Goal', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    final isDark = ThemeHelper.isDark(context);

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.whiteBg,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: ThemeHelper.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Text(
          'Savings Goals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ThemeHelper.textPrimary(context),
            fontSize: 24,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.coral),
          onPressed: _loadGoals,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: ThemeHelper.cardDecoration(context, radius: 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search goals...',
          hintStyle: TextStyle(color: ThemeHelper.textSecondary(context)),
          prefixIcon: Icon(Icons.search, color: ThemeHelper.textSecondary(context)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: ThemeHelper.textSecondary(context)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: TextStyle(color: ThemeHelper.textPrimary(context)),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: GoalFilter.values.map((filter) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(filter.label),
            selected: _currentFilter == filter,
            onSelected: (selected) {
              setState(() {
                _currentFilter = filter;
                _applyFilters();
              });
            },
            selectedColor: AppTheme.coral.withOpacity(0.2),
            checkmarkColor: AppTheme.coral,
            labelStyle: TextStyle(
              color: _currentFilter == filter
                  ? AppTheme.coral
                  : ThemeHelper.textSecondary(context),
              fontWeight: _currentFilter == filter ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final isDark = ThemeHelper.isDark(context);
    final activeGoals = _allGoals.where((g) => !g.isCompleted).length;
    final completedGoals = _allGoals.where((g) => g.isCompleted).length;
    final totalTarget = _allGoals
        .where((g) => !g.isCompleted)
        .fold(0.0, (sum, g) => sum + g.targetAmount);
    final totalSaved = _allGoals
        .where((g) => !g.isCompleted)
        .fold(0.0, (sum, g) => sum + g.currentAmount);
    final overallProgress = totalTarget > 0 ? (totalSaved / totalTarget * 100) : 0.0;

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Active', activeGoals.toString(), Icons.flag),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildStatItem('Completed', completedGoals.toString(), Icons.check_circle),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildStatItem('Progress', '${overallProgress.toStringAsFixed(0)}%', Icons.trending_up),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.savings, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Saved',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '₹${totalSaved.toStringAsFixed(0)} / ₹${totalTarget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.coral),
        ),
      );
    }

    if (_filteredGoals.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 64,
                color: ThemeHelper.textSecondary(context).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No goals found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try adjusting your filters'
                    : 'Tap + to create your first goal',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeHelper.textSecondary(context).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final goal = _filteredGoals[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildGoalCard(goal),
            );
          },
          childCount: _filteredGoals.length,
        ),
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final isDark = ThemeHelper.isDark(context);

    return InkWell(
      onTap: () => _showGoalOptions(goal),
      onLongPress: () => _showGoalOptions(goal),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.cardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: goal.isCompleted
              ? Border.all(color: Colors.green.withOpacity(0.5), width: 2)
              : goal.isOverdue
                  ? Border.all(color: Colors.red.withOpacity(0.5), width: 2)
                  : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: goal.isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : AppTheme.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      goal.isCompleted ? '✅' : goal.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.textPrimary(context),
                          decoration: goal.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.category.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: ThemeHelper.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!goal.isCompleted)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditGoalDialog(goal),
                    color: AppTheme.coral,
                  ),
              ],
            ),
            if (goal.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                goal.description,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Progress bar
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: goal.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: goal.isCompleted
                            ? [Colors.green, Colors.green.shade700]
                            : goal.isOnTrack
                                ? [AppTheme.purple, AppTheme.deepBlue]
                                : [Colors.orange, Colors.red],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount and progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${goal.currentAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.textPrimary(context),
                      ),
                    ),
                    Text(
                      'of ₹${goal.targetAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeHelper.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: goal.isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : goal.isOnTrack
                            ? AppTheme.purple.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${goal.progressPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: goal.isCompleted
                          ? Colors.green
                          : goal.isOnTrack
                              ? AppTheme.purple
                              : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Additional info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.event,
                  DateFormat('MMM d, yyyy').format(goal.targetDate),
                  goal.isOverdue ? 'OVERDUE' : 'target',
                ),
                if (!goal.isCompleted) ...[
                  _buildInfoChip(
                    Icons.trending_up,
                    '₹${goal.monthlyTarget.toStringAsFixed(0)}',
                    '/month',
                  ),
                  _buildInfoChip(
                    Icons.schedule,
                    '${goal.daysRemaining.abs()}d',
                    goal.daysRemaining < 0 ? 'over' : 'left',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: ThemeHelper.textSecondary(context)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: label.contains('OVERDUE')
                ? Colors.red
                : ThemeHelper.textPrimary(context),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ThemeHelper.textSecondary(context),
          ),
        ),
      ],
    );
  }

  void _showGoalOptions(SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: ThemeHelper.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: AppTheme.purple),
                title: const Text('Update Progress'),
                onTap: () {
                  Navigator.pop(context);
                  _updateProgress(goal);
                },
              ),
              if (!goal.isCompleted)
                ListTile(
                  leading: const Icon(Icons.edit, color: AppTheme.coral),
                  title: const Text('Edit Goal'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditGoalDialog(goal);
                  },
                ),
              if (!goal.isCompleted && goal.progress >= 1.0)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as Completed'),
                  onTap: () {
                    Navigator.pop(context);
                    _markCompleted(goal);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Goal'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteGoal(goal);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddEditGoalDialog extends StatefulWidget {
  final SavingsGoal? goal;
  final VoidCallback onSave;

  const _AddEditGoalDialog({
    this.goal,
    required this.onSave,
  });

  @override
  State<_AddEditGoalDialog> createState() => _AddEditGoalDialogState();
}

class _AddEditGoalDialogState extends State<_AddEditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();

  GoalCategory _selectedCategory = GoalCategory.other;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  String _selectedEmoji = '🎯';

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _nameController.text = widget.goal!.name;
      _descriptionController.text = widget.goal!.description;
      _targetAmountController.text = widget.goal!.targetAmount.toStringAsFixed(0);
      _currentAmountController.text = widget.goal!.currentAmount.toStringAsFixed(0);
      _selectedCategory = widget.goal!.category;
      _targetDate = widget.goal!.targetDate;
      _selectedEmoji = widget.goal!.emoji;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final service = SavingsGoalsService();

    if (widget.goal == null) {
      // Create new goal
      final newGoal = await service.createGoal(
        name: _nameController.text,
        description: _descriptionController.text,
        targetAmount: double.parse(_targetAmountController.text),
        targetDate: _targetDate,
        category: _selectedCategory,
        emoji: _selectedEmoji,
      );

      // Set initial progress if provided
      final currentAmount = double.tryParse(_currentAmountController.text) ?? 0.0;
      if (currentAmount > 0) {
        await service.setProgress(newGoal.id, currentAmount);
      }
    } else {
      // Update existing goal
      await service.updateGoal(
        widget.goal!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          targetAmount: double.parse(_targetAmountController.text),
          currentAmount: double.tryParse(_currentAmountController.text) ?? 0.0,
          targetDate: _targetDate,
          category: _selectedCategory,
          emoji: _selectedEmoji,
          updatedAt: DateTime.now(),
        ),
      );
    }

    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.goal == null ? 'New Savings Goal' : 'Edit Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji selector
              Row(
                children: [
                  Text('Emoji: $_selectedEmoji', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Simple emoji picker (you could use a package for better UX)
                      setState(() {
                        final emojis = ['🎯', '✈️', '🆘', '🎓', '🏠', '🚗', '💒', '🌴', '📱', '💰', '🎉', '⭐'];
                        final currentIndex = emojis.indexOf(_selectedEmoji);
                        _selectedEmoji = emojis[(currentIndex + 1) % emojis.length];
                      });
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<GoalCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: GoalCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text('${cat.defaultEmoji} ${cat.label}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedEmoji = value.defaultEmoji;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Target Amount
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  prefixText: '₹',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Current Amount
              TextFormField(
                controller: _currentAmountController,
                decoration: const InputDecoration(
                  labelText: 'Current Amount (optional)',
                  prefixText: '₹',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Target Date
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _targetDate = date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Target Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM d, yyyy').format(_targetDate)),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.coral,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.goal == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

enum GoalFilter {
  active,
  completed,
  onTrack,
  offTrack,
  all,
}

extension GoalFilterExtension on GoalFilter {
  String get label {
    switch (this) {
      case GoalFilter.active:
        return 'Active';
      case GoalFilter.completed:
        return 'Completed';
      case GoalFilter.onTrack:
        return 'On Track';
      case GoalFilter.offTrack:
        return 'Off Track';
      case GoalFilter.all:
        return 'All';
    }
  }
}
