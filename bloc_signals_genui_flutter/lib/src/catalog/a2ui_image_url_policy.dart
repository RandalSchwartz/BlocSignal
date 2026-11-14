/// Policy governing which network image URLs an A2UI `Image` component may
/// load.
///
/// By default, only `https` URLs targeting non-loopback, non-link-local hosts
/// are permitted, blocking `http`, `javascript`, `data`, `file`, `ftp`, and
/// local/metadata IP ranges (such as `127.0.0.0/8`, `169.254.0.0/16`, `::1`,
/// and `fe80::/10`).
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
    this.customValidator,
  });

  /// Allowed URI schemes (matched case-insensitively). Defaults to `{'https'}`.
  final Set<String> allowedSchemes;

  /// Whether loopback hosts (`localhost`, `*.localhost`, `0.0.0.0`,
  /// `127.0.0.0/8`, `::1`, `::`, and IPv4-mapped loopback addresses) are
  /// permitted.
  final bool allowLoopback;

  /// Whether link-local hosts (`169.254.0.0/16`, `fe80::/10`, and IPv4-mapped
  /// link-local addresses) are permitted.
  final bool allowLinkLocal;

  /// Optional predicate evaluated after all built-in scheme and host checks
  /// pass.
  final bool Function(Uri uri)? customValidator;

  /// Returns `true` if [rawUrl] parses to a valid URI with an allowed scheme,
  /// a non-empty permitted host, and passes [customValidator] (if provided).
  bool isAllowed(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;

    final scheme = uri.scheme.toLowerCase();
    final schemeAllowed = allowedSchemes.any(
      (allowed) => allowed.toLowerCase() == scheme,
    );
    if (!schemeAllowed) return false;

    var host = uri.host.toLowerCase();
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) return false;

    if (!allowLoopback && _isLoopbackHost(host)) return false;
    if (!allowLinkLocal && _isLinkLocalHost(host)) return false;

    if (customValidator != null && !customValidator!(uri)) return false;

    return true;
  }

  static bool _isLoopbackHost(String host) {
    if (host == 'localhost' || host.endsWith('.localhost')) {
      return true;
    }

    final ipv4 = _tryParseIPv4(host);
    if (ipv4 != null) {
      return _isLoopbackIPv4(ipv4);
    }

    final ipv6 = _tryParseIPv6(host);
    if (ipv6 != null) {
      final isV6Loopback = _isAllZero(ipv6, 0, 15) && ipv6[15] == 1;
      final isV6Unspecified = _isAllZero(ipv6, 0, 16);
      if (isV6Loopback || isV6Unspecified) return true;

      final mapped = _extractIPv4Mapped(ipv6);
      if (mapped != null) return _isLoopbackIPv4(mapped);
    }

    return false;
  }

  static bool _isLinkLocalHost(String host) {
    final ipv4 = _tryParseIPv4(host);
    if (ipv4 != null) {
      return _isLinkLocalIPv4(ipv4);
    }

    final ipv6 = _tryParseIPv6(host);
    if (ipv6 != null) {
      if (ipv6[0] == 0xfe && (ipv6[1] & 0xc0) == 0x80) {
        return true;
      }

      final mapped = _extractIPv4Mapped(ipv6);
      if (mapped != null) return _isLinkLocalIPv4(mapped);
    }

    return false;
  }

  static bool _isLoopbackIPv4(List<int> bytes) {
    return bytes[0] == 127 ||
        (bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0 && bytes[3] == 0);
  }

  static bool _isLinkLocalIPv4(List<int> bytes) {
    return bytes[0] == 169 && bytes[1] == 254;
  }

  static List<int>? _tryParseIPv4(String host) {
    try {
      return Uri.parseIPv4Address(host);
    } on FormatException {
      return null;
    }
  }

  static List<int>? _tryParseIPv6(String host) {
    if (!host.contains(':')) return null;
    final zoneIndex = host.indexOf('%');
    final stripped = zoneIndex == -1 ? host : host.substring(0, zoneIndex);
    try {
      return Uri.parseIPv6Address(stripped);
    } on FormatException {
      return null;
    }
  }

  static List<int>? _extractIPv4Mapped(List<int> ipv6) {
    if (_isAllZero(ipv6, 0, 10) && ipv6[10] == 0xff && ipv6[11] == 0xff) {
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
