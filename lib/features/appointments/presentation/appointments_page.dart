import '../../../app/layout/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/appointment_providers.dart';
import '../domain/appointment.dart';
import 'appointment_async_view.dart';
import 'appointment_labels.dart';

class AppointmentsPage extends ConsumerStatefulWidget {
  const AppointmentsPage({super.key});
  @override
  ConsumerState<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends ConsumerState<AppointmentsPage> {
  AppointmentView _view = AppointmentView.upcoming;
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final fr = appointmentFrench(context);
    final query = AppointmentListQuery(view: _view, page: _page);
    final provider = appointmentsProvider(query);
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Mes rendez-vous' : 'My appointments')),
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
              FilledButton.icon(
                onPressed: () => context.pushNamed('appointment-book'),
                icon: const Icon(Icons.add),
                label: Text(fr ? 'Prendre rendez-vous' : 'Book an appointment'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<AppointmentView>(
                segments: [
                  ButtonSegment(
                    value: AppointmentView.upcoming,
                    label: Text(fr ? 'À venir' : 'Upcoming'),
                  ),
                  ButtonSegment(
                    value: AppointmentView.past,
                    label: Text(fr ? 'Historique' : 'History'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (values) => setState(() {
                  _view = values.first;
                  _page = 0;
                }),
              ),
              const SizedBox(height: 16),
              AppointmentAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr
                          ? 'Connectez-vous pour consulter vos rendez-vous.'
                          : 'Sign in to view your appointments.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          _view == AppointmentView.upcoming
                              ? (fr
                                    ? 'Aucun rendez-vous à venir.'
                                    : 'No upcoming appointments.')
                              : (fr
                                    ? 'Aucun rendez-vous dans votre historique.'
                                    : 'No appointment history.'),
                        ),
                      for (final appointment in data.content)
                        Card(
                          child: ListTile(
                            selected: AdaptiveNavigation.isSelected(
                              context,
                              appointment.id,
                              routePrefix: '/appointments',
                            ),
                            leading: const Icon(Icons.event_outlined),
                            title: Text(
                              appointmentDateTime(
                                context,
                                appointment.scheduledStart,
                              ),
                            ),
                            subtitle: Text(
                              [
                                appointment.professionalName ??
                                    (fr
                                        ? 'Professionnel non renseigné'
                                        : 'Professional not provided'),
                                appointment.organizationName ??
                                    (fr
                                        ? 'Établissement non renseigné'
                                        : 'Organization not provided'),
                                appointmentStatus(
                                  appointment.status,
                                  french: fr,
                                ),
                              ].join('\n'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => AdaptiveNavigation.openDetail(
                              context,
                              'appointment-detail',
                              pathParameters: {'id': appointment.id},
                            ),
                          ),
                        ),
                      if (data.totalPages > 1)
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _page > 0
                                  ? () => setState(() => _page--)
                                  : null,
                              child: Text(fr ? 'Précédent' : 'Previous'),
                            ),
                            Text(
                              '${fr ? 'Page' : 'Page'} ${data.number + 1} / ${data.totalPages}',
                            ),
                            TextButton(
                              onPressed: !data.last
                                  ? () => setState(() => _page++)
                                  : null,
                              child: Text(fr ? 'Suivant' : 'Next'),
                            ),
                          ],
                        ),
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
}
