import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contract for persistent and in-memory auth token management.
///
/// Ensures separation of token storage mechanisms across native platforms
/// (OS-backed Keystore/Keychain) and Web (in-memory only).
abstract class AuthTokenStore {
  /// Reads the currently stored Bearer token, if any.
  Future<String?> readToken();

  /// Reads the stored token expiration timestamp in UTC, if any.
  Future<DateTime?> readExpiresAt();

  /// Securely records the session's Bearer token and expiration timestamp.
  Future<void> writeSession({
    required String token,
    required DateTime expiresAt,
  });

  /// Wipes all stored session credentials and timestamps.
  Future<void> clearSession();

  /// Factory constructing the appropriate platform-specific store.
  factory AuthTokenStore.create({FlutterSecureStorage? secureStorage}) {
    if (kIsWeb) {
      return InMemoryAuthTokenStore();
    }
    return SecureAuthTokenStore(storage: secureStorage);
  }
}

/// OS-backed secure storage for mobile platforms using Android Keystore and iOS Keychain.
class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const String _tokenKey = 'cms_auth_token';
  static const String _expiresAtKey = 'cms_auth_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DateTime?> readExpiresAt() async {
    try {
      final raw = await _storage.read(key: _expiresAtKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSession({
    required String token,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _expiresAtKey,
      value: expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiresAtKey);
    } catch (_) {
      // Best-effort cleanup
    }
  }
}

/// Ephemeral in-memory token store for Web platform and testing.
///
/// **Web Security Decision:**
/// The backend uses JavaScript-accessible Bearer authentication rather than
/// HttpOnly browser cookies. Persisting Bearer tokens in browser `localStorage`,
/// `sessionStorage`, or `IndexedDB` exposes tokens to Cross-Site Scripting (XSS).
/// Therefore, Web sessions are intentionally kept in-memory only. A browser page
/// reload requires re-authentication, guaranteeing tokens are never leaked to
/// persistent browser storage.
class InMemoryAuthTokenStore implements AuthTokenStore {
  String? _token;
  DateTime? _expiresAt;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<DateTime?> readExpiresAt() async => _expiresAt;

  @override
  Future<void> writeSession({
    required String token,
    required DateTime expiresAt,
  }) async {
    _token = token;
    _expiresAt = expiresAt.toUtc();
  }

  @override
  Future<void> clearSession() async {
    _token = null;
    _expiresAt = null;
  }
}
