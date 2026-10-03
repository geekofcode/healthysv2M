class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
    this.idToken,
  });
  final String accessToken;
  final DateTime expiresAt;
  final String? refreshToken;
  final String? idToken;
  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'refreshToken': refreshToken,
    'idToken': idToken,
  };
  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final expiry = json['expiresAt'];
    final refresh = json['refreshToken'];
    final identity = json['idToken'];
    if (access is! String ||
        access.trim().isEmpty ||
        expiry is! String ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(expiry) ||
        (refresh != null && (refresh is! String || refresh.trim().isEmpty)) ||
        (identity != null &&
            (identity is! String || identity.trim().isEmpty))) {
      throw const FormatException('Invalid secure session');
    }
    final expiresAt = DateTime.tryParse(expiry);
    if (expiresAt == null) {
      throw const FormatException('Invalid secure session');
    }
    return SessionTokens(
      accessToken: access,
      expiresAt: expiresAt,
      refreshToken: refresh as String?,
      idToken: identity as String?,
    );
  }

  @override
  String toString() =>
      'SessionTokens(expiresAt: $expiresAt, credentials: redacted)';
}

enum SessionStatus {
  restoring,
  signedOut,
  authenticating,
  authenticated,
  expired,
}

class MobileProfile {
  const MobileProfile(this.data);
  final Map<String, dynamic> data;
  String? get id => data['id']?.toString();
  String? get email => data['email'] as String?;
  String get displayName =>
      [data['firstName'], data['lastName']].whereType<String>().join(' ');
}

enum SessionIssue {
  connectivity,
  profileUnlinked,
  remoteLogout,
  storage,
  authentication,
}

class SessionState {
  const SessionState({
    this.status = SessionStatus.restoring,
    this.profile,
    this.error,
    this.logoutFailed = false,
    this.issue,
  });
  final SessionStatus status;
  final MobileProfile? profile;
  final String? error;
  final bool logoutFailed;
  final SessionIssue? issue;
  bool get isAuthenticated => status == SessionStatus.authenticated;
}

class SessionExpiredException implements Exception {}

class OidcFailure implements Exception {
  const OidcFailure({this.invalidGrant = false, this.cancelled = false});
  final bool invalidGrant;
  final bool cancelled;
}

abstract interface class OidcClient {
  Future<SessionTokens> login();
  Future<SessionTokens> refresh(SessionTokens previous);
  Future<void> logout(String? idToken);
}

abstract interface class ProfileClient {
  Future<MobileProfile> fetch(String token);
}
