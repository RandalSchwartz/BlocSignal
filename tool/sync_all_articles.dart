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
    final request = await client.getUrl(listUri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final jsonString = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      stderr.writeln(
        '❌ Failed to fetch articles listing: HTTP ${response.statusCode}',
      );
      exitCode = 1;
      return;
    }

    final decodedArticles = jsonDecode(jsonString);
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

      final id = article['id'];
      if (id == null) {
        stderr.writeln('⚠️ Skipping article without id.');
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
      final detailReq = await client.getUrl(detailUri);
      detailReq.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      );
      detailReq.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final detailRes = await detailReq.close();
      final detailJson = await detailRes.transform(utf8.decoder).join();

      if (detailRes.statusCode == 200) {
        final detailDecoded = jsonDecode(detailJson);
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
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    stdout.writeln(
      '🎉 Successfully downloaded $downloadedCount articles into doc/articles/',
    );
  } finally {
    client.close();
  }
}
