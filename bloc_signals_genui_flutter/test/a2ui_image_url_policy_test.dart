import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('(Issue #423) A2uiImageUrlPolicy', () {
    const defaultPolicy = A2uiImageUrlPolicy();

    test('allows valid https URLs and trims surrounding whitespace', () {
      expect(defaultPolicy.isAllowed('https://example.com/image.png'), isTrue);
      expect(
        defaultPolicy.isAllowed('HTTPS://CDN.EXAMPLE.COM/path/img.webp?w=400'),
        isTrue,
      );
      expect(
        defaultPolicy.isAllowed('  https://example.com/avatar.jpg#top  '),
        isTrue,
      );
      expect(
        defaultPolicy.isAllowed('https://example.com./trailing-dot.png'),
        isTrue,
      );
    });

    test('rejects empty, whitespace-only, and malformed URLs', () {
      expect(defaultPolicy.isAllowed(''), isFalse);
      expect(defaultPolicy.isAllowed('   \t\n  '), isFalse);
      expect(defaultPolicy.isAllowed('not a valid url'), isFalse);
      expect(defaultPolicy.isAllowed('://missing-scheme.com/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://'), isFalse);
      expect(defaultPolicy.isAllowed('https:///no-host.png'), isFalse);
    });

    test('rejects non-https schemes by default', () {
      expect(defaultPolicy.isAllowed('http://example.com/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('javascript:alert(1)'), isFalse);
      expect(
        defaultPolicy.isAllowed('data:image/png;base64,iVBORw0KGgo='),
        isFalse,
      );
      expect(defaultPolicy.isAllowed('file:///etc/passwd'), isFalse);
      expect(defaultPolicy.isAllowed('ftp://example.com/a.png'), isFalse);
    });

    test('rejects loopback hosts by default', () {
      expect(defaultPolicy.isAllowed('https://localhost/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://LOCALHOST./a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://sub.localhost/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://0.0.0.0/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://127.0.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://127.255.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://[::1]/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://[::]/a.png'), isFalse);
      expect(
        defaultPolicy.isAllowed('https://[::ffff:127.0.0.1]/a.png'),
        isFalse,
      );
      expect(
        defaultPolicy.isAllowed('https://[::ffff:0.0.0.0]/a.png'),
        isFalse,
      );
    });

    test('rejects link-local hosts by default', () {
      expect(
        defaultPolicy.isAllowed('https://169.254.169.254/latest/meta-data'),
        isFalse,
      );
      expect(defaultPolicy.isAllowed('https://169.254.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://[fe80::1]/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://[febf::1]/a.png'), isFalse);
      expect(
        defaultPolicy.isAllowed('https://[::ffff:169.254.169.254]/a.png'),
        isFalse,
      );
    });

    test('allows public IPv4 and IPv6 addresses', () {
      expect(defaultPolicy.isAllowed('https://93.184.216.34/a.png'), isTrue);
      expect(
        defaultPolicy.isAllowed('https://[2606:4700:4700::1111]/a.png'),
        isTrue,
      );
      expect(defaultPolicy.isAllowed('https://169.253.0.1/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://[fe7f::1]/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://[fec0::1]/a.png'), isTrue);
    });

    test('supports custom allowedSchemes case-insensitively', () {
      const policy = A2uiImageUrlPolicy(allowedSchemes: {'HTTPS', 'Http'});

      expect(policy.isAllowed('http://example.com/a.png'), isTrue);
      expect(policy.isAllowed('https://example.com/a.png'), isTrue);
      expect(policy.isAllowed('ftp://example.com/a.png'), isFalse);
      expect(policy.isAllowed('http://127.0.0.1/a.png'), isFalse);
    });

    test('allowLoopback permits loopback hosts while still blocking link-local',
        () {
      const policy = A2uiImageUrlPolicy(allowLoopback: true);

      expect(policy.isAllowed('https://localhost/a.png'), isTrue);
      expect(policy.isAllowed('https://sub.localhost/a.png'), isTrue);
      expect(policy.isAllowed('https://127.0.0.1:8080/a.png'), isTrue);
      expect(policy.isAllowed('https://0.0.0.0/a.png'), isTrue);
      expect(policy.isAllowed('https://[::1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::ffff:127.0.0.1]/a.png'), isTrue);

      expect(policy.isAllowed('https://169.254.169.254/a.png'), isFalse);
      expect(policy.isAllowed('https://[fe80::1]/a.png'), isFalse);
    });

    test(
        'allowLinkLocal permits link-local hosts while still blocking loopback',
        () {
      const policy = A2uiImageUrlPolicy(allowLinkLocal: true);

      expect(policy.isAllowed('https://169.254.169.254/a.png'), isTrue);
      expect(policy.isAllowed('https://[fe80::1]/a.png'), isTrue);
      expect(
        policy.isAllowed('https://[::ffff:169.254.169.254]/a.png'),
        isTrue,
      );

      expect(policy.isAllowed('https://127.0.0.1/a.png'), isFalse);
      expect(policy.isAllowed('https://localhost/a.png'), isFalse);
    });

    test('customValidator runs only after built-in checks pass', () {
      var validatorCalled = false;
      final policy = A2uiImageUrlPolicy(
        customValidator: (uri) {
          validatorCalled = true;
          return uri.host == 'cdn.example.com';
        },
      );

      expect(policy.isAllowed('http://cdn.example.com/a.png'), isFalse);
      expect(validatorCalled, isFalse);

      expect(policy.isAllowed('https://other.example.com/a.png'), isFalse);
      expect(validatorCalled, isTrue);

      expect(policy.isAllowed('https://cdn.example.com/a.png'), isTrue);
    });
  });
}
