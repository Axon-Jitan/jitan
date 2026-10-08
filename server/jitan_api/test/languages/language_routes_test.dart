import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _en = Language(id: 1, code: 'en', name: 'English');
const _nl = Language(id: 2, code: 'nl', name: 'Dutch');

TestApp _app({int? devUserId = 1}) {
  final app = TestApp(devUserId: devUserId);
  app.languages.languages = [_en, _nl];
  app.translations.texts = {
    1: {'common.save': 'Save', 'company.title': 'Companies'},
    2: {'common.save': 'Opslaan'},
  };
  return app;
}

void main() {
  group('GET /languages', () {
    test('lists active languages without sign-in', () async {
      final response = await _app(devUserId: null).get('/languages');

      expect(response.statusCode, 200);
      expect(await jsonBody(response), {
        'languages': [
          {'id': 1, 'code': 'en', 'name': 'English'},
          {'id': 2, 'code': 'nl', 'name': 'Dutch'},
        ],
      });
    });
  });

  group('GET /translations', () {
    test('returns the whole bundle for a language without sign-in', () async {
      final response = await _app(devUserId: null).get('/translations?language=nl');

      expect(response.statusCode, 200);
      expect(await jsonBody(response), {
        'language': 'nl',
        'translations': {'common.save': 'Opslaan'},
      });
    });

    test('serves only database content; no server-side fallback is mixed in', () async {
      final body = await jsonBody(await _app().get('/translations?language=nl'));

      expect((body['translations'] as Map).containsKey('company.title'), isFalse);
    });

    test('404 for an unknown or inactive language', () async {
      final response = await _app().get('/translations?language=xx');

      expect(response.statusCode, 404);
      expect((await jsonBody(response))['error'], containsPair('code', 'not_found'));
    });

    test('400 without a language', () async {
      expect((await _app().get('/translations')).statusCode, 400);
      expect((await _app().get('/translations?language=%20')).statusCode, 400);
    });

    test('400 for an over-long language code', () async {
      expect((await _app().get('/translations?language=${'x' * 17}')).statusCode, 400);
    });
  });

  group('GET /me/language', () {
    test('returns the user\'s language', () async {
      final app = _app(devUserId: 1)..languages.userLanguages = {1: ['nl']};

      final body = await jsonBody(await app.get('/me/language'));

      expect(body, {'languageCode': 'nl'});
    });

    test('returns null when the user has no language (client uses English)', () async {
      final body = await jsonBody(await _app().get('/me/language'));

      expect(body, {'languageCode': null});
    });

    test('409 configuration_error when several languages are assigned (CLARIFY-07)', () async {
      final app = _app(devUserId: 1)..languages.userLanguages = {1: ['en', 'nl']};

      final response = await app.get('/me/language');

      expect(response.statusCode, 409);
      expect((await jsonBody(response))['error'], containsPair('code', 'configuration_error'));
    });

    test('requires sign-in', () async {
      expect((await _app(devUserId: null).get('/me/language')).statusCode, 401);
    });
  });

  group('PUT /me/language', () {
    TestApp app() {
      final a = _app(devUserId: 1);
      a.userLanguages.languages = {
        1: (name: 'English', code: 'en', active: true),
        2: (name: 'Dutch', code: 'nl', active: true),
      };
      a.userLanguages.rows[1] = [(userLanguageId: 7, languageId: 1)];
      return a;
    }

    test('the signed-in user changes their own language whenever they want, audited', () async {
      final a = app();

      final first = await a.put('/me/language', '{"languageCode": "nl"}');
      final back = await a.put('/me/language', '{"languageCode": "en"}');

      expect(first.statusCode, 200);
      expect(await jsonBody(first), {'languageCode': 'nl'});
      expect(back.statusCode, 200);
      expect(a.userLanguages.rows[1], [(userLanguageId: 7, languageId: 1)], reason: 'one row, updated in place');
      expect(a.audit.events.map((e) => (e.actorUserId, e.references[EventLogReference.user])), [(1, 1), (1, 1)]);
      expect(a.audit.events.map((e) => e.type).toSet(), {AuditEventType.languageChanged});
    });

    test('unknown or inactive language codes are refused on languageCode', () async {
      final a = app();

      final response = await a.put('/me/language', '{"languageCode": "xx"}');

      expect(response.statusCode, 400);
      expect((await jsonBody(response))['error'], containsPair('field', 'languageCode'));
      expect(a.audit.events, isEmpty);
    });

    test('requires sign-in and a well-formed body', () async {
      expect((await _app(devUserId: null).put('/me/language', '{"languageCode": "nl"}')).statusCode, 401);
      expect((await app().put('/me/language', '{}')).statusCode, 400);
    });
  });

  test('company routes still resolve alongside the language routes', () async {
    expect((await _app().get('/companies')).statusCode, 200);
  });
}
