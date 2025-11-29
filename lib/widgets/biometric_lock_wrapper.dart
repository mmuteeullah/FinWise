import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

/// Wrapper widget that handles biometric authentication on app launch
///
/// This widget will show a lock screen if biometric lock is enabled,
/// and only display the child widget after successful authentication.
class BiometricLockWrapper extends StatefulWidget {
  final Widget child;

  const BiometricLockWrapper({
    super.key,
    required this.child,
  });

  @override
  State<BiometricLockWrapper> createState() => _BiometricLockWrapperState();
}

class _BiometricLockWrapperState extends State<BiometricLockWrapper> with WidgetsBindingObserver {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  String _biometricTypeName = 'Biometric';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Lock the app when it goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lockApp();
    }
  }

  void _lockApp() async {
    final isEnabled = await _biometricService.isBiometricLockEnabled();
    if (isEnabled && _isAuthenticated) {
      setState(() {
        _isAuthenticated = false;
      });
    }
  }

  Future<void> _checkAndAuthenticate() async {
    final isEnabled = await _biometricService.isBiometricLockEnabled();

    if (!isEnabled) {
      // Biometric lock is disabled, allow access
      setState(() {
        _isAuthenticated = true;
      });
      return;
    }

    // Get the biometric type name for display
    final typeName = await _biometricService.getPrimaryBiometricName();
    setState(() {
      _biometricTypeName = typeName;
    });

    // Attempt authentication
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    final success = await _biometricService.authenticate(
      localizedReason: 'Authenticate to access FinWise',
    );

    setState(() {
      _isAuthenticating = false;
      if (success) {
        _isAuthenticated = true;
      }
    });

    // If authentication failed, show the error and allow retry
    if (!success && mounted) {
      // User can retry by tapping the button
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      // User is authenticated, show the app
      return widget.child;
    }

    // Show lock screen
    return _buildLockScreen();
  }

  Widget _buildLockScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.glassBlueGradient
              : const LinearGradient(
                  colors: [AppTheme.purple, AppTheme.deepBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon/logo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _biometricTypeName == 'Face ID'
                        ? Icons.face
                        : Icons.fingerprint,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // App name
                const Text(
                  'FinWise',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Lock message
                Text(
                  'Tap to unlock with $_biometricTypeName',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 60),

                // Authenticate button
                ElevatedButton(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _biometricTypeName == 'Face ID'
                                  ? Icons.face
                                  : Icons.fingerprint,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Unlock',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
