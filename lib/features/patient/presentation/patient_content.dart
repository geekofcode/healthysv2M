import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../application/patient_dashboard_provider.dart';
import '../domain/patient_dashboard.dart';

/// Medical data stays in the session-scoped provider, never in local storage.
class PatientContent extends ConsumerWidget {
  const PatientContent({super.key, required this.builder});

  final Widget Function(BuildContext, PatientDashboard) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(patientDashboardProvider);
    final french = Localizations.localeOf(context).languageCode == 'fr';
    void retry() => ref.invalidate(patientDashboardProvider);
    if (value.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (value.hasError) {
      final error = value.error;
      if (error is AppException && error.statusCode == 403) {
        return PatientNotice(
          message: french
              ? 'Cet espace est réservé aux comptes patients.'
              : 'This space is available to patient accounts only.',
          onRetry: retry,
        );
      }
      if (error is AppException && error.statusCode == 404) {
        return _unlinked(french, retry);
      }
      return ErrorView(
        error: error is AppException
            ? error
            : const AppException(kind: AppErrorKind.unknown, message: ''),
        onRetry: retry,
      );
    }
    final dashboard = value.value;
    if (dashboard == null) return _unlinked(french, retry);
    return builder(context, dashboard);
  }

  Widget _unlinked(bool french, VoidCallback retry) => PatientNotice(
    message: french
        ? 'Aucun dossier patient n’est lié à votre compte. Contactez votre établissement.'
        : 'No patient record is linked to your account. Contact your organization.',
    onRetry: retry,
  );
}

class PatientNotice extends StatelessWidget {
  const PatientNotice({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.info_outline),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: Text(
              Localizations.localeOf(context).languageCode == 'fr'
                  ? 'Réessayer'
                  : 'Try again',
            ),
          ),
      ],
    ),
  );
}

class PatientSection extends StatelessWidget {
  const PatientSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class PatientField extends StatelessWidget {
  const PatientField({super.key, required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          value?.trim().isNotEmpty == true
              ? value!
              : Localizations.localeOf(context).languageCode == 'fr'
              ? 'Non renseigné'
              : 'Not provided',
        ),
      ],
    ),
  );
}
