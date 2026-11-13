// Builds what IT installs (DEPLOYMENT_CONFIGURATION), into build/release/:
//
// - jitan-server: the Linux x64 API with the HR website built in, so the
//   website and the API share one address and an update stays one file.
// - jitan-first-hr: sets up the very first HR person in one step (Linux x64).
// - jitan-employee.apk: the employee app, talking to --api-url.
// - SHA256SUMS: to check the files arrived whole.
//
//   dart run tool/build_release.dart --api-url https://10.1.101.65:8080 [--trust-cert agapp05.crt] [--only-apk]
//
// --trust-cert: the server's certificate when no public authority issued it
// (IT's is self-signed). Its SHA-256 fingerprint goes into the APK
// (JITAN_API_CERT_SHA256), which then accepts exactly that certificate, and
// only from the API's address (CertificatePin). The fingerprint is printed, to
// confirm with IT. A new certificate on the server needs a new APK.
//
// --only-apk: builds the APK alone; the server and the website stay as built.
//
// The HR website reaches the API on its own address (`/`). A Mapbox token for
// its map comes from the JITAN_MAPBOX_TOKEN environment variable, never from
// the command line or the repository; without it the map says it is not set up.
//
// lib/src/web/embedded_web_assets.dart is filled for the compile and put back
// to its empty form afterwards, also when a step fails.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _assetsFile = 'lib/src/web/embedded_web_assets.dart';

Future<void> main(List<String> args) async {
  try {
    await _build(args);
  } on _StepFailed catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  }
}

Future<void> _build(List<String> args) async {
  final apiUrl = _option(args, '--api-url');
  if (apiUrl == null || Uri.tryParse(apiUrl)?.scheme != 'https') {
    stderr.writeln('Usage: dart run tool/build_release.dart --api-url https://<server>:<port> [--trust-cert <file.crt>] [--only-apk]');
    exit(64);
  }
  final certPath = _option(args, '--trust-cert');
  final trustCert = certPath == null ? null : File(certPath);
  if (args.contains('--trust-cert') && (trustCert == null || !trustCert.existsSync())) {
    stderr.writeln('--trust-cert needs the certificate file (PEM).');
    exit(64);
  }

  final server = Directory.current;
  final root = server.parent.parent;
  final adminWeb = Directory('${root.path}/apps/admin_web');
  final mobile = Directory('${root.path}/apps/employee_mobile');
  final out = Directory('${server.path}/build/release')..createSync(recursive: true);

  if (!args.contains('--only-apk')) {
    await _serverAndWebsite(server, adminWeb, out, Platform.environment['JITAN_MAPBOX_TOKEN']?.trim() ?? '');
  }

  stdout.writeln('4/4 Employee app');
  final pin = trustCert == null ? null : _fingerprint(trustCert);
  if (pin != null) stdout.writeln('   pinned to the certificate with SHA-256 $pin, for ${Uri.parse(apiUrl).host} only');
  await _run('flutter', [
    'build',
    'apk',
    '--release',
    '--dart-define=JITAN_API_BASE_URL=$apiUrl',
    if (pin != null) '--dart-define=JITAN_API_CERT_SHA256=$pin',
  ], mobile);
  File('${mobile.path}/build/app/outputs/flutter-apk/app-release.apk').copySync('${out.path}/jitan-employee.apk');

  final sums = [
    for (final name in ['jitan-server', 'jitan-first-hr', 'jitan-employee.apk'])
      if (File('${out.path}/$name').existsSync()) '${sha256.convert(File('${out.path}/$name').readAsBytesSync())}  $name',
  ];
  File('${out.path}/SHA256SUMS').writeAsStringSync('${sums.join('\n')}\n');
  stdout.writeln('Done: ${out.path}\n${sums.join('\n')}');
}

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i < 0 || i + 1 >= args.length ? null : args[i + 1];
}

/// The HR website, built into the Linux server, and the first-HR command.
Future<void> _serverAndWebsite(Directory server, Directory adminWeb, Directory out, String mapbox) async {
  stdout.writeln('1/4 HR website');
  await _run(
    'flutter',
    [
      'build',
      'web',
      '--release',
      '--no-web-resources-cdn',
      '--dart-define=JITAN_API_BASE_URL=/',
      if (mapbox.isNotEmpty) '--dart-define=JITAN_MAPBOX_TOKEN=$mapbox',
    ],
    adminWeb,
    secret: mapbox,
  );
  if (mapbox.isEmpty) stdout.writeln('   (no JITAN_MAPBOX_TOKEN: the Locations map will say it is not set up)');

  final stub = File(_assetsFile).readAsStringSync();
  try {
    stdout.writeln('2/4 Built into the server');
    File(_assetsFile).writeAsStringSync(_embedded(Directory('${adminWeb.path}/build/web'), stub));

    stdout.writeln('3/4 Linux x64 executables');
    for (final (source, name) in [('bin/server.dart', 'jitan-server'), ('bin/first_hr.dart', 'jitan-first-hr')]) {
      await _run('dart', ['compile', 'exe', '--target-os', 'linux', '--target-arch', 'x64', source, '-o', '${out.path}/$name'], server);
    }
  } finally {
    File(_assetsFile).writeAsStringSync(stub);
  }
}

/// The SHA-256 fingerprint of a PEM certificate, as `AB:CD:…`.
String _fingerprint(File certificate) {
  final pem = certificate.readAsStringSync();
  final der = base64.decode(const LineSplitter().convert(pem).where((l) => l.isNotEmpty && !l.startsWith('-----')).join());
  return _colons(sha256.convert(der).toString());
}

String _colons(String hex) => [for (var i = 0; i < hex.length; i += 2) hex.substring(i, i + 2).toUpperCase()].join(':');

/// The assets file with every file of [web], gzip-compressed and base64-encoded.
/// Debug symbols (`*.symbols`) stay out: browsers never ask for them.
String _embedded(Directory web, String stub) {
  final entries = <String>[];
  final files = web.listSync(recursive: true).whereType<File>().where((f) => !f.path.endsWith('.symbols')).toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final path = file.path.substring(web.path.length + 1).replaceAll(r'\', '/');
    entries.add("  '$path': '${base64.encode(gzip.encode(file.readAsBytesSync()))}',");
  }
  final header = stub.substring(0, stub.indexOf('const embeddedWebAssets'));
  return '${header}const embeddedWebAssets = <String, String>{\n${entries.join('\n')}\n};\n';
}

/// Runs [command] in [directory]; stops the build when it fails. [secret]
/// never appears in what is printed.
Future<void> _run(String command, List<String> args, Directory directory, {String secret = ''}) async {
  final process = await Process.start(command, args, workingDirectory: directory.path, runInShell: true);
  String clean(String s) => secret.isEmpty ? s : s.replaceAll(secret, '***');
  process.stdout.transform(utf8.decoder).listen((s) => stdout.write(clean(s)));
  process.stderr.transform(utf8.decoder).listen((s) => stderr.write(clean(s)));
  final code = await process.exitCode;
  if (code != 0) throw _StepFailed('$command ${args.first} failed ($code)');
}

class _StepFailed implements Exception {
  _StepFailed(this.message);

  final String message;

  @override
  String toString() => message;
}
