import 'dart:io';
import 'package:dio/dio.dart';
import 'document_preview_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/document_repository.dart';
import '../domain/document.dart';

abstract interface class DocumentExporter {
  Future<bool> save(DownloadedDocument document);
}

class NativeDocumentExporter implements DocumentExporter {
  @override
  Future<bool> save(DownloadedDocument document) async {
    final name =
        '$documentExportPrefix${DateTime.now().microsecondsSinceEpoch}-${safeDocumentName(document.metadata.fileName)}';
    try {
      return await FilePicker.saveFile(fileName: name, bytes: document.bytes) !=
          null;
    } finally {
      // Remove only this export's iOS staging file, never other plugins' files.
      if (Platform.isIOS) {
        final staged = File('${Directory.systemTemp.path}/$name');
        if (await staged.exists()) await staged.delete();
      }
    }
  }
}

String safeDocumentName(String name) {
  final base = name.replaceAll('\\', '/').split('/').last;
  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
  return safe.isEmpty || safe == '.' || safe == '..' ? 'document' : safe;
}

final documentExporterProvider = Provider<DocumentExporter>(
  (ref) => NativeDocumentExporter(),
);
final documentExportProvider =
    NotifierProvider.autoDispose<DocumentExport, AsyncValue<void>>(
      DocumentExport.new,
    );

class DocumentExport extends Notifier<AsyncValue<void>> {
  CancelToken? _pending;
  int _epoch = 0;
  @override
  AsyncValue<void> build() {
    ref.watch(
      sessionControllerProvider.select((s) => (s.status, s.profile?.id)),
    );
    _epoch++;
    _pending?.cancel('Session changed');
    _pending = null;
    ref.onDispose(() {
      _epoch++;
      _pending?.cancel('Session or screen changed');
    });
    return const AsyncData(null);
  }

  Future<bool> save(String id) async {
    if (!ref.read(sessionControllerProvider).isAuthenticated ||
        state.isLoading) {
      throw _cancelled;
    }
    final epoch = _epoch;
    final token = CancelToken();
    _pending = token;
    state = const AsyncLoading();
    try {
      final document = await ref
          .read(documentRepositoryProvider)
          .download(id, cancelToken: token);
      if (!_current(epoch, token)) throw _cancelled;
      final saved = await ref.read(documentExporterProvider).save(document);
      if (!_current(epoch, token)) throw _cancelled;
      state = const AsyncData(null);
      return saved;
    } catch (error, stack) {
      if (!_current(epoch, token)) throw _cancelled;
      final safe = error is AppException
          ? error
          : const AppException(
              kind: AppErrorKind.unknown,
              message: 'Le document ne peut pas être enregistré.',
            );
      state = AsyncError(safe, stack);
      throw safe;
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }

  bool _current(int epoch, CancelToken token) =>
      ref.mounted &&
      epoch == _epoch &&
      !token.isCancelled &&
      ref.read(sessionControllerProvider).isAuthenticated;
}

const _cancelled = AppException(
  kind: AppErrorKind.cancelled,
  message: 'La session a changé.',
);
