import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class InsightsCard extends StatelessWidget {
  final double totalSpending;
  final double lastMonthSpending;
  final Map<String, double> topCategories;
  final List<String> topMerchants;

  const InsightsCard({
    super.key,
    required this.totalSpending,
    required this.lastMonthSpending,
    required this.topCategories,
    required this.topMerchants,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spendingChange = lastMonthSpending > 0
        ? ((totalSpending - lastMonthSpending) / lastMonthSpending) * 100
        : 0.0;
    final isIncrease = spendingChange > 0;

    return Container(
      decoration: AppDecorations.elevatedCard(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: AppTheme.primaryPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Insights',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Monthly Comparison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isIncrease
                  ? AppTheme.errorRed.withAlpha((0.1 * 255).toInt())
                  : AppTheme.successGreen.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isIncrease ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: isIncrease ? AppTheme.errorRed : AppTheme.successGreen,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isIncrease ? '+' : ''}${spendingChange.toStringAsFixed(1)}% vs last month',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isIncrease ? AppTheme.errorRed : AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isIncrease
                            ? 'You spent more this month'
                            : 'Great! You spent less this month',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Top Categories
          if (topCategories.isNotEmpty) ...[
            Text(
              'Top Spending Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...topCategories.entries.take(3).map((entry) {
              final percentage = (totalSpending > 0 ? (entry.value / totalSpending) * 100 : 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '₹${_formatAmount(entry.value)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${percentage.toStringAsFixed(0)}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],

          // Top Merchants
          if (topMerchants.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Frequent Merchants',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topMerchants.take(5).map((merchant) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    merchant,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.decimalPattern('en_IN').format(amount);
  }
}
