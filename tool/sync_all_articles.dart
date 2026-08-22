import 'dart:convert';
import 'dart:io';

/// Script to download all published DEV.to articles for @randalschwartz
/// into `doc/articles/` as canonical markdown backups.
Future<void> main() async {
  final articlesDir = Directory('doc/articles');
  if (!articlesDir.existsSync()) {
    articlesDir.createSync(recursive: true);
  }

  final client = HttpClient();
  final listUri = Uri.parse(
    'https://dev.to/api/articles?username=randalschwartz&per_page=100',
  );

  print('📡 Fetching article listing from DEV.to...');
  final request = await client.getUrl(listUri);
  request.headers.set(
    HttpHeaders.userAgentHeader,
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
  );
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');

  final response = await request.close();
  final jsonString = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    print('❌ Failed to fetch articles listing: HTTP ${response.statusCode}');
    client.close();
    exit(1);
  }

  final List<dynamic> articles = jsonDecode(jsonString);
  print('📚 Found ${articles.length} articles on DEV.to.');

  var downloadedCount = 0;

  for (final article in articles) {
    final id = article['id'];
    final slug = article['slug'] as String? ?? 'article-$id';

    // Sanitize slug for filename
    final filename = '$slug.md';
    final targetFile = File('${articlesDir.path}/$filename');

    print('⬇️ Fetching full markdown for: $slug (ID: $id)...');

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
      final Map<String, dynamic> detail = jsonDecode(detailJson);
      final bodyMarkdown = detail['body_markdown'] as String?;

      if (bodyMarkdown != null && bodyMarkdown.isNotEmpty) {
        targetFile.writeAsStringSync(bodyMarkdown);
        downloadedCount++;
      }
    } else {
      print('⚠️ Failed to fetch detail for $id: HTTP ${detailRes.statusCode}');
    }

    // Rate-limit friendly pause
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  client.close();
  print(
    '🎉 Successfully downloaded $downloadedCount articles into doc/articles/',
  );
}
