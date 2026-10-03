import 'package:flutter/material.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/messaging_providers.dart';

class MessagingConnectionBanner extends StatelessWidget {
  const MessagingConnectionBanner({
    super.key,
    required this.status,
    required this.onRetry,
  });
  final MessagingConnectionStatus status;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final fr = clinicalFrench(context);
    final label = switch (status) {
      MessagingConnectionStatus.connected =>
        fr ? 'Connecté en temps réel' : 'Live connection',
      MessagingConnectionStatus.connecting => fr ? 'Connexion…' : 'Connecting…',
      MessagingConnectionStatus.reconnecting =>
        fr ? 'Reconnexion…' : 'Reconnecting…',
      MessagingConnectionStatus.disconnected =>
        fr ? 'Temps réel déconnecté' : 'Live connection disconnected',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final retry = status == MessagingConnectionStatus.disconnected;
          final stacked =
              constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final description = Row(
            children: [
              Icon(
                status == MessagingConnectionStatus.connected
                    ? Icons.wifi
                    : Icons.wifi_off,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
            ],
          );
          final action = TextButton(
            onPressed: onRetry,
            child: Text(fr ? 'Reconnecter' : 'Reconnect'),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [description, if (retry) action],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              if (retry) action,
            ],
          );
        },
      ),
    );
  }
}
