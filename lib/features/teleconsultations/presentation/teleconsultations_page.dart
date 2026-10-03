import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../consultations/presentation/clinical_async_view.dart';
import '../application/teleconsultation_providers.dart';
import '../domain/teleconsultation.dart';

class TeleconsultationsPage extends ConsumerStatefulWidget {
  const TeleconsultationsPage({super.key});

  @override
  ConsumerState<TeleconsultationsPage> createState() =>
      _TeleconsultationsPageState();
}

class _TeleconsultationsPageState extends ConsumerState<TeleconsultationsPage> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final provider = videoSessionsProvider(VideoSessionQuery(page: _page));
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Mes téléconsultations' : 'My video consultations'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {
              // The view displays a controlled error without medical details.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Téléconsultations indisponibles.'
                    : 'Video consultations unavailable.',
                builder: (data) {
                  if (data == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          fr
                              ? 'Aucune téléconsultation.'
                              : 'No video consultations.',
                        ),
                      for (final session in data.content)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.video_call_outlined),
                            title: Text(session.sessionNumber),
                            subtitle: Text(
                              [
                                for (final participant in session.participants)
                                  if (participant.role == 'PROFESSIONAL' &&
                                      participant.displayName != null)
                                    participant.displayName!,
                                clinicalDateTime(
                                  context,
                                  session.scheduledStart,
                                ),
                                teleconsultationStatus(
                                  session.status,
                                  french: fr,
                                ),
                              ].join('\n'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.pushNamed(
                              'teleconsultation-room',
                              pathParameters: {'id': session.id},
                            ),
                          ),
                        ),
                      ClinicalPagination(
                        number: data.number,
                        totalPages: data.totalPages,
                        last: data.number + 1 >= data.totalPages,
                        onPrevious: () => setState(() => _page--),
                        onNext: () => setState(() => _page++),
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

String teleconsultationStatus(String status, {required bool french}) =>
    switch (status) {
      'SCHEDULED' => french ? 'Planifiée' : 'Scheduled',
      'ACTIVE' => french ? 'Ouverte' : 'Open',
      'COMPLETED' || 'ENDED' => french ? 'Terminée' : 'Completed',
      'CANCELLED' => french ? 'Annulée' : 'Cancelled',
      _ => french ? 'En attente' : 'Pending',
    };
