import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';
import '../application/patient_medical_record_provider.dart';
import '../domain/patient_medical_record.dart';
import 'patient_content.dart';

class MedicalRecordContent extends ConsumerWidget {
  const MedicalRecordContent({super.key, required this.builder});
  final Widget Function(BuildContext, PatientMedicalRecord) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(patientMedicalRecordProvider);
    final french = Localizations.localeOf(context).languageCode == 'fr';
    void retry() => ref.invalidate(patientMedicalRecordProvider);
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
              ? 'Ce dossier est réservé au patient concerné.'
              : 'This record is available to the patient concerned only.',
          onRetry: retry,
        );
      }
      if (error is AppException && error.statusCode == 404) {
        return _missing(french, retry);
      }
      return ErrorView(
        error: error is AppException
            ? error
            : const AppException(kind: AppErrorKind.unknown, message: ''),
        onRetry: retry,
      );
    }
    final record = value.value;
    if (record == null) return _missing(french, retry);
    return builder(context, record);
  }

  Widget _missing(bool french, VoidCallback retry) => PatientNotice(
    message: french
        ? 'Aucun dossier patient n’est lié à votre compte. Contactez votre établissement.'
        : 'No patient record is linked to your account. Contact your organization.',
    onRetry: retry,
  );
}
