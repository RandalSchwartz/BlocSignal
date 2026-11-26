import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final RegExp _validSlugPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
final RegExp _invalidSlugCharsPattern = RegExp('[^a-zA-Z0-9_-]+');
final RegExp _multiHyphenPattern = RegExp('-+');
final RegExp _edgeTrimPattern = RegExp(r'^[-_.]+|[-_.]+$');

String _normalizeToken(String raw) {
  return raw
      .replaceAll(_invalidSlugCharsPattern, '-')
      .replaceAll(_multiHyphenPattern, '-')
      .replaceAll(_edgeTrimPattern, '');
}

/// Sanitizes an article [slug] into a safe filename stem matching
/// `^[a-zA-Z0-9_-]+$`, falling back to `article-<id>` when [slug] is empty
/// or contains no valid slug characters.
///
/// Throws an [ArgumentError] if fallback is required and [id] is `null` or
/// cannot produce a valid slug matching `^[a-zA-Z0-9_-]+$`.
String sanitizeSlug(String? slug, {required Object? id}) {
  if (slug != null) {
    final normalized = _normalizeToken(slug);
    if (normalized.isNotEmpty &&
        !normalized.contains('..') &&
        _validSlugPattern.hasMatch(normalized)) {
      return normalized;
    }
  }

  if (id == null) {
    throw ArgumentError.notNull('id');
  }

  final normalizedId = _normalizeToken(id.toString());
  if (normalizedId.isEmpty ||
      normalizedId.contains('..') ||
      !_validSlugPattern.hasMatch(normalizedId)) {
    throw ArgumentError.value(
      id,
      'id',
      'Article id cannot produce a valid fallback slug.',
    );
  }

  final fallback = _normalizeToken('article-$normalizedId');
  if (fallback.isEmpty ||
      fallback.contains('..') ||
      !_validSlugPattern.hasMatch(fallback)) {
    throw ArgumentError.value(id, 'id', 'Fallback slug failed validation.');
  }

  return fallback;
}

/// Resolves `<slug>.md` strictly within [articlesDir], rejecting invalid slugs,
/// symbolic links, and any path whose canonical target escapes [articlesDir].
///
/// Throws an [ArgumentError] if [slug] violates `^[a-zA-Z0-9_-]+$` or if path
/// containment checks fail.
File resolveContainedArticleFile(Directory articlesDir, String slug) {
  if (slug.isEmpty ||
      slug.contains('..') ||
      !_validSlugPattern.hasMatch(slug)) {
    throw ArgumentError.value(slug, 'slug', 'Invalid article slug.');
  }

  final fileName = '$slug.md';
  if (p.basename(fileName) != fileName) {
    throw ArgumentError.value(
      slug,
      'slug',
      'Slug must resolve to a single filename.',
    );
  }

  final canonicalDir = articlesDir.existsSync()
      ? articlesDir.resolveSymbolicLinksSync()
      : p.canonicalize(articlesDir.path);
  final candidatePath = p.join(canonicalDir, fileName);

  if (FileSystemEntity.isLinkSync(candidatePath)) {
    throw ArgumentError.value(
      candidatePath,
      'slug',
      'Refusing to resolve a symbolic link inside articles directory.',
    );
  }

  final candidateFile = File(candidatePath);
  final canonicalTarget = candidateFile.existsSync()
      ? candidateFile.resolveSymbolicLinksSync()
      : p.canonicalize(candidatePath);

  if (!p.isWithin(canonicalDir, canonicalTarget) ||
      p.dirname(canonicalTarget) != canonicalDir ||
      p.basename(canonicalTarget) != fileName) {
    throw ArgumentError.value(
      canonicalTarget,
      'slug',
      'Resolved article path escapes articles directory.',
    );
  }

  return File(canonicalTarget);
}

Duration _clampDelay(Duration delay, Duration maxDelay) {
  if (delay < Duration.zero) return Duration.zero;
  if (delay > maxDelay) return maxDelay;
  return delay;
}

/// Parses an HTTP `Retry-After` header [headerValue] (either integer seconds
/// or an HTTP-date) clamped to `[Duration.zero, maxDelay]`, returning
/// [fallback] (also clamped) when missing or invalid.
Duration parseRetryAfter(
  String? headerValue, {
  required Duration fallback,
  DateTime? now,
  Duration maxDelay = const Duration(seconds: 60),
}) {
  final clampedFallback = _clampDelay(fallback, maxDelay);
  final trimmed = headerValue?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return clampedFallback;
  }

  final seconds = int.tryParse(trimmed);
  if (seconds != null) {
    if (seconds < 0) return clampedFallback;
    return _clampDelay(Duration(seconds: seconds), maxDelay);
  }

  try {
    final targetTime = HttpDate.parse(trimmed);
    final reference = (now ?? DateTime.now()).toUtc();
    return _clampDelay(targetTime.difference(reference), maxDelay);
  } on HttpException {
    return clampedFallback;
  }
}

