import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../application/document_providers.dart';
import '../application/document_preview_storage.dart';
import '../domain/document.dart';

class DocumentPreviewPage extends ConsumerWidget {
  const DocumentPreviewPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final provider = downloadedDocumentProvider(id);
    final value = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Document médical' : 'Medical document')),
      body: SafeArea(
        child: value.isLoading
            ? const Center(child: CircularProgressIndicator())
            : value.hasError
            ? ErrorView(
                error: value.error is AppException
                    ? value.error! as AppException
                    : _unavailable,
                onRetry: () => ref.invalidate(provider),
              )
            : value.value == null
            ? Center(
                child: Text(
                  fr ? 'Document indisponible.' : 'Document unavailable.',
                ),
              )
            : DocumentPreview(document: value.value!),
      ),
    );
  }
}

class DocumentPreview extends StatefulWidget {
  const DocumentPreview({super.key, required this.document});
  final DownloadedDocument document;
  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  @override
  void dispose() {
    if (widget.document.metadata.mimeType.startsWith('image/')) {
      unawaited(MemoryImage(widget.document.bytes).evict());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    switch (document.metadata.mimeType) {
      case 'application/pdf':
        return _PdfPreview(document: document);
      case 'image/png':
      case 'image/jpeg':
        return InteractiveViewer(
          child: Center(
            child: Image.memory(
              document.bytes,
              errorBuilder: (context, error, stack) =>
                  const ErrorView(error: _unavailable),
            ),
          ),
        );
      case 'text/plain':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(utf8.decode(document.bytes)),
        );
      default:
        return const ErrorView(error: _unavailable);
    }
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.document});
  final DownloadedDocument document;
  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  PdfControllerPinch? _controller;
  PdfDocument? _document;
  TemporaryDocumentPreview? _file;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    TemporaryDocumentPreview? file;
    PdfDocument? document;
    try {
      file = await DocumentPreviewStorage().create(widget.document.bytes);
      if (!mounted) {
        await file.dispose();
        return;
      }
      document = await PdfDocument.openFile(file.file.path);
      if (!mounted) {
        await document.close();
        await file.dispose();
        return;
      }
      _file = file;
      _document = document;
      setState(
        () =>
            _controller = PdfControllerPinch(document: Future.value(document)),
      );
    } catch (_) {
      try {
        if (document != null) await document.close();
      } catch (_) {
        // The native reader may already have closed after an opening failure.
      } finally {
        try {
          if (file != null) await file.dispose();
        } catch (_) {
          // Startup cleanup retries removal of a remaining preview directory.
        }
      }
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_close().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _close() async {
    try {
      await _document?.close();
    } finally {
      await _file?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const ErrorView(error: _unavailable);
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfViewPinch(
      controller: controller,
      onDocumentError: (_) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }
}

const _unavailable = AppException(
  kind: AppErrorKind.unknown,
  message: 'Le document ne peut pas être affiché.',
);
