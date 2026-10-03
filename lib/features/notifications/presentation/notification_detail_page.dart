import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/notification_providers.dart';

class NotificationDetailPage extends ConsumerStatefulWidget {
  const NotificationDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NotificationDetailPage> createState() =>
      _NotificationDetailPageState();
}

class _NotificationDetailPageState
    extends ConsumerState<NotificationDetailPage> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _open() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final destination = await ref
          .read(notificationActionsProvider)
          .open(widget.id);
      if (mounted) {
        context.go(destination);
      }
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

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref.read(notificationActionsProvider).markRead(widget.id);
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

  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    ref.watch(notificationActionsProvider);
    final provider = notificationDetailProvider(widget.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClinicalAsyncView(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              missingMessage: fr
                  ? 'Cette notification est indisponible.'
                  : 'This notification is unavailable.',
              builder: (item) {
                if (item == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.title?.trim().isNotEmpty == true
                          ? item.title!
                          : "HEALTH'YS",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(item.body),
                    const SizedBox(height: 12),
                    Text(clinicalDateTime(context, item.createdAt)),
                    Text(
                      item.read
                          ? (fr ? 'Lue' : 'Read')
                          : (fr ? 'Non lue' : 'Unread'),
                    ),
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          fr
                              ? 'Action indisponible. Réessayez.'
                              : 'Action unavailable. Try again.',
                        ),
                      ),
                    if (!item.read)
                      TextButton(
                        onPressed: _busy ? null : _read,
                        child: Text(fr ? 'Marquer comme lue' : 'Mark as read'),
                      ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _open,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        fr
                            ? 'Ouvrir dans mon espace patient'
                            : 'Open in my patient dashboard',
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
