import 'dart:convert';

import '../config/app_config.dart';
import '../../features/auth/domain/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Isolated from authentication so credentials can be replaced or cleared safely.
abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<void> writeAccessToken(String token);
  Future<void> clear();
}

abstract interface class SessionTokenStore implements TokenStore {
  Future<SessionTokens?> readSession();
  Future<void> writeSession(SessionTokens tokens);
}

class SecureTokenStore implements SessionTokenStore {
  SecureTokenStore(this._storage, {this.namespace = 'default'});
  final String namespace;

  final FlutterSecureStorage _storage;
  String get _accessTokenKey => 'healthys.$namespace.access_token';
  String get _sessionKey => 'healthys.$namespace.session.v1';

  @override
  Future<SessionTokens?> readSession() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null) return null;
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic>) throw const FormatException();
      return SessionTokens.fromJson(data);
    } on FormatException {
      // Corrupt credentials cannot be restored. Clear the complete namespace,
      // including a legacy access token, rather than fall back to stale data.
      await clear();
      return null;
    }
  }

  @override
  Future<void> writeSession(SessionTokens tokens) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<String?> readAccessToken() async =>
      (await readSession())?.accessToken ??
      await _storage.read(key: _accessTokenKey);

  @override
  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _accessTokenKey);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  final config = ref.watch(appConfigProvider);
  final namespace = base64Url.encode(
    utf8.encode('${config.issuer}|${config.oidcClientId}|${config.apiBaseUrl}'),
  );
  return SecureTokenStore(const FlutterSecureStorage(), namespace: namespace);
});
