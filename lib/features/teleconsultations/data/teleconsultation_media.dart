import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import '../domain/teleconsultation.dart';

enum MediaConnection { connected, reconnecting, disconnected }

abstract interface class TeleconsultationMedia {
  Stream<MediaConnection> get events;
  Future<void> connect(VideoSessionToken token);
  Future<void> setCamera(bool enabled);
  Future<void> setMicrophone(bool enabled);
  Future<void> switchCamera();
  Future<void> close();
  bool get hasRemoteVideo;
  Widget videoView({required bool local});
}

abstract interface class TeleconsultationPermissions {
  Future<bool> request({required bool camera, required bool microphone});
  Future<void> openSettings();
}

class NativeTeleconsultationPermissions implements TeleconsultationPermissions {
  @override
  Future<bool> request({required bool camera, required bool microphone}) async {
    final requested = [
      if (camera) Permission.camera,
      if (microphone) Permission.microphone,
    ];
    if (requested.isEmpty) {
      return true;
    }
    final result = await requested.request();
    return result.values.every((status) => status.isGranted);
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

class LiveKitTeleconsultationMedia implements TeleconsultationMedia {
  final _room = lk.Room(
    roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
  );
  final _events = StreamController<MediaConnection>.broadcast();
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _closed = false;
  bool _frontCamera = true;
  @override
  Stream<MediaConnection> get events => _events.stream;
  @override
  Future<void> connect(VideoSessionToken token) async {
    _listener = _room.createListener()
      ..on<lk.RoomReconnectingEvent>((_) => _emit(MediaConnection.reconnecting))
      ..on<lk.RoomReconnectedEvent>((_) => _emit(MediaConnection.connected))
      ..on<lk.RoomDisconnectedEvent>(
        (_) => _emit(MediaConnection.disconnected),
      );
    await _room
        .connect(token.serverUrl, token.token)
        .timeout(const Duration(seconds: 25));
    if (_closed) {
      await _room.disconnect();
      return;
    }
    _emit(MediaConnection.connected);
  }

  void _emit(MediaConnection event) {
    if (!_closed) {
      _events.add(event);
    }
  }

  @override
  Future<void> setCamera(bool enabled) async {
    if (_closed && enabled) {
      return;
    }
    await _room.localParticipant?.setCameraEnabled(enabled);
  }

  @override
  Future<void> setMicrophone(bool enabled) async {
    if (_closed && enabled) {
      return;
    }
    await _room.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> switchCamera() async {
    final tracks = _room.localParticipant?.videoTrackPublications;
    if (tracks == null) {
      return;
    }
    for (final publication in tracks) {
      final track = publication.track;
      if (track is lk.LocalVideoTrack) {
        _frontCamera = !_frontCamera;
        await track.setCameraPosition(
          _frontCamera ? lk.CameraPosition.front : lk.CameraPosition.back,
        );
        break;
      }
    }
  }

  @override
  bool get hasRemoteVideo => _room.remoteParticipants.values.any(
    (p) => p.videoTrackPublications.any((t) => t.track != null && !t.muted),
  );
  @override
  Widget videoView({required bool local}) => ListenableBuilder(
    listenable: _room,
    builder: (context, _) {
      final publications = local
          ? _room.localParticipant?.videoTrackPublications
          : _room.remoteParticipants.values
                .expand((p) => p.videoTrackPublications)
                .toList();
      final tracks = publications
          ?.where((p) => !p.muted)
          .map((p) => p.track)
          .whereType<lk.VideoTrack>();
      if (tracks == null || tracks.isEmpty) {
        return const Center(child: Icon(Icons.videocam_off, size: 48));
      }
      return lk.VideoTrackRenderer(tracks.first);
    },
  );
  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    // Disconnect stops and disposes locally published tracks, even on mute failure.
    try {
      final participant = _room.localParticipant;
      if (participant != null) {
        await Future.wait(
          [
            ...participant.videoTrackPublications,
            ...participant.audioTrackPublications,
          ].map((publication) async {
            await publication.track?.stop();
          }),
        );
      }
      await _room.disconnect().timeout(const Duration(seconds: 3));
    } finally {
      await _listener?.dispose();
      await _room.dispose();
      await _events.close();
    }
  }
}

final teleconsultationMediaFactoryProvider =
    Provider<TeleconsultationMedia Function()>(
      (ref) => LiveKitTeleconsultationMedia.new,
    );
final teleconsultationPermissionsProvider =
    Provider<TeleconsultationPermissions>(
      (ref) => NativeTeleconsultationPermissions(),
    );
