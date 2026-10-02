import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../patient/presentation/patient_content.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment.dart';
import 'appointment_async_view.dart';
import 'appointment_labels.dart';

class AppointmentDetailPage extends ConsumerStatefulWidget {
  const AppointmentDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AppointmentDetailPage> createState() =>
      _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends ConsumerState<AppointmentDetailPage> {
  bool _busy = false;
  Object? _error;
  @override
  Widget build(BuildContext context) {
    final action = ref.watch(appointmentActionsProvider);
    final fr = appointmentFrench(context);
    final provider = appointmentDetailProvider(widget.id);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Rendez-vous' : 'Appointment')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {
              /* Controlled state below. */
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              AppointmentAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                builder: (appointment) {
                  if (appointment == null) {
                    return Text(
                      fr
                          ? 'Rendez-vous indisponible.'
                          : 'Appointment unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PatientSection(
                        title: fr
                            ? 'Détails du rendez-vous'
                            : 'Appointment details',
                        children: [
                          PatientField(
                            label: fr ? 'Numéro' : 'Number',
                            value: appointment.appointmentNumber,
                          ),
                          PatientField(
                            label: fr ? 'Professionnel' : 'Professional',
                            value: appointment.professionalName,
                          ),
                          PatientField(
                            label: fr ? 'Établissement' : 'Organization',
                            value: appointment.organizationName,
                          ),
                          PatientField(
                            label: fr ? 'Début' : 'Starts',
                            value: appointmentDateTime(
                              context,
                              appointment.scheduledStart,
                            ),
                          ),
                          PatientField(
                            label: fr ? 'Fin' : 'Ends',
                            value: appointmentDateTime(
                              context,
                              appointment.scheduledEnd,
                            ),
                          ),
                          PatientField(
                            label: fr ? 'Statut' : 'Status',
                            value: appointmentStatus(
                              appointment.status,
                              french: fr,
                            ),
                          ),
                          PatientField(
                            label: fr ? 'Motif' : 'Reason',
                            value: appointment.reason,
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        AppointmentFailure(error: _error!),
                        Text(
                          fr
                              ? 'Vérifiez l’état de votre rendez-vous avant de soumettre à nouveau une demande.'
                              : 'Check your appointment status before submitting another request.',
                        ),
                      ],
                      if (appointment.canReschedule)
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => context.pushNamed(
                                  'appointment-reschedule',
                                  pathParameters: {'id': widget.id},
                                ),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: Text(
                            fr
                                ? 'Reporter le rendez-vous'
                                : 'Reschedule appointment',
                          ),
                        ),
                      if (appointment.canCancel)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _cancel(appointment),
                          icon: const Icon(Icons.event_busy_outlined),
                          label: Text(
                            fr
                                ? 'Annuler le rendez-vous'
                                : 'Cancel appointment',
                          ),
                        ),
                      if (_busy && action.isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(AppointmentSummary appointment) async {
    final fr = appointmentFrench(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final confirmed = await confirmAppointmentAction(
      context,
      title: fr ? 'Annuler ce rendez-vous ?' : 'Cancel this appointment?',
      message:
          '${appointment.professionalName ?? ''}\n${appointmentDateTime(context, appointment.scheduledStart)}',
      confirmLabel: fr ? 'Confirmer l’annulation' : 'Confirm cancellation',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _busy = false);
      return;
    }
    try {
      await ref.read(appointmentActionsProvider.notifier).cancel(widget.id);
      if (!mounted) return;
      ref.invalidate(appointmentDetailProvider(widget.id));
      ref.invalidate(appointmentsProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
