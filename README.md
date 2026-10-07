# Jitan

Workforce time registration. **Time tracking without the tracking.**

Rules and context: [CLAUDE.md](CLAUDE.md) · [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md) ·
[docs/ROADMAP.md](docs/ROADMAP.md) · [docs/database/ERD.md](docs/database/ERD.md)

## Repository

Dart pub workspace (one lockfile at the root).

```text
apps/admin_web            HR/Admin web app (Flutter web)
packages/jitan_models     shared API/domain models (pure Dart)
packages/jitan_api_client typed API client for all Flutter apps (pure Dart)
packages/jitan_core       shared client logic, e.g. the translation service (pure Dart)
packages/jitan_ui         design system from Figma: tokens, theme, components (Flutter)
server/jitan_api          Dart API, the only component that talks to MySQL
```

Not created yet, added with their first slice: `apps/employee_mobile`, `apps/employee_web`,
`apps/terminal`.

Requirements: Flutter 3.44+ (Dart 3.12+). No Docker needed.

```sh
flutter pub get        # at the repo root; resolves every package
dart analyze           # whole workspace
```

## Run the API (development)

```sh
cd server/jitan_api
cp .env.example .env   # fill in the dev database; never commit .env
dart run bin/server.dart
```

- `GET /health`: process is up (no database needed)
- `GET /health/database`: `SELECT 1` against MySQL (503 when unreachable)
- `GET /languages`, `GET /translations?language=<code>`: UI text from `tblTranslation`
  (no sign-in needed, so the login screen can be translated)
- `GET /me/language`: the signed-in user's language from `tblUserLanguage`
- `GET /companies?search=`: company list (needs an identity, see below)
- `GET /companies/{id}/employees?search=`: that company's employees

**Development identity.** Real login isn't built yet. With `JITAN_ENV=development`, set
`JITAN_DEV_USER_ID` to an active `tblUser.userID`; every request then acts as that user. A
dev-only permission evaluator allows everything. With `JITAN_ENV=production` (also the
default when unset) the server **refuses to start** if any `JITAN_DEV_*` variable is set,
and every protected route answers 401/403 until real auth and permissions exist.

**Translations.** English is built into the apps (`builtInEnglish` in `jitan_core`) and
always works, even with no API or database. Other languages come from `tblTranslation`;
missing texts fall back to English.

**Development data.** To fill an empty dev database with `[DEV]` companies and users:

```sh
cd server/jitan_api
dart run tool/dev_seed.dart                   # [DEV] companies, users, groups; prints the
                                              # userID to use as JITAN_DEV_USER_ID
dart run tool/dev_seed.dart --pseudo-language # also: a fake "[DEV] Pseudo" database language
                                              # (texts in ⟦…⟧) assigned to the dev user
dart run tool/dev_seed.dart --remove          # deletes everything the seed created
```

Refuses to run outside `development`/`test`.

## Run the HR/Admin web app

```sh
cd apps/admin_web
flutter run -d chrome --web-port 5000 \
  --dart-define=JITAN_API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=JITAN_DEV_TOOLS=true
```

`JITAN_DEV_TOOLS=true` (development only) shows the **current company selector** above every
page. Company-scoped pages such as Employees need a current company, and the production
company switcher is not designed yet. Leave it out of production builds.

`JITAN_API_BASE_URL` is required. Without it the app shows a configuration error instead
of guessing. The API must list the web origin in `JITAN_CORS_ORIGINS`
(`.env.example` has `http://localhost:5000`).

## Tests

```sh
cd packages/jitan_models     && dart test
cd packages/jitan_api_client && dart test
cd packages/jitan_core       && dart test
cd server/jitan_api          && dart test
cd packages/jitan_ui         && flutter test
cd apps/admin_web            && flutter test
```

Server **integration tests** (`test/integration/`) run against a real dev/test MySQL and are
skipped until one is configured. Set `JITAN_TEST_DB_HOST`, `JITAN_TEST_DB_NAME`,
`JITAN_TEST_DB_USER`, `JITAN_TEST_DB_PASSWORD` (or put them in a git-ignored
`server/jitan_api/.env.test`). They verify every column the repositories use exists with
the exact ERD spelling, then run the real SQL on `[DEV-TEST]` fixtures that they remove
afterwards. **Never point them at production.**
