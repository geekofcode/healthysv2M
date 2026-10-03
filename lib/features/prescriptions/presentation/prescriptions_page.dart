import '../../../app/layout/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/prescription_providers.dart';
import '../domain/prescription.dart';
import 'prescription_labels.dart';

class PrescriptionsPage extends ConsumerStatefulWidget {
  const PrescriptionsPage({super.key});
  @override
  ConsumerState<PrescriptionsPage> createState() => _PrescriptionsPageState();
}

class _PrescriptionsPageState extends ConsumerState<PrescriptionsPage> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final provider = prescriptionsProvider(PrescriptionListQuery(page: _page));
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Mes prescriptions' : 'My prescriptions'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {}
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
                          ? 'Prescriptions indisponibles.'
                          : 'Prescriptions unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          fr
                              ? 'Aucune prescription disponible.'
                              : 'No prescriptions available.',
                        ),
                      for (final prescription in data.content)
                        Card(
                          child: ListTile(
                            selected: AdaptiveNavigation.isSelected(
                              context,
                              prescription.id,
                              routePrefix: '/prescriptions',
                            ),
                            leading: const Icon(Icons.medication_outlined),
                            title: Text(prescription.prescriptionNumber),
                            subtitle: Text(
                              [
                                prescription.prescriberName ??
                                    (fr
                                        ? 'Prescripteur non renseigné'
                                        : 'Prescriber not provided'),
                                clinicalDateTime(
                                  context,
                                  prescription.prescribedAt,
                                ),
                                prescriptionStatus(prescription.status, fr),
                                if (prescription.expired)
                                  fr
                                      ? 'Date de validité dépassée'
                                      : 'Validity date has passed',
                              ].join('\n'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => AdaptiveNavigation.openDetail(
                              context,
                              'prescription-detail',
                              pathParameters: {'id': prescription.id},
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