/// Invokes [fetch], retrying `HTTP 429` responses up to [maxRetries] times
/// using the response's `Retry-After` header or exponential backoff starting
/// at [initialBackoff], bounded by [maxDelay].
Future<({int statusCode, String body})> fetchWithRateLimitRetry(
  Future<({int statusCode, String body, String? retryAfter})> Function()
  fetch, {
  int maxRetries = 4,
  Duration initialBackoff = const Duration(seconds: 2),
  Duration maxDelay = const Duration(seconds: 60),
  Future<void> Function(Duration delay)? sleep,
  void Function(int retryAttempt, Duration delay)? onRetry,
}) async {
  final wait = sleep ?? Future<void>.delayed;
  var attempt = 0;

  while (true) {
    final response = await fetch();
    if (response.statusCode != 429 || attempt >= maxRetries) {
      return (statusCode: response.statusCode, body: response.body);
    }

    final exponentialFallback = Duration(
      milliseconds: initialBackoff.inMilliseconds * (1 << attempt),
    );
    final delay = parseRetryAfter(
      response.retryAfter,
      fallback: exponentialFallback,
      maxDelay: maxDelay,
    );
    attempt++;
    onRetry?.call(attempt, delay);
    await wait(delay);
  }
}

Future<({int statusCode, String body, String? retryAfter})> _getJsonResponse(
  HttpClient client,
  Uri uri,
) async {
  final request = await client.getUrl(uri);
  request.headers.set(
    HttpHeaders.userAgentHeader,
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
  );
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');

  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  return (
    statusCode: response.statusCode,
    body: body,
    retryAfter: response.headers.value(HttpHeaders.retryAfterHeader),
  );
}

/// Validates that [rawId] is a positive integer DEV.to article ID, returning
/// the validated `int` or `null` when invalid.
int? parseValidArticleId(Object? rawId) =>
    rawId is int && rawId > 0 ? rawId : null;

/// Script to download all published DEV.to articles for `@randalschwartz`
/// into `doc/articles/` as canonical markdown backups.
Future<void> main() async {
  final articlesDir = Directory('doc/articles');
  if (!articlesDir.existsSync()) {
    articlesDir.createSync(recursive: true);
  }

  final client = HttpClient();
  try {
    final listUri = Uri.parse(
      'https://dev.to/api/articles?username=randalschwartz&per_page=100',
    );

    stdout.writeln('📡 Fetching article listing from DEV.to...');
    final listRes = await fetchWithRateLimitRetry(
      () => _getJsonResponse(client, listUri),
      onRetry: (attempt, delay) => stderr.writeln(
        '⏳ Rate-limited (429) fetching listing; retrying attempt $attempt '
        'in ${delay.inSeconds}s...',
      ),
    );

    if (listRes.statusCode != 200) {
      stderr.writeln(
        '❌ Failed to fetch articles listing: HTTP ${listRes.statusCode}',
      );
      exitCode = 1;
      return;
    }

    final decodedArticles = jsonDecode(listRes.body);
    if (decodedArticles is! List<dynamic>) {
      stderr.writeln('❌ Unexpected DEV.to articles listing payload.');
      exitCode = 1;
      return;
    }

    stdout.writeln('📚 Found ${decodedArticles.length} articles on DEV.to.');

    var downloadedCount = 0;

    for (final article in decodedArticles) {
      if (article is! Map<String, dynamic>) {
        stderr.writeln('⚠️ Skipping malformed article entry.');
        continue;
      }

      final id = parseValidArticleId(article['id']);
      if (id == null) {
        stderr.writeln(
          '⚠️ Skipping article with invalid id: ${article['id']}.',
        );
        continue;
      }

      final rawSlug = article['slug'];
      final slugInput = rawSlug is String ? rawSlug : null;

      final String safeSlug;
      final File targetFile;
      try {
        safeSlug = sanitizeSlug(slugInput, id: id);
        targetFile = resolveContainedArticleFile(articlesDir, safeSlug);
        // Isolate untrusted remote DEV.to payloads per article.
        // ignore: avoid_catching_errors
      } on ArgumentError catch (error) {
        stderr.writeln('⚠️ Skipping unsafe article ($id): $error');
        continue;
      }

      stdout.writeln('⬇️ Fetching full markdown for: $safeSlug (ID: $id)...');

      final detailUri = Uri.parse('https://dev.to/api/articles/$id');
      final detailRes = await fetchWithRateLimitRetry(
        () => _getJsonResponse(client, detailUri),
        onRetry: (attempt, delay) => stderr.writeln(
          '⏳ Rate-limited (429) for $id; retrying attempt $attempt '
          'in ${delay.inSeconds}s...',
        ),
      );

      if (detailRes.statusCode == 200) {
        final detailDecoded = jsonDecode(detailRes.body);
        if (detailDecoded is Map<String, dynamic>) {
          final bodyMarkdown = detailDecoded['body_markdown'];
          if (bodyMarkdown is String && bodyMarkdown.isNotEmpty) {
            targetFile.writeAsStringSync(bodyMarkdown);
            downloadedCount++;
          }
        }
      } else {
        stderr.writeln(
          '⚠️ Failed to fetch detail for $id: HTTP ${detailRes.statusCode}',
        );
      }

      // Rate-limit friendly pause
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    stdout.writeln(
      '🎉 Successfully downloaded $downloadedCount articles into doc/articles/',
    );
  } finally {
    client.close();
  }
}
