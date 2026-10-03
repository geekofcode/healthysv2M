import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../../auth/application/session_controller.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../../documents/application/document_export.dart';
import '../../documents/presentation/document_preview_page.dart';
import '../application/messaging_providers.dart';
import '../domain/messaging.dart';

class MessagingAttachmentPage extends ConsumerStatefulWidget {
  const MessagingAttachmentPage({
    super.key,
    required this.conversationId,
    required this.documentId,
  });
  final String conversationId, documentId;
  @override
  ConsumerState<MessagingAttachmentPage> createState() =>
      _MessagingAttachmentPageState();
}

class _MessagingAttachmentPageState
    extends ConsumerState<MessagingAttachmentPage> {
  bool _preview = false, _saving = false;
  AppException? _error;
  MessagingAttachmentQuery get _query =>
      MessagingAttachmentQuery(widget.conversationId, widget.documentId);
  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final identity = ref.read(sessionControllerProvider).profile?.id;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final document = await ref
          .read(messagingActionsProvider)
          .download(widget.conversationId, widget.documentId);
      if (!mounted ||
          !ref.read(sessionControllerProvider).isAuthenticated ||
          ref.read(sessionControllerProvider).profile?.id != identity) {
        return;
      }
      final saved = await ref.read(documentExporterProvider).save(document);
      if (mounted &&
          saved &&
          ref.read(sessionControllerProvider).profile?.id == identity) {
        final fr = clinicalFrench(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fr ? 'Fichier enregistré.' : 'File saved.')),
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(messagingActionsProvider);
    final fr = clinicalFrench(context);
    final metadata = messagingAttachmentProvider(_query);
    final download = downloadedMessagingAttachmentProvider(_query);
    final session = ref.watch(sessionControllerProvider);
    if (!session.isAuthenticated) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Pièce jointe' : 'Attachment')),
      body: SafeArea(
        child: Column(
          children: [
            ClinicalAsyncView(
              value: ref.watch(metadata),
              onRetry: () => ref.invalidate(metadata),
              missingMessage: fr
                  ? 'Pièce jointe indisponible.'
                  : 'Attachment unavailable.',
              builder: (data) => data == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            data.fileName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${data.mimeType} • ${(data.sizeBytes / 1024).ceil()} ${fr ? 'Ko' : 'KB'}',
                          ),
                          Wrap(
                            spacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => setState(() => _preview = true),
                                icon: const Icon(Icons.visibility_outlined),
                                label: Text(fr ? 'Visualiser' : 'Preview'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: const Icon(Icons.download_outlined),
                                label: Text(fr ? 'Télécharger' : 'Download'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null)
              Text(localizedErrorMessage(_error!.kind, french: fr)),
            if (_preview)
              Expanded(
                child: ClinicalAsyncView(
                  value: ref.watch(download),
                  onRetry: () => ref.invalidate(download),
                  missingMessage: fr
                      ? 'Fichier indisponible.'
                      : 'File unavailable.',
                  builder: (document) => document == null
                      ? const SizedBox.shrink()
                      : DocumentPreview(document: document),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
