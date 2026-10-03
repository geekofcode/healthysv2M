import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthysv2/features/messaging/data/stomp_codec.dart';
import 'package:healthysv2/features/messaging/data/messaging_socket.dart';

class FakeSocket implements MessagingSocket {
  final events = StreamController<Object>.broadcast();
  final sent = <String>[];
  bool closed = false;
  @override
  Stream<Object> get stream => events.stream;
  @override
  void send(String value) => sent.add(value);
  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  test(
    'codec preserves UTF8 octet content length embedded NUL and fragmented frames',
    () {
      final wire = StompFrame(
        'MESSAGE',
        headers: {'destination': 'a:b\nc\\d'},
        body: 'é\u0000suite',
      ).encode();
      final decoder = StompDecoder();
      final bytes = utf8.encode(wire);
      expect(decoder.add(bytes.sublist(0, bytes.length - 2)), isEmpty);
      final frames = decoder.add(bytes.sublist(bytes.length - 2));
      expect(frames.single.body, 'é\u0000suite');
      expect(frames.single.headers['destination'], 'a:b\nc\\d');
    },
  );
  test('codec accepts heartbeats CRLF and multiple frames', () {
    final frames = StompDecoder().add(
      '\r\nCONNECTED\r\nversion:1.2\r\n\r\n\u0000\nMESSAGE\ndestination:/topic/a\n\nhello\u0000',
    );
    expect(frames.map((frame) => frame.command), ['CONNECTED', 'MESSAGE']);
  });
  test('CONNECT headers do not escape authorization or host', () {
    expect(
      StompFrame('CONNECT', headers: {'host': 'host:8080'}).encode(),
      contains('host:host:8080'),
    );
    expect(
      () => StompDecoder().add('MESSAGE\na:b\\z\n\n\u0000'),
      throwsFormatException,
    );
  });
  test('rejects oversized or malformed frame lengths', () {
    expect(
      () => StompDecoder().add('MESSAGE\ncontent-length:-1\n\n\u0000'),
      throwsFormatException,
    );
    expect(
      () => StompDecoder().add('MESSAGE\ncontent-length:1\n\nab\u0000'),
      throwsFormatException,
    );
  });
  test('socket URI preserves proxy prefix and refuses credential URL', () {
    expect(
      messagingSocketUri(Uri.parse('https://host/healthys/api/v1/')).toString(),
      'wss://host/healthys/ws',
    );
    expect(
      () => messagingSocketUri(Uri.parse('https://user@host/api/v1')),
      throwsArgumentError,
    );
  });
  test(
    'fresh token CONNECT subscribes exact topics and ignores unrelated message',
    () async {
      final socket = FakeSocket();
      final states = <MessagingConnectionStatus>[];
      var changes = 0;
      final realtime = MessagingRealtime(
        uri: Uri.parse('wss://host/ws'),
        conversationId: 'id',
        tokenReader: ({bool forceRefresh = false}) async => 'fresh',
        isCurrent: () => true,
        onState: states.add,
        onChange: () => changes++,
        connector: (_) async => socket,
      );
      await realtime.start();
      expect(socket.sent.single, contains('Authorization:Bearer fresh'));
      expect(socket.sent.single, isNot(contains('?token')));
      socket.events.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\u0000');
      await Future<void>.delayed(Duration.zero);
      expect(states.last, MessagingConnectionStatus.connected);
      expect(socket.sent.length, 3);
      expect(changes, 1);
      socket.events.add(
        'MESSAGE\ndestination:/topic/conversations/other\n\n{}\u0000',
      );
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);
      socket.events.add(
        'MESSAGE\ndestination:/topic/conversations/id\n\n{"readByCurrentUser":true}\u0000',
      );
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);
      realtime.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(socket.closed, isTrue);
      await socket.events.close();
    },
  );
  test('late token result from expired session cannot connect', () async {
    final token = Completer<String?>();
    var current = true;
    var connects = 0;
    final realtime = MessagingRealtime(
      uri: Uri.parse('wss://host/ws'),
      conversationId: 'id',
      tokenReader: ({bool forceRefresh = false}) => token.future,
      isCurrent: () => current,
      onState: (_) {},
      onChange: () {},
      connector: (_) async {
        connects++;
        return FakeSocket();
      },
    );
    final pending = realtime.start();
    await Future<void>.delayed(Duration.zero);
    current = false;
    token.complete('old');
    await pending;
    expect(connects, 0);
    realtime.dispose();
  });
  test(
    'late socket from suspended screen is closed without credentials',
    () async {
      final pending = Completer<MessagingSocket>();
      final socket = FakeSocket();
      final realtime = MessagingRealtime(
        uri: Uri.parse('wss://host/ws'),
        conversationId: 'id',
        tokenReader: ({bool forceRefresh = false}) async => 'token',
        isCurrent: () => true,
        onState: (_) {},
        onChange: () {},
        connector: (_) => pending.future,
      );
      final start = realtime.start();
      await Future<void>.delayed(Duration.zero);
      realtime.suspend();
      pending.complete(socket);
      await start;
      expect(socket.closed, isTrue);
      expect(socket.sent, isEmpty);
      realtime.dispose();
      await socket.events.close();
    },
  );
  test(
    'token refresh reconnects with fresh token and closes old socket',
    () async {
      var token = 'old';
      final sockets = <FakeSocket>[];
      final realtime = MessagingRealtime(
        uri: Uri.parse('wss://host/ws'),
        conversationId: 'id',
        tokenReader: ({bool forceRefresh = false}) async => token,
        isCurrent: () => true,
        onState: (_) {},
        onChange: () {},
        tokenCheckInterval: const Duration(milliseconds: 10),
        connector: (_) async {
          final socket = FakeSocket();
          sockets.add(socket);
          return socket;
        },
      );
      await realtime.start();
      sockets.first.events.add(
        'CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\u0000',
      );
      await Future<void>.delayed(Duration.zero);
      token = 'new';
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(sockets.length, 2);
      expect(sockets.first.closed, isTrue);
      expect(sockets.last.sent.single, contains('Bearer new'));
      realtime.dispose();
      for (final socket in sockets) {
        await socket.events.close();
      }
    },
  );
  test(
    'repeated connect failures stop after capped retries and manual reconnect restarts',
    () async {
      var calls = 0;
      final states = <MessagingConnectionStatus>[];
      final realtime = MessagingRealtime(
        uri: Uri.parse('wss://host/ws'),
        personId: 'person',
        tokenReader: ({bool forceRefresh = false}) async => 'token',
        isCurrent: () => true,
        onState: states.add,
        onChange: () {},
        retryBase: Duration.zero,
        retryJitter: Duration.zero,
        connector: (_) async {
          calls++;
          throw StateError('network');
        },
      );
      await realtime.start();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls, 7);
      expect(states.last, MessagingConnectionStatus.disconnected);
      realtime.reconnect();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(calls, 14);
      realtime.dispose();
    },
  );
  test('list subscribes only current person topic', () async {
    final socket = FakeSocket();
    var changes = 0;
    final realtime = MessagingRealtime(
      uri: Uri.parse('wss://host/ws'),
      personId: 'person',
      tokenReader: ({bool forceRefresh = false}) async => 'token',
      isCurrent: () => true,
      onState: (_) {},
      onChange: () => changes++,
      connector: (_) async => socket,
    );
    await realtime.start();
    socket.events.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\u0000');
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent.length, 2);
    expect(socket.sent.last, contains('/topic/messaging/users/person'));
    expect(changes, 1);
    realtime.dispose();
    await socket.events.close();
  });
}
