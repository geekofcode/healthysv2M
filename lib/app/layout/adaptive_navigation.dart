import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A usable split requires space for a readable list and detail at the current
/// accessibility text size; device labels and orientation are not used.
bool supportsMasterDetail(BuildContext context, double width) =>
    width /
        (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(
          1.0,
          double.infinity,
        ) >=
    720;

class AdaptiveSelection extends InheritedWidget {
  const AdaptiveSelection({
    required this.selectedId,
    required this.listPath,
    required this.routePath,
    required this.split,
    required this.masterVisible,
    required super.child,
    super.key,
  });
  final String? selectedId;
  final String listPath;
  final String routePath;
  final bool split;
  final bool masterVisible;
  @override
  bool updateShouldNotify(AdaptiveSelection oldWidget) =>
      selectedId != oldWidget.selectedId ||
      listPath != oldWidget.listPath ||
      routePath != oldWidget.routePath ||
      split != oldWidget.split ||
      masterVisible != oldWidget.masterVisible;
}

abstract final class AdaptiveNavigation {
  static AdaptiveSelection? _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveSelection>();
  static bool isSelected(
    BuildContext context,
    String id, {
    String? routePrefix,
  }) {
    final scope = _scope(context);
    return scope?.selectedId == id &&
        (routePrefix == null || scope!.routePath.startsWith(routePrefix));
  }

  static bool masterVisible(BuildContext context) =>
      _scope(context)?.masterVisible ?? true;
  static void openDetail(
    BuildContext context,
    String routeName, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    if (_scope(context)?.split == true) {
      context.goNamed(
        routeName,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      );
    } else {
      context.pushNamed(
        routeName,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      );
    }
  }

  static void closeDetail(BuildContext context) {
    final scope = _scope(context);
    if (scope?.split == true) {
      context.go(scope!.listPath);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(scope?.listPath ?? '/');
    }
  }
}
