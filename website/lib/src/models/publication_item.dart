/// Metadata for a published article or video resource displayed on the
/// publications page.
class const PublicationItem({
  /// The article or video title.
  required final String title,

  /// A short summary of the publication.
  required final String description,

  /// The canonical external HTTPS URL for the publication.
  required final String url,

  /// The human-readable publication date (for example `'Nov 7'`).
  required final String date,

  /// The estimated reading time (for example `'5 min read'`).
  required final String readTime,

  /// The primary topic category used for filtering.
  required final String category,

  /// The publication format (for example `'Article'`).
  required final String type,

  /// Topic tags associated with the publication.
  required final List<String> tags,
}) {
  /// Whether [url] uses the `https://` scheme.
  bool get isHttps => url.startsWith('https://');
}
