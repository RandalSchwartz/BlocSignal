/// Policy governing which network image URLs an A2UI `Image` component may
/// load.
///
/// By default, only `https` URLs targeting public, non-loopback,
/// non-link-local, non-private hosts are permitted, blocking `http`,
/// `javascript`, `data`, `file`, `ftp`, local/metadata IP ranges (such as
/// `127.0.0.0/8`, `169.254.0.0/16`, `::1`, and `fe80::/10`), private/CGNAT/ULA
/// networks (`0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10`, `172.16.0.0/12`,
/// `192.168.0.0/16`, `fc00::/7`, and NAT64 `64:ff9b::/96`), and non-standard
/// IPv4 notations (octal, shorthand, hex, or 32-bit integer literals).
///
/// ```dart
/// const policy = A2uiImageUrlPolicy();
/// print(policy.isAllowed('https://example.com/photo.png')); // true
/// print(policy.isAllowed('http://169.254.169.254/meta')); // false
/// ```
class A2uiImageUrlPolicy {
  /// Creates an [A2uiImageUrlPolicy].
  const A2uiImageUrlPolicy({
    this.allowedSchemes = const {'https'},
    this.allowLoopback = false,
    this.allowLinkLocal = false,
    this.allowPrivateNetworks = false,
    this.customValidator,
  });

  static final RegExp _decimalDigitsRegex = RegExp(r'^[0-9]+$');
  static final RegExp _hexLiteralRegex = RegExp(r'^0x[0-9a-f]+$');

  /// Allowed URI schemes (matched case-insensitively). Defaults to `{'https'}`.
  final Set<String> allowedSchemes;

  /// Whether loopback hosts (`localhost`, `*.localhost`, `0.0.0.0`,
  /// `127.0.0.0/8`, `::1`, `::`, and embedded loopback addresses) are
  /// permitted.
  final bool allowLoopback;

  /// Whether link-local hosts (`169.254.0.0/16`, `fe80::/10`, and embedded
  /// link-local addresses) are permitted.
  final bool allowLinkLocal;

  /// Whether private, carrier-grade NAT, benchmarking, multicast/reserved, and
  /// transitional networks (non-zero `0.0.0.0/8`, `10.0.0.0/8`,
  /// `100.64.0.0/10`, `172.16.0.0/12`, `192.168.0.0/16`, `198.18.0.0/15`,
  /// `224.0.0.0/4`, `240.0.0.0/4`, IPv6 ULA `fc00::/7`, IPv4-translated
  /// `::ffff:0:0:0/96`, NAT64 `64:ff9b::/96` and `64:ff9b:1::/48`, 6to4
  /// `2002::/16`, and Teredo `2001::/32`) are permitted.
  final bool allowPrivateNetworks;

  /// Optional predicate evaluated after all built-in scheme and host checks
  /// pass.
  final bool Function(Uri uri)? customValidator;

  /// Returns `true` if [rawUrl] parses to a valid URI with an allowed scheme,
  /// a non-empty permitted host, and passes [customValidator] (if provided).
  bool isAllowed(String? rawUrl) {
    if (rawUrl == null) return false;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;

    final scheme = uri.scheme.toLowerCase();
    final schemeAllowed = allowedSchemes.any(
      (allowed) => allowed.toLowerCase() == scheme,
    );
    if (!schemeAllowed) return false;

    final rawHost = uri.host.toLowerCase();
    var hostEnd = rawHost.length;
    while (hostEnd > 0 && rawHost.codeUnitAt(hostEnd - 1) == 0x2e) {
      hostEnd--;
    }
    if (hostEnd == 0) return false;
    final host =
        hostEnd == rawHost.length ? rawHost : rawHost.substring(0, hostEnd);

    if (!_isAllowedHost(host)) return false;

    if (customValidator != null && !customValidator!(uri)) return false;

    return true;
  }

  bool _isAllowedHost(String host) {
    if (host.contains(':')) {
      return _isAllowedIPv6Host(host);
    }

    // Reject percent-encoded hosts and UTF-8 percent-encoded IDNA confusables
    // (such as 127.0.0.%31, %6c%6f%63%61%6c%68%6f%73%74, or 127。0。0。1).
    if (host.contains('%')) return false;

    final ipv4 = _tryParseStrictIPv4(host);
    if (ipv4 != null) {
      return _isAllowedIPv4(ipv4);
    }

    if (!allowLoopback &&
        (host == 'localhost' || host.endsWith('.localhost'))) {
      return false;
    }

    // Reject non-IPv6 hosts whose final dot-separated label is purely numeric
    // or 0x-prefixed hex (blocks octal, shorthand, 32-bit int, and hex SSRF
    // parser differentials such as 0177.0.0.1, 127.1, 2130706433, 0x7f000001).
    final lastLabel = host.split('.').last;
    if (_decimalDigitsRegex.hasMatch(lastLabel) ||
        _hexLiteralRegex.hasMatch(lastLabel)) {
      return false;
    }

    return true;
  }

