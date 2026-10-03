import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/teleconsultation_media.dart';
import '../data/teleconsultation_repository.dart';
import '../domain/teleconsultation.dart';
export '../data/teleconsultation_media.dart'
    show TeleconsultationMedia, MediaConnection;

enum CallPhase {
  idle,
  waiting,
  connecting,
  connected,
  reconnecting,
  interrupted,
  permissionDenied,
  ended,
  failed,
}

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.session,
    this.cameraEnabled = false,
    this.microphoneEnabled = false,
    this.error,
    this.media,
  });
  final CallPhase phase;
  final VideoSession? session;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final AppException? error;
  final TeleconsultationMedia? media;
  bool get busy => phase == CallPhase.connecting;
  CallState copyWith({
    CallPhase? phase,
    VideoSession? session,
    bool? cameraEnabled,
    bool? microphoneEnabled,
    AppException? error,
    TeleconsultationMedia? media,
    bool clearMedia = false,
  }) => CallState(
    phase: phase ?? this.phase,
    session: session ?? this.session,
    cameraEnabled: cameraEnabled ?? this.cameraEnabled,
    microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
    error: error,
    media: clearMedia ? null : media ?? this.media,
  );
}

final videoSessionsProvider = FutureProvider.autoDispose
    .family<VideoSessionPage?, VideoSessionQuery>((ref, query) async {
      final session = ref.watch(sessionControllerProvider);
      if (!session.isAuthenticated) {
        return null;
      }
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      final result = await ref
          .watch(teleconsultationRepositoryProvider)
          .list(query, cancelToken: token);
      if (!ref.mounted || token.isCancelled) {
        throw _changed;
      }
      return result;
    }, retry: (_, _) => null);
final videoSessionProvider = FutureProvider.autoDispose
    .family<VideoSession?, String>((ref, id) async {
      if (!ref.watch(sessionControllerProvider).isAuthenticated) {
        return null;
      }
      final token = CancelToken();
      ref.onDispose(() => token.cancel());
      final result = await ref
          .watch(teleconsultationRepositoryProvider)
          .detail(id, cancelToken: token);
      if (!ref.mounted || token.isCancelled) {
        throw _changed;
      }
      return result;
    }, retry: (_, _) => null);
// Null disables polling in deterministic tests. Poll only while room screen lives.
final teleconsultationPollIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 5),
);
final teleconsultationControllerProvider = NotifierProvider.autoDispose
    .family<TeleconsultationController, CallState, String>(
      TeleconsultationController.new,
    );
const _changed = AppException(
  kind: AppErrorKind.cancelled,
  message: 'La session a changé.',
);

class TeleconsultationController extends Notifier<CallState> {
  TeleconsultationController(this.id);
  final String id;
  int _epoch = 0;
  TeleconsultationMedia? _media;
  StreamSubscription<MediaConnection>? _subscription;
  Timer? _poll;
  Timer? _reconnectDeadline;
  CancelToken? _pending;
  CancelToken? _detailPending;
  Future<void> _closing = Future<void>.value();
  bool _action = false;
  bool _refreshing = false;
  bool _interrupted = false;
  bool _permissionPending = false;
  bool _visible = true;
  @override
  CallState build() {
    final identity = ref.watch(
      sessionControllerProvider.select((s) => (s.status, s.profile?.id)),
    );
    _epoch++;
    _pending?.cancel();
    _detailPending?.cancel();
    _poll?.cancel();
    _reconnectDeadline?.cancel();
    unawaited(_closeMedia());
    _action = false;
    _refreshing = false;
    _interrupted = false;
    _permissionPending = false;
    _visible = true;
    final hooks = ref.read(sessionEndHooksProvider);
    Future<void> end(String? _) {
      _epoch++;
      _pending?.cancel();
      _detailPending?.cancel();
      return _closeMedia();
    }

    hooks.callbacks.add(end);
    ref.onDispose(() {
      hooks.callbacks.remove(end);
      _epoch++;
      _pending?.cancel();
      _detailPending?.cancel();
      _poll?.cancel();
      _reconnectDeadline?.cancel();
      unawaited(_closeMedia());
    });
    if (identity.$2 != null &&
        ref.read(sessionControllerProvider).isAuthenticated) {
      final epoch = _epoch;
      Future.microtask(
        () => _current(epoch) ? refresh() : Future<void>.value(),
      );
      final interval = ref.read(teleconsultationPollIntervalProvider);
      if (interval != null) {
        _poll = Timer.periodic(interval, (_) => unawaited(refresh()));
      }
    }
    return const CallState();
  }

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      ref.read(sessionControllerProvider).isAuthenticated;
  TeleconsultationRepository get _repository =>
      ref.read(teleconsultationRepositoryProvider);
  Future<void> refresh() async {
    if (!_visible ||
        _refreshing ||
        _action ||
        !ref.read(sessionControllerProvider).isAuthenticated) {
      return;
    }
    _refreshing = true;
    final epoch = _epoch;
    final cancel = CancelToken();
    _detailPending = cancel;
    try {
      final session = await _repository.detail(id, cancelToken: cancel);
      if (!_current(epoch)) {
        return;
      }
      if (session.isEnded) {
        _refreshing = false;
        final endedEpoch = ++_epoch;
        await _closeMedia();
        if (_current(endedEpoch)) {
          state = CallState(phase: CallPhase.ended, session: session);
        }
      } else {
        final phase =
            state.phase == CallPhase.idle ||
                state.phase == CallPhase.waiting ||
                state.phase == CallPhase.failed
            ? (session.waitingRoom.any((e) => e.status == 'WAITING')
                  ? CallPhase.waiting
                  : CallPhase.idle)
            : state.phase;
        state = state.copyWith(session: session, phase: phase);
      }
    } catch (error) {
      if (_current(epoch)) {
        final safe = _safe(error);
        if (safe.kind == AppErrorKind.forbidden ||
            safe.statusCode == 404 ||
            safe.kind == AppErrorKind.unauthorized) {
          final interruption = interrupt();
          final interruptedEpoch = _epoch;
          await interruption;
          if (_current(interruptedEpoch)) {
            state = state.copyWith(error: safe);
          }
        } else {
          state = state.copyWith(error: safe);
        }
      }
    } finally {
      if (_current(epoch)) {
        _refreshing = false;
      }
    }
  }

