import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'adaptive_navigation.dart';

class AdaptiveMaster {
  const AdaptiveMaster({
    required this.path,
    required this.child,
    this.selectedId,
  });
  final String path;
  final Widget child;
  final String? selectedId;
}

/// The routed detail stays inside GoRouter's navigator, preserving route
/// visibility, system back, and video/message lifecycle semantics.
class AdaptivePatientShell extends StatelessWidget {
  const AdaptivePatientShell({
    required this.path,
    required this.child,
    this.master,
    super.key,
  });
  final String path;
  final Widget child;
  final AdaptiveMaster? master;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rail = supportsMasterDetail(context, constraints.maxWidth);
      final usable = constraints.maxWidth - (rail ? 96 : 0);
      final split = master != null && supportsMasterDetail(context, usable);
      final detail = master != null && path != master!.path;
      final masterWidth = split ? (usable * .38).clamp(280.0, 420.0) : usable;
      final detailWidth = split ? usable - masterWidth - 1 : usable;
      final fr = Localizations.localeOf(context).languageCode == 'fr';
      final content = master == null
          ? Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: path == '/'
                      ? 1440
                      : path.startsWith('/teleconsultations/')
                      ? double.infinity
                      : 1000,
                ),
                child: child,
              ),
            )
          : AdaptiveSelection(
              selectedId: master!.selectedId,
              listPath: master!.path,
              routePath: path,
              split: split,
              masterVisible: split || !detail,
              child: Row(
                children: [
                  // Stable slot preserves list filters, pagination and scroll
                  // when selecting another detail or resizing the window.
                  Offstage(
                    offstage: !split && detail,
                    child: SizedBox(
                      width: masterWidth,
                      child: TickerMode(
                        enabled: split || !detail,
                        child: KeyedSubtree(
                          key: ValueKey(master!.path),
                          child: Column(
                            children: [
                              if (!split &&
                                  GoRouter.maybeOf(context)?.canPop() == true)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: BackButton(
                                    onPressed: () => context.pop(),
                                  ),
                                ),
                              Expanded(
                                key: const ValueKey('master-content'),
                                child: master!.child,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (split) const VerticalDivider(width: 1),
                  Expanded(
                    key: const ValueKey('routed-detail'),
                    child: Stack(
                      children: [
                        // Even the placeholder route's Navigator stays mounted:
                        // history, system back and ShellRoute state remain valid.
                        Offstage(
                          offstage: !detail,
                          child: OverflowBox(
                            minWidth: detailWidth,
                            maxWidth: detailWidth,
                            alignment: Alignment.topLeft,
                            child: TickerMode(
                              enabled: detail,
                              child: Column(
                                children: [
                                  if (detail)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Builder(
                                        builder: (context) => IconButton(
                                          tooltip: fr
                                              ? 'Retour à la liste'
                                              : 'Back to list',
                                          icon: const Icon(Icons.arrow_back),
                                          onPressed: () =>
                                              AdaptiveNavigation.closeDetail(
                                                context,
                                              ),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    key: const ValueKey('detail-navigator'),
                                    child: child,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (split && !detail)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                fr
                                    ? 'Sélectionnez un élément pour afficher ses détails.'
                                    : 'Select an item to view its details.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
      return Material(
        child: Row(
          children: [
            if (rail)
              SizedBox(
                width: 96,
                child: NavigationRail(
                  scrollable: true,
                  minWidth: 96,
                  selectedIndex: _selectedIndex(path),
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) => context.go(_paths[index]),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.home_outlined),
                      label: Text(fr ? 'Accueil' : 'Home'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(fr ? 'RDV' : 'Visits'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(fr ? 'Dossier' : 'Records'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(fr ? 'Messages' : 'Messages'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline),
                      label: Text(fr ? 'Profil' : 'Profile'),
                    ),
                  ],
                ),
              ),
            Expanded(child: content),
          ],
        ),
      );
    },
  );
  static const _paths = [
    '/',
    '/appointments',
    '/medical-record',
    '/messages',
    '/profile',
  ];
  static int? _selectedIndex(String path) {
    if (path == '/') return 0;
    if (path.startsWith('/appointments')) return 1;
    if (path == '/medical-record' ||
        path.startsWith('/consultations') ||
        path.startsWith('/documents') ||
        path.startsWith('/lab-results') ||
        path.startsWith('/prescriptions') ||
        path.startsWith('/maternal-child')) {
      return 2;
    }
    if (path.startsWith('/messages')) return 3;
    if (path == '/profile' || path == '/settings') return 4;
    return null;
  }
}
