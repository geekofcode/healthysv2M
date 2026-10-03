import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../../auth/application/session_controller.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/messaging_providers.dart';

class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});
  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final _subject = TextEditingController();
  String? _recipient;
  bool _creating = false;
  AppException? _error;
  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final recipient = _recipient;
    if (_creating || recipient == null) {
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(messagingActionsProvider)
          .create(recipient, _subject.text.trim());
      if (mounted) {
        context.replaceNamed(
          'conversation',
          pathParameters: {'id': conversation.id},
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AppException
              ? error
              : const AppException(kind: AppErrorKind.unknown, message: ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(messagingActionsProvider);
    ref.listen(sessionControllerProvider, (previous, next) {
      if (previous?.profile?.id != next.profile?.id || !next.isAuthenticated) {
        _subject.clear();
        _recipient = null;
        _error = null;
      }
    });
    final fr = clinicalFrench(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Nouvelle conversation' : 'New conversation'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              fr
                  ? 'Contactez un professionnel de votre équipe de soins.'
                  : 'Contact a professional on your care team.',
            ),
            const SizedBox(height: 16),
            ClinicalAsyncView(
              value: ref.watch(messagingRecipientsProvider),
              onRetry: () => ref.invalidate(messagingRecipientsProvider),
              missingMessage: fr
                  ? 'Équipe de soins indisponible.'
                  : 'Care team unavailable.',
              builder: (recipients) {
                if (recipients == null || recipients.isEmpty) {
                  return Text(
                    fr
                        ? 'Aucun professionnel joignable dans votre équipe de soins.'
                        : 'No reachable professional on your care team.',
                  );
                }
                final valid = recipients.any((p) => p.personId == _recipient);
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: valid ? _recipient : null,
                      decoration: InputDecoration(
                        labelText: fr ? 'Professionnel' : 'Professional',
                      ),
                      items: [
                        for (final person in recipients)
                          DropdownMenuItem(
                            value: person.personId,
                            child: Text(person.displayName),
                          ),
                      ],
                      onChanged: _creating
                          ? null
                          : (value) => setState(() => _recipient = value),
                    ),
                    TextField(
                      controller: _subject,
                      enabled: !_creating,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: fr
                            ? 'Objet (facultatif)'
                            : 'Subject (optional)',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _creating || !valid ? null : _create,
                      icon: _creating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        fr ? 'Ouvrir la conversation' : 'Open conversation',
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_error != null)
              Text(localizedErrorMessage(_error!.kind, french: fr)),
            if (_error != null &&
                {
                  AppErrorKind.network,
                  AppErrorKind.timeout,
                  AppErrorKind.unknown,
                }.contains(_error!.kind))
              Text(
                fr
                    ? 'Vérifiez la liste des conversations avant de réessayer.'
                    : 'Check the conversation list before trying again.',
              ),
          ],
        ),
      ),
    );
  }
}
