import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../consultations/presentation/clinical_async_view.dart';
import '../application/teleconsultation_providers.dart';

class TeleconsultationRoomPage extends ConsumerStatefulWidget {
  const TeleconsultationRoomPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TeleconsultationRoomPage> createState() =>
      _TeleconsultationRoomPageState();
}

class _TeleconsultationRoomPageState
    extends ConsumerState<TeleconsultationRoomPage>
    with WidgetsBindingObserver {
  bool _camera = false;
  bool _microphone = false;
  bool _allowPop = false;
  bool _confirmingLeave = false;
  bool? _visible;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(
      teleconsultationControllerProvider(widget.id).notifier,
    );
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.interrupt(inactive: true));
      return;
    }
    _resumed = state == AppLifecycleState.resumed;
    controller.setVisible(
      _resumed && ModalRoute.of(context)?.isCurrent == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _confirmingLeave) return;
      final visible = _resumed && ModalRoute.of(context)?.isCurrent == true;
      if (_visible != visible) {
        _visible = visible;
        ref
            .read(teleconsultationControllerProvider(widget.id).notifier)
            .setVisible(visible);
      }
    });
    final fr = clinicalFrench(context);
    final state = ref.watch(teleconsultationControllerProvider(widget.id));
    final controller = ref.read(
      teleconsultationControllerProvider(widget.id).notifier,
    );
    final session = state.session;
    final identity = ref.watch(sessionControllerProvider);
    final personId = identity.profile?.id;
    if (!identity.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text(fr ? 'Téléconsultation' : 'Video consultation'),
        ),
      );
    }
    final active = const {
      CallPhase.connecting,
      CallPhase.connected,
      CallPhase.reconnecting,
    }.contains(state.phase);
    final busy = state.phase == CallPhase.connecting;
    final joined =
        state.phase == CallPhase.connected ||
        state.phase == CallPhase.reconnecting;
    return PopScope(
      canPop: _allowPop || !active,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_leave(pop: true));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(fr ? 'Téléconsultation' : 'Video consultation'),
          actions: [
            IconButton(
              tooltip: fr ? 'Actualiser' : 'Refresh',
              onPressed: busy ? null : () => controller.refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (session != null) ...[
                    Text(
                      session.sessionNumber,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(clinicalDateTime(context, session.scheduledStart)),
                    for (final participant in session.participants)
                      if (participant.personId != personId)
                        Text(
                          participant.displayName ??
                              (fr
                                  ? 'Professionnel de santé'
                                  : 'Health professional'),
                        ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    state.phase == CallPhase.ended && session?.isEnded != true
                        ? (fr
                              ? 'Vous avez quitté l’appel'
                              : 'You have left the call')
                        : _phaseMessage(state.phase, fr),
                    key: const Key('teleconsultation-phase'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (busy ||
                      (session == null && state.phase == CallPhase.idle))
                    const LinearProgressIndicator(),
                  if (state.error != null || state.phase == CallPhase.failed)
                    Text(
                      fr
                          ? 'La connexion est indisponible. Actualisez puis réessayez.'
                          : 'Connection unavailable. Refresh and try again.',
                    ),
                  if (state.phase == CallPhase.permissionDenied) ...[
                    Text(
                      fr
                          ? 'Autorisez la caméra ou le microphone dans les paramètres du téléphone, ou rejoignez sans les activer.'
                          : 'Allow camera or microphone in phone settings, or join without enabling them.',
                    ),
                    TextButton(
                      onPressed: () => controller.openSettings(),
                      child: Text(
                        fr ? 'Ouvrir les paramètres' : 'Open settings',
                      ),
                    ),
                  ],
                  if (joined) ...[
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 840;
                        final remote = ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .65,
                          ),
                          child: AspectRatio(
                            aspectRatio: wide ? 16 / 9 : 4 / 3,
                            child:
                                state.media?.videoView(local: false) ??
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      fr
                                          ? 'En attente de la vidéo du professionnel.'
                                          : 'Waiting for the professional’s video.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                          ),
                        );
                        final preview =
                            state.cameraEnabled && state.media != null
                            ? AspectRatio(
                                aspectRatio: 4 / 3,
                                child: state.media!.videoView(local: true),
                              )
                            : null;
                        if (wide) {
                          return Row(
                            key: const Key('teleconsultation-wide-video'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: remote),
                              if (preview != null) ...[
                                const SizedBox(width: 16),
                                Expanded(child: preview),
                              ],
                            ],
                          );
                        }
                        return Column(
                          key: const Key('teleconsultation-compact-video'),
                          children: [
                            remote,
                            if (preview != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: constraints.maxWidth < 480 ? 120 : 180,
                                  child: preview,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton.filledTonal(
                          tooltip: state.microphoneEnabled
                              ? (fr
                                    ? 'Couper le microphone'
                                    : 'Mute microphone')
                              : (fr
                                    ? 'Activer le microphone'
                                    : 'Enable microphone'),
                          onPressed: () => controller.toggleMicrophone(),
                          icon: Icon(
                            state.microphoneEnabled ? Icons.mic : Icons.mic_off,
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: state.cameraEnabled
                              ? (fr ? 'Couper la caméra' : 'Disable camera')
                              : (fr ? 'Activer la caméra' : 'Enable camera'),
                          onPressed: () => controller.toggleCamera(),
                          icon: Icon(
                            state.cameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: fr ? 'Changer de caméra' : 'Switch camera',
                          onPressed: state.cameraEnabled
                              ? () => controller.switchCamera()
                              : null,
                          icon: const Icon(Icons.cameraswitch),
                        ),
                      ],
                    ),
                  ] else if (session?.isEnded != true) ...[
                    const SizedBox(height: 12),
                    Text(
                      fr
                          ? 'La caméra et le microphone restent désactivés dans la salle d’attente.'
                          : 'Camera and microphone remain off in the waiting room.',
                    ),
                    if (session != null && personId != null && !session.canJoin)
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => controller.enterWaitingRoom(),
                        icon: const Icon(Icons.meeting_room_outlined),
                        label: Text(
                          fr
                              ? 'Entrer en salle d’attente'
                              : 'Enter waiting room',
                        ),
                      ),
                    if (session != null &&
                        personId != null &&
                        session.canJoin) ...[
                      CheckboxListTile(
                        value: _camera,
                        onChanged: busy
                            ? null
                            : (value) =>
                                  setState(() => _camera = value ?? false),
                        title: Text(
                          fr ? 'Activer ma caméra' : 'Enable my camera',
                        ),
                      ),
                      CheckboxListTile(
                        value: _microphone,
                        onChanged: busy
                            ? null
                            : (value) =>
                                  setState(() => _microphone = value ?? false),
                        title: Text(
                          fr
                              ? 'Activer mon microphone'
                              : 'Enable my microphone',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => controller.join(
                                camera: _camera,
                                microphone: _microphone,
                              ),
                        icon: const Icon(Icons.video_call),
                        label: Text(fr ? 'Rejoindre l’appel' : 'Join call'),
                      ),
                    ],
                  ],
                  if (active)
                    FilledButton.tonalIcon(
                      onPressed: () => _leave(),
                      icon: const Icon(Icons.call_end),
                      label: Text(fr ? 'Quitter l’appel' : 'Leave call'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _leave({bool pop = false}) async {
    if (_confirmingLeave) return;
    _confirmingLeave = true;
    final fr = clinicalFrench(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fr ? 'Quitter l’appel ?' : 'Leave call?'),
        content: Text(
          fr
              ? 'Vous pourrez revenir tant que la consultation est ouverte.'
              : 'You can return while the consultation remains open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(fr ? 'Rester' : 'Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(fr ? 'Quitter' : 'Leave'),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (!mounted || confirmed != true) return;
    await ref
        .read(teleconsultationControllerProvider(widget.id).notifier)
        .leave();
    if (!mounted) return;
    if (pop) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }
}

String _phaseMessage(CallPhase phase, bool fr) => switch (phase) {
  CallPhase.idle => fr ? 'Votre téléconsultation' : 'Your video consultation',
  CallPhase.waiting => fr ? 'En salle d’attente' : 'In the waiting room',
  CallPhase.connecting => fr ? 'Connexion en cours…' : 'Connecting…',
  CallPhase.connected => fr ? 'Appel en cours' : 'Call in progress',
  CallPhase.reconnecting => fr ? 'Reconnexion en cours…' : 'Reconnecting…',
  CallPhase.interrupted =>
    fr
        ? 'Appel interrompu. Rejoignez à nouveau pour reprendre.'
        : 'Call interrupted. Join again to resume.',
  CallPhase.permissionDenied => fr ? 'Permission refusée' : 'Permission denied',
  CallPhase.ended => fr ? 'Consultation terminée' : 'Consultation ended',
  CallPhase.failed => fr ? 'Connexion impossible' : 'Unable to connect',
};