  bool _isAllowedIPv4(List<int> bytes) {
    final isUnspecified =
        bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0 && bytes[3] == 0;
    final isLoopback = bytes[0] == 127 || isUnspecified;
    if (!allowLoopback && isLoopback) return false;

    final isLinkLocal = bytes[0] == 169 && bytes[1] == 254;
    if (!allowLinkLocal && isLinkLocal) return false;

    if (!allowPrivateNetworks) {
      final isNonZeroThisNetwork = bytes[0] == 0 && !isUnspecified;
      final isRfc1918 = bytes[0] == 10 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168);
      final isCgnat = bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127;
      final isBenchmark = bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19);
      final isMulticastOrReserved = bytes[0] >= 224;
      if (isNonZeroThisNetwork ||
          isRfc1918 ||
          isCgnat ||
          isBenchmark ||
          isMulticastOrReserved) {
        return false;
      }
    }

    return true;
  }

  bool _isAllowedIPv6Host(String host) {
    final ipv6 = _tryParseIPv6(host);
    if (ipv6 == null) return false;

    final isV6Loopback = _isAllZero(ipv6, 0, 15) && ipv6[15] == 1;
    final isV6Unspecified = _isAllZero(ipv6, 0, 16);
    if (isV6Loopback || isV6Unspecified) {
      return allowLoopback;
    }

    final isV6LinkLocal = ipv6[0] == 0xfe && (ipv6[1] & 0xc0) == 0x80;
    if (!allowLinkLocal && isV6LinkLocal) {
      return false;
    }

    final isV6Ula = (ipv6[0] & 0xfe) == 0xfc;
    if (!allowPrivateNetworks && isV6Ula) {
      return false;
    }

    // Check NAT64 64:ff9b::/96 and local-use NAT64 64:ff9b:1::/48.
    final isNat64 = ipv6[0] == 0x00 &&
        ipv6[1] == 0x64 &&
        ipv6[2] == 0xff &&
        ipv6[3] == 0x9b &&
        ((_isAllZero(ipv6, 4, 12)) || (ipv6[4] == 0x00 && ipv6[5] == 0x01));
    if (isNat64) {
      if (!allowPrivateNetworks) return false;
      return _isAllowedIPv4(ipv6.sublist(12, 16));
    }

    // Check IPv4-translated ::ffff:0:0:0/96 (0000:0000:0000:ffff:0000:0000/96).
    final isIpv4Translated = _isAllZero(ipv6, 0, 6) &&
        ipv6[6] == 0xff &&
        ipv6[7] == 0xff &&
        _isAllZero(ipv6, 8, 12);
    if (isIpv4Translated) {
      if (!allowPrivateNetworks) return false;
      return _isAllowedIPv4(ipv6.sublist(12, 16));
    }

    // Check 6to4 2002::/16 (bytes 2..5 hold the embedded IPv4 address).
    if (ipv6[0] == 0x20 && ipv6[1] == 0x02) {
      if (!allowPrivateNetworks) return false;
      return _isAllowedIPv4(ipv6.sublist(2, 6));
    }

    // Check Teredo 2001::/32.
    if (ipv6[0] == 0x20 &&
        ipv6[1] == 0x01 &&
        ipv6[2] == 0x00 &&
        ipv6[3] == 0x00) {
      if (!allowPrivateNetworks) return false;
    }

    // Check IPv4-mapped (::ffff:0:0/96) and IPv4-compatible (::/96).
    final embedded = _extractEmbeddedIPv4(ipv6);
    if (embedded != null) {
      return _isAllowedIPv4(embedded);
    }

    return true;
  }

  static List<int>? _tryParseStrictIPv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;

    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty || part.length > 3) return null;
      if (part.length > 1 && part.startsWith('0')) return null;
      if (!_decimalDigitsRegex.hasMatch(part)) return null;
      final value = int.parse(part);
      if (value > 255) return null;
      octets.add(value);
    }
    return octets;
  }

  static List<int>? _tryParseIPv6(String host) {
    final zoneIndex = host.indexOf('%');
    final stripped = zoneIndex == -1 ? host : host.substring(0, zoneIndex);
    if (stripped.contains('.')) {
      final lastColon = stripped.lastIndexOf(':');
      if (lastColon == -1) return null;
      final suffix = stripped.substring(lastColon + 1);
      if (_tryParseStrictIPv4(suffix) == null) return null;
    }
    try {
      return Uri.parseIPv6Address(stripped);
    } on FormatException {
      return null;
    }
  }

  static List<int>? _extractEmbeddedIPv4(List<int> ipv6) {
    final isMapped =
        _isAllZero(ipv6, 0, 10) && ipv6[10] == 0xff && ipv6[11] == 0xff;
    final isCompatible = _isAllZero(ipv6, 0, 12);
    if (isMapped || isCompatible) {
      return ipv6.sublist(12, 16);
    }
    return null;
  }

  static bool _isAllZero(List<int> bytes, int start, int end) {
    for (var i = start; i < end; i++) {
      if (bytes[i] != 0) return false;
    }
    return true;
  }
}
