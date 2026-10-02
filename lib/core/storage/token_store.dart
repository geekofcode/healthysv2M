import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Isolated from authentication so credentials can be replaced or cleared safely.
abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<void> writeAccessToken(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _accessTokenKey = 'healthys.access_token';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _accessTokenKey);
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(const FlutterSecureStorage()),
);
