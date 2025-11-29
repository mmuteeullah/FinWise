import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:background_fetch/background_fetch.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/manage_categories_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/add_transaction_sheet.dart';
import 'widgets/biometric_lock_wrapper.dart';
import 'services/background_email_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register headless task for background fetch
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  // Initialize background email service
  await BackgroundEmailService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;

  void _onInitializationComplete() {
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Update system UI overlay based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeProvider.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    // Get appropriate theme based on mode
    ThemeData currentTheme;
    switch (themeProvider.themeMode) {
      case AppThemeMode.light:
        currentTheme = AppTheme.lightTheme;
        break;
      case AppThemeMode.dark:
        currentTheme = AppTheme.darkTheme;
        break;
      case AppThemeMode.oledBlack:
        currentTheme = AppTheme.oledBlackTheme;
        break;
    }

    return MaterialApp(
      title: 'FinWise',
      theme: currentTheme,
      home: _isInitialized
          ? const BiometricLockWrapper(child: MainScreen())
          : SplashScreen(
              onInitializationComplete: _onInitializationComplete,
            ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/manage-categories':
            return MaterialPageRoute(
              builder: (_) => const ManageCategoriesScreen(),
            );
          default:
            return null;
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<TransactionsScreenState> _transactionsKey = GlobalKey<TransactionsScreenState>();
  final GlobalKey<BudgetScreenState> _budgetKey = GlobalKey<BudgetScreenState>();

  // Lazy-loaded screens cache
  final Map<int, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();
    // Preload only the home screen
    _screenCache[0] = HomeScreen(key: _homeKey);
  }

  Widget _getScreen(int index) {
    // Return cached screen or create new one
    return _screenCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return HomeScreen(key: _homeKey);
        case 1:
          return TransactionsScreen(key: _transactionsKey);
        case 2:
          return BudgetScreen(key: _budgetKey);
        case 3:
          return const InsightsScreen();
        case 4:
          return const AnalyticsScreen();
        case 5:
          return const SettingsScreen();
        default:
          return HomeScreen(key: _homeKey);
      }
    });
  }

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Refresh screen data when switching to certain tabs
    switch (index) {
      case 1: // Transactions
        _transactionsKey.currentState?.refresh();
        break;
      case 2: // Budget
        _budgetKey.currentState?.refresh();
        break;
    }
  }

  /// Refresh transactions screen (can be called from anywhere)
  void refreshTransactionsScreen() {
    _transactionsKey.currentState?.refresh();
  }

  /// Refresh budget screen (can be called from anywhere)
  void refreshBudgetScreen() {
    _budgetKey.currentState?.refresh();
  }

  /// Refresh both screens after transaction changes
  void refreshAfterTransactionChange() {
    _transactionsKey.currentState?.refresh();
    _budgetKey.currentState?.refresh();
    _homeKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isOled = themeProvider.isOledBlack;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(6, (index) => _getScreen(index)),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isOled
              ? AppTheme.backgroundOled
              : (isDark ? AppTheme.cardBackgroundDark : AppTheme.whiteBg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transactions',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.savings_rounded,
                  label: 'Budget',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.lightbulb_rounded,
                  label: 'Insights',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.show_chart_rounded,
                  label: 'Analytics',
                  index: 4,
                ),
                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  index: 5,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddTransactionSheet(
                    onTransactionAdded: () {
                      // Refresh all screens that show transaction data
                      refreshAfterTransactionChange();
                    },
                  ),
                );
              },
              backgroundColor: AppTheme.coral,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        // Refresh home screen when switching to it
        if (index == 0) {
          _homeKey.currentState?.refresh();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? AppTheme.coral
                : (isDark ? AppTheme.textSecondaryDark : Colors.grey),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppTheme.coral
                  : (isDark ? AppTheme.textSecondaryDark : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
