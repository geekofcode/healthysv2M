import 'package:flutter/material.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';

bool appointmentFrench(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'fr';

String appointmentDateTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  final locale = MaterialLocalizations.of(context);
  return '${locale.formatMediumDate(local)} • ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

String appointmentStatus(String status, {required bool french}) =>
    switch (status.toUpperCase()) {
      'REQUESTED' => french ? 'Demandé' : 'Requested',
      'SCHEDULED' => french ? 'Planifié' : 'Scheduled',
      'RESCHEDULED' => french ? 'Reporté' : 'Rescheduled',
      'CONFIRMED' => french ? 'Confirmé' : 'Confirmed',
      'CANCELLED' || 'CANCELED' => french ? 'Annulé' : 'Cancelled',
      'COMPLETED' => french ? 'Terminé' : 'Completed',
      'CHECKED_IN' => french ? 'Arrivé' : 'Checked in',
      'IN_PROGRESS' => french ? 'En cours' : 'In progress',
      'NO_SHOW' => french ? 'Absence' : 'No show',
      _ => french ? 'Statut non renseigné' : 'Status not provided',
    };

String appointmentError(Object error, {required bool french}) {
  if (error is AppException) {
    if (error.statusCode == 409) {
      return french
          ? 'Ce créneau ou ce rendez-vous a changé. Actualisez les disponibilités avant de réessayer.'
          : 'This slot or appointment has changed. Refresh availability before trying again.';
    }
    if (error.statusCode == 404) {
      return french
          ? 'Ce rendez-vous ou ce dossier patient est introuvable.'
          : 'This appointment or patient record could not be found.';
    }
    return localizedErrorMessage(error.kind, french: french);
  }
  return french
      ? 'Une erreur est survenue. Réessayez.'
      : 'Something went wrong. Try again.';
}

class AppointmentFailure extends StatelessWidget {
  const AppointmentFailure({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final fr = appointmentFrench(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 12),
          Text(
            appointmentError(error, french: fr),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(fr ? 'Réessayer' : 'Try again'),
            ),
        ],
      ),
    );
  }
}
