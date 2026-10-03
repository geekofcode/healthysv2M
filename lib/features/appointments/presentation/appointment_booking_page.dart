import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment.dart';
import 'appointment_async_view.dart';
import 'appointment_labels.dart';

class AppointmentBookingPage extends ConsumerWidget {
  const AppointmentBookingPage({super.key, this.appointmentId});
  final String? appointmentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fr = appointmentFrench(context);
    final id = appointmentId;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          id == null
              ? (fr ? 'Prendre rendez-vous' : 'Book an appointment')
              : (fr ? 'Reporter le rendez-vous' : 'Reschedule appointment'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (id == null)
              AppointmentAsyncView(
                value: ref.watch(bookingOptionsProvider),
                onRetry: () => ref.invalidate(bookingOptionsProvider),
                builder: (options) {
                  if (options == null) {
                    return Text(
                      fr
                          ? 'Les réservations sont indisponibles.'
                          : 'Booking is unavailable.',
                    );
                  }
                  if (options.organizations.isEmpty) {
                    return Text(
                      fr
                          ? 'Aucun établissement ne permet la réservation pour votre dossier. Contactez votre établissement.'
                          : 'No organization offers booking for your record. Contact your organization.',
                    );
                  }
                  return _BookingForm(
                    key: ObjectKey(options),
                    options: options,
                  );
                },
              ),
            if (id != null)
              AppointmentAsyncView(
                value: ref.watch(appointmentDetailProvider(id)),
                onRetry: () => ref.invalidate(appointmentDetailProvider(id)),
                builder: (appointment) {
                  if (appointment == null) {
                    return Text(
                      fr
                          ? 'Rendez-vous indisponible.'
                          : 'Appointment unavailable.',
                    );
                  }
                  if (!appointment.canReschedule) {
                    return Text(
                      fr
                          ? 'Ce rendez-vous ne peut plus être reporté.'
                          : 'This appointment can no longer be rescheduled.',
                    );
                  }
                  return _BookingForm(
                    key: ObjectKey(appointment),
                    appointment: appointment,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingForm extends ConsumerStatefulWidget {
  const _BookingForm({super.key, this.options, this.appointment});
  final BookingOptions? options;
  final AppointmentSummary? appointment;
  @override
  ConsumerState<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<_BookingForm> {
  final _reason = TextEditingController();
  String? _organizationId;
  String? _professionalId;
  DateTime _day = DateTime.now();
  DateTime _searchFrom = DateTime.now();
  AppointmentSlot? _slot;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final appointment = widget.appointment;
    if (appointment != null) {
      _organizationId = appointment.organizationId;
      _professionalId = appointment.professionalId;
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  AvailabilityQuery? get _query {
    final organizationId = _organizationId;
    final professionalId = _professionalId;
    if (organizationId == null || professionalId == null) return null;
    final dayStart = DateTime(_day.year, _day.month, _day.day);
    final from = dayStart.isBefore(_searchFrom) ? _searchFrom : dayStart;
    return AvailabilityQuery(
      organizationId: organizationId,
      professionalId: professionalId,
      from: from.toUtc(),
      to: DateTime(_day.year, _day.month, _day.day + 1).toUtc(),
      excludeAppointmentId: widget.appointment?.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(appointmentActionsProvider);
    final fr = appointmentFrench(context);
    final original = widget.appointment;
    final options = widget.options;
    final professionals =
        options?.professionals
            .where((p) => p.organizationId == _organizationId)
            .toList() ??
        <BookingProfessional>[];
    final query = _query;
    final availability = query == null
        ? null
        : ref.watch(availabilityProvider(query));
    final slotValid =
        availability != null &&
        !availability.isLoading &&
        !availability.hasError &&
        availability.value?.any(
              (s) =>
                  s.scheduledStart == _slot?.scheduledStart &&
                  s.scheduledEnd == _slot?.scheduledEnd,
            ) ==
            true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (original == null && options != null) ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            key: ValueKey('organization-$_organizationId'),
            initialValue: _organizationId,
            decoration: InputDecoration(
              labelText: fr ? 'Établissement' : 'Organization',
            ),
            items: [
              for (final organization in options.organizations)
                DropdownMenuItem(
                  value: organization.id,
                  child: Text(organization.name, softWrap: true),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _organizationId = value;
                    _searchFrom = DateTime.now();
                    _professionalId = null;
                    _slot = null;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            key: ValueKey('professional-$_organizationId-$_professionalId'),
            initialValue: _professionalId,
            decoration: InputDecoration(
              labelText: fr ? 'Professionnel' : 'Professional',
            ),
            items: [
              for (final professional in professionals)
                DropdownMenuItem(
                  value: professional.id,
                  child: Text(professional.name, softWrap: true),
                ),
            ],
            onChanged: _busy || professionals.isEmpty
                ? null
                : (value) => setState(() {
                    _professionalId = value;
                    _searchFrom = DateTime.now();
                    _slot = null;
                    _error = null;
                  }),
          ),
          if (_organizationId != null && professionals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                fr
                    ? 'Aucun professionnel disponible dans cet établissement.'
                    : 'No professionals available in this organization.',
              ),
            ),
        ],
        if (original != null) ...[
          Text(
            original.organizationName ??
                (fr
                    ? 'Établissement non renseigné'
                    : 'Organization not provided'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            original.professionalName ??
                (fr
                    ? 'Professionnel non renseigné'
                    : 'Professional not provided'),
          ),
          Text(
            '${fr ? 'Rendez-vous actuel' : 'Current appointment'} : ${appointmentDateTime(context, original.scheduledStart)}',
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickDay,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(MaterialLocalizations.of(context).formatMediumDate(_day)),
        ),
        Text(
          fr
              ? 'Les horaires sont affichés dans le fuseau horaire de votre appareil.'
              : 'Times are shown in your device’s time zone.',
        ),
        const SizedBox(height: 16),
        if (query == null)
          Text(
            fr
                ? 'Choisissez un établissement et un professionnel pour afficher les créneaux.'
                : 'Choose an organization and professional to view available slots.',
          ),
        if (query != null)
          AppointmentAsyncView(
            value: availability!,
            onRetry: () => _refreshSlots(query),
            builder: (slots) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  fr ? 'Créneaux disponibles' : 'Available slots',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (slots == null || slots.isEmpty)
                  Text(
                    fr
                        ? 'Aucun créneau disponible pour cette date.'
                        : 'No available slots for this date.',
                  ),
                if (slots != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in slots)
                        ChoiceChip(
                          label: Text(
                            appointmentDateTime(context, slot.scheduledStart),
                          ),
                          selected:
                              _slot?.scheduledStart == slot.scheduledStart &&
                              _slot?.scheduledEnd == slot.scheduledEnd,
                          onSelected: _busy
                              ? null
                              : (selected) => setState(() {
                                  _slot = selected ? slot : null;
                                  _error = null;
                                }),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        if (query != null)
          TextButton.icon(
            onPressed: _busy ? null : () => _refreshSlots(query),
            icon: const Icon(Icons.refresh),
            label: Text(
              fr ? 'Actualiser les disponibilités' : 'Refresh availability',
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _reason,
          enabled: !_busy,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: original == null
                ? (fr ? 'Motif (facultatif)' : 'Reason (optional)')
                : (fr
                      ? 'Motif du report (facultatif)'
                      : 'Reason for rescheduling (optional)'),
          ),
        ),
        if (_error != null) ...[
          AppointmentFailure(error: _error!),
          if (_error is AppException &&
              const [
                AppErrorKind.network,
                AppErrorKind.timeout,
              ].contains((_error as AppException).kind))
            Text(
              fr
                  ? 'La demande a peut-être été traitée. Vérifiez vos rendez-vous avant de réessayer.'
                  : 'The request may have been processed. Check your appointments before trying again.',
            ),
          TextButton(
            onPressed: _busy ? null : () => context.goNamed('appointments'),
            child: Text(
              fr ? 'Vérifier mes rendez-vous' : 'Check my appointments',
            ),
          ),
        ],
        FilledButton(
          onPressed: _busy || !slotValid ? null : _submit,
          child: Text(
            original == null
                ? (fr ? 'Réserver ce créneau' : 'Book this slot')
                : (fr ? 'Confirmer le nouveau créneau' : 'Confirm new slot'),
          ),
        ),
        if (_busy && action.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  void _refreshSlots(AvailabilityQuery previous) {
    setState(() {
      _slot = null;
      _searchFrom = DateTime.now();
      final today = DateTime(
        _searchFrom.year,
        _searchFrom.month,
        _searchFrom.day,
      );
      if (_day.isBefore(today)) {
        _day = today;
      }
    });
    if (_query == previous) {
      ref.invalidate(availabilityProvider(previous));
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(first) ? first : _day,
      firstDate: first,
      lastDate: first.add(const Duration(days: 30)),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _day = chosen;
      _searchFrom = DateTime.now();
      _slot = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final slot = _slot;
    if (slot == null || _busy) return;
    final fr = appointmentFrench(context);
    final original = widget.appointment;
    setState(() {
      _busy = true;
      _error = null;
    });
    final confirmed = await confirmAppointmentAction(
      context,
      title: original == null
          ? (fr ? 'Confirmer la réservation ?' : 'Confirm booking?')
          : (fr ? 'Confirmer le report ?' : 'Confirm reschedule?'),
      message: appointmentDateTime(context, slot.scheduledStart),
      confirmLabel: fr ? 'Confirmer' : 'Confirm',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _busy = false);
      return;
    }
    try {
      final actions = ref.read(appointmentActionsProvider.notifier);
      final reason = _reason.text.trim();
      final result = original == null
          ? await actions.create(
              organizationId: _organizationId!,
              professionalId: _professionalId!,
              scheduledStart: slot.scheduledStart,
              scheduledEnd: slot.scheduledEnd,
              reason: reason.isEmpty ? null : reason,
            )
          : await actions.reschedule(
              original.id,
              scheduledStart: slot.scheduledStart,
              scheduledEnd: slot.scheduledEnd,
              reason: reason.isEmpty ? null : reason,
            );
      if (!mounted) return;
      ref.invalidate(appointmentsProvider);
      ref.invalidate(appointmentDetailProvider(result.id));
      if (_query case final AvailabilityQuery query) {
        ref.invalidate(availabilityProvider(query));
      }
      context.goNamed('appointment-detail', pathParameters: {'id': result.id});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _slot = null;
        _searchFrom = DateTime.now();
      });
      if (_query case final AvailabilityQuery query) {
        ref.invalidate(availabilityProvider(query));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
