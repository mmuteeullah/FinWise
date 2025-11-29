import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../widgets/add_transaction_sheet.dart';
import 'raw_sms_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  Set<String> _selectedCategories = {}; // Changed to Set for multi-selection
  Set<String> _selectedPaymentMethods = {}; // Payment method filter
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  bool _showSearch = false;
  late TabController _tabController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
    _loadTransactions();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getActiveCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    final transactions = await _transactionService.getAllTransactions();

    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  /// Public method to refresh transactions (called from main screen when tab changes)
  void refresh() {
    _loadCategories();  // Reload categories to pick up any changes
    _loadTransactions();
  }

  /// Public method to set category filter and navigate to this screen
  void setCategoryFilter(String category) {
    setState(() {
      _selectedCategories.clear();
      _selectedCategories.add(category);
    });
  }

  void _applyFilter() {
    setState(() {});
  }

  List<Transaction> _getFilteredTransactions(int tabIndex) {
    // Start with all transactions
    List<Transaction> filtered = _transactions;

    // Filter by transaction type (All/Expense/Income)
    if (tabIndex == 1) {
      // Expenses
      filtered = filtered.where((t) => t.type == TransactionType.debit).toList();
    } else if (tabIndex == 2) {
      // Income
      filtered = filtered.where((t) => t.type == TransactionType.credit).toList();
    }

    // Filter by multiple categories
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((t) => _selectedCategories.contains(t.category)).toList();
    }

    // Filter by payment methods
    if (_selectedPaymentMethods.isNotEmpty) {
      filtered = filtered.where((t) {
        if (t.accountLastDigits == null) return false;
        return _selectedPaymentMethods.contains(t.accountLastDigits);
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               t.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((t) {
        return t.timestamp.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
               t.timestamp.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Filter by amount range
    if (_minAmount != null) {
      filtered = filtered.where((t) => (t.amount ?? 0) >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((t) => (t.amount ?? 0) <= _maxAmount!).toList();
    }

    return filtered;
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchDebounce?.cancel();

    // Create new timer with 300ms delay
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
      _applyFilter();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _showSearch = false;
    });
    _applyFilter();
  }

  void _clearFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedPaymentMethods.clear();
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
      _minAmount = null;
      _maxAmount = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    _applyFilter();
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
           _selectedCategories.isNotEmpty ||
           _selectedPaymentMethods.isNotEmpty ||
           _startDate != null ||
           _endDate != null ||
           _minAmount != null ||
           _maxAmount != null;
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategories.clear();
      _selectedPaymentMethods.clear();
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
      _minAmountController.clear();
      _maxAmountController.clear();
      _showSearch = false;
    });
  }

  Future<void> _showDateRangePicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DateRangePickerSheet(
        currentStart: _startDate,
        currentEnd: _endDate,
        onRangeSelected: (start, end) {
          setState(() {
            _startDate = start;
            _endDate = end;
          });
          _applyFilter();
        },
        onClear: () {
          setState(() {
            _startDate = null;
            _endDate = null;
          });
          _applyFilter();
        },
      ),
    );
  }

  Future<void> _showEditTransactionDialog(Transaction transaction) async {
    final isDark = ThemeHelper.isDark(context);
    final TextEditingController amountController = TextEditingController(
      text: (transaction.amount ?? 0).toStringAsFixed(2),
    );
    final TextEditingController merchantController = TextEditingController(
      text: transaction.merchant,
    );

    String selectedCategory = transaction.category;
    DateTime selectedDate = transaction.timestamp;
    TransactionType selectedType = transaction.type;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: ThemeHelper.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Transaction',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: Icon(Icons.close_rounded, color: ThemeHelper.textSecondary(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Amount Field
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                    prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.coral),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.coral, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Merchant Field
                TextField(
                  controller: merchantController,
                  decoration: InputDecoration(
                    labelText: 'Merchant',
                    prefixIcon: const Icon(Icons.store, color: AppTheme.coral),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.coral, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Type Selector
                DropdownButtonFormField<TransactionType>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    prefixIcon: const Icon(Icons.swap_vert, color: AppTheme.coral),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.coral, width: 2),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: TransactionType.debit,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 16, color: AppTheme.coral),
                          const SizedBox(width: 8),
                          const Text('Debit (Spending)'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.credit,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.successGreen),
                          const SizedBox(width: 8),
                          const Text('Credit (Income)'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Category Selector
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.coral),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.coral, width: 2),
                    ),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category.name,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: category.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Date Selector
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? ColorScheme.dark(
                                    primary: AppTheme.coral,
                                    onPrimary: Colors.white,
                                    surface: AppTheme.cardBackgroundDark,
                                    onSurface: AppTheme.textPrimaryDark,
                                  )
                                : const ColorScheme.light(
                                    primary: AppTheme.coral,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black87,
                                  ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppTheme.coral),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                      ),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeHelper.textPrimary(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: AppTheme.coral.withOpacity(0.3),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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

    if (result == true) {
      final amount = double.tryParse(amountController.text);
      final merchant = merchantController.text.trim();

      if (amount != null && amount > 0 && merchant.isNotEmpty) {
        final updated = transaction.copyWith(
          amount: amount,
          merchant: merchant,
          category: selectedCategory,
          timestamp: selectedDate,
          type: selectedType,
        );

        await _transactionService.updateTransaction(updated, learnCategory: true);
        await _loadTransactions();

        // Refresh Budget and Home screens to show updated spending
        try {
          final mainScreenState = context.findRootAncestorStateOfType<State>();
          if (mainScreenState != null) {
            (mainScreenState as dynamic).refreshAfterTransactionChange();
          }
        } catch (e) {
          // Ignore if method doesn't exist
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaction updated successfully!'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: Text('Delete transaction from ${transaction.merchant}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _transactionService.deleteTransaction(transaction.id);
      await _loadTransactions();

      // Refresh Budget and Home screens to show updated spending
      try {
        final mainScreenState = context.findRootAncestorStateOfType<State>();
        if (mainScreenState != null) {
          (mainScreenState as dynamic).refreshAfterTransactionChange();
        }
      } catch (e) {
        // Ignore if method doesn't exist
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showTransactionDetails(Transaction transaction) async {
    final isDebit = transaction.type == TransactionType.debit;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: ThemeHelper.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeHelper.surfaceColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header with icon and merchant
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (isDebit ? AppTheme.coral : AppTheme.successGreen)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDebit
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: isDebit ? AppTheme.coral : AppTheme.successGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.merchant.isEmpty
                              ? transaction.category
                              : transaction.merchant,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAmountWithCurrency(transaction),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDebit ? AppTheme.coral : AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Transaction Details Section
              _buildSectionHeader('Transaction Details'),
              const SizedBox(height: 12),
              _buildDetailRow('Merchant', transaction.merchant.isEmpty ? transaction.category : transaction.merchant),
              _buildDetailRow('Type', transaction.type == TransactionType.debit ? 'Debit' : 'Credit'),
              _buildDetailRow('Category', transaction.category),
              _buildDetailRow('Date', _formatDate(transaction.timestamp)),
              if (transaction.parserType != null)
                _buildDetailRow('Parser', _formatParserType(transaction.parserType!)),
              if (transaction.parserConfidence > 0)
                _buildDetailRow(
                  'Confidence',
                  '${(transaction.parserConfidence * 100).toStringAsFixed(0)}%',
                ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteTransaction(transaction);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditTransactionDialog(transaction);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Debug Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RawSmsScreen(initialTransactionId: transaction.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Debug Transaction'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isTitle
                  ? Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
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
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 140,
                floating: false,
                pinned: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.zero,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: ThemeHelper.backgroundGradient(context),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, top: 20, bottom: 60),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Transactions',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              actions: [
                IconButton(
                  icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _clearSearch();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.date_range, color: Colors.white),
                  onPressed: _showDateRangePicker,
                  tooltip: 'Date Range',
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
                  onPressed: _showFilterDialog,
                  tooltip: 'Filter by Category',
                ),
                AnimatedScale(
                  scale: _hasActiveFilters() ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _hasActiveFilters() ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _hasActiveFilters()
                        ? IconButton(
                            icon: const Icon(Icons.clear_all, color: Colors.white),
                            onPressed: _clearAllFilters,
                            tooltip: 'Clear All Filters',
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Expenses'),
                      Tab(text: 'Income'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
          body: Container(
            decoration: BoxDecoration(
              color: isDark ? scaffoldBg : AppTheme.whiteBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Animated Search bar
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showSearch
                      ? AnimatedOpacity(
                          opacity: _showSearch ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by merchant or category...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.coral),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: ThemeHelper.cardColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ThemeHelper.inputBorderColor(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.coral, width: 2),
                        ),
                      ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Filter chips
                if (_hasActiveFilters())
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_searchQuery.isNotEmpty)
                          _buildFilterChip(
                            label: 'Search: $_searchQuery',
                            onDelete: _clearSearch,
                          ),
                        ..._selectedCategories.map((category) =>
                          _buildFilterChip(
                            label: category,
                            onDelete: () {
                              setState(() {
                                _selectedCategories.remove(category);
                              });
                              _applyFilter();
                            },
                          ),
                        ),
                        ..._selectedPaymentMethods.map((paymentMethod) =>
                          _buildFilterChip(
                            label: _getPaymentMethodLabel(paymentMethod),
                            onDelete: () {
                              setState(() {
                                _selectedPaymentMethods.remove(paymentMethod);
                              });
                              _applyFilter();
                            },
                          ),
                        ),
                        if (_startDate != null && _endDate != null)
                          _buildFilterChip(
                            label: '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                            onDelete: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                              _applyFilter();
                            },
                          ),
                        if (_minAmount != null || _maxAmount != null)
                          _buildFilterChip(
                            label: '₹${_minAmount?.toStringAsFixed(0) ?? '0'} - ₹${_maxAmount?.toStringAsFixed(0) ?? '∞'}',
                            onDelete: () {
                              setState(() {
                                _minAmount = null;
                                _maxAmount = null;
                                _minAmountController.clear();
                                _maxAmountController.clear();
                              });
                              _applyFilter();
                            },
                          ),
                        if (_hasActiveFilters())
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.coral,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_hasActiveFilters())
                  const SizedBox(height: 8),
                // Content with TabBarView for swipeable tabs
                Expanded(
                  child: _isLoading
                      ? _buildShimmerLoading()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTabContent(0), // All
                            _buildTabContent(1), // Expenses
                            _buildTabContent(2), // Income
                          ],
                        ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final filteredTransactions = _getFilteredTransactions(tabIndex);
    final hasFilters = _hasActiveFilters();

    if (filteredTransactions.isEmpty) {
      return _buildEmptyState(hasFilters: hasFilters);
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: AppTheme.coral,
      child: Column(
        children: [
          // Statistics cards
          _buildStatisticsCards(filteredTransactions),
          // Transaction list
          Expanded(
            child: _buildTransactionsList(filteredTransactions),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({bool hasFilters = false}) {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: AppTheme.coral,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasFilters ? Icons.search_off_rounded : Icons.receipt_long_outlined,
                    size: 80,
                    color: AppTheme.coral,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                hasFilters ? 'No matching transactions' : 'No transactions yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  hasFilters
                      ? 'Try adjusting your filters or search terms'
                      : 'Start tracking your finances by adding transactions',
                  style: TextStyle(
                    fontSize: 15,
                    color: ThemeHelper.textSecondary(context),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              if (hasFilters)
                ElevatedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                )
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Show add transaction sheet
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddTransactionSheet(
                            onTransactionAdded: () {
                              _loadTransactions();
                              // Refresh Budget and Home screens
                              try {
                                final mainScreenState = context.findRootAncestorStateOfType<State>();
                                if (mainScreenState != null) {
                                  (mainScreenState as dynamic).refreshAfterTransactionChange();
                                }
                              } catch (e) {
                                // Ignore if method doesn't exist
                              }
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to settings to enable SMS fetching
                        Navigator.pushNamed(context, '/settings');
                      },
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Configure SMS Import'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.coral,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    // Group transactions by date
    final groupedTransactions = _groupTransactionsByDate(transactions);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateEntry = groupedTransactions.entries.elementAt(index);
        final date = dateEntry.key;
        final transactions = dateEntry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animated date header
            TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Text(
                  _formatDateHeader(date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
              ),
            ),
            ...transactions.asMap().entries.map((entry) {
              final transactionIndex = entry.key;
              final transaction = entry.value;
              return _buildAnimatedTransactionTile(transaction, index, transactionIndex);
            }).toList(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedTransactionTile(Transaction transaction, int groupIndex, int transactionIndex) {
    final delay = Duration(milliseconds: 350 + (groupIndex * 50) + (transactionIndex * 50));

    return TweenAnimationBuilder<double>(
      duration: delay,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _buildTransactionTile(transaction),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final isDebit = transaction.type == TransactionType.debit;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.horizontal,
      // Edit background (swipe right)
      background: Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.edit_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      // Delete background (swipe left)
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.coral,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();

        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Edit action
          _showEditTransactionDialog(transaction);
          return false; // Don't dismiss, just show edit dialog
        } else {
          // Swipe left - Delete action
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Delete Transaction'),
              content: Text('Delete transaction from ${transaction.merchant}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) async {
        // Only delete action dismisses
        await _transactionService.deleteTransaction(transaction.id);
        _loadTransactions();

        // Refresh Budget and Home screens to show updated spending
        try {
          final mainScreenState = context.findRootAncestorStateOfType<State>();
          if (mainScreenState != null) {
            (mainScreenState as dynamic).refreshAfterTransactionChange();
          }
        } catch (e) {
          // Ignore if method doesn't exist
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${transaction.merchant} deleted'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: ThemeHelper.cardDecoration(context),
        child: InkWell(
          onTap: () => _showTransactionDetails(transaction),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isDebit ? AppTheme.coral : AppTheme.successGreen)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDebit
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: isDebit ? AppTheme.coral : AppTheme.successGreen,
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
                        color: ThemeHelper.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          transaction.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeHelper.textSecondary(context),
                          ),
                        ),
                        if (transaction.autoCategorized) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: AppTheme.primaryPurple.withOpacity(0.6),
                          ),
                        ],
                        if (transaction.transactionId != null && transaction.transactionId!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 10,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'ID',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Source badge (SMS/PDF/Manual)
                        const SizedBox(width: 6),
                        _buildSourceBadge(transaction),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${isDebit ? '-' : '+'} ${_formatAmountWithCurrency(transaction)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDebit ? AppTheme.coral : AppTheme.successGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(List<Transaction> transactions) {
    final grouped = <DateTime, List<Transaction>>{};

    for (final transaction in transactions) {
      final date = DateTime(
        transaction.timestamp.year,
        transaction.timestamp.month,
        transaction.timestamp.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(transaction);
    }

    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildSourceBadge(Transaction transaction) {
    // Determine transaction source based on parserType and rawMessage
    String sourceLabel;
    Color backgroundColor;
    Color textColor;
    IconData icon;

    final parserType = transaction.parserType;
    final rawMessage = transaction.rawMessage;

    if (parserType != null && (parserType.contains('Email') || parserType.startsWith('Email-'))) {
      // Email source (supports 'Email-LLM', 'Email-2Step-LLM', etc.)
      sourceLabel = 'Email';
      backgroundColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue[700]!;
      icon = Icons.email;
    } else if (rawMessage.isEmpty || rawMessage == 'Manual Entry') {
      // Manual entry
      sourceLabel = 'Manual';
      backgroundColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange[700]!;
      icon = Icons.edit;
    } else {
      // SMS source (default)
      sourceLabel = 'SMS';
      backgroundColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green[700]!;
      icon = Icons.sms;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: textColor,
          ),
          const SizedBox(width: 2),
          Text(
            sourceLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.decimalPattern('en_IN').format(amount);
  }

  /// Format amount with currency display (original + converted)
  String _formatAmountWithCurrency(Transaction transaction) {
    final amount = transaction.amount ?? 0;
    final formatted = _formatAmount(amount);

    // If transaction has original currency (not INR), show both
    if (transaction.originalCurrency != null &&
        transaction.originalCurrency != 'INR' &&
        transaction.originalAmount != null) {
      final originalFormatted = _formatAmount(transaction.originalAmount!);
      // Get currency symbol
      final currencySymbol = _getCurrencySymbol(transaction.originalCurrency!);
      return '$currencySymbol$originalFormatted (₹$formatted)';
    }

    // Default: INR only
    return '₹$formatted';
  }

  /// Get currency symbol for common currencies
  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'AED':
      case 'SAR':
      case 'QAR':
        return currencyCode + ' ';
      default:
        return currencyCode + ' ';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy h:mm a').format(date);
  }

  String _getPaymentMethodLabel(String paymentMethod) {
    if (paymentMethod == 'XUPI') {
      return 'UPI';
    }
    return 'Card ****$paymentMethod';
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: ThemeHelper.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories.clear();
                          _selectedPaymentMethods.clear();
                          _minAmount = null;
                          _maxAmount = null;
                          _minAmountController.clear();
                          _maxAmountController.clear();
                        });
                        setModalState(() {});
                        _applyFilter();
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
              const Divider(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categories Section
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((category) {
                          final isSelected = _selectedCategories.contains(category.name);
                          return FilterChip(
                            selected: isSelected,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(category.icon, size: 16, color: isSelected ? Colors.white : category.color),
                                const SizedBox(width: 6),
                                Text(category.name),
                              ],
                            ),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _selectedCategories.add(category.name);
                                } else {
                                  _selectedCategories.remove(category.name);
                                }
                              });
                            },
                            selectedColor: category.color,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : ThemeHelper.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Payment Methods Section
                      Text(
                        'Payment Methods',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<Map<String, int>>(
                        future: _transactionService.getUniqueAccounts(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Text(
                              'No payment methods found',
                              style: TextStyle(
                                color: ThemeHelper.textSecondary(context),
                                fontSize: 14,
                              ),
                            );
                          }

                          final paymentMethods = snapshot.data!;
                          // Add XUPI if exists
                          final allMethods = <String>[];
                          // Check if there are UPI transactions
                          final hasUPI = _transactions.any((t) => t.accountLastDigits == 'XUPI');
                          if (hasUPI) {
                            allMethods.add('XUPI');
                          }
                          allMethods.addAll(paymentMethods.keys);

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allMethods.map((method) {
                              final isSelected = _selectedPaymentMethods.contains(method);
                              final count = method == 'XUPI'
                                  ? _transactions.where((t) => t.accountLastDigits == 'XUPI').length
                                  : paymentMethods[method] ?? 0;

                              return FilterChip(
                                selected: isSelected,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      method == 'XUPI' ? Icons.account_balance_wallet : Icons.credit_card,
                                      size: 16,
                                      color: isSelected ? Colors.white : AppTheme.coral,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(_getPaymentMethodLabel(method)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($count)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected ? Colors.white70 : ThemeHelper.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      _selectedPaymentMethods.add(method);
                                    } else {
                                      _selectedPaymentMethods.remove(method);
                                    }
                                  });
                                },
                                selectedColor: AppTheme.coral,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : ThemeHelper.textPrimary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Amount Range Section
                      Text(
                        'Amount Range',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Min Amount',
                                prefixText: '₹',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: ThemeHelper.cardColor(context),
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  _minAmount = double.tryParse(value);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _maxAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max Amount',
                                prefixText: '₹',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: ThemeHelper.cardColor(context),
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  _maxAmount = double.tryParse(value);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Apply Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Trigger rebuild with new filters
                    });
                    _applyFilter();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onDelete}) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDelete,
      backgroundColor: AppTheme.coral.withOpacity(0.1),
      deleteIconColor: AppTheme.coral,
      labelStyle: const TextStyle(
        color: AppTheme.coral,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.coral.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildStatisticsCards(List<Transaction> transactions) {
    // Calculate statistics
    double totalSpent = 0;
    double totalEarned = 0;

    for (final transaction in transactions) {
      if (transaction.amount != null) {
        if (transaction.type == TransactionType.debit) {
          totalSpent += transaction.amount!;
        } else if (transaction.type == TransactionType.credit) {
          totalEarned += transaction.amount!;
        }
      }
    }

    final net = totalEarned - totalSpent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Total Spent Card
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: totalSpent),
              builder: (context, value, child) {
                return _buildStatCard(
                  title: 'Spent',
                  amount: value,
                  icon: Icons.arrow_upward_rounded,
                  color: AppTheme.coral,
                  isDark: isDark,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Total Earned Card
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: totalEarned),
              builder: (context, value, child) {
                return _buildStatCard(
                  title: 'Earned',
                  amount: value,
                  icon: Icons.arrow_downward_rounded,
                  color: AppTheme.successGreen,
                  isDark: isDark,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Net Card
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: net),
              builder: (context, value, child) {
                return _buildStatCard(
                  title: 'Net',
                  amount: value,
                  icon: Icons.account_balance_wallet_rounded,
                  color: net >= 0 ? AppTheme.successGreen : AppTheme.coral,
                  isDark: isDark,
                  showSign: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool showSign = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: ThemeHelper.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${showSign && amount >= 0 ? '+' : ''}₹${_formatAmount(amount.abs())}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Icon placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Text placeholders
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Amount placeholder
                Container(
                  width: 80,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.coral,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.coral,
          ),
        ),
      ],
    );
  }

  String _formatParserType(String parserType) {
    if (parserType == 'Email-2Step-LLM') {
      return 'Email LLM (2-Step)';
    } else if (parserType == 'Email-LLM') {
      return 'Email LLM';
    } else if (parserType.contains('llm')) {
      return 'LLM Text Parser';
    } else if (parserType.contains('regex')) {
      return 'Regex Parser';
    }
    return parserType;
  }
}

class _DateRangePickerSheet extends StatelessWidget {
  final DateTime? currentStart;
  final DateTime? currentEnd;
  final Function(DateTime start, DateTime end) onRangeSelected;
  final VoidCallback onClear;

  const _DateRangePickerSheet({
    required this.currentStart,
    required this.currentEnd,
    required this.onRangeSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final now = DateTime.now();

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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.textPrimary(context),
                    ),
                  ),
                  if (currentStart != null && currentEnd != null)
                    TextButton(
                      onPressed: () {
                        onClear();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),

            // Quick presets
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildPresetTile(
                    context,
                    'Today',
                    Icons.today,
                    () {
                      final today = DateTime(now.year, now.month, now.day);
                      onRangeSelected(today, now);
                      Navigator.pop(context);
                    },
                  ),
                  _buildPresetTile(
                    context,
                    'Last 7 Days',
                    Icons.date_range,
                    () {
                      final start = now.subtract(const Duration(days: 7));
                      onRangeSelected(start, now);
                      Navigator.pop(context);
                    },
                  ),
                  _buildPresetTile(
                    context,
                    'Last 30 Days',
                    Icons.calendar_month,
                    () {
                      final start = now.subtract(const Duration(days: 30));
                      onRangeSelected(start, now);
                      Navigator.pop(context);
                    },
                  ),
                  _buildPresetTile(
                    context,
                    'This Month',
                    Icons.calendar_today,
                    () {
                      final start = DateTime(now.year, now.month, 1);
                      onRangeSelected(start, now);
                      Navigator.pop(context);
                    },
                  ),
                  _buildPresetTile(
                    context,
                    'Last Month',
                    Icons.calendar_view_month,
                    () {
                      final lastMonth = DateTime(now.year, now.month - 1, 1);
                      final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
                      onRangeSelected(lastMonth, lastDayOfLastMonth);
                      Navigator.pop(context);
                    },
                  ),
                  _buildPresetTile(
                    context,
                    'This Year',
                    Icons.calendar_today_outlined,
                    () {
                      final start = DateTime(now.year, 1, 1);
                      onRangeSelected(start, now);
                      Navigator.pop(context);
                    },
                  ),
                  _buildPresetTile(
                    context,
                    'Last Year',
                    Icons.event_note,
                    () {
                      final start = DateTime(now.year - 1, 1, 1);
                      final end = DateTime(now.year - 1, 12, 31);
                      onRangeSelected(start, end);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 32),
                  _buildPresetTile(
                    context,
                    'Custom Range',
                    Icons.edit_calendar,
                    () async {
                      Navigator.pop(context);
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: currentStart != null && currentEnd != null
                            ? DateTimeRange(start: currentStart!, end: currentEnd!)
                            : null,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? ColorScheme.dark(
                                      primary: AppTheme.coral,
                                      onPrimary: Colors.white,
                                      surface: AppTheme.cardBackgroundDark,
                                      onSurface: AppTheme.textPrimaryDark,
                                    )
                                  : const ColorScheme.light(
                                      primary: AppTheme.coral,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        onRangeSelected(picked.start, picked.end);
                      }
                    },
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

  Widget _buildPresetTile(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.coral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.coral, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: ThemeHelper.textSecondary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
