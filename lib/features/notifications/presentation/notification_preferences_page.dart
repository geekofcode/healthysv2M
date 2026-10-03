import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/notification_providers.dart';
import '../application/push_controller.dart';
import '../domain/notifications.dart';

class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save(NotificationPreferences value) => _perform(() async {
    await ref.read(notificationActionsProvider).savePreferences(value);
  });
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    ref.watch(notificationActionsProvider);
    final push = ref.watch(pushControllerProvider);
    final status = switch (push.status) {
      PushStatus.enabled =>
        fr
            ? 'Notifications push actives sur cet appareil.'
            : 'Push notifications active on this device.',
      PushStatus.denied =>
        fr
            ? 'Autorisation refusée. Activez les notifications dans les réglages de votre appareil, puis réessayez.'
            : 'Permission denied. Enable notifications in your device settings, then try again.',
      PushStatus.registrationFailed =>
        fr
            ? 'Autorisation accordée, mais l’enregistrement de cet appareil a échoué. Vérifiez votre connexion, puis réessayez.'
            : 'Permission granted, but device registration failed. Check your connection, then try again.',
      PushStatus.unavailable =>
        fr
            ? 'Notifications push indisponibles. Vérifiez la configuration et la connexion, puis réessayez.'
            : 'Push notifications unavailable. Check configuration and connection, then try again.',
      PushStatus.disabled =>
        fr
            ? 'Notifications push non configurées sur cet appareil.'
            : 'Push notifications are not configured on this device.',
      PushStatus.idle =>
        fr
            ? 'Activez les notifications pour recevoir les alertes HEALTH’YS.'
            : 'Enable notifications to receive HEALTH’YS alerts.',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fr ? 'Préférences de notification' : 'Notification preferences',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(status),
            const SizedBox(height: 12),
            Text(
              fr
                  ? 'Les notifications affichées sur l’écran verrouillé ne contiennent pas d’informations médicales.'
                  : 'Notifications on the lock screen contain no medical information.',
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  fr
                      ? 'Modification impossible. Réessayez.'
                      : 'Could not save changes. Try again.',
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _perform(
                      () => ref.read(pushControllerProvider.notifier).enable(),
                    ),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                fr
                    ? 'Activer / réessayer sur cet appareil'
                    : 'Enable / retry on this device',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _perform(
                      () => ref.read(pushControllerProvider.notifier).disable(),
                    ),
              child: Text(
                fr
                    ? 'Désactiver les notifications push'
                    : 'Disable push notifications',
              ),
            ),
            const Divider(),
            ClinicalAsyncView(
              value: ref.watch(notificationPreferencesProvider),
              onRetry: () => ref.invalidate(notificationPreferencesProvider),
              missingMessage: fr
                  ? 'Préférences indisponibles.'
                  : 'Preferences unavailable.',
              builder: (preferences) {
                if (preferences == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        fr
                            ? 'Notifications dans l’application'
                            : 'In-app notifications',
                      ),
                      value: preferences.inAppEnabled,
                      onChanged: _busy
                          ? null
                          : (value) => _save(
                              preferences.copyWith(inAppEnabled: value),
                            ),
                    ),
                    ListTile(
                      title: Text(
                        fr
                            ? 'Notifications push du compte'
                            : 'Account push notifications',
                      ),
                      subtitle: Text(
                        preferences.pushEnabled
                            ? (fr ? 'Activées' : 'Enabled')
                            : (fr ? 'Désactivées' : 'Disabled'),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(fr ? 'Courriel' : 'Email'),
                      value: preferences.emailEnabled,
                      onChanged: _busy
                          ? null
                          : (value) => _save(
                              preferences.copyWith(emailEnabled: value),
                            ),
                    ),
                    SwitchListTile(
                      title: const Text('SMS'),
                      value: preferences.smsEnabled,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                _save(preferences.copyWith(smsEnabled: value)),
                    ),
                    if (preferences.quietHoursStart != null &&
                        preferences.quietHoursEnd != null)
                      ListTile(
                        title: Text(
                          fr ? 'Heures de silence (UTC)' : 'Quiet hours (UTC)',
                        ),
                        subtitle: Text(
                          '${preferences.quietHoursStart} – ${preferences.quietHoursEnd}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
