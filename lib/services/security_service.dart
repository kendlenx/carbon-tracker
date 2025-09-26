import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys for secure storage
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _databasePasswordKey = 'database_password';
  static const String _userDataEncryptionKey = 'user_data_key';
  static const String _appLockEnabledKey = 'app_lock_enabled';

  /// Check if biometric authentication is available
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Enable biometric authentication
  Future<bool> enableBiometricAuth() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Karbon takip verilerinizi güvende tutmak için biometric kimlik doğrulamayı etkinleştirin',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
        await _generateDatabasePassword();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error enabling biometric auth: $e');
      return false;
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometricAuth() async {
    await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
    await _secureStorage.write(key: _appLockEnabledKey, value: 'false');
  }

  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    final String? enabled = await _secureStorage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  /// Authenticate user with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool isEnabled = await isBiometricEnabled();
      if (!isEnabled) return true; // Skip if not enabled

      return await _localAuth.authenticate(
        localizedReason: 'Carbon Tracker verilerinize erişmek için kimlik doğrulaması yapın',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Error authenticating with biometrics: $e');
      return false;
    }
  }

  /// Generate a secure database password
  Future<void> _generateDatabasePassword() async {
    final String? existingPassword = await _secureStorage.read(key: _databasePasswordKey);
    if (existingPassword == null) {
      final String password = _generateSecurePassword();
      await _secureStorage.write(key: _databasePasswordKey, value: password);
    }
  }

  /// Get database password for SQLCipher
  Future<String> getDatabasePassword() async {
    String? password = await _secureStorage.read(key: _databasePasswordKey);
    if (password == null) {
      password = _generateSecurePassword();
      await _secureStorage.write(key: _databasePasswordKey, value: password);
    }
    return password;
  }

  /// Generate encryption key for user data
  Future<String> getUserDataEncryptionKey() async {
    String? key = await _secureStorage.read(key: _userDataEncryptionKey);
    if (key == null) {
      key = _generateSecureKey();
      await _secureStorage.write(key: _userDataEncryptionKey, value: key);
    }
    return key;
  }

  /// Encrypt sensitive user data
  Future<String> encryptData(String data) async {
    try {
      final String key = await getUserDataEncryptionKey();
      // Simple XOR encryption (in production, use proper AES encryption)
      final List<int> keyBytes = utf8.encode(key);
      final List<int> dataBytes = utf8.encode(data);
      final List<int> encrypted = [];

      for (int i = 0; i < dataBytes.length; i++) {
        encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return base64.encode(encrypted);
    } catch (e) {
      debugPrint('Error encrypting data: $e');
      return data; // Return original data if encryption fails
    }
  }

  /// Decrypt sensitive user data
  Future<String> decryptData(String encryptedData) async {
    try {
      final String key = await getUserDataEncryptionKey();
      final List<int> keyBytes = utf8.encode(key);
      final List<int> encrypted = base64.decode(encryptedData);
      final List<int> decrypted = [];

      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ keyBytes[i % keyBytes.length]);
      }

      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Error decrypting data: $e');
      return encryptedData; // Return original data if decryption fails
    }
  }

  /// Store sensitive data securely
  Future<void> storeSecureData(String key, String value) async {
    final String encryptedValue = await encryptData(value);
    await _secureStorage.write(key: key, value: encryptedValue);
  }

  /// Read sensitive data securely
  Future<String?> readSecureData(String key) async {
    final String? encryptedValue = await _secureStorage.read(key: key);
    if (encryptedValue == null) return null;
    return await decryptData(encryptedValue);
  }

  /// Enable/disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    await _secureStorage.write(key: _appLockEnabledKey, value: enabled.toString());
  }

  /// Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    final String? enabled = await _secureStorage.read(key: _appLockEnabledKey);
    return enabled == 'true';
  }

  /// Clear all secure storage (for logout/reset)
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  /// Generate a secure password
  String _generateSecurePassword() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?';
    final Random random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate a secure encryption key
  String _generateSecureKey() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random.secure();
    return List.generate(64, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Get security status for settings screen
  Future<Map<String, bool>> getSecurityStatus() async {
    return {
      'biometricsAvailable': await isBiometricsAvailable(),
      'biometricsEnabled': await isBiometricEnabled(),
      'appLockEnabled': await isAppLockEnabled(),
      'dataEncrypted': await _secureStorage.read(key: _userDataEncryptionKey) != null,
    };
  }

  /// Initialize security on app startup
  Future<void> initializeSecurity() async {
    try {
      // Generate encryption keys if they don't exist
      await getUserDataEncryptionKey();
      await getDatabasePassword();
      
      debugPrint('Security service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing security service: $e');
    }
  }
}