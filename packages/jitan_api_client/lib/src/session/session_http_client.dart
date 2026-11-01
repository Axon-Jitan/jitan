import 'package:http/http.dart' as http;

/// Tells the app when the server refuses the session, whichever page asked.
/// A 401 on sign-in itself is a wrong password, not an ended session.
class SessionHttpClient extends http.BaseClient {
  SessionHttpClient(this._onRefused, {http.Client? inner}) : _inner = inner ?? http.Client();

  final void Function() _onRefused;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 401 && !request.url.path.endsWith('/auth/sign-in')) _onRefused();
    return response;
  }
}
