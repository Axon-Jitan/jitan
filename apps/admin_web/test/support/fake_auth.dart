import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

const testAccount = EmployeeAccount(firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', companies: ['Almeco']);

class FakeAuthApi implements AuthApi {
  final requests = <SignInRequest>[];
  ApiClientException? failure;

  @override
  Future<SessionResponse> signIn(SignInRequest request) async {
    requests.add(request);
    if (failure case final f?) throw f;
    return SessionResponse(
      account: EmployeeAccount(firstName: 'Disan', lastName: 'Ssebowa', code: request.code, companies: const ['Almeco']),
      session: SessionInfo(accessToken: 'token-1', expiresAt: DateTime(2026, 11, 30, 9)),
    );
  }
}

class FakeMeApi implements MeApi {
  ApiClientException? failure;

  @override
  Future<EmployeeAccount> me() async {
    if (failure case final f?) throw f;
    return testAccount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers at once, unlike the completer-driven [FakeCompaniesApi].
class AllCompaniesApi implements CompaniesApi {
  ApiClientException? failure;

  @override
  Future<List<CompanySummary>> listCompanies({String? search}) async {
    if (failure case final f?) throw f;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
