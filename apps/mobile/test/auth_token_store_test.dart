import 'package:coffee_management_mobile/features/auth/data/auth_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake in-memory implementation of FlutterSecureStorage for testing SecureAuthTokenStore.
class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

void main() {
  group('InMemoryAuthTokenStore', () {
    test('initial state returns null', () async {
      final store = InMemoryAuthTokenStore();
      expect(await store.readToken(), isNull);
      expect(await store.readExpiresAt(), isNull);
    });

    test('writes and reads session correctly in UTC', () async {
      final store = InMemoryAuthTokenStore();
      final expiry = DateTime.utc(2026, 10, 7, 8, 30);

      await store.writeSession(token: 'token-123', expiresAt: expiry);

      expect(await store.readToken(), equals('token-123'));
      expect(await store.readExpiresAt(), equals(expiry));
      expect((await store.readExpiresAt())!.isUtc, isTrue);
    });

    test('clearSession resets all stored fields', () async {
      final store = InMemoryAuthTokenStore();
      await store.writeSession(
        token: 'token-123',
        expiresAt: DateTime.utc(2026, 10, 7),
      );

      await store.clearSession();

      expect(await store.readToken(), isNull);
      expect(await store.readExpiresAt(), isNull);
    });
  });

  group('SecureAuthTokenStore', () {
    test(
      'writes session with token and expires_at only without password',
      () async {
        final fakeStorage = FakeFlutterSecureStorage();
        final store = SecureAuthTokenStore(storage: fakeStorage);
        final expiry = DateTime.utc(2026, 10, 7, 14, 0);

        await store.writeSession(token: 'secure-token-xyz', expiresAt: expiry);

        expect(await store.readToken(), equals('secure-token-xyz'));
        expect(await store.readExpiresAt(), equals(expiry));

        // Verify that no password key was stored
        expect(await fakeStorage.read(key: 'password'), isNull);
        expect(await fakeStorage.read(key: 'user'), isNull);
      },
    );

    test('clearSession removes keys from storage', () async {
      final fakeStorage = FakeFlutterSecureStorage();
      final store = SecureAuthTokenStore(storage: fakeStorage);

      await store.writeSession(
        token: 'secure-token-xyz',
        expiresAt: DateTime.utc(2026, 10, 7),
      );

      await store.clearSession();

      expect(await store.readToken(), isNull);
      expect(await store.readExpiresAt(), isNull);
    });
  });
}
