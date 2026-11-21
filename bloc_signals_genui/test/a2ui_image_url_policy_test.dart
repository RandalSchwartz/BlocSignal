import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:test/test.dart';

void main() {
  group('(Issue #423 / #463) A2uiImageUrlPolicy', () {
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
      expect(defaultPolicy.isAllowed('https://123.example.com/a.png'), isTrue);
      expect(
        defaultPolicy.isAllowed('https://v2.0x1.example.com/a.png'),
        isTrue,
      );
    });

    test('rejects null, empty, whitespace-only, and malformed URLs', () {
      expect(defaultPolicy.isAllowed(null), isFalse);
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
      expect(
        defaultPolicy.isAllowed('https://[::127.0.0.1]/a.png'),
        isFalse,
      );
      expect(
        defaultPolicy.isAllowed('https://[64:ff9b::127.0.0.1]/a.png'),
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
      expect(
        defaultPolicy.isAllowed('https://[fe80::1%25eth0]/a.png'),
        isFalse,
      );
      expect(defaultPolicy.isAllowed('https://[febf::1]/a.png'), isFalse);
      expect(
        defaultPolicy.isAllowed('https://[::ffff:169.254.169.254]/a.png'),
        isFalse,
      );
      expect(
        defaultPolicy.isAllowed('https://[::169.254.169.254]/a.png'),
        isFalse,
      );
      expect(
        defaultPolicy.isAllowed('https://[64:ff9b::169.254.169.254]/a.png'),
        isFalse,
      );
    });

    test('rejects IPv4 SSRF parser differentials (octal, shorthand, hex, int)',
        () {
      expect(defaultPolicy.isAllowed('https://0177.0.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://012.0.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://127.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://10.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://2130706433/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://2852039166/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://0x7f000001/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://0x7f.0.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://127.0.0.0x1/a.png'), isFalse);
      expect(
        defaultPolicy.isAllowed('https://[::ffff:0177.0.0.1]/a.png'),
        isFalse,
      );
    });

    test('rejects private, CGNAT, ULA, and NAT64 networks by default', () {
      // Non-zero 0.0.0.0/8 ("this network")
      expect(defaultPolicy.isAllowed('https://0.0.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://0.255.255.255/a.png'), isFalse);

      // RFC 1918
      expect(defaultPolicy.isAllowed('https://10.0.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://10.255.255.254/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://172.16.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://172.31.255.254/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://192.168.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://192.168.1.1/a.png'), isFalse);

      // CGNAT 100.64.0.0/10
      expect(defaultPolicy.isAllowed('https://100.64.0.1/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://100.127.255.254/a.png'), isFalse);

      // IPv6 ULA fc00::/7
      expect(defaultPolicy.isAllowed('https://[fc00::1]/a.png'), isFalse);
      expect(defaultPolicy.isAllowed('https://[fd12:3456::1]/a.png'), isFalse);

      // IPv4-mapped / IPv4-compatible private ranges
      expect(
        defaultPolicy.isAllowed('https://[::ffff:10.0.0.1]/a.png'),
        isFalse,
      );
      expect(
        defaultPolicy.isAllowed('https://[::ffff:192.168.1.1]/a.png'),
        isFalse,
      );
      expect(defaultPolicy.isAllowed('https://[::10.0.0.1]/a.png'), isFalse);

      // NAT64 64:ff9b::/96
      expect(
        defaultPolicy.isAllowed('https://[64:ff9b::93.184.216.34]/a.png'),
        isFalse,
      );
      expect(
        defaultPolicy.isAllowed('https://[64:ff9b::10.0.0.1]/a.png'),
        isFalse,
      );
    });

    test('allows public IPv4 and IPv6 addresses including boundary peers', () {
      expect(defaultPolicy.isAllowed('https://93.184.216.34/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://100.63.255.255/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://100.128.0.0/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://172.15.255.255/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://172.32.0.0/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://192.167.255.255/a.png'), isTrue);
      expect(defaultPolicy.isAllowed('https://192.169.0.0/a.png'), isTrue);
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

    test(
        'allowLoopback permits loopback hosts while still blocking link-local and private',
        () {
      const policy = A2uiImageUrlPolicy(allowLoopback: true);

      expect(policy.isAllowed('https://localhost/a.png'), isTrue);
      expect(policy.isAllowed('https://sub.localhost/a.png'), isTrue);
      expect(policy.isAllowed('https://127.0.0.1:8080/a.png'), isTrue);
      expect(policy.isAllowed('https://0.0.0.0/a.png'), isTrue);
      expect(policy.isAllowed('https://[::1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::ffff:127.0.0.1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::127.0.0.1]/a.png'), isTrue);

      // Non-zero 0.0.0.0/8 is private/unspecified network, not loopback.
      expect(policy.isAllowed('https://0.0.0.1/a.png'), isFalse);
      // Malformed leading-zero embedded IPv4 must still be rejected.
      expect(policy.isAllowed('https://[::ffff:0177.0.0.1]/a.png'), isFalse);

      expect(policy.isAllowed('https://169.254.169.254/a.png'), isFalse);
      expect(policy.isAllowed('https://[fe80::1]/a.png'), isFalse);
      expect(policy.isAllowed('https://10.0.0.1/a.png'), isFalse);
    });

    test(
        'allowLinkLocal permits link-local hosts while still blocking loopback and private',
        () {
      const policy = A2uiImageUrlPolicy(allowLinkLocal: true);

      expect(policy.isAllowed('https://169.254.169.254/a.png'), isTrue);
      expect(policy.isAllowed('https://[fe80::1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[fe80::1%25eth0]/a.png'), isTrue);
      expect(
        policy.isAllowed('https://[::ffff:169.254.169.254]/a.png'),
        isTrue,
      );
      expect(
        policy.isAllowed('https://[::169.254.169.254]/a.png'),
        isTrue,
      );

      expect(policy.isAllowed('https://127.0.0.1/a.png'), isFalse);
      expect(policy.isAllowed('https://localhost/a.png'), isFalse);
      expect(policy.isAllowed('https://192.168.1.1/a.png'), isFalse);
    });

    test(
        'allowPrivateNetworks permits RFC 1918, CGNAT, ULA, 0/8, and NAT64 while still blocking loopback and link-local',
        () {
      const policy = A2uiImageUrlPolicy(allowPrivateNetworks: true);

      expect(policy.isAllowed('https://0.0.0.1/a.png'), isTrue);
      expect(policy.isAllowed('https://10.0.0.1/a.png'), isTrue);
      expect(policy.isAllowed('https://100.64.0.1/a.png'), isTrue);
      expect(policy.isAllowed('https://172.16.0.1/a.png'), isTrue);
      expect(policy.isAllowed('https://192.168.1.1/a.png'), isTrue);
      expect(policy.isAllowed('https://[fc00::1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[fd12:3456::1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::ffff:10.0.0.1]/a.png'), isTrue);
      expect(policy.isAllowed('https://[::10.0.0.1]/a.png'), isTrue);
      expect(
        policy.isAllowed('https://[64:ff9b::93.184.216.34]/a.png'),
        isTrue,
      );
      expect(policy.isAllowed('https://[64:ff9b::10.0.0.1]/a.png'), isTrue);

      // Loopback and link-local remain blocked even when allowPrivateNetworks is true.
      expect(policy.isAllowed('https://127.0.0.1/a.png'), isFalse);
      expect(policy.isAllowed('https://0.0.0.0/a.png'), isFalse);
      expect(policy.isAllowed('https://169.254.169.254/a.png'), isFalse);
      expect(
        policy.isAllowed('https://[64:ff9b::169.254.169.254]/a.png'),
        isFalse,
      );
      expect(
        policy.isAllowed('https://[64:ff9b::127.0.0.1]/a.png'),
        isFalse,
      );
      // Malformed SSRF differentials remain blocked even with allowPrivateNetworks.
      expect(policy.isAllowed('https://0177.0.0.1/a.png'), isFalse);
      expect(policy.isAllowed('https://[::ffff:0177.0.0.1]/a.png'), isFalse);
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
