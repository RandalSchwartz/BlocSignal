import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../website/tool/update_publications.dart' as update_tool;

void main() {
  group('update_publications code generation (Issue #419)', () {
    group('validateHttpsUrl', () {
      test(
        'accepts valid https URLs with paths, query params, and anchors',
        () {
          const validUrls = [
            'https://dev.to/gde/my-article',
            'https://example.com/path/to/resource?query=1&sort=desc#section',
            'https://sub.domain.example.org:8443/test',
            'https://blocsignal.dev',
          ];

          for (final url in validUrls) {
            expect(
              update_tool.validateHttpsUrl(url),
              equals(url),
              reason: 'Expected $url to be valid',
            );
          }
        },
      );

      test('throws FormatException for null, empty, or whitespace strings', () {
        const invalidInputs = [null, '', '   ', '\t\n  '];

        for (final input in invalidInputs) {
          expect(
            () => update_tool.validateHttpsUrl(input),
            throwsFormatException,
            reason: 'Expected "$input" to throw FormatException',
          );
        }
      });

      test('throws FormatException for non-string types', () {
        const nonStrings = [
          123,
          true,
          ['https://dev.to'],
          {'url': 'https://dev.to'},
        ];

        for (final input in nonStrings) {
          expect(
            () => update_tool.validateHttpsUrl(input),
            throwsFormatException,
          );
        }
      });

      test('throws FormatException for non-https schemes', () {
        const forbiddenSchemes = [
          'http://dev.to/article',
          'javascript:alert(1)',
          'ftp://files.example.com',
          'data:text/html;base64,PHNjcmlwdD4=',
          'file:///etc/passwd',
          'ws://localhost:8080',
          'blob:https://example.com/1234',
        ];

        for (final url in forbiddenSchemes) {
          expect(
            () => update_tool.validateHttpsUrl(url),
            throwsFormatException,
            reason: 'Scheme in $url must be rejected',
          );
        }
      });

      test('throws FormatException for malformed URLs or missing host', () {
        const malformedUrls = [
          'https://',
          'https:///',
          'https:///path',
          'not a url',
          '://no-scheme',
          'https://:8080',
        ];

        for (final url in malformedUrls) {
          expect(
            () => update_tool.validateHttpsUrl(url),
            throwsFormatException,
            reason: 'Malformed URL $url must throw FormatException',
          );
        }
      });
    });

    group('formatTagsCode', () {
      test('returns const [] for null or empty lists', () {
        expect(update_tool.formatTagsCode(null), equals('const []'));
        expect(update_tool.formatTagsCode([]), equals('const []'));
      });

      test("returns const ['flutter', 'dart'] for standard tag lists", () {
        expect(
          update_tool.formatTagsCode(['flutter', 'dart']),
          equals("const ['flutter', 'dart']"),
        );
        expect(
          update_tool.formatTagsCode([
            'architecture',
            'state-management',
            'web',
          ]),
          equals("const ['architecture', 'state-management', 'web']"),
        );
      });

      test('escapes special characters in tags via escapeDartString', () {
        final tags = [
          "it's",
          'quote"double',
          r'backslash\test',
          r'cost$50',
          r'evil${process.run}',
          'new\nline',
          'carriage\rreturn',
        ];

        final result = update_tool.formatTagsCode(tags);
        expect(
          result,
          equals(
            r"""const ['it\'s', 'quote"double', 'backslash\\test', 'cost\$50', 'evil\${process.run}', 'new\nline', 'carriage\rreturn']""",
          ),
        );
      });
    });

    group('generatePublicationItemCode', () {
      test(
        'emits valid, formatted PublicationItem code with standard inputs',
        () {
          final code = update_tool.generatePublicationItemCode(
            title: 'The Symmetry of State',
            description: 'A deep dive into reactive patterns.',
            url: 'https://dev.to/gde/symmetry-of-state',
            date: 'Sep 11',
            readTime: '9 min read',
            category: 'Flutter & Jaspr',
            tags: ['flutter', 'dart'],
          );

          expect(
            code,
            equals(
              '  PublicationItem(\n'
              "    title: 'The Symmetry of State',\n"
              "    description: 'A deep dive into reactive patterns.',\n"
              "    url: 'https://dev.to/gde/symmetry-of-state',\n"
              "    date: 'Sep 11',\n"
              "    readTime: '9 min read',\n"
              "    category: 'Flutter & Jaspr',\n"
              "    type: 'Article',\n"
              "    tags: const ['flutter', 'dart'],\n"
              '  ),',
            ),
          );
        },
      );

      test('formats tags as const [] when tags is null or empty', () {
        final codeWithNullTags = update_tool.generatePublicationItemCode(
          title: 'Title',
          description: 'Desc',
          url: 'https://dev.to/gde/article',
          date: 'Aug 14',
          readTime: '5 min read',
          category: 'Architecture',
        );
        expect(codeWithNullTags, contains('tags: const [],'));

        final codeWithEmptyTags = update_tool.generatePublicationItemCode(
          title: 'Title',
          description: 'Desc',
          url: 'https://dev.to/gde/article',
          date: 'Aug 14',
          readTime: '5 min read',
          category: 'Architecture',
          tags: [],
        );
        expect(codeWithEmptyTags, contains('tags: const [],'));
      });

      test('rejects non-HTTPS or invalid URLs by throwing FormatException', () {
        expect(
          () => update_tool.generatePublicationItemCode(
            title: 'Title',
            description: 'Desc',
            url: 'http://insecure.dev.to/article',
            date: 'Aug 14',
            readTime: '5 min read',
            category: 'Architecture',
            tags: ['flutter'],
          ),
          throwsFormatException,
        );

        expect(
          () => update_tool.generatePublicationItemCode(
            title: 'Title',
            description: 'Desc',
            url: 'javascript:alert(1)',
            date: 'Aug 14',
            readTime: '5 min read',
            category: 'Architecture',
            tags: ['flutter'],
          ),
          throwsFormatException,
        );

        expect(
          () => update_tool.generatePublicationItemCode(
            title: 'Title',
            description: 'Desc',
            url: '',
            date: 'Aug 14',
            readTime: '5 min read',
            category: 'Architecture',
            tags: ['flutter'],
          ),
          throwsFormatException,
        );
      });

      test('escapes quotes, backslashes, dollar signs, and multiline values '
          'across all fields', () {
        final code = update_tool.generatePublicationItemCode(
          title: r"Randal's Article: $100 & \path & ${inject}",
          description: "Line 1\nLine 2\r\n'Quotes' and \$dollar",
          url: r'https://dev.to/gde/article?query=$foo',
          date: "Sep '11\n2026",
          readTime:
              "9 min' read"
              '\n'
              r'$fast',
          category: r"State 'Machines'$cat",
          type: r"Special'Type$val",
          tags: ["tag'1", r'$tag2', 'tag\n3'],
        );

        expect(
          code,
          contains(r"title: 'Randal\'s Article: \$100 & \\path & \${inject}',"),
        );
        expect(
          code,
          contains(
            r"description: 'Line 1\nLine 2\r\n\'Quotes\' and \$dollar',",
          ),
        );
        expect(
          code,
          contains(r"url: 'https://dev.to/gde/article?query=\$foo',"),
        );
        expect(code, contains(r"date: 'Sep \'11\n2026',"));
        expect(code, contains(r"readTime: '9 min\' read\n\$fast',"));
        expect(code, contains(r"category: 'State \'Machines\'\$cat',"));
        expect(code, contains(r"type: 'Special\'Type\$val',"));
        expect(code, contains(r"tags: const ['tag\'1', '\$tag2', 'tag\n3'],"));
      });
    });

    group('fetchAllDevToArticles pagination (Issue #483)', () {
      test(
        'paginates per_page=100 across multiple pages until a short page',
        () async {
          final requestedPages = <String?>[];
          final requestedPerPages = <String?>[];
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));

          server.listen((request) async {
            requestedPages.add(request.uri.queryParameters['page']);
            requestedPerPages.add(request.uri.queryParameters['per_page']);
            final page = int.parse(request.uri.queryParameters['page'] ?? '1');
            final items = switch (page) {
              1 => List<Map<String, dynamic>>.generate(
                100,
                (i) => <String, dynamic>{
                  'id': i + 1,
                  'title': 'Article ${i + 1}',
                  'url': 'https://dev.to/gde/article-${i + 1}',
                },
              ),
              2 => <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 101,
                  'title': 'Article 101',
                  'url': 'https://dev.to/gde/article-101',
                },
                <String, dynamic>{
                  'id': 102,
                  'title': 'Article 102',
                  'url': 'https://dev.to/gde/article-102',
                },
              ],
              _ => <Map<String, dynamic>>[],
            };
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(items));
            await request.response.close();
          });

          final articles = await update_tool.fetchAllDevToArticles(
            baseUri: Uri.parse('http://127.0.0.1:${server.port}/articles'),
          );

          expect(requestedPages, equals(['1', '2']));
          expect(requestedPerPages, equals(['100', '100']));
          expect(articles, hasLength(102));
          expect(articles.first['id'], equals(1));
          expect(articles.last['id'], equals(102));
        },
      );
    });
  });
}
