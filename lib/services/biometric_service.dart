import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling biometric authentication (Face ID / Touch ID)
///
/// This service provides secure app lock functionality using platform-specific
/// biometric authentication (Face ID on newer iPhones, Touch ID on older devices).
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;

  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // SharedPreferences key for biometric lock setting
  static const String _keyBiometricEnabled = 'biometric_lock_enabled';

  /// Checks if the device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometric support: $e');
      return false;
    }
  }

  /// Checks if the device has biometric hardware and enrolled biometrics
  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      print('Error checking device support: $e');
      return false;
    }
  }

  /// Gets a list of available biometric types (Face ID, Touch ID, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticates the user with biometrics
  ///
  /// Returns true if authentication is successful, false otherwise.
  /// [localizedReason] is the message shown to the user explaining why
  /// authentication is needed.
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access FinWise',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        print('Biometric authentication not supported on this device');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Error during authentication: $e');
      return false;
    }
  }

  /// Checks if biometric lock is enabled in settings
  Future<bool> isBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Enables or disables biometric lock
  ///
  /// When enabling, the user must authenticate first.
  /// Returns true if the setting was successfully changed.
  Future<bool> setBiometricLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      // Check if device supports biometrics before enabling
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        print('Cannot enable biometric lock: device not supported');
        return false;
      }

      // Require authentication before enabling
      final authenticated = await authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
      );

      if (!authenticated) {
        print('Authentication failed, biometric lock not enabled');
        return false;
      }
    }

    await prefs.setBool(_keyBiometricEnabled, enabled);
    print('✓ Biometric lock ${enabled ? 'enabled' : 'disabled'}');
    return true;
  }

  /// Gets a user-friendly name for the biometric type
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Touch ID';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Biometric';
      case BiometricType.weak:
        return 'Biometric';
    }
  }

  /// Gets the primary biometric type available on the device
  Future<String> getPrimaryBiometricName() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.isEmpty) return 'Biometric';

    // Prefer Face ID, then Touch ID, then others
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else {
      return getBiometricTypeName(biometrics.first);
    }
  }
}
