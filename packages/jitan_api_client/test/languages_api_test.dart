import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

LanguagesApi _api(Map<String, Object> responsesByPath, {List<Uri>? requested}) => LanguagesApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((request) async {
          requested?.add(request.url);
          final body = responsesByPath[request.url.path];
          return body == null
              ? http.Response('{"error":{"code":"not_found","message":"x"}}', 404)
              : http.Response(jsonEncode(body), 200);
        }),
      ),
    );

void main() {
  test('lists languages', () async {
    final api = _api({
      '/languages': {
        'languages': [
          {'id': 1, 'code': 'en', 'name': 'English'},
        ],
      },
    });

    expect((await api.listLanguages()).single.code, 'en');
  });

  test('fetches one bundle per language code', () async {
    final requested = <Uri>[];
    final api = _api({
      '/translations': {
        'language': 'nl',
        'translations': {'common.save': 'Opslaan'},
      },
    }, requested: requested);

    final bundle = await api.translationBundle('nl');

    expect(requested.single.toString(), 'http://api.test/translations?language=nl');
    expect(bundle.texts, {'common.save': 'Opslaan'});
  });

  test('reads the current user language, including none', () async {
    expect(await _api({'/me/language': {'languageCode': 'fr'}}).currentUserLanguage(), 'fr');
    expect(await _api({'/me/language': {'languageCode': null}}).currentUserLanguage(), isNull);
  });

  test('a malformed bundle is an invalid response', () async {
    final api = _api({
      '/translations': {'language': 'nl', 'translations': 'nope'},
    });

    expect(
      api.translationBundle('nl'),
      throwsA(isA<ApiClientException>().having((e) => e.kind, 'kind', ApiFailureKind.invalidResponse)),
    );
  });

  test('an unknown language surfaces the server error', () async {
    expect(
      _api({}).translationBundle('xx'),
      throwsA(isA<ApiClientException>().having((e) => e.error?.code, 'code', 'not_found')),
    );
  });
}
