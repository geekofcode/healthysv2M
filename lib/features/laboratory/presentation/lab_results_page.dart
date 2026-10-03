import '../../../app/layout/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/lab_result_providers.dart';
import '../domain/lab_result.dart';

class LabResultsPage extends ConsumerStatefulWidget {
  const LabResultsPage({super.key});
  @override
  ConsumerState<LabResultsPage> createState() => _LabResultsPageState();
}

class _LabResultsPageState extends ConsumerState<LabResultsPage> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final provider = labResultsProvider(LabResultListQuery(page: _page));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fr ? 'Mes résultats de laboratoire' : 'My laboratory results',
        ),
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
              Text(
                fr
                    ? 'Résultats validés par le laboratoire'
                    : 'Results validated by the laboratory',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ClinicalAsyncView(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                missingMessage: fr
                    ? 'Aucun dossier patient n’est lié à votre compte.'
                    : 'No patient record is linked to your account.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr ? 'Résultats indisponibles.' : 'Results unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          fr
                              ? 'Aucun résultat validé disponible.'
                              : 'No validated results available.',
                        ),
                      for (final result in data.content)
                        Card(
                          child: ListTile(
                            selected: AdaptiveNavigation.isSelected(
                              context,
                              item.id,
                              routePrefix: '/lab-results',
                            ),
                            leading: const Icon(Icons.science_outlined),
                            title: Text(result.resultNumber),
                            subtitle: Text(
                              [
                                result.laboratoryName ??
                                    (fr
                                        ? 'Laboratoire non renseigné'
                                        : 'Laboratory not provided'),
                                clinicalDateTime(context, result.validatedAt),
                                fr ? 'Validé' : 'Validated',
                              ].join('\n'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => AdaptiveNavigation.openDetail(
                              context,
                              'lab-result-detail',
                              pathParameters: {'id': result.id},
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
