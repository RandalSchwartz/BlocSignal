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

  group('(Issue #473) GeminiSseStreamer bounds & timeouts', () {
    test(
        'throws FormatException when SSE line exceeds maxLineBytes without '
        'newline', () async {
      final oversizedLine = 'data: ${'a' * (256 * 1024 + 128)}';
      final response = _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        bodyBytes: utf8.encode(oversizedLine),
      );
      final client = _FakeHttpClient(response);

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          client: client,
        ).toList(),
        throwsA(isA<FormatException>()),
      );
    });

    test('caps non-200 error body read to 1024 bytes', () async {
      final largeErrorBody = 'E' * 4096;
      final response = _FakeHttpClientResponse(
        statusCode: HttpStatus.internalServerError,
        bodyBytes: utf8.encode(largeErrorBody),
      );
      final client = _FakeHttpClient(response);

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          client: client,
        ).toList(),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message.length,
            'message.length',
            lessThanOrEqualTo(1150),
          ),
        ),
      );
    });

    test('throws TimeoutException when chunk stream stalls past chunkTimeout',
        () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final response = _StreamHttpClientResponse(
        statusCode: HttpStatus.ok,
        stream: controller.stream,
      );
      final client = _FakeHttpClient(response);

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          client: client,
          chunkTimeout: const Duration(milliseconds: 50),
        ).toList(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('throws FormatException on newline-terminated oversized line',
        () async {
      final oversizedLine = 'data: ${'a' * (256 * 1024 + 10)}\n';
      final response = _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        bodyBytes: utf8.encode(oversizedLine),
      );
      final client = _FakeHttpClient(response);

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          client: client,
        ).toList(),
        throwsA(isA<FormatException>()),
      );
    });

    test('reassembles multi-chunk SSE lines, strips CR, and flushes EOF line',
        () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final response = _StreamHttpClientResponse(
        statusCode: HttpStatus.ok,
        stream: controller.stream,
      );
      final client = _FakeHttpClient(response);

      final future = GeminiSseStreamer.streamFromGemini(
        apiKey: 'test-key',
        prompt: 'Find flights',
        client: client,
      ).toList();

      controller.add(utf8.encode('data: {"candidates":'));
      await Future<void>.delayed(Duration.zero);
      controller.add(utf8.encode('[{"index":0}]}\r\n'));
      await Future<void>.delayed(Duration.zero);
      // Trailing line at EOF without newline
      controller.add(utf8.encode('data: {"candidates":[{"index":1}]}'));
      await controller.close();

      final chunks = await future;
      expect(chunks, hasLength(2));
      expect(
        (chunks[0]['candidates'] as List<dynamic>).first['index'],
        equals(0),
      );
      expect(
        (chunks[1]['candidates'] as List<dynamic>).first['index'],
        equals(1),
      );
    });

    test(
        'caps multi-chunk error body, strips control chars, and adds '
        'truncated suffix', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final response = _StreamHttpClientResponse(
        statusCode: HttpStatus.badRequest,
        stream: controller.stream,
      );
      final client = _FakeHttpClient(response);

      final future = GeminiSseStreamer.streamFromGemini(
        apiKey: 'test-key',
        prompt: 'Find flights',
        client: client,
      ).toList();

      // Chunk 1: 600 bytes with control chars; Chunk 2: 600 bytes (exceeds 1024)
      controller.add(utf8.encode('err\x00\x1B\n${'A' * 594}'));
      await Future<void>.delayed(Duration.zero);
      controller.add(utf8.encode('B' * 600));
      await controller.close();

      await expectLater(
        future,
        throwsA(
          isA<HttpException>()
              .having(
                (e) => e.message,
                'message',
                contains('... (truncated)'),
              )
              .having(
                (e) => e.message,
                'control chars stripped',
                isNot(
                    anyOf(contains('\x00'), contains('\x1B'), contains('\n'))),
              ),
        ),
      );
    });

    test('throws TimeoutException when postUrl stalls past requestTimeout',
        () async {
      final client = _StallingPostUrlHttpClient();

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          client: client,
          requestTimeout: const Duration(milliseconds: 50),
        ).toList(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
        'throws TimeoutException when request.close stalls past requestTimeout',
        () async {
      final client = _StallingCloseHttpClient();

      await expectLater(
        GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          client: client,
          requestTimeout: const Duration(milliseconds: 50),
        ).toList(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
        'throws TimeoutException and cancels subscription when error body '
        'stalls past requestTimeout', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final response = _StreamHttpClientResponse(
        statusCode: HttpStatus.internalServerError,
        stream: controller.stream,
      );
      final client = _FakeHttpClient(response);

      final future = GeminiSseStreamer.streamFromGemini(
        apiKey: 'test-key',
        prompt: 'Find flights',
        client: client,
        requestTimeout: const Duration(milliseconds: 50),
      ).toList();

      await expectLater(future, throwsA(isA<TimeoutException>()));
      expect(controller.hasListener, isFalse);
    });

    test(
        'sets connectionTimeout and closes internal HttpClient when client '
        'is null', () async {
      const ssePayload = 'data: {"candidates":[{"index":0}]}\n\n';
      final response = _FakeHttpClientResponse(
        statusCode: HttpStatus.ok,
        bodyBytes: utf8.encode(ssePayload),
      );
      final internalClient = _ConfigurableFakeHttpClient(response);

      final chunks = await HttpOverrides.runZoned(
        () => GeminiSseStreamer.streamFromGemini(
          apiKey: 'test-key',
          prompt: 'Find flights',
          requestTimeout: const Duration(seconds: 12),
        ).toList(),
        createHttpClient: (_) => internalClient,
      );

      expect(chunks, hasLength(1));
      expect(
        internalClient.connectionTimeout,
        equals(const Duration(seconds: 12)),
      );
      expect(internalClient.closed, isTrue);
    });
  });
}

class _ConfigurableFakeHttpClient extends _FakeHttpClient {
  _ConfigurableFakeHttpClient(super.response);

  @override
  Duration? connectionTimeout;
}

class _StallingPostUrlHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StallingCloseHttpClientRequest implements HttpClientRequest {
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() => Completer<HttpClientResponse>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StallingCloseHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _StallingCloseHttpClientRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _StreamHttpClientResponse({
    required this.statusCode,
    required Stream<List<int>> stream,
  }) : _stream = stream;

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
