import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public Firebase application identifiers supplied per build environment.
/// Service-account credentials and APNs signing keys belong on the server.
class PushConfiguration {
  const PushConfiguration({
    this.enabled = const bool.fromEnvironment('PUSH_ENABLED'),
    this.apiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
    this.appId = const String.fromEnvironment('FIREBASE_APP_ID'),
    this.messagingSenderId = const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    this.projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    this.iosBundleId = const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  });

  final bool enabled;
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String iosBundleId;

  bool get isConfigured =>
      enabled &&
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}

abstract interface class PushClient {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokenChanges;
  Stream<String> get foregroundIds;
  Stream<String> get openedIds;
  Future<String?> initialNotificationId();
}

final pushClientProvider = Provider<PushClient>(
  (ref) => FirebasePushClient(const PushConfiguration()),
);

/// Only an opaque server notification ID may enter navigation. Routes, patient
/// identifiers and medical content received from push are never trusted.
String? pushNotificationId(Map<String, dynamic> data) {
  final value = data['notificationId'];
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    return null;
  }
  return value.toLowerCase();
}

class FirebasePushClient implements PushClient {
  FirebasePushClient(this.configuration);
  final PushConfiguration configuration;
  FirebaseMessaging? _messaging;
  bool get _isApple => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> initialize() async {
    if (_messaging != null) {
      return true;
    }
    if (!configuration.isConfigured ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android && !_isApple)) {
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) {
        // Reuse the native default app so background/cold-start delivery and
        // Dart use exactly the same Firebase project.
        try {
          await Firebase.initializeApp();
        } catch (_) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: configuration.apiKey,
              appId: configuration.appId,
              messagingSenderId: configuration.messagingSenderId,
              projectId: configuration.projectId,
              iosBundleId: configuration.iosBundleId.isEmpty
                  ? null
                  : configuration.iosBundleId,
            ),
          );
        }
      }
      final nativeOptions = Firebase.app().options;
      if (nativeOptions.projectId != configuration.projectId ||
          nativeOptions.appId != configuration.appId ||
          nativeOptions.messagingSenderId != configuration.messagingSenderId) {
        return false;
      }
      final messaging = FirebaseMessaging.instance;
      // Explicit user action enables token creation; initialization never asks
      // for OS permission or creates an installation token automatically.
      await messaging.setAutoInitEnabled(false);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _messaging = messaging;
      return true;
    } catch (_) {
      // Missing platform services/configuration must not prevent app startup.
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) {
      return false;
    }
    final settings = await messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    final messaging = _messaging;
    if (messaging == null) {
      return null;
    }
    final settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return null;
    }
    await messaging.setAutoInitEnabled(true);
    if (_isApple && await messaging.getAPNSToken() == null) {
      return null;
    }
    return messaging.getToken();
  }

  @override
  Future<void> deleteToken() async {
    final messaging = _messaging;
    if (messaging != null) {
      await messaging.setAutoInitEnabled(false);
      if (!_isApple || await messaging.getAPNSToken() != null) {
        await messaging.deleteToken();
      }
    }
  }

  @override
  Stream<String> get tokenChanges =>
      _messaging?.onTokenRefresh ?? const Stream.empty();

  Stream<String> _ids(Stream<RemoteMessage> messages) => messages
      .map((message) => pushNotificationId(message.data))
      .where((id) => id != null)
      .cast<String>();

  @override
  Stream<String> get foregroundIds => _messaging == null
      ? const Stream.empty()
      : _ids(FirebaseMessaging.onMessage);

  @override
  Stream<String> get openedIds => _messaging == null
      ? const Stream.empty()
      : _ids(FirebaseMessaging.onMessageOpenedApp);

  @override
  Future<String?> initialNotificationId() async {
    final message = await _messaging?.getInitialMessage();
    return message == null ? null : pushNotificationId(message.data);
  }
}
