import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_view.dart';

bool clinicalFrench(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'fr';
String clinicalDateTime(BuildContext context, DateTime? instant) {
  final fr = clinicalFrench(context);
  if (instant == null) return fr ? 'Non renseigné' : 'Not provided';
  final local = instant.toLocal();
  final locale = MaterialLocalizations.of(context);
  return '${locale.formatMediumDate(local)} • ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class ClinicalAsyncView<T> extends StatelessWidget {
  const ClinicalAsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    required this.missingMessage,
  });
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  final String missingMessage;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (value.hasError) {
      final error = value.error;
      if (error is AppException && error.statusCode == 404) {
        return Column(
          children: [
            Text(missingMessage, textAlign: TextAlign.center),
            TextButton(
              onPressed: onRetry,
              child: Text(clinicalFrench(context) ? 'Réessayer' : 'Try again'),
            ),
          ],
        );
      }
      return ErrorView(
        error: error is AppException
            ? error
            : const AppException(kind: AppErrorKind.unknown, message: ''),
        onRetry: onRetry,
      );
    }
    return builder(value.requireValue);
  }
}

class ClinicalPagination extends StatelessWidget {
  const ClinicalPagination({
    super.key,
    required this.number,
    required this.totalPages,
    required this.last,
    required this.onPrevious,
    required this.onNext,
  });
  final int number, totalPages;
  final bool last;
  final VoidCallback onPrevious, onNext;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    if (totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: number > 0 ? onPrevious : null,
          child: Text(fr ? 'Précédent' : 'Previous'),
        ),
        Text('Page ${number + 1} / $totalPages'),
        TextButton(
          onPressed: last ? null : onNext,
          child: Text(fr ? 'Suivant' : 'Next'),
        ),
      ],
    );
  }
}
