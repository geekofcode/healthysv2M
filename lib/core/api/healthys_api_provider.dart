import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthys_api/healthys_api.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';

/// Shares the configured transport, secure token handling and error mapping.
final healthysApiProvider = Provider<HealthysApi>((ref) {
  return HealthysApi(
    dio: ref.watch(dioProvider),
    basePathOverride: ref.watch(appConfigProvider).apiBaseUrl.toString(),
    // Authentication is provided by the application's Dio interceptor.
    interceptors: const [],
  );
});
