import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../../auth/application/session_controller.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/messaging_providers.dart';
import '../domain/messaging.dart';
import 'messaging_file_picker.dart';
import 'messaging_attachment_page.dart';
import 'messaging_connection_banner.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _read = <String>{};
  int _page = 0;
  bool _resumed = true;
  bool? _visible;
  bool _sending = false;
  bool _uploading = false;
  final _attachments = <MessagingAttachment>[];
  AppException? _sendError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (mounted) {
      final connection = ref.read(
        messagingConnectionProvider(widget.id).notifier,
      );
      if (_resumed && ModalRoute.of(context)?.isCurrent == true) {
        connection.resume();
      } else {
        connection.suspend();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  void _syncVisibility(List<Message>? messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final visible = _resumed && ModalRoute.of(context)?.isCurrent == true;
      if (_visible != visible) {
        _visible = visible;
        final connection = ref.read(
          messagingConnectionProvider(widget.id).notifier,
        );
        if (visible) {
          connection.resume();
        } else {
          connection.suspend();
        }
      }
      if (visible && messages != null) {
        unawaited(_markRead(messages));
      }
    });
  }

  Future<void> _markRead(List<Message> messages) async {
    final personId = ref.read(sessionControllerProvider).profile?.id;
    for (final message in messages) {
      if (!_resumed || !mounted || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (message.senderPersonId == personId ||
          message.readByCurrentUser ||
          message.deletedAt != null ||
          !_read.add(message.id)) {
        continue;
      }
      try {
        await ref.read(messagingActionsProvider).markRead(message.id);
      } catch (_) {
        _read.remove(message.id);
        // Retry only on a subsequent visible refresh/event; avoid read loops.
      }
    }
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (_sending ||
        _uploading ||
        (content.isEmpty && _attachments.isEmpty) ||
        !_resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await ref
          .read(messagingActionsProvider)
          .send(
            widget.id,
            content,
            documentIds: _attachments.map((a) => a.id).toList(),
          );
      if (mounted) {
        _text.clear();
        _attachments.clear();
        setState(() => _page = 0);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _sendError = error is AppException
              ? error
              : const AppException(kind: AppErrorKind.unknown, message: ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _attach() async {
    if (_uploading ||
        _sending ||
        _attachments.length >= 10 ||
        !_resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final identity = ref.read(sessionControllerProvider).profile?.id;
    final sessionRevision = ref
        .read(sessionControllerProvider.notifier)
        .revision;
    setState(() {
      _uploading = true;
      _sendError = null;
    });
    try {
      final picked = await ref.read(messagingFilePickerProvider).pick();
      if (picked == null ||
          !_resumed ||
          ModalRoute.of(context)?.isCurrent != true ||
          ref.read(sessionControllerProvider.notifier).revision !=
              sessionRevision ||
          !mounted ||
          !ref.read(sessionControllerProvider).isAuthenticated ||
          ref.read(sessionControllerProvider).profile?.id != identity) {
        return;
      }
      final attachment = await ref
          .read(messagingActionsProvider)
          .upload(widget.id, picked.name, picked.bytes);
      if (mounted &&
          ref.read(sessionControllerProvider).profile?.id == identity) {
        setState(() => _attachments.add(attachment));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _sendError = error is AppException
              ? error
              : const AppException(kind: AppErrorKind.unknown, message: ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, (previous, next) {
      if (previous?.profile?.id != next.profile?.id || !next.isAuthenticated) {
        _text.clear();
        _attachments.clear();
        _read.clear();
        _sendError = null;
      }
    });
    ref.watch(messagingActionsProvider);
    final fr = clinicalFrench(context);
    final detail = conversationDetailProvider(widget.id);
    final provider = messagesProvider(
      MessagingQuery(conversationId: widget.id, page: _page),
    );
    final messages = ref.watch(provider);
    final connection = ref.watch(messagingConnectionProvider(widget.id));
    final session = ref.watch(sessionControllerProvider);
    _syncVisibility(messages.value?.content);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Conversation' : 'Conversation')),
      body: SafeArea(
        child: Column(
          children: [
            MessagingConnectionBanner(
              status: connection.status,
              onRetry: () => ref
                  .read(messagingConnectionProvider(widget.id).notifier)
                  .reconnect(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(detail);
                  ref.invalidate(provider);
                  try {
                    await ref.read(provider.future);
                  } catch (_) {
                    // The view renders controlled errors.
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClinicalAsyncView(
                      value: ref.watch(detail),
                      onRetry: () => ref.invalidate(detail),
                      missingMessage: fr
                          ? 'Conversation indisponible.'
                          : 'Conversation unavailable.',
                      builder: (data) => data == null
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data.subject?.isNotEmpty == true)
                                  Text(
                                    data.subject!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                Text(
                                  data.participants
                                      .map(
                                        (p) =>
                                            p.displayName?.trim().isNotEmpty ==
                                                true
                                            ? p.displayName!
                                            : (fr
                                                  ? 'Participant'
                                                  : 'Participant'),
                                      )
                                      .join(' • '),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                    ),
                    ClinicalAsyncView(
                      value: messages,
                      onRetry: () => ref.invalidate(provider),
                      missingMessage: fr
                          ? 'Messages indisponibles.'
                          : 'Messages unavailable.',
                      builder: (data) {
                        if (data == null) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (data.content.isEmpty)
                              Text(fr ? 'Aucun message.' : 'No messages.'),
                            for (final message in data.content.reversed)
                              _MessageCard(
                                message: message,
                                own:
                                    message.senderPersonId ==
                                    session.profile?.id,
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
            if (_sendError != null)
              Text(
                localizedErrorMessage(_sendError!.kind, french: fr),
                textAlign: TextAlign.center,
              ),
            if (_sendError != null &&
                {
                  AppErrorKind.network,
                  AppErrorKind.timeout,
                  AppErrorKind.unknown,
                }.contains(_sendError!.kind))
              Text(
                fr
                    ? 'Actualisez l’historique avant de renvoyer.'
                    : 'Refresh the history before sending again.',
                textAlign: TextAlign.center,
              ),
            if (_attachments.isNotEmpty)
              Wrap(
                children: [
                  for (final attachment in _attachments)
                    InputChip(
                      label: Text(attachment.fileName),
                      onDeleted: _sending || _uploading
                          ? null
                          : () =>
                                setState(() => _attachments.remove(attachment)),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: fr ? 'Joindre un fichier' : 'Attach a file',
                    onPressed:
                        _sending ||
                            _uploading ||
                            !session.isAuthenticated ||
                            _attachments.length >= 10
                        ? null
                        : _attach,
                    icon: _uploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled:
                          !_sending && !_uploading && session.isAuthenticated,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 10000,
                      decoration: InputDecoration(
                        labelText: fr ? 'Votre message' : 'Your message',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: fr ? 'Envoyer' : 'Send',
                    onPressed:
                        _sending || _uploading || !session.isAuthenticated
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.own});
  final Message message;
  final bool own;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: own ? Theme.of(context).colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                own
                    ? (fr ? 'Vous' : 'You')
                    : (message.senderName ??
                          (fr ? 'Participant' : 'Participant')),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (message.deletedAt != null)
                Text(fr ? 'Message supprimé' : 'Deleted message')
              else ...[
                if (message.content?.isNotEmpty == true)
                  SelectableText(message.content!),
                for (final documentId in message.documentIds)
                  _AttachmentButton(
                    conversationId: message.conversationId,
                    documentId: documentId,
                  ),
              ],
              const SizedBox(height: 4),
              Text(
                clinicalDateTime(context, message.sentAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (own && message.deletedAt == null)
                Text(
                  message.readByOthersCount > 0
                      ? (fr ? 'Lu' : 'Read')
                      : (fr ? 'Envoyé' : 'Sent'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.conversationId,
    required this.documentId,
  });
  final String conversationId, documentId;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return TextButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MessagingAttachmentPage(
            conversationId: conversationId,
            documentId: documentId,
          ),
        ),
      ),
      icon: const Icon(Icons.attach_file),
      label: Text(fr ? 'Pièce jointe' : 'Attachment'),
    );
  }
}
