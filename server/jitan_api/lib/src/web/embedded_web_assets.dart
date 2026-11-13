/// The HR website, built into the executable (DEPLOYMENT_CONFIGURATION:
/// executable-only updates). Each entry is a file of `apps/admin_web`'s web
/// build: its path → its bytes, gzip-compressed and base64-encoded.
///
/// Empty in the repository: `dart run tool/build_release.dart` fills it for
/// the release it compiles and puts it back afterwards. Empty means the
/// server serves only the API.
const embeddedWebAssets = <String, String>{};
