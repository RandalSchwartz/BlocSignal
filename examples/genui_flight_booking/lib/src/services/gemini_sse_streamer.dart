import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Live SSE / REST streamer connecting to Google Gemini API when an API key is provided.
class GeminiSseStreamer {
  /// Stream prompt response chunks from Gemini API endpoint.
  static Stream<Map<String, dynamic>> streamFromGemini({
    required String apiKey,
    required String prompt,
    HttpClient? client,
  }) async* {
    final effectiveClient = client ?? HttpClient();
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent?alt=sse',
      );

      final request = await effectiveClient.postUrl(uri);
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
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        final errorBody = await response.transform(utf8.decoder).join();
        throw HttpException(
          'Gemini API streaming error (status ${response.statusCode}): $errorBody',
          uri: uri,
        );
      }

      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
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
}
