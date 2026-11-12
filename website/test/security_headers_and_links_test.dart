import 'package:blocsignal_website/src/pages/publications_page.dart';
import 'package:test/test.dart';

void main() {
  group('Security Headers & External Link Hardening (Issue #426)', () {
    test('(Issue #426: F02) PublicationsPage enforces https:// schemes on all PublicationItem entries', () {
      expect(PublicationsPage.allPublications, isNotEmpty);
      for (final pub in PublicationsPage.allPublications) {
        expect(
          pub.isHttps,
          isTrue,
          reason: 'Publication "${pub.title}" must have an https scheme',
        );
        expect(
          pub.url,
          startsWith('https://'),
          reason: 'Publication "${pub.title}" URL must start with https://',
        );
        final parsed = Uri.tryParse(pub.url);
        expect(
          parsed,
          isNotNull,
          reason: 'Publication "${pub.title}" URL must be valid URI',
        );
        expect(
          parsed!.scheme,
          equals('https'),
          reason: 'Publication "${pub.title}" scheme must be https',
        );
      }

      // Verify PublicationItem.isHttps negative branches
      const insecureHttpPub = PublicationItem(
        title: 'Insecure Article',
        description: 'Description',
        url: 'http://insecure.example.com/article',
        date: 'Nov 12, 2026',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: ['security'],
      );
      expect(insecureHttpPub.isHttps, isFalse);

      const insecureFtpPub = PublicationItem(
        title: 'FTP Link',
        description: 'Description',
        url: 'ftp://ftp.example.com/file',
        date: 'Nov 12, 2026',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: ['security'],
      );
      expect(insecureFtpPub.isHttps, isFalse);

      const javascriptPub = PublicationItem(
        title: 'JS Exploit',
        description: 'Description',
        url: 'javascript:alert(1)',
        date: 'Nov 12, 2026',
        readTime: '5 min read',
        category: 'Architecture',
        type: 'Article',
        tags: ['security'],
      );
      expect(javascriptPub.isHttps, isFalse);
    });
  });
}
