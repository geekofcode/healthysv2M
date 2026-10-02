import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/consultation_providers.dart';
import '../domain/consultation.dart';
import 'clinical_async_view.dart';
import 'consultation_labels.dart';

class ConsultationHistoryPage extends ConsumerStatefulWidget {
  const ConsultationHistoryPage({super.key});
  @override
  ConsumerState<ConsultationHistoryPage> createState() =>
      _ConsultationHistoryPageState();
}

class _ConsultationHistoryPageState
    extends ConsumerState<ConsultationHistoryPage> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final provider = consultationsProvider(ConsultationListQuery(page: _page));
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Mes consultations' : 'My consultations'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {
              /* The controlled state renders below. */
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
                    ? 'Aucun dossier patient n’est lié à votre compte.'
                    : 'No patient record is linked to your account.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr
                          ? 'Les consultations sont indisponibles.'
                          : 'Consultations are unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          fr
                              ? 'Aucune consultation enregistrée.'
                              : 'No recorded consultations.',
                        ),
                      for (final consultation in data.content)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.medical_services_outlined,
                            ),
                            title: Text(
                              clinicalDateTime(context, consultation.startedAt),
                            ),
                            subtitle: Text(
                              [
                                consultation.professionalName ??
                                    (fr
                                        ? 'Professionnel non renseigné'
                                        : 'Professional not provided'),
                                consultation.organizationName ??
                                    (fr
                                        ? 'Établissement non renseigné'
                                        : 'Organization not provided'),
                                consultationStatus(
                                  consultation.status,
                                  french: fr,
                                ),
                              ].join('\n'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.pushNamed(
                              'consultation-detail',
                              pathParameters: {'id': consultation.id},
                            ),
                          ),
                        ),
                      ClinicalPagination(
                        number: data.number,
                        totalPages: data.totalPages,
                        last: data.last,
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
