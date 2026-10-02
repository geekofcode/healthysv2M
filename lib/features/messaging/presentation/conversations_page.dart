import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/messaging_providers.dart';
import '../domain/messaging.dart';
import 'messaging_connection_banner.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});
  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage>
    with WidgetsBindingObserver {
  bool _resumed = true;
  bool? _visible;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (mounted) {
      final connection = ref.read(messagingListConnectionProvider.notifier);
      if (_resumed && ModalRoute.of(context)?.isCurrent == true) {
        connection.resume();
      } else {
        connection.suspend();
      }
      setState(() {});
    }
  }

  void _syncVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final visible = _resumed && ModalRoute.of(context)?.isCurrent == true;
      if (visible != _visible) {
        _visible = visible;
        final connection = ref.read(messagingListConnectionProvider.notifier);
        if (visible) {
          connection.resume();
        } else {
          connection.suspend();
        }
      }
    });
  }

  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(messagingListConnectionProvider);
    _syncVisibility();
    final fr = clinicalFrench(context);
    final provider = conversationsProvider(MessagingQuery(page: _page));
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Ma messagerie' : 'My messages'),
        actions: [
          IconButton(
            tooltip: fr ? 'Nouvelle conversation' : 'New conversation',
            onPressed: () => context.pushNamed('conversation-new'),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {
              // The view renders a controlled error.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              MessagingConnectionBanner(
                status: connection.status,
                onRetry: () => ref
                    .read(messagingListConnectionProvider.notifier)
                    .reconnect(),
              ),
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Messagerie indisponible.'
                    : 'Messaging unavailable.',
                builder: (data) {
                  if (data == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(fr ? 'Aucune conversation.' : 'No conversations.'),
                      for (final conversation in data.content)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(
                              conversation.subject?.trim().isNotEmpty == true
                                  ? conversation.subject!
                                  : (fr ? 'Conversation' : 'Conversation'),
                            ),
                            subtitle: Text(
                              [
                                if (conversation.lastMessage?.isNotEmpty ==
                                    true)
                                  conversation.lastMessage!,
                                if (conversation.lastMessageAt != null)
                                  clinicalDateTime(
                                    context,
                                    conversation.lastMessageAt,
                                  ),
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: conversation.unreadCount > 0
                                ? Semantics(
                                    label: fr
                                        ? '${conversation.unreadCount} messages non lus'
                                        : '${conversation.unreadCount} unread messages',
                                    child: Badge(
                                      label: Text(
                                        '${conversation.unreadCount}',
                                      ),
                                      child: const Icon(Icons.chevron_right),
                                    ),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () => context.pushNamed(
                              'conversation',
                              pathParameters: {'id': conversation.id},
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
