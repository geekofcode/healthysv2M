import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/healthys_app.dart';
import 'core/config/app_config.dart';
import 'features/documents/application/document_preview_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  try {
    await cleanDocumentTemporaryFiles();
  } catch (_) {
    // A storage failure does not prevent login; previews report their own errors.
  }
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const HealthysApp(),
    ),
  );
}
