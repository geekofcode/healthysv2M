import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/features/documents/application/document_preview_storage.dart';
import 'package:healthysv2/features/documents/application/document_export.dart';

void main() {
  test('preview disposal and startup purge remove only owned files', () async {
    final temp = await Directory.systemTemp.createTemp(
      'healthys-storage-test-',
    );
    addTearDown(() => temp.delete(recursive: true));
    final other = await File(
      '${temp.path}/another-plugin.txt',
    ).writeAsString('keep');
    final storage = DocumentPreviewStorage(
      temporaryDirectory: () async => temp,
    );
    final first = await storage.create(Uint8List.fromList([1, 2, 3]));
    final second = await storage.create(Uint8List.fromList([4, 5]));
    expect(await first.file.readAsBytes(), [1, 2, 3]);
    await first.dispose();
    await first.dispose();
    expect(await first.directory.exists(), isFalse);
    expect(await second.file.exists(), isTrue);
    await storage.purge();
    expect(await second.directory.exists(), isFalse);
    expect(await other.readAsString(), 'keep');
  });
  test('export names cannot contain path traversal', () {
    expect(safeDocumentName('../../diagnostic.pdf'), 'diagnostic.pdf');
    expect(safeDocumentName(r'C:\private\result.pdf'), 'result.pdf');
    expect(safeDocumentName('..'), 'document');
    expect(safeDocumentName(''), 'document');
  });
}
