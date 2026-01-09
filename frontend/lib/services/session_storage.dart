import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'role';
  static const _familyIdKey = 'family_id';
  static const _familyNameKey = 'family_name';
  static const _userNameKey = 'user_name';
  static const _emailKey = 'email';
  static const _biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  SessionStorage()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        _localAuth = LocalAuthentication();

  /// Save session data securely
  Future<void> saveSession({
    required String token,
    String? refreshToken,
    required int userId,
    required String role,
    int? familyId,
    String? familyName,
    String? userName,
    String? email,
  }) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
    await _secureStorage.write(key: _userIdKey, value: userId.toString());
    await _secureStorage.write(key: _roleKey, value: role);
    if (familyId != null) {
      await _secureStorage.write(key: _familyIdKey, value: familyId.toString());
    }
    if (familyName != null) {
      await _secureStorage.write(key: _familyNameKey, value: familyName);
    }
    if (userName != null) {
      await _secureStorage.write(key: _userNameKey, value: userName);
    }
    if (email != null) {
      await _secureStorage.write(key: _emailKey, value: email);
    }
  }

  /// Update only tokens (after refresh)
  Future<void> updateTokens({required String token, String? refreshToken}) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  /// Update family info
  Future<void> updateFamily({required int familyId, required String familyName}) async {
    await _secureStorage.write(key: _familyIdKey, value: familyId.toString());
    await _secureStorage.write(key: _familyNameKey, value: familyName);
  }

  /// Load saved session
  Future<Map<String, dynamic>?> loadSession() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token == null) return null;

    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final userIdStr = await _secureStorage.read(key: _userIdKey);
    final role = await _secureStorage.read(key: _roleKey);
    final familyIdStr = await _secureStorage.read(key: _familyIdKey);
    final familyName = await _secureStorage.read(key: _familyNameKey);
    final userName = await _secureStorage.read(key: _userNameKey);
    final email = await _secureStorage.read(key: _emailKey);

    return {
      'token': token,
      'refreshToken': refreshToken,
      'userId': userIdStr != null ? int.tryParse(userIdStr) : null,
      'role': role ?? 'guest',
      'familyId': familyIdStr != null ? int.tryParse(familyIdStr) : null,
      'familyName': familyName,
      'userName': userName,
      'email': email,
    };
  }

  /// Clear all session data
  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _roleKey);
    await _secureStorage.delete(key: _familyIdKey);
    await _secureStorage.delete(key: _familyNameKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _emailKey);
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Check if biometric is enabled for this user
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({String reason = 'Bitte authentifizieren'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  /// Check if there's a saved session
  Future<bool> hasSession() async {
    final token = await _secureStorage.read(key: _tokenKey);
    return token != null;
  }
}
