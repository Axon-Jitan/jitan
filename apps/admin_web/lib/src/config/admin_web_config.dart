/// Build-time configuration, passed with `--dart-define`.
class AdminWebConfig {
  const AdminWebConfig({required this.apiBaseUri});

  /// Where the Jitan API lives. Required; there is no default, so a
  /// misconfigured build fails visibly instead of calling the wrong server.
  ///
  /// Absolute (`http://127.0.0.1:8080`) or relative to the page
  /// (`/api`, for same-origin hosting behind Nginx).
  final Uri apiBaseUri;

  static const _apiBaseUrl = String.fromEnvironment('JITAN_API_BASE_URL');

  /// `null` when `JITAN_API_BASE_URL` was not provided.
  static AdminWebConfig? fromEnvironment({Uri? pageUri}) {
    final raw = _apiBaseUrl.trim();
    if (raw.isEmpty) return null;
    final withSlash = raw.endsWith('/') ? raw : '$raw/';
    return AdminWebConfig(apiBaseUri: (pageUri ?? Uri.base).resolve(withSlash));
  }
}
