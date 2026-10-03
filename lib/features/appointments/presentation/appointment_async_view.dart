import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appointment_labels.dart';

class AppointmentAsyncView<T> extends StatelessWidget {
  const AppointmentAsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) {
    if (value.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (value.hasError) {
      return AppointmentFailure(error: value.error!, onRetry: onRetry);
    }
    return builder(value.requireValue);
  }
}

Future<bool> confirmAppointmentAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final fr = appointmentFrench(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(fr ? 'Retour' : 'Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
