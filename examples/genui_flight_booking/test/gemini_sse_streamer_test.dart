import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flight_booking/src/services/gemini_sse_streamer.dart';

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  String? value(String name) => values[name.toLowerCase()]?.firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.statusCode,
    required List<int> bodyBytes,
  }) : _stream = Stream<List<int>>.value(bodyBytes);

  @override
  final int statusCode;

  final Stream<List<int>> _stream;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._response);

  final HttpClientResponse _response;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();
  final StringBuffer _bodyBuffer = StringBuffer();

  String get body => _bodyBuffer.toString();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object) {
    _bodyBuffer.write(object);
  }

  @override
  Future<HttpClientResponse> close() async => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._response);

  final HttpClientResponse _response;
  Uri? capturedUri;
  late _FakeHttpClientRequest capturedRequest;
  bool closed = false;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    capturedUri = url;
    capturedRequest = _FakeHttpClientRequest(_response);
    return capturedRequest;
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('(Issue #430) GeminiSseStreamer', () {
    test(
        'sends API key in x-goog-api-key header, omits key from URI, and '
        'separates system_instruction from contents', () async {
      const ssePayload = 'data: {"candidates":[{"index":0}]}\n\n';
      final response = _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        bodyBytes: utf8.encode(ssePayload),
      );
      final client = _FakeHttpClient(response);

      final chunks = await GeminiSseStreamer.streamFromGemini(
        apiKey: 'secret-test-key',
        prompt: 'Find flights to Tokyo',
        client: client,
      ).toList();

      expect(chunks, hasLength(1));
      expect(chunks.first['candidates'], isA<List<dynamic>>());

      final uri = client.capturedUri!;
      expect(uri.queryParameters.containsKey('key'), isFalse);
      expect(uri.queryParameters['alt'], equals('sse'));

      final headers = client.capturedRequest.headers;
      expect(headers.value('x-goog-api-key'), equals('secret-test-key'));
      expect(headers.value('content-type'), equals('application/json'));

      final decodedBody =
          jsonDecode(client.capturedRequest.body) as Map<String, dynamic>;
      expect(decodedBody.containsKey('system_instruction'), isTrue);
      final contents = decodedBody['contents'] as List<dynamic>;
      final firstContent = contents.first as Map<String, dynamic>;
      final parts = firstContent['parts'] as List<dynamic>;
      final firstPart = parts.first as Map<String, dynamic>;
      expect(firstPart['text'], equals('Find flights to Tokyo'));

      // Externally provided client must not be closed by streamFromGemini.
      expect(client.closed, isFalse);
    });

    test('throws HttpException on non-200 HTTP response', () async {
      final response = _FakeHttpClientResponse(
        statusCode: HttpStatus.forbidden,
        bodyBytes: utf8.encode('{"error":"API key invalid"}'),
      );
      final client = _FakeHttpClient(response);

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'bad-key',
          prompt: 'Find flights',
          client: client,
        ).toList(),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
