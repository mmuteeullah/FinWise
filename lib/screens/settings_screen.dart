import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/exchange_rate_service.dart';
import '../services/biometric_service.dart';
import '../services/icloud_backup_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../theme/theme_helper.dart';
import 'raw_sms_screen.dart';
import 'llm_settings_screen.dart';
import 'manage_transactions_screen.dart';
import 'manage_cards_screen.dart';
import 'email_settings_screen.dart';
import 'email_inbox_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;

  // Biometric authentication state
  final BiometricService _biometricService = BiometricService();
  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  String _biometricTypeName = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load biometric settings
    final biometricSupported = await _biometricService.isDeviceSupported();
    final biometricEnabled = await _biometricService.isBiometricLockEnabled();
    final biometricTypeName = await _biometricService.getPrimaryBiometricName();

    setState(() {
      _biometricSupported = biometricSupported;
      _biometricEnabled = biometricEnabled;
      _biometricTypeName = biometricTypeName;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometricLock(bool value) async {
    if (!_biometricSupported) {
      _showSnackBar('Biometric authentication is not available on this device', isError: true);
      return;
    }

    final success = await _biometricService.setBiometricLockEnabled(value);

    if (success) {
      setState(() {
        _biometricEnabled = value;
      });
      _showSnackBar(
        value
          ? '$_biometricTypeName lock enabled'
          : '$_biometricTypeName lock disabled'
      );
    } else {
      _showSnackBar(
        'Failed to ${value ? 'enable' : 'disable'} $_biometricTypeName lock',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    // Header with gradient background
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settings',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Customize your experience',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.sync_rounded, color: Colors.white),
                              onPressed: _loadData,
                              tooltip: 'Refresh',
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
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPreferencesSection(),
                              const SizedBox(height: 24),
                              _buildCurrencySection(),
                              const SizedBox(height: 24),
                              _buildDataManagementSection(),
                              const SizedBox(height: 24),
                              _buildDeveloperSection(),
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

  Widget _buildPreferencesSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildThemeSelector(themeProvider),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          _buildNavigationTile(
            'LLM Integration',
            'Configure AI-powered transaction parsing',
            Icons.smart_toy,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LLMSettingsScreen(),
                ),
              );
            },
          ),
          if (_biometricSupported) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildBiometricToggle(),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exchangeRateService = ExchangeRateService.instance;

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currency Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<DateTime?>(
            future: exchangeRateService.getLastUpdateTime(),
            builder: (context, snapshot) {
              final lastUpdate = snapshot.data;
              final needsRefresh = lastUpdate == null ||
                  DateTime.now().difference(lastUpdate) > const Duration(hours: 24);

              String statusText = 'Checking...';
              Color statusColor = Colors.grey;

              if (snapshot.hasData) {
                if (lastUpdate == null) {
                  statusText = 'Not synced';
                  statusColor = Colors.orange;
                } else if (needsRefresh) {
                  final age = DateTime.now().difference(lastUpdate);
                  statusText = 'Expired (${age.inDays}d ago)';
                  statusColor = Colors.orange;
                } else {
                  final age = DateTime.now().difference(lastUpdate);
                  if (age.inHours < 1) {
                    statusText = 'Up to date (${age.inMinutes}m ago)';
                  } else {
                    statusText = 'Up to date (${age.inHours}h ago)';
                  }
                  statusColor = Colors.green;
                }
              }

              return Column(
                children: [
                  _buildCurrencyInfoRow('Exchange Rates', statusText, statusColor),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildActionTile(
                    'Sync Exchange Rates',
                    'Update currency conversion rates',
                    Icons.sync,
                    () async {
                      _showSnackBar('Syncing exchange rates...');
                      final success = await exchangeRateService.refreshRates(force: true);
                      if (success) {
                        setState(() {}); // Refresh UI
                        _showSnackBar('Exchange rates updated successfully!');
                      } else {
                        _showSnackBar('Failed to sync rates. Using fallback.', isError: true);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyInfoRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.currency_exchange, color: AppTheme.primaryPurple, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.coral, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.coral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.palette_rounded, color: AppTheme.coral, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose your preferred theme',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textSecondaryDark : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildThemeOption(
                'Light',
                Icons.light_mode_rounded,
                AppThemeMode.light,
                themeProvider.themeMode == AppThemeMode.light,
                () async {
                  await themeProvider.setThemeMode(AppThemeMode.light);
                  if (mounted) {
                    _showSnackBar('Light mode enabled ☀️');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildThemeOption(
                'Dark',
                Icons.dark_mode_rounded,
                AppThemeMode.dark,
                themeProvider.themeMode == AppThemeMode.dark,
                () async {
                  await themeProvider.setThemeMode(AppThemeMode.dark);
                  if (mounted) {
                    _showSnackBar('Dark mode enabled 🌙');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildThemeOption(
                'OLED',
                Icons.brightness_2_rounded,
                AppThemeMode.oledBlack,
                themeProvider.themeMode == AppThemeMode.oledBlack,
                () async {
                  await themeProvider.setThemeMode(AppThemeMode.oledBlack);
                  if (mounted) {
                    _showSnackBar('OLED Black mode enabled 🖤');
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    String label,
    IconData icon,
    AppThemeMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple.withOpacity(0.15)
              : (isDark ? AppTheme.cardBackgroundDark : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.surfaceColorDark.withOpacity(0.3) : Colors.transparent),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryPurple
                  : (isDark ? AppTheme.textSecondaryDark : Colors.grey[600]),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryPurple
                    : (isDark ? AppTheme.textSecondaryDark : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.purple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeHelper.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: ThemeHelper.textSecondary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricToggle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.coral.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _biometricTypeName == 'Face ID'
                ? Icons.face
                : Icons.fingerprint,
            color: AppTheme.coral,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_biometricTypeName Lock',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Secure app with $_biometricTypeName',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeHelper.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _biometricEnabled,
          onChanged: _toggleBiometricLock,
          activeColor: AppTheme.coral,
        ),
      ],
    );
  }

  Widget _buildDataManagementSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.storage_rounded, color: AppTheme.coral, size: 20),
              const SizedBox(width: 8),
              Text(
                'Data Management',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.credit_card_rounded, color: Colors.blue, size: 24),
                ),
                title: const Text(
                  'Manage Payment Methods',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: const Text('Configure visible cards'),
                trailing: Icon(Icons.arrow_forward_rounded, color: ThemeHelper.textSecondary(context)),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageCardsScreen()),
                  );

                  // Refresh if changes were made
                  if (result == true && mounted) {
                    setState(() {});
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_upload_rounded, color: AppTheme.successGreen, size: 24),
                ),
                title: const Text(
                  'Create Backup',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: const Text('Encrypted backup (accessible in Files app)'),
                trailing: Icon(Icons.arrow_forward_rounded, color: ThemeHelper.textSecondary(context)),
                onTap: _createBackup,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_download_rounded, color: AppTheme.warningOrange, size: 24),
                ),
                title: const Text(
                  'Restore from Backup',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: const Text('Restore data from backup file'),
                trailing: Icon(Icons.arrow_forward_rounded, color: ThemeHelper.textSecondary(context)),
                onTap: _restoreFromBackup,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.manage_accounts_rounded, color: AppTheme.errorRed, size: 24),
                ),
                title: const Text(
                  'Manage Transactions',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: const Text('Clear data and reset rules'),
                trailing: Icon(Icons.chevron_right_rounded, color: ThemeHelper.textSecondary(context)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageTransactionsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.code_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Developer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.message_rounded, color: Colors.orange, size: 24),
            ),
            title: const Text(
              'Transaction Debug Log',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: const Text('View raw transaction data & debug parsing'),
            trailing: Icon(Icons.chevron_right_rounded, color: ThemeHelper.textSecondary(context)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RawSmsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.coral.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.email_rounded, color: AppTheme.coral, size: 24),
            ),
            title: const Text(
              'Email Integration',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: const Text('Connect and manage Gmail accounts'),
            trailing: Icon(Icons.chevron_right_rounded, color: ThemeHelper.textSecondary(context)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmailSettingsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.purple.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inbox_rounded, color: AppTheme.purple, size: 24),
            ),
            title: const Text(
              'Email Inbox',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: const Text('View synced transactional emails'),
            trailing: Icon(Icons.chevron_right_rounded, color: ThemeHelper.textSecondary(context)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmailInboxScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  // Local Backup Methods

  Future<void> _createBackup() async {
    final backupService = ICloudBackupService.instance;

    // Check storage availability
    final isAvailable = await backupService.isBackupStorageAvailable();
    if (!isAvailable && mounted) {
      _showErrorDialog(
        'Storage Not Available',
        'Unable to access storage for backup.',
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = ThemeHelper.isDark(context);
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground,
          title: Text(
            'Create Backup',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'This will create an encrypted backup of your database. The backup will be secured with Face ID/Touch ID and accessible in the Files app.\n\nYou can manually copy it to iCloud Drive or share it.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Backup'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.successGreen),
      ),
    );

    try {
      // Perform backup
      final success = await backupService.createBackup();

      if (mounted) {
        Navigator.pop(context); // Close progress

        if (success) {
          _showSuccessDialog(
            'Backup Successful',
            'Your data has been securely backed up.\n\nAccess it in: Files app → On My iPhone → FinWise → Backups\n\nYou can copy it to iCloud Drive manually.',
          );
        } else {
          _showErrorDialog(
            'Backup Failed',
            'Unable to create backup. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress
        _showErrorDialog(
          'Backup Error',
          'An error occurred: $e',
        );
      }
    }
  }

  Future<void> _restoreFromBackup() async {
    final backupService = ICloudBackupService.instance;

    // Check storage availability
    final isAvailable = await backupService.isBackupStorageAvailable();
    if (!isAvailable && mounted) {
      _showErrorDialog(
        'Storage Not Available',
        'Unable to access storage.',
      );
      return;
    }

    // List available backups
    final backups = await backupService.listBackups();

    if (backups.isEmpty && mounted) {
      _showErrorDialog(
        'No Backups Found',
        'No backups were found. Create a backup first.',
      );
      return;
    }

    if (!mounted) return;

    // Show backup selection dialog
    final selectedBackup = await showDialog<BackupInfo>(
      context: context,
      builder: (context) {
        final isDark = ThemeHelper.isDark(context);
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground,
          title: Text(
            'Select Backup to Restore',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  leading: Icon(
                    backup.encrypted ? Icons.lock : Icons.lock_open,
                    color: backup.encrypted ? AppTheme.successGreen : AppTheme.warningOrange,
                  ),
                  title: Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(backup.created),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${backup.formattedSize} • ${backup.encrypted ? "Encrypted" : "Unencrypted"}',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        );
      },
    );

    if (selectedBackup == null) return;

    // Show warning dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = ThemeHelper.isDark(context);
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground,
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: AppTheme.warningOrange),
              const SizedBox(width: 8),
              Text(
                'Warning',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          content: Text(
            'This will replace all your current data with the backup from ${DateFormat('MMM dd, yyyy HH:mm').format(selectedBackup.created)}.\n\nYour current data will be backed up before restore.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppTheme.warningOrange),
      ),
    );

    try {
      // Perform restore
      final success = await backupService.restoreBackup(
        backupPath: selectedBackup.path,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress

        if (success) {
          _showSuccessDialog(
            'Restore Successful',
            'Your data has been restored from backup. Please restart the app to see the changes.',
          );
        } else {
          _showErrorDialog(
            'Restore Failed',
            'Unable to restore backup. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress
        _showErrorDialog(
          'Restore Error',
          'An error occurred: $e',
        );
      }
    }
  }

  void _showSuccessDialog(String title, String message) {
    final isDark = ThemeHelper.isDark(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    final isDark = ThemeHelper.isDark(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground,
        title: Row(
          children: [
            Icon(Icons.error, color: AppTheme.errorRed),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
