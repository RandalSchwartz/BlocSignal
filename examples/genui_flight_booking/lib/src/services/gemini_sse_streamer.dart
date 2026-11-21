import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Live SSE / REST streamer connecting to Google Gemini API when an API key is provided.
class GeminiSseStreamer {
  /// Default timeout for establishing the HTTP connection and receiving headers.
  static const Duration defaultRequestTimeout = Duration(seconds: 15);

  /// Default timeout between consecutive SSE response chunks.
  static const Duration defaultChunkTimeout = Duration(seconds: 30);

  /// Default maximum number of bytes read from a non-200 error response body.
  static const int defaultMaxErrorBodyBytes = 1024;

  /// Default maximum number of bytes buffered for a single SSE line.
  static const int defaultMaxLineBytes = 256 * 1024;

  /// Stream prompt response chunks from Gemini API endpoint.
  static Stream<Map<String, dynamic>> streamFromGemini({
    required String apiKey,
    required String prompt,
    HttpClient? client,
    Duration requestTimeout = defaultRequestTimeout,
    Duration chunkTimeout = defaultChunkTimeout,
    int maxErrorBodyBytes = defaultMaxErrorBodyBytes,
    int maxLineBytes = defaultMaxLineBytes,
  }) async* {
    final effectiveClient =
        client ?? (HttpClient()..connectionTimeout = requestTimeout);
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent?alt=sse',
      );

      final request =
          await effectiveClient.postUrl(uri).timeout(requestTimeout);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('x-goog-api-key', apiKey);

      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {
              'text':
                  'You are a flight booking assistant that outputs A2UI declarative JSON messages.',
            },
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      });

      request.write(body);
      final response = await request.close().timeout(
        requestTimeout,
        onTimeout: () {
          try {
            request.abort();
          } on Object catch (_) {
            // Ignore if a test double does not implement abort().
          }
          throw TimeoutException(
            'Timed out waiting for Gemini API response headers',
            requestTimeout,
          );
        },
      );

      if (response.statusCode != HttpStatus.ok) {
        final errorBody = await _readBoundedErrorBody(
          response,
          maxErrorBodyBytes,
          requestTimeout,
        );
        throw HttpException(
          'Gemini API streaming error (status ${response.statusCode}): $errorBody',
          uri: uri,
        );
      }

      final timedByteStream = response.timeout(chunkTimeout);
      await for (final line in _splitBoundedLines(
        timedByteStream,
        maxLineBytes,
      )) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6).trim();
          if (jsonStr.isNotEmpty) {
            try {
              final parsed = jsonDecode(jsonStr);
              if (parsed is Map<String, dynamic>) {
                yield parsed;
              }
            } on FormatException catch (_) {
              // Ignore partial or non-JSON chunk
            }
          }
        }
      }
    } finally {
      if (client == null) {
        effectiveClient.close();
      }
    }
  }

  static Future<String> _readBoundedErrorBody(
    HttpClientResponse response,
    int maxBytes,
    Duration timeout,
  ) async {
    final builder = BytesBuilder(copy: false);
    final completer = Completer<String>();
    var truncated = false;
    StreamSubscription<List<int>>? subscription;
    Timer? timer;

    String formatErrorBody() {
      final decoded = utf8
          .decode(builder.takeBytes(), allowMalformed: true)
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
      return truncated ? '$decoded... (truncated)' : decoded;
    }

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        unawaited(subscription?.cancel());
        completer.completeError(
          TimeoutException('Timed out reading error response body', timeout),
        );
      }
    });

    try {
      subscription = response.listen(
        (chunk) {
          final remaining = maxBytes - builder.length;
          if (remaining <= 0) {
            truncated = true;
            unawaited(subscription?.cancel());
            if (!completer.isCompleted) {
              completer.complete(formatErrorBody());
            }
            return;
          }
          if (chunk.length > remaining) {
            builder.add(chunk.sublist(0, remaining));
            truncated = true;
            unawaited(subscription?.cancel());
            if (!completer.isCompleted) {
              completer.complete(formatErrorBody());
            }
            return;
          }
          builder.add(chunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
        onDone: () {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(formatErrorBody());
          }
        },
        cancelOnError: true,
      );

      return await completer.future;
    } finally {
      timer.cancel();
      await subscription?.cancel();
    }
  }

  static Stream<String> _splitBoundedLines(
    Stream<List<int>> byteStream,
    int maxLineBytes,
  ) async* {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in byteStream) {
      var start = 0;
      for (var i = 0; i < chunk.length; i++) {
        if (chunk[i] == 0x0A) {
          final lineLength = buffer.length + (i - start);
          if (lineLength > maxLineBytes) {
            throw FormatException(
              'SSE line exceeds maximum allowed size of $maxLineBytes bytes',
            );
          }
          if (i > start) {
            buffer.add(chunk.sublist(start, i));
          }
          final lineBytes = buffer.takeBytes();
          final end = (lineBytes.isNotEmpty && lineBytes.last == 0x0D)
              ? lineBytes.length - 1
              : lineBytes.length;
          yield utf8.decode(
            end == lineBytes.length ? lineBytes : lineBytes.sublist(0, end),
            allowMalformed: true,
          );
          start = i + 1;
        }
      }
      final remaining = chunk.length - start;
      if (buffer.length + remaining > maxLineBytes) {
        throw FormatException(
          'SSE line exceeds maximum allowed size of $maxLineBytes bytes',
        );
      }
      if (remaining > 0) {
        buffer.add(start == 0 ? chunk : chunk.sublist(start));
      }
    }
    if (buffer.isNotEmpty) {
      final lineBytes = buffer.takeBytes();
      final end = (lineBytes.isNotEmpty && lineBytes.last == 0x0D)
          ? lineBytes.length - 1
          : lineBytes.length;
      yield utf8.decode(
        end == lineBytes.length ? lineBytes : lineBytes.sublist(0, end),
        allowMalformed: true,
      );
    }
  }
}
