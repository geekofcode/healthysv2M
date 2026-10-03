import '../../../app/layout/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/maternal_child_providers.dart';
import '../domain/maternal_child.dart';
import 'notebook_fields.dart';

class MaternalChildPage extends ConsumerStatefulWidget {
  const MaternalChildPage({super.key});
  @override
  ConsumerState<MaternalChildPage> createState() => _MaternalChildPageState();
}

class _MaternalChildPageState extends ConsumerState<MaternalChildPage> {
  int _pregnancyPage = 0, _childPage = 0;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final pregnancies = pregnanciesProvider(
      MaternalChildListQuery(page: _pregnancyPage),
    );
    final children = childrenProvider(MaternalChildListQuery(page: _childPage));
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Carnet mère-enfant' : 'Mother and child notebook'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pregnancies);
            ref.invalidate(children);
            await Future.wait([
              ref
                  .read(pregnancies.future)
                  .then<void>((_) {})
                  .catchError((Object _) {}),
              ref
                  .read(children.future)
                  .then<void>((_) {})
                  .catchError((Object _) {}),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                fr ? 'Grossesses' : 'Pregnancies',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ClinicalAsyncView(
                value: ref.watch(pregnancies),
                onRetry: () => ref.invalidate(pregnancies),
                missingMessage: fr
                    ? 'Dossier patient indisponible.'
                    : 'Patient record unavailable.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr
                          ? 'Grossesses indisponibles.'
                          : 'Pregnancies unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          fr
                              ? 'Aucune grossesse enregistrée.'
                              : 'No recorded pregnancies.',
                        ),
                      for (final pregnancy in data.content)
                        Card(
                          child: ListTile(
                            selected: AdaptiveNavigation.isSelected(
                              context,
                              pregnancy.id,
                              routePrefix: '/maternal-child/pregnancies',
                            ),
                            leading: const Icon(Icons.pregnant_woman_outlined),
                            title: Text(pregnancy.pregnancyNumber),
                            subtitle: Text(
                              '${notebookStatus(pregnancy.status, fr)}\n${fr ? 'Terme prévu' : 'Expected delivery'} : ${notebookDate(context, pregnancy.expectedDeliveryDate)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => AdaptiveNavigation.openDetail(
                              context,
                              'pregnancy-detail',
                              pathParameters: {'id': pregnancy.id},
                            ),
                          ),
                        ),
                      ClinicalPagination(
                        number: data.number,
                        totalPages: data.totalPages,
                        last: data.last,
                        onPrevious: () => setState(() => _pregnancyPage--),
                        onNext: () => setState(() => _pregnancyPage++),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                fr ? 'Enfants' : 'Children',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ClinicalAsyncView(
                value: ref.watch(children),
                onRetry: () => ref.invalidate(children),
                missingMessage: fr
                    ? 'Dossier patient indisponible.'
                    : 'Patient record unavailable.',
                builder: (data) {
                  if (data == null) {
                    return Text(
                      fr ? 'Enfants indisponibles.' : 'Children unavailable.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.content.isEmpty)
                        Text(
                          fr
                              ? 'Aucun carnet enfant accessible.'
                              : 'No accessible child notebook.',
                        ),
                      for (final child in data.content)
                        Card(
                          child: ListTile(
                            selected: AdaptiveNavigation.isSelected(
                              context,
                              child.childPatientId,
                              routePrefix: '/maternal-child/children',
                            ),
                            leading: const Icon(Icons.child_care_outlined),
                            title: Text(
                              [child.firstName, child.lastName]
                                      .whereType<String>()
                                      .where((name) => name.trim().isNotEmpty)
                                      .join(' ')
                                      .isEmpty
                                  ? (fr ? 'Enfant' : 'Child')
                                  : [child.firstName, child.lastName]
                                        .whereType<String>()
                                        .where((name) => name.trim().isNotEmpty)
                                        .join(' '),
                            ),
                            subtitle: Text(
                              '${notebookDate(context, child.dateOfBirth)}\n${notebookStatus(child.status, fr)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => AdaptiveNavigation.openDetail(
                              context,
                              'child-detail',
                              pathParameters: {'id': child.childPatientId},
                            ),
                          ),
                        ),
                      ClinicalPagination(
                        number: data.number,
                        totalPages: data.totalPages,
                        last: data.last,
                        onPrevious: () => setState(() => _childPage--),
                        onNext: () => setState(() => _childPage++),
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
