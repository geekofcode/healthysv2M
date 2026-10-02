import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../documents/application/document_export.dart';

class PickedMessagingFile {
  const PickedMessagingFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

abstract interface class MessagingFilePicker {
  Future<PickedMessagingFile?> pick();
}

class NativeMessagingFilePicker implements MessagingFilePicker {
  @override
  Future<PickedMessagingFile?> pick() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
      );
      if (file == null) {
        return null;
      }
      const maxBytes = 25 * 1024 * 1024;
      final size = await file.length();
      if (size == null || size <= 0 || size > maxBytes) {
        throw const AppException(kind: AppErrorKind.validation, message: '');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (builder.length + chunk.length > maxBytes) {
          throw const AppException(kind: AppErrorKind.validation, message: '');
        }
        builder.add(chunk);
      }
      if (builder.length != size || builder.isEmpty) {
        throw const AppException(kind: AppErrorKind.validation, message: '');
      }
      return PickedMessagingFile(
        name: safeDocumentName(file.name),
        bytes: builder.takeBytes(),
      );
    } finally {
      // Native pickers may cache a copy; the draft keeps only bounded bytes.
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {
        // No app-managed preview or downloaded copy is created here.
      }
    }
  }
}

final messagingFilePickerProvider = Provider<MessagingFilePicker>(
  (ref) => NativeMessagingFilePicker(),
);
