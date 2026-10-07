import 'config_exception.dart';

/// Where the server is running. Controls which development-only mechanisms
/// may be enabled.
enum AppEnvironment {
  development,
  test,
  production;

  /// Parses `JITAN_ENV`. A missing or empty value means [production], so
  /// development mechanisms can never switch on by omission.
  static AppEnvironment parse(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return AppEnvironment.production;
    for (final environment in AppEnvironment.values) {
      if (environment.name == value) return environment;
    }
    throw ConfigException(
      'JITAN_ENV must be one of development, test, production; got "$raw".',
    );
  }

  bool get allowsDevelopmentMechanisms => this != AppEnvironment.production;
}
