import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

const documentExportPrefix = 'healthys-export-';

/// Each preview owns one private directory; no document is retained as a cache.
class DocumentPreviewStorage {
  DocumentPreviewStorage({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  Future<Directory> _root() async => Directory(
    '${(await _temporaryDirectory()).path}/healthys-document-previews',
  );
  Future<void> purge() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<TemporaryDocumentPreview> create(Uint8List bytes) async {
    final root = await _root();
    await root.create(recursive: true);
    final directory = await root.createTemp('view-');
    final file = File('${directory.path}/document.pdf');
    try {
      await file.writeAsBytes(bytes, flush: true);
      return TemporaryDocumentPreview(file, directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }
}

class TemporaryDocumentPreview {
  TemporaryDocumentPreview(this.file, this.directory);
  final File file;
  final Directory directory;
  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<void> cleanDocumentTemporaryFiles() async {
  await DocumentPreviewStorage().purge();
  if (Platform.isIOS) {
    await for (final entry in Directory.systemTemp.list(followLinks: false)) {
      if (entry is File &&
          entry.uri.pathSegments.last.startsWith(documentExportPrefix)) {
        await entry.delete();
      }
    }
  }
}
