/// Escapes a raw string so that it can be safely embedded inside a
/// single-quoted Dart string literal during source code generation.
///
/// Escapes backslashes, dollar signs (preventing unintended string
/// interpolation), single quotes, carriage returns, and newlines.
///
/// ```dart
/// final escaped = escapeDartString(r"Cost: $50 \ 'quote'");
/// // Returns: Cost: \$50 \\ \'quote\'
/// ```
String escapeDartString(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(r'$', r'\$')
    .replaceAll("'", r"\'")
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n');
