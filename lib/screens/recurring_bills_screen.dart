import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as models;
import '../services/recurring_service.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class RecurringBillsScreen extends StatefulWidget {
  const RecurringBillsScreen({super.key});

  @override
  State<RecurringBillsScreen> createState() => _RecurringBillsScreenState();
}

class _RecurringBillsScreenState extends State<RecurringBillsScreen> {
  final RecurringService _recurringService = RecurringService();
  final TextEditingController _searchController = TextEditingController();

  List<RecurringTransaction> _allBills = [];
  List<RecurringTransaction> _filteredBills = [];
  bool _isLoading = true;
  String _searchQuery = '';
  BillFilter _currentFilter = BillFilter.all;
  RecurringFrequency? _frequencyFilter;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);

    final bills = await _recurringService.getAll();

    setState(() {
      _allBills = bills;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<RecurringTransaction> filtered = List.from(_allBills);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((bill) {
        return bill.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               bill.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    switch (_currentFilter) {
      case BillFilter.all:
        filtered = filtered.where((b) => b.isActive).toList();
        break;
      case BillFilter.upcoming:
        filtered = filtered.where((b) => b.isActive && b.isUpcoming).toList();
        break;
      case BillFilter.overdue:
        filtered = filtered.where((b) => b.isActive && b.isOverdue).toList();
        break;
      case BillFilter.inactive:
        filtered = filtered.where((b) => !b.isActive).toList();
        break;
    }

    // Apply frequency filter
    if (_frequencyFilter != null) {
      filtered = filtered.where((b) => b.frequencyType == _frequencyFilter).toList();
    }

    // Sort by next expected date
    filtered.sort((a, b) {
      if (a.nextExpectedDate == null && b.nextExpectedDate == null) return 0;
      if (a.nextExpectedDate == null) return 1;
      if (b.nextExpectedDate == null) return -1;
      return a.nextExpectedDate!.compareTo(b.nextExpectedDate!);
    });

    setState(() {
      _filteredBills = filtered;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilters();
    });
  }

  Future<void> _markAsInactive(RecurringTransaction bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Inactive?'),
        content: Text('This will mark "${bill.merchant}" as inactive. You can reactivate it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.coral),
            child: const Text('Mark Inactive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _recurringService.markInactive(bill.id);
      _showSnackBar('Bill marked as inactive');
      _loadBills();
    }
  }

  Future<void> _deleteBill(RecurringTransaction bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('This will permanently delete "${bill.merchant}". This action cannot be undone.'),
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
      await _recurringService.delete(bill.id);
      _showSnackBar('Bill deleted');
      _loadBills();
    }
  }

  Future<void> _showBillDetails(RecurringTransaction bill) async {
    // Get transactions for this bill
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'merchant = ? AND category = ?',
      whereArgs: [bill.merchant, bill.category],
      orderBy: 'date DESC',
      limit: 10,
    );

    final transactions = maps.map((map) => models.Transaction.fromMap(map)).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BillDetailsSheet(
        bill: bill,
        transactions: transactions,
        onMarkInactive: () {
          Navigator.pop(context);
          _markAsInactive(bill);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteBill(bill);
        },
      ),
    );
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
          _buildBillsList(),
        ],
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
          'Recurring Bills',
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
          onPressed: _loadBills,
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
          hintText: 'Search bills...',
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
        children: [
          ...BillFilter.values.map((filter) => Padding(
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
          )),
          const SizedBox(width: 4),
          PopupMenuButton<RecurringFrequency?>(
            child: Chip(
              avatar: Icon(
                Icons.schedule,
                size: 18,
                color: _frequencyFilter != null ? AppTheme.purple : ThemeHelper.textSecondary(context),
              ),
              label: Text(_frequencyFilter?.toString().split('.').last ?? 'Frequency'),
              deleteIcon: _frequencyFilter != null
                  ? const Icon(Icons.close, size: 18)
                  : null,
              onDeleted: _frequencyFilter != null
                  ? () {
                      setState(() {
                        _frequencyFilter = null;
                        _applyFilters();
                      });
                    }
                  : null,
              labelStyle: TextStyle(
                color: _frequencyFilter != null
                    ? AppTheme.purple
                    : ThemeHelper.textSecondary(context),
              ),
            ),
            onSelected: (frequency) {
              setState(() {
                _frequencyFilter = frequency;
                _applyFilters();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Frequencies'),
              ),
              ...RecurringFrequency.values.map((freq) => PopupMenuItem(
                value: freq,
                child: Text(freq.toString().split('.').last.toUpperCase()),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    final isDark = ThemeHelper.isDark(context);
    final totalActive = _allBills.where((b) => b.isActive).length;
    final upcomingCount = _allBills.where((b) => b.isActive && b.isUpcoming).length;
    final overdueCount = _allBills.where((b) => b.isActive && b.isOverdue).length;
    final totalMonthly = _allBills
        .where((b) => b.isActive && b.frequencyType == RecurringFrequency.monthly)
        .fold(0.0, (sum, b) => sum + b.averageAmount);

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
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Active', totalActive.toString(), Icons.check_circle_outline),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildStatItem('Upcoming', upcomingCount.toString(), Icons.calendar_today),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildStatItem('Overdue', overdueCount.toString(), Icons.warning_amber_rounded),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildStatItem('Monthly', '₹${totalMonthly.toStringAsFixed(0)}', Icons.currency_rupee),
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

  Widget _buildBillsList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.coral),
        ),
      );
    }

    if (_filteredBills.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: ThemeHelper.textSecondary(context).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No bills found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty || _frequencyFilter != null
                    ? 'Try adjusting your filters'
                    : 'Bills will appear here automatically',
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final bill = _filteredBills[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBillCard(bill),
            );
          },
          childCount: _filteredBills.length,
        ),
      ),
    );
  }

  Widget _buildBillCard(RecurringTransaction bill) {
    final isDark = ThemeHelper.isDark(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return InkWell(
      onTap: () => _showBillDetails(bill),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: bill.isOverdue
              ? Border.all(color: Colors.red.withOpacity(0.5), width: 2)
              : bill.isUpcoming
                  ? Border.all(color: Colors.orange.withOpacity(0.5), width: 2)
                  : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status indicator
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bill.isOverdue
                        ? Colors.red.withOpacity(0.1)
                        : bill.isUpcoming
                            ? Colors.orange.withOpacity(0.1)
                            : AppTheme.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    bill.isOverdue
                        ? Icons.warning_amber_rounded
                        : bill.isUpcoming
                            ? Icons.schedule
                            : Icons.check_circle_outline,
                    color: bill.isOverdue
                        ? Colors.red
                        : bill.isUpcoming
                            ? Colors.orange
                            : AppTheme.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.merchant,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            bill.category,
                            style: TextStyle(
                              fontSize: 13,
                              color: ThemeHelper.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.coral.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bill.frequencyLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.coral,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(bill.averageAmount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.history,
                  '${bill.occurrenceCount}x',
                  'times',
                ),
                if (bill.nextExpectedDate != null)
                  _buildInfoChip(
                    Icons.event,
                    DateFormat('MMM d').format(bill.nextExpectedDate!),
                    bill.isOverdue
                        ? 'OVERDUE'
                        : bill.isUpcoming
                            ? 'SOON'
                            : 'next',
                  ),
                _buildInfoChip(
                  Icons.trending_up,
                  '${(bill.confidenceScore * 100).toStringAsFixed(0)}%',
                  'confidence',
                ),
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
                : label.contains('SOON')
                    ? Colors.orange
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
}

class _BillDetailsSheet extends StatelessWidget {
  final RecurringTransaction bill;
  final List<models.Transaction> transactions;
  final VoidCallback onMarkInactive;
  final VoidCallback onDelete;

  const _BillDetailsSheet({
    required this.bill,
    required this.transactions,
    required this.onMarkInactive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.merchant,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: ThemeHelper.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bill.category,
                              style: TextStyle(
                                fontSize: 14,
                                color: ThemeHelper.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(bill.averageAmount),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.coral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Details
                  _buildDetailRow('Frequency', bill.frequencyLabel, Icons.schedule),
                  _buildDetailRow(
                    'Occurrences',
                    '${bill.occurrenceCount} times',
                    Icons.history,
                  ),
                  if (bill.nextExpectedDate != null)
                    _buildDetailRow(
                      'Next Expected',
                      DateFormat('MMM d, yyyy').format(bill.nextExpectedDate!),
                      Icons.event,
                    ),
                  _buildDetailRow(
                    'First Seen',
                    DateFormat('MMM d, yyyy').format(bill.firstOccurrence),
                    Icons.calendar_today,
                  ),
                  _buildDetailRow(
                    'Last Seen',
                    DateFormat('MMM d, yyyy').format(bill.lastOccurrence),
                    Icons.update,
                  ),
                  _buildDetailRow(
                    'Confidence',
                    '${(bill.confidenceScore * 100).toStringAsFixed(0)}%',
                    Icons.trending_up,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Transaction history
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Transaction History (Last 10)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt,
                          size: 16,
                          color: ThemeHelper.textSecondary(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('MMM d, yyyy').format(tx.timestamp),
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeHelper.textPrimary(context),
                            ),
                          ),
                        ),
                        Text(
                          currencyFormat.format(tx.amount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMarkInactive,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Mark Inactive'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.coral,
                        side: const BorderSide(color: AppTheme.coral),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum BillFilter {
  all,
  upcoming,
  overdue,
  inactive,
}

extension BillFilterExtension on BillFilter {
  String get label {
    switch (this) {
      case BillFilter.all:
        return 'All';
      case BillFilter.upcoming:
        return 'Upcoming';
      case BillFilter.overdue:
        return 'Overdue';
      case BillFilter.inactive:
        return 'Inactive';
    }
  }
}
