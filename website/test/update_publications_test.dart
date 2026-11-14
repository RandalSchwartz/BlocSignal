import 'package:blocsignal_website/src/models/publication_generator.dart';
import 'package:blocsignal_website/src/models/publication_item.dart';
import 'package:test/test.dart';

void main() {
  group('PublicationItem (Issue #412)', () {
    test('isHttps returns true for https:// URLs and false otherwise', () {
      const valid = PublicationItem(
        title: 'Title',
        description: 'Description',
        url: 'https://dev.to/gde/example',
        date: 'Nov 7',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: ['dart'],
      );
      const httpUrl = PublicationItem(
        title: 'Title',
        description: 'Description',
        url: 'http://dev.to/gde/example',
        date: 'Nov 7',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: [],
      );
      const jsUrl = PublicationItem(
        title: 'Title',
        description: 'Description',
        url: 'javascript:alert(1)',
        date: 'Nov 7',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: [],
      );
      const emptyUrl = PublicationItem(
        title: 'Title',
        description: 'Description',
        url: '',
        date: 'Nov 7',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: [],
      );

      expect(valid.isHttps, isTrue);
      expect(httpUrl.isHttps, isFalse);
      expect(jsUrl.isHttps, isFalse);
      expect(emptyUrl.isHttps, isFalse);
    });
  });

  group('validateHttpsUrl (Issue #412)', () {
    test('accepts valid https:// URLs and trims surrounding whitespace', () {
      expect(
        validateHttpsUrl('https://dev.to/gde/post'),
        equals('https://dev.to/gde/post'),
      );
      expect(
        validateHttpsUrl('  https://blocsignal.dev/docs  '),
        equals('https://blocsignal.dev/docs'),
      );
    });

    test('rejects null, non-String, empty, http://, and malformed URLs', () {
      expect(() => validateHttpsUrl(null), throwsFormatException);
      expect(() => validateHttpsUrl(123), throwsFormatException);
      expect(() => validateHttpsUrl(''), throwsFormatException);
      expect(() => validateHttpsUrl('   '), throwsFormatException);
      expect(
        () => validateHttpsUrl('http://dev.to/gde/post'),
        throwsFormatException,
      );
      expect(
        () => validateHttpsUrl('https:///missing-host'),
        throwsFormatException,
      );
      expect(() => validateHttpsUrl('not a url'), throwsFormatException);
    });
  });

  group('formatTagsCode (Issue #412)', () {
    test('returns const [] for null or empty list', () {
      expect(formatTagsCode(null), equals('const []'));
      expect(formatTagsCode(<dynamic>[]), equals('const []'));
    });

    test('escapes special characters in tags and formats const list', () {
      expect(
        formatTagsCode(['flutter', "it's", r'a\b', r'$var']),
        equals(r"const ['flutter', 'it\'s', 'a\\b', '\$var']"),
      );
    });
  });

  group('generatePublicationItemCode (Issue #412)', () {
    test('escapes single quotes, dollar signs, backslashes, CR, and LF', () {
      final code = generatePublicationItemCode(
        title: "It's \$100 \\ test",
        description: 'Line1\r\nLine2',
        url: 'https://dev.to/gde/test',
        date: 'Nov 7',
        readTime: '5 min read',
        category: 'Architecture',
        tags: ['dart', "x'y"],
      );

      expect(code, contains(r"title: 'It\'s \$100 \\ test',"));
      expect(code, contains(r"description: 'Line1\r\nLine2',"));
      expect(code, contains("url: 'https://dev.to/gde/test',"));
      expect(code, contains(r"tags: const ['dart', 'x\'y'],"));
    });

    test('rejects non-HTTPS URLs with FormatException', () {
      expect(
        () => generatePublicationItemCode(
          title: 'Insecure',
          description: 'Desc',
          url: 'http://dev.to/gde/test',
          date: 'Nov 7',
          readTime: '5 min read',
          category: 'Architecture',
        ),
        throwsFormatException,
      );
    });
  });

  group('generatePublicationsDataFile (Issue #412)', () {
    test('generates header, model import, and const List<PublicationItem> publications', () {
      final generated = generatePublicationsDataFile([
        <String, dynamic>{
          'title': 'Flutter & Jaspr Signal Architecture',
          'description': "Deep dive into \$state and 'signals'.",
          'canonical_url': 'https://dev.to/gde/flutter-jaspr',
          'readable_publish_date': 'Nov 7',
          'reading_time_minutes': 5,
          'tag_list': ['flutter', 'dart'],
        },
        <String, dynamic>{
          'title': 'State Machines in Dart',
          'description': 'Finite state machines.',
          'url': 'https://dev.to/gde/fsm',
          'published_at': '2026-08-08T12:00:00Z',
          'reading_time_minutes': 4,
          'tag_list': ['dart'],
        },
      ]);

      expect(
        generated,
        startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND'),
      );
      expect(generated, contains("import '../models/publication_item.dart';"));
      expect(
        generated,
        contains('const List<PublicationItem> publications = ['),
      );
      expect(generated, contains("category: 'Flutter & Jaspr',"));
      expect(generated, contains("category: 'State Machines',"));
      expect(generated, contains("date: 'Aug 8',"));
    });
  });
}
