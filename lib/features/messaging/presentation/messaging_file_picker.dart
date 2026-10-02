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
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
        withData: false,
        withReadStream: true,
      );
      if (selection == null) {
        return null;
      }
      final file = selection.files.single;
      const maxBytes = 25 * 1024 * 1024;
      if (file.size <= 0 || file.size > maxBytes) {
        throw const AppException(kind: AppErrorKind.validation, message: '');
      }
      final builder = BytesBuilder(copy: false);
      if (file.readStream case final stream?) {
        await for (final chunk in stream) {
          if (builder.length + chunk.length > maxBytes) {
            throw const AppException(
              kind: AppErrorKind.validation,
              message: '',
            );
          }
          builder.add(chunk);
        }
      } else if (file.bytes case final bytes?) {
        if (bytes.length > maxBytes) {
          throw const AppException(kind: AppErrorKind.validation, message: '');
        }
        builder.add(bytes);
      }
      if (builder.length != file.size || builder.isEmpty) {
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
