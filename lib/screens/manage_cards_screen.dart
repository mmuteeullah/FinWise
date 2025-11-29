import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class ManageCardsScreen extends StatefulWidget {
  const ManageCardsScreen({super.key});

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Map<String, Map<String, dynamic>> _accounts = {};
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    final accounts = await _db.getAccountsWithPreferences();

    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  Future<void> _toggleVisibility(String accountDigits, bool isVisible) async {
    // Update or create preference
    await _db.upsertCardPreference({
      'account_last_digits': accountDigits,
      'is_visible': isVisible ? 1 : 0,
      'card_type': _accounts[accountDigits]?['card_type'] ?? 'credit',
    });

    setState(() {
      _accounts[accountDigits]?['is_visible'] = isVisible ? 1 : 0;
      _hasChanges = true;
    });
  }

  Future<void> _editCard(String accountDigits) async {
    final account = _accounts[accountDigits];
    if (account == null) return;

    final nicknameController = TextEditingController(
      text: account['card_nickname']?.toString() ?? '',
    );
    final issuerController = TextEditingController(
      text: account['card_issuer']?.toString() ?? '',
    );
    String selectedType = account['card_type']?.toString() ?? 'credit';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = ThemeHelper.isDark(context);

            return AlertDialog(
              backgroundColor: isDark
                  ? AppTheme.cardBackgroundDark
                  : AppTheme.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Edit Card ••$accountDigits',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nickname
                    TextField(
                      controller: nicknameController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nickname (Optional)',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        hintText: 'e.g., HDFC Regalia',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.coral),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Issuer
                    TextField(
                      controller: issuerController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Bank/Issuer (Optional)',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        hintText: 'e.g., HDFC, SBI, ICICI',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.coral),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card Type Dropdown
                    Text(
                      'Card Type',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          dropdownColor: isDark
                              ? AppTheme.cardBackgroundDark
                              : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'credit',
                              child: Text('Credit Card'),
                            ),
                            DropdownMenuItem(
                              value: 'debit',
                              child: Text('Debit Card'),
                            ),
                            DropdownMenuItem(
                              value: 'prepaid',
                              child: Text('Prepaid Card'),
                            ),
                            DropdownMenuItem(
                              value: 'bank_account',
                              child: Text('Bank Account'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                      ),
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
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'nickname': nicknameController.text.trim(),
                      'issuer': issuerController.text.trim(),
                      'type': selectedType,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _db.upsertCardPreference({
        'account_last_digits': accountDigits,
        'is_visible': account['is_visible'],
        'card_nickname': result['nickname']?.isNotEmpty == true ? result['nickname'] : null,
        'card_issuer': result['issuer']?.isNotEmpty == true ? result['issuer'] : null,
        'card_type': result['type'],
      });

      setState(() {
        _accounts[accountDigits]?['card_nickname'] = result['nickname'];
        _accounts[accountDigits]?['card_issuer'] = result['issuer'];
        _accounts[accountDigits]?['card_type'] = result['type'];
        _hasChanges = true;
      });
    }
  }

  Future<void> _applyChanges() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.coral),
      ),
    );

    // Reload card carousel data
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context, true); // Return to settings with success flag
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    // Separate accounts into categories
    final visibleCards = <String, Map<String, dynamic>>{};
    final hiddenCards = <String, Map<String, dynamic>>{};
    final suspectedNonCards = <String, Map<String, dynamic>>{};

    for (final entry in _accounts.entries) {
      final account = entry.value;
      final transactionCount = account['transaction_count'] as int;
      final isVisible = (account['is_visible'] ?? 1) == 1;

      if (transactionCount == 1) {
        // Likely not a card (only 1 transaction)
        suspectedNonCards[entry.key] = account;
      } else if (isVisible) {
        visibleCards[entry.key] = account;
      } else {
        hiddenCards[entry.key] = account;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => _applyChanges(),
        ),
        title: Text(
          'Manage Payment Methods',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.coral),
            )
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_off,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No cards detected',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cards will appear here after parsing transactions',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.coral,
                  onRefresh: _loadAccounts,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Visible Cards Section
                      if (visibleCards.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Visible Cards (${visibleCards.length})',
                          Icons.credit_card,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        ...visibleCards.entries.map(
                          (entry) => _buildCardTile(entry.key, entry.value, isDark),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Hidden Cards Section
                      if (hiddenCards.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Hidden Cards (${hiddenCards.length})',
                          Icons.visibility_off,
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        ...hiddenCards.entries.map(
                          (entry) => _buildCardTile(entry.key, entry.value, isDark),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Suspected Non-Cards Section
                      if (suspectedNonCards.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Suspected Non-Cards (${suspectedNonCards.length})',
                          Icons.warning_amber_rounded,
                          isDark,
                          subtitle: 'Only 1 transaction detected',
                        ),
                        const SizedBox(height: 12),
                        ...suspectedNonCards.entries.map(
                          (entry) => _buildCardTile(entry.key, entry.value, isDark),
                        ),
                      ],
                    ],
                  ),
                ),
      bottomNavigationBar: _hasChanges
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardBackgroundDark
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _applyChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark, {String? subtitle}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black26,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardTile(String accountDigits, Map<String, dynamic> account, bool isDark) {
    final isVisible = (account['is_visible'] ?? 1) == 1;
    final transactionCount = account['transaction_count'] as int;
    final nickname = account['card_nickname']?.toString();
    final issuer = account['card_issuer']?.toString();
    final cardType = account['card_type']?.toString() ?? 'credit';

    String displayName = '••$accountDigits';
    if (nickname != null && nickname.isNotEmpty) {
      displayName = nickname;
    } else if (issuer != null && issuer.isNotEmpty) {
      displayName = '$issuer ••$accountDigits';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isVisible
                ? AppTheme.coral.withOpacity(0.1)
                : isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getCardIcon(cardType),
            color: isVisible
                ? AppTheme.coral
                : isDark
                    ? Colors.white30
                    : Colors.black26,
            size: 24,
          ),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getCardTypeDisplay(cardType),
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$transactionCount transaction${transactionCount != 1 ? 's' : ''}',
              style: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit,
                color: isDark ? Colors.white60 : Colors.black54,
                size: 20,
              ),
              onPressed: () => _editCard(accountDigits),
            ),
            Switch(
              value: isVisible,
              onChanged: (value) => _toggleVisibility(accountDigits, value),
              activeColor: AppTheme.coral,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'credit':
        return Icons.credit_card;
      case 'debit':
        return Icons.payment;
      case 'prepaid':
        return Icons.card_giftcard;
      case 'bank_account':
        return Icons.account_balance;
      default:
        return Icons.credit_card;
    }
  }

  String _getCardTypeDisplay(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'credit':
        return 'Credit Card';
      case 'debit':
        return 'Debit Card';
      case 'prepaid':
        return 'Prepaid Card';
      case 'bank_account':
        return 'Bank Account';
      default:
        return cardType;
    }
  }
}
