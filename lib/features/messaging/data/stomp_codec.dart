import 'dart:convert';

class StompFrame {
  const StompFrame(this.command, {this.headers = const {}, this.body = ''});
  final String command;
  final Map<String, String> headers;
  final String body;
  String encode() {
    final escaped = command != 'CONNECT' && command != 'CONNECTED';
    String escape(String value) => escaped
        ? value
              .replaceAll('\\', r'\\')
              .replaceAll('\r', r'\r')
              .replaceAll('\n', r'\n')
              .replaceAll(':', r'\c')
        : value;
    final fields = {
      ...headers,
      if (body.isNotEmpty) 'content-length': '${utf8.encode(body).length}',
    };
    return '$command\n${fields.entries.map((e) => '${escape(e.key)}:${escape(e.value)}\n').join()}\n$body\u0000';
  }
}

/// Incremental byte parser: WebSocket chunks do not define STOMP frame boundaries.
class StompDecoder {
  final List<int> _buffer = [];
  static const maxBytes = 1024 * 1024;
  List<StompFrame> add(Object chunk) {
    _buffer.addAll(chunk is String ? utf8.encode(chunk) : (chunk as List<int>));
    if (_buffer.length > maxBytes) {
      throw const FormatException('Oversized STOMP frame');
    }
    final result = <StompFrame>[];
    while (_buffer.isNotEmpty) {
      if (_buffer.first == 10 || _buffer.first == 13) {
        _buffer.removeAt(0);
        continue;
      }
      var headerEnd = -1, separatorSize = 0;
      for (var i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 10 && _buffer[i + 1] == 10) {
          headerEnd = i;
          separatorSize = 2;
          break;
        }
        if (i + 3 < _buffer.length &&
            _buffer[i] == 13 &&
            _buffer[i + 1] == 10 &&
            _buffer[i + 2] == 13 &&
            _buffer[i + 3] == 10) {
          headerEnd = i;
          separatorSize = 4;
          break;
        }
      }
      if (headerEnd < 0) {
        break;
      }
      final lines = utf8
          .decode(_buffer.sublist(0, headerEnd))
          .split(RegExp(r'\r?\n'));
      final command = lines.first;
      final escaped = command != 'CONNECT' && command != 'CONNECTED';
      String unescape(String value) {
        if (!escaped) {
          return value;
        }
        final out = StringBuffer();
        for (var i = 0; i < value.length; i++) {
          if (value[i] != '\\') {
            out.write(value[i]);
            continue;
          }
          if (++i >= value.length) {
            throw const FormatException('Invalid STOMP escape');
          }
          out.write(switch (value[i]) {
            'n' => '\n',
            'r' => '\r',
            'c' => ':',
            '\\' => '\\',
            _ => throw const FormatException('Invalid STOMP escape'),
          });
        }
        return out.toString();
      }

      final headers = <String, String>{};
      for (final line in lines.skip(1)) {
        final split = line.indexOf(':');
        if (split < 1) {
          throw const FormatException('Invalid STOMP header');
        }
        headers.putIfAbsent(
          unescape(line.substring(0, split)),
          () => unescape(line.substring(split + 1)),
        );
      }
      final bodyStart = headerEnd + separatorSize;
      int bodyEnd;
      if (headers.containsKey('content-length')) {
        final length = int.tryParse(headers['content-length']!);
        if (length == null || length < 0 || length > maxBytes) {
          throw const FormatException('Invalid STOMP length');
        }
        bodyEnd = bodyStart + length;
        if (_buffer.length <= bodyEnd) {
          break;
        }
        if (_buffer[bodyEnd] != 0) {
          throw const FormatException('Missing STOMP terminator');
        }
      } else {
        bodyEnd = _buffer.indexOf(0, bodyStart);
        if (bodyEnd < 0) {
          break;
        }
      }
      result.add(
        StompFrame(
          command,
          headers: headers,
          body: utf8.decode(_buffer.sublist(bodyStart, bodyEnd)),
        ),
      );
      _buffer.removeRange(0, bodyEnd + 1);
    }
    return result;
  }
}