  Future<void> enterWaitingRoom() => _run(() async {
    final epoch = _epoch;
    await _repository.enterWaitingRoom(id, cancelToken: _pending);
    if (!_current(epoch)) {
      return;
    }
    final session = await _repository.detail(id, cancelToken: _pending);
    if (_current(epoch)) {
      state = state.copyWith(
        session: session,
        phase: session.isEnded ? CallPhase.ended : CallPhase.waiting,
      );
    }
  });
  Future<void> join({bool camera = false, bool microphone = false}) =>
      _run(() async {
        final epoch = _epoch;
        _interrupted = false;
        state = state.copyWith(phase: CallPhase.connecting);
        final session = await _repository.detail(id, cancelToken: _pending);
        if (!_current(epoch) || _interrupted) {
          return;
        }
        state = state.copyWith(session: session);
        if (session.isEnded) {
          state = CallState(phase: CallPhase.ended, session: session);
          return;
        }
        if (!session.canJoin) {
          state = state.copyWith(phase: CallPhase.waiting);
          return;
        }
        final allowed = await _requestPermissions(
          camera: camera,
          microphone: microphone,
        );
        if (!_current(epoch) || _interrupted) {
          return;
        }
        if (!allowed) {
          state = state.copyWith(phase: CallPhase.permissionDenied);
          return;
        }
        final token = await _repository.token(id, cancelToken: _pending);
        if (!_current(epoch) || _interrupted) {
          return;
        }
        _validateToken(token);
        await _closeMedia();
        if (!_current(epoch) || _interrupted) {
          return;
        }
        final media = ref.read(teleconsultationMediaFactoryProvider)();
        _media = media;
        _subscription = media.events.listen((event) => _onMedia(event, epoch));
        await media.connect(token);
        if (!_current(epoch) || _interrupted || !identical(_media, media)) {
          await media.close();
          return;
        }
        if (camera) {
          await media.setCamera(true);
        }
        if (!_current(epoch) || _interrupted || !identical(_media, media)) {
          await media.close();
          return;
        }
        if (microphone) {
          await media.setMicrophone(true);
        }
        if (!_current(epoch) || _interrupted || !identical(_media, media)) {
          await media.close();
          return;
        }
        state = state.copyWith(
          phase: CallPhase.connected,
          cameraEnabled: camera,
          microphoneEnabled: microphone,
          media: media,
        );
      });
  void _validateToken(VideoSessionToken token) {
    final uri = Uri.tryParse(token.serverUrl);
    final production = ref.read(appConfigProvider).isProduction;
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(production ? {'wss'} : {'ws', 'wss'}).contains(uri.scheme) ||
        token.token.isEmpty ||
        !token.expiresAt.isAfter(DateTime.now())) {
      throw const AppException(
        kind: AppErrorKind.validation,
        message: 'Configuration de téléconsultation invalide.',
      );
    }
  }

  void _onMedia(MediaConnection event, int epoch) {
    if (!_current(epoch) || _interrupted) {
      return;
    }
    switch (event) {
      case MediaConnection.connected:
        _reconnectDeadline?.cancel();
        if (!_action) {
          state = state.copyWith(phase: CallPhase.connected);
        }
      case MediaConnection.reconnecting:
        state = state.copyWith(phase: CallPhase.reconnecting);
        _reconnectDeadline?.cancel();
        _reconnectDeadline = Timer(
          const Duration(seconds: 25),
          () => unawaited(interrupt()),
        );
      case MediaConnection.disconnected:
        unawaited(interrupt());
    }
  }

  Future<void> interrupt({bool inactive = false}) async {
    if (inactive && _permissionPending && _media == null) {
      return;
    }
    _interrupted = true;
    _epoch++;
    _pending?.cancel();
    _detailPending?.cancel();
    _action = false;
    _refreshing = false;
    // State loses renderer immediately; close media before a resume/rejoin.
    if (ref.mounted) {
      state = state.copyWith(
        phase: CallPhase.interrupted,
        cameraEnabled: false,
        microphoneEnabled: false,
        clearMedia: true,
      );
    }
    await _closeMedia();
  }

  void setVisible(bool visible) {
    _visible = visible;
    _poll?.cancel();
    if (!visible) {
      unawaited(interrupt());
      return;
    }
    final interval = ref.read(teleconsultationPollIntervalProvider);
    if (interval != null) {
      _poll = Timer.periodic(interval, (_) => unawaited(refresh()));
    }
    unawaited(refresh());
  }

  Future<void> leave() async {
    _interrupted = true;
    _epoch++;
    _pending?.cancel();
    _detailPending?.cancel();
    _action = false;
    _refreshing = false;
    final epoch = _epoch;
    final repository = _repository;
    if (ref.mounted) {
      state = state.copyWith(
        phase: CallPhase.ended,
        cameraEnabled: false,
        microphoneEnabled: false,
        clearMedia: true,
      );
    }
    await _closeMedia();
    if (!_current(epoch)) {
      return;
    }
    try {
      await repository.leave(id);
      if (_current(epoch)) {
        final session = await repository.detail(id);
        if (_current(epoch)) {
          state = state.copyWith(session: session);
        }
      }
    } catch (error) {
      if (_current(epoch)) {
        state = state.copyWith(error: _safe(error));
      }
    }
    if (_current(epoch)) {
      ref.invalidate(videoSessionsProvider);
      ref.invalidate(videoSessionProvider(id));
    }
  }

  Future<void> toggleCamera() => _toggle(camera: true);
  Future<void> toggleMicrophone() => _toggle(camera: false);
  Future<void> _toggle({required bool camera}) => _run(() async {
    final media = _media;
    final epoch = _epoch;
    if (media == null || state.phase != CallPhase.connected) {
      return;
    }
    final enabled = !(camera ? state.cameraEnabled : state.microphoneEnabled);
    if (enabled) {
      final allowed = await ref
          .read(teleconsultationPermissionsProvider)
          .request(camera: camera, microphone: !camera);
      if (!_current(epoch) || _interrupted) {
        return;
      }
      if (!allowed) {
        state = state.copyWith(
          error: const AppException(
            kind: AppErrorKind.forbidden,
            message: 'Autorisation caméra ou microphone refusée.',
          ),
        );
        return;
      }
    }
    if (camera) {
      await media.setCamera(enabled);
    } else {
      await media.setMicrophone(enabled);
    }
    if (!_current(epoch) || _interrupted) {
      await media.close();
      return;
    }
    state = state.copyWith(
      cameraEnabled: camera ? enabled : null,
      microphoneEnabled: camera ? null : enabled,
    );
  });
  Future<void> switchCamera() => _run(() async {
    if (state.phase == CallPhase.connected && state.cameraEnabled) {
      await _media?.switchCamera();
    }
  });
  Future<bool> _requestPermissions({
    required bool camera,
    required bool microphone,
  }) async {
    _permissionPending = true;
    try {
      return await ref
          .read(teleconsultationPermissionsProvider)
          .request(camera: camera, microphone: microphone);
    } finally {
      _permissionPending = false;
    }
  }

  Future<void> openSettings() =>
      ref.read(teleconsultationPermissionsProvider).openSettings();
  Future<void> _run(Future<void> Function() action) async {
    if (_action || !ref.read(sessionControllerProvider).isAuthenticated) {
      return;
    }
    _action = true;
    final epoch = _epoch;
    _pending = CancelToken();
    try {
      await action();
    } catch (error) {
      if (_current(epoch)) {
        await _closeMedia();
        if (_current(epoch)) {
          state = state.copyWith(
            phase: CallPhase.failed,
            cameraEnabled: false,
            microphoneEnabled: false,
            clearMedia: true,
            error: _safe(error),
          );
        }
      }
    } finally {
      if (epoch == _epoch) {
        _action = false;
        _pending = null;
      }
    }
  }

  Future<void> _closeMedia() {
    final media = _media;
    _media = null;
    final subscription = _subscription;
    _subscription = null;
    _reconnectDeadline?.cancel();
    final closing = _closing.then((_) async {
      await subscription?.cancel();
      try {
        await media?.close();
      } catch (_) {
        /* No credentials retained on SDK failure. */
      }
    });
    _closing = closing.catchError((Object _) {});
    return _closing;
  }

  AppException _safe(Object error) => error is AppException
      ? error
      : const AppException(
          kind: AppErrorKind.network,
          message: 'La connexion vidéo est indisponible. Réessayez.',
        );
}
