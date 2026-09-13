import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Live SSE / REST streamer connecting to Google Gemini API when an API key is provided.
class GeminiSseStreamer {
  /// Stream prompt response chunks from Gemini API endpoint.
  static Stream<Map<String, dynamic>> streamFromGemini({
    required String apiKey,
    required String prompt,
  }) async* {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent?alt=sse&key=$apiKey',
      );

      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'You are a flight booking assistant that outputs A2UI declarative JSON messages.\n$prompt',
              },
            ],
          },
        ],
      });

      request.write(body);
      final response = await request.close();

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
            } catch (_) {
              // Ignore partial or non-JSON chunk
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
