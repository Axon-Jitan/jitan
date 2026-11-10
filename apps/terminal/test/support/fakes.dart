import 'package:flutter/widgets.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:terminal/src/app/terminal_app.dart';
import 'package:terminal/src/device/terminal_store.dart';
import 'package:terminal/src/flow/terminal_controller.dart';

const info = TerminalInfo(id: 1, name: 'Almeco Reception', canScan: true);

const towers = MyProject(id: 1, name: 'Cooling towers', companyId: 1, companyName: 'Almeco', isClient: true, isCurrent: true);
const workshop = MyProject(id: 2, name: 'Clean the workshop', companyId: 1, companyName: 'Almeco', isClient: false, isCurrent: true);

TerminalScanResult scanResult(TerminalScanOutcome outcome, {MyProject? project = towers, String? name = 'Disan'}) => TerminalScanResult(
  outcome: outcome,
  timeLocal: '09:42',
  firstName: name,
  current: project == null
      ? null
      : CurrentActivity(kind: ActivityKind.clientOnSite, since: DateTime.utc(2026, 11, 2, 8), project: project),
  projects: const [towers, workshop],
);

ApiClientException refused(int status, String code) =>
    ApiClientException.server(status, ApiError(code: code, message: 'x'));

class FakeStore implements TerminalStore {
  FakeStore({this.saved});

  String? saved;

  @override
  Future<String?> token() async => saved;

  @override
  Future<void> saveToken(String token) async => saved = token;

  @override
  Future<void> clearToken() async => saved = null;

  @override
  Future<String> deviceId() async => 'tablet-1';

  @override
  Future<String?> deviceName() async => 'Samsung Tab A9';
}

class FakeDeviceApi implements TerminalDeviceApi {
  TerminalInfo info_ = info;
  TerminalScanResult result = scanResult(TerminalScanOutcome.checkedIn);
  ApiClientException? failMe;
  ApiClientException? failScan;
  ApiClientException? failPair;
  ApiClientException? failSwitch;
  final scans = <TerminalScanRequest>[];
  final switches = <TerminalSwitchRequest>[];
  final pairs = <TerminalPairRequest>[];

  @override
  Future<TerminalInfo> me() async {
    if (failMe case final failure?) throw failure;
    return info_;
  }

  @override
  Future<TerminalPairResponse> pair(TerminalPairRequest request) async {
    pairs.add(request);
    if (failPair case final failure?) throw failure;
    return TerminalPairResponse(token: '1.secret', terminal: info_);
  }

  @override
  Future<TerminalScanResult> scan(TerminalScanRequest request) async {
    scans.add(request);
    if (failScan case final failure?) throw failure;
    return result;
  }

  @override
  Future<TerminalScanResult> switchTo(TerminalSwitchRequest request) async {
    switches.add(request);
    if (failSwitch case final failure?) throw failure;
    return result;
  }
}

class FakeLanguagesApi implements LanguagesApi {
  @override
  Future<List<Language>> listLanguages() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The app with a camera a test can read codes through.
class Harness {
  Harness({String? token}) : store = FakeStore(saved: token);

  final api = FakeDeviceApi();
  final FakeStore store;
  DateTime now = DateTime(2026, 11, 2, 9, 42);
  String? token;
  ValueChanged<String>? read;

  late final controller = TerminalController(api: api, store: store, setToken: (value) => token = value, clock: () => now);

  Widget app() {
    final languages = FakeLanguagesApi();
    return TerminalApp(
      controller: controller,
      languagesApi: languages,
      translations: TranslationService(languages),
      clock: () => now,
      camera: (onRead) {
        read = onRead;
        return const SizedBox.expand();
      },
    );
  }
}
