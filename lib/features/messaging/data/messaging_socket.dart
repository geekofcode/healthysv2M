import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'stomp_codec.dart';

Uri messagingSocketUri(Uri api) {
  final path = api.path.replaceFirst(RegExp(r'/api/v1/?$'), '/ws');
  if (path == api.path ||
      !{'http', 'https'}.contains(api.scheme) ||
      api.hasQuery ||
      api.hasFragment ||
      api.userInfo.isNotEmpty) {
    throw ArgumentError('Invalid API socket origin');
  }
  return api.replace(scheme: api.scheme == 'https' ? 'wss' : 'ws', path: path);
}

abstract interface class MessagingSocket {
  Stream<Object> get stream;
  void send(String value);
  Future<void> close();
}

class NativeMessagingSocket implements MessagingSocket {
  NativeMessagingSocket(this.socket);
  final WebSocket socket;
  @override
  Stream<Object> get stream => socket.cast<Object>();
  @override
  void send(String value) => socket.add(value);
  @override
  Future<void> close() async {
    await socket.close();
  }
}

typedef MessagingSocketConnector = Future<MessagingSocket> Function(Uri uri);
Future<MessagingSocket> connectMessagingSocket(Uri uri) async {
  var timedOut = false;
  final pending = WebSocket.connect(uri.toString(), protocols: ['v12.stomp']);
  unawaited(
    pending.then((socket) {
      if (timedOut) {
        unawaited(socket.close().then<void>((_) {}, onError: (Object _) {}));
      }
    }, onError: (Object _) {}),
  );
  final socket = await pending.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      timedOut = true;
      throw TimeoutException('Socket connection timeout');
    },
  );
  return NativeMessagingSocket(socket);
}

enum MessagingConnectionStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

class MessagingConnectionState {
  const MessagingConnectionState(this.status, {this.revision = 0});
  final MessagingConnectionStatus status;
  final int revision;
}

/// Events carry no clinical payload to providers: REST reconciles recipient state.
class MessagingRealtime {
  MessagingRealtime({
    required this.uri,
    this.conversationId,
    this.personId,
    required this.tokenReader,
    required this.isCurrent,
    required this.onState,
    required this.onChange,
    this.connector = connectMessagingSocket,
    Random? random,
    this.retryBase = const Duration(seconds: 1),
    this.retryJitter = const Duration(milliseconds: 500),
    this.tokenCheckInterval = const Duration(seconds: 20),
  }) : random = random ?? Random();
  final Uri uri;
  final String? conversationId, personId;
  final Future<String?> Function({bool forceRefresh}) tokenReader;
  final bool Function() isCurrent;
  final void Function(MessagingConnectionStatus) onState;
  final void Function() onChange;
  final MessagingSocketConnector connector;
  final Random random;
  final Duration retryBase, retryJitter, tokenCheckInterval;
  MessagingSocket? _socket;
  StreamSubscription<Object>? _subscription;
  Timer? _retry, _heartbeat, _timeout, _tokenTimer, _stableTimer;
  int _generation = 0, _attempt = 0;
  bool _disposed = false,
      _suspended = false,
      _connected = false,
      _checkingToken = false;
  String? _connectedToken;
  DateTime _lastReceived = DateTime.now();
  int _incomingHeartbeat = 0;
  bool _active(int generation) =>
      !_disposed && !_suspended && generation == _generation && isCurrent();
  Future<void> start() async {
    if (_disposed || _suspended || !isCurrent()) {
      return;
    }
    final generation = ++_generation;
    await _cleanup();
    if (!_active(generation)) {
      return;
    }
    onState(
      _attempt == 0
          ? MessagingConnectionStatus.connecting
          : MessagingConnectionStatus.reconnecting,
    );
    try {
      final token = await tokenReader();
      if (!_active(generation)) {
        return;
      }
      if (token == null || token.isEmpty) {
        suspend();
        return;
      }
      final socket = await connector(uri);
      if (!_active(generation)) {
        await socket.close();
        return;
      }
      _socket = socket;
      _connectedToken = token;
      final decoder = StompDecoder();
      _subscription = socket.stream.listen(
        (chunk) {
          if (!_active(generation)) {
            return;
          }
          _lastReceived = DateTime.now();
          try {
            for (final frame in decoder.add(chunk)) {
              _frame(frame, generation);
            }
          } catch (_) {
            _failed(generation);
          }
        },
        onError: (Object _) => _failed(generation),
        onDone: () => _failed(generation),
      );
      socket.send(
        StompFrame(
          'CONNECT',
          headers: {
            'accept-version': '1.2',
            'host': uri.host,
            'Authorization': 'Bearer $token',
            'heart-beat': '10000,10000',
          },
        ).encode(),
      );
      _timeout = Timer(const Duration(seconds: 15), () => _failed(generation));
    } catch (_) {
      _failed(generation);
    }
  }

