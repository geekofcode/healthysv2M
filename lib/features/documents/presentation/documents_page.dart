import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/document_export.dart';
import '../application/document_providers.dart';
import '../domain/document.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key, this.consultationId});
  final String? consultationId;
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  int _page = 0;
  Object? _exportError;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final export = ref.watch(documentExportProvider);
    final provider = documentsProvider(
      DocumentListQuery(consultationId: widget.consultationId, page: _page),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.consultationId == null
              ? (fr ? 'Mes documents' : 'My documents')
              : (fr
                    ? 'Documents de la consultation'
                    : 'Consultation documents'),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {
              /* The controlled state renders below. */
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_exportError != null)
                ErrorView(
                  error: _exportError is AppException
                      ? _exportError as AppException
                      : const AppException(
                          kind: AppErrorKind.unknown,
                          message: '',
                        ),
                ),
              if (export.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Ce dossier patient ou cette consultation est introuvable.'
                    : 'This patient record or consultation could not be found.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr
                          ? 'Les documents sont indisponibles.'
                          : 'Documents are unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          widget.consultationId == null
                              ? (fr
                                    ? 'Aucun document disponible.'
                                    : 'No documents available.')
                              : (fr
                                    ? 'Aucun document associé à cette consultation.'
                                    : 'No documents linked to this consultation.'),
                        ),
                      for (final document in data.content)
                        _DocumentCard(
                          document: document,
                          busy: export.isLoading,
                          onPreview: () => context.pushNamed(
                            'document-preview',
                            pathParameters: {'id': document.id},
                          ),
                          onSave: () => _save(document),
                        ),
                      ClinicalPagination(
                        number: data.number,
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

  Future<void> _save(DocumentMetadata document) async {
    setState(() => _exportError = null);
    try {
      final saved = await ref
          .read(documentExportProvider.notifier)
          .save(document.id);
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clinicalFrench(context)
                ? 'Document enregistré.'
                : 'Document saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _exportError = error);
    }
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.busy,
    required this.onPreview,
    required this.onSave,
  });
  final DocumentMetadata document;
  final bool busy;
  final VoidCallback onPreview, onSave;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              document.fileName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              document.categoryName ??
                  (fr ? 'Catégorie non renseignée' : 'Category not provided'),
            ),
            Text(
              '${documentFormat(document.mimeType, french: fr)} • ${documentSize(document.sizeBytes, french: fr)}',
            ),
            Text(
              '${fr ? 'Ajouté le' : 'Uploaded'} : ${clinicalDateTime(context, document.uploadedAt)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onPreview,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(fr ? 'Visualiser' : 'View'),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onSave,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(fr ? 'Télécharger' : 'Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String documentFormat(String mimeType, {required bool french}) {
  if (mimeType == 'application/pdf') return 'PDF';
  if (mimeType.startsWith('image/')) return french ? 'Image' : 'Image';
  if (mimeType.startsWith('text/')) return french ? 'Texte' : 'Text';
  return french ? 'Fichier' : 'File';
}

String documentSize(int bytes, {required bool french}) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ${french ? 'Mo' : 'MB'}';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} ${french ? 'Ko' : 'KB'}';
  }
  return '$bytes ${french ? 'octets' : 'bytes'}';
}
