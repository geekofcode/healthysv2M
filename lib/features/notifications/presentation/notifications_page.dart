import '../../../app/layout/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/notification_providers.dart';
import '../domain/notifications.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _page = 0;
  bool _unreadOnly = false;
  bool _busy = false;
  Future<void> _markAll() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationActionsProvider).markAllRead();
    } catch (_) {
      if (mounted) {
        final fr = clinicalFrench(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fr
                  ? 'Impossible de mettre à jour les notifications.'
                  : 'Could not update notifications.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationActionsProvider);
    final fr = clinicalFrench(context);
    final provider = notificationsProvider(
      NotificationQuery(page: _page, unreadOnly: _unreadOnly),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed('notification-preferences'),
            tooltip: fr ? 'Préférences' : 'Preferences',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            ref.invalidate(notificationUnreadCountProvider);
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: Text(fr ? 'Non lues uniquement' : 'Unread only'),
                value: _unreadOnly,
                onChanged: (value) => setState(() {
                  _unreadOnly = value;
                  _page = 0;
                }),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _markAll,
                icon: const Icon(Icons.done_all),
                label: Text(fr ? 'Tout marquer comme lu' : 'Mark all as read'),
              ),
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Notifications indisponibles.'
                    : 'Notifications unavailable.',
                builder: (data) {
                  if (data == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(fr ? 'Aucune notification.' : 'No notifications.'),
                      for (final item in data.content)
                        Card(
                          child: ListTile(
                            selected: AdaptiveNavigation.isSelected(
                              context,
                              item.id,
                              routePrefix: '/notifications',
                            ),
                            leading: Icon(
                              item.read
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                            ),
                            title: Text(
                              item.title?.trim().isNotEmpty == true
                                  ? item.title!
                                  : "HEALTH'YS",
                              style: item.read
                                  ? null
                                  : const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                            ),
                            subtitle: Text(
                              '${item.body}\n${clinicalDateTime(context, item.createdAt)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => AdaptiveNavigation.openDetail(
                              context,
                              'notification-detail',
                              pathParameters: {'id': item.id},
                            ),
                          ),
                        ),
                      ClinicalPagination(
                        number: data.page,
                        totalPages: data.totalPages,
                        last: data.last,
                        onPrevious: () => setState(() => _page--),
                        onNext: () => setState(() => _page++),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
