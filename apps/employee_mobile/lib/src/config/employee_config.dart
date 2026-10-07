/// Build-time configuration, passed with `--dart-define`.
class EmployeeConfig {
  const EmployeeConfig({required this.apiBaseUri});

  /// Where the Jitan API lives, e.g. `https://jitan.example.com/api/`.
  /// Required; there is no default, so a misconfigured build fails visibly
  /// instead of calling the wrong server.
  final Uri apiBaseUri;

  static const _apiBaseUrl = String.fromEnvironment('JITAN_API_BASE_URL');

  /// `null` when `JITAN_API_BASE_URL` is missing or not an absolute URL.
  static EmployeeConfig? fromEnvironment() => parse(_apiBaseUrl);

  static EmployeeConfig? parse(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return EmployeeConfig(apiBaseUri: uri);
  }
}