  void _frame(StompFrame frame, int generation) {
    if (frame.command == 'CONNECTED') {
      if (_connected || frame.headers['version'] != '1.2') {
        _failed(generation);
        return;
      }
      _connected = true;
      _stableTimer = Timer(const Duration(seconds: 60), () {
        if (_active(generation)) {
          _attempt = 0;
        }
      });
      _timeout?.cancel();
      final heartbeat = (frame.headers['heart-beat'] ?? '0,0').split(',');
      if (heartbeat.length != 2) {
        _failed(generation);
        return;
      }
      final send = int.tryParse(heartbeat[0]),
          receive = int.tryParse(heartbeat[1]);
      if (send == null || receive == null || send < 0 || receive < 0) {
        _failed(generation);
        return;
      }
      _incomingHeartbeat = send == 0 ? 0 : max(10000, send);
      final outgoing = receive == 0 ? 0 : max(10000, receive);
      final destinations = personId != null
          ? ['/topic/messaging/users/$personId']
          : [
              '/topic/conversations/$conversationId',
              '/topic/conversations/$conversationId/receipts',
            ];
      for (final destination in destinations) {
        _socket?.send(
          StompFrame(
            'SUBSCRIBE',
            headers: {
              'id': destination.endsWith('/receipts') ? 'receipts' : 'messages',
              'destination': destination,
              'ack': 'auto',
            },
          ).encode(),
        );
      }
      if (outgoing > 0) {
        _heartbeat = Timer.periodic(Duration(milliseconds: outgoing), (_) {
          if (_active(generation)) {
            try {
              _socket?.send('\n');
            } catch (_) {
              _failed(generation);
            }
          }
        });
      }
      _tokenTimer = Timer.periodic(
        tokenCheckInterval,
        (_) => _checkToken(generation),
      );
      onState(MessagingConnectionStatus.connected);
      onChange();
    } else if (frame.command == 'MESSAGE' && _connected) {
      final destination = frame.headers['destination'];
      if (destination == '/topic/conversations/$conversationId' ||
          destination == '/topic/conversations/$conversationId/receipts' ||
          destination == '/topic/messaging/users/$personId') {
        onChange();
      }
    } else if (frame.command == 'ERROR') {
      _failed(generation);
    }
  }

  Future<void> _checkToken(int generation) async {
    if (!_active(generation) || _checkingToken) {
      return;
    }
    if (_incomingHeartbeat > 0 &&
        DateTime.now().difference(_lastReceived).inMilliseconds >
            _incomingHeartbeat * 3) {
      _failed(generation);
      return;
    }
    _checkingToken = true;
    try {
      final token = await tokenReader();
      if (_active(generation) && token != _connectedToken) {
        unawaited(start());
      }
    } catch (_) {
      _failed(generation);
    } finally {
      _checkingToken = false;
    }
  }

  void _failed(int generation) {
    if (!_active(generation)) {
      return;
    }
    ++_generation;
    _attempt++;
    unawaited(_cleanup());
    if (_attempt > 6) {
      onState(MessagingConnectionStatus.disconnected);
      return;
    }
    onState(MessagingConnectionStatus.reconnecting);
    final factor = 1 << min(_attempt - 1, 5);
    final delay =
        min(30000, retryBase.inMilliseconds * factor) +
        (retryJitter.inMilliseconds > 0
            ? random.nextInt(retryJitter.inMilliseconds)
            : 0);
    _retry = Timer(Duration(milliseconds: delay), () => unawaited(start()));
  }

  void reconnect() {
    _attempt = 0;
    _suspended = false;
    unawaited(start());
  }

  void suspend() {
    _suspended = true;
    ++_generation;
    unawaited(_cleanup());
    if (!_disposed) {
      onState(MessagingConnectionStatus.disconnected);
    }
  }

  void resume() {
    if (_suspended) {
      _suspended = false;
      _attempt = 0;
      unawaited(start());
    }
  }

  Future<void> _cleanup() async {
    _retry?.cancel();
    _heartbeat?.cancel();
    _timeout?.cancel();
    _tokenTimer?.cancel();
    _stableTimer?.cancel();
    _connected = false;
    final subscription = _subscription, socket = _socket;
    _subscription = null;
    _socket = null;
    _connectedToken = null;
    try {
      await subscription?.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await socket?.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_cleanup());
  }
}
