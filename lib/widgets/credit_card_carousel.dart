import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/transaction_service.dart';
import '../services/database_helper.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';
import 'card_transactions_bottom_sheet.dart';

class CreditCardModel {
  final String cardNumber;
  final String cardIdentifier; // e.g., "1234", "XUPI", "Others"
  final double balance;
  final DateTime expiryDate;
  final int transactionCount;

  const CreditCardModel({
    required this.cardNumber,
    required this.cardIdentifier,
    required this.balance,
    required this.expiryDate,
    this.transactionCount = 0,
  });
}

class CreditCardCarousel extends StatefulWidget {
  final Function(int)? onPageChanged;

  const CreditCardCarousel({
    Key? key,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<CreditCardCarousel> createState() => _CreditCardCarouselState();
}

class _CreditCardCarouselState extends State<CreditCardCarousel> {
  final TransactionService _transactionService = TransactionService();
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
    initialPage: 0,
  );
  List<CreditCardModel> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _transactionService.getUniqueAccounts();
      final allTransactions = await _transactionService.getAllTransactions();

      // Get card preferences to filter visible cards
      final accountsWithPrefs = await DatabaseHelper.instance.getAccountsWithPreferences();

      List<CreditCardModel> cards = [];

      // Separate transactions into UPI, card, and other
      final upiTransactions = allTransactions
          .where((t) => t.accountLastDigits == 'XUPI')
          .toList();

      final otherTransactions = allTransactions
          .where((t) => t.accountLastDigits == null || t.accountLastDigits!.isEmpty)
          .toList();

      // Add UPI card FIRST if there are UPI transactions
      if (upiTransactions.isNotEmpty) {
        double upiSpending = 0;
        for (var transaction in upiTransactions) {
          final amount = transaction.amount ?? 0.0;
          if (transaction.type == TransactionType.debit) {
            upiSpending += amount;
          }
        }

        cards.add(CreditCardModel(
          cardNumber: 'UPI',
          cardIdentifier: 'XUPI',
          balance: upiSpending,
          expiryDate: DateTime.now().add(const Duration(days: 365 * 2)),
          transactionCount: upiTransactions.length,
        ));
      }

      // Add "Others" card for non-card/non-UPI transactions
      if (otherTransactions.isNotEmpty) {
        double otherSpending = 0;
        for (var transaction in otherTransactions) {
          final amount = transaction.amount ?? 0.0;
          if (transaction.type == TransactionType.debit) {
            otherSpending += amount;
          }
        }

        cards.add(CreditCardModel(
          cardNumber: 'Others',
          cardIdentifier: 'Others',
          balance: otherSpending,
          expiryDate: DateTime.now().add(const Duration(days: 365 * 2)),
          transactionCount: otherTransactions.length,
        ));
      }

      // Add individual credit card accounts (only visible ones)
      for (var entry in accounts.entries) {
        final accountDigits = entry.key;

        // Check if card is hidden in preferences
        final accountPref = accountsWithPrefs[accountDigits];
        final isVisible = accountPref?['is_visible'] ?? 1;

        // Skip hidden cards
        if (isVisible == 0) {
          print('Skipping hidden card: $accountDigits');
          continue;
        }

        final cardTransactions = allTransactions
            .where((t) => t.accountLastDigits == accountDigits)
            .toList();

        double cardSpending = 0;
        for (var transaction in cardTransactions) {
          final amount = transaction.amount ?? 0.0;
          if (transaction.type == TransactionType.debit) {
            cardSpending += amount;
          }
        }

        // Get display name from preferences
        String displayName = 'XXXXXXXXXXXX$accountDigits';
        final nickname = accountPref?['card_nickname']?.toString();
        final issuer = accountPref?['card_issuer']?.toString();

        if (nickname != null && nickname.isNotEmpty) {
          displayName = nickname;
        } else if (issuer != null && issuer.isNotEmpty) {
          displayName = '$issuer XX$accountDigits';
        }

        cards.add(CreditCardModel(
          cardNumber: displayName,
          cardIdentifier: accountDigits,
          balance: cardSpending,
          expiryDate: DateTime.now().add(const Duration(days: 365 * 2)),
          transactionCount: entry.value,
        ));
      }

      setState(() {
        _cards = cards;
        _isLoading = false;
      });

      // Ensure carousel starts at the first card
      if (cards.isNotEmpty && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }
    } catch (e) {
      print('Error loading cards: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showCardTransactions(BuildContext context, CreditCardModel card) async {
    // Get all transactions for this card
    final allTransactions = await _transactionService.getAllTransactions();
    final cardTransactions = allTransactions.where((t) {
      if (card.cardIdentifier == 'XUPI') {
        return t.accountLastDigits == 'XUPI';
      } else if (card.cardIdentifier == 'Others') {
        return t.accountLastDigits == null || t.accountLastDigits!.isEmpty;
      } else {
        return t.accountLastDigits == card.cardIdentifier;
      }
    }).toList();

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CardTransactionsBottomSheet(
        cardIdentifier: card.cardIdentifier,
        cardDisplayName: card.cardNumber,
        transactions: cardTransactions,
        onTransactionUpdated: () {
          // Reload cards after transaction update
          _loadCards();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_cards.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No cards found',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          widget.onPageChanged?.call(index);
        },
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final card = _cards[index];

          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                final page = _pageController.page ?? 0.0;
                value = page - index;
                value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
              } else {
                // Handle initial state before dimensions are available
                value = index == 0 ? 1.0 : 0.7;
              }

              return Center(
                child: SizedBox(
                  height: Curves.easeInOut.transform(value) * 220,
                  child: Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: GestureDetector(
                        onTap: () => _showCardTransactions(context, card),
                        child: CreditCardWidget(card: card),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CreditCardWidget extends StatelessWidget {
  final CreditCardModel card;

  const CreditCardWidget({
    Key? key,
    required this.card,
  }) : super(key: key);

  String _obscureCardNumber(String cardNumber) {
    // If it's the UPI or Others card, don't obscure it
    if (cardNumber == 'UPI' || cardNumber == 'Others') {
      return cardNumber;
    }

    // If it's a custom nickname (doesn't start with X's or contain "XX"), don't obscure it
    // Nicknames are user-friendly names like "SAPPIRO", "HDFC Regalia", etc.
    if (!cardNumber.startsWith('X') && !cardNumber.contains('XX')) {
      return cardNumber;
    }

    // Only obscure actual card numbers (e.g., "XXXXXXXXXXXX2008" or "HDFC XX2008")
    if (cardNumber.length < 4) return cardNumber;
    String obscured = '';
    for (int i = 0; i < cardNumber.length; i++) {
      if (i > 0 && i % 4 == 0) {
        obscured += ' ';
      }
      if (i < cardNumber.length - 4) {
        obscured += '•';
      } else {
        obscured += cardNumber[i];
      }
    }
    return obscured;
  }

  String _formatBalance(double balance) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(balance);
  }

  String _dateToExpiry(DateTime dateTime) {
    return DateFormat('MM/yy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppDecorations.bankGlassmorphicCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Spending',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.25),
                      offset: const Offset(0, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatBalance(card.balance),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 32,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.25),
                      offset: const Offset(0, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _obscureCardNumber(card.cardNumber),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.25),
                      offset: const Offset(0, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valid Thru',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _dateToExpiry(card.expiryDate),
                        style: const TextStyle(
                          color: Colors.white,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      card.cardNumber == 'UPI'
                          ? Icons.account_balance_wallet_rounded
                          : card.cardNumber == 'Others'
                              ? Icons.more_horiz_rounded
                              : Icons.credit_card,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
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
}
